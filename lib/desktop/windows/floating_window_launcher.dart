import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/services/floating_window_service.dart';
import '../widgets/floating_window/floating_window_app.dart';
import '../widgets/floating_window/floating_window_state.dart';

/// 浮动窗口启动器
class FloatingWindowLauncher {
  FloatingWindowLauncher._();

  /// 启动浮动窗口
  static Future<void> launch(
    WindowController controller,
    FloatingWindowConfig config,
  ) async {
    final windowId = controller.windowId;

    // 创建状态通知器，用于 IPC 状态更新
    final stateNotifier = FloatingWindowStateNotifier();

    // 从 config.extra 解析初始状态并立即初始化
    final initialState = FloatingWindowState.fromMap(config.extra);
    stateNotifier.initialize(initialState);
    debugPrint('[FloatingWindow] Pre-initialized state: ${initialState.state}');

    // 设置 IPC 处理器
    await _setupMethodHandler(controller, stateNotifier);

    runApp(
      FloatingWindowApp(
        config: config,
        windowId: windowId,
        stateNotifier: stateNotifier,
      ),
    );
  }

  /// 设置窗口方法处理器
  static Future<void> _setupMethodHandler(
    WindowController controller,
    FloatingWindowStateNotifier stateNotifier,
  ) async {
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
  }
}
