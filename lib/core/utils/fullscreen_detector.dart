import 'dart:ffi';
import 'dart:io';

import 'log_service.dart';

/// Windows 用户通知状态枚举
/// 对应 QUERY_USER_NOTIFICATION_STATE
enum UserNotificationState {
  /// 用户不在（锁屏/屏保/用户切换）
  notPresent, // QUNS_NOT_PRESENT = 1
  /// 全屏应用运行中（F11 全屏、游戏等）
  busy, // QUNS_BUSY = 2
  /// D3D 独占全屏模式
  runningD3DFullScreen, // QUNS_RUNNING_D3D_FULL_SCREEN = 3
  /// 演示模式
  presentationMode, // QUNS_PRESENTATION_MODE = 4
  /// 可以接收通知
  acceptsNotifications, // QUNS_ACCEPTS_NOTIFICATIONS = 5
  /// 静默时间
  quietTime, // QUNS_QUIET_TIME = 6
  /// Windows Store 应用运行中（Windows 8+）
  app, // QUNS_APP = 7
}

/// 全屏检测器
/// 使用 Windows API SHQueryUserNotificationState 检测是否有全屏应用运行
class FullscreenDetector {
  static FullscreenDetector? _instance;
  static FullscreenDetector get instance => _instance ??= FullscreenDetector._();

  FullscreenDetector._();

  // Windows API 函数签名
  // HRESULT SHQueryUserNotificationState(QUERY_USER_NOTIFICATION_STATE *pquns)
  DynamicLibrary? _shell32;
  int Function(Pointer<Int32>)? _shQueryUserNotificationState;
  bool _initialized = false;

  /// 初始化 Windows API
  void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    if (!Platform.isWindows) {
      _shell32 = null;
      _shQueryUserNotificationState = null;
      return;
    }

    try {
      _shell32 = DynamicLibrary.open('shell32.dll');
      _shQueryUserNotificationState = _shell32!
          .lookupFunction<Int32 Function(Pointer<Int32>), int Function(Pointer<Int32>)>(
        'SHQueryUserNotificationState',
      );
      LogService.d('[FullscreenDetector] Initialized successfully');
    } catch (e) {
      LogService.e('[FullscreenDetector] Failed to initialize: $e');
      _shell32 = null;
      _shQueryUserNotificationState = null;
    }
  }

  /// 查询当前用户通知状态
  UserNotificationState? queryNotificationState() {
    _ensureInitialized();

    if (_shQueryUserNotificationState == null) {
      return null;
    }

    final pquns = _allocateInt32();
    try {
      final result = _shQueryUserNotificationState!(pquns);
      if (result == 0) {
        // S_OK
        final state = pquns.value;
        // API 返回值从 1 开始，枚举从 0 开始
        if (state >= 1 && state <= 7) {
          return UserNotificationState.values[state - 1];
        }
      }
      return null;
    } finally {
      _freeMemory(pquns);
    }
  }

  /// 检测是否有 D3D 独占全屏应用正在运行
  /// 返回 true 表示有独占全屏应用，不应该创建子窗口
  bool isFullscreenAppRunning() {
    final state = queryNotificationState();
    if (state == null) {
      // 无法检测，默认允许
      return false;
    }

    // 只检测 D3D 独占全屏模式，其他模式不影响
    if (state == UserNotificationState.runningD3DFullScreen) {
      LogService.d('[FullscreenDetector] D3D exclusive fullscreen detected');
      return true;
    }
    return false;
  }

  /// 检测是否可以安全地创建子窗口
  /// 返回 true 表示可以创建
  bool canCreateWindow() {
    return !isFullscreenAppRunning();
  }
}

// 简单的内存分配，使用 msvcrt
final DynamicLibrary _msvcrt = Platform.isWindows 
    ? DynamicLibrary.open('msvcrt.dll') 
    : DynamicLibrary.process();

final Pointer<Void> Function(int) _malloc = _msvcrt
    .lookupFunction<Pointer<Void> Function(IntPtr), Pointer<Void> Function(int)>('malloc');

final void Function(Pointer<Void>) _free = _msvcrt
    .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('free');

Pointer<Int32> _allocateInt32() {
  return _malloc(4).cast<Int32>(); // Int32 = 4 bytes
}

void _freeMemory(Pointer pointer) {
  _free(pointer.cast<Void>());
}
