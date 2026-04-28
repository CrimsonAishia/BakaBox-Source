import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/core.dart';
import '../widgets/lobby/broadcast_dialog_mobile.dart';
import '../widgets/lobby/chat_drawer_mobile.dart';
import '../widgets/lobby/lobby_floating_actions_mobile.dart';
import '../widgets/lobby/lobby_loading_screen_mobile.dart';
import '../widgets/lobby/lobby_scene_mobile.dart';
import '../widgets/lobby/lobby_settings_sheet.dart';
import '../widgets/lobby/online_players_sheet.dart';
import '../widgets/lobby/portal_confirm_dialog_mobile.dart';
import '../../desktop/widgets/lobby/mosaic_reveal_effect.dart';
import '../../desktop/widgets/lobby/player_notification_overlay.dart';

/// 移动端大厅页面
///
/// 自行创建 [LobbyBloc]，仅在页面可见时触发 [LobbyStarted]，
/// 避免应用启动时就建立 WebSocket 连接。
class LobbyPageMobile extends StatefulWidget {
  const LobbyPageMobile({super.key});

  @override
  State<LobbyPageMobile> createState() => _LobbyPageMobileState();
}

class _LobbyPageMobileState extends State<LobbyPageMobile>
    with PageLifecycleMixin, TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late final LobbyBloc _lobbyBloc;
  bool _started = false;

  // ─── 传送动画相关 ───────────────────────────────────────
  AnimationController? _teleportController;
  Animation<double>? _teleportAnimation;
  bool _showTeleportOverlay = false;
  Timer? _teleportHideTimer;
  LobbyMapConfig? _targetMapConfig;
  bool? _lastTeleportingState;

  static const int _teleportDurationMs = 3000;
  static const int _holdDurationMs = 1500;

  // ─── transientNotice 定时消失 ────────────────────────────
  int _transientNoticeId = 0;
  Timer? _transientNoticeTimer;

  // 记录上次看到的消息数量，只有消息真正新增时才累加未读数
  int _lastSeenMessageCount = 0;

  // ─── 聊天未读消息计数 ────────────────────────────────────
  int _unreadMessageCount = 0;
  bool _isChatOpen = false;

  // ─── 权限引导 ────────────────────────────────────────────
  bool _permissionChecked = false;

  // ─── 保活通知防抖 ─────────────────────────────────────────
  Timer? _foregroundNotifyDebounce;
  String? _lastForegroundMapName;
  int? _lastForegroundOnlineCount;

  // ─── 后台恢复相关 ─────────────────────────────────────────
  /// 进入后台的时间戳（用于判断是否需要刷新数据）
  DateTime? _backgroundTimestamp;

  /// 后台超过此时间才触发完整恢复（清除气泡 + 刷新 snapshot）
  static const Duration _backgroundRecoveryThreshold = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _lobbyBloc = LobbyBloc(initialActivityText: '手机在线');

    _teleportController = AnimationController(
      duration: const Duration(milliseconds: _teleportDurationMs),
      vsync: this,
    );
    _teleportAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _teleportController!, curve: Curves.easeInOut),
    );
  }

  StreamSubscription<AuthState>? _authWaitSubscription;

  @override
  void onPageBecameActive() {
    _ensureStarted();
    // 切回大厅时重新开启屏幕常亮
    if (_started && _lobbyBloc.state.pageStatus == LobbyPageStatus.ready) {
      ScreenWakelock.enable();
      // 检查保活服务是否还在运行，掉了就重启
      if (Platform.isAndroid) {
        _restoreForegroundServiceIfNeeded();
      }
      // 从后台恢复时，判断是否需要执行完整恢复
      _checkForegroundRecovery();
    }
  }

  /// 从后台恢复时的处理：根据后台时长决定是否需要清除气泡和刷新 snapshot
  void _checkForegroundRecovery() {
    final backgroundTime = _backgroundTimestamp;
    _backgroundTimestamp = null; // 重置

    if (backgroundTime == null) return;

    final duration = DateTime.now().difference(backgroundTime);
    if (duration < _backgroundRecoveryThreshold) {
      // 后台时间较短，定时器还在正常工作，不需要额外处理
      return;
    }

    // 后台时间超过阈值，清除所有聊天气泡并刷新 snapshot
    LogService.d('[LobbyPageMobile] 后台超过 ${_backgroundRecoveryThreshold.inMinutes} 分钟，触发完整恢复');
    _lobbyBloc.add(const LobbyChatBubblesCleared());
    _lobbyBloc.add(const LobbySnapshotRefreshRequested());
  }

  @override
  void onPageBecameInactive() {
    // 切离大厅时关闭屏幕常亮
    ScreenWakelock.disable();
    // 记录进入后台的时间
    _backgroundTimestamp = DateTime.now();
  }

  void _ensureStarted() {
    if (_started) return;
    if (_lobbyBloc.state.pageStatus != LobbyPageStatus.idle) return;

    final authBloc = context.read<AuthBloc>();
    final authStatus = authBloc.state.status;

    // AuthBloc 还在初始化中（initial/loading），等它完成再启动大厅
    // 这样 AuthService.isLoggedIn 和 TokenService.isTokenValid 才是准确的
    if (authStatus == AuthStatus.initial || authStatus == AuthStatus.loading) {
      _authWaitSubscription?.cancel();
      _authWaitSubscription = authBloc.stream.listen((authState) {
        if (authState.status != AuthStatus.initial &&
            authState.status != AuthStatus.loading) {
          _authWaitSubscription?.cancel();
          _authWaitSubscription = null;
          _doStart();
        }
      });
      return;
    }

    _doStart();
  }

  void _doStart() {
    if (_started) return;
    _started = true;
    _lobbyBloc.add(const LobbyStarted());
  }

  @override
  void dispose() {
    _authWaitSubscription?.cancel();
    _teleportController?.removeStatusListener(_onTeleportAnimationStatus);
    _teleportController?.dispose();
    _teleportHideTimer?.cancel();
    _transientNoticeTimer?.cancel();
    _foregroundNotifyDebounce?.cancel();
    // 关闭屏幕常亮
    ScreenWakelock.disable();
    // 页面销毁时停止保活服务
    if (Platform.isAndroid) {
      AppPermissionService.stopForegroundService();
    }
    _lobbyBloc.close();
    super.dispose();
  }

  // ─── 权限引导逻辑 ──────────────────────────────────────

  Future<void> _checkAndShowPermissionGuide() async {
    // 开启屏幕常亮
    ScreenWakelock.enable();

    // 静默启动保活服务（用户无感知）
    if (Platform.isAndroid) {
      await AppPermissionService.startForegroundService();
      _updateForegroundNotification(_lobbyBloc.state);
    }
    // 权限已在应用启动时强制申请，此处不再弹窗
  }

  /// 回到大厅时恢复保活服务（如已停止则重启，如在运行则 restart 刷新 TaskHandler）
  Future<void> _restoreForegroundServiceIfNeeded() async {
    if (!mounted) return;
    LogService.i('[LobbyPage] 检查并恢复保活服务');
    await AppPermissionService.startForegroundService();
    // 重置防抖缓存，强制刷新通知内容
    _lastForegroundMapName = null;
    _lastForegroundOnlineCount = null;
    _updateForegroundNotification(_lobbyBloc.state);
  }

  /// 更新前台保活通知内容（防抖：内容不变则跳过，500ms 内合并多次调用）
  void _updateForegroundNotification(LobbyState state) {
    final mapName = state.mapConfig?.displayName;
    final onlineCount = state.serverOnlineCount;

    // 内容没变化，跳过
    if (mapName == _lastForegroundMapName &&
        onlineCount == _lastForegroundOnlineCount) {
      return;
    }
    _lastForegroundMapName = mapName;
    _lastForegroundOnlineCount = onlineCount;

    _foregroundNotifyDebounce?.cancel();
    _foregroundNotifyDebounce = Timer(const Duration(milliseconds: 500), () {
      AppPermissionService.updateForegroundNotification(
        mapName: mapName,
        serverOnlineCount: onlineCount,
      );
    });
  }

  // ─── 传送动画逻辑（复用桌面端） ──────────────────────────

  void _syncTeleportAnimation(LobbyState state) {
    if (_lastTeleportingState == null) {
      _lastTeleportingState = state.isTeleporting;
      if (state.isTeleporting) {
        _showTeleportOverlay = true;
        _teleportHideTimer?.cancel();
        _targetMapConfig = _findTargetMapConfig(state);
        _startTeleportAnimation();
      }
      return;
    }

    if (state.isTeleporting && !_lastTeleportingState!) {
      _showTeleportOverlay = true;
      _teleportHideTimer?.cancel();
      _targetMapConfig = _findTargetMapConfig(state);
      _startTeleportAnimation();
      _lastTeleportingState = true;
    } else if (!state.isTeleporting && _lastTeleportingState!) {
      _lastTeleportingState = false;
      _scheduleHideOverlay();
    }
  }

  void _startTeleportAnimation() {
    _teleportController?.removeStatusListener(_onTeleportAnimationStatus);
    _teleportController?.addStatusListener(_onTeleportAnimationStatus);
    _teleportController?.forward(from: 0);
  }

  void _scheduleHideOverlay() {
    _teleportHideTimer?.cancel();
    final animationValue = _teleportController?.value ?? 0.0;
    final remainingMs = ((1.0 - animationValue) * _teleportDurationMs).round();
    final delayMs = remainingMs + _holdDurationMs;

    _teleportHideTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) {
        _showTeleportOverlay = false;
        _targetMapConfig = null;
        _teleportController?.removeStatusListener(_onTeleportAnimationStatus);
        _teleportController?.reset();
        setState(() {});
      }
    });
  }

  void _onTeleportAnimationStatus(AnimationStatus status) {
    // 动画完成或重置时的回调（可扩展）
  }

  LobbyMapConfig? _findTargetMapConfig(LobbyState state) {
    if (state.teleportTarget == null) return null;
    final targetMapId = state.teleportTarget!.targetMapId;
    return state.assets.getMapById(targetMapId);
  }

  Widget _buildMosaicTargetContent(LobbyMapConfig mapConfig) {
    if (mapConfig.backgroundUrl != null &&
        mapConfig.backgroundUrl!.isNotEmpty) {
      return _MosaicMapPreviewMobile(mapConfig: mapConfig);
    }
    return _MosaicPlaceholderMobile(mapName: mapConfig.displayName);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocProvider.value(
      value: _lobbyBloc,
      child: BlocConsumer<LobbyBloc, LobbyState>(
        listenWhen: (previous, current) =>
            current.messages.length > previous.messages.length ||
            (previous.pageStatus != LobbyPageStatus.ready &&
                current.pageStatus == LobbyPageStatus.ready) ||
            previous.isTeleporting != current.isTeleporting ||
            previous.nearbyPortal != current.nearbyPortal ||
            previous.transientNotice != current.transientNotice ||
            previous.playerNotifications != current.playerNotifications ||
            previous.users.length != current.users.length ||
            previous.serverOnlineCount != current.serverOnlineCount ||
            previous.mapConfig != current.mapConfig,
        listener: (context, state) {
          // 页面进入 ready 时主动请求在线人数
          if (state.pageStatus == LobbyPageStatus.ready &&
              state.serverOnlineCount == 0) {
            _lobbyBloc.add(const LobbyOnlineStatsRequested());
          }

          // 页面进入 ready 时检查权限引导（仅 Android）
          if (state.pageStatus == LobbyPageStatus.ready &&
              !_permissionChecked) {
            _permissionChecked = true;
            _checkAndShowPermissionGuide();
          }

          // transientNotice 出现时，2秒后自动清除
          if (state.transientNotice != null) {
            _transientNoticeId++;
            final currentId = _transientNoticeId;
            _transientNoticeTimer?.cancel();
            _transientNoticeTimer = Timer(const Duration(seconds: 2), () {
              if (mounted && currentId == _transientNoticeId) {
                _lobbyBloc.add(const LobbyTransientNoticeShown());
              }
            });
          }

          // 处理传送状态变化
          setState(() {
            _syncTeleportAnimation(state);
          });

          // ─── 未读消息计数 ─────────────────────────────────────
          // 只在消息列表真正新增（count 增加）且是单条追加时才累加未读数。
          // 快照恢复 / 重连刷新会一次性替换整个 messages 列表（批量变化），
          // 此时只更新计数基线，不累加未读数。
          final currentCount = state.messages.length;
          final isNewSingleMessage =
              currentCount > 0 && currentCount == _lastSeenMessageCount + 1;
          _lastSeenMessageCount = currentCount;

          if (isNewSingleMessage) {
            // 聊天面板未打开时，累加未读消息数
            if (!_isChatOpen) {
              setState(() {
                _unreadMessageCount++;
              });
            }
            // 广播通知已在 LobbyBloc 中统一处理，这里不再重复调用
          }

          // ─── 更新前台保活通知 ─────────────────────────────────
          if (Platform.isAndroid &&
              state.pageStatus == LobbyPageStatus.ready) {
            _updateForegroundNotification(state);
          }
        },
        buildWhen: (previous, current) =>
            previous.pageStatus != current.pageStatus ||
            previous.mapConfig != current.mapConfig ||
            previous.transientNotice != current.transientNotice ||
            previous.nearbyPortal != current.nearbyPortal ||
            previous.isPortalHovered != current.isPortalHovered ||
            previous.isTeleporting != current.isTeleporting ||
            previous.serverOnlineCount != current.serverOnlineCount ||
            previous.broadcastCooldownSeconds !=
                current.broadcastCooldownSeconds ||
            previous.isAnonymous != current.isAnonymous ||
            previous.playerNotifications != current.playerNotifications ||
            previous.kickedReason != current.kickedReason,
        builder: (context, state) {
          return Scaffold(
            body: _buildBody(context, state),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, LobbyState state) {
    // 被踢出时，无论当前处于哪个加载阶段，都优先显示踢出遮罩
    // 避免在 loading 阶段被踢时永远卡在 loading 页面
    if (state.kickedReason != null) {
      return Stack(
        children: [
          // 背景（loading 或 ready 的底层内容）
          if (state.pageStatus == LobbyPageStatus.ready)
            _buildReadyView(context, state)
          else
            LobbyLoadingScreenMobile(state: state),
          // 踢出遮罩覆盖在最上层
          Positioned.fill(
            child: LobbyKickedOverlay(
              reason: state.kickedReason!,
              message: state.kickedMessage,
              onDismiss: () {
                _lobbyBloc.add(const LobbyKickedDismissed());
              },
            ),
          ),
        ],
      );
    }

    switch (state.pageStatus) {
      case LobbyPageStatus.idle:
      case LobbyPageStatus.loading:
        return LobbyLoadingScreenMobile(state: state);
      case LobbyPageStatus.error:
        return _buildErrorView(context);
      case LobbyPageStatus.ready:
        return _buildReadyView(context, state);
    }
  }

  Widget _buildReadyView(BuildContext context, LobbyState state) {
    final mapConfig = state.mapConfig;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // 地图场景（全屏）- 独立重绘边界
        Positioned.fill(
          child: mapConfig == null
              ? Container(
                  color: isDark
                      ? const Color(0xFF0B1120)
                      : const Color(0xFFDDE7F7),
                )
              : RepaintBoundary(
                  child: LobbySceneMobile(
                    mapConfig: mapConfig,
                    state: state,
                  ),
                ),
        ),
        // 状态横幅
        if (state.transientNotice != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: _buildStatusBanner(context, state),
            ),
          ),
        // 浮动按钮组（右下角）
        Positioned(
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
          child: LobbyFloatingActionsMobile(
            state: state,
            unreadMessageCount: _unreadMessageCount,
            onChatTap: () => _showChatSheet(context),
            onPlayersTap: () => _showOnlinePlayersSheet(context),
            onSettingsTap: () => _showSettingsSheet(context),
            onBroadcastTap: () => _showBroadcastDialog(context),
          ),
        ),
        // 传送动画层
        if (_showTeleportOverlay && _targetMapConfig != null)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: ListenableBuilder(
                listenable:
                    _teleportController ?? AlwaysStoppedAnimation(0.0),
                builder: (context, child) {
                  final progress = _teleportAnimation?.value ?? 0.0;
                  return MosaicRevealEffect(
                    targetContent:
                        _buildMosaicTargetContent(_targetMapConfig!),
                    targetName: _targetMapConfig!.displayName,
                    progress: progress,
                    showTouhouDecoration: true,
                  );
                },
              ),
            ),
          ),
        // 传送门高亮边框（走近传送门时）
        if (state.nearbyPortal != null && !state.isTeleporting)
          const Positioned.fill(
            child: IgnorePointer(
              child: _PortalHighlightBorder(),
            ),
          ),
        // 玩家加入/离开通知（右上角）
        if (state.playerNotifications.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: PlayerNotificationOverlay(
                notifications: state.playerNotifications,
                onNotificationExpire: (id) {
                  _lobbyBloc.add(LobbyNotificationExpired(id));
                },
              ),
            ),
          ),
        // 传送门确认对话框
        if (state.nearbyPortal != null && !state.isTeleporting)
          Positioned.fill(
            child: PortalConfirmDialogMobile(
              portal: state.nearbyPortal!,
              onConfirm: () {
                _lobbyBloc.add(
                  LobbyPortalConfirmRequested(state.nearbyPortal!.key),
                );
              },
              onCancel: () {
                _lobbyBloc.add(const LobbyPortalDialogDismissed());
              },
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBanner(BuildContext context, LobbyState state) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: state.transientNotice == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(state.transientNotice),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                state.transientNotice!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
    );
  }

  void _showChatSheet(BuildContext context) {
    setState(() {
      _isChatOpen = true;
      _unreadMessageCount = 0;
    });
    showChatBottomSheet(context, _lobbyBloc).then((_) {
      if (mounted) {
        setState(() {
          _isChatOpen = false;
        });
      }
    });
  }

  void _showOnlinePlayersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: _lobbyBloc,
        child: const OnlinePlayersSheet(),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: _lobbyBloc,
        child: const LobbySettingsSheet(),
      ),
    );
  }

  void _showBroadcastDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: _lobbyBloc,
        child: const BroadcastDialogMobile(),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 56,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(height: 16),
          const Text(
            '加载失败，请重试',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              _lobbyBloc.add(const LobbyStarted());
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

// ─── 传送动画辅助组件 ──────────────────────────────────────

/// 移动端地图预览（传送动画用）
class _MosaicMapPreviewMobile extends StatefulWidget {
  final LobbyMapConfig mapConfig;
  const _MosaicMapPreviewMobile({required this.mapConfig});

  @override
  State<_MosaicMapPreviewMobile> createState() =>
      _MosaicMapPreviewMobileState();
}

class _MosaicMapPreviewMobileState extends State<_MosaicMapPreviewMobile> {
  bool _imageLoaded = false;
  bool _hasError = false;
  Uint8List? _cachedImageBytes;

  @override
  void initState() {
    super.initState();
    _loadFromCache();
  }

  @override
  void didUpdateWidget(_MosaicMapPreviewMobile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapConfig.backgroundUrl != widget.mapConfig.backgroundUrl) {
      _imageLoaded = false;
      _hasError = false;
      _cachedImageBytes = null;
      _loadFromCache();
    }
  }

  Future<void> _loadFromCache() async {
    if (widget.mapConfig.backgroundUrl == null ||
        widget.mapConfig.backgroundUrl!.isEmpty) {
      return;
    }
    try {
      final bytes = await LobbyImageCacheService.instance.getImage(
        widget.mapConfig.backgroundUrl!,
      );
      if (bytes != null && mounted) {
        setState(() {
          _cachedImageBytes = bytes;
          _imageLoaded = true;
        });
      } else if (mounted) {
        setState(() => _hasError = true);
      }
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || !_imageLoaded || _cachedImageBytes == null) {
      return _MosaicPlaceholderMobile(
          mapName: widget.mapConfig.displayName);
    }
    return Image.memory(
      _cachedImageBytes!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _MosaicPlaceholderMobile(
          mapName: widget.mapConfig.displayName),
    );
  }
}

