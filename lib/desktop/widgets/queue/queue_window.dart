import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/bloc/auth/auth_bloc.dart';
import '../../../core/bloc/queue/queue_bloc.dart';
import '../../../core/bloc/queue/queue_event.dart';
import '../../../core/bloc/queue/queue_state.dart';
import '../../../core/bloc/queue_users/queue_users_bloc.dart';
import '../../../core/bloc/queue_users/queue_users_event.dart';
import '../../../core/bloc/queue_users/queue_users_state.dart';
import '../../../core/models/server_models.dart';
import '../../../core/services/status_window_service.dart';
import '../../../core/services/steam_user_service.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../core/widgets/csgo_manual_launch_dialog.dart';
import 'arena_activity_session.dart';
import 'arena_window_widgets.dart';
import 'queue_activity_log.dart';
import 'queue_arena.dart';
import 'queue_arena_session.dart';
import 'queue_settings.dart';

/// 挤服窗口
class QueueWindow extends StatefulWidget {
  final String serverAddress;
  final bool isCustomServer; // 是否为自定义服务器
  final VoidCallback? onClose;

  /// 初始服务器信息（可选，用于立即显示已有数据）
  final ServerInfo? initialServerInfo;

  /// 初始地图信息（可选）
  final MapData? initialMapInfo;

  /// 自定义服务器名称（通常是用户设置的备注名，如果没有则是官方名）
  final String? serverName;

  const QueueWindow({
    super.key,
    required this.serverAddress,
    this.isCustomServer = false,
    this.onClose,
    this.initialServerInfo,
    this.initialMapInfo,
    this.serverName,
  });

  @override
  State<QueueWindow> createState() => _QueueWindowState();
}

class _QueueWindowState extends State<QueueWindow> {
  late final QueueBloc _queueBloc;
  final StatusWindowService _statusService = StatusWindowService();

  @override
  void initState() {
    super.initState();
    // 标记挤服窗口已打开
    _statusService.setQueueWindowOpen(true);

    _queueBloc = QueueBloc()
      ..add(
        QueueInitialize(
          widget.serverAddress,
          isCustomServer: widget.isCustomServer,
          initialServerInfo: widget.initialServerInfo,
          initialMapInfo: widget.initialMapInfo,
          serverName: widget.serverName,
        ),
      );

    // 如果挤服正在进行且 WebSocket 未连接，立即重新连接
    // 注意：不发送新的 QueueUsersJoin，让 QueueUsersBloc 的 _lastJoin 机制处理重连后的 join
    final currentState = _statusService.state;
    final usersBloc = QueueUsersBloc.instance;
    if (currentState.type == OperationType.queueing &&
        currentState.status == OperationStatus.running &&
        !usersBloc.state.isConnected) {
      usersBloc.add(QueueUsersConnect(serverAddress: widget.serverAddress));
      // 连接成功后会通过 _lastJoin 机制自动重发 join（保留原有用户信息）
    }
  }

  @override
  void dispose() {
    // 标记挤服窗口已关闭
    _statusService.setQueueWindowOpen(false);

    // 窗口关闭时不断开 WebSocket 连接，让挤服在后台继续运行
    // 单例 Bloc 和 Service 保持运行，不关闭

    // 确保 QueueBloc 被正确关闭，释放 Timer 和 StreamSubscription
    _queueBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _queueBloc),
        BlocProvider.value(value: QueueUsersBloc.instance),
      ],
      child: _QueueWindowContent(
        serverAddress: widget.serverAddress,
        onClose: widget.onClose,
      ),
    );
  }
}

class _QueueWindowContent extends StatefulWidget {
  final String serverAddress;
  final VoidCallback? onClose;

  const _QueueWindowContent({required this.serverAddress, this.onClose});

  @override
  State<_QueueWindowContent> createState() => _QueueWindowContentState();
}

