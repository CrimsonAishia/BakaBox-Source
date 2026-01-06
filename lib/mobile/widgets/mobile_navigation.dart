import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/navigation/app_navigation.dart';

class MobileNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final List<NavigationItem> items;

  const MobileNavigation({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CurvedNavigationBar(
      index: currentIndex,
      height: 60.0,
      items: items.map((item) {
        final isSelected = currentIndex == items.indexOf(item);
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
      buttonBackgroundColor: items[currentIndex].activeColor,
      backgroundColor: isDark 
        ? const Color(0xFF0F172A).withValues(alpha: 0.95)
        : const Color(0xFFE9EEF8).withValues(alpha: 0.95),
      animationCurve: Curves.easeInOutCubic,
      animationDuration: const Duration(milliseconds: 350),
      onTap: (index) {
        if (currentIndex != index) {
          HapticFeedback.lightImpact();
          onIndexChanged(index);
        }
      },
    )
    .animate()
    .slideY(begin: 1.0, end: 0.0, duration: 600.ms, curve: Curves.easeOutCubic)
    .fadeIn(duration: 400.ms, delay: 200.ms);
  }
}
