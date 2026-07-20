import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/models/queue_user.dart';
import 'arena_activity_session.dart';
import 'queue_user_avatar.dart';

/// 用户动画状态
class _UserAnimationState {
  final QueueUser user;
  double x; // 相对位置 0-1
  double y; // 相对位置 0-1
  double size; // 头像大小
  double opacity;
  bool isFlying;
  double flyProgress;
  double floatPhase; // 漂浮动画相位
  double floatSpeed; // 漂浮速度

  // 动画控制
  AnimationController? fadeController;
  AnimationController? flyController;

  _UserAnimationState({
    required this.user,
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.isFlying,
    required this.flyProgress,
    required this.floatPhase,
    required this.floatSpeed,
  });

  factory _UserAnimationState.create({
    required QueueUser user,
    required double x,
    required double y,
    required double size,
    required double floatPhase,
    required double floatSpeed,
    double opacity = 0.0,
  }) {
    return _UserAnimationState(
      user: user,
      x: x,
      y: y,
      size: size,
      opacity: opacity,
      isFlying: false,
      flyProgress: 0.0,
      floatPhase: floatPhase,
      floatSpeed: floatSpeed,
    );
  }

  void dispose() {
    fadeController?.dispose();
    flyController?.dispose();
  }
}

/// 挤服动画面板
///
/// 用户随机分布在面板中，中心是服务器
class QueueArena extends StatefulWidget {
  /// 用户列表
  final List<QueueUser> users;

  /// 中心组件（如服务器图标）
  final Widget centerWidget;

  /// 刚加入的用户ID（触发淡入动画）
  final String? joinedUserId;

  /// 刚离开的用户ID（触发淡出动画）
  final String? leftUserId;

  /// 刚成功的用户ID（触发飞入中心动画）
  final String? successUserId;

  /// 动画触发后的回调
  final VoidCallback? onAnimationTriggered;

  /// 用户成功动画完成后的回调
  final void Function(QueueUser user)? onUserSuccessAnimationComplete;

  /// 基础头像大小
  final double avatarSize;

  /// 是否是暖服
  final bool isWarmup;

  /// 可选的会话存储，用于持久化用户位置（窗口重开后保持）。
  /// 为 null 时位置仅保存在内存中（窗口关闭即丢失）。
  final ArenaActivitySession? session;

  const QueueArena({
    super.key,
    required this.users,
    required this.centerWidget,
    this.joinedUserId,
    this.leftUserId,
    this.successUserId,
    this.onAnimationTriggered,
    this.onUserSuccessAnimationComplete,
    this.avatarSize = 36,
    this.isWarmup = false,
    this.session,
  });

  @override
  State<QueueArena> createState() => _QueueArenaState();
}

class _QueueArenaState extends State<QueueArena> with TickerProviderStateMixin {
  /// 漂浮动画 Ticker
  Ticker? _floatTicker;
  double _floatTime = 0;

  /// 用户动画状态映射
  final Map<String, _UserAnimationState> _userStates = {};

  /// 正在淡出的用户（离开或成功）
  final Map<String, _UserAnimationState> _fadingOutUsers = {};

  /// 随机数生成器
  final Random _random = Random();

  /// 面板宽高比（width / height），用于把归一化距离修正为等效物理距离。
  ///
  /// 面板通常为长方形（约 388×250 → 1.55），若直接用归一化欧氏距离判定，
  /// Y 方向 1 单位对应的物理像素比 X 方向少 55%，会导致上下相邻头像明显重叠。
  /// 距离判定时用 `dy / _panelAspectRatio` 校正后，判定等效于比较物理距离。
  ///
  /// 首次 build 前默认取贴近实际的 1.55，避免 initState 里放置初始用户时判错。
  double _panelAspectRatio = 1.55;

  /// 淡入动画时长
  static const Duration _fadeInDuration = Duration(milliseconds: 400);

  /// 淡出动画时长
  static const Duration _fadeOutDuration = Duration(milliseconds: 300);

