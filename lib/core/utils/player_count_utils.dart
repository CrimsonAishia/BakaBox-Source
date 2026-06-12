import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// 玩家数量相关的工具类
/// 根据玩家数量百分比返回对应的颜色等级
class PlayerCountUtils {
  PlayerCountUtils._();

  /// 根据玩家数量和最大玩家数返回对应的颜色
  ///
  /// 颜色等级规则：
  /// - 0-80%: 绿色 (低负载)
  /// - 80-99%: 橙色 (中等负载)
  /// - 100%: 红色 (满人)
  ///
  /// [players] 当前玩家数量
  /// [maxPlayers] 最大玩家数量
  ///
  /// 返回对应负载等级的颜色
  static Color getPlayerCountColor(int players, int maxPlayers) {
    // 处理边界情况
    if (maxPlayers <= 0) {
      return lowLoadColor;
    }

    // 确保玩家数量在有效范围内
    final validPlayers = players.clamp(0, maxPlayers);

    // 满人 - 红色
    if (validPlayers >= maxPlayers) {
      return highLoadColor;
    }

    final percentage = validPlayers / maxPlayers;

    // 80%以上 - 橙色
    if (percentage >= 0.8) {
      return mediumLoadColor;
    }

    // 80%以下 - 绿色
    return lowLoadColor;
  }

  /// 低负载颜色 (绿色)
  static const Color lowLoadColor = AppColors.emerald500;

  /// 中等负载颜色 (橙色)
  static const Color mediumLoadColor = AppColors.orange;

  /// 高负载颜色 (红色)
  static const Color highLoadColor = Color(0xFFF44336);

  /// 获取玩家数量百分比
  static double getPlayerPercentage(int players, int maxPlayers) {
    if (maxPlayers <= 0) return 0.0;
    return (players / maxPlayers).clamp(0.0, 1.0);
  }

  /// 获取负载等级描述
  static String getLoadLevelText(int players, int maxPlayers) {
    if (maxPlayers <= 0) return '未知';

    // 满人
    if (players >= maxPlayers) {
      return '满人';
    }

    final percentage = getPlayerPercentage(players, maxPlayers);

    // 80%以上
    if (percentage >= 0.8) {
      return '高负载';
    }

    // 80%以下
    return '低负载';
  }
}
