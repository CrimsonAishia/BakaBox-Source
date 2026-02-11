import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/bloc/queue/queue_bloc.dart';
import '../../../core/bloc/queue/queue_event.dart';
import '../../../core/bloc/queue/queue_state.dart';
import '../../../core/services/status_window_service.dart';
import '../../../core/utils/map_utils.dart';
import '../../../core/utils/player_count_utils.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../core/widgets/map_background.dart';
import '../../../core/widgets/csgo_manual_launch_dialog.dart';
import 'queue_settings.dart';

/// 挤服窗口
class QueueWindow extends StatefulWidget {
  final String serverAddress;
  final bool isCustomServer; // 是否为自定义服务器
  final VoidCallback? onClose;

  const QueueWindow({
    super.key,
    required this.serverAddress,
    this.isCustomServer = false,
    this.onClose,
  });

  @override
  State<QueueWindow> createState() => _QueueWindowState();
}

class _QueueWindowState extends State<QueueWindow> {
  late final QueueBloc _queueBloc;

  @override
  void initState() {
    super.initState();
    _queueBloc = QueueBloc()..add(QueueInitialize(widget.serverAddress, isCustomServer: widget.isCustomServer));
  }

  @override
  void dispose() {
    // 确保 Bloc 被正确关闭，释放 Timer 和 StreamSubscription
    _queueBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _queueBloc,
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

  const _QueueWindowContent({
    required this.serverAddress,
    this.onClose,
  });

  @override
  State<_QueueWindowContent> createState() => _QueueWindowContentState();
}

class _QueueWindowContentState extends State<_QueueWindowContent> {
  // 上一次处理的连接状态，用于防止重复 Toast
  QueueConnectionState? _lastToastConnectionState;
  
  // 监听全局操作状态
  final StatusWindowService _statusService = StatusWindowService();
  StreamSubscription<OperationState>? _stateSubscription;

  @override
  void initState() {
    super.initState();
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
    // 页面关闭不影响服务继续运行
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
        constraints: const BoxConstraints(maxHeight: 580),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: BlocListener<QueueBloc, QueueBlocState>(
          listenWhen: (previous, current) {
            // needManualLaunch 优先级最高，单独处理
            if (!previous.needManualLaunch && current.needManualLaunch) return true;
            
            // 如果 needManualLaunch 为 true，不处理其他状态变化（避免重复提示）
            if (current.needManualLaunch) return false;
            
            // 挤服开始时自动关闭对话框
            if (!previous.isQueueActive && current.isQueueActive) return true;
            
            // 其他状态变化
            if (previous.error != current.error && current.error != null) return true;
            if (previous.connectionState != current.connectionState) return true;
            
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
            
            // 挤服开始时自动关闭对话框，让悬浮卡片显示
            if (state.isQueueActive) {
              // 延迟一点关闭，让用户看到挤服已开始
              Future.delayed(const Duration(milliseconds: 300), () {
                if (context.mounted) {
                  context.read<QueueBloc>().add(const QueueDispose());
                  widget.onClose?.call();
                }
              });
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
              ToastUtils.showSuccess(context, '进去啦！');
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
    final mapName = serverInfo?.map ?? '未知地图';
    final mapUrl = state.mapInfo?.mapUrl;
    
    final players = serverInfo?.players ?? 0;
    final maxPlayers = serverInfo?.maxPlayers ?? 0;
    final playerColor = PlayerCountUtils.getPlayerCountColor(players, maxPlayers);

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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                    Icon(MdiIcons.accountMultiplePlus, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      '挤服',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // 玩家数量标签
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: playerColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(MdiIcons.accountGroup, size: 14, color: Colors.white),
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
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // 服务器名称
                Text(
                  serverInfo?.hostName ?? '加载中...',
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
  Widget _buildContent(BuildContext context, QueueBlocState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 设置面板（始终显示）
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
            mapName: state.serverInfo?.map,
            isCustomServer: state.isCustomServer,
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
          ),
          const SizedBox(height: 16),
          // 操作按钮
          _buildActionButtons(context, state),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, QueueBlocState state) {
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
    final isGlobalBusy = globalState.type != OperationType.none && 
        globalState.status == OperationStatus.running;
    final isOtherServerBusy = globalState.serverAddress != widget.serverAddress && isGlobalBusy;

    // 游戏未运行或正在启动时，禁用挤服按钮
    if (!state.isGameRunning || state.isLaunchingGame) {
      return SizedBox(
        height: 44,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: state.isLaunchingGame
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                )
              : Icon(MdiIcons.play, size: 18),
          label: Text(
            state.isLaunchingGame ? '等待启动...' : '开始挤',
            style: const TextStyle(fontSize: 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }

    if (state.isQueueActive) {
      return SizedBox(
        height: 44,
        child: ElevatedButton.icon(
          onPressed: () => context.read<QueueBloc>().add(const QueuePause()),
          icon: Icon(MdiIcons.pause, size: 18),
          label: const Text('暂停', style: TextStyle(fontSize: 14)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
          ),
          label: const Text('连接中...', style: TextStyle(fontSize: 14)),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: state.isCheckingGame ? null : () => context.read<QueueBloc>().add(const QueueStart()),
        icon: state.isCheckingGame
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(MdiIcons.play, size: 18),
        label: Text(state.isCheckingGame ? '检查中...' : '开始挤', style: const TextStyle(fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildLaunchGameButton(BuildContext context, QueueBlocState state) {
    // 正在启动游戏时显示启动中状态（优先级最高）
    if (state.isLaunchingGame) {
      return SizedBox(
        height: 44,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          label: const Text('启动中...', style: TextStyle(fontSize: 14)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              const Text('游戏已启动', style: TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.w500)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

/// 显示挤服窗口对话框
Future<void> showQueueWindow(BuildContext context, {required String serverAddress}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => QueueWindow(
      serverAddress: serverAddress,
      onClose: () => Navigator.of(context).pop(),
    ),
  );
}
