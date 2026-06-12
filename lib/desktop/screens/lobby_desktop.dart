import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/core.dart';
import '../../core/widgets/marquee_text.dart';
import '../games/lobby_game.dart';
import '../widgets/lobby/lobby_loading_screen.dart';
import '../widgets/lobby/lobby_scene.dart';
import '../widgets/lobby/lobby_chat_overlay.dart';
import '../widgets/lobby/lobby_floating_actions.dart';
import '../widgets/lobby/lobby_settings_panel.dart';
import '../widgets/lobby/lobby_helper.dart';
import '../widgets/lobby/lobby_broadcast_dialog.dart';
import '../widgets/lobby/mosaic_reveal_effect.dart';
import '../widgets/lobby/portal_confirm_dialog.dart';
import '../widgets/lobby/player_notification_overlay.dart';
import '../widgets/lobby/lobby_user_profile_panel.dart';

class LobbyDesktop extends StatefulWidget {
  const LobbyDesktop({super.key});

  @override
  State<LobbyDesktop> createState() => _LobbyDesktopState();
}

class _LobbyDesktopState extends State<LobbyDesktop>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _chatController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();
  final FocusNode _sceneFocusNode = FocusNode();
  bool _started = false;
  Timer? _transientNoticeTimer;

  /// 传送动画控制器
  AnimationController? _teleportController;
  Animation<double>? _teleportAnimation;

  /// 玩家抽屉滑出动画控制器
  late final AnimationController _playersDrawerController;
  late final Animation<Offset> _playersDrawerSlideAnimation;
  late final Animation<double> _playersDrawerFadeAnimation;

  /// 是否显示传送动画（延迟消失）
  bool _showTeleportOverlay = false;
  Timer? _teleportHideTimer;

  /// 目标地图配置
  LobbyMapConfig? _targetMapConfig;

  /// 是否处于"聚焦"模式（玩家抽屉右键弹出菜单时）
  /// 用于临时隐藏聊天栏，避免遮挡聚光灯下的目标角色
  bool _isPlayerFocused = false;

  @override
  void initState() {
    super.initState();
    // 注册生命周期监听器，用于处理页面切换
    WidgetsBinding.instance.addObserver(this);

    _teleportController = AnimationController(
      duration: const Duration(milliseconds: _phase1DurationMs),
      vsync: this,
    );
    _teleportAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _teleportController!, curve: Curves.easeInOut),
    );

    _playersDrawerController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _playersDrawerSlideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _playersDrawerController,
            curve: Curves.easeOutCubic,
          ),
        );
    _playersDrawerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _playersDrawerController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bloc = context.read<LobbyBloc>();

    // 检查是否需要刷新大厅数据
    if (bloc.state.pageStatus == LobbyPageStatus.ready) {
      // 如果当前是 ready 状态，检查登录状态是否与大厅数据一致
      if (!AuthService.instance.isLoggedIn && !bloc.state.isAnonymous) {
        // 用户已登出但大厅仍显示登录身份，需要刷新
        LogService.i('[LobbyDesktop] 检测到用户登出，刷新大厅数据');
        _started = true; // 防止重复触发
        bloc.add(const LobbyStarted());
        return;
      }
    }

    if (_started) {
      // 页面重新激活时，确保焦点在场景上
      // 仅在应用处于前台（resumed 且窗口已聚焦）时才恢复焦点，避免窗口失焦时抢焦点
      final appState = WidgetsBinding.instance.lifecycleState;
      if (appState == AppLifecycleState.resumed) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (mounted && bloc.state.pageStatus == LobbyPageStatus.ready) {
            await _requestSceneFocusIfWindowActive();
          }
        });
      }
      return;
    }

    // 检查 Bloc 是否已经在处理中，避免热重载时重复初始化
    if (bloc.state.pageStatus != LobbyPageStatus.idle) {
      return;
    }

    _started = true;
    bloc.add(const LobbyStarted());
  }

  @override
  void deactivate() {
    // 页面离开时关闭面板和聊天，避免返回时按钮仍显示选中状态
    final bloc = context.read<LobbyBloc>();
    if (bloc.state.isPlayersPanelOpen ||
        bloc.state.isSettingsPanelOpen ||
        bloc.state.isChatActive) {
      bloc.add(const LobbyPanelsDismissed());
    }
    // 广播弹窗单独关闭
    if (bloc.state.isBroadcastDialogOpen) {
      bloc.add(const LobbyBroadcastDialogToggled());
    }
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatController.dispose();
    _chatFocusNode.dispose();
    _sceneFocusNode.dispose();
    _teleportController?.removeStatusListener(_onTeleportAnimationStatus);
    _teleportController?.dispose();
    _playersDrawerController.dispose();
    _transientNoticeTimer?.cancel();
    _teleportHideTimer?.cancel();
    _minDurationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 监听应用生命周期变化，确保页面切换回来时能正确恢复焦点
    if (state == AppLifecycleState.resumed) {
      // 页面重新可见时，延迟请求场景焦点
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sceneFocusNode.context != null) {
          _sceneFocusNode.requestFocus();
        }
      });

      // 从后台恢复时，检查排队状态或对齐 snapshot
      if (_started && mounted) {
        context.read<LobbyBloc>().add(const LobbyAppResumed());
      }
    }
  }

  /// 安全请求场景焦点
  ///
  /// 仅当主窗口处于前台时才调用 `_sceneFocusNode.requestFocus()`，
  /// 避免在用户已经把焦点切到其它应用（例如游戏中的 CS2）时把
  /// Flutter 主窗口强行拉到前台抢占焦点。
  Future<void> _requestSceneFocusIfWindowActive() async {
    if (!mounted) return;
    try {
      final isFocused = await windowManager.isFocused();
      if (!mounted || !isFocused) return;
      _sceneFocusNode.requestFocus();
    } catch (_) {
      // windowManager 异常时保守处理：不抢占焦点
    }
  }

  /// 上一次检测到的传送状态
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

  /// 同步传送动画状态
  void _syncTeleportAnimation(LobbyState state) {
    // 检测 isTeleporting 状态变化
    if (_lastTeleportingState == null) {
      // 首次检测，根据当前状态初始化
      _lastTeleportingState = state.isTeleporting;
      if (state.isTeleporting) {
        LogService.d('[LobbyDesktop] _syncTeleportAnimation: 首次检测到传送中，启动动画');
        _showTeleportOverlay = true;
        _teleportHideTimer?.cancel();
        _targetMapConfig = _findTargetMapConfig(state);
        _startTeleportAnimation();
      }
      return;
    }

    if (state.isTeleporting && !_lastTeleportingState!) {
      // 开始传送 — 立即显示动画（阶段1：缓慢推进到 70%）
      LogService.d('[LobbyDesktop] _syncTeleportAnimation: 检测到传送开始，启动动画');
      _showTeleportOverlay = true;
      _teleportHideTimer?.cancel();
      _minDurationTimer?.cancel();
      _teleportDataReady = false;
      _targetMapConfig = _findTargetMapConfig(state);
      _startTeleportAnimation();
      _lastTeleportingState = true;
    } else if (!state.isTeleporting && _lastTeleportingState!) {
      // 传送数据就绪（正常完成）或传送被取消/拒绝
      // 统一走 _onTeleportDataReady()：满足最小时间后快速完成动画再隐藏
      LogService.d('[LobbyDesktop] _syncTeleportAnimation: 检测到传送结束');
      _lastTeleportingState = false;
      _onTeleportDataReady();
    }
  }

  /// 启动传送动画（阶段1：缓慢推进到 70%）
  void _startTeleportAnimation() {
    LogService.d(
      '[LobbyDesktop] _startTeleportAnimation: 开始阶段1动画, controller=$_teleportController',
    );
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
    LogService.d(
      '[LobbyDesktop] _startTeleportAnimation: 阶段1开始，目标 ${(_phase1TargetProgress * 100).toInt()}%',
    );
  }

  /// 传送数据就绪时调用
  void _onTeleportDataReady() {
    final startTime = _teleportStartTime;
    if (startTime == null) {
      // 异常情况：没有开始时间，直接完成
      _startPhase2();
      return;
    }

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    final remaining = _minTeleportDurationMs - elapsed;

    if (remaining <= 0) {
      // 已满足最小动画时间，立即进入阶段2
      LogService.d(
        '[LobbyDesktop] _onTeleportDataReady: 已满足最小时间(${elapsed}ms)，进入阶段2',
      );
      _startPhase2();
    } else {
      // 未满足最小动画时间，等待剩余时间后再进入阶段2
      LogService.d(
        '[LobbyDesktop] _onTeleportDataReady: 未满足最小时间(${elapsed}ms)，等待${remaining}ms',
      );
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
    LogService.d(
      '[LobbyDesktop] _startPhase2: 从 ${_teleportController?.value ?? 0} 快速推进到 100%',
    );
    _teleportDataReady = false;
    _minDurationTimer?.cancel();

    // animateTo 的实际时间 = duration * (target - current) / range
    // 要让实际时间 = _phase2DurationMs，需要 duration = _phase2DurationMs / (1.0 - current)
    final currentValue = _teleportController?.value ?? 0.0;
    final remaining = 1.0 - currentValue;
    if (remaining <= 0) {
      // 已经到达或超过 1.0，直接触发完成
      _scheduleHideOverlay();
      return;
    }
    _teleportController?.duration = Duration(
      milliseconds: (_phase2DurationMs / remaining).round(),
    );
    _teleportController?.animateTo(1.0);
  }

  /// 调度隐藏覆盖层（在动画完成后延迟）
  void _scheduleHideOverlay() {
    _teleportHideTimer?.cancel();

    LogService.d('[LobbyDesktop] 计划 ${_holdDurationMs}ms 后隐藏覆盖层');

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

  /// 动画状态监听
  void _onTeleportAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      final value = _teleportController?.value ?? 0.0;
      if (value >= 1.0) {
        // 阶段2完成（进度到达 100%），调度隐藏
        LogService.d('[LobbyDesktop] 传送动画播放完成（100%），调度隐藏');
        _scheduleHideOverlay();
      } else {
        // 阶段1完成（停在 70%），等待传送数据就绪
        LogService.d(
          '[LobbyDesktop] 阶段1动画完成（${(value * 100).toInt()}%），等待传送数据',
        );
        // 如果数据已经就绪（在阶段1动画期间到达），立即进入阶段2
        if (_teleportDataReady) {
          _startPhase2();
        }
      }
    } else if (status == AnimationStatus.dismissed) {
      // 动画被重置
    }
  }

  /// 查找目标地图配置
  LobbyMapConfig? _findTargetMapConfig(LobbyState state) {
    if (state.teleportTarget == null) return null;
    final targetMapId = state.teleportTarget!.targetMapId;
    // 从 assets.maps 中查找
    return state.assets.getMapById(targetMapId);
  }

  /// 构建马赛克效果中的目标地图内容预览
  Widget _buildMosaicTargetContent(LobbyMapConfig mapConfig) {
    // 如果地图有背景URL，使用预览组件
    if (mapConfig.backgroundUrl != null &&
        mapConfig.backgroundUrl!.isNotEmpty) {
      return _MosaicMapPreview(mapConfig: mapConfig);
    }
    // 否则显示占位背景
    return _MosaicPlaceholderBackground(mapName: mapConfig.displayName);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LobbyBloc, LobbyState>(
      buildWhen: (previous, current) =>
          previous.chatCooldownSeconds != current.chatCooldownSeconds ||
          previous.isChatActive != current.isChatActive ||
          previous.pageStatus != current.pageStatus ||
          previous.mapConfig != current.mapConfig ||
          previous.users != current.users ||
          previous.messages != current.messages ||
          previous.connectionStatus != current.connectionStatus ||
          previous.isPlayersPanelOpen != current.isPlayersPanelOpen ||
          previous.isSettingsPanelOpen != current.isSettingsPanelOpen ||
          previous.isBroadcastDialogOpen != current.isBroadcastDialogOpen ||
          previous.nearbyPortal != current.nearbyPortal ||
          previous.isTeleporting != current.isTeleporting ||
          previous.playerNotifications != current.playerNotifications ||
          previous.transientNotice != current.transientNotice ||
          previous.kickedReason != current.kickedReason ||
          previous.serverOnlineCount != current.serverOnlineCount ||
          previous.broadcastCooldownSeconds !=
              current.broadcastCooldownSeconds ||
          previous.isAnonymous != current.isAnonymous ||
          previous.anonymousSwitchCooldownSeconds !=
              current.anonymousSwitchCooldownSeconds ||
          previous.steamNameSwitchCooldownSeconds !=
              current.steamNameSwitchCooldownSeconds ||
          previous.pendingSettings != current.pendingSettings ||
          previous.isSpriteChangePending != current.isSpriteChangePending ||
          previous.allOnlineUsers != current.allOnlineUsers ||
          previous.isLoadingAllOnlineUsers != current.isLoadingAllOnlineUsers ||
          previous.queueTicket != current.queueTicket ||
          previous.queuePosition != current.queuePosition ||
          previous.queueTotal != current.queueTotal ||
          previous.queueEtaSeconds != current.queueEtaSeconds ||
          previous.queueIsRequeue != current.queueIsRequeue,
      listenWhen: (previous, current) =>
          previous.isChatActive != current.isChatActive ||
          previous.transientNoticeSeq != current.transientNoticeSeq ||
          previous.transientNotice != current.transientNotice ||
          previous.isTeleporting != current.isTeleporting ||
          previous.isPlayersPanelOpen != current.isPlayersPanelOpen ||
          previous.isSettingsPanelOpen != current.isSettingsPanelOpen ||
          previous.isBroadcastDialogOpen != current.isBroadcastDialogOpen ||
          previous.nearbyPortal != current.nearbyPortal ||
          previous.pendingPortal != current.pendingPortal ||
          previous.isPortalHovered != current.isPortalHovered ||
          previous.kickedReason != current.kickedReason ||
          previous.pageStatus != current.pageStatus,
      listener: (context, state) {
        // 处理传送状态变化
        _syncTeleportAnimation(state);

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

        // 当页面状态变为 ready 时，请求场景焦点（但聊天激活时不抢焦点）
        if (state.pageStatus == LobbyPageStatus.ready && !state.isChatActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _requestSceneFocusIfWindowActive();
          });
        }

        // 控制玩家抽屉动画
        if (state.isPlayersPanelOpen) {
          if (!_playersDrawerController.isCompleted) {
            _playersDrawerController.forward();
          }
        } else {
          if (_playersDrawerController.value > 0) {
            _playersDrawerController.reverse();
          }
        }

        if (state.isChatActive) {
          if (!_chatFocusNode.hasFocus) {
            _chatFocusNode.requestFocus();
          }
        } else {
          _chatController.clear();
          _chatFocusNode.unfocus();
          // 延迟到下一帧再请求 scene 焦点，避免同一 build 周期内焦点不稳定
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _requestSceneFocusIfWindowActive();
          });
        }
        // 每次 transientNotice 变化都重置定时器
        if (state.transientNotice != null) {
          final bloc = context.read<LobbyBloc>();
          final currentSeq = state.transientNoticeSeq;
          // 取消之前的定时器
          _transientNoticeTimer?.cancel();
          _transientNoticeTimer = Timer(const Duration(seconds: 2), () {
            if (mounted && currentSeq == bloc.state.transientNoticeSeq) {
              bloc.add(const LobbyTransientNoticeShown());
            }
          });
        } else {
          _transientNoticeTimer?.cancel();
          _transientNoticeTimer = null;
        }
      },
      builder: (context, state) {
        final pageStatus = state.pageStatus;

        // 被踢出时，无论处于哪个加载阶段，都优先显示踢出遮罩
        if (state.kickedReason != null) {
          return Stack(
            children: [
              if (pageStatus == LobbyPageStatus.ready)
                _buildReadyView(context, state)
              else
                LobbyLoadingScreen(state: state),
              Positioned.fill(
                child: LobbyKickedOverlay(
                  reason: state.kickedReason!,
                  message: state.kickedMessage,
                  onDismiss: () {
                    context.read<LobbyBloc>().add(const LobbyKickedDismissed());
                  },
                ),
              ),
            ],
          );
        }

        // Loading 阶段：显示加载界面或排队界面
        if (pageStatus == LobbyPageStatus.loading) {
          if (state.isQueueing) {
            return _LobbyQueueScreen(state: state);
          }
          return LobbyLoadingScreen(state: state);
        }

        // idle / error：显示空状态
        if (pageStatus == LobbyPageStatus.error) {
          return _LobbyErrorScreen(state: state);
        }
        if (pageStatus == LobbyPageStatus.idle) {
          return _LobbyIdleScreen(state: state);
        }

        return _buildReadyView(context, state);
      },
    );
  }

  /// 构建 ready 状态的主视图
  Widget _buildReadyView(BuildContext context, LobbyState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mapConfig = state.mapConfig;
    // ignore: deprecated_member_use
    return RawKeyboardListener(
      focusNode: _sceneFocusNode,
      autofocus: true,
      onKey: (event) {
        // ignore: deprecated_member_use
        if (event is! RawKeyDownEvent) return;

        // 面板打开时忽略键盘事件
        if (state.isPlayersPanelOpen || state.isSettingsPanelOpen) {
          return;
        }

        if (event.logicalKey == LogicalKeyboardKey.enter) {
          // 聊天栏已打开时，尝试发送消息
          if (state.isChatActive) {
            final text = _chatController.text;
            if (text.trim().isNotEmpty) {
              context.read<LobbyBloc>().add(LobbyChatSubmitted(text));
            } else {
              // 空消息回车关闭聊天栏
              context.read<LobbyBloc>().add(const LobbyChatModeChanged(false));
            }
          } else {
            // 直接打开聊天栏，让用户看到输入框的占位提示
            context.read<LobbyBloc>().add(const LobbyChatModeChanged(true));
          }
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          // Escape 关闭聊天（如果已打开）或面板
          if (state.isChatActive) {
            context.read<LobbyBloc>().add(const LobbyChatModeChanged(false));
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(22),
            bottomRight: Radius.circular(22),
          ),
          color: isDark ? const Color(0xFF0B1120) : const Color(0xFFDDE7F7),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(22),
            bottomRight: Radius.circular(22),
          ),
          child: Stack(
            children: [
              // 地图场景
              Positioned.fill(
                child: mapConfig == null
                    ? const SizedBox.shrink()
                    : LobbyScene(
                        mapConfig: mapConfig,
                        state: state,
                        sceneFocusNode: _sceneFocusNode,
                      ),
              ),
              // 状态横幅
              Positioned(
                top: 20,
                left: 24,
                right: 24,
                child: IgnorePointer(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: state.transientNotice == null
                        ? const SizedBox.shrink()
                        : LobbyStatusBanner(
                            key: ValueKey(state.transientNotice),
                            message: state.transientNotice!,
                            connectionStatus: state.connectionStatus,
                          ),
                  ),
                ),
              ),
              // 聊天激活时的背景遮罩（排除聊天输入框区域，点击其他地方关闭聊天）
              if (state.isChatActive &&
                  !state.isPlayersPanelOpen &&
                  !state.isSettingsPanelOpen)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // 聊天输入框的位置：left: 24, bottom: 24, 宽度 360
                      final chatWidth = 360.0;
                      final chatHeight = 360.0; // 估算高度（消息列表300 + 输入框等）
                      final chatLeft = 24.0;
                      final chatBottom = 24.0;
                      final chatRight =
                          constraints.maxWidth - chatLeft - chatWidth;

                      return Stack(
                        children: [
                          // 遮罩层 - 排除聊天输入框区域
                          Positioned(
                            top: 0,
                            left: 0,
                            right: chatRight,
                            bottom: 0,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                context.read<LobbyBloc>().add(
                                  const LobbyChatModeChanged(false),
                                );
                                _sceneFocusNode.requestFocus();
                              },
                              child: Container(color: Colors.transparent),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            bottom:
                                constraints.maxHeight - chatBottom - chatHeight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                context.read<LobbyBloc>().add(
                                  const LobbyChatModeChanged(false),
                                );
                                _sceneFocusNode.requestFocus();
                              },
                              child: Container(color: Colors.transparent),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            bottom: 0,
                            width: constraints.maxWidth - chatLeft - chatWidth,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                context.read<LobbyBloc>().add(
                                  const LobbyChatModeChanged(false),
                                );
                                _sceneFocusNode.requestFocus();
                              },
                              child: Container(color: Colors.transparent),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              // 聊天输入（放在遮罩层上面，确保能接收点击事件）
              // 聊天未激活时开启 IgnorePointer 允许鼠标事件穿透到游戏场景
              // 聚焦某个角色时（玩家抽屉右键菜单打开），临时淡出隐藏聊天栏，
              // 避免遮挡聚光灯下的目标角色
              Positioned(
                left: 24,
                bottom: 24,
                child: IgnorePointer(
                  ignoring: !state.isChatActive || _isPlayerFocused,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    opacity: _isPlayerFocused ? 0.0 : 1.0,
                    child: LobbyChatOverlay(
                      state: state,
                      controller: _chatController,
                      focusNode: _chatFocusNode,
                    ),
                  ),
                ),
              ),
              // 浮动按钮
              Positioned(
                right: 24,
                bottom: 24,
                child: LobbyFloatingActions(state: state),
              ),
              // 面板打开时的背景遮罩（使用 opaque 确保点击任意位置都能关闭面板）
              // 注意：此时如果聊天也激活，聊天输入框在面板下面，不应该被遮挡
              if (state.isPlayersPanelOpen || state.isSettingsPanelOpen)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      context.read<LobbyBloc>().add(
                        const LobbyPanelsDismissed(),
                      );
                      _sceneFocusNode.requestFocus();
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),
              // 玩家抽屉
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: 320,
                child: SlideTransition(
                  position: _playersDrawerSlideAnimation,
                  child: FadeTransition(
                    opacity: _playersDrawerFadeAnimation,
                    child: state.isPlayersPanelOpen
                        ? _PlayersDrawer(
                            state: state,
                            onClose: () => context.read<LobbyBloc>().add(
                              const LobbyPanelsDismissed(),
                            ),
                            onFocusChanged: (focused) {
                              if (!mounted) return;
                              if (_isPlayerFocused == focused) return;
                              setState(() => _isPlayerFocused = focused);
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
              // 设置面板
              Positioned(
                left: 0,
                right: 0,
                bottom: 90,
                child: Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.6,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -0.2),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: state.isSettingsPanelOpen
                          ? LobbySettingsPanel(
                              key: const ValueKey('settings'),
                              state: state,
                            )
                          : SizedBox.shrink(
                              key: const ValueKey('settings_empty'),
                            ),
                    ),
                  ),
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
                          targetContent: _buildMosaicTargetContent(
                            _targetMapConfig!,
                          ),
                          targetName: _targetMapConfig!.displayName,
                          progress: progress,
                          showTouhouDecoration: true,
                        );
                      },
                    ),
                  ),
                ),
              // 玩家加入/离开通知
              if (state.playerNotifications.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: PlayerNotificationOverlay(
                      notifications: state.playerNotifications,
                      onNotificationExpire: (id) {
                        context.read<LobbyBloc>().add(
                          LobbyNotificationExpired(id),
                        );
                      },
                    ),
                  ),
                ),
              // 传送门询问对话框
              if (state.nearbyPortal != null && !state.isTeleporting)
                Positioned.fill(
                  child: PortalConfirmDialog(
                    portal: state.nearbyPortal!,
                    onConfirm: () {
                      context.read<LobbyBloc>().add(
                        LobbyPortalConfirmRequested(state.nearbyPortal!.key),
                      );
                    },
                    onCancel: () {
                      context.read<LobbyBloc>().add(
                        const LobbyPortalDialogDismissed(),
                      );
                    },
                  ),
                ),
              // 广播发送弹窗
              if (state.isBroadcastDialogOpen) const LobbyBroadcastDialog(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 大厅空闲/未进入状态
class _LobbyIdleScreen extends StatelessWidget {
  final LobbyState state;

  const _LobbyIdleScreen({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? Colors.white54 : AppColors.slate600;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        color: isDark ? const Color(0xFF0B1120) : const Color(0xFFDDE7F7),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.castle,
                size: 64,
                color: textSecondary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                '大厅未初始化',
                style: TextStyle(color: textSecondary, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 大厅错误状态
class _LobbyErrorScreen extends StatelessWidget {
  final LobbyState state;

  const _LobbyErrorScreen({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? Colors.white54 : AppColors.slate600;
    final errorColor = AppColors.red500;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        color: isDark ? const Color(0xFF0B1120) : const Color(0xFFDDE7F7),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: errorColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: errorColor.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                '大厅加载失败',
                style: TextStyle(
                  color: errorColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (state.transientNotice != null)
                Text(
                  state.transientNotice!,
                  style: TextStyle(color: textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  context.read<LobbyBloc>().add(const LobbyStarted());
                },
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
                style: TextButton.styleFrom(foregroundColor: errorColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 玩家抽屉
class _PlayersDrawer extends StatefulWidget {
  final LobbyState state;
  final VoidCallback onClose;

  /// 聚焦状态变化回调（右键菜单打开 -> true，关闭 -> false）
  /// 用于通知父级临时隐藏聊天栏等会遮挡聚光灯的 UI
  final ValueChanged<bool>? onFocusChanged;

  const _PlayersDrawer({
    required this.state,
    required this.onClose,
    this.onFocusChanged,
  });

  @override
  State<_PlayersDrawer> createState() => _PlayersDrawerState();
}

class _PlayersDrawerState extends State<_PlayersDrawer> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// 状态筛选：null=全部, 'online'=在线, 'inGame'=游戏中, 'queuingOrWarming'=挤服/暖服中
  String? _statusFilter;

  /// 关注用户 ID 集合（从本地存储读取）
  Set<String> _followedIds = {};

  /// 当前高亮的用户 ID（点击弹出菜单时）
  String? _highlightedUserId;

  /// 当前打开的菜单 OverlayEntry（用于面板关闭时清理）
  OverlayEntry? _activeMenuEntry;

  @override
  void initState() {
    super.initState();
    _loadFollowedIds();
  }

  void _loadFollowedIds() {
    final list = StorageUtils.getStringList('lobby_followed_user_ids');
    _followedIds = list.toSet();
  }

  @override
  void didUpdateWidget(covariant _PlayersDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 每次面板刷新时重新读取关注列表（用户可能刚通过菜单关注/取消关注）
    _loadFollowedIds();
  }

  /// 显示玩家右键菜单
  void _showPlayerContextMenu(
    BuildContext context,
    LobbyUser user,
    Offset globalPosition,
    bool isFollowed,
  ) {
    setState(() {
      _highlightedUserId = user.userId;
    });
    widget.onFocusChanged?.call(true);

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _PlayerPopupMenu(
        position: globalPosition,
        isFollowed: isFollowed,
        onInvestigate: () {
          entry.remove();
          _activeMenuEntry = null;
          setState(() => _highlightedUserId = null);
          widget.onFocusChanged?.call(false);
          LobbyGame.activeInstance?.cancelFocus();
          LobbyUserProfilePanel.show(context, user);
        },
        onToggleFollow: () {
          entry.remove();
          _activeMenuEntry = null;
          // 切换关注状态
          if (isFollowed) {
            _followedIds.remove(user.businessUserId);
          } else {
            if (user.businessUserId != null &&
                user.businessUserId!.isNotEmpty) {
              _followedIds.add(user.businessUserId!);
            }
          }
          StorageUtils.setStringList(
            'lobby_followed_user_ids',
            _followedIds.toList(),
          );
          // 通知游戏刷新角色关注状态
          LobbyGame.activeInstance?.reloadFollowedUsers();
          LobbyGame.activeInstance?.cancelFocus();
          setState(() => _highlightedUserId = null);
          widget.onFocusChanged?.call(false);
        },
        onDismiss: () {
          entry.remove();
          _activeMenuEntry = null;
          LobbyGame.activeInstance?.cancelFocus();
          setState(() => _highlightedUserId = null);
          widget.onFocusChanged?.call(false);
        },
      ),
    );

    // 菜单弹出时，将视角移到该用户
    _activeMenuEntry = entry;
    LobbyGame.activeInstance?.focusOnUser(user.userId);
    overlay.insert(entry);
  }

  @override
  void dispose() {
    // 面板关闭时清理残留的菜单和聚焦状态
    if (_activeMenuEntry != null) {
      _activeMenuEntry!.remove();
      _activeMenuEntry = null;
      LobbyGame.activeInstance?.cancelFocus();
      widget.onFocusChanged?.call(false);
    }
    _searchController.dispose();
    super.dispose();
  }

  /// 返回搜索过滤后、状态过滤前的在线用户列表（用于计算各分类人数）
  List<LobbyUser> _getSearchedUsers() {
    final users = widget.state.allOnlineUsers.isNotEmpty
        ? widget.state.allOnlineUsers
        : widget.state.users;
    var filtered = users.where((user) => user.isOnline).toList();
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((user) => user.displayName.toLowerCase().contains(query))
          .toList();
    }
    return filtered;
  }

  /// 判断单个用户是否匹配指定筛选条件
  bool _matchesFilter(LobbyUser user, String? filter) {
    if (filter == null) return true;
    final status = (user.statusText ?? '在线').toLowerCase();
    switch (filter) {
      case 'online':
        return !status.contains('游戏中') &&
            !status.contains('挤服') &&
            !status.contains('暖服') &&
            !status.contains('热身') &&
            !status.contains('主菜单');
      case 'inGame':
        return status.contains('游戏中') ||
            status.contains('热身') ||
            status.contains('主菜单');
      case 'queuingOrWarming':
        return status.contains('挤服') || status.contains('暖服');
      default:
        return true;
    }
  }

  /// 计算指定筛选条件下的人数（基于搜索后列表，随搜索词动态变化）
  int _countForFilter(List<LobbyUser> searchedUsers, String? filter) {
    return searchedUsers.where((u) => _matchesFilter(u, filter)).length;
  }

  /// 兜底去重，确保列表中同一用户只出现一次。
  ///
  /// 去重键优先级：businessUserId（账户级稳定 ID）> userId。
  /// 同时保证最多只有一个"自己"（isSelf），并且当某个非 self 记录与 self
  /// 共享同一 businessUserId 时（例如 online.stats 自身识别失败、本地注入的
  /// self 与服务端返回的同账号记录并存）也会被折叠，避免身份切换/丢帧造成
  /// 重复"自己"导致点击高亮多行或多行显示"你"标签。
  /// 保留各分组首次出现的元素，维持原有排序。
  List<LobbyUser> _dedupUsers(List<LobbyUser> users) {
    // 先确定"自己"的账户级 ID，用于折叠同账号的非 self 记录
    String? selfBizId;
    for (final user in users) {
      if (user.isSelf &&
          user.businessUserId != null &&
          user.businessUserId!.isNotEmpty) {
        selfBizId = user.businessUserId;
        break;
      }
    }

    final seen = <String>{};
    var selfKept = false;
    final result = <LobbyUser>[];
    for (final user in users) {
      if (user.isSelf) {
        if (selfKept) continue;
        selfKept = true;
        result.add(user);
        continue;
      }
      // 非 self 但与自己同账号 → 视为重复的"自己"，丢弃
      if (selfBizId != null &&
          user.businessUserId != null &&
          user.businessUserId!.isNotEmpty &&
          user.businessUserId == selfBizId) {
        continue;
      }
      final key =
          (user.businessUserId != null && user.businessUserId!.isNotEmpty)
          ? 'biz_${user.businessUserId}'
          : 'uid_${user.userId}';
      if (seen.add(key)) {
        result.add(user);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 优先使用全服人数，否则使用当前房间人数
    final onlineCount = widget.state.allOnlineUsers.isNotEmpty
        ? widget.state.totalOnlineCount
        : widget.state.onlineCount;
    final isLoading =
        widget.state.isLoadingAllOnlineUsers &&
        widget.state.allOnlineUsers.isEmpty;

    // 基于搜索结果计算各分类人数（状态过滤前），供 chip 动态显示
    final searchedUsers = _getSearchedUsers();
    final countAll = searchedUsers.length;
    final countOnline = _countForFilter(searchedUsers, 'online');
    final countInGame = _countForFilter(searchedUsers, 'inGame');
    final countQueuingOrWarming = _countForFilter(
      searchedUsers,
      'queuingOrWarming',
    );

    final displayUsers =
        searchedUsers.where((u) => _matchesFilter(u, _statusFilter)).toList()
          ..sort((a, b) {
            if (a.isSelf) return -1;
            if (b.isSelf) return 1;
            // 关注用户排在前面
            final aFollowed = _followedIds.contains(a.businessUserId);
            final bFollowed = _followedIds.contains(b.businessUserId);
            if (aFollowed && !bFollowed) return -1;
            if (!aFollowed && bFollowed) return 1;
            return a.displayName.compareTo(b.displayName);
          });
    // 兜底去重：防止身份切换/丢帧场景下同一用户（尤其是"自己"）重复出现，
    // 导致点击一个高亮多行、或多行显示"你"标签。
    final dedupedUsers = _dedupUsers(displayUsers);

    return Row(
      children: [
        // 半透明背景遮罩（点击可关闭）
        Expanded(
          child: GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        // 抽屉主体
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0B1120).withValues(alpha: 0.96)
                : AppColors.slate800.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 32,
                offset: const Offset(-8, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // 抽屉标题栏
              _DrawerHeader(title: '在线玩家', onlineCount: onlineCount),
              const Divider(height: 1, color: Colors.white10),
              // 搜索和筛选栏
              _buildFilterBar(
                countAll: countAll,
                countOnline: countOnline,
                countInGame: countInGame,
                countQueuingOrWarming: countQueuingOrWarming,
              ),
              const Divider(height: 1, color: Colors.white10),
              // 玩家列表
              Expanded(
                child: isLoading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white54,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              '正在加载玩家列表...',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : displayUsers.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty || _statusFilter != null
                              ? '没有匹配的玩家'
                              : '暂无在线玩家',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: dedupedUsers.length,
                        itemBuilder: (context, index) {
                          final user = dedupedUsers[index];
                          final isFollowed = _followedIds.contains(
                            user.businessUserId,
                          );
                          final isHighlighted =
                              _highlightedUserId == user.userId;
                          // 判断用户是否在本地图：检查 state.users（当前地图用户列表）中是否存在该用户
                          final isOnCurrentMap = widget.state.users.any(
                            (u) => u.userId == user.userId,
                          );
                          // 解析用户所在地图名称：优先使用服务端返回的 mapId
                          String? userMapName;
                          if (isOnCurrentMap) {
                            userMapName = widget.state.mapConfig?.displayName;
                          } else if (user.mapId != null &&
                              user.mapId!.isNotEmpty) {
                            userMapName =
                                widget.state.assets
                                    .getMapById(user.mapId!)
                                    ?.displayName ??
                                user.mapId;
                          }
                          return _PlayerListTile(
                            // 稳定 key：去重后 businessUserId/userId 唯一，
                            // 避免列表重排时 StatefulWidget 状态错位到相邻用户
                            key: ValueKey(
                              user.businessUserId?.isNotEmpty == true
                                  ? 'biz_${user.businessUserId}'
                                  : 'uid_${user.userId}',
                            ),
                            user: user,
                            isFollowed: isFollowed,
                            isHighlighted: isHighlighted,
                            isOnCurrentMap: isOnCurrentMap,
                            currentMapName: isOnCurrentMap
                                ? widget.state.mapConfig?.displayName
                                : userMapName,
                            onTapAt: user.isSelf
                                ? null
                                : user.isAnonymous
                                ? null
                                : (offset) => _showPlayerContextMenu(
                                    context,
                                    user,
                                    offset,
                                    isFollowed,
                                  ),
                            onSelfTap: user.isSelf && !widget.state.isAnonymous
                                ? () =>
                                      LobbyUserProfilePanel.show(context, user)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar({
    required int countAll,
    required int countOnline,
    required int countInGame,
    required int countQueuingOrWarming,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          // 搜索框
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: '搜索玩家...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 状态筛选标签
          SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(null, '全部', countAll),
                const SizedBox(width: 6),
                _buildFilterChip('online', '在线', countOnline),
                const SizedBox(width: 6),
                _buildFilterChip('inGame', '游戏中', countInGame),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'queuingOrWarming',
                  '挤服/暖服',
                  countQueuingOrWarming,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String? filterValue, String label, int count) {
    final isSelected = _statusFilter == filterValue;
    return _HoverFilterChip(
      label: label,
      count: isSelected ? count : null, // 只有选中时才传入人数
      isSelected: isSelected,
      onTap: () => setState(() => _statusFilter = filterValue),
    );
  }
}

class _HoverFilterChip extends StatefulWidget {
  final String label;

  /// 仅选中时传入，用于显示动态人数；null 表示不显示人数
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  const _HoverFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.count,
  });

  @override
  State<_HoverFilterChip> createState() => _HoverFilterChipState();
}

class _HoverFilterChipState extends State<_HoverFilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final displayText = (widget.isSelected && widget.count != null)
        ? '${widget.label} (${widget.count})'
        : widget.label;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.lobbyBlue.withValues(alpha: 0.25)
                : _hovered
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.lobbyBlue.withValues(alpha: 0.5)
                  : _hovered
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            displayText,
            style: TextStyle(
              color: widget.isSelected
                  ? AppColors.lobbyBlue
                  : _hovered
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// 抽屉标题栏
class _DrawerHeader extends StatelessWidget {
  final String title;
  final int onlineCount;

  const _DrawerHeader({required this.title, required this.onlineCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Steam 风格图标
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.lobbyBlue, Color(0xFF0B66C2)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.group, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$onlineCount 人在线',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 玩家列表项
class _PlayerListTile extends StatefulWidget {
  final LobbyUser user;
  final bool isFollowed;
  final bool isHighlighted;
  final bool isOnCurrentMap;
  final String? currentMapName;
  final void Function(Offset globalPosition)? onTapAt;
  final VoidCallback? onSelfTap;

  const _PlayerListTile({
    super.key,
    required this.user,
    this.isFollowed = false,
    this.isHighlighted = false,
    this.isOnCurrentMap = true,
    this.currentMapName,
    this.onTapAt,
    this.onSelfTap,
  });

  @override
  State<_PlayerListTile> createState() => _PlayerListTileState();
}

class _PlayerListTileState extends State<_PlayerListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isFollowed = widget.isFollowed;
    final isHighlighted = widget.isHighlighted;
    final canInteract = widget.onTapAt != null || widget.onSelfTap != null;

    return MouseRegion(
      cursor: canInteract ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: widget.onTapAt != null
            ? (details) => widget.onTapAt!(details.globalPosition)
            : widget.onSelfTap != null
            ? (_) => widget.onSelfTap!()
            : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isHighlighted
                ? const Color(0xFF40C4FF).withValues(alpha: 0.10)
                : _isHovered
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isHighlighted
                  ? const Color(0xFF40C4FF).withValues(alpha: 0.7)
                  : user.isSelf
                  ? AppColors.lobbyBlue.withValues(alpha: 0.4)
                  : _isHovered
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.05),
              width: isHighlighted ? 1.5 : 1,
            ),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: const Color(0xFF40C4FF).withValues(alpha: 0.25),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                // 头像
                _PlayerAvatar(user: user),
                const SizedBox(width: 12),
                // 名称、状态、地图标签
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 18,
                        child: MarqueeText(
                          text: user.displayName,
                          style: TextStyle(
                            color: isFollowed
                                ? const Color(0xFFFFD740)
                                : isHighlighted
                                ? const Color(0xFF40C4FF)
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: user.isOnline
                                  ? const Color(0xFF4ADE80)
                                  : Colors.white24,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SizedBox(
                              height: 15,
                              child: MarqueeText(
                                text: user.statusText ?? '在线',
                                style: TextStyle(
                                  color: isHighlighted
                                      ? const Color(0xFF81D4FA)
                                      : Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 第三行：地图标签（自己也显示地图名称）
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isOnCurrentMap
                              ? const Color(0xFF4ADE80).withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: widget.isOnCurrentMap
                                ? const Color(0xFF4ADE80).withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          widget.isOnCurrentMap
                              ? widget.currentMapName != null
                                    ? '${widget.currentMapName}（本地图）'
                                    : '本地图'
                              : (widget.currentMapName ?? '其他地图'),
                          style: TextStyle(
                            color: widget.isOnCurrentMap
                                ? const Color(0xFF4ADE80).withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 右侧：自己显示"你"标签，其他用户显示箭头
                if (user.isSelf) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lobbyBlue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.lobbyBlue.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Text(
                      '我',
                      style: TextStyle(
                        color: AppColors.lobbyBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ] else if (!user.isAnonymous) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 玩家交互弹出菜单（Overlay 实现）
class _PlayerPopupMenu extends StatelessWidget {
  final Offset position;
  final bool isFollowed;
  final VoidCallback onInvestigate;
  final VoidCallback onToggleFollow;
  final VoidCallback onDismiss;

  const _PlayerPopupMenu({
    required this.position,
    required this.isFollowed,
    required this.onInvestigate,
    required this.onToggleFollow,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸，计算菜单实际位置（防止溢出）
    final screenSize = MediaQuery.of(context).size;
    const menuWidth = 110.0;
    const menuHeight = 76.0; // 2项 × 28 + padding 10 + 间距
    final dx = (position.dx + menuWidth > screenSize.width)
        ? position.dx - menuWidth
        : position.dx;
    final dy = (position.dy + menuHeight > screenSize.height)
        ? position.dy - menuHeight
        : position.dy;

    return Stack(
      children: [
        // 背景遮罩（点击关闭）
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: Container(color: Colors.transparent),
          ),
        ),
        // 菜单
        Positioned(
          left: dx,
          top: dy,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PopupMenuItem(label: '调查', onTap: onInvestigate),
                  _PopupMenuItem(
                    label: isFollowed ? '取消关注' : '关注',
                    onTap: onToggleFollow,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 弹出菜单项
class _PopupMenuItem extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _PopupMenuItem({required this.label, required this.onTap});

  @override
  State<_PopupMenuItem> createState() => _PopupMenuItemState();
}

class _PopupMenuItemState extends State<_PopupMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// 玩家头像组件
class _PlayerAvatar extends StatelessWidget {
  final LobbyUser user;

  const _PlayerAvatar({required this.user});

  static const int _avatarSize = 64;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;

    Widget avatar;
    if (hasAvatar) {
      avatar = ClipOval(
        child: Image.network(
          user.avatarUrl!,
          width: 40,
          height: 40,
          cacheWidth: _avatarSize,
          cacheHeight: _avatarSize,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackAvatar();
          },
        ),
      );
    } else {
      avatar = _buildFallbackAvatar();
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: user.isSelf
              ? AppColors.lobbyBlue
              : Colors.white.withValues(alpha: 0.1),
          width: user.isSelf ? 2 : 1,
        ),
      ),
      child: avatar,
    );
  }

  Widget _buildFallbackAvatar() {
    return CircleAvatar(
      radius: 20,
      backgroundColor: user.isSelf
          ? AppColors.lobbyBlue.withValues(alpha: 0.3)
          : Colors.white.withValues(alpha: 0.1),
      child: const Icon(Icons.person, size: 22, color: Colors.white54),
    );
  }
}

/// 排队等待界面
class _LobbyQueueScreen extends StatefulWidget {
  final LobbyState state;

  const _LobbyQueueScreen({required this.state});

  @override
  State<_LobbyQueueScreen> createState() => _LobbyQueueScreenState();
}

class _LobbyQueueScreenState extends State<_LobbyQueueScreen>
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
    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _rotateController, curve: Curves.linear));

    _progressGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _progressGlowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _progressGlowController, curve: Curves.easeInOut),
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
    final textPrimary = isDark ? Colors.white : AppColors.slate800;
    final textSecondary = isDark ? Colors.white70 : AppColors.slate600;
    final accentColor = AppColors.sky400;
    final successColor = AppColors.green500;

    final position = widget.state.queuePosition;
    final total = widget.state.queueTotal;
    final eta = widget.state.queueEtaSeconds;
    final progress = _calculateProgress();

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        color: isDark ? const Color(0xFF0B1120) : const Color(0xFFDDE7F7),
      ),
      child: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ),
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
                  widget.state.queueIsRequeue ? '重新排队' : '正在排队',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 中心圆环动画（与 loading screen 风格一致）
              AnimatedBuilder(
                animation: Listenable.merge([
                  _pulseAnimation,
                  _rotateAnimation,
                ]),
                builder: (context, child) {
                  return SizedBox(
                    width: 100,
                    height: 100,
                    child: CustomPaint(
                      painter: _QueueRingPainter(
                        progress: progress,
                        rotation: _rotateAnimation.value * 6.28,
                        pulse: _pulseAnimation.value,
                        ringBgColor: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppColors.slate300,
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
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '人排队',
                              style: TextStyle(
                                color: textSecondary.withValues(alpha: 0.7),
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
                    style: TextStyle(color: textSecondary, fontSize: 14),
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
                                  alpha: 0.15 * _progressGlowAnimation.value,
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
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : const Color(
                                        0xFFCBD5E1,
                                      ).withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            // 进度
                            FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [accentColor, successColor],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
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
                          color: successColor.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.state.queueIsRequeue
                        ? '连接已恢复 · 重新排队中'
                        : '连接正常 · 排队中',
                    style: TextStyle(
                      color: textSecondary.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 排队界面的圆环画笔（与 loading screen 风格一致）
class _QueueRingPainter extends CustomPainter {
  final double progress;
  final double rotation;
  final double pulse;
  final Color ringBgColor;
  final Color accentColor;

  _QueueRingPainter({
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
            AppColors.green500,
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
  bool shouldRepaint(covariant _QueueRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rotation != rotation ||
        oldDelegate.pulse != pulse;
  }
}

/// 地图预览组件
class _MosaicMapPreview extends StatefulWidget {
  final LobbyMapConfig mapConfig;

  const _MosaicMapPreview({required this.mapConfig});

  @override
  State<_MosaicMapPreview> createState() => _MosaicMapPreviewState();
}

class _MosaicMapPreviewState extends State<_MosaicMapPreview> {
  bool _imageLoaded = false;
  bool _hasError = false;
  Uint8List? _cachedImageBytes;

  @override
  void initState() {
    super.initState();
    _loadFromCache();
  }

  @override
  void didUpdateWidget(_MosaicMapPreview oldWidget) {
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
      // 直接从 LobbyImageCacheService 获取已缓存的图片数据
      // 这样可以确保使用已经下载好的图片，而不是重新下载
      final bytes = await LobbyImageCacheService.instance.getImage(
        widget.mapConfig.backgroundUrl!,
      );

      if (bytes != null && mounted) {
        setState(() {
          _cachedImageBytes = bytes;
          _imageLoaded = true;
        });
        LogService.d('[MosaicMapPreview] 从 LobbyImageCacheService 加载图片成功');
      } else if (mounted) {
        // 缓存中没有，尝试用 Image.network 加载
        setState(() {
          _hasError = true;
        });
      }
    } catch (e) {
      LogService.w('[MosaicMapPreview] 从缓存加载图片失败: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _MosaicPlaceholderBackground(
        mapName: widget.mapConfig.displayName,
      );
    }

    // 如果还没有加载完，先显示占位背景
    if (!_imageLoaded || _cachedImageBytes == null) {
      return _MosaicPlaceholderBackground(
        mapName: widget.mapConfig.displayName,
      );
    }

    // 使用 MemoryImage 从已缓存的字节数据加载图片
    return Image.memory(
      _cachedImageBytes!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        LogService.w('[MosaicMapPreview] Image.memory 加载失败: $error');
        return _MosaicPlaceholderBackground(
          mapName: widget.mapConfig.displayName,
        );
      },
    );
  }
}

/// 占位背景组件（当没有地图背景URL时显示）
class _MosaicPlaceholderBackground extends StatelessWidget {
  final String mapName;

  const _MosaicPlaceholderBackground({required this.mapName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF1A1F2E), const Color(0xFF0F1624)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map,
              size: 80,
              color: Colors.cyan.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              mapName,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '地图预览',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
