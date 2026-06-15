import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/bootstrap/app_initializer.dart';
import '../../core/services/single_instance_service.dart';
import '../../core/services/webview_environment_service.dart';
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

    // 主窗口需要单实例检查。
    // 必须在初始化存储（Hive）之前完成：若已有实例运行，当前进程要在
    // 打开被独占锁定的 box 文件之前就退出，否则会卡死并残留进程。
    if (!isSubWindow) {
      final canStart = await SingleInstanceService.instance
          .ensureSingleInstance(args);
      if (!canStart) {
        // 已有实例在运行（且已被唤醒），当前进程干净退出
        exit(0);
      }
    }

    // 初始化桌面端基础服务（子窗口跳过存储初始化）
    await AppInitializer.initDesktopBase(
      skipStorage: isSubWindow,
      onPlatformInit: () => windowManager.ensureInitialized(),
    );

    // 初始化 WebView2 环境（必须在 AppDirectoryService.init 之后、
    // 创建任何 InAppWebView 之前），将缓存指向可写的项目缓存目录，
    // 避免安装在 Program Files 等只读目录时无法写入。
    await WebViewEnvironmentService.init();

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
