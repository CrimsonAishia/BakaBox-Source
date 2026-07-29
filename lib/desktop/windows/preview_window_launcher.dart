import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../widgets/position_preview_window.dart';

/// 位置预览窗口启动器
class PreviewWindowLauncher {
  PreviewWindowLauncher._();

  /// 启动位置预览窗口
  static Future<void> launch(WindowController controller) async {
    final config = PositionPreviewConfig.fromArguments(controller.arguments);

    // 设置 IPC 处理器
    await _setupMethodHandler(controller);

    runApp(PositionPreviewWindowApp(config: config));
  }

  /// 设置窗口方法处理器
  static Future<void> _setupMethodHandler(WindowController controller) async {
    await controller.setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'window_close':
        case 'close_self':
          await windowManager.close();
          return true;
        case 'updatePosition':
          final args = call.arguments as Map<dynamic, dynamic>;
          final x = (args['x'] as num?)?.toDouble() ?? 0;
          final y = (args['y'] as num?)?.toDouble() ?? 0;
          await windowManager.setPosition(Offset(x, y));
          return true;
        default:
          throw MissingPluginException('Not implemented: ${call.method}');
      }
    });
  }
}
