import 'dart:async';
import 'dart:io';

import 'package:window_manager/window_manager.dart';

import 'floating_window_service.dart';
import 'obs_server_service.dart';
import 'tray_service.dart';

/// 应用程序退出服务
/// 负责完整的退出流程：停止服务、销毁窗口、退出进程
class AppExitService {
  AppExitService._();

  static final AppExitService instance = AppExitService._();

  /// 执行完整的应用退出流程
  Future<void> exitApplication() async {
    // 1. 停止 OBS 服务
    final obsService = ObsServerService();
    if (obsService.isRunning) {
      obsService.clearDisplay();
      await obsService.stop();
    }

    // 2. 关闭所有浮动窗口
    await FloatingWindowService().closeAllWindows();

    // 3. 隐藏主窗口
    await windowManager.hide();

    // 4. 销毁托盘图标
    await TrayService.instance.dispose();

    // 5. 销毁窗口句柄并退出进程
    await windowManager.destroy();
    exit(0);
  }
}