  /// 飞入中心动画时长
  static const Duration _flyDuration = Duration(milliseconds: 500);

  /// 最大显示用户数
  static const int _maxDisplayUsers = 50;

  /// 中心排斥半径（aspect 修正后，等价于物理圆的归一化半径）
  ///
  /// 判定采用 aspect 修正欧氏距离：sqrt(dx² + (dy/aspect)²) < ratio。
  /// 面板宽 388、高 250，aspect≈1.55；0.22 对应物理 X 半径 ≈ 85px、Y 半径 ≈ 85px
  /// （两方向物理距离相等的圆），服务器图标半径 ≈ 50px 时留白约 35px。
  static const double _centerExclusionRatio = 0.22;

  /// 头像大小基础浮动幅度（±15%）
  static const double _sizeVariation = 0.15;

  /// 面板外框留白（0.06 → 88% 有效放置带宽）
  static const double _edgeMargin = 0.06;

  /// 漂浮幅度
  static const double _floatAmplitude = 3.0;

  @override
  void initState() {
    super.initState();

    // 使用 Ticker 实现流畅的漂浮动画
    _floatTicker = createTicker((elapsed) {
      setState(() {
        _floatTime = elapsed.inMilliseconds / 1000.0;
      });
    });
    _floatTicker!.start();

    _initializeUserStates();
  }

  @override
  void didUpdateWidget(QueueArena oldWidget) {
    super.didUpdateWidget(oldWidget);
    _handleUsersChanged(oldWidget);
  }

  @override
  void dispose() {
    _floatTicker?.dispose();
    // 清理所有用户的动画控制器
    for (final state in _userStates.values) {
      state.dispose();
    }
    for (final state in _fadingOutUsers.values) {
      state.dispose();
    }
    super.dispose();
  }

  /// 初始化用户状态
  void _initializeUserStates() {
    final limitedUsers = _limitDisplayUsers(widget.users);

    for (final user in limitedUsers) {
      final pos = _resolvePosition(user.uniqueId);

      _userStates[user.uniqueId] = _UserAnimationState.create(
        user: user,
        x: pos.x,
        y: pos.y,
        size: pos.size,
        floatPhase: pos.floatPhase,
        floatSpeed: pos.floatSpeed,
        opacity: 1.0,
      );
    }
  }

  /// 解析用户位置：
  /// - 若 session 中已保存该用户位置，复用（保证窗口重开后位置不变）。
  /// - 否则新生成一个不重叠的位置，并在有 session 时存入。
  QueueArenaUserPosition _resolvePosition(String userId) {
    final session = widget.session;
    final saved = session?.positions[userId];
    if (saved != null) return saved;

    final position = _findAvailablePosition();
    final pos = QueueArenaUserPosition(
      x: position.$1,
      y: position.$2,
      size: _randomSize(),
      floatPhase: _random.nextDouble() * 2 * pi,
      floatSpeed: 0.3 + _random.nextDouble() * 0.2, // 更慢的漂浮速度
    );
    session?.positions[userId] = pos;
    return pos;
  }

  /// 限制显示用户数
  ///
  /// 截断前把自己置顶：`isSelf=true` 的用户永远优先显示，避免用户挤到 21 位以后
  /// 在竞技场里看不到自己头像。
  List<QueueUser> _limitDisplayUsers(List<QueueUser> users) {
    if (users.length <= _maxDisplayUsers) return users;

    QueueUser? self;
    final others = <QueueUser>[];
    for (final u in users) {
      if (u.isSelf && self == null) {
        self = u;
      } else {
        others.add(u);
      }
    }

    if (self == null) {
      return users.sublist(0, _maxDisplayUsers);
    }
    return [self, ...others.take(_maxDisplayUsers - 1)];
  }

