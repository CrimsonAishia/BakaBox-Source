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

import 'welcome_screen.dart';
import 'servers_desktop.dart';
import 'update_logs_desktop.dart';
import 'issues_desktop.dart';
import 'tools_screen.dart';
import 'settings_desktop.dart';
import '../widgets/settings/path_invalid_dialog.dart';
import 'character_gallery_desktop.dart';
import 'bilibili_content_screen.dart';
import 'lobby_desktop.dart';
import '../../core/services/game_status_service.dart';
import '../widgets/global_broadcast_bar.dart';
import '../widgets/floating_chat/floating_chat_button.dart';

/// 桌面端主屏幕
class DesktopHomeScreen extends StatefulWidget {
  const DesktopHomeScreen({super.key});

  @override
  State<DesktopHomeScreen> createState() => _DesktopHomeScreenState();
}

class _DesktopHomeScreenState extends State<DesktopHomeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _contentAnimationController;
  StreamSubscription<GameStatusEvent>? _gameStatusSubscription;
  bool _shownObsWarningForCurrentGame = false;
  late final FloatingChatCubit _floatingChatCubit;

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
      5 => const UpdateLogsDesktop(),
      6 => const ToolsScreen(),
      7 => const SettingsDesktop(),
      8 => const IssuesDesktop(),
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
      final gameService = GameStatusService();
      if (gameService.isGameRunning && !gameService.isMonitorable) {
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
      } else if (event.isRunning && !event.isMonitorable) {
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
        newActivityText = '在看更新日志';
        break;
      case 6:
        newActivityText = '在使用工具箱';
        break;
      case 7:
        newActivityText = '在看设置';
        break;
      case 8:
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

    return BlocProvider<FloatingChatCubit>.value(
      value: _floatingChatCubit,
      child: BlocListener<SettingsBloc, SettingsState>(
        listenWhen: (previous, current) =>
            !previous.isPathInvalidated && current.isPathInvalidated,
        listener: (context, state) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const PathInvalidDialog(),
          );
        },
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
                      onFeedbackTap: () => _onIndexChanged(8),
                      isFeedbackSelected: _currentIndex == 8,
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
                        QueueFloatingCard(),
                      ],
                    ),
                  ),
              ],
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
