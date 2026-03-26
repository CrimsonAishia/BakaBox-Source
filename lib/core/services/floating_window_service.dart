import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

import '../utils/log_service.dart';
import '../utils/storage_utils.dart';

/// 浮窗类型
enum FloatingWindowType {
  queue, // 挤服
  launch, // 启动游戏
  connect, // 连接服务器
  status, // 通用状态
}

/// 浮窗配置
class FloatingWindowConfig {
  final FloatingWindowType type;
  final String? serverAddress;
  final String? title;
  final Map<String, dynamic>? extra;

  const FloatingWindowConfig({
    required this.type,
    this.serverAddress,
    this.title,
    this.extra,
  });

  /// 转换为 JSON 字符串
  String toJson() {
    return jsonEncode({
      'type': type.index,
      'serverAddress': serverAddress,
      'title': title,
      'extra': extra,
    });
  }

  /// 从 JSON 字符串解析
  static FloatingWindowConfig fromJson(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return FloatingWindowConfig(
        type: FloatingWindowType.values[map['type'] as int? ?? 0],
        serverAddress: map['serverAddress'] as String?,
        title: map['title'] as String?,
        extra: map['extra'] as Map<String, dynamic>?,
      );
    } catch (e) {
      debugPrint('[FloatingWindowConfig] Parse error: $e');
      return const FloatingWindowConfig(type: FloatingWindowType.status);
    }
  }

  /// 从 WindowController 的 arguments 解析
  static FloatingWindowConfig fromArguments(String arguments) {
    if (arguments.isEmpty) {
      return const FloatingWindowConfig(type: FloatingWindowType.status);
    }
    return fromJson(arguments);
  }

  /// 获取窗口尺寸
  Size get windowSize => const Size(280, 160);
}

/// 通用浮窗管理服务
class FloatingWindowService {
  static final FloatingWindowService _instance =
      FloatingWindowService._internal();
  factory FloatingWindowService() => _instance;
  FloatingWindowService._internal();

  /// 当前活跃的浮窗 windowId -> config (windowId 是 String UUID)
  final Map<String, FloatingWindowConfig> _activeWindows = {};

  /// 是否有活跃的浮窗
  bool get hasActiveWindow => _activeWindows.isNotEmpty;

  /// 获取指定类型的活跃窗口ID
  String? getWindowIdByType(FloatingWindowType type) {
    for (final entry in _activeWindows.entries) {
      if (entry.value.type == type) {
        return entry.key;
      }
    }
    return null;
  }

  /// 打开浮窗
  Future<String?> openWindow(FloatingWindowConfig config) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      LogService.w('Floating window only supported on desktop');
      return null;
    }

    try {
      LogService.d('Creating floating window: type=${config.type}');

      // 读取浮窗位置设置并添加到 extra 中
      final configWithPosition = _addPositionToConfig(config);

      // 创建窗口
      final controller = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: configWithPosition.toJson(),
        ),
      );

      final windowId = controller.windowId;
      _activeWindows[windowId] = config;

      LogService.d(
        'Floating window created: id=$windowId, type=${config.type}',
      );
      return windowId;
    } catch (e, stack) {
      LogService.e('Create floating window error: $e\n$stack');
      return null;
    }
  }

  /// 添加位置设置到配置中
  FloatingWindowConfig _addPositionToConfig(FloatingWindowConfig config) {
    try {
      // 从存储中读取浮窗位置设置
      final positionIndex =
          StorageUtils.getInt('floating_window_position') ?? 8; // 默认右下角

      // 将位置信息添加到 extra 中
      final extra = Map<String, dynamic>.from(config.extra ?? {});
      extra['floatingWindowPosition'] = positionIndex;

      return FloatingWindowConfig(
        type: config.type,
        serverAddress: config.serverAddress,
        title: config.title,
        extra: extra,
      );
    } catch (e) {
      LogService.w(
        'Failed to read floating window position, using default: $e',
      );
      return config;
    }
  }

  /// 关闭浮窗
  /// 发送关闭命令并从本地列表移除
  Future<bool> closeWindow(String windowId) async {
    _activeWindows.remove(windowId);
    LogService.d('Window removed from tracking: $windowId');

    // 发送关闭命令给窗口
    try {
      final controller = WindowController.fromWindowId(windowId);
      await controller.invokeMethod('window_close');
      LogService.d('Close command sent to window: $windowId');
    } catch (e) {
      // 窗口可能已经关闭，忽略错误
      LogService.d('Window may already be closed: $windowId, error: $e');
    }

    return true;
  }

  /// 关闭指定类型的浮窗
  Future<bool> closeWindowByType(FloatingWindowType type) async {
    final windowId = getWindowIdByType(type);
    if (windowId != null) {
      return closeWindow(windowId);
    }
    return true;
  }

  /// 关闭所有浮窗（非阻塞，快速返回）
  Future<void> closeAllWindows() async {
    final ids = List<String>.from(_activeWindows.keys);
    _activeWindows.clear(); // 立即清空列表

    // 并行发送关闭命令，不等待响应
    for (final id in ids) {
      try {
        final controller = WindowController.fromWindowId(id);
        // 使用 unawaited 发送关闭命令，不阻塞
        controller.invokeMethod('window_close').catchError((_) {});
      } catch (e) {
        // 忽略错误，窗口可能已经关闭
      }
    }
  }

  /// 聚焦浮窗
  Future<bool> focusWindow(String windowId) async {
    try {
      final controller = WindowController.fromWindowId(windowId);
      await controller.show();
      return true;
    } catch (e) {
      LogService.d('Focus floating window failed: $e');
      _activeWindows.remove(windowId);
      return false;
    }
  }

  /// 检查窗口是否仍然活跃
  bool isWindowActive(String windowId) {
    return _activeWindows.containsKey(windowId);
  }

  /// 标记窗口已关闭（由窗口自身调用）
  void markWindowClosed(String windowId) {
    _activeWindows.remove(windowId);
  }

  /// 向子窗口发送状态更新
  Future<bool> sendStateUpdate(
    String windowId, {
    required String state,
    String? message,
    String? subtitle,
    int? currentPlayers,
    int? targetPlayers,
    List<String>? threadStatuses,
    String? mapName,
    String? mapNameCn,
    String? mapBackground,
    int? autoDismissSeconds,
  }) async {
    if (!_activeWindows.containsKey(windowId)) {
      LogService.w('Window $windowId not found in active windows');
      return false;
    }

    try {
      final controller = WindowController.fromWindowId(windowId);

      // 总是包含所有 key，这样接收端可以区分 "未传递" 和 "传递了 null"
      final args = <String, dynamic>{
        'state': state,
        'message': message,
        'subtitle': subtitle,
        'currentPlayers': currentPlayers,
        'targetPlayers': targetPlayers,
        'threadStatuses': threadStatuses,
        'mapName': mapName,
        'mapNameCn': mapNameCn,
        'mapBackground': mapBackground,
        'autoDismissSeconds': autoDismissSeconds,
      };

      await controller.invokeMethod('updateState', args);

      LogService.d(
        'IPC state update sent to window $windowId: $state, message: $message',
      );
      return true;
    } catch (e) {
      LogService.e('IPC send state update error', e);
      // 如果是通道未注册错误，说明窗口已关闭，从活跃列表中移除
      if (e.toString().contains('CHANNEL_UNREGISTERED')) {
        _activeWindows.remove(windowId);
        LogService.w(
          'Window $windowId channel unregistered, removed from active windows',
        );
      }
      return false;
    }
  }

  /// 清理资源
  void dispose() {
    closeAllWindows();
  }
}
