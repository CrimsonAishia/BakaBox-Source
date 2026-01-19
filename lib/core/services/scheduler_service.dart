import 'dart:async';
import '../utils/log_service.dart';

/// 定时任务配置
class ScheduledTask {
  final String id;
  final String name;
  final Duration interval;
  final Future<void> Function() callback;
  final bool runImmediately;

  ScheduledTask({
    required this.id,
    required this.name,
    required this.interval,
    required this.callback,
    this.runImmediately = false,
  });
}

/// 任务运行记录
class _TaskEntry {
  final ScheduledTask task;
  Timer? timer;
  DateTime? lastRunTime;
  bool isRunning = false;

  _TaskEntry(this.task);

  void cancel() {
    timer?.cancel();
    timer = null;
  }
}

/// 统一定时任务调度服务（单例）
///
/// 基于 Timer.periodic，集中管理所有定时任务
/// 支持任务注册、取消、状态查询
class SchedulerService {
  static final SchedulerService _instance = SchedulerService._internal();
  factory SchedulerService() => _instance;
  SchedulerService._internal();

  final Map<String, _TaskEntry> _tasks = {};

  /// 是否有任务在运行
  bool get isRunning => _tasks.values.any((e) => e.timer != null);

  /// 获取所有任务 ID
  Set<String> get taskIds => _tasks.keys.toSet();

  /// 获取任务上次运行时间
  DateTime? getLastRunTime(String taskId) => _tasks[taskId]?.lastRunTime;

  /// 注册定时任务
  void register(ScheduledTask task) {
    // 如果已存在，跳过
    if (_tasks.containsKey(task.id)) {
      LogService.d('[Scheduler] 任务已存在，跳过: ${task.id}');
      return;
    }

    final entry = _TaskEntry(task);

    // 创建定时器
    entry.timer = Timer.periodic(task.interval, (_) async {
      if (entry.isRunning) return; // 防止重入
      entry.isRunning = true;
      entry.lastRunTime = DateTime.now();

      LogService.d('[Scheduler] 执行任务: ${task.name} (${task.id})');
      try {
        await task.callback();
      } catch (e) {
        LogService.e('[Scheduler] 任务执行失败: ${task.name}', e);
      } finally {
        entry.isRunning = false;
      }
    });

    _tasks[task.id] = entry;

    LogService.d(
        '[Scheduler] 注册任务: ${task.name} (${task.id}), 间隔=${task.interval.inSeconds}秒');

    // 立即执行一次
    if (task.runImmediately) {
      entry.lastRunTime = DateTime.now();
      LogService.d('[Scheduler] 立即执行任务: ${task.name}');
      task.callback().catchError((e) {
        LogService.e('[Scheduler] 任务执行失败: ${task.name}', e);
      });
    }
  }

  /// 取消指定任务
  void cancel(String taskId) {
    final entry = _tasks.remove(taskId);
    if (entry != null) {
      entry.cancel();
      LogService.d('[Scheduler] 取消任务: $taskId');
    }
  }

  /// 取消所有任务
  void cancelAll() {
    for (final entry in _tasks.values) {
      entry.cancel();
    }
    _tasks.clear();
    LogService.d('[Scheduler] 已取消所有任务');
  }

  /// 检查任务是否存在
  bool hasTask(String taskId) => _tasks.containsKey(taskId);

  /// 获取调度状态摘要（用于调试）
  Map<String, dynamic> getStatus() {
    return {
      'isRunning': isRunning,
      'taskCount': _tasks.length,
      'tasks': _tasks.entries.map((e) {
        return {
          'id': e.key,
          'name': e.value.task.name,
          'interval': e.value.task.interval.inSeconds,
          'lastRun': e.value.lastRunTime?.toIso8601String(),
          'timerActive': e.value.timer != null,
        };
      }).toList(),
    };
  }

  /// 销毁服务
  void dispose() {
    cancelAll();
  }
}

/// 常用时间间隔
class Intervals {
  /// 1 分钟
  static const Duration oneMinute = Duration(minutes: 1);

  /// 5 分钟
  static const Duration fiveMinutes = Duration(minutes: 5);

  /// 10 分钟
  static const Duration tenMinutes = Duration(minutes: 10);

  /// 30 分钟
  static const Duration thirtyMinutes = Duration(minutes: 30);

  /// 1 小时
  static const Duration oneHour = Duration(hours: 1);

  /// 10 秒
  static const Duration tenSeconds = Duration(seconds: 10);

  /// 3 秒
  static const Duration threeSeconds = Duration(seconds: 3);

  /// 1 秒
  static const Duration oneSecond = Duration(seconds: 1);
}
