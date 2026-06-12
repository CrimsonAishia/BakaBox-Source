import 'dart:async';

import '../api/server_api.dart';
import '../models/server_models.dart';
import '../utils/log_service.dart';
import '../utils/map_runtime_utils.dart';
import 'console_log_service.dart';
import 'game_status_service.dart';
import 'notification_window_service.dart';
import 'realtime/realtime_server_map_runtime_channel.dart';
import 'scheduler_service.dart';
import 'server_address_mapping_service.dart';
import '../utils/server_resolver_utils.dart';

/// 热身监控服务（单例）
///
/// 工作模式：
/// 1. 通过 [ConsoleLogService] 跟踪用户当前连接的服务器
/// 2. 通过 `server.map.runtime` WS 频道实时拿到换图事件，避免轮询服务器列表
/// 3. 检测到地图变化后，调用 `getMapRuntime` 获取热身倒计时；热身期间使用 1s 定时器更新通知
class WarmupMonitorService {
  static final WarmupMonitorService _instance =
      WarmupMonitorService._internal();
  factory WarmupMonitorService() => _instance;
  WarmupMonitorService._internal();

  final ConsoleLogService _consoleLogService = ConsoleLogService();
  final NotificationWindowService _notificationService =
      NotificationWindowService();
  final ServerApi _serverApi = ServerApi();
  final GameStatusService _gameStatusService = GameStatusService();
  final SchedulerService _scheduler = SchedulerService();
  final ServerAddressMappingService _addressMapping =
      ServerAddressMappingService();
  final RealtimeServerMapRuntimeChannel _realtimeChannel =
      RealtimeServerMapRuntimeChannel();

  // 热身倒计时刷新任务（仅热身期间运行）
  static const String _taskId = 'warmup_monitor';

  String? _currentServerAddress; // IP 地址（从游戏日志获取）
  String? _currentServerDomainAddress; // 域名地址（用于 API 调用 + WS 匹配）
  String? _currentServerName;
  String? _currentMapName;
  MapRuntimeData? _currentMapRuntime;
  int? _currentMapRuntimeFetchedAt;
  MapData? _currentMapInfo;
  bool _isWarmingUp = false;
  bool _enabled = true;

  StreamSubscription<ConsoleLogState>? _consoleStateSubscription;
  StreamSubscription<GameStatusEvent>? _gameStatusSubscription;
  StreamSubscription<ServerMapRuntimeEvent>? _realtimeSubscription;
  bool _realtimeSubscribed = false;
  GameState _lastGameState = GameState.unknown;

  /// 初始化服务
  Future<void> initialize() async {
    _consoleStateSubscription?.cancel();
    _consoleStateSubscription = _consoleLogService.stateStream.listen(
      _onConsoleStateChanged,
    );

    _gameStatusSubscription?.cancel();
    _gameStatusSubscription = _gameStatusService.statusStream.listen(
      _onGameStatusChanged,
    );

    await _addressMapping.load();

    _restoreStateFromConsoleLog();

    LogService.d('[WarmupMonitor] 服务已初始化（WS 驱动）');
  }


  void _ensureRealtimeSubscribed() {
    if (_realtimeSubscribed) return;
    _realtimeSubscribed = true;
    _realtimeChannel.subscribe();
    _realtimeSubscription = _realtimeChannel.events.listen(_onRealtimeEvent);
  }

  void _stopRealtime() {
    if (!_realtimeSubscribed) return;
    _realtimeSubscribed = false;
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _realtimeChannel.unsubscribe();
  }

  void _onRealtimeEvent(ServerMapRuntimeEvent event) {
    final apiAddress = _currentServerDomainAddress;
    if (apiAddress == null) return;

    if (event.kind == ServerMapRuntimeEventKind.snapshot) {
      // 用 snapshot 给当前服务器对齐地图，但不立刻判断热身（让 changed 事件来触发）
      final entry = _realtimeChannel.snapshotFor(apiAddress);
      if (entry != null && _currentMapName == null) {
        _onMapDetected(entry.mapName);
      }
      return;
    }

    for (final entry in event.entries) {
      if (entry.serverAddress != apiAddress) continue;
      _onMapDetected(entry.mapName);
    }
  }

