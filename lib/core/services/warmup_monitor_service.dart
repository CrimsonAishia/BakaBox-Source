import 'dart:async';
import 'dart:io';

import '../api/server_api.dart';
import '../models/server_models.dart';
import '../utils/log_service.dart';
import '../utils/map_runtime_utils.dart';
import 'console_log_service.dart';
import 'game_status_service.dart';
import 'notification_window_service.dart';
import 'source_server_service.dart';

/// 热身监控服务（单例）
///
/// 监控用户当前所在服务器的热身状态：
/// 1. 通过 ConsoleLogService 获取用户当前所在服务器
/// 2. 定期查询该服务器的地图运行时间
/// 3. 如果检测到热身，显示通知
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

  Timer? _monitorTimer;
  String? _currentServerAddress; // IP 地址（从游戏日志获取）
  String? _currentServerDomainAddress; // 域名地址（用于 API 调用）
  String? _currentServerName;
  String? _currentMapName;
  MapRuntimeData? _currentMapRuntime;
  int? _currentMapRuntimeFetchedAt;
  MapData? _currentMapInfo;
  bool _isWarmingUp = false;

  StreamSubscription<ConsoleLogState>? _consoleStateSubscription;
  StreamSubscription<GameStatusEvent>? _gameStatusSubscription;
  GameState _lastGameState = GameState.unknown;
  String? _connectedServerAddress;

  // IP 到域名地址的映射缓存
  final Map<String, String> _ipToDomainCache = {};
  
  static const int normalIntervalSeconds = 2;
  static const int warmupIntervalSeconds = 1;

  /// 初始化服务
  Future<void> initialize() async {
    _consoleStateSubscription?.cancel();
    _consoleStateSubscription =
        _consoleLogService.stateStream.listen(_onConsoleStateChanged);

    // 监听游戏状态变化，游戏退出时关闭热身通知
    _gameStatusSubscription?.cancel();
    _gameStatusSubscription =
        _gameStatusService.statusStream.listen(_onGameStatusChanged);

    // 先加载服务器列表，建立 IP 到域名的映射
    await _loadServerAddressMapping();

    // 从 ConsoleLogService 获取当前状态（它已经分析过历史日志了）
    _restoreStateFromConsoleLog();
    
    _startMonitorLoop(isWarmup: false);
    
    LogService.i('[WarmupMonitor] 服务已初始化');
  }
  
  /// 从 ConsoleLogService 恢复当前状态
  void _restoreStateFromConsoleLog() {
    final state = _consoleLogService.currentState;
    if (state.state == GameState.inGame && state.serverAddress.isNotEmpty) {
      _connectedServerAddress = state.serverAddress;
      _currentServerAddress = state.serverAddress;
      _currentServerDomainAddress = _getDomainAddress(state.serverAddress);
      if (state.mapName.isNotEmpty) {
        _currentMapName = state.mapName;
      }
      LogService.d('[WarmupMonitor] 历史: 用户当前在服务器: ${state.serverAddress}, 地图: ${state.mapName}');
      _checkCurrentServer();
    } else {
      LogService.d('[WarmupMonitor] 历史: 用户当前未连接服务器');
    }
  }

  /// 游戏状态变化处理
  void _onGameStatusChanged(GameStatusEvent event) {
    if (!event.isRunning) {
      // 游戏退出，关闭热身通知并停止监控
      LogService.i('[WarmupMonitor] 游戏已退出，关闭热身通知并停止监控');
      
      // 停止监控定时器
      _monitorTimer?.cancel();
      _monitorTimer = null;
      
      // 关闭热身通知
      if (_isWarmingUp && _currentServerAddress != null) {
        _notificationService.dismissWarmupNotification(_currentServerAddress!);
        _isWarmingUp = false;
      }
      // 重置状态
      _connectedServerAddress = null;
      _currentServerAddress = null;
      _currentServerDomainAddress = null;
      _currentServerName = null;
      _currentMapName = null;
      _currentMapRuntime = null;
      _currentMapRuntimeFetchedAt = null;
      _currentMapInfo = null;
      _lastGameState = GameState.unknown;
    } else {
      // 游戏启动，重新开始监控
      if (_monitorTimer == null) {
        LogService.i('[WarmupMonitor] 游戏已启动，重新开始监控');
        _startMonitorLoop(isWarmup: false);
      }
    }
  }

  /// 加载服务器地址映射（IP -> 域名）
  Future<void> _loadServerAddressMapping() async {
    try {
      final categories = await _serverApi.getServerList();
      for (final category in categories) {
        for (final server in category.serverList) {
          final domainAddress = server.address;
          if (domainAddress != null && domainAddress.isNotEmpty) {
            final parts = domainAddress.split(':');
            if (parts.length == 2) {
              final host = parts[0];
              final port = parts[1];
              try {
                final addresses = await InternetAddress.lookup(host);
                if (addresses.isNotEmpty) {
                  final ip = addresses.first.address;
                  final ipAddress = '$ip:$port';
                  _ipToDomainCache[ipAddress] = domainAddress;
                }
              } catch (e) {
                // 如果是 IP 地址，直接使用
                _ipToDomainCache[domainAddress] = domainAddress;
              }
            }
          }
        }
      }
      LogService.d(
          '[WarmupMonitor] 地址映射加载完成，共 ${_ipToDomainCache.length} 个');
    } catch (e) {
      LogService.e('[WarmupMonitor] 加载服务器地址映射失败', e);
    }
  }

  String _getDomainAddress(String ipAddress) {
    return _ipToDomainCache[ipAddress] ?? ipAddress;
  }

  void _onConsoleStateChanged(ConsoleLogState state) {
    final newGameState = state.state;

    if (newGameState != _lastGameState) {
      _lastGameState = newGameState;

      if (newGameState == GameState.inGame) {
        final serverAddress = state.serverAddress;
        if (serverAddress.isNotEmpty) {
          _connectedServerAddress = serverAddress;
          LogService.i('[WarmupMonitor] 用户进入服务器: $serverAddress');

          if (serverAddress != _currentServerAddress) {
            if (_isWarmingUp && _currentServerAddress != null) {
              _notificationService
                  .dismissWarmupNotification(_currentServerAddress!);
            }
            _currentServerAddress = serverAddress;
            _currentServerDomainAddress = _getDomainAddress(serverAddress);
            _currentMapName = null;
            _currentMapRuntime = null;
            _currentMapRuntimeFetchedAt = null;
            _currentMapInfo = null;
            _isWarmingUp = false;
            _checkCurrentServer();
          }
        }
      } else if (newGameState == GameState.mainMenu ||
          newGameState == GameState.unknown ||
          newGameState == GameState.failed) {
        if (_connectedServerAddress != null) {
          LogService.i('[WarmupMonitor] 用户退出服务器');
          _connectedServerAddress = null;
        }
        if (_isWarmingUp && _currentServerAddress != null) {
          _notificationService
              .dismissWarmupNotification(_currentServerAddress!);
          _isWarmingUp = false;
        }
        _currentServerAddress = null;
        _currentServerDomainAddress = null;
        _currentServerName = null;
        _currentMapName = null;
        _currentMapRuntime = null;
      }
    }
  }

  void _startMonitorLoop({bool isWarmup = false}) {
    _monitorTimer?.cancel();
    final interval = isWarmup ? warmupIntervalSeconds : normalIntervalSeconds;
    _monitorTimer = Timer.periodic(
      Duration(seconds: interval),
      (_) => _checkCurrentServer(),
    );
  }

  Future<void> _checkCurrentServer() async {
    if (_connectedServerAddress == null || _connectedServerAddress!.isEmpty) {
      if (_isWarmingUp && _currentServerAddress != null) {
        await _notificationService
            .dismissWarmupNotification(_currentServerAddress!);
        _isWarmingUp = false;
      }
      _currentServerAddress = null;
      _currentServerDomainAddress = null;
      _currentServerName = null;
      _currentMapName = null;
      _currentMapRuntime = null;
      return;
    }

    final serverAddress = _connectedServerAddress!;

    if (serverAddress != _currentServerAddress) {
      if (_isWarmingUp && _currentServerAddress != null) {
        await _notificationService
            .dismissWarmupNotification(_currentServerAddress!);
      }
      _currentServerAddress = serverAddress;
      _currentServerDomainAddress = _getDomainAddress(serverAddress);
      _currentMapName = null;
      _currentMapRuntime = null;
      _currentMapRuntimeFetchedAt = null;
      _currentMapInfo = null;
      _isWarmingUp = false;
    }

    await _fetchServerInfo(serverAddress);
  }

  Future<void> _fetchServerInfo(String serverAddress) async {
    try {
      final parts = serverAddress.split(':');
      if (parts.length != 2) return;

      final ip = parts[0];
      final port = int.tryParse(parts[1]);
      if (port == null) return;

      final serverInfo =
          await SourceServerService.getServerInfo(ip, port, timeout: 3000);
      if (serverInfo == null) return;

      _currentServerName = serverInfo.name;
      final mapName = serverInfo.map;

      // 跳过服务器重启时的加载地图
      if (mapName == 'graphics_settings') return;

      if (mapName != _currentMapName) {
        final oldMapName = _currentMapName;
        _currentMapName = mapName;
        _currentMapRuntime = null;
        _currentMapRuntimeFetchedAt = null;
        _currentMapInfo = null;
        if (_isWarmingUp) {
          _isWarmingUp = false;
          await _notificationService.dismissWarmupNotification(serverAddress);
        }

        LogService.i('[WarmupMonitor] 地图变化: $oldMapName -> $mapName');

        try {
          _currentMapInfo = await _serverApi.getMapInfo(mapName);
        } catch (e) {
          // 忽略地图信息获取失败
        }

        // 使用域名地址调用 API
        final apiAddress = _currentServerDomainAddress ?? serverAddress;
        try {
          _currentMapRuntime =
              await _serverApi.getMapRuntime(apiAddress, mapName);
          _currentMapRuntimeFetchedAt = DateTime.now().millisecondsSinceEpoch;
        } catch (e) {
          LogService.e('[WarmupMonitor] 获取地图运行时间失败', e);
          return;
        }

        if (_currentMapRuntime == null) return;

        final warmupDuration = MapRuntimeUtils.getWarmupDuration(mapName);
        if (warmupDuration == null) return;

        final apiRuntime = _currentMapRuntime?.currentRuntime ?? 0;

        // 如果运行时间已超过热身时间，不显示通知
        if (apiRuntime > warmupDuration) return;

        _isWarmingUp = true;
        _startMonitorLoop(isWarmup: true);
        _showWarmupNotification();
        LogService.i('[WarmupMonitor] 检测到热身: $mapName, runtime=$apiRuntime');
      } else if (_isWarmingUp) {
        // 检查热身是否结束
        final isStillWarmingUp = MapRuntimeUtils.isWarmingUp(
          _currentMapRuntime,
          fetchedAt: _currentMapRuntimeFetchedAt,
          mapName: mapName,
        );

        if (!isStillWarmingUp) {
          _isWarmingUp = false;
          _startMonitorLoop(isWarmup: false);
          await _notificationService.dismissWarmupNotification(serverAddress);
          LogService.i('[WarmupMonitor] 热身结束');
        }
      }
    } catch (e) {
      LogService.e('[WarmupMonitor] 查询服务器失败', e);
    }
  }

  void _showWarmupNotification() {
    if (_currentServerAddress == null || _currentMapRuntime == null) return;

    final apiRuntime = _currentMapRuntime!.currentRuntime;
    final warmupDuration =
        MapRuntimeUtils.getWarmupDuration(_currentMapName) ?? 120;

    if (apiRuntime > warmupDuration) {
      _isWarmingUp = false;
      _startMonitorLoop(isWarmup: false);
      return;
    }

    final warmupRemaining = MapRuntimeUtils.getWarmupTimeRemaining(
      _currentMapRuntime,
      fetchedAt: _currentMapRuntimeFetchedAt,
      mapName: _currentMapName,
    );

    if (warmupRemaining <= 0) {
      if (_isWarmingUp) {
        _isWarmingUp = false;
        _notificationService.dismissWarmupNotification(_currentServerAddress!);
        _startMonitorLoop(isWarmup: false);
      }
      return;
    }

    _notificationService.showWarmupNotification(
      serverAddress: _currentServerAddress!,
      serverName: _currentServerName ?? _currentServerAddress!,
      mapName: _currentMapName,
      mapNameCn: _currentMapInfo?.mapLabel,
      mapBackground: _currentMapInfo?.mapUrl,
      warmupRemainingSeconds: warmupRemaining,
    );
  }

  void dispose() {
    _monitorTimer?.cancel();
    _consoleStateSubscription?.cancel();
    _gameStatusSubscription?.cancel();
    if (_isWarmingUp && _currentServerAddress != null) {
      _notificationService.dismissWarmupNotification(_currentServerAddress!);
    }
    _connectedServerAddress = null;
  }
}
