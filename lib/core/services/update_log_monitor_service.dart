import 'dart:async';

import '../api/update_log_api.dart';
import '../utils/log_service.dart';
import '../utils/storage_utils.dart';
import '../utils/time_utils.dart';
import 'notification_window_service.dart';
import 'realtime/realtime_workshop_changelog_channel.dart';
import 'realtime_service.dart';

/// 更新日志监控服务（单例）
///
/// 通过 WebSocket 实时推送接收更新日志通知，当有新更新时发送桌面通知。
class UpdateLogMonitorService {
  static final UpdateLogMonitorService _instance =
      UpdateLogMonitorService._internal();
  factory UpdateLogMonitorService() => _instance;
  UpdateLogMonitorService._internal();

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
  final RealtimeWorkshopChangelogChannel _channel =
      RealtimeWorkshopChangelogChannel();

  /// WebSocket 事件订阅
  StreamSubscription<WorkshopChangelogEvent>? _subscription;

  /// 重连成功订阅
  StreamSubscription<void>? _reconnectedSubscription;

  /// 初始化服务（应用启动时调用）
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _subscribeRealtime();

    // 延迟 10 秒主动检查一次，覆盖应用关闭期间漏掉的更新
    Future.delayed(const Duration(seconds: 10), () => checkForUpdates());

