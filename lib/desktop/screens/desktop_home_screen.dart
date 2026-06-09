import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../core/core.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/desktop_window_controls.dart';
import '../widgets/desktop_navigation.dart';
import '../widgets/queue/queue_floating_card.dart';
import '../widgets/warmup/warmup_floating_card.dart';

import 'welcome_screen.dart';
import 'servers_desktop.dart';
import 'update_logs_desktop.dart';
import 'issues_desktop.dart';
import 'tools_screen.dart';
import 'settings_desktop.dart';
import '../widgets/settings/path_invalid_dialog.dart';
import '../widgets/cs2_crash_dialog.dart';
import 'character_gallery_desktop.dart';
import 'bilibili_content_screen.dart';
import 'lobby_desktop.dart';
import 'community_guide_screen.dart';
import '../../core/services/game_status_service.dart';
import '../../core/services/cs2_crash_monitor_service.dart';
import '../widgets/global_broadcast_bar.dart';
import '../widgets/floating_chat/floating_chat_button.dart';
import '../widgets/warmup/warmup_countdown_dialog.dart';
import '../../core/widgets/csgo_manual_launch_dialog.dart';
import '../../core/bloc/warmup/warmup_bloc.dart';
import '../../core/bloc/warmup/warmup_state.dart';

/// 桌面端主屏幕
class DesktopHomeScreen extends StatefulWidget {
  const DesktopHomeScreen({super.key});

  @override
  State<DesktopHomeScreen> createState() => _DesktopHomeScreenState();
}

