import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/models/queue_user.dart';
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

  /// 淡入动画时长
  static const Duration _fadeInDuration = Duration(milliseconds: 400);

  /// 淡出动画时长
  static const Duration _fadeOutDuration = Duration(milliseconds: 300);

  /// 飞入中心动画时长
  static const Duration _flyDuration = Duration(milliseconds: 500);

  /// 最大显示用户数
  static const int _maxDisplayUsers = 20;

  /// 中心区域半径比例（避开中心服务器图标）
  static const double _centerExclusionRatio = 0.38;

  /// 头像大小浮动范围
  static const double _sizeVariation = 0.2; // ±20%

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
      final position = _findAvailablePosition();
      final size = _randomSize();

      _userStates[user.uniqueId] = _UserAnimationState.create(
        user: user,
        x: position.$1,
        y: position.$2,
        size: size,
        floatPhase: _random.nextDouble() * 2 * pi,
        floatSpeed: 0.3 + _random.nextDouble() * 0.2, // 更慢的漂浮速度
        opacity: 1.0,
      );
    }
  }

  /// 限制显示用户数
  List<QueueUser> _limitDisplayUsers(List<QueueUser> users) {
    if (users.length <= _maxDisplayUsers) return users;
    return users.sublist(0, _maxDisplayUsers);
  }

  /// 随机生成头像大小
  double _randomSize() {
    final variation = (_random.nextDouble() * 2 - 1) * _sizeVariation;
    return widget.avatarSize * (1 + variation);
  }

  /// 找一个可用的位置
  (double, double) _findAvailablePosition() {
    const maxAttempts = 50;
    const minDistance = 0.12;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final x = 0.1 + _random.nextDouble() * 0.8;
      final y = 0.1 + _random.nextDouble() * 0.8;

      final distToCenter = sqrt(pow(x - 0.5, 2) + pow(y - 0.5, 2));
      if (distToCenter < _centerExclusionRatio) continue;

      bool overlaps = false;
      for (final state in _userStates.values) {
        final dist = sqrt(pow(x - state.x, 2) + pow(y - state.y, 2));
        if (dist < minDistance) {
          overlaps = true;
          break;
        }
      }

      if (!overlaps) return (x, y);
    }

    double x, y;
    do {
      x = 0.1 + _random.nextDouble() * 0.8;
      y = 0.1 + _random.nextDouble() * 0.8;
    } while (sqrt(pow(x - 0.5, 2) + pow(y - 0.5, 2)) < _centerExclusionRatio);

    return (x, y);
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
    }

    // 添加新用户（不在 _userStates 和 _fadingOutUsers 中的用户）
    for (final user in limitedUsers) {
      final userId = user.uniqueId;
      if (!_userStates.containsKey(userId) &&
          !_fadingOutUsers.containsKey(userId)) {
        final position = _findAvailablePosition();
        final size = _randomSize();

        final state = _UserAnimationState.create(
          user: user,
          x: position.$1,
          y: position.$2,
          size: size,
          floatPhase: _random.nextDouble() * 2 * pi,
          floatSpeed: 0.3 + _random.nextDouble() * 0.2,
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

    final position = _findAvailablePosition();
    final size = _randomSize();

    final state = _UserAnimationState.create(
      user: user,
      x: position.$1,
      y: position.$2,
      size: size,
      floatPhase: _random.nextDouble() * 2 * pi,
      floatSpeed: 0.3 + _random.nextDouble() * 0.2,
      opacity: 0.0,
    );

    _userStates[userId] = state;
    _animateFadeIn(userId, state);
  }

  /// 处理用户离开
  void _handleUserLeft(String userId) {
    final state = _userStates.remove(userId);
    if (state == null) return;

    _fadingOutUsers[userId] = state;
    _animateFadeOut(userId, state);
  }

  /// 处理用户成功
  void _handleUserSuccess(String userId) {
    final state = _userStates.remove(userId);
    if (state == null) return;

    state.isFlying = true;
    _fadingOutUsers[userId] = state;
    _animateFlyToCenter(userId, state);
  }

  /// 淡入动画
  void _animateFadeIn(String userId, _UserAnimationState state) {
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
        state.fadeController = null;
      }
    });

    controller.forward();
  }

  /// 淡出动画
  void _animateFadeOut(String userId, _UserAnimationState state) {
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
          child: QueueUserAvatar(user: state.user, size: state.size),
        ),
      ),
    );
  }
}