class _QueueWindowContentState extends State<_QueueWindowContent>
    with ArenaSessionBinding<_QueueWindowContent> {
  // 上一次处理的连接状态，用于防止重复 Toast
  QueueConnectionState? _lastToastConnectionState;

  // 监听全局操作状态
  final StatusWindowService _statusService = StatusWindowService();
  final SteamUserService _steamUserService = SteamUserService();
  StreamSubscription<OperationState>? _stateSubscription;

  // 活动日志与竞技场状态持久化在 QueueArenaSession 中（窗口重开后保持），
  // 且日志记录由 session 直接订阅 QueueUsersBloc 完成，
  // 因此即使窗口关闭、挤服在后台运行，日志也会持续记录、不丢失。
  @override
  final QueueArenaSession session = QueueArenaSession.instance;

  @override
  void initState() {
    super.initState();
    // 注意：不在这里清空会话数据。
    // 会话数据在"开始挤服"时由 _startQueue 重置，在"停止挤服"时清空，
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
  void _handleClose(BuildContext context, QueueBlocState state) {
    // 关闭对话框时不暂停挤服，让挤服在后台继续运行
    // 用户可以通过悬浮卡片查看状态或停止挤服
    context.read<QueueBloc>().add(const QueueDispose());
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
        child: BlocListener<QueueBloc, QueueBlocState>(
          listenWhen: (previous, current) {
            // needManualLaunch 优先级最高，单独处理
            if (!previous.needManualLaunch && current.needManualLaunch) {
              return true;
            }

            // 如果 needManualLaunch 为 true，不处理其他状态变化（避免重复提示）
            if (current.needManualLaunch) return false;

            // 其他状态变化
            if (previous.error != current.error && current.error != null) {
              return true;
            }
            if (previous.connectionState != current.connectionState) {
              return true;
            }

            return false;
          },
          listener: (context, state) {
            // 需要手动启动 CSGO
            if (state.needManualLaunch) {
              showDialog(
                context: context,
                builder: (context) => CsgoManualLaunchDialog(
                  serverAddress: state.serverAddress ?? widget.serverAddress,
                ),
              );
              return;
            }

            // 错误提示
            if (state.error != null) {
              ToastUtils.showError(context, state.error!);
              return;
            }

            // 连接成功 Toast（只提示一次）
            if (state.connectionState == QueueConnectionState.connected &&
                _lastToastConnectionState != QueueConnectionState.connected) {
              _lastToastConnectionState = QueueConnectionState.connected;
              // WebSocket 断开由 StatusWindowService 统一处理
              // 文案优先用 service 的实际消息（可能是"你已在服务器中"），
              // 没有则回退到默认提示。
              ToastUtils.showSuccess(
                context,
                state.connectionMessage ?? '进去啦！',
              );
              // 延迟关闭窗口，让用户看到成功提示
              Future.delayed(const Duration(milliseconds: 500), () {
                if (context.mounted) {
                  context.read<QueueBloc>().add(const QueueDispose());
                  widget.onClose?.call();
                }
              });
              return;
            }

            // 重置 Toast 状态追踪（新的挤服周期）
            if (state.connectionState == QueueConnectionState.idle) {
              _lastToastConnectionState = null;
            }
          },
          child: BlocBuilder<QueueBloc, QueueBlocState>(
            builder: (context, state) {
              return Column(
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
              );
            },
          ),
        ),
      ),
    );
  }

  /// 构建头部
  Widget _buildHeader(BuildContext context, QueueBlocState state) {
    final serverInfo = state.serverInfo;
    return ArenaWindowHeader(
      title: '挤服',
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
  Widget _buildContent(BuildContext context, QueueBlocState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 挤服中显示动画面板，否则显示设置面板
          if (state.isQueueActive)
            _buildArenaPanel(context, state)
          else
            QueueSettings(
              key: const ValueKey('settings'),
              targetPlayers: state.config.targetPlayers,
              threadCount: state.config.threadCount,
              enableAutoRetry: state.config.enableAutoRetry,
              isDonator: state.config.isDonator,
              disabled: state.isQueueActive || state.isConnecting,
              isGameRunning: state.isGameRunning,
              maxPlayers: state.serverInfo?.maxPlayers ?? 64,
              gameType: state.serverInfo?.gameType,
              appId: state.serverInfo?.appId,
              mapName: state.serverInfo?.map,
              isCustomServer: state.isCustomServer,
              multiThreadEnabled: state.config.multiThreadEnabled,
              requestIntervalSeconds: state.config.requestIntervalSeconds,
              onTargetPlayersChanged: (value) {
                context.read<QueueBloc>().add(QueueSetTargetPlayers(value));
              },
              onThreadCountChanged: (value) {
                context.read<QueueBloc>().add(QueueSetThreadCount(value));
              },
              onAutoRetryChanged: (value) {
                context.read<QueueBloc>().add(QueueSetAutoRetry(value));
              },
              onDonatorChanged: (value) {
                context.read<QueueBloc>().add(QueueSetDonator(value));
              },
              onMultiThreadEnabledChanged: (value) {
                context
                    .read<QueueBloc>()
                    .add(QueueSetMultiThreadEnabled(value));
              },
              onRequestIntervalChanged: (value) {
                context
                    .read<QueueBloc>()
                    .add(QueueSetRequestInterval(value));
              },
            ),
          const SizedBox(height: 16),
          // 操作按钮
          _buildActionButtons(context, state),
        ],
      ),
    );
  }

  /// 构建动画面板
  Widget _buildArenaPanel(BuildContext context, QueueBlocState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<QueueUsersBloc, QueueUsersState>(
      builder: (context, usersState) {
        // 注意：活动日志的记录已移至 QueueArenaSession（直接订阅 QueueUsersBloc），
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
                session: session,
                centerWidget: ArenaServerIcon(
                  canJoin: canJoin,
                  hasUserJoined: hasUserJoined,
                ),
                joinedUserId: usersState.joinedUserId,
                leftUserId: usersState.leftUserId,
                successUserId: usersState.successUserId,
                onAnimationTriggered: () {
                  context.read<QueueUsersBloc>().clearAnimationTriggers();
                },
                onUserSuccessAnimationComplete: (user) {
                  if (user.isSelf) {
                    // 自己成功进入，关闭窗口
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (context.mounted) {
                        context.read<QueueBloc>().add(const QueueDispose());
                        widget.onClose?.call();
                      }
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            // 活动日志
            QueueActivityLog(activities: activities),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context, QueueBlocState state) {
    // CS:Source 只发连接指令、不需要"启动游戏"，仅显示挤服按钮。
    if (state.isConnectOnlyServer) {
      return Row(
        children: [
          Expanded(child: _buildQueueButton(context, state)),
        ],
      );
    }

    return Row(
      children: [
        // 开始/暂停挤服按钮
        Expanded(child: _buildQueueButton(context, state)),
        const SizedBox(width: 12),
        // 启动游戏按钮
        Expanded(child: _buildLaunchGameButton(context, state)),
      ],
    );
  }

  Widget _buildQueueButton(BuildContext context, QueueBlocState state) {
    final theme = Theme.of(context);

    // 检查全局操作状态（是否有其他服务器正在操作）
    final globalState = _statusService.state;
    final isGlobalBusy =
        globalState.type != OperationType.none &&
        globalState.status == OperationStatus.running;
    final isOtherServerBusy =
        globalState.serverAddress != widget.serverAddress && isGlobalBusy;

    // 游戏未就绪或正在启动时，禁用挤服按钮
    // CS:Source 无需游戏运行即可挤服（isQueueReady 已包含该判断）。
    if (!state.isQueueReady || state.isLaunchingGame) {
      return SizedBox(
        height: 44,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: state.isLaunchingGame
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                )
              : Icon(MdiIcons.play, size: 18),
          label: Text(
            state.isLaunchingGame ? '等待启动...' : '开始挤',
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

    if (state.isQueueActive) {
      return SizedBox(
        height: 44,
        child: ElevatedButton.icon(
          onPressed: () {
            // pauseQueue 内部会断开 WebSocket 连接
            // 停止挤服时清空会话（活动日志、竞技场用户、位置），符合"除非停止挤服才清空"。
            session.clear();
            context.read<QueueBloc>().add(const QueuePause());
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

    if (state.isConnecting) {
      return SizedBox(
        height: 44,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white70,
            ),
          ),
          label: const Text('连接中...', style: TextStyle(fontSize: 14)),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    // 其他服务器正在操作时，禁用开始挤按钮
    if (isOtherServerBusy) {
      return SizedBox(
        height: 44,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: Icon(MdiIcons.play, size: 18),
          label: const Text('开始挤', style: TextStyle(fontSize: 14)),
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
        onPressed: state.isCheckingGame ? null : () => _startQueue(context),
        icon: state.isCheckingGame
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
          state.isCheckingGame ? '检查中...' : '开始挤',
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

  /// 开始挤服
  ///
  /// 获取用户昵称优先级：Steam 客户端 > GSI > 登录用户名 > null（匿名）
  Future<void> _startQueue(BuildContext context) async {
    // 在任何 await 之前先取出依赖，避免 BuildContext 跨异步使用
    final authState = context.read<AuthBloc>().state;
    final usersBloc = context.read<QueueUsersBloc>();
    final queueBloc = context.read<QueueBloc>();

    if (!mounted) return;

    // 开始新的挤服会话：重置持久化的活动日志、竞技场位置与自己加入标记，
    // 并开始订阅用户事件流（后台也会持续记录日志）。
    session.resetFor(widget.serverAddress);

    final isAuthenticated = authState.isAuthenticated;
    final userInfo = authState.userInfo;

    // 获取 Steam 用户名（优先级：Steam 配置 > GSI）
    final steamUsername = await _steamUserService.getCurrentUsername();

    // 最终昵称优先级：Steam 用户名 > 登录用户名 > null
    final nickname =
        steamUsername ?? (isAuthenticated ? userInfo?.username : null);
    final avatarUrl = isAuthenticated ? userInfo?.avatar : null;

    if (!mounted) return;

    // 先连接 WebSocket（如果还没连接）
    if (!usersBloc.state.isConnected) {
      usersBloc.add(QueueUsersConnect(serverAddress: widget.serverAddress));
    }

    // 构建 QueueUsersJoin 事件，包含当前用户信息
    // 后端不返回当前用户，需要在客户端把自己加入列表
    usersBloc.add(QueueUsersJoin(nickname: nickname, avatarUrl: avatarUrl));
    queueBloc.add(const QueueStart());
  }

  Widget _buildLaunchGameButton(BuildContext context, QueueBlocState state) {
    // 正在启动游戏时显示启动中状态（优先级最高）
    if (state.isLaunchingGame) {
      return SizedBox(
        height: 44,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          label: const Text('启动中...', style: TextStyle(fontSize: 14)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    // 游戏已运行时显示状态
    if (state.isGameRunning) {
      return SizedBox(
        height: 44,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(MdiIcons.checkCircle, size: 18, color: Colors.green),
              const SizedBox(width: 6),
              const Text(
                '游戏已启动',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 游戏未运行时显示启动按钮
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: () => context.read<QueueBloc>().add(const QueueLaunchGame()),
        icon: Icon(MdiIcons.gamepadVariant, size: 18),
        label: const Text('启动游戏', style: TextStyle(fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

/// 显示挤服窗口对话框
Future<void> showQueueWindow(
  BuildContext context, {
  required String serverAddress,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => QueueWindow(
      serverAddress: serverAddress,
      onClose: () => Navigator.of(context).pop(),
    ),
  );
}
