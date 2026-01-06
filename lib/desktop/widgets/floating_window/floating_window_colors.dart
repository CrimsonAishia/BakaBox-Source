import 'package:flutter/material.dart';
import 'floating_window_state.dart';

/// 浮窗颜色配置
class FloatingWindowColors {
  static const Color idle = Color(0xFF6B7280);
  static const Color launching = Color(0xFF3B82F6);
  static const Color connecting = Color(0xFF0080FF);
  static const Color loading = Color(0xFFF59E0B);
  static const Color queueing = Color(0xFF0080FF);
  static const Color success = Color(0xFF10B981);
  static const Color failed = Color(0xFFEF4444);
  static const Color serverFull = Color(0xFFF59E0B);
  static const Color paused = Color(0xFF6B7280);
  
  // 背景色
  static const Color background = Color(0xF21E293B); // 0.95 opacity
  static const Color backgroundDark = Color(0xFF0F172A);
  
  /// 根据状态获取颜色
  static Color fromState(FloatingWindowState state) {
    if (state.isIdle) return idle;
    if (state.isLaunching) return launching;
    if (state.isConnecting) return connecting;
    if (state.isLoading) return loading;
    if (state.isQueueing) return queueing;
    if (state.isSuccess) return success;
    if (state.isFailed) return failed;
    if (state.isServerFull) return serverFull;
    if (state.isPaused) return paused;
    return idle;
  }
  
  /// 线程状态颜色
  static Color threadColor(String status) {
    switch (status) {
      case 'idle': return Colors.white.withValues(alpha: 0.3);
      case 'requesting': return connecting;
      case 'success': return success;
      case 'failed': return failed;
      default: return Colors.white.withValues(alpha: 0.3);
    }
  }
}