  Future<void> _onMapDetected(String mapName) async {
    if (mapName == 'graphics_settings') return;
    if (_currentServerAddress == null) return;
    if (mapName == _currentMapName) return;

    final oldMap = _currentMapName;
    _currentMapName = mapName;
    _currentMapRuntime = null;
    _currentMapRuntimeFetchedAt = null;
    _currentMapInfo = null;

    if (_isWarmingUp) {
      _isWarmingUp = false;
      await _notificationService.dismissWarmupNotification(
        _currentServerAddress!,
      );
      _stopWarmupTimer();
    }

    LogService.d('[WarmupMonitor] 地图变化: $oldMap -> $mapName');

    // 限制：只监控默认分类的服务器
    final apiAddress = _currentServerDomainAddress ?? _currentServerAddress!;
    if (!_addressMapping.isDefaultCategoryServer(apiAddress)) {
      LogService.d('[WarmupMonitor] 非默认分类服务器，跳过热身监控: $apiAddress');
      return;
    }

    MapData? mapInfo;
    try {
      mapInfo = await _serverApi.getMapInfo(mapName);
    } catch (_) {}
    // await 期间又发生了换图，本次结果已过期，直接丢弃，避免覆盖新地图状态
    if (mapName != _currentMapName) {
      LogService.d('[WarmupMonitor] getMapInfo 返回时地图已变化，丢弃过期结果: $mapName');
      return;
    }
    _currentMapInfo = mapInfo;

    MapRuntimeData? runtime;
    try {
      runtime = await _serverApi.getMapRuntime(apiAddress, mapName);
    } catch (e) {
      LogService.e('[WarmupMonitor] 获取地图运行时间失败', e);
      if (mapName == _currentMapName) _currentMapName = null;
      return;
    }
    // 同样校验：await 期间地图可能已经又变了
    if (mapName != _currentMapName) {
      LogService.d('[WarmupMonitor] getMapRuntime 返回时地图已变化，丢弃过期结果: $mapName');
      return;
    }

    if (runtime == null) {
      _currentMapName = null;
      return;
    }
    _currentMapRuntime = runtime;
    _currentMapRuntimeFetchedAt = DateTime.now().millisecondsSinceEpoch;

    final warmupDuration = MapRuntimeUtils.getWarmupDuration(mapName);
    if (warmupDuration == null) return;

    final apiRuntime = _currentMapRuntime!.currentRuntime;
    if (apiRuntime > warmupDuration) return;

    _isWarmingUp = true;
    _startWarmupTimer();
    _showWarmupNotification();
    LogService.d('[WarmupMonitor] 检测到热身: $mapName, runtime=$apiRuntime');
  }


  void _startWarmupTimer() {
    _scheduler.cancel(_taskId);
    _scheduler.register(
      ScheduledTask(
        id: _taskId,
        name: '热身倒计时',
        interval: const Duration(seconds: 1),
        callback: _tickWarmup,
      ),
    );
  }

  void _stopWarmupTimer() {
    _scheduler.cancel(_taskId);
  }

  Future<void> _tickWarmup() async {
    if (!_isWarmingUp) {
      _stopWarmupTimer();
      return;
    }

    final remaining = MapRuntimeUtils.getWarmupTimeRemaining(
      _currentMapRuntime,
      fetchedAt: _currentMapRuntimeFetchedAt,
      mapName: _currentMapName,
    );

    if (remaining <= 0) {
      _isWarmingUp = false;
      _stopWarmupTimer();
      if (_currentServerAddress != null) {
        await _notificationService.dismissWarmupNotification(
          _currentServerAddress!,
        );
      }
      return;
    }

    _showWarmupNotification();
  }

  void _showWarmupNotification() {
    if (!_enabled) return;
    if (_currentServerAddress == null || _currentMapRuntime == null) return;

    final remaining = MapRuntimeUtils.getWarmupTimeRemaining(
      _currentMapRuntime,
      fetchedAt: _currentMapRuntimeFetchedAt,
      mapName: _currentMapName,
    );
    if (remaining <= 0) return;

    _notificationService.showWarmupNotification(
      serverAddress: _currentServerAddress!,
      serverName: _currentServerName ?? _currentServerAddress!,
      mapName: _currentMapName,
      mapNameCn: _currentMapInfo?.mapLabel,
      mapBackground: _currentMapInfo?.mapUrl,
      warmupRemainingSeconds: remaining,
    );
  }


