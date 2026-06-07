import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/bloc/auth/auth_bloc.dart';
import '../../../core/bloc/warmup/warmup_bloc.dart';
import '../../../core/bloc/warmup/warmup_event.dart';
import '../../../core/bloc/warmup/warmup_state.dart';
import '../../../core/bloc/warmup_users/warmup_users_bloc.dart';
import '../../../core/bloc/warmup_users/warmup_users_event.dart';
import '../../../core/bloc/warmup_users/warmup_users_state.dart';
import '../../../core/models/server_models.dart';
import '../../../core/services/status_window_service.dart';
import '../../../core/services/steam_user_service.dart';
import '../../../core/utils/map_utils.dart';
import '../../../core/utils/player_count_utils.dart';
import '../../../core/widgets/map_background.dart';
import '../queue/queue_activity_log.dart';
import '../queue/queue_arena.dart';
import 'warmup_settings.dart';

/// 缓存的用户信息
class _CachedUserInfo {
  final String userName;
  final bool isSelf;

  const _CachedUserInfo({required this.userName, required this.isSelf});
}

/// 挤服窗口
class WarmupWindow extends StatefulWidget {
  final String serverAddress;
  final bool isCustomServer; // 是否为自定义服务器
  final VoidCallback? onClose;

  /// 初始服务器信息（可选，用于立即显示已有数据）
  final ServerInfo? initialServerInfo;

  /// 初始地图信息（可选）
  final MapData? initialMapInfo;

  /// 自定义服务器名称（通常是用户设置的备注名，如果没有则是官方名）
  final String? serverName;
  final int queueCount;

  const WarmupWindow({
    super.key,
    required this.serverAddress,
    this.isCustomServer = false,
    this.onClose,
    this.initialServerInfo,
    this.initialMapInfo,
    this.serverName,
    this.queueCount = 0,
  });

  @override
  State<WarmupWindow> createState() => _WarmupWindowState();
}

class _WarmupWindowState extends State<WarmupWindow> {
  late final WarmupBloc _warmupBloc;
  final StatusWindowService _statusService = StatusWindowService();

  @override
  void initState() {
    super.initState();
    // 标记挤服窗口已打开
    _statusService.setWarmupWindowOpen(true);

    _warmupBloc = WarmupBloc.instance
      ..add(
        WarmupInitialize(
          widget.serverAddress,
          isCustomServer: widget.isCustomServer,
          initialServerInfo: widget.initialServerInfo,
          initialMapInfo: widget.initialMapInfo,
          serverName: widget.serverName,
          queueCount: widget.queueCount,
        ),
      );

    // 如果挤服正在进行且 WebSocket 未连接，立即重新连接
    // 注意：不发送新的 WarmupUsersJoin，让 WarmupUsersBloc 的 _lastJoin 机制处理重连后的 join
    final currentState = _statusService.state;
    final usersBloc = WarmupUsersBloc.instance;
    if (currentState.type == OperationType.queueing &&
        currentState.status == OperationStatus.running &&
        !usersBloc.state.isConnected) {
      usersBloc.add(WarmupUsersConnect(serverAddress: widget.serverAddress));
      // 连接成功后会通过 _lastJoin 机制自动重发 join（保留原有用户信息）
    }
  }

  @override
  void dispose() {

    // 标记挤服窗口已关闭
    _statusService.setWarmupWindowOpen(false);

    // 窗口关闭时不断开 WebSocket 连接，让挤服在后台继续运行
    // 单例 Bloc 和 Service 保持运行，不关闭

    // 此时不再关闭 _warmupBloc，让它作为单例在后台继续轮询
    // _warmupBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _warmupBloc),
        BlocProvider.value(value: WarmupUsersBloc.instance),
      ],
      child: _WarmupWindowContent(
        serverAddress: widget.serverAddress,
        onClose: widget.onClose,
      ),
    );
  }
}

