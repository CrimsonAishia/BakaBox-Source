import 'dart:async';

import '../utils/log_service.dart';
import '../utils/platform_utils.dart';
import 'game_launcher_service.dart';
import 'scheduler_service.dart';

/// 游戏状态变化事件
class GameStatusEvent {
  final bool isRunning;
  final bool isMonitorable;
  final DateTime timestamp;
  final String? gameType; // 游戏类型：'cs2' 或 'csgo'

  const GameStatusEvent({
    required this.isRunning,
    required this.isMonitorable,
    required this.timestamp,
    this.gameType,
  });
}

/// 游戏状态管理服务 - 桌面端专属功能
///
/// 职责：
/// - 监控游戏进程是否运行（每3秒检测一次）
/// - 检测游戏是否带 -condebug 启动（可监控状态）
/// - 发送游戏运行/退出事件
///
/// 注意：console.log 相关操作由 ConsoleLogService 负责
class GameStatusService {
  final GameLauncherService _gameLauncher = GameLauncherService();

  // 状态
  bool _isGameRunning = false;
  bool _isMonitorable = false; // 是否可监控（带 -condebug 启动）
  DateTime? _lastGameStartTime;
  String? _runningGameType; // 当前运行的游戏类型：'cs2' 或 'csgo'

  // 监控
  bool _isMonitoring = false;
  final SchedulerService _scheduler = SchedulerService();
  static const String _taskId = 'game_status_monitor';

  // 事件流
  final _statusController = StreamController<GameStatusEvent>.broadcast();

  /// 状态变化流
  Stream<GameStatusEvent> get statusStream => _statusController.stream;

  /// 游戏是否运行中
  bool get isGameRunning => _isGameRunning;

  /// 是否可监控（带 -condebug 启动）
  bool get isMonitorable => _isMonitorable;

  /// 被监控的游戏（CS2）是否正在运行
  ///
  /// 本项目只监控 CS2。独立版 CSGO (csgo.exe) 与 CS:Source (hl2.exe)
  /// 虽然会让 [isGameRunning] 为真（挤服 / 连接 / 启动流程需要这个广义判断），
  /// 但它们不属于监控范围。需要判断"是否应当监控 / 提示无法监控"时，
  /// 必须使用本 getter，避免连接 CS:Source 服务器或启动独立版 CSGO 时
  /// 被误判为"游戏已启动但无法监控"。
  bool get isMonitoredGameRunning =>
      _isGameRunning && _runningGameType == 'cs2';

  /// 是否正在监控
  bool get isMonitoring => _isMonitoring;

  /// 当前运行的游戏类型（'cs2' 或 'csgo'）
  String? get runningGameType => _runningGameType;

  /// 单例模式
  static final GameStatusService _instance = GameStatusService._internal();
  factory GameStatusService() => _instance;
  GameStatusService._internal();

  /// 检查是否为桌面平台
  bool get isDesktopPlatform => PlatformUtils.isDesktopPlatform;

  /// 开始监控游戏状态
  Future<void> startMonitoring() async {
    if (_isMonitoring) {
      return;
    }

    _isMonitoring = true;

    // 初始检测
    await _checkGameStatus();

    // 启动定时监控（每3秒）
    _scheduler.register(
      ScheduledTask(
        id: _taskId,
        name: '游戏状态监控',
        interval: Intervals.threeSeconds,
        callback: () async {
          if (_isMonitoring) await _checkGameStatus();
        },
      ),
    );

    LogService.d('[GameStatus] 游戏状态监控已启动');
    return;
  }

  /// 停止监控
  void stopMonitoring() {
    if (!_isMonitoring) {
      return;
    }

    _scheduler.cancel(_taskId);
    _isMonitoring = false;

    LogService.d('[GameStatus] 游戏状态监控已停止');
    return;
  }

