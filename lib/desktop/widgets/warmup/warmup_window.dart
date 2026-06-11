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
import '../queue/arena_activity_session.dart';
import '../queue/arena_window_widgets.dart';
import '../queue/queue_activity_log.dart';
import '../queue/queue_arena.dart';
import 'warmup_arena_session.dart';
import 'warmup_settings.dart';

/// 暖服窗口
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

  const WarmupWindow({
    super.key,
    required this.serverAddress,
    this.isCustomServer = false,
    this.onClose,
    this.initialServerInfo,
    this.initialMapInfo,
    this.serverName,
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

class _WarmupWindowContentState extends State<_WarmupWindowContent>
    with ArenaSessionBinding<_WarmupWindowContent> {
  // 监听全局操作状态
  final StatusWindowService _statusService = StatusWindowService();
  final SteamUserService _steamUserService = SteamUserService();
  StreamSubscription<OperationState>? _stateSubscription;

  // 活动日志与竞技场状态持久化在 WarmupArenaSession 中（窗口重开后保持），
  // 且日志记录由 session 直接订阅 WarmupUsersBloc 完成，
  // 因此即使窗口关闭、暖服在后台运行，日志也会持续记录、不丢失。
  @override
  final WarmupArenaSession session = WarmupArenaSession.instance;

  @override
  void initState() {
    super.initState();
    // 注意：不在这里清空会话数据。
    // 会话数据在"开始暖服"时由 _startWarmup 重置，在"停止暖服"时清空，
    // 窗口关闭再重开（最小化到后台后唤醒）需要保持原有日志和竞技场用户。
    bindSession();

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
    unbindSession();
    super.dispose();
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
        child: BlocListener<WarmupBloc, WarmupBlocState>(
          listenWhen: (previous, current) =>
              previous.status != WarmupStatus.launching &&
              current.status == WarmupStatus.launching,
          listener: (context, state) {
            // 达标后点击"立即加入"或倒计时结束 → 进入 launching：
            // 连接指令已下发，直接关闭暖服面板，不在此等待游戏启动/进服。
            // 单例 Bloc/Service 会在后台继续完成启动与连接。
            widget.onClose?.call();
          },
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
      ),
    );
  }

  /// 构建头部
  Widget _buildHeader(BuildContext context, WarmupBlocState state) {
    final serverInfo = state.serverInfo;
    return ArenaWindowHeader(
      title: '暖服',
      serverName: state.serverName ?? serverInfo?.hostName ?? '加载中...',
      mapName: serverInfo?.map ?? '未知地图',
      mapUrl: state.mapInfo?.mapUrl,
      serverAddress: widget.serverAddress,
      players: serverInfo?.players ?? 0,
      maxPlayers: serverInfo?.maxPlayers ?? 0,
      isInitialized: state.isInitialized,
      onClose: () => _handleClose(context, state),
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

    return BlocBuilder<WarmupUsersBloc, WarmupUsersState>(
      builder: (context, usersState) {
        // 注意：活动日志的记录已移至 WarmupArenaSession（直接订阅 WarmupUsersBloc），
        // 这样窗口关闭、后台运行时也能持续记录日志，不会出现空档。
        // 本面板只负责渲染。

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
              decoration: arenaPanelDecoration(isDark),
              child: QueueArena(
                users: usersState.users,
                isWarmup: true,
                session: session,
                centerWidget: ArenaServerIcon(
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
            QueueActivityLog(activities: activities, isWarmup: true),
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
            // 停止暖服时清空会话（活动日志、竞技场用户、位置）。
            session.clear();
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
    // 开始新的暖服会话：重置持久化的活动日志、竞技场位置与自己加入标记，
    // 并开始订阅用户事件流（后台也会持续记录日志）。
    session.resetFor(widget.serverAddress);

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
