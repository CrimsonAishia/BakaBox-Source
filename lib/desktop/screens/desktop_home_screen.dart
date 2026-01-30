import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../core/core.dart';
import '../widgets/desktop_window_controls.dart';
import '../widgets/desktop_navigation.dart';

import 'welcome_screen.dart';
import 'servers_desktop.dart';
import 'update_logs_desktop.dart';
import 'issues_desktop.dart';
import 'tools_screen.dart';
import 'settings_desktop.dart';

/// 桌面端主屏幕
class DesktopHomeScreen extends StatefulWidget {
  const DesktopHomeScreen({super.key});

  @override
  State<DesktopHomeScreen> createState() => _DesktopHomeScreenState();
}

class _DesktopHomeScreenState extends State<DesktopHomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _contentAnimationController;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.home_outlined, selectedIcon: Icons.home, label: '首页',
      activeColor: const Color(0xFF0080FF), inactiveColor: const Color(0xFF64748B),
    ),
    NavigationItem(
      icon: MdiIcons.server, selectedIcon: MdiIcons.serverNetwork, label: '服务器列表',
      activeColor: const Color(0xFF0080FF), inactiveColor: const Color(0xFF64748B),
    ),
    NavigationItem(
      icon: MdiIcons.fileDocumentOutline, selectedIcon: MdiIcons.fileDocument, label: '更新日志',
      activeColor: const Color(0xFF0080FF), inactiveColor: const Color(0xFF64748B),
    ),
    NavigationItem(
      icon: MdiIcons.toolboxOutline, selectedIcon: MdiIcons.toolbox, label: '工具箱',
      activeColor: const Color(0xFF0080FF), inactiveColor: const Color(0xFF64748B),
    ),
    NavigationItem(
      icon: MdiIcons.cogOutline, selectedIcon: MdiIcons.cog, label: '设置',
      activeColor: const Color(0xFF0080FF), inactiveColor: const Color(0xFF64748B),
    ),
  ];

  /// 根据索引构建页面（使用全局 Bloc，页面切换不重新创建）
  Widget _buildScreen(int index) {
    return switch (index) {
      0 => WelcomeScreen(onNavigateToServers: () => _onIndexChanged(1)),
      1 => const ServersDesktop(),
      2 => const UpdateLogsDesktop(),
      3 => const ToolsScreen(),
      4 => const SettingsDesktop(),
      5 => const IssuesDesktop(),
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
    });
  }

  @override
  void dispose() {
    _contentAnimationController.dispose();
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
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

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
                  onFeedbackTap: () => _onIndexChanged(5),
                  isFeedbackSelected: _currentIndex == 5,
                ),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _contentAnimationController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                          CurvedAnimation(parent: _contentAnimationController, curve: Curves.easeOutCubic),
                        ),
                        child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0.1, 0.0), end: Offset.zero).animate(
                            CurvedAnimation(parent: _contentAnimationController, curve: Curves.easeOutCubic),
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
              Positioned(
                top: 12,
                right: 12,
                child: DesktopWindowControls(),
              ),
            if (isDesktop)
              const Positioned(
                top: 0, left: 0, right: 120, height: 56,
                child: DragToMoveArea(child: SizedBox.expand()),
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