  /// 检查游戏状态
  Future<void> _checkGameStatus() async {
    final wasRunning = _isGameRunning;
    // isGameRunning 表示"任意受支持的游戏（CS2 / 独立版 CSGO / CS:Source）是否在运行"，
    // 挤服、连接、启动等流程都依赖这个广义判断。
    // 是否需要"监控"由 runningGameType == 'cs2' 单独判断（见 isMonitoredGameRunning）。
    final isRunning = await _gameLauncher.isCS2Running();

    _isGameRunning = isRunning;

    if (!wasRunning && isRunning) {
      // 游戏刚启动，检测游戏类型和是否可监控
      _lastGameStartTime = DateTime.now();
      await _detectGameType();
      await _checkIfMonitorable();

      LogService.d(
        '[GameStatus] 检测到游戏启动，类型: $_runningGameType, 可监控: $_isMonitorable',
      );

      _emitStatusEvent();
    } else if (wasRunning && !isRunning) {
      // 游戏刚关闭，清空游戏类型
      _isMonitorable = false;
      _runningGameType = null;

      LogService.d('[GameStatus] 检测到游戏关闭，已清空游戏类型');

      _emitStatusEvent();
    } else if (isRunning && !_isMonitorable) {
      // 游戏运行中但之前未检测到可监控，重新检测
      // 这处理了 BakaBox 启动后游戏才完全初始化的情况
      if (_runningGameType == null) {
        await _detectGameType();
      }
      await _checkIfMonitorable();
      if (_isMonitorable) {
        LogService.d('[GameStatus] 重新检测到游戏可监控');
        _emitStatusEvent();
      }
    }
  }

  /// 检测游戏类型
  Future<void> _detectGameType() async {
    final gameType = await _gameLauncher.getRunningGameType();
    _runningGameType = gameType;

    if (gameType != null) {
      LogService.d('[GameStatus] 检测到游戏类型: $gameType');
    } else {
      LogService.w('[GameStatus] 无法检测游戏类型');
    }
  }

  /// 检查游戏是否可监控
  ///
  /// 判断依据：检测游戏进程命令行是否包含 -condebug 参数
  Future<void> _checkIfMonitorable() async {
    final hasCondebug = await _gameLauncher.isCS2LaunchedWithCondebug();
    _isMonitorable = hasCondebug;

    if (hasCondebug) {
      LogService.d('[GameStatus] 检测到游戏带 -condebug 参数，可以监控');
    } else {
      LogService.d('[GameStatus] 游戏未带 -condebug 参数，无法监控');
    }
  }

  /// 标记游戏为可监控状态
  /// 在 GameLauncher 成功启动游戏后调用
  ///
  /// [gameType] 启动的游戏类型（'cs2' 或 'csgo'）
  void markAsMonitorable({String? gameType}) {
    _isMonitorable = true;
    _isGameRunning = true;
    _lastGameStartTime = DateTime.now();

    // 如果提供了游戏类型，保存它
    if (gameType != null) {
      _runningGameType = gameType;
      LogService.d('[GameStatus] 已标记游戏为可监控，类型: $gameType');
    } else {
      LogService.d('[GameStatus] 已标记游戏为可监控');
    }

    _emitStatusEvent();
  }

  /// 获取当前状态
  Map<String, dynamic> getStatus() {
    return {
      'success': true,
      'isRunning': _isGameRunning,
      'isMonitorable': _isMonitorable,
      'isMonitoring': _isMonitoring,
      'lastStartTime': _lastGameStartTime,
      'gameType': _runningGameType,
    };
  }

  /// 立即刷新状态
  Future<Map<String, dynamic>> refreshStatus() async {
    await _checkGameStatus();
    return getStatus();
  }

  /// 发送状态事件
  void _emitStatusEvent() {
    _statusController.add(
      GameStatusEvent(
        isRunning: _isGameRunning,
        isMonitorable: _isMonitorable,
        timestamp: DateTime.now(),
        gameType: _runningGameType,
      ),
    );
  }

  /// 清理资源
  void dispose() {
    stopMonitoring();
    _statusController.close();
  }
}
