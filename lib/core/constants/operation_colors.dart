import 'package:flutter/material.dart';

/// 挤服 / 暖服等操作相关的语义化颜色常量
///
/// 集中管理操作状态配色，确保服务器卡片、通知窗口等不同界面保持一致。
class OperationColors {
  OperationColors._();

  /// 挤服 - 红色
  static const Color queue = Color(0xFFF44336);

  /// 暖服 - 黄色
  static const Color warmup = Color(0xFFF59E0B);

  /// 同时存在挤服和暖服时使用的渐变（红 → 黄）
  static const LinearGradient queueWarmupGradient = LinearGradient(
    colors: [queue, warmup],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
