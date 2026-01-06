import 'package:flutter/material.dart';

/// 服务器分类相关的工具类
class CategoryUtils {
  CategoryUtils._();

  static IconData getCategoryIcon(String? categoryName) {
    switch (categoryName?.toLowerCase()) {
      case 'cs2-僵尸逃跑':
      case 'cs-僵尸逃跑':
        return Icons.directions_run;
      case 'cs2-娱乐对抗':
      case 'cs-娱乐对抗':
        return Icons.sports_esports;
      case 'cs2-娱乐混战':
      case 'cs-混战':
        return Icons.group;
      case 'cs2-挂机大厅':
        return Icons.meeting_room;
      case 'cs-你画我猜':
        return Icons.draw;
      case 'cs-匪镇谍影':
        return Icons.visibility;
      case 'cs-连跳':
        return Icons.sports_gymnastics;
      case 'cs-攀岩':
        return Icons.terrain;
      case 'cs-闯关':
        return Icons.flag;
      case 'cs-滑翔':
        return Icons.surfing;
      case 'cs-死亡奔跑':
        return Icons.directions_run;
      default:
        return Icons.dns;
    }
  }

  static Color getCategoryColor(String? categoryName) {
    switch (categoryName?.toLowerCase()) {
      case 'cs2-僵尸逃跑':
      case 'cs-僵尸逃跑':
        return const Color(0xFF0080FF);
      case 'cs2-娱乐对抗':
      case 'cs-娱乐对抗':
        return const Color(0xFFFF6B35);
      case 'cs2-娱乐混战':
      case 'cs-混战':
        return const Color(0xFF00D4AA);
      case 'cs2-挂机大厅':
        return const Color(0xFF9C27B0);
      case 'cs-你画我猜':
        return const Color(0xFFFF3366);
      case 'cs-匪镇谍影':
        return const Color(0xFF6B7280);
      case 'cs-连跳':
        return const Color(0xFFFF9500);
      case 'cs-攀岩':
        return const Color(0xFF8B5CF6);
      case 'cs-闯关':
        return const Color(0xFF10B981);
      case 'cs-滑翔':
        return const Color(0xFF06B6D4);
      case 'cs-死亡奔跑':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF0080FF);
    }
  }

  static LinearGradient getCategoryGradient(String? categoryName) {
    final color = getCategoryColor(categoryName);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.7)],
    );
  }

  static Color getCategoryShadowColor(String? categoryName) {
    return getCategoryColor(categoryName).withValues(alpha: 0.3);
  }
}
