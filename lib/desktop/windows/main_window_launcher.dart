import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/bootstrap/app_initializer.dart';
import '../../core/services/app_exit_service.dart';
import '../../core/services/broadcast_notification_service.dart';
import '../../core/services/floating_window_service.dart';
import '../../core/services/notification_window_service.dart';
import '../../core/services/status_window_service.dart';
import '../../core/services/obs_server_service.dart';
import '../../core/services/tray_service.dart';
import '../../core/utils/storage_utils.dart';
import '../app.dart';

import '../../core/utils/log_service.dart';

/// 主窗口启动器
class MainWindowLauncher {
  MainWindowLauncher._();

  /// 启动主窗口
  static Future<void> launch(WindowController controller) async {
    // 注册桌面端退出处理器
    AppExitService.instance.registerDesktopExitHandler(_exitDesktop);

    // 设置主窗口 ID，供通知服务使用
    NotificationWindowService().setMainWindowId(controller.windowId);

    // 设置窗口方法处理器
    await _setupMethodHandler(controller);

    // 初始化主窗口
    await _initWindow();

    // 初始化主窗口服务
    await AppInitializer.initMainWindowServices();

    // 初始化广播系统通知服务
    await BroadcastNotificationService.instance.init();

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

  /// 桌面端完整退出流程
  ///
  /// 关键：不再用 `exit(0)` ，而是走 `windowManager.destroy()`
  ///   → 原生 `PostQuitMessage(0)`
  ///   → `wWinMain` 消息循环自然退出
  ///   → `CoUninitialize()` 被调用
  ///
  /// `exit(0)` 直接跳过消息循环，`CoInitializeEx` 对应的 `CoUninitialize`
  /// 永远不会执行。WebView2 / tray_manager / windows_notification / fvp 等
  /// 大量依赖 COM 的原生插件在"COM 未反初始化"状态下被 DLL_PROCESS_DETACH
  /// 卸载，会触发 SEH 异常。WER 正常的机器上表现为静默 werfault；
  /// WER 被禁的机器上则弹出 "Unknown Hard Error" 系统级弹窗
  /// （部分精简版 Windows、优化软件、组策略环境会禁 WER）。
  ///
  /// desktop_multi_window 的子窗口本身用 `windowManager.destroy()` 关闭，
  /// 是干净的；崩点在主进程。所以只需要修主进程退出路径。
  static Future<void> _exitDesktop() async {
    const closeTimeout = Duration(seconds: 2);
    final stopwatch = Stopwatch()..start();
    LogService.i('[Exit] Starting desktop exit process...');

    // 1. 停止 OBS 服务
    final obsService = ObsServerService();
    if (obsService.isRunning) {
      try {
        LogService.i('[Exit] Stopping OBS service...');
        obsService.clearDisplay();
        await obsService.stop().timeout(closeTimeout);
        LogService.i(
          '[Exit] OBS service stopped (Elapsed: ${stopwatch.elapsedMilliseconds}ms)',
        );
      } catch (e) {
        LogService.e('[Exit] stop OBS failed', e);
      }
    }

    // 2. 先隐藏主窗口 —— 视觉上立即"退出"，后续清理在后台做
    try {
      LogService.i('[Exit] Hiding main window...');
      await windowManager.hide();
      LogService.i(
        '[Exit] Main window hidden (Elapsed: ${stopwatch.elapsedMilliseconds}ms)',
      );
    } catch (e) {
      LogService.e('[Exit] hide window failed', e);
    }

    // 3. 关闭所有浮动窗口（挤服 / 暖服 / 连接 / 启动 等浮窗）
    try {
      LogService.i('[Exit] Closing floating windows...');
      await FloatingWindowService().closeAllWindows().timeout(closeTimeout);
      LogService.i(
        '[Exit] Floating windows closed (Elapsed: ${stopwatch.elapsedMilliseconds}ms)',
      );
    } catch (e) {
      LogService.e('[Exit] closeAllWindows failed or timed out', e);
    }

    // 4. 关闭所有通知窗口（换图 / 更新日志 / 广播 等通知窗）
    try {
      LogService.i('[Exit] Closing notification windows...');
      await NotificationWindowService().dismissAll().timeout(closeTimeout);
      LogService.i(
        '[Exit] Notification windows closed (Elapsed: ${stopwatch.elapsedMilliseconds}ms)',
      );
    } catch (e) {
      LogService.e('[Exit] dismissAll notifications failed or timed out', e);
    }

    // 5. 给子窗口进程 teardown 宽限期
    LogService.i(
      '[Exit] Waiting 1500ms for child process teardown (Elapsed: ${stopwatch.elapsedMilliseconds}ms)',
    );
    await Future.delayed(const Duration(milliseconds: 1500));

    // 6. 销毁托盘图标
    try {
      LogService.i(
        '[Exit] Disposing tray service (Elapsed: ${stopwatch.elapsedMilliseconds}ms)',
      );
      await TrayService.instance.dispose();
      LogService.i('[Exit] Tray service disposed');
    } catch (e) {
      LogService.e('[Exit] tray dispose failed', e);
    }

    // 7. 解除 preventClose，然后 destroy 触发原生 PostQuitMessage(0)
    try {
      LogService.i(
        '[Exit] Setting preventClose to false (Elapsed: ${stopwatch.elapsedMilliseconds}ms)',
      );
      await windowManager.setPreventClose(false);
    } catch (e) {
      LogService.e('[Exit] setPreventClose(false) failed', e);
    }

    try {
      LogService.i(
        '[Exit] Destroying main window (Elapsed: ${stopwatch.elapsedMilliseconds}ms)...',
      );
      // 在销毁窗口前，强制刷新一次内存中的所有日志到文件，
      // 因为一旦 destroy，C++ 原生层会立刻终止进程，后续的异步日志将丢失。
      await LogService.flush();
      
      await windowManager.destroy();
    } catch (e) {
      LogService.e('[Exit] destroy failed', e);
      // 如果销毁失败，再刷新一次错误日志
      await LogService.flush();
    }

    // 8. 兜底：正常路径下上面 destroy 后进程已终止，代码走不到这里。
    //    极端情况（destroy 抛异常或消息循环卡住）10 秒后强退。
    LogService.w(
      '[Exit] Reached fallback! Waiting 10 seconds before forced exit (Elapsed: ${stopwatch.elapsedMilliseconds}ms)',
    );
    await Future.delayed(const Duration(seconds: 10));
    LogService.w(
      '[Exit] Forcing exit(0) after timeout! (Elapsed: ${stopwatch.elapsedMilliseconds}ms)',
    );
    exit(0);
  }
}
