import 'package:flutter/material.dart';

/// 应用全局调色板（颜色唯一数据源）
///
/// 跨平台共享（desktop / mobile / web）。命名基于 Tailwind 色阶，
/// 与原硬编码色值一一对应（零视觉变化），避免在各处重复硬编码同一色值导致漂移。
///
/// 语义化颜色（如挤服 / 暖服）见 [OperationColors]，其底层引用本调色板。
class AppColors {
  AppColors._();

  /// 主品牌色 - 蓝（自定义，非 Tailwind 色阶）
  static const Color primary = Color(0xFF0080FF);

  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);

  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  static const Color red500 = Color(0xFFEF4444);
  static const Color red600 = Color(0xFFDC2626);

  static const Color blue500 = Color(0xFF3B82F6);
  static const Color sky400 = Color(0xFF38BDF8);

  static const Color indigo500 = Color(0xFF6366F1);
  static const Color violet500 = Color(0xFF8B5CF6);

  static const Color emerald500 = Color(0xFF10B981);
  static const Color green500 = Color(0xFF22C55E);

  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color orange = Color(0xFFFF9800); // Material Orange 500

  /// 角色图鉴技能绿
  static const Color skillGreen = Color(0xFF4A7C59);

  /// 大厅 / 社交蓝
  static const Color lobbyBlue = Color(0xFF1D9BF0);
}
