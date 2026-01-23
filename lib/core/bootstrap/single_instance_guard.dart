import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_alone/flutter_alone.dart';

/// 单实例检查守卫
/// 
/// 确保应用只有一个实例在运行（仅 Windows 平台）
class SingleInstanceGuard {
  SingleInstanceGuard._();

  /// 检查是否允许启动
  /// 
  /// 返回 true 表示可以启动，false 表示已有实例运行
  static Future<bool> check() async {
    if (!Platform.isWindows) return true;

    try {
      final config = FlutterAloneConfig.forWindows(
        windowsConfig: const CustomWindowsMutexConfig(
          customMutexName: 'BakaBox_CS2_Launcher_Mutex',
        ),
        windowConfig: const WindowConfig(
          windowTitle: 'BakaBox',
        ),
        duplicateCheckConfig: const DuplicateCheckConfig(
          enableInDebugMode: false,
        ),
        messageConfig: const CustomMessageConfig(
          customTitle: 'BakaBox',
          customMessage: 'BakaBox 已经在运行中',
          showMessageBox: true,
        ),
      );
      
      final isFirst = await FlutterAlone.instance.checkAndRun(config: config);
      if (!isFirst) {
        debugPrint('[BakaBox] 检测到已有实例运行，退出...');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[BakaBox] 单实例检查失败: $e，继续正常启动');
      return true;
    }
  }
}
