import 'dart:io';

import 'package:flutter/services.dart';

import 'log_service.dart';

/// 屏幕常亮工具
///
/// 通过 Android 原生 FLAG_KEEP_SCREEN_ON 实现，
/// 仅 Android 平台生效。
class ScreenWakelock {
  static const _channel = MethodChannel('cc.aishia.bakabox/wakelock');

  /// 开启屏幕常亮
  static Future<void> enable() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('enable');
      LogService.i('屏幕常亮已开启');
    } catch (e) {
      LogService.e('开启屏幕常亮失败', e);
    }
  }

  /// 关闭屏幕常亮
  static Future<void> disable() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('disable');
      LogService.i('屏幕常亮已关闭');
    } catch (e) {
      LogService.e('关闭屏幕常亮失败', e);
    }
  }
}