class _DesktopHomeScreenState extends State<DesktopHomeScreen>
    with TickerProviderStateMixin
    implements DesktopNavigator {
  int _currentIndex = 0;
  late AnimationController _contentAnimationController;
  StreamSubscription<GameStatusEvent>? _gameStatusSubscription;
  StreamSubscription<Cs2CrashDetectedEvent>? _crashSubscription;
  bool _shownObsWarningForCurrentGame = false;
  late final FloatingChatCubit _floatingChatCubit;
  Route? _warmupCountdownRoute;

  // 攻略模块 GlobalKey，供 DesktopNavigator 调用
  final GlobalKey<CommunityGuideScreenState> _guideHostKey = GlobalKey();

  // 跨模块跳转到工具箱时的待消费参数
  String? _pendingTool;
  Map<String, dynamic>? _pendingArgs;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: '首页',
      activeColor: const Color(0xFF0080FF),
      inactiveColor: const Color(0xFF64748B),
    ),
    NavigationItem(
      icon: MdiIcons.server,
      selectedIcon: MdiIcons.serverNetwork,
      label: '服务器列表',
      activeColor: const Color(0xFF0080FF),
      inactiveColor: const Color(0xFF64748B),
    ),
    NavigationItem(
      icon: MdiIcons.castle,
      selectedIcon: MdiIcons.castle,
      label: '大厅',
      activeColor: const Color(0xFF0080FF),
      inactiveColor: const Color(0xFF64748B),
    ),
    NavigationItem(
      icon: MdiIcons.accountGroup,
      selectedIcon: MdiIcons.accountGroupOutline,
      label: '角色图鉴',
      activeColor: const Color(0xFF0080FF),
      inactiveColor: const Color(0xFF64748B),
    ),
    NavigationItem(
      icon: MdiIcons.playCircleOutline,
      selectedIcon: MdiIcons.playCircle,
      label: '直播/视频',
      activeColor: const Color(0xFF0080FF),
      inactiveColor: const Color(0xFF64748B),
    ),
    NavigationItem(
      icon: MdiIcons.bookOpenPageVariantOutline,
      selectedIcon: MdiIcons.bookOpenPageVariant,
      label: '攻略',
      activeColor: const Color(0xFF0080FF),
      inactiveColor: const Color(0xFF64748B),
    ),
    NavigationItem(
      icon: MdiIcons.fileDocumentOutline,
      selectedIcon: MdiIcons.fileDocument,
      label: '更新日志',
      activeColor: const Color(0xFF0080FF),
      inactiveColor: const Color(0xFF64748B),
    ),
    NavigationItem(
      icon: MdiIcons.toolboxOutline,
      selectedIcon: MdiIcons.toolbox,
      label: '工具箱',
      activeColor: const Color(0xFF0080FF),
      inactiveColor: const Color(0xFF64748B),
    ),
    NavigationItem(
      icon: MdiIcons.cogOutline,
      selectedIcon: MdiIcons.cog,
      label: '设置',
      activeColor: const Color(0xFF0080FF),
      inactiveColor: const Color(0xFF64748B),
    ),
  ];

  /// 根据索引构建页面（使用全局 Bloc，页面切换不重新创建）
  Widget _buildScreen(int index) {
    return switch (index) {
      0 => WelcomeScreen(onNavigateToServers: () => _onIndexChanged(1)),
      1 => const ServersDesktop(),
      2 => const LobbyDesktop(),
      3 => const CharacterGalleryDesktop(),
      4 => const BilibiliContentScreen(),
      5 => CommunityGuideScreen(key: _guideHostKey),
      6 => const UpdateLogsDesktop(),
      7 => ToolsScreen(
          initialToolId: _pendingTool,
          initialToolArgs: _pendingArgs,
          onArgsConsumed: () => setState(() {
            _pendingTool = null;
            _pendingArgs = null;
          }),
        ),
      8 => const SettingsDesktop(),
      9 => const IssuesDesktop(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  void initState() {
    super.initState();
    _floatingChatCubit = FloatingChatCubit();
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _contentAnimationController.forward();

    // 应用启动时立即连接大厅 WebSocket 并预加载大厅数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 进入主页时检查路径是否已失效（处理冷启动场景：
      // SettingsBloc 在 splash 屏幕期间已完成校验并将 isPathInvalidated 设为 true，
      // 此时 BlocListener 监听不到 false→true 的转变，需要主动检查初始 state）
      final settingsState = context.read<SettingsBloc>().state;
      if (settingsState.isPathInvalidated && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const PathInvalidDialog(),
        );
      }

      LobbyNakamaService.instance.initialize();

      final bloc = context.read<AnnouncementBloc>();
      bloc.add(AnnouncementFetch());
      bloc.add(const AnnouncementStartRealtime());

      context.read<LobbyBloc>().add(const LobbyPageActivityChanged('在看主页'));

      // 预加载大厅数据（消息、用户列表等），使浮动聊天按钮在未进入大厅时也能显示历史消息
      final lobbyBloc = context.read<LobbyBloc>();
      if (lobbyBloc.state.pageStatus == LobbyPageStatus.idle) {
        lobbyBloc.add(const LobbyStarted());
      }

      // 检查当前状态，防止错过初始化时的事件
      // 仅在被监控的游戏（CS2）运行但不可监控时提示；
      // 独立版 CSGO / CS:Source 不在监控范围内，不触发提示。
      final gameService = GameStatusService();
      if (gameService.isMonitoredGameRunning && !gameService.isMonitorable) {
        final obsEnabled = StorageUtils.getBool(
          'obs_tool_enabled',
          defaultValue: false,
        );
        if (obsEnabled && mounted && !_shownObsWarningForCurrentGame) {
          _shownObsWarningForCurrentGame = true;
          _showObsWarningDialog();
        }
      }
    });

    _gameStatusSubscription = GameStatusService().statusStream.listen((event) {
      if (!event.isRunning) {
        _shownObsWarningForCurrentGame = false;
      } else if (event.isRunning &&
          event.gameType == 'cs2' &&
          !event.isMonitorable) {
        // 仅 CS2 在监控范围内；独立版 CSGO / CS:Source 不提示"无法监控"。
        final obsEnabled = StorageUtils.getBool(
          'obs_tool_enabled',
          defaultValue: false,
        );
        if (obsEnabled && mounted && !_shownObsWarningForCurrentGame) {
          _shownObsWarningForCurrentGame = true;
          _showObsWarningDialog();
        }
      }
    });

    // 监听 CS2 崩溃 (.mdmp) 检测事件，弹窗展示分析报告
    _crashSubscription = Cs2CrashMonitorService().crashStream.listen((event) {
      if (!mounted) return;
      Cs2CrashDialog.show(context, event.summary);
    });
  }

  void _showObsWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('无法监控游戏'),
          ],
        ),
        content: const Text(
          '检测到游戏已启动，但未添加监控支持（比如通过 Steam 快捷方式启动）。\n\n'
          '如果需要使用 OBS 投屏等功能，请在 BakaBox 软件内启动游戏，或者给 Steam 的游戏加上 "-condebug" 启动项。',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _contentAnimationController.dispose();
    _gameStatusSubscription?.cancel();
    _crashSubscription?.cancel();
    if (_warmupCountdownRoute != null) {
      Navigator.of(context).removeRoute(_warmupCountdownRoute!);
      _warmupCountdownRoute = null;
    }
    _floatingChatCubit.close();
    super.dispose();
  }

  void _onIndexChanged(int index) {
    if (_currentIndex == index) return;

    // 页面切换时清理 Flutter 图片缓存，释放内存
    PaintingBinding.instance.imageCache.clear();

    String newActivityText = '在线';
    switch (index) {
      case 0:
        newActivityText = '在看主页';
        break;
      case 1:
        newActivityText = '在逛服务器列表';
        break;
      case 2:
        newActivityText = '在大厅';
        _floatingChatCubit.onLobbyPageEntered();
        break;
      case 3:
        newActivityText = '在看角色图鉴';
        break;
      case 4:
        newActivityText = '在看视频/直播';
        break;
      case 5:
        newActivityText = '在看攻略';
        break;
      case 6:
        newActivityText = '在看更新日志';
        break;
      case 7:
        newActivityText = '在使用工具箱';
        break;
      case 8:
        newActivityText = '在看设置';
        break;
      case 9:
        newActivityText = '在看问题反馈';
        break;
    }
    context.read<LobbyBloc>().add(LobbyPageActivityChanged(newActivityText));

    setState(() {
      _currentIndex = index;
      _contentAnimationController.reset();
      _contentAnimationController.forward();
    });
  }

  // ---------------------------------------------------------------------------
  // DesktopNavigator 实现
  // ---------------------------------------------------------------------------

  @override
  void openGuides({String? mapName}) {
    _navigateToGuideHostWithLeaveCheck(() {
      _guideHostKey.currentState?.showList(mapName: mapName);
    });
  }

  @override
  void openGuideDetail(int id) {
    _navigateToGuideHostWithLeaveCheck(() {
      _guideHostKey.currentState?.showDetail(id);
    });
  }

  @override
  void openGuideEditor({int? guideId, String? prefillMapName}) {
    _navigateToGuideHostWithLeaveCheck(() {
      _guideHostKey.currentState?.showEditor(
        guideId: guideId,
        prefillMapName: prefillMapName,
      );
    });
  }

  @override
  void openMine({bool fromPublish = false}) {
    _navigateToGuideHostWithLeaveCheck(() {
      _guideHostKey.currentState?.showMine(fromPublish: fromPublish);
    });
  }

  @override
  void openMapDatabase({String? mapName}) {
    _performWithLeaveCheck(() {
      setState(() {
        _pendingTool = 'map_database';
        _pendingArgs = mapName != null ? {'mapName': mapName} : null;
      });
      _onIndexChanged(7); // 工具箱 index
    });
  }

  /// 辅助：在切换前检查编辑器是否有未保存内容，通过后执行跳转
  void _performWithLeaveCheck(VoidCallback action) async {
    final hostState = _guideHostKey.currentState;
    if (hostState != null) {
      final canLeave = await hostState.canLeaveCurrentView();
      if (!canLeave) return; // 用户选择取消，中止跳转
    }
    action();
  }

  /// 辅助：切换到攻略页面并在帧结束后调用回调（带 leave 检查）
  void _navigateToGuideHostWithLeaveCheck(VoidCallback afterSwitch) async {
    const guideIndex = 5;

    // 如果当前在攻略页面，先检查能否离开当前视图（编辑器）
    if (_currentIndex == guideIndex) {
      final hostState = _guideHostKey.currentState;
      if (hostState != null) {
        final canLeave = await hostState.canLeaveCurrentView();
        if (!canLeave) return; // 用户选择取消，中止跳转
      }
      afterSwitch();
    } else {
      // 从其他模块跳到攻略，无需 leave 检查
      _onIndexChanged(guideIndex);
      // 等待页面 build 完成后再操作 Host
      WidgetsBinding.instance.addPostFrameCallback((_) {
        afterSwitch();
      });
    }
  }

  Future<bool> _handleExit() async {
    return ExitDialog.handleWindowClose(
      context,
      behavior: context.read<SettingsBloc>().state.appExitBehavior,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: WarmupBloc.instance),
        BlocProvider<FloatingChatCubit>.value(value: _floatingChatCubit),
      ],
      child: DesktopNavigatorProvider(
        navigator: this,
        child: MultiBlocListener(
        listeners: [
          BlocListener<SettingsBloc, SettingsState>(
            listenWhen: (previous, current) =>
                !previous.isPathInvalidated && current.isPathInvalidated,
            listener: (context, state) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const PathInvalidDialog(),
              );
            },
          ),
          BlocListener<WarmupBloc, WarmupBlocState>(
            listenWhen: (previous, current) {
              if (!previous.needManualLaunch && current.needManualLaunch) return true;
              if (current.needManualLaunch) return false;
              if (previous.error != current.error && current.error != null) return true;

              final wasCountdown = previous.status == WarmupStatus.countdown || previous.status == WarmupStatus.launching;
              final isCountdown = current.status == WarmupStatus.countdown || current.status == WarmupStatus.launching;
              if (wasCountdown != isCountdown) return true;

              return false;
            },
            listener: (context, state) {
              // 先协调全局倒计时弹窗的显隐。
              // 必须在 error / needManualLaunch 的 early return 之前执行，
              // 否则启动失败（error 被设置）或需手动启动 CSGO 时，
              // 会因提前 return 而无法移除倒计时弹窗，导致全屏遮罩卡死。
              final isCountdown = state.status == WarmupStatus.countdown ||
                  state.status == WarmupStatus.launching;
              if (isCountdown && _warmupCountdownRoute == null) {
                final warmupBloc = context.read<WarmupBloc>();
                _warmupCountdownRoute = DialogRoute(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) {
                    return BlocProvider.value(
                      value: warmupBloc,
                      child: BlocBuilder<WarmupBloc, WarmupBlocState>(
                        builder: (context, dialogState) {
                          return Material(
                            color: Colors.transparent,
                            child: WarmupCountdownDialog(state: dialogState),
                          );
                        },
                      ),
                    );
                  },
                );
                Navigator.of(context).push(_warmupCountdownRoute!);
              } else if (!isCountdown && _warmupCountdownRoute != null) {
                Navigator.of(context).removeRoute(_warmupCountdownRoute!);
                _warmupCountdownRoute = null;
              }

              // 需要手动启动 CSGO
              if (state.needManualLaunch) {
                showDialog(
                  context: context,
                  builder: (context) => CsgoManualLaunchDialog(
                    serverAddress: state.serverAddress ?? '',
                  ),
                );
                return;
              }

              // 错误提示
              if (state.error != null) {
                ToastUtils.showError(context, state.error!);
                return;
              }
            },
          ),
        ],
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldExit = await _handleExit();
            if (shouldExit && context.mounted) SystemNavigator.pop();
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                Row(
                  children: [
                    DesktopNavigation(
                      currentIndex: _currentIndex,
                      onIndexChanged: _onIndexChanged,
                      items: _navigationItems,
                      onFeedbackTap: () => _onIndexChanged(9),
                      isFeedbackSelected: _currentIndex == 9,
                    ),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _contentAnimationController,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: Tween<double>(begin: 0.0, end: 1.0)
                                .animate(
                                  CurvedAnimation(
                                    parent: _contentAnimationController,
                                    curve: Curves.easeOutCubic,
                                  ),
                                ),
                            child: SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(0.1, 0.0),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _contentAnimationController,
                                      curve: Curves.easeOutCubic,
                                    ),
                                  ),
                              child: _buildPageContent(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (isDesktop)
                  Positioned(top: 8, right: 12, child: DesktopWindowControls()),
                if (isDesktop)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 120,
                    height: 56,
                    child: DragToMoveArea(child: SizedBox.expand()),
                  ),
                // 浮动聊天按钮（非大厅页面显示）
                if (isDesktop && _currentIndex != 2)
                  const Positioned.fill(child: FloatingChatButton()),
                // 右下角悬浮区域：广播通知卡片 + 挤服卡片（从下到上堆叠）
                if (isDesktop)
                  Positioned(
                    key: const ValueKey('bottom_right_overlay'),
                    bottom: 16,
                    right: 16,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GlobalBroadcastBar(),
                        SizedBox(height: 8),
                        WarmupFloatingCard(),
                        SizedBox(height: 8),
                        QueueFloatingCard(),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  /// 构建页面内容，使用 KeyedSubtree 确保页面切换时正确销毁
  Widget _buildPageContent() {
    return KeyedSubtree(
      key: ValueKey(_currentIndex),
      child: _buildScreen(_currentIndex),
    );
  }
}
