import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../core/core.dart';
import '../widgets/desktop_window_controls.dart';
import '../widgets/desktop_navigation.dart';
import '../widgets/queue/queue_floating_card.dart';

import 'welcome_screen.dart';
import 'servers_desktop.dart';
import 'update_logs_desktop.dart';
import 'issues_desktop.dart';
import 'tools_screen.dart';
import 'settings_desktop.dart';
import 'character_gallery_desktop.dart';
import 'bilibili_content_screen.dart';
import '../../core/services/game_status_service.dart';
import '../../core/utils/storage_utils.dart';

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
      2 => const CharacterGalleryDesktop(),
      3 => const BilibiliContentScreen(),
      4 => const UpdateLogsDesktop(),
      5 => const ToolsScreen(),
      6 => const SettingsDesktop(),
      7 => const IssuesDesktop(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  void initState() {
    super.initState();
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _contentAnimationController.forward();

    // 初始化时获取公告数据并启动自动刷新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<AnnouncementBloc>();
      bloc.add(AnnouncementFetch());
      bloc.add(AnnouncementStartAutoRefresh());

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
    super.dispose();
  }

  void _onIndexChanged(int index) {
    if (_currentIndex == index) return;

    // 页面切换时清理 Flutter 图片缓存，释放内存
    PaintingBinding.instance.imageCache.clear();

    setState(() {
      _currentIndex = index;
      _contentAnimationController.reset();
      _contentAnimationController.forward();
    });
  }

  Future<bool> _handleExit() async {
    final result = await ExitDialog.show(context);
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return PopScope(
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
                  onFeedbackTap: () => _onIndexChanged(7),
                  isFeedbackSelected: _currentIndex == 7,
                ),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _contentAnimationController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
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
              Positioned(top: 12, right: 12, child: DesktopWindowControls()),
            if (isDesktop)
              const Positioned(
                top: 0,
                left: 0,
                right: 120,
                height: 56,
                child: DragToMoveArea(child: SizedBox.expand()),
              ),
            // 挤服悬浮卡片
            if (isDesktop)
              const Positioned(
                bottom: 16,
                right: 16,
                child: QueueFloatingCard(),
              ),
          ],
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
