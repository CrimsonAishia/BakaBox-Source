import 'dart:async';
import 'dart:io';

/// 应用程序退出服务
/// 负责完整的退出流程：停止服务、销毁窗口、退出进程
///
/// 桌面端通过 [registerDesktopExitHandler] 注册平台特定的退出逻辑，
/// 避免移动端引入桌面端依赖（window_manager、obs_server_service 等）。
class AppExitService {
  AppExitService._();

  static final AppExitService instance = AppExitService._();

  /// 桌面端退出处理器，由桌面端启动时注册
  Future<void> Function()? _desktopExitHandler;

  /// 注册桌面端退出处理器
  /// 在桌面端初始化时调用，注入平台特定的退出逻辑
  void registerDesktopExitHandler(Future<void> Function() handler) {
    _desktopExitHandler = handler;
  }

  /// 执行完整的应用退出流程
  Future<void> exitApplication() async {
    if (_desktopExitHandler != null) {
      await _desktopExitHandler!();
    } else {
      exit(0);
    }
  }
}
