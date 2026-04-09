import 'dart:io';

import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import '../services/tray_service.dart';

/// 单实例服务
///
/// 负责管理 Windows 平台的单实例检查和窗口唤醒
class SingleInstanceService {
  SingleInstanceService._();

  static final SingleInstanceService instance = SingleInstanceService._();

  /// 单实例唯一标识符（只能使用 a-z, 0-9, _ 和 -）
  static const _key = 'BakaBox_CS2_Launcher';

  /// 确保单实例运行
  ///
  /// 如果已有实例运行，会唤醒已存在的窗口并返回 false
  /// 如果是首个实例，返回 true
  Future<bool> ensureSingleInstance(List<String> args) async {
    if (!Platform.isWindows) return true;

    try {
      await WindowsSingleInstance.ensureSingleInstance(
        args,
        _key,
        onSecondWindow: _wakeExistingInstance,
      );
      return true;
    } catch (e) {
      // 单实例检查失败时允许启动
      return true;
    }
  }

  /// 唤醒已存在的窗口实例
  Future<void> _wakeExistingInstance(List<String> args) async {
    // 如果窗口被隐藏，重新显示
    final isVisible = await windowManager.isVisible();
    if (!isVisible) {
      await windowManager.show();
    }

    // 如果窗口被最小化，恢复它
    final isMinimized = await windowManager.isMinimized();
    if (isMinimized) {
      await windowManager.restore();
    }

    // 将窗口置顶并获取焦点
    await windowManager.focus();

    // 销毁托盘图标
    await TrayService.instance.dispose();
  }
}