class _WarmupWindowContent extends StatefulWidget {
  final String serverAddress;
  final VoidCallback? onClose;

  const _WarmupWindowContent({required this.serverAddress, this.onClose});

  @override
  State<_WarmupWindowContent> createState() => _WarmupWindowContentState();
}

class _WarmupWindowContentState extends State<_WarmupWindowContent> {
  // 监听全局操作状态
  final StatusWindowService _statusService = StatusWindowService();
  final SteamUserService _steamUserService = SteamUserService();
  StreamSubscription<OperationState>? _stateSubscription;

  // 活动日志列表（限制最大条数防止内存溢出）
  final List<QueueActivityItem> _activities = [];
  static const int _maxActivities = 100;

  // 用户信息缓存（用于在用户离开/成功时获取昵称）
  final Map<String, _CachedUserInfo> _userInfoCache = {};
  static const int _maxCacheSize = 50;

  @override
  void initState() {
    super.initState();
    // 清除上次的活动日志和缓存
    _activities.clear();
    _userInfoCache.clear();

    // 监听全局状态变化，触发 UI 更新
    _stateSubscription = _statusService.stateStream.listen((_) {
      // 双重检查 mounted 状态，确保安全
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _activities.clear();
    _userInfoCache.clear();
    super.dispose();
  }

  /// 添加活动日志（带数量限制）
  void _addActivity(QueueActivityItem activity) {
    setState(() {
      _activities.add(activity);
      // 超过最大条数时移除最早的记录
      if (_activities.length > _maxActivities) {
        _activities.removeRange(0, _activities.length - _maxActivities);
      }
    });
  }

  /// 更新用户信息缓存
  void _updateUserInfoCache(List<dynamic> users) {
    for (final user in users) {
      final uniqueId = user.uniqueId as String;
      final nickname = user.nickname as String?;
      final isSelf = user.isSelf as bool;
      _userInfoCache[uniqueId] = _CachedUserInfo(
        userName: nickname ?? (user.isAnonymous ? '未登录用户' : '用户'),
        isSelf: isSelf,
      );
    }
    // 缓存过大时清理最早的条目
    if (_userInfoCache.length > _maxCacheSize) {
      final keysToRemove = _userInfoCache.keys
          .take(_userInfoCache.length - _maxCacheSize)
          .toList();
      for (final key in keysToRemove) {
        _userInfoCache.remove(key);
      }
    }
  }

  /// 获取缓存的用户信息
  _CachedUserInfo _getCachedUserInfo(String uniqueId) {
    return _userInfoCache[uniqueId] ??
        const _CachedUserInfo(userName: '用户', isSelf: false);
  }

  /// 处理关闭按钮点击
  void _handleClose(BuildContext context, WarmupBlocState state) {
    // 关闭对话框时不暂停挤服，让挤服在后台继续运行
    // 用户可以通过悬浮卡片查看状态或停止暖服
    context.read<WarmupBloc>().add(const WarmupDispose());
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: BlocBuilder<WarmupBloc, WarmupBlocState>(
          builder: (context, state) {
            return Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 头部（地图背景 + 服务器信息）
                    _buildHeader(context, state),
                    // 内容区域
                    Flexible(
                      child: SingleChildScrollView(
                        child: _buildContent(context, state),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 构建头部
  Widget _buildHeader(BuildContext context, WarmupBlocState state) {
    final serverInfo = state.serverInfo;
    final mapName = serverInfo?.map ?? '未知地图';
    final mapUrl = state.mapInfo?.mapUrl;

    final players = serverInfo?.players ?? 0;
    final maxPlayers = serverInfo?.maxPlayers ?? 0;
    final playerColor = PlayerCountUtils.getPlayerCountColor(
      players,
      maxPlayers,
    );

    return Container(
      height: 130,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        color: Color(0xFF1E293B),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 地图背景
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: MapBackground(mapName: mapName, imageUrl: mapUrl),
          ),
          // 渐变遮罩
          Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
          // 服务器信息
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部：标题和关闭按钮
                Row(
                  children: [
                    Icon(
                      MdiIcons.accountMultiplePlus,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '暖服',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // 玩家数量标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: playerColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            MdiIcons.accountGroup,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$players/$maxPlayers',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 关闭按钮
                    InkWell(
                      onTap: () => _handleClose(context, state),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // 服务器名称
                Text(
                  state.serverName ?? serverInfo?.hostName ?? '加载中...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // 服务器信息标签
                Row(
                  children: [
                    _buildInfoChip(MdiIcons.map, _getFormattedMapName(mapName)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoChip(MdiIcons.ip, widget.serverAddress),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 加载遮罩
          if (!state.isInitialized)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 获取格式化的地图名称
  String _getFormattedMapName(String mapName) {
    return MapUtils.formatMapName(mapName);
  }

  /// 构建信息标签
  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 构建内容区域
  Widget _buildContent(BuildContext context, WarmupBlocState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 挤服中显示动画面板，否则显示设置面板
              if (state.isWarmupActive)
                _buildArenaPanel(context, state)
              else
                WarmupSettings(state: state),
              const SizedBox(height: 16),
              // 操作按钮
              _buildActionButtons(context, state),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建动画面板
  Widget _buildArenaPanel(BuildContext context, WarmupBlocState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocConsumer<WarmupUsersBloc, WarmupUsersState>(
      listenWhen: (previous, current) {
        // 监听用户加入、离开、成功事件（只在 ID 变化时触发，避免重复）
        return (current.joinedUserId != null &&
                previous.joinedUserId != current.joinedUserId) ||
            (current.leftUserId != null &&
                previous.leftUserId != current.leftUserId) ||
            (current.successUserId != null &&
                previous.successUserId != current.successUserId);
      },
      listener: (context, usersState) {
        // 先更新缓存（确保在处理事件前缓存是最新的）
        _updateUserInfoCache(usersState.users);

        // 用户加入
        if (usersState.joinedUserId != null) {
          final joinedId = usersState.joinedUserId!;
          try {
            final user = usersState.users.firstWhere(
              (u) => u.uniqueId == joinedId,
            );
            _addActivity(
              QueueActivityItem.fromUser(user, QueueActivityType.join),
            );
          } catch (_) {
            // 用户不在列表中，使用缓存
            final cachedInfo = _getCachedUserInfo(joinedId);
            _addActivity(
              QueueActivityItem(
                id: '${joinedId}_join_${DateTime.now().millisecondsSinceEpoch}',
                type: QueueActivityType.join,
                userName: cachedInfo.userName,
                isSelf: cachedInfo.isSelf,
                timestamp: DateTime.now(),
              ),
            );
          }
        }

        // 用户离开 - 优先使用 state 中保存的用户信息，其次使用缓存
        if (usersState.leftUserId != null) {
          final leftId = usersState.leftUserId!;
          final leftUser = usersState.leftUser;
          if (leftUser != null) {
            _addActivity(
              QueueActivityItem.fromUser(leftUser, QueueActivityType.leave),
            );
          } else {
            final cachedInfo = _getCachedUserInfo(leftId);
            _addActivity(
              QueueActivityItem(
                id: '${leftId}_leave_${DateTime.now().millisecondsSinceEpoch}',
                type: QueueActivityType.leave,
                userName: cachedInfo.userName,
                isSelf: cachedInfo.isSelf,
                timestamp: DateTime.now(),
              ),
            );
          }
        }

        // 用户成功进入服务器 - 优先使用 state 中保存的用户信息，其次使用缓存
        if (usersState.successUserId != null) {
          final successId = usersState.successUserId!;
          final successUser = usersState.successUser;
          if (successUser != null) {
            _addActivity(
              QueueActivityItem.fromUser(
                successUser,
                QueueActivityType.success,
              ),
            );
          } else {
            final cachedInfo = _getCachedUserInfo(successId);
            _addActivity(
              QueueActivityItem(
                id: '${successId}_success_${DateTime.now().millisecondsSinceEpoch}',
                type: QueueActivityType.success,
                userName: cachedInfo.userName,
                isSelf: cachedInfo.isSelf,
                timestamp: DateTime.now(),
              ),
            );
          }
        }
      },
      builder: (context, usersState) {
        // 每次用户列表变化时更新缓存（包括 sync 事件）
        // 确保在用户离开/成功前已缓存其信息
        _updateUserInfoCache(usersState.users);

        // 判断服务器是否可加入
        final players = state.serverInfo?.players ?? 0;
        final maxPlayers = state.serverInfo?.maxPlayers ?? 0;
        final canJoin = maxPlayers > 0 && players < maxPlayers;
        final hasUserJoined = usersState.successUserId != null;

        return Column(
          children: [
            // 竞技场面板
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                    : const Color(0xFFF1F5F9).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: QueueArena(
                users: usersState.users,
                isWarmup: true,
                centerWidget: _WarmupServerIcon(
                  canJoin: canJoin,
                  hasUserJoined: hasUserJoined,
                ),
                joinedUserId: usersState.joinedUserId,
                leftUserId: usersState.leftUserId,
                successUserId: usersState.successUserId,
                onAnimationTriggered: () {
                  context.read<WarmupUsersBloc>().clearAnimationTriggers();
                },
                onUserSuccessAnimationComplete: (user) {
                  if (user.isSelf) {
                    // 自己成功进入，关闭窗口
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (context.mounted) {
                        context.read<WarmupBloc>().add(const WarmupDispose());
                        widget.onClose?.call();
                      }
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            // 活动日志
            QueueActivityLog(activities: _activities, isWarmup: true),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context, WarmupBlocState state) {
    // 暖服面板不再提供"启动游戏"按钮，游戏启动由达标倒计时结束后自动触发。
    return _buildWarmupButton(context, state);
  }

  Widget _buildWarmupButton(BuildContext context, WarmupBlocState state) {
    final theme = Theme.of(context);

    // 检查全局操作状态（是否有其他服务器正在操作）
    final globalState = _statusService.state;
    final isGlobalBusy =
        globalState.type != OperationType.none &&
        globalState.status == OperationStatus.running;
    final isOtherServerBusy =
        globalState.serverAddress != widget.serverAddress && isGlobalBusy;

    if (state.isWarmupActive) {
      return SizedBox(
        height: 44,
        child: ElevatedButton.icon(
          onPressed: () {
            // pauseQueue 内部会断开 WebSocket 连接
            context.read<WarmupBloc>().add(const WarmupPause());
          },
          icon: Icon(MdiIcons.pause, size: 18),
          label: const Text('暂停', style: TextStyle(fontSize: 14)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    // 其他服务器正在操作时，禁用开始暖服按钮
    if (isOtherServerBusy) {
      return SizedBox(
        height: 44,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: Icon(MdiIcons.play, size: 18),
          label: const Text('开始暖服', style: TextStyle(fontSize: 14)),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: (state.status == WarmupStatus.launching)
            ? null
            : () => _startWarmup(context),
        icon: (state.status == WarmupStatus.launching)
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(MdiIcons.play, size: 18),
        label: Text(
          (state.status == WarmupStatus.launching) ? '检查中...' : '开始暖服',
          style: const TextStyle(fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  /// 开始暖服
  ///
  /// 获取用户昵称优先级：Steam 客户端 > GSI > 登录用户名 > null（匿名）
  Future<void> _startWarmup(BuildContext context) async {
    // 清空活动日志和用户缓存（每次开始暖服都重新开始）
    setState(() {
      _activities.clear();
      _userInfoCache.clear();
    });

    // 获取当前用户信息（在 await 之前获取，避免 BuildContext 跨异步使用）
    final authState = context.read<AuthBloc>().state;
    final isAuthenticated = authState.isAuthenticated;
    final userInfo = authState.userInfo;
    final usersBloc = context.read<WarmupUsersBloc>();
    final queueBloc = context.read<WarmupBloc>();

    // 获取 Steam 用户名（优先级：Steam 配置 > GSI）
    final steamUsername = await _steamUserService.getCurrentUsername();

    // 最终昵称优先级：Steam 用户名 > 登录用户名 > null
    final nickname =
        steamUsername ?? (isAuthenticated ? userInfo?.username : null);
    final avatarUrl = isAuthenticated ? userInfo?.avatar : null;

    if (!mounted) return;

    // 先连接 WebSocket（如果还没连接）
    if (!usersBloc.state.isConnected) {
      usersBloc.add(WarmupUsersConnect(serverAddress: widget.serverAddress));
    }

    // 构建 WarmupUsersJoin 事件，包含当前用户信息
    // 后端不返回当前用户，需要在客户端把自己加入列表
    usersBloc.add(WarmupUsersJoin(nickname: nickname, avatarUrl: avatarUrl));
    queueBloc.add(const WarmupStart());
  }
}

/// 暖服中心服务器图标组件
///
/// 根据服务器状态显示不同颜色的光晕：
/// - 红色：服务器满员，无法加入
/// - 绿色：服务器有空位，可以加入（或有用户成功加入时）
class _WarmupServerIcon extends StatefulWidget {
  /// 是否可以加入（服务器有空位）
  final bool canJoin;

  /// 是否有用户刚成功加入
  final bool hasUserJoined;

  const _WarmupServerIcon({required this.canJoin, this.hasUserJoined = false});

  @override
  State<_WarmupServerIcon> createState() => _WarmupServerIconState();
}

class _WarmupServerIconState extends State<_WarmupServerIcon>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // 颜色过渡动画
  late AnimationController _colorController;
  late Animation<Color?> _colorAnimation;

  static const _greenColor = Color(0xFF22C55E);
  static const _redColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 颜色过渡动画控制器
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    final initialColor = (widget.canJoin || widget.hasUserJoined)
        ? _greenColor
        : _redColor;
    _colorAnimation = ColorTween(begin: initialColor, end: initialColor)
        .animate(
          CurvedAnimation(parent: _colorController, curve: Curves.easeInOut),
        );
  }

  @override
  void didUpdateWidget(_WarmupServerIcon oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldCanJoin = oldWidget.canJoin || oldWidget.hasUserJoined;
    final newCanJoin = widget.canJoin || widget.hasUserJoined;

    if (oldCanJoin != newCanJoin) {
      final fromColor = oldCanJoin ? _greenColor : _redColor;
      final toColor = newCanJoin ? _greenColor : _redColor;

      _colorAnimation = ColorTween(begin: fromColor, end: toColor).animate(
        CurvedAnimation(parent: _colorController, curve: Curves.easeInOut),
      );
      _colorController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _colorAnimation]),
      builder: (context, child) {
        final glowColor = _colorAnimation.value ?? _greenColor;

        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              // 外层光晕
              BoxShadow(
                color: glowColor.withValues(alpha: 0.3 * _pulseAnimation.value),
                blurRadius: 30 * _pulseAnimation.value,
                spreadRadius: 10 * _pulseAnimation.value,
              ),
              // 内层光晕
              BoxShadow(
                color: glowColor.withValues(alpha: 0.5 * _pulseAnimation.value),
                blurRadius: 15 * _pulseAnimation.value,
                spreadRadius: 3 * _pulseAnimation.value,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/queue/server.png',
            width: 80,
            height: 80,
          ),
        );
      },
    );
  }
}

/// 显示挤服窗口对话框
Future<void> showWarmupWindow(
  BuildContext context, {
  required String serverAddress,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => WarmupWindow(
      serverAddress: serverAddress,
      onClose: () => Navigator.of(context).pop(),
    ),
  );
}
