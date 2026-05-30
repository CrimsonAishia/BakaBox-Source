import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/bootstrap/app_initializer.dart';
import '../../core/services/single_instance_service.dart';
import '../../core/services/floating_window_service.dart';
import '../../core/services/notification_window_service.dart';
import '../widgets/position_preview_window.dart';
import 'floating_window_launcher.dart';
import 'main_window_launcher.dart';
import 'notification_window_launcher.dart';
import 'preview_window_launcher.dart';

/// 桌面端窗口启动分发器
///
/// 负责判断窗口类型并分发到对应的启动器
class DesktopWindowLauncher {
  DesktopWindowLauncher._();

  /// 启动桌面端应用
  static Future<void> launch(List<String> args) async {
    final isSubWindow = args.isNotEmpty;

    // 主窗口需要单实例检查
    if (!isSubWindow) {
      final canStart = await SingleInstanceService.instance
          .ensureSingleInstance(args);
      if (!canStart) {
        exit(0);
      }
    }

    // 初始化桌面端基础服务（子窗口跳过存储初始化）
    await AppInitializer.initDesktopBase(
      skipStorage: isSubWindow,
      onPlatformInit: () => windowManager.ensureInitialized(),
    );

    // 获取当前窗口控制器
    final controller = await WindowController.fromCurrentEngine();

    // 判断窗口类型并分发
    final isMainWindow = controller.arguments.isEmpty;

    if (isMainWindow) {
      await MainWindowLauncher.launch(controller);
    } else if (PositionPreviewConfig.isPositionPreviewWindow(
      controller.arguments,
    )) {
      await PreviewWindowLauncher.launch(controller);
    } else if (NotificationData.isSingleNotificationWindow(
      controller.arguments,
    )) {
      await NotificationWindowLauncher.launch(controller);
    } else {
      final config = FloatingWindowConfig.fromArguments(controller.arguments);
      await FloatingWindowLauncher.launch(controller, config);
    }
  }
}
