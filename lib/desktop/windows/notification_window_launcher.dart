import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/services/notification_window_service.dart';
import '../widgets/notification_window_app.dart';

/// 通知窗口启动器
class NotificationWindowLauncher {
  NotificationWindowLauncher._();

  /// 启动单个通知窗口
  static Future<void> launch(WindowController controller) async {
    final windowId = controller.windowId;

    // 从参数解析通知数据、位置、Y偏移量、主窗口ID和通知位置
    final (notification, position, yOffset, mainWindowId, notificationPosition) =
        NotificationData.fromArguments(controller.arguments);

    // 创建状态通知器
    final stateNotifier = SingleNotificationStateNotifier(
      notification,
      position,
      yOffset: yOffset,
      notificationPosition: notificationPosition,
    );

    // 获取主窗口控制器用于 IPC
    final mainWindowController = mainWindowId.isNotEmpty
        ? WindowController.fromWindowId(mainWindowId)
        : null;

    // 设置 IPC 处理器
    await _setupMethodHandler(
      controller,
      stateNotifier,
      mainWindowController,
      notification.id,
    );

    runApp(SingleNotificationWindowApp(
      windowId: windowId,
      stateNotifier: stateNotifier,
      mainWindowController: mainWindowController,
      notificationId: notification.id,
    ));
  }

  /// 设置窗口方法处理器
  static Future<void> _setupMethodHandler(
    WindowController controller,
    SingleNotificationStateNotifier stateNotifier,
    WindowController? mainWindowController,
    String notificationId,
  ) async {
    await controller.setWindowMethodHandler((call) async {
      debugPrint('[SingleNotification] Received IPC call: ${call.method}');
      switch (call.method) {
        case 'window_close':
        case 'close_self':
          // 通知主窗口此通知已关闭
          if (mainWindowController != null) {
            try {
              await mainWindowController.invokeMethod(
                  'notificationClosed', {'id': notificationId});
            } catch (e) {
              debugPrint('[SingleNotification] Failed to notify main window: $e');
            }
          }
          await windowManager.close();
          return true;
        case 'window_show':
          await windowManager.show();
          return true;
        case 'window_hide':
          await windowManager.hide();
          return true;
        case 'updateNotification':
          final args = call.arguments as Map<dynamic, dynamic>;
          final updatedNotification =
              NotificationData.fromMap(Map<String, dynamic>.from(args));
          stateNotifier.updateNotification(updatedNotification);
          return 'ok';
        case 'updatePosition':
          final args = call.arguments as Map<dynamic, dynamic>;
          final newPosition = args['position'] as int? ?? 0;
          final newYOffset = args['yOffset'] as double?;
          stateNotifier.updatePosition(newPosition, yOffset: newYOffset);
          return 'ok';
        default:
          throw MissingPluginException('Not implemented: ${call.method}');
      }
    });
  }
}
