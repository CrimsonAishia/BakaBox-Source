import 'dart:ffi';
import 'dart:io';

import 'log_service.dart';

/// Windows 进程优先级工具类
class WindowsPriorityUtils {
  WindowsPriorityUtils._();

  static const int _idlePriorityClass = 0x00000040;
  static const int _normalPriorityClass = 0x00000020;

  static DynamicLibrary? _kernel32;
  static int Function()? _getCurrentProcess;
  static int Function(int hProcess, int dwPriorityClass)? _setPriorityClass;

  static bool _initialized = false;

  static void _init() {
    if (_initialized || !Platform.isWindows) return;
    try {
      _kernel32 = DynamicLibrary.open('kernel32.dll');
      _getCurrentProcess = _kernel32!
          .lookupFunction<IntPtr Function(), int Function()>(
            'GetCurrentProcess',
          );

      _setPriorityClass = _kernel32!
          .lookupFunction<
            Int32 Function(IntPtr hProcess, Uint32 dwPriorityClass),
            int Function(int hProcess, int dwPriorityClass)
          >('SetPriorityClass');

      _initialized = true;
    } catch (e) {
      LogService.e('[WindowsPriorityUtils] 初始化 FFI 失败', e);
    }
  }

  /// 降低进程优先级至 Idle（系统空闲时才分配 CPU 资源，完美让路给游戏）
  static void setIdlePriority() {
    if (!Platform.isWindows) return;
    _init();
    if (_initialized &&
        _getCurrentProcess != null &&
        _setPriorityClass != null) {
      final hProcess = _getCurrentProcess!();
      final result = _setPriorityClass!(hProcess, _idlePriorityClass);
      if (result == 0) {
        LogService.e('[WindowsPriorityUtils] 降低进程优先级失败');
      }
    }
  }

  /// 恢复进程优先级至 Normal（正常模式）
  static void setNormalPriority() {
    if (!Platform.isWindows) return;
    _init();
    if (_initialized &&
        _getCurrentProcess != null &&
        _setPriorityClass != null) {
      final hProcess = _getCurrentProcess!();
      final result = _setPriorityClass!(hProcess, _normalPriorityClass);
      if (result == 0) {
        LogService.e('[WindowsPriorityUtils] 恢复进程优先级失败');
      }
    }
  }
}
