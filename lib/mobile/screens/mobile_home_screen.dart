import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

import '../../core/widgets/exit_dialog.dart';
import '../../core/widgets/page_view_with_listener.dart';

import 'welcome_mobile.dart';
import 'servers_mobile.dart';
import 'update_logs_mobile.dart';
import 'settings_mobile.dart';

/// 移动端主屏幕
class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _navigationAnimationController;
  bool _isAnimating = false;

  late final List<Widget> _screens;

  final List<NavigationItemData> _navigationItems = [
    NavigationItemData(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: '首页',
      activeColor: const Color(0xFF0080FF),
      inactiveColor: const Color(0xFF64748B),
    ),
    NavigationItemData(
      icon: MdiIcons.server,
      selectedIcon: MdiIcons.serverNetwork,
      label: '服务器',
      activeColor: const Color(0xFF10B981),
      inactiveColor: const Color(0xFF64748B),
    ),
    NavigationItemData(
      icon: MdiIcons.fileDocumentOutline,
      selectedIcon: MdiIcons.fileDocument,
      label: '更新日志',
      activeColor: const Color(0xFFEF4444),
      inactiveColor: const Color(0xFF64748B),
    ),
    NavigationItemData(
      icon: MdiIcons.cogOutline,
      selectedIcon: MdiIcons.cog,
      label: '设置',
      activeColor: const Color(0xFF8B5CF6),
      inactiveColor: const Color(0xFF64748B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _navigationAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _screens = [
      WelcomeMobile(onNavigateToServers: () => _navigateToPage(1)),
      const ServersMobile(),
      const UpdateLogsMobile(),
      const SettingsMobile(),
    ];
  }

  void _navigateToPage(int index) {
    if (_currentIndex != index && !_isAnimating) {
      HapticFeedback.lightImpact();
      _isAnimating = true;
      setState(() => _currentIndex = index);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      ).then((_) => _isAnimating = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _navigationAnimationController.dispose();
    super.dispose();
  }

  Future<bool> _handleExit() async {
    final result = await ExitDialog.show(context);
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _handleExit();
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: PageViewWithListener(
          controller: _pageController,
          onPageChanged: (index) {
            if (_currentIndex != index && !_isAnimating) {
              HapticFeedback.selectionClick();
              setState(() => _currentIndex = index);
            }
          },
          physics: const BouncingScrollPhysics(),
          children: _screens,
        ),
        bottomNavigationBar: CurvedNavigationBar(
          index: _currentIndex,
          height: 60.0,
          items: _navigationItems.map((item) {
            final isSelected = _currentIndex == _navigationItems.indexOf(item);
            return SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                isSelected ? item.selectedIcon : item.icon,
                size: 28,
                color: isSelected 
                  ? Colors.white
                  : isDark 
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.black.withValues(alpha: 0.6),
              ),
            );
          }).toList(),
          color: isDark 
            ? const Color(0xFF1E293B).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
          buttonBackgroundColor: _navigationItems[_currentIndex].activeColor,
          backgroundColor: isDark 
            ? const Color(0xFF0F172A).withValues(alpha: 0.95)
            : const Color(0xFFE9EEF8).withValues(alpha: 0.95),
          animationCurve: Curves.easeInOutCubic,
          animationDuration: const Duration(milliseconds: 350),
          onTap: (index) {
            if (_currentIndex != index && !_isAnimating) {
              HapticFeedback.lightImpact();
              _isAnimating = true;
              setState(() => _currentIndex = index);
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
              ).then((_) => _isAnimating = false);
            }
          },
        )
          .animate()
          .slideY(begin: 1.0, end: 0.0, duration: 600.ms, curve: Curves.easeOutCubic)
          .fadeIn(duration: 400.ms, delay: 200.ms),
      ),
    );
  }
}

class NavigationItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color activeColor;
  final Color inactiveColor;

  const NavigationItemData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.activeColor,
    required this.inactiveColor,
  });
}
