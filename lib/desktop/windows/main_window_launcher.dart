import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/bootstrap/app_initializer.dart';
import '../../core/services/floating_window_service.dart';
import '../../core/services/notification_window_service.dart';
import '../../core/services/status_window_service.dart';
import '../../core/services/obs_server_service.dart';
import '../../core/utils/storage_utils.dart';
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

    // 根据开关状态决定是否启动 OBS 浏览器源数据服务
    final obsEnabled = StorageUtils.getBool(
      'obs_tool_enabled',
      defaultValue: false,
    );
    if (obsEnabled) {
      ObsServerService().start();
    }

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
            NotificationWindowService().onNotificationWindowClosed(
              notificationId,
            );
          }
          return true;
        case 'floatingWindowClosed':
          // 处理浮动窗口关闭事件
          final args = call.arguments as Map<dynamic, dynamic>?;
          final windowId = args?['windowId'] as String?;
          if (windowId != null) {
            debugPrint('[MainWindow] Floating window closed: $windowId');
            FloatingWindowService().markWindowClosed(windowId);
            StatusWindowService().onFloatingWindowClosed(windowId);
          }
          return true;
        default:
          throw MissingPluginException('Not implemented: ${call.method}');
      }
    });
  }

  /// 初始化窗口
  static Future<void> _initWindow() async {
    const windowSize = Size(1150, 768);
    const windowOptions = WindowOptions(
      size: windowSize,
      minimumSize: windowSize, // 设置最小尺寸，防止分辨率变化时窗口被缩小
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
        // 防止窗口被系统自动调整大小
        await windowManager.setResizable(false);
      }
    });
  }
}
