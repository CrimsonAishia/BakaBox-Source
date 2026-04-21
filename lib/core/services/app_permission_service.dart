import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/log_service.dart';

// ─── TaskHandler（运行在独立 isolate）────────────────────────

/// 保活服务的任务处理器
///
/// 运行在独立 isolate 中，负责维持前台服务存活。
/// 不执行实际业务逻辑，仅保持服务运行。
class _LobbyKeepAliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // 服务启动，无需额外操作
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 无重复任务，使用 ForegroundTaskEventAction.nothing()
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // 服务销毁，无需额外操作
  }
}

/// 前台服务启动回调（必须是顶层函数）
@pragma('vm:entry-point')
void lobbyKeepAliveCallback() {
  FlutterForegroundTask.setTaskHandler(_LobbyKeepAliveTaskHandler());
}

// ─── AppPermissionService ────────────────────────────────────

/// 应用权限服务
///
/// 管理应用启动时需要的权限：
/// 1. 通知权限 - 接收广播消息
/// 2. 电池优化白名单 - 防止系统杀死后台进程
/// 3. 前台服务保活 - 维持 WebSocket 连接
class AppPermissionService {
  static const String _hiveBoxName = 'app_permissions';
  static const String _keyPermissionAsked = 'permission_asked';

  /// 初始化前台服务配置（应用启动时调用一次）
  ///
  /// 必须在 [startForegroundService] 之前调用。
  static void initForegroundService() {
    if (!Platform.isAndroid) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'bakabox_lobby_keepalive',
        channelName: 'BakaBox 大厅保活',
        channelDescription: '保持大厅连接不被系统中断',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// 是否已经询问过权限（每次安装只弹一次引导）
  static Future<bool> hasAskedPermissions() async {
    final box = await Hive.openBox(_hiveBoxName);
    return box.get(_keyPermissionAsked, defaultValue: false) as bool;
  }

  /// 标记已询问过权限
  static Future<void> markPermissionsAsked() async {
    final box = await Hive.openBox(_hiveBoxName);
    await box.put(_keyPermissionAsked, true);
  }

  /// 检查是否需要显示权限引导弹窗
  ///
  /// 仅在 Android 平台且未询问过时返回 true
  static Future<bool> shouldShowPermissionGuide() async {
    if (!Platform.isAndroid) return false;
    if (kIsWeb) return false;
    final asked = await hasAskedPermissions();
    return !asked;
  }

  /// 获取各权限当前状态
  static Future<PermissionStatusInfo> checkPermissionStatus() async {
    final notificationStatus = await Permission.notification.status;
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;

    return PermissionStatusInfo(
      notificationGranted: notificationStatus.isGranted,
      batteryOptimizationIgnored: batteryStatus.isGranted,
    );
  }

  /// 请求通知权限
  static Future<bool> requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      LogService.i('通知权限请求结果: $status');
      return status.isGranted;
    } catch (e) {
      LogService.e('请求通知权限失败', e);
      return false;
    }
  }

  /// 请求忽略电池优化
  static Future<bool> requestIgnoreBatteryOptimization() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      LogService.i('电池优化白名单请求结果: $status');
      return status.isGranted;
    } catch (e) {
      LogService.e('请求电池优化白名单失败', e);
      return false;
    }
  }

  /// 启动前台保活服务
  ///
  /// 服务已在运行时调用 [FlutterForegroundTask.restartService]，
  /// 确保 TaskHandler 始终处于活跃状态。
  static Future<void> startForegroundService() async {
    try {
      if (!Platform.isAndroid) return;

      final isRunning = await FlutterForegroundTask.isRunningService;
      if (isRunning) {
        // 服务已在运行，重启以确保 TaskHandler 活跃
        await FlutterForegroundTask.restartService();
        LogService.i('前台保活服务已重启');
      } else {
        final result = await FlutterForegroundTask.startService(
          serviceId: 1001,
          notificationTitle: 'BakaBox 大厅',
          notificationText: '正在连接大厅...',
          callback: lobbyKeepAliveCallback,
        );
        LogService.i('前台保活服务启动结果: $result');
      }
    } catch (e) {
      LogService.e('启动前台保活服务失败', e);
    }
  }

  /// 更新前台保活通知内容
  static Future<void> updateForegroundNotification({
    String? mapName,
    int? serverOnlineCount,
  }) async {
    try {
      if (!Platform.isAndroid) return;
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (!isRunning) return;

      final parts = <String>[];
      if (mapName != null && mapName.isNotEmpty) {
        parts.add(mapName);
      }
      if (serverOnlineCount != null && serverOnlineCount > 0) {
        parts.add('$serverOnlineCount 人在线');
      }

      final text = parts.isNotEmpty ? parts.join('  ·  ') : '大厅连接中...';

      await FlutterForegroundTask.updateService(
        notificationTitle: 'BakaBox 大厅',
        notificationText: text,
      );
    } catch (e) {
      // 静默失败，不影响核心功能
    }
  }

  /// 停止前台保活服务
  static Future<void> stopForegroundService() async {
    try {
      if (!Platform.isAndroid) return;
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (!isRunning) return;
      await FlutterForegroundTask.stopService();
      LogService.i('前台保活服务已停止');
    } catch (e) {
      LogService.e('停止前台保活服务失败', e);
    }
  }
}

/// 权限状态信息
class PermissionStatusInfo {
  final bool notificationGranted;
  final bool batteryOptimizationIgnored;

  const PermissionStatusInfo({
    required this.notificationGranted,
    required this.batteryOptimizationIgnored,
  });

  /// 是否所有权限都已授予
  bool get allGranted => notificationGranted && batteryOptimizationIgnored;
}
