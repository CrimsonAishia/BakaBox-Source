import 'dart:async';
import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_alone/flutter_alone.dart';
import 'package:window_manager/window_manager.dart';

import 'core/core.dart';
import 'core/services/notification_window_service.dart';
import 'core/services/status_window_service.dart';
import 'desktop/app.dart';
import 'desktop/widgets/floating_window/floating_window_app.dart';
import 'desktop/widgets/floating_window/floating_window_state.dart';
import 'desktop/widgets/notification_window_app.dart';
import 'mobile/app.dart';

/// 1. 使用 WindowController.fromCurrentEngine() 获取当前窗口
/// 2. 根据 arguments 判断窗口类型
/// 3. 运行不同的 App
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 记录启动时间（统一在此处记录，确保统计完整的启动耗时）
  AnalyticsService.instance.setStartTime(DateTime.now());

  // 移动端直接启动
  if (!PlatformUtils.isDesktopPlatform) {
    runApp(const MobileApp());
    return;
  }

  // 桌面端：单实例检查（仅对主窗口生效）
  // 子窗口通过 desktop_multi_window 创建，不需要单实例检查
  final isSubWindow = args.isNotEmpty;
  if (!isSubWindow) {
    try {
      // Windows 单实例检查
      if (Platform.isWindows) {
        final config = FlutterAloneConfig.forWindows(
          windowsConfig: const CustomWindowsMutexConfig(
            customMutexName: 'BakaBox_CS2_Server_Browser_Mutex',
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
          exit(0);
        }
      }
    } catch (e) {
      debugPrint('[BakaBox] 单实例检查失败: $e，继续正常启动');
    }
  }

  // 初始化应用目录服务（缓存和日志目录）
  await AppDirectoryService.init();

  // 先初始化 windowManager
  await windowManager.ensureInitialized();

  // 桌面端：获取当前窗口控制器
  final controller = await WindowController.fromCurrentEngine();

  // 解析窗口参数，判断窗口类型
  // 主窗口的 arguments 为空，子窗口的 arguments 包含配置信息
  final isMainWindow = controller.arguments.isEmpty;

  if (isMainWindow) {
    await _runMainWindow(controller);
  } else {
    // 检查是否是单个通知窗口
    if (NotificationData.isSingleNotificationWindow(controller.arguments)) {
      await _runSingleNotificationWindow(controller);
    } else {
      final config = FloatingWindowConfig.fromArguments(controller.arguments);
      await _runFloatingWindow(controller, config);
    }
  }
}

/// 运行主窗口
Future<void> _runMainWindow(WindowController controller) async {
  // 设置主窗口 ID，供通知服务使用
  NotificationWindowService().setMainWindowId(controller.windowId);

  // windowManager 已在 main() 中初始化

  // 设置窗口方法处理器
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

  // 初始化主窗口
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

  // 初始化日志
  await LogService.init();
  
  // 初始化状态窗口服务
  StatusWindowService().initialize();

  runApp(const DesktopApp());
}

/// 运行浮动窗口
Future<void> _runFloatingWindow(
  WindowController controller,
  FloatingWindowConfig config,
) async {
  final windowId = controller.windowId;

  // 创建状态通知器，用于 IPC 状态更新
  final stateNotifier = FloatingWindowStateNotifier();
  
  // 从 config.extra 解析初始状态并立即初始化
  // 这样可以确保在 IPC 更新到达之前，状态已经被正确初始化
  final initialState = FloatingWindowState.fromMap(config.extra);
  stateNotifier.initialize(initialState);
  debugPrint('[FloatingWindow] Pre-initialized state: ${initialState.state}');

  // 设置 IPC 处理器
  await controller.setWindowMethodHandler((call) async {
    debugPrint('[FloatingWindow] Received IPC call: ${call.method}');
    switch (call.method) {
      case 'window_center':
        await windowManager.center();
        return true;
      case 'window_close':
      case 'close_self':
        await windowManager.close();
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
      case 'updateState':
        final args = call.arguments as Map<dynamic, dynamic>;
        debugPrint('[FloatingWindow] updateState args: $args');
        stateNotifier.updateState(args);
        return 'ok';
      default:
        throw MissingPluginException('Not implemented: ${call.method}');
    }
  });

  runApp(FloatingWindowApp(
    config: config,
    windowId: windowId,
    stateNotifier: stateNotifier,
  ));
}

/// 运行单个通知窗口
Future<void> _runSingleNotificationWindow(WindowController controller) async {
  final windowId = controller.windowId;

  // 从参数解析通知数据、位置、Y偏移量和主窗口ID
  final (notification, position, yOffset, mainWindowId) =
      NotificationData.fromArguments(controller.arguments);

  // 创建状态通知器
  final stateNotifier = SingleNotificationStateNotifier(notification, position, yOffset: yOffset);

  // 获取主窗口控制器用于 IPC
  final mainWindowController = mainWindowId.isNotEmpty
      ? WindowController.fromWindowId(mainWindowId)
      : null;

  // 设置 IPC 处理器
  await controller.setWindowMethodHandler((call) async {
    debugPrint('[SingleNotification] Received IPC call: ${call.method}');
    switch (call.method) {
      case 'window_close':
      case 'close_self':
        // 通知主窗口此通知已关闭
        if (mainWindowController != null) {
          try {
            await mainWindowController.invokeMethod(
                'notificationClosed', {'id': notification.id});
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

  runApp(SingleNotificationWindowApp(
    windowId: windowId,
    stateNotifier: stateNotifier,
    mainWindowController: mainWindowController,
    notificationId: notification.id,
  ));
}