/// 占位背景（无地图背景URL时）
class _MosaicPlaceholderMobile extends StatelessWidget {
  final String mapName;
  const _MosaicPlaceholderMobile({required this.mapName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1F2E), Color(0xFF0F1624)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map, size: 64,
                color: Colors.cyan.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              mapName,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 传送门高亮边框 ────────────────────────────────────────

/// 走近传送门时屏幕四周的脉冲高亮边框
class _PortalHighlightBorder extends StatefulWidget {
  const _PortalHighlightBorder();

  @override
  State<_PortalHighlightBorder> createState() => _PortalHighlightBorderState();
}

class _PortalHighlightBorderState extends State<_PortalHighlightBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        return CustomPaint(
          painter: _PortalBorderPainter(opacity: _pulseAnimation.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _PortalBorderPainter extends CustomPainter {
  final double opacity;
  _PortalBorderPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    const borderWidth = 6.0;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 外发光
    final glowPaint = Paint()
      ..color = Colors.purpleAccent.withValues(alpha: opacity * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth * 4;
    canvas.drawRect(rect.deflate(borderWidth * 2), glowPaint);

    // 主边框渐变
    final borderPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.purpleAccent.withValues(alpha: opacity),
          Colors.cyanAccent.withValues(alpha: opacity * 0.8),
          Colors.purpleAccent.withValues(alpha: opacity),
        ],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRect(rect.deflate(borderWidth / 2), borderPaint);
  }

  @override
  bool shouldRepaint(_PortalBorderPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