  void _restoreStateFromConsoleLog() {
    if (!_gameStatusService.isGameRunning) return;
    final state = _consoleLogService.currentState;
    if (state.state == GameState.inGame && state.serverAddress.isNotEmpty) {
      _currentServerAddress = state.serverAddress;
      _currentServerDomainAddress = _addressMapping.getDomainAddress(
        state.serverAddress,
      );
      _ensureRealtimeSubscribed();
    }
  }

  void _onGameStatusChanged(GameStatusEvent event) {
    if (!event.isRunning) {
      _stopWarmupTimer();
      _stopRealtime();
      if (_isWarmingUp && _currentServerAddress != null) {
        _notificationService.dismissWarmupNotification(_currentServerAddress!);
        _isWarmingUp = false;
      }
      _currentServerAddress = null;
      _currentServerDomainAddress = null;
      _currentServerName = null;
      _currentMapName = null;
      _currentMapRuntime = null;
      _currentMapRuntimeFetchedAt = null;
      _currentMapInfo = null;
      _lastGameState = GameState.unknown;
    }
  }

  void _onConsoleStateChanged(ConsoleLogState state) {
    final newGameState = state.state;
    if (newGameState == _lastGameState) return;
    _lastGameState = newGameState;

    if (newGameState == GameState.inGame) {
      final serverAddress = state.serverAddress;
      if (serverAddress.isEmpty) return;

      if (serverAddress != _currentServerAddress) {
        if (_isWarmingUp && _currentServerAddress != null) {
          _notificationService.dismissWarmupNotification(
            _currentServerAddress!,
          );
        }
        _currentServerAddress = serverAddress;
        _currentServerDomainAddress = _addressMapping.getDomainAddress(
          serverAddress,
        );
        _currentServerName = null;

        _tryResolveServerName(
          _currentServerDomainAddress ?? _currentServerAddress!,
        );

        _currentMapName = null;
        _currentMapRuntime = null;
        _currentMapRuntimeFetchedAt = null;
        _currentMapInfo = null;
        _isWarmingUp = false;
        _stopWarmupTimer();

        _ensureRealtimeSubscribed();

        // 立即从 snapshot 取一次
        final apiAddress =
            _currentServerDomainAddress ?? _currentServerAddress!;
        final entry = _realtimeChannel.snapshotFor(apiAddress);
        if (entry != null) {
          _onMapDetected(entry.mapName);
        }
      }
    } else if (newGameState == GameState.mainMenu ||
        newGameState == GameState.unknown ||
        newGameState == GameState.failed) {
      if (_isWarmingUp && _currentServerAddress != null) {
        _notificationService.dismissWarmupNotification(_currentServerAddress!);
        _isWarmingUp = false;
      }
      _stopWarmupTimer();
      _currentServerAddress = null;
      _currentServerDomainAddress = null;
      _currentServerName = null;
      _currentMapName = null;
      _currentMapRuntime = null;
      _currentMapRuntimeFetchedAt = null;
      _stopRealtime();
    }
  }

  Future<void> _tryResolveServerName(String address) async {
    try {
      final name = await ServerResolverUtils.resolveServerName(address);
      if (name != null) {
        _currentServerName = name;
        LogService.d('[WarmupMonitor] 全局解析到服务器名称: $_currentServerName');
      }
    } catch (e) {
      LogService.e('[WarmupMonitor] 尝试解析服务器名称失败: $address', e);
    }
  }


  /// 获取当前数据源（向外暴露用于诊断）
  String get dataSource => 'WS';

  /// GSI 是否可用（保留以兼容历史调用，固定 false）
  bool get isGsiAvailable => false;

  bool get isEnabled => _enabled;

  void setEnabled(bool enabled) {
    _enabled = enabled;
    LogService.d('[WarmupMonitor] 热身通知已${enabled ? '启用' : '禁用'}');
    if (!enabled && _isWarmingUp && _currentServerAddress != null) {
      _notificationService.dismissWarmupNotification(_currentServerAddress!);
    }
  }

  void dispose() {
    _stopWarmupTimer();
    _stopRealtime();
    _consoleStateSubscription?.cancel();
    _gameStatusSubscription?.cancel();
    if (_isWarmingUp && _currentServerAddress != null) {
      _notificationService.dismissWarmupNotification(_currentServerAddress!);
    }
  }
}
