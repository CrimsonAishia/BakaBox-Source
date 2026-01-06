import 'package:flutter/material.dart';

/// 玩家数量相关的工具类
/// 根据玩家数量百分比返回对应的颜色等级
class PlayerCountUtils {
  PlayerCountUtils._();

  /// 根据玩家数量和最大玩家数返回对应的颜色
  /// 
  /// 颜色等级规则：
  /// - 0-30%: 绿色 (低负载)
  /// - 30-70%: 黄色 (中等负载)
  /// - 70-100%: 红色 (高负载)
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
    final percentage = validPlayers / maxPlayers;
    
    if (percentage <= 0.3) {
      return lowLoadColor;
    } else if (percentage <= 0.7) {
      return mediumLoadColor;
    } else {
      return highLoadColor;
    }
  }

  /// 低负载颜色 (绿色)
  static const Color lowLoadColor = Color(0xFF4CAF50);

  /// 中等负载颜色 (黄色)
  static const Color mediumLoadColor = Color(0xFFFFC107);

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
    
    final percentage = getPlayerPercentage(players, maxPlayers);
    
    if (percentage <= 0.3) {
      return '低负载';
    } else if (percentage <= 0.7) {
      return '中等负载';
    } else {
      return '高负载';
    }
  }
}
