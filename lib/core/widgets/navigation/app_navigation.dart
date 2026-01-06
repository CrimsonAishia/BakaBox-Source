import 'package:flutter/material.dart';

/// 导航项数据模型
class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color activeColor;
  final Color inactiveColor;

  const NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.activeColor,
    required this.inactiveColor,
  });
}