    LogService.i('[UpdateLogMonitor] 服务已初始化（实时推送模式）');
  }

  /// 订阅实时推送频道
  void _subscribeRealtime() {
    _channel.subscribe();
    _subscription = _channel.events.listen(_onWorkshopChangelogEvent);
    // workshop.changelog 频道不回放断线期间的更新，监听对账信号主动检查一次
    // （reconcileStream 覆盖断线重连 + 连接保持期间的周期性兜底，
    //   checkForUpdates 内部基于上次记录时间判断，不会重复通知）
    _reconnectedSubscription = RealtimeService().reconcileStream.listen((_) {
      LogService.d('[UpdateLogMonitor] 对账信号，主动检查更新');
      checkForUpdates();
    });
  }

  /// 取消订阅实时推送频道
  void _unsubscribeRealtime() {
    _subscription?.cancel();
    _subscription = null;
    _reconnectedSubscription?.cancel();
    _reconnectedSubscription = null;
    _channel.unsubscribe();
  }

  /// 启动时主动检查一次更新（覆盖离线期间的更新）
  Future<void> checkForUpdates() async {
    try {
      final lastCheckTime = StorageUtils.getString(_lastCheckTimeKey);

      final response = await _updateLogApi.getUpdateLogs(
        pageIndex: 1,
        pageSize: 1,
        keyword: '',
      );

      if (response.items.isEmpty) return;

      final latestLog = response.items.first;
      final latestUpdateTime = latestLog.updateTime;

      // 首次检查（没有记录），只记录时间不通知
      if (lastCheckTime == null || lastCheckTime.isEmpty) {
        await StorageUtils.setString(_lastCheckTimeKey, latestUpdateTime);
        LogService.i('[UpdateLogMonitor] 首次检查，记录时间: $latestUpdateTime');
        return;
      }

      final latestTime = TimeUtils.parseServerTime(latestUpdateTime);
      final lastTime = TimeUtils.parseServerTime(lastCheckTime);

      if (latestTime == null || lastTime == null) {
        if (latestUpdateTime != lastCheckTime) {
          await _sendNotification(latestLog, latestUpdateTime);
        }
        return;
      }

      if (latestTime.isAfter(lastTime)) {
        LogService.i(
          '[UpdateLogMonitor] 检测到离线期间新更新: $latestUpdateTime (上次: $lastCheckTime)',
        );
        await _sendNotification(latestLog, latestUpdateTime);
      }
    } catch (e) {
      LogService.e('[UpdateLogMonitor] 启动检查更新失败', e);
    }
  }

  /// 处理实时推送事件
  Future<void> _onWorkshopChangelogEvent(WorkshopChangelogEvent event) async {
    LogService.i(
      '[UpdateLogMonitor] 收到实时推送: workshopItemId=${event.workshopItemId}, '
      'updateTime=${event.updateTime}',
    );

    if (!_enabled) {
      LogService.d('[UpdateLogMonitor] 通知已禁用，跳过');
      return;
    }

    try {
      // 使用推送中的内容直接通知
      if (event.content.isNotEmpty) {
        final displayTime = _formatUnixTime(event.updateTime);
        await _notificationService.showUpdateLogNotification(
          updateTime: displayTime,
          content: event.content,
        );
        // 更新本地记录时间（转为服务端北京时间格式，与 API 返回格式一致）
        await StorageUtils.setString(
          _lastCheckTimeKey,
          _unixToServerTimeString(event.updateTime),
        );
        return;
      }

      // 如果推送中没有内容，回退到 API 获取最新日志详情
      await _fetchAndNotify();
    } catch (e) {
      LogService.e('[UpdateLogMonitor] 处理实时推送失败', e);
    }
  }

  /// 通过 API 获取最新日志并发送通知
  Future<void> _fetchAndNotify() async {
    try {
      final response = await _updateLogApi.getUpdateLogs(
        pageIndex: 1,
        pageSize: 1,
        keyword: '',
      );

      if (response.items.isEmpty) return;

      final latestLog = response.items.first;
      await _sendNotification(latestLog, latestLog.updateTime);
    } catch (e) {
      LogService.e('[UpdateLogMonitor] 获取最新日志失败', e);
    }
  }

  /// 发送通知并更新本地记录时间
  Future<void> _sendNotification(
    dynamic latestLog,
    String latestUpdateTime,
  ) async {
    if (!_enabled) {
      // 即使通知禁用，仍更新记录时间，避免启用后重复通知
      await StorageUtils.setString(_lastCheckTimeKey, latestUpdateTime);
      return;
    }

    final displayTime = _formatUpdateTime(latestUpdateTime);
    final htmlContent = latestLog.rawHtml.isNotEmpty
        ? latestLog.rawHtml
        : latestLog.content;

    await _notificationService.showUpdateLogNotification(
      updateTime: displayTime,
      content: htmlContent,
    );
    await StorageUtils.setString(_lastCheckTimeKey, latestUpdateTime);
  }

  /// 格式化 Unix 时间戳（秒）为本地时间显示
  String _formatUnixTime(int unixSeconds) {
    if (unixSeconds <= 0) return '';
    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    ).toLocal();
    return '${dateTime.year}年${dateTime.month.toString().padLeft(2, '0')}月'
        '${dateTime.day.toString().padLeft(2, '0')}日 '
        '${dateTime.hour.toString().padLeft(2, '0')}时'
        '${dateTime.minute.toString().padLeft(2, '0')}分';
  }

  /// 将 Unix 时间戳（秒）转为服务端北京时间格式字符串
  /// 格式："2025-06-06 15:30:00"，与 API 返回的 updateTime 格式一致
  String _unixToServerTimeString(int unixSeconds) {
    if (unixSeconds <= 0) return '';
    // Unix 时间戳是 UTC，加 8 小时得到北京时间
    final beijingTime = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    ).add(const Duration(hours: 8));
    return '${beijingTime.year}-'
        '${beijingTime.month.toString().padLeft(2, '0')}-'
        '${beijingTime.day.toString().padLeft(2, '0')} '
        '${beijingTime.hour.toString().padLeft(2, '0')}:'
        '${beijingTime.minute.toString().padLeft(2, '0')}:'
        '${beijingTime.second.toString().padLeft(2, '0')}';
  }

  /// 格式化更新时间字符串（服务器北京时间）为本地时间显示
  String _formatUpdateTime(String updateTime) {
    final localDateTime = TimeUtils.parseServerTime(updateTime);
    if (localDateTime == null) return updateTime;
    return '${localDateTime.year}年${localDateTime.month.toString().padLeft(2, '0')}月'
        '${localDateTime.day.toString().padLeft(2, '0')}日 '
        '${localDateTime.hour.toString().padLeft(2, '0')}时'
        '${localDateTime.minute.toString().padLeft(2, '0')}分';
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
    _unsubscribeRealtime();
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
