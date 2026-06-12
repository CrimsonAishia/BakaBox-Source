import 'package:flutter/material.dart';
import 'floating_window_state.dart';
import '../../../core/constants/app_colors.dart';

/// 浮窗颜色配置
class FloatingWindowColors {
  static const Color idle = AppColors.gray500;
  static const Color launching = AppColors.blue500;
  static const Color connecting = AppColors.primary;
  static const Color loading = AppColors.amber500;
  static const Color queueing = AppColors.primary;
  static const Color warming = Color(0xFFFF6B00); // 暖服的专属火热橙色
  static const Color success = AppColors.emerald500;
  static const Color failed = AppColors.red500;
  static const Color serverFull = AppColors.amber500;
  static const Color paused = AppColors.gray500;

  // 背景色
  static const Color background = Color(0xF21E293B); // 0.95 opacity
  static const Color backgroundDark = AppColors.slate900;

  /// 根据状态获取颜色
  static Color fromState(FloatingWindowState state) {
    if (state.isIdle) return idle;
    if (state.isLaunching) return launching;
    if (state.isConnecting) return connecting;
    if (state.isLoading) return loading;
    if (state.isQueueing) return queueing;
    if (state.isWarming) return warming;
    if (state.isSuccess) return success;
    if (state.isFailed) return failed;
    if (state.isServerFull) return serverFull;
    if (state.isPaused) return paused;
    return idle;
  }

  /// 线程状态颜色
  static Color threadColor(String status) {
    switch (status) {
      case 'idle':
        return Colors.white.withValues(alpha: 0.3);
      case 'requesting':
        return connecting;
      case 'success':
        return success;
      case 'failed':
        return failed;
      default:
        return Colors.white.withValues(alpha: 0.3);
    }
  }
}
