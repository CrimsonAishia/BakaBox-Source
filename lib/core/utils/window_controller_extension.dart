import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// WindowController 扩展
/// 用于在不同窗口之间进行 IPC 通信
extension WindowControllerExtension on WindowController {
  /// 初始化窗口方法处理器
  /// 在子窗口中调用，用于接收来自主窗口的命令
  Future<void> doCustomInitialize() async {
    return await setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'window_center':
          return await windowManager.center();
        case 'window_close':
          // 使用 destroy() 立即销毁窗口
          return await windowManager.destroy();
        case 'window_show':
          return await windowManager.show();
        case 'window_hide':
          return await windowManager.hide();
        case 'window_focus':
          return await windowManager.focus();
        default:
          throw MissingPluginException('Not implemented: ${call.method}');
      }
    });
  }

  /// 居中窗口
  Future<void> center() {
    return invokeMethod('window_center');
  }

  /// 关闭窗口
  Future<void> close() {
    return invokeMethod('window_close');
  }

  /// 显示窗口
  Future<void> show() {
    return invokeMethod('window_show');
  }

  /// 隐藏窗口
  Future<void> hide() {
    return invokeMethod('window_hide');
  }

  /// 聚焦窗口
  Future<void> focus() {
    return invokeMethod('window_focus');
  }
}
