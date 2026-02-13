import 'dart:async';

import '../api/update_log_api.dart';
import '../utils/log_service.dart';
import '../utils/storage_utils.dart';
import '../utils/time_utils.dart';
import 'notification_window_service.dart';
import 'scheduler_service.dart';

/// 更新日志监控服务（单例）
///
/// 定期检查更新日志，当有新更新时发送通知
class UpdateLogMonitorService {
  static final UpdateLogMonitorService _instance =
      UpdateLogMonitorService._internal();
  factory UpdateLogMonitorService() => _instance;
  UpdateLogMonitorService._internal();

  final SchedulerService _scheduler = SchedulerService();

  /// 监控间隔（秒）
  static const int monitorIntervalSeconds = 300; // 5分钟检查一次

  /// 任务 ID
  static const String _taskId = 'update_log_monitor';

  /// 存储 key - 上次检查的更新时间
  static const String _lastCheckTimeKey = 'update_log_last_check_time';

  /// 是否已初始化
  bool _initialized = false;
  
  /// 通知开关
  bool _enabled = true;

  /// 依赖服务
  final UpdateLogApi _updateLogApi = UpdateLogApi();
  final NotificationWindowService _notificationService =
      NotificationWindowService();

  /// 初始化服务（应用启动时调用）
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _startMonitorLoop();
    LogService.i('[UpdateLogMonitor] 服务已初始化');
  }

  /// 启动监控循环
  void _startMonitorLoop() {
    if (_scheduler.hasTask(_taskId)) return;

    _scheduler.register(ScheduledTask(
      id: _taskId,
      name: '更新日志监控',
      interval: Intervals.fiveMinutes,
      callback: () async => checkForUpdates(),
    ));

    // 延迟10秒后执行首次检查，避免启动时立即弹出通知
    Future.delayed(const Duration(seconds: 10), () => checkForUpdates());
  }

  /// 停止监控循环
  void _stopMonitorLoop() {
    _scheduler.cancel(_taskId);
  }

  /// 检查更新日志
  Future<void> checkForUpdates() async {
    try {
      final lastCheckTime = StorageUtils.getString(_lastCheckTimeKey);

      // 获取最新的更新日志
      final response = await _updateLogApi.getUpdateLogs(
        pageIndex: 1,
        pageSize: 1,
        keyword: '',
      );

      if (response.items.isEmpty) return;

      final latestLog = response.items.first;
      final latestUpdateTime = latestLog.updateTime;

      // 如果是首次检查（没有记录），只记录时间不通知
      if (lastCheckTime == null || lastCheckTime.isEmpty) {
        await StorageUtils.setString(_lastCheckTimeKey, latestUpdateTime);
        LogService.i('[UpdateLogMonitor] 首次检查，记录时间: $latestUpdateTime');
        return;
      }

      // 使用时间戳比较，避免字符串格式不一致导致的问题
      final latestTime = TimeUtils.parseServerTime(latestUpdateTime);
      final lastTime = TimeUtils.parseServerTime(lastCheckTime);
      
      if (latestTime == null || lastTime == null) {
        LogService.w('[UpdateLogMonitor] 时间解析失败，使用字符串比较');
        // 降级到字符串比较
        if (latestUpdateTime != lastCheckTime) {
          await _sendUpdateNotification(latestLog, latestUpdateTime);
        }
        return;
      }

      // 比较时间戳，如果有新更新则通知
      if (latestTime.isAfter(lastTime)) {
        LogService.i('[UpdateLogMonitor] 检测到新更新: $latestUpdateTime (上次: $lastCheckTime)');
        await _sendUpdateNotification(latestLog, latestUpdateTime);
      }
    } catch (e) {
      LogService.e('[UpdateLogMonitor] 检查更新失败', e);
      // 异常时不影响应用运行，静默处理
    }
  }

  /// 发送更新通知
  Future<void> _sendUpdateNotification(dynamic latestLog, String latestUpdateTime) async {
    // 如果通知已禁用，不发送
    if (!_enabled) {
      LogService.d('[UpdateLogMonitor] 通知已禁用，跳过发送');
      // 仍然更新记录的时间，避免下次启用时重复通知
      await StorageUtils.setString(_lastCheckTimeKey, latestUpdateTime);
      return;
    }
    
    try {
      // 格式化时间（去掉秒）
      final displayTime = _formatUpdateTime(latestUpdateTime);

      // 发送通知（优先使用 rawHtml，否则使用 content）
      final htmlContent = latestLog.rawHtml.isNotEmpty 
          ? latestLog.rawHtml 
          : latestLog.content;
      await _notificationService.showUpdateLogNotification(
        updateTime: displayTime,
        content: htmlContent,
      );

      // 更新记录的时间（保存原始时间用于比较）
      await StorageUtils.setString(_lastCheckTimeKey, latestUpdateTime);
    } catch (e) {
      LogService.e('[UpdateLogMonitor] 发送通知失败', e);
    }
  }

  /// 格式化更新时间（转换为用户本地时区）
  String _formatUpdateTime(String updateTime) {
    // 使用 TimeUtils 解析服务器时间（北京时间 UTC+8）并转换为本地时间
    final localDateTime = TimeUtils.parseServerTime(updateTime);
    if (localDateTime == null) {
      // 解析失败时返回原始字符串
      return updateTime;
    }
    // 格式化为本地时间显示
    return '${localDateTime.year}年${localDateTime.month.toString().padLeft(2, '0')}月${localDateTime.day.toString().padLeft(2, '0')}日 ${localDateTime.hour.toString().padLeft(2, '0')}时${localDateTime.minute.toString().padLeft(2, '0')}分';
  }

  /// 获取最新的更新日志（用于测试）
  Future<void> testWithLatestLog() async {
    try {
      final response = await _updateLogApi.getUpdateLogs(
        pageIndex: 1,
        pageSize: 1,
        keyword: '',
      );

      if (response.items.isEmpty) {
        LogService.w('[UpdateLogMonitor] 没有更新日志');
        return;
      }

      final latestLog = response.items.first;
      final displayTime = _formatUpdateTime(latestLog.updateTime);

      // 优先使用 rawHtml，否则使用 content
      final htmlContent = latestLog.rawHtml.isNotEmpty 
          ? latestLog.rawHtml 
          : latestLog.content;
      await _notificationService.showUpdateLogNotification(
        updateTime: displayTime,
        content: htmlContent,
      );
    } catch (e) {
      LogService.e('[UpdateLogMonitor] 测试失败', e);
    }
  }

  /// 销毁服务
  void dispose() {
    _stopMonitorLoop();
    _initialized = false;
  }
  
  /// 通知是否启用
  bool get isEnabled => _enabled;
  
  /// 设置通知开关
  void setEnabled(bool enabled) {
    _enabled = enabled;
    LogService.d('[UpdateLogMonitor] 通知已${enabled ? '启用' : '禁用'}');
  }
}