  /// 随机生成头像大小（根据当前人数动态缩放）
  ///
  /// - ≤20 人：完整 avatarSize，±15% 浮动
  /// - 21-50 人：base 线性缩到 55%（36 → 20px），且浮动收到 ±8% 避免最大值超预算
  ///
  /// 与 [_getMinDistance] 配套设计：50 人时 base=20、max=21.6px，
  /// 而 minDistance=0.06 对应水平物理距离 23.3px，能容纳最大头像。
  double _randomSize() {
    final count = _userStates.length;
    final scale = count <= 20
        ? 1.0
        : (1.0 - (count - 20) * 0.015).clamp(0.55, 1.0);
    // 人多时收敛浮动，避免罕见"两个都是最大"命中重叠边界
    final variation = count > 30 ? 0.08 : _sizeVariation;
    final rnd = (_random.nextDouble() * 2 - 1) * variation;
    return widget.avatarSize * scale * (1 + rnd);
  }

  /// 根据当前人数动态决定最小归一化间距（水平方向物理距离）
  ///
  /// - ≤20 人：0.11 → 水平 42.7px，能容纳 41.4px 最大头像
  /// - 50 人：  0.06 → 水平 23.3px，能容纳 21.6px 最大头像
  ///
  /// 判定时对 dy 做 aspect 修正，等效于比较物理距离，保证 Y 方向也不重叠。
  double _getMinDistance() {
    final count = _userStates.length;
    if (count <= 20) return 0.11;
    return (0.11 - (count - 20) * 0.00167).clamp(0.06, 0.11);
  }

  /// 找一个可用的位置
  ///
  /// **距离判定原理**：面板是长方形（宽 > 高），归一化坐标下同一 dx/dy 对应
  /// 的物理像素不等。判定时把 dy 除以 aspect 比例，使 `sqrt(dx² + (dy/aspect)²)`
  /// 等价于比较 X 方向物理距离，保证任意方向上头像都不会重叠。
  ///
  /// - 中心排斥用同样的 aspect 修正，让排斥区在物理上是圆而非椭圆
  /// - 头像间距 [_getMinDistance] 已按最大头像尺寸预留缓冲
  (double, double) _findAvailablePosition() {
    const maxAttempts = 100;
    final minDistance = _getMinDistance();
    final aspect = _panelAspectRatio;
    final range = 1.0 - 2 * _edgeMargin;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final x = _edgeMargin + _random.nextDouble() * range;
      final y = _edgeMargin + _random.nextDouble() * range;

      // 中心排斥（aspect 修正后 → 物理圆）
      final dxc = x - 0.5;
      final dyc = (y - 0.5) / aspect;
      if (sqrt(dxc * dxc + dyc * dyc) < _centerExclusionRatio) continue;

      // 与已放置头像的最小间距检查（aspect 修正后 → 物理距离）
      bool overlaps = false;
      for (final state in _userStates.values) {
        final dx = x - state.x;
        final dy = (y - state.y) / aspect;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < minDistance) {
          overlaps = true;
          break;
        }
      }

