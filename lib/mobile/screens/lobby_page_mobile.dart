import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
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
    with PageLifecycleMixin, TickerProviderStateMixin, AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
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

  /// 传送动画开始时间（用于保证最小动画时长）
  DateTime? _teleportStartTime;

  /// 整体最短传送时长（毫秒）：从动画开始到 overlay 完全消失
  /// = _minTeleportDurationMs + _phase2DurationMs + _holdDurationMs
  static const int _minTeleportDurationMs = 700;

  /// 阶段1动画时长（等待传送完成时，缓慢推进到 70%）
  static const int _phase1DurationMs = 900;

  /// 阶段2动画时长（传送完成后，快速推进到 100%）
  static const int _phase2DurationMs = 200;

  /// 阶段1目标进度（等待传送完成时最多推进到此值）
  static const double _phase1TargetProgress = 0.7;

  /// 动画完成后额外显示时长（毫秒）
  static const int _holdDurationMs = 100;

  /// 等待最小动画时间的定时器
  Timer? _minDurationTimer;

  /// 标记传送数据是否已就绪（等待最小动画时间后再进入阶段2）
  bool _teleportDataReady = false;

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
    WidgetsBinding.instance.addObserver(this);
    _lobbyBloc = LobbyBloc(initialActivityText: '手机在线');

    _teleportController = AnimationController(
      duration: const Duration(milliseconds: _phase1DurationMs),
      vsync: this,
    );
    _teleportAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _teleportController!, curve: Curves.easeInOut),
    );
  }

  StreamSubscription<AuthState>? _authWaitSubscription;

  @override
  void onPageBecameActive() {
    // 已经连接过的情况下，切回大厅时恢复状态
    if (_started && _lobbyBloc.state.pageStatus == LobbyPageStatus.ready) {
      // 检查登录状态是否与大厅数据一致
      if (!AuthService.instance.isLoggedIn && !_lobbyBloc.state.isAnonymous) {
        // 用户已登出但大厅仍显示登录身份，需要刷新
        LogService.i('[LobbyPageMobile] 检测到用户登出，刷新大厅数据');
        _lobbyBloc.add(const LobbyStarted());
        return;
      }
      ScreenWakelock.enable();
      // 检查保活服务是否还在运行，掉了就重启
      if (Platform.isAndroid) {
        _restoreForegroundServiceIfNeeded();
      }
      // 从后台恢复时，判断是否需要执行完整恢复
      _checkForegroundRecovery();
    }
    // 首次进入时不自动连接，等用户手动点击"加入大厅"按钮
  }

  /// 从后台恢复时的处理：根据后台时长决定是否需要刷新 snapshot
  void _checkForegroundRecovery() {
    final backgroundTime = _backgroundTimestamp;
    _backgroundTimestamp = null; // 重置

    if (backgroundTime == null) return;

    final duration = DateTime.now().difference(backgroundTime);

    // 排队中：无论后台多久都立即确认状态（ticket 30 秒未轮询会过期）
    if (_lobbyBloc.state.isQueueing) {
      LogService.d('[LobbyPageMobile] 从后台恢复，排队中，立即确认排队状态');
      _lobbyBloc.add(const LobbyAppResumed());
      return;
    }

    if (duration < _backgroundRecoveryThreshold) {
      // 后台时间较短，不需要刷新 snapshot
      return;
    }

    // 后台时间超过阈值，刷新 snapshot 确保数据最新
    LogService.d('[LobbyPageMobile] 后台超过 ${_backgroundRecoveryThreshold.inMinutes} 分钟，刷新 snapshot');
    _lobbyBloc.add(const LobbyAppResumed());
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
    WidgetsBinding.instance.removeObserver(this);
    _authWaitSubscription?.cancel();
    _teleportController?.removeStatusListener(_onTeleportAnimationStatus);
    _teleportController?.dispose();
    _teleportHideTimer?.cancel();
    _minDurationTimer?.cancel();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // 从后台恢复时，立即清除所有聊天气泡
      // 避免后台期间收到的消息导致气泡卡住不消失
      if (_started && _lobbyBloc.state.pageStatus == LobbyPageStatus.ready) {
        _lobbyBloc.add(const LobbyChatBubblesCleared());
      }
    } else if (state == AppLifecycleState.paused) {
      // 记录进入后台的时间
      _backgroundTimestamp = DateTime.now();
    }
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

  // ─── 传送动画逻辑（复用桌面端两阶段动画） ──────────────────────────

  void _syncTeleportAnimation(LobbyState state) {
    if (_lastTeleportingState == null) {
      _lastTeleportingState = state.isTeleporting;
      if (state.isTeleporting) {
        _showTeleportOverlay = true;
        _teleportHideTimer?.cancel();
        _minDurationTimer?.cancel();
        _teleportDataReady = false;
        _targetMapConfig = _findTargetMapConfig(state);
        _startTeleportAnimation();
      }
      return;
    }

    if (state.isTeleporting && !_lastTeleportingState!) {
      // 开始传送 — 立即显示动画（阶段1：缓慢推进到 70%）
      _showTeleportOverlay = true;
      _teleportHideTimer?.cancel();
      _minDurationTimer?.cancel();
      _teleportDataReady = false;
      _targetMapConfig = _findTargetMapConfig(state);
      _startTeleportAnimation();
      _lastTeleportingState = true;
    } else if (!state.isTeleporting && _lastTeleportingState!) {
      _lastTeleportingState = false;
      _onTeleportDataReady();
    }
  }

  /// 启动传送动画（阶段1：缓慢推进到 70%）
  void _startTeleportAnimation() {
    _teleportStartTime = DateTime.now();
    _teleportDataReady = false;

    // animateTo 的实际时间 = duration * (target - current) / range
    // 要让实际时间 = _phase1DurationMs，需要 duration = _phase1DurationMs / 0.7
    _teleportController?.removeStatusListener(_onTeleportAnimationStatus);
    _teleportController?.duration = Duration(
      milliseconds: (_phase1DurationMs / _phase1TargetProgress).round(),
    );
    _teleportController?.addStatusListener(_onTeleportAnimationStatus);
    _teleportController?.value = 0;
    _teleportController?.animateTo(_phase1TargetProgress);
  }

  /// 传送数据就绪时调用
  void _onTeleportDataReady() {
    final startTime = _teleportStartTime;
    if (startTime == null) {
      _startPhase2();
      return;
    }

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    final remaining = _minTeleportDurationMs - elapsed;

    if (remaining <= 0) {
      _startPhase2();
    } else {
      _teleportDataReady = true;
      _minDurationTimer?.cancel();
      _minDurationTimer = Timer(Duration(milliseconds: remaining), () {
        if (mounted && _teleportDataReady) {
          _startPhase2();
        }
      });
    }
  }

  /// 启动阶段2动画（快速推进到 100%）
  void _startPhase2() {
    _teleportDataReady = false;
    _minDurationTimer?.cancel();

    // animateTo 的实际时间 = duration * (target - current) / range
    // 要让实际时间 = _phase2DurationMs，需要 duration = _phase2DurationMs / (1.0 - current)
    final currentValue = _teleportController?.value ?? 0.0;
    final remaining = 1.0 - currentValue;
    if (remaining <= 0) {
      _scheduleHideOverlay();
      return;
    }
    _teleportController?.duration = Duration(
      milliseconds: (_phase2DurationMs / remaining).round(),
    );
    _teleportController?.animateTo(1.0);
  }

  void _scheduleHideOverlay() {
    _teleportHideTimer?.cancel();

    _teleportHideTimer = Timer(Duration(milliseconds: _holdDurationMs), () {
      if (mounted) {
        _showTeleportOverlay = false;
        _targetMapConfig = null;
        _teleportController?.removeStatusListener(_onTeleportAnimationStatus);
        _teleportController?.reset();
        _teleportStartTime = null;
        setState(() {});
      }
    });
  }

  void _onTeleportAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      final value = _teleportController?.value ?? 0.0;
      if (value >= 1.0) {
        // 阶段2完成（进度到达 100%），调度隐藏
        _scheduleHideOverlay();
      } else {
        // 阶段1完成（停在 70%），等待传送数据就绪
        if (_teleportDataReady) {
          _startPhase2();
        }
      }
    }
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
            previous.transientNoticeSeq != current.transientNoticeSeq ||
            previous.playerNotifications != current.playerNotifications ||
            previous.users.length != current.users.length ||
            previous.serverOnlineCount != current.serverOnlineCount ||
            previous.mapConfig != current.mapConfig ||
            previous.queueTicket != current.queueTicket ||
            previous.pageStatus != current.pageStatus,
        listener: (context, state) {
          // 页面重新进入 loading 时重置传送动画状态（防止重连后状态残留）
          if (state.pageStatus == LobbyPageStatus.loading) {
            _lastTeleportingState = null;
            _showTeleportOverlay = false;
            _targetMapConfig = null;
            _teleportHideTimer?.cancel();
            _minDurationTimer?.cancel();
            _teleportDataReady = false;
            _teleportStartTime = null;
            _teleportController?.reset();
          }

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
            previous.anonymousSwitchCooldownSeconds !=
                current.anonymousSwitchCooldownSeconds ||
            previous.steamNameSwitchCooldownSeconds !=
                current.steamNameSwitchCooldownSeconds ||
            previous.playerNotifications != current.playerNotifications ||
            previous.kickedReason != current.kickedReason ||
            previous.queueTicket != current.queueTicket ||
            previous.queuePosition != current.queuePosition ||
            previous.queueTotal != current.queueTotal ||
            previous.queueEtaSeconds != current.queueEtaSeconds,
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
        return _buildIdleView(context);
      case LobbyPageStatus.loading:
        // 排队中显示排队界面
        if (state.isQueueing) {
          return _LobbyQueueScreenMobile(
            state: state,
            onCancel: _cancelQueueAndReset,
          );
        }
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

  /// 移动端取消排队：通知服务端取消，然后重建 Bloc 回到 idle 状态
  void _cancelQueueAndReset() {
    // 直接调用 service 取消排队（不经过 Bloc 的 LobbyQueueCancelled，因为它会自动重连）
    final service = LobbyNakamaService.instance;
    final ticket = _lobbyBloc.state.queueTicket ?? '';
    // 先关闭 Bloc 停止轮询，再通知服务端取消（fire-and-forget）
    _lobbyBloc.close();
    if (ticket.isNotEmpty) {
      unawaited(service.rpcQueueCancel(ticket));
    }

    // 重建 Bloc，回到 idle 状态
    setState(() {
      _started = false;
      _lobbyBloc = LobbyBloc(initialActivityText: '手机在线');
    });
  }

  Widget _buildIdleView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF475569);

    return Container(
      color: isDark ? const Color(0xFF0B1120) : const Color(0xFFDDE7F7),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.castle,
                  size: 64,
                  color: textSecondary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 20),
                Text(
                  '大厅',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '与其他玩家实时互动、聊天、传送',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 180,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _ensureStarted,
                    icon: const Icon(Icons.login, size: 20),
                    label: const Text('加入大厅'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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

// ─── 排队等待界面（移动端） ──────────────────────────────────────

/// 移动端排队等待界面
class _LobbyQueueScreenMobile extends StatefulWidget {
  final LobbyState state;
  final VoidCallback? onCancel;

  const _LobbyQueueScreenMobile({required this.state, this.onCancel});

  @override
  State<_LobbyQueueScreenMobile> createState() =>
      _LobbyQueueScreenMobileState();
}

class _LobbyQueueScreenMobileState extends State<_LobbyQueueScreenMobile>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rotateController;
  late final AnimationController _progressGlowController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _rotateAnimation;
  late final Animation<double> _progressGlowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _rotateAnimation = Tween<double>(begin: 0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    _progressGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _progressGlowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(
          parent: _progressGlowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _progressGlowController.dispose();
    super.dispose();
  }

  String _formatEta(int seconds) {
    if (seconds <= 0) return '计算中...';
    if (seconds < 60) return '$seconds 秒';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) return '$minutes 分钟';
    return '$minutes 分 $remainingSeconds 秒';
  }

  double _calculateProgress() {
    final position = widget.state.queuePosition;
    final total = widget.state.queueTotal;
    if (total <= 0 || position <= 0) return 0.0;
    // position=1 表示下一个就是自己，显示较高进度
    if (position == 1) return 0.9;
    return ((total - position) / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF475569);
    final accentColor = const Color(0xFF38BDF8);
    final successColor = const Color(0xFF22C55E);

    final position = widget.state.queuePosition;
    final total = widget.state.queueTotal;
    final eta = widget.state.queueEtaSeconds;
    final progress = _calculateProgress();

    return Container(
      color: isDark ? const Color(0xFF0B1120) : const Color(0xFFDDE7F7),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题（带脉冲动画）
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: 0.7 + 0.3 * _pulseAnimation.value,
                      child: child,
                    );
                  },
                  child: Text(
                    '正在排队',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 中心圆环动画
                AnimatedBuilder(
                  animation: Listenable.merge(
                      [_pulseAnimation, _rotateAnimation]),
                  builder: (context, child) {
                    return SizedBox(
                      width: 90,
                      height: 90,
                      child: CustomPaint(
                        painter: _QueueRingPainterMobile(
                          progress: progress,
                          rotation: _rotateAnimation.value * 6.28,
                          pulse: _pulseAnimation.value,
                          ringBgColor: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : const Color(0xFFCBD5E1),
                          accentColor: accentColor,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(position - 1).clamp(0, total)}',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '人排队',
                                style: TextStyle(
                                  color:
                                      textSecondary.withValues(alpha: 0.7),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 预计等待时间
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.schedule,
                      color: textSecondary.withValues(alpha: 0.6),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '预计等待 ${_formatEta(eta)}',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 进度条（带发光动画）
                AnimatedBuilder(
                  animation: _progressGlowAnimation,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: progress > 0
                            ? [
                                BoxShadow(
                                  color: accentColor.withValues(
                                    alpha: 0.15 *
                                        _progressGlowAnimation.value,
                                  ),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 10,
                          child: Stack(
                            children: [
                              // 背景
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white
                                          .withValues(alpha: 0.06)
                                      : const Color(0xFFCBD5E1)
                                          .withValues(alpha: 0.5),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                              ),
                              // 进度
                              FractionallySizedBox(
                                widthFactor: progress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        accentColor,
                                        successColor,
                                      ],
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 进度信息行
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '第 $position / $total 位',
                      style: TextStyle(
                        color: textSecondary.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 连接状态指示
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: successColor,
                        boxShadow: [
                          BoxShadow(
                            color:
                                successColor.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '连接正常 · 排队中',
                      style: TextStyle(
                        color: textSecondary.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 取消排队按钮
                SizedBox(
                  width: 140,
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textSecondary,
                      side: BorderSide(
                        color: textSecondary.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      '取消排队',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 移动端排队界面的圆环画笔
class _QueueRingPainterMobile extends CustomPainter {
  final double progress;
  final double rotation;
  final double pulse;
  final Color ringBgColor;
  final Color accentColor;

  _QueueRingPainterMobile({
    required this.progress,
    required this.rotation,
    required this.pulse,
    required this.ringBgColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // 脉冲外环
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.12 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius + 5 + pulse * 3, glowPaint);

    // 背景圆环
    final bgPaint = Paint()
      ..color = ringBgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, bgPaint);

    // 进度弧线
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -1.57,
          endAngle: 4.71,
          colors: [
            accentColor,
            const Color(0xFF22C55E),
            accentColor.withValues(alpha: 0.1),
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.57,
        progress * 6.28,
        false,
        progressPaint,
      );
    }

    // 旋转装饰点（4个点围绕圆环旋转）
    final dotPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.6 * pulse)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final angle = rotation + (i * 1.57); // 每 90 度一个点
      final x = center.dx + (radius + 2) * math.cos(angle);
      final y = center.dy + (radius + 2) * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 2 * pulse, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _QueueRingPainterMobile oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rotation != rotation ||
        oldDelegate.pulse != pulse;
  }
}
