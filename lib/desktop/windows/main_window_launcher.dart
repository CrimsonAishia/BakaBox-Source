import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/bootstrap/app_initializer.dart';
import '../../core/services/notification_window_service.dart';
import '../../core/services/status_window_service.dart';
import '../app.dart';

/// 主窗口启动器
class MainWindowLauncher {
  MainWindowLauncher._();

  /// 启动主窗口
  static Future<void> launch(WindowController controller) async {
    // 设置主窗口 ID，供通知服务使用
    NotificationWindowService().setMainWindowId(controller.windowId);

    // 设置窗口方法处理器
    await _setupMethodHandler(controller);

    // 初始化主窗口
    await _initWindow();

    // 初始化主窗口服务
    await AppInitializer.initMainWindowServices();

    // 初始化状态窗口服务
    StatusWindowService().initialize();

    runApp(const DesktopApp());
  }

  /// 设置窗口方法处理器
  static Future<void> _setupMethodHandler(WindowController controller) async {
    await controller.setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'window_close':
          await windowManager.close();
          return true;
        case 'window_center':
          await windowManager.center();
          return true;
        case 'window_show':
          await windowManager.show();
          return true;
        case 'window_hide':
          await windowManager.hide();
          return true;
        case 'window_focus':
          await windowManager.focus();
          return true;
        case 'navigateToUpdateLog':
          // 处理从通知窗口发来的导航请求
          final args = call.arguments as Map<dynamic, dynamic>?;
          final updateTime = args?['updateTime'] as String?;
          debugPrint('[MainWindow] Received navigateToUpdateLog: $updateTime');
          NotificationWindowService().navigateToUpdateLog(updateTime);
          return true;
        case 'notificationClosed':
          // 处理通知窗口关闭事件
          final args = call.arguments as Map<dynamic, dynamic>?;
          final notificationId = args?['id'] as String?;
          if (notificationId != null) {
            debugPrint('[MainWindow] Notification closed: $notificationId');
            NotificationWindowService().onNotificationWindowClosed(notificationId);
          }
          return true;
        default:
          throw MissingPluginException('Not implemented: ${call.method}');
      }
    });
  }

  /// 初始化窗口
  static Future<void> _initWindow() async {
    const windowOptions = WindowOptions(
      size: Size(1150, 768),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      if (Platform.isWindows) {
        await windowManager.setAsFrameless();
      }
    });
  }
}