      if (!overlaps) return (x, y);
    }

    // 兜底：只保证中心排斥，允许与其他头像轻微重叠（尝试 100 次都没找到，
    // 意味着面板已经很拥挤，此时 UX 上少量重叠比抛异常好）
    double x, y;
    do {
      x = _edgeMargin + _random.nextDouble() * range;
      y = _edgeMargin + _random.nextDouble() * range;
      final dxc = x - 0.5;
      final dyc = (y - 0.5) / aspect;
      if (sqrt(dxc * dxc + dyc * dyc) >= _centerExclusionRatio) {
        return (x, y);
      }
    } while (true);
  }

  /// 处理用户列表变化
  void _handleUsersChanged(QueueArena oldWidget) {
    if (widget.successUserId != null &&
        widget.successUserId != oldWidget.successUserId) {
      _handleUserSuccess(widget.successUserId!);
      widget.onAnimationTriggered?.call();
    }

    if (widget.leftUserId != null &&
        widget.leftUserId != oldWidget.leftUserId) {
      _handleUserLeft(widget.leftUserId!);
      widget.onAnimationTriggered?.call();
    }

    if (widget.joinedUserId != null &&
        widget.joinedUserId != oldWidget.joinedUserId) {
      _handleUserJoined(widget.joinedUserId!);
      widget.onAnimationTriggered?.call();
    }

    _syncUserList();
  }

  /// 同步用户列表
  void _syncUserList() {
    final limitedUsers = _limitDisplayUsers(widget.users);
    final currentIds = limitedUsers.map((u) => u.uniqueId).toSet();

    // 移除不在列表中的用户（但不移除正在淡出的用户）
    final toRemove = _userStates.keys
        .where(
          (id) => !currentIds.contains(id) && !_fadingOutUsers.containsKey(id),
        )
        .toList();
    for (final id in toRemove) {
      _userStates[id]?.dispose();
      _userStates.remove(id);
      widget.session?.positions.remove(id);
    }

    // 添加新用户（不在 _userStates 和 _fadingOutUsers 中的用户）
    for (final user in limitedUsers) {
      final userId = user.uniqueId;
      if (!_userStates.containsKey(userId) &&
          !_fadingOutUsers.containsKey(userId)) {
        final pos = _resolvePosition(userId);

        final state = _UserAnimationState.create(
          user: user,
          x: pos.x,
          y: pos.y,
          size: pos.size,
          floatPhase: pos.floatPhase,
          floatSpeed: pos.floatSpeed,
          opacity: 0.0, // 从透明开始，淡入显示
        );

        _userStates[userId] = state;
        _animateFadeIn(userId, state);
      }
    }
  }

  /// 处理用户加入
  void _handleUserJoined(String userId) {
    if (_userStates.containsKey(userId)) return;
    if (widget.users.isEmpty) return;

    final userIndex = widget.users.indexWhere((u) => u.uniqueId == userId);
    if (userIndex < 0) return;

    final user = widget.users[userIndex];
    final limitedUsers = _limitDisplayUsers(widget.users);
    if (!limitedUsers.any((u) => u.uniqueId == userId)) return;

    final pos = _resolvePosition(userId);

    final state = _UserAnimationState.create(
      user: user,
      x: pos.x,
      y: pos.y,
      size: pos.size,
      floatPhase: pos.floatPhase,
      floatSpeed: pos.floatSpeed,
      opacity: 0.0,
    );

    _userStates[userId] = state;
    _animateFadeIn(userId, state);
  }

  /// 处理用户离开
  void _handleUserLeft(String userId) {
    final state = _userStates.remove(userId);
    if (state == null) return;

    widget.session?.positions.remove(userId);
    _fadingOutUsers[userId] = state;
    _animateFadeOut(userId, state);
  }

  /// 处理用户成功
  void _handleUserSuccess(String userId) {
    final state = _userStates.remove(userId);
    if (state == null) return;

    widget.session?.positions.remove(userId);
    state.isFlying = true;
    _fadingOutUsers[userId] = state;
    _animateFlyToCenter(userId, state);
  }

  /// 淡入动画
  void _animateFadeIn(String userId, _UserAnimationState state) {
    // 若已有旧 fade controller 未结束（例如淡入过程中又被 sync 覆盖），
    // 先 dispose 再新建，避免泄漏和帧回调抖动。
    state.fadeController?.dispose();
    state.fadeController = null;

    final controller = AnimationController(
      vsync: this,
      duration: _fadeInDuration,
    );

    state.fadeController = controller;

    controller.addListener(() {
      if (mounted) {
        setState(() {
          state.opacity = Curves.easeOut.transform(controller.value);
        });
      }
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        // 只有当引用仍指向当前 controller 时才清空，避免误清后建的新 controller
        if (identical(state.fadeController, controller)) {
          state.fadeController = null;
        }
      }
    });

    controller.forward();
  }

  /// 淡出动画
  void _animateFadeOut(String userId, _UserAnimationState state) {
    // 淡出前先清掉可能残留的淡入 controller，防止两条动画同时驱动 opacity。
    state.fadeController?.dispose();
    state.fadeController = null;

    final controller = AnimationController(
      vsync: this,
      duration: _fadeOutDuration,
    );

    state.fadeController = controller;
    final startOpacity = state.opacity;

    controller.addListener(() {
      if (mounted) {
        setState(() {
          state.opacity =
              startOpacity * (1.0 - Curves.easeIn.transform(controller.value));
        });
      }
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _fadingOutUsers.remove(userId);
          });
        }
        state.dispose();
      }
    });

    controller.forward();
  }

  /// 飞入中心动画
  void _animateFlyToCenter(String userId, _UserAnimationState state) {
    // 飞入前清掉可能存在的旧 fly / fade controller，避免两个 controller 同时
    // 驱动 opacity / flyProgress，造成状态跳变。
    state.flyController?.dispose();
    state.flyController = null;
    state.fadeController?.dispose();
    state.fadeController = null;

    final controller = AnimationController(vsync: this, duration: _flyDuration);

    state.flyController = controller;

    controller.addListener(() {
      if (mounted) {
        final progress = controller.value;
        final easedProgress = Curves.easeInQuart.transform(progress);

        setState(() {
          state.flyProgress = easedProgress;
          if (progress > 0.6) {
            state.opacity = 1.0 - ((progress - 0.6) / 0.4);
          }
        });
      }
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        final user = state.user;
        if (mounted) {
          setState(() {
            _fadingOutUsers.remove(userId);
          });
        }
        state.dispose();
        widget.onUserSuccessAnimationComplete?.call(user);
      }
    });

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final centerX = width / 2;
        final centerY = height / 2;

        // 更新面板 aspect（用于 _findAvailablePosition 的距离修正）。
        // 首次 initState 时使用默认 1.55；build 拿到实际尺寸后校准，之后新加入
        // 的用户位置解析会使用真实 aspect。
        if (width > 0 && height > 0) {
          _panelAspectRatio = width / height;
        }

        return Stack(
          children: [
            // 用户头像
            ..._buildUserAvatars(width, height, centerX, centerY),
            // 中心组件
            Center(child: widget.centerWidget),
          ],
        );
      },
    );
  }

  /// 构建用户头像列表
  List<Widget> _buildUserAvatars(
    double width,
    double height,
    double centerX,
    double centerY,
  ) {
    final avatars = <Widget>[];

    for (final entry in _userStates.entries) {
      avatars.add(_buildAvatar(entry.value, width, height, centerX, centerY));
    }

    for (final entry in _fadingOutUsers.entries) {
      avatars.add(_buildAvatar(entry.value, width, height, centerX, centerY));
    }

    return avatars;
  }

  /// 构建单个头像
  Widget _buildAvatar(
    _UserAnimationState state,
    double width,
    double height,
    double centerX,
    double centerY,
  ) {
    // 使用正弦函数实现平滑漂浮，结合多个频率实现更自然的效果
    final floatOffsetY =
        sin(_floatTime * state.floatSpeed * 2 * pi + state.floatPhase) *
        _floatAmplitude;
    final floatOffsetX =
        sin(
          _floatTime * state.floatSpeed * 1.3 * pi + state.floatPhase + pi / 3,
        ) *
        _floatAmplitude *
        0.5;

    double x = state.x * width - state.size / 2 + floatOffsetX;
    double y = state.y * height - state.size / 2 + floatOffsetY;

    // 飞向中心
    if (state.isFlying) {
      final targetX = centerX - state.size / 2;
      final targetY = centerY - state.size / 2;
      x = x + (targetX - x) * state.flyProgress;
      y = y + (targetY - y) * state.flyProgress;
    }

    final scale = state.isFlying ? 1.0 - state.flyProgress * 0.5 : 1.0;

    return Positioned(
      left: x,
      top: y,
      child: Opacity(
        opacity: state.opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: QueueUserAvatar(
            user: state.user,
            size: state.size,
            isWarmup: widget.isWarmup,
          ),
        ),
      ),
    );
  }
}
