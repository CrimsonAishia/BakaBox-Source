import 'dart:async';
import 'dart:io';

import '../api/server_api.dart';
import '../models/gsi_models.dart';
import '../models/server_models.dart';
import '../utils/log_service.dart';
import '../utils/map_runtime_utils.dart';
import 'console_log_service.dart';
import 'game_status_service.dart';
import 'gsi_service.dart';
import 'notification_window_service.dart';
import 'scheduler_service.dart';
import 'source_server_service.dart';

/// 热身监控服务（单例）
///
/// 基于 GSI (Game State Integration) 监控热身状态：
/// 1. 监听 GSI 数据流获取游戏状态
/// 2. 通过 map.phase 判断是否处于热身阶段
/// 3. 通过 phaseCountdowns.phaseEndsIn 获取热身剩余时间
/// 4. 如果检测到热身，显示通知
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
  final GsiService _gsiService = GsiService();
  final SchedulerService _scheduler = SchedulerService();

  // GSI 相关
  StreamSubscription<GsiGameState?>? _gsiSubscription;
  bool _useGsi = false; // 是否使用 GSI 数据源
  String? _gsiMapName; // GSI 获取的地图名

  // API 轮询相关
  static const String _taskId = 'warmup_monitor';
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
    // 监听 GSI 数据流（GSI 收到有效数据时会自动切换）
    _gsiSubscription?.cancel();
    _gsiSubscription = _gsiService.stateStream.listen(_onGsiStateChanged);

    _consoleStateSubscription?.cancel();
    _consoleStateSubscription =
        _consoleLogService.stateStream.listen(_onConsoleStateChanged);

    // 监听游戏状态变化，游戏退出时关闭热身通知
    _gameStatusSubscription?.cancel();
    _gameStatusSubscription =
        _gameStatusService.statusStream.listen(_onGameStatusChanged);

    // 先加载服务器列表，建立 IP 到域名的映射（API 轮询需要）
    await _loadServerAddressMapping();

    // 从 ConsoleLogService 获取当前状态（它已经分析过历史日志了）
    _restoreStateFromConsoleLog();
    
    // 默认启动 API 轮询，GSI 收到数据后会自动切换
    _useGsi = false;
    _startMonitorLoop(isWarmup: false);
    
    LogService.i('[WarmupMonitor] 服务已初始化，默认使用 API 轮询');
  }

  /// GSI 数据变化处理
  void _onGsiStateChanged(GsiGameState? state) {
    // 检查是否在主菜单（activity == 'menu'）
    if (state != null && state.isInMenu) {
      LogService.d('[WarmupMonitor] GSI: 玩家在主菜单');
      // 玩家在主菜单，清理热身状态
      if (_isWarmingUp && _currentServerAddress != null) {
        _notificationService.dismissWarmupNotification(_currentServerAddress!);
        _isWarmingUp = false;
        LogService.i('[WarmupMonitor] GSI: 玩家回到主菜单，关闭热身通知');
      }
      // 主菜单时保持 GSI 监听，但不处理热身逻辑
      // 注意：不切换到 API 轮询，因为 GSI 仍然在工作
      return;
    }
    
    if (state == null || state.map == null) {
      // GSI 无有效数据，保持/切换到 API 轮询
      if (_useGsi) {
        _useGsi = false;
        LogService.i('[WarmupMonitor] GSI 数据丢失，切换到 API 轮询');
        
        // 如果当前正在热身但没有 mapRuntime 数据，需要立即获取
        if (_isWarmingUp && _currentMapRuntime == null && _currentMapName != null) {
          _fetchMapRuntimeForFallback();
        }
        
        _startMonitorLoop(isWarmup: _isWarmingUp);
      }
      return;
    }

    // GSI 收到有效游戏数据，立即切换到 GSI（GSI 数据为准）
    if (!_useGsi) {
      _useGsi = true;
      _scheduler.cancel(_taskId);
      LogService.i('[WarmupMonitor] GSI 收到有效数据，切换到 GSI 模式');
    }

    _processGsiState(state);
  }

  /// GSI 切换到 API 时，获取 mapRuntime 以便继续监控
  Future<void> _fetchMapRuntimeForFallback() async {
    if (_currentMapName == null) return;
    
    final apiAddress = _currentServerDomainAddress ?? _currentServerAddress;
    if (apiAddress == null) return;
    
    try {
      _currentMapRuntime = await _serverApi.getMapRuntime(apiAddress, _currentMapName!);
      _currentMapRuntimeFetchedAt = DateTime.now().millisecondsSinceEpoch;
      LogService.d('[WarmupMonitor] 回退时获取 mapRuntime: ${_currentMapRuntime?.currentRuntime}');
    } catch (e) {
      LogService.e('[WarmupMonitor] 回退时获取 mapRuntime 失败', e);
      // 获取失败时，重置 mapName 让下次轮询重新触发地图变化分支
      _currentMapName = null;
    }
  }

  /// 处理 GSI 状态数据
  void _processGsiState(GsiGameState state) {
    // 如果用户不在服务器中，忽略 GSI 数据
    if (_connectedServerAddress == null || _connectedServerAddress!.isEmpty) {
      return;
    }
    
    final mapInfo = state.map;
    if (mapInfo == null) return;

    final mapName = mapInfo.name;
    final mapPhase = mapInfo.phase;

    // 跳过服务器重启时的加载地图
    if (mapName == 'graphics_settings') return;

    // 判断是否处于热身阶段
    // GSI map.phase 可能的值: warmup, live, intermission, gameover 等
    final isWarmupPhase = mapPhase == 'warmup';

    _gsiMapName = mapName;

    // 地图变化时获取地图信息（用于通知显示）
    if (mapName != null && mapName != _currentMapName) {
      final wasWarmingUp = _isWarmingUp;
      _currentMapName = mapName;
      _currentMapInfo = null;
      _currentMapRuntime = null;
      _currentMapRuntimeFetchedAt = null;
      _isWarmingUp = false; // 换图时重置热身状态
      _fetchMapInfoAsync(mapName);
      // 地图变化时也获取服务器名称
      _fetchServerNameAsync();
      
      // 如果之前在热身，关闭旧通知
      if (wasWarmingUp && _currentServerAddress != null) {
        _notificationService.dismissWarmupNotification(_currentServerAddress!);
      }
    }

    // 热身状态变化处理
    if (isWarmupPhase) {
      // 检查地图是否支持热身监控
      final warmupDuration = MapRuntimeUtils.getWarmupDuration(mapName);
      if (warmupDuration == null) {
        // 不支持热身的地图，关闭之前的热身通知
        if (_isWarmingUp && _currentServerAddress != null) {
          _notificationService.dismissWarmupNotification(_currentServerAddress!);
          _isWarmingUp = false;
          LogService.i('[WarmupMonitor/GSI] 地图 $mapName 不支持热身监控，关闭通知');
        }
        return;
      }
      
      if (!_isWarmingUp) {
        _isWarmingUp = true;
        LogService.i('[WarmupMonitor/GSI] 检测到热身: $mapName');
        // 获取 API 时间并显示通知（只需一次，通知窗口自己倒计时）
        _fetchMapRuntimeAndShowNotification();
      }
    } else if (_isWarmingUp) {
      // 热身结束
      _isWarmingUp = false;
      _currentMapRuntime = null;
      _currentMapRuntimeFetchedAt = null;
      if (_currentServerAddress != null) {
        _notificationService.dismissWarmupNotification(_currentServerAddress!);
      }
      LogService.i('[WarmupMonitor/GSI] 热身结束');
    }
  }

  /// GSI 模式下获取 API 时间并显示通知
  Future<void> _fetchMapRuntimeAndShowNotification() async {
    if (_currentMapName == null) return;
    
    // 保存当前状态，用于检查请求返回时是否已变化
    final requestMapName = _currentMapName;
    final requestServerAddress = _currentServerAddress;
    
    final apiAddress = _currentServerDomainAddress ?? _currentServerAddress;
    final serverAddress = _currentServerAddress ?? 'gsi_server';
    
    // 如果服务器名称为空，先尝试获取（等待完成）
    if (_currentServerName == null && _currentServerAddress != null) {
      await _fetchServerNameAsync();
      // 检查服务器是否已变化
      if (_currentServerAddress != requestServerAddress) {
        LogService.d('[WarmupMonitor/GSI] 服务器已变化，忽略旧请求');
        return;
      }
    }
    // 获取后再读取，如果仍为空则使用地址作为回退
    final serverName = _currentServerName ?? serverAddress;
    
    // 先尝试获取 API 时间
    int warmupRemaining = -1; // 默认显示"热身中"
    if (apiAddress != null) {
      try {
        final mapRuntime = await _serverApi.getMapRuntime(apiAddress, requestMapName!);
        
        // 检查地图或服务器是否已变化，如果变化则忽略此次请求结果
        if (_currentMapName != requestMapName || _currentServerAddress != requestServerAddress) {
          LogService.d('[WarmupMonitor/GSI] 地图或服务器已变化，忽略旧请求结果');
          return;
        }
        
        _currentMapRuntime = mapRuntime;
        _currentMapRuntimeFetchedAt = DateTime.now().millisecondsSinceEpoch;
        LogService.d('[WarmupMonitor/GSI] 获取 mapRuntime: ${_currentMapRuntime?.currentRuntime}');
        
        if (_currentMapRuntime != null) {
          warmupRemaining = MapRuntimeUtils.getWarmupTimeRemaining(
            _currentMapRuntime,
            fetchedAt: _currentMapRuntimeFetchedAt,
            mapName: _currentMapName,
          );
        }
      } catch (e) {
        LogService.e('[WarmupMonitor/GSI] 获取 mapRuntime 失败', e);
        // 检查地图或服务器是否已变化
        if (_currentMapName != requestMapName || _currentServerAddress != requestServerAddress) return;
      }
    }
    
    // 再次检查地图或服务器是否已变化
    if (_currentMapName != requestMapName || _currentServerAddress != requestServerAddress) return;
    
    // 检查是否仍在热身状态（可能在异步期间热身已结束）
    if (!_isWarmingUp) {
      LogService.d('[WarmupMonitor/GSI] 热身已结束，不显示通知');
      return;
    }
    
    // 显示通知（通知窗口会自己倒计时）
    _notificationService.showWarmupNotification(
      serverAddress: serverAddress,
      serverName: serverName,
      mapName: _gsiMapName,
      mapNameCn: _currentMapInfo?.mapLabel,
      mapBackground: _currentMapInfo?.mapUrl,
      warmupRemainingSeconds: warmupRemaining,
    );
  }

  /// 异步获取服务器名称
  Future<void> _fetchServerNameAsync() async {
    if (_currentServerAddress == null) return;
    
    try {
      final parts = _currentServerAddress!.split(':');
      if (parts.length != 2) return;
      
      final ip = parts[0];
      final port = int.tryParse(parts[1]);
      if (port == null) return;
      
      final serverInfo = await SourceServerService.getServerInfo(ip, port, timeout: 3000);
      if (serverInfo != null) {
        _currentServerName = serverInfo.name;
      }
    } catch (e) {
      // 忽略获取失败
    }
  }

  /// 异步获取地图信息
  Future<void> _fetchMapInfoAsync(String mapName) async {
    try {
      _currentMapInfo = await _serverApi.getMapInfo(mapName);
    } catch (e) {
      // 忽略地图信息获取失败
    }
  }
  
  /// 从 ConsoleLogService 恢复当前状态
  void _restoreStateFromConsoleLog() {
    final state = _consoleLogService.currentState;
    if (state.state == GameState.inGame && state.serverAddress.isNotEmpty) {
      _connectedServerAddress = state.serverAddress;
      _currentServerAddress = state.serverAddress;
      _currentServerDomainAddress = _getDomainAddress(state.serverAddress);
      // 不恢复 mapName，让 API 轮询重新获取并检测热身
      // 因为恢复 mapName 但没有 mapRuntime 会导致无法检测热身
      LogService.d('[WarmupMonitor] 历史: 用户当前在服务器: ${state.serverAddress}');
      if (!_useGsi) {
        _checkCurrentServer();
      }
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
      _scheduler.cancel(_taskId);

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
      _gsiMapName = null;
      _useGsi = false; // 重置 GSI 状态，下次需要重新检测
    } else {
      // 游戏启动，如果 GSI 不可用则重新开始 API 轮询
      if (!_scheduler.hasTask(_taskId) && !_useGsi) {
        LogService.i('[WarmupMonitor] 游戏已启动，重新开始 API 轮询');
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
            if (!_useGsi) {
              _checkCurrentServer();
            }
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
        _currentMapRuntimeFetchedAt = null;
      }
    }
  }

  // ========== API 轮询模式（GSI 不可用时的回退方案）==========

  void _startMonitorLoop({bool isWarmup = false}) {
    if (_useGsi) return; // GSI 可用时不启动轮询

    _scheduler.cancel(_taskId);
    final interval = isWarmup ? warmupIntervalSeconds : normalIntervalSeconds;

    _scheduler.register(ScheduledTask(
      id: _taskId,
      name: '热身监控',
      interval: Duration(seconds: interval),
      callback: () async {
        if (!_useGsi) await _checkCurrentServer();
      },
      runImmediately: true,
    ));
  }

  Future<void> _checkCurrentServer() async {
    if (_useGsi) return; // GSI 可用时跳过
    
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
    if (_useGsi) return; // GSI 可用时跳过
    
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

        LogService.i('[WarmupMonitor/API] 地图变化: $oldMapName -> $mapName');

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
          LogService.e('[WarmupMonitor/API] 获取地图运行时间失败', e);
          // 重置 mapName 以便下次轮询重试
          _currentMapName = null;
          return;
        }

        if (_currentMapRuntime == null) {
          // 重置 mapName 以便下次轮询重试
          _currentMapName = null;
          return;
        }

        final warmupDuration = MapRuntimeUtils.getWarmupDuration(mapName);
        if (warmupDuration == null) return;

        final apiRuntime = _currentMapRuntime?.currentRuntime ?? 0;

        // 如果运行时间已超过热身时间，不显示通知
        if (apiRuntime > warmupDuration) return;

        _isWarmingUp = true;
        _startMonitorLoop(isWarmup: true);
        _showApiWarmupNotification();
        LogService.i('[WarmupMonitor/API] 检测到热身: $mapName, runtime=$apiRuntime');
      } else if (_isWarmingUp) {
        // 如果 mapRuntime 为 null（可能是 GSI 切换过来还没获取到），跳过本次检测
        if (_currentMapRuntime == null) {
          LogService.d('[WarmupMonitor/API] mapRuntime 为空，跳过热身检测');
          return;
        }
        
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
          LogService.i('[WarmupMonitor/API] 热身结束');
        } else {
          // 更新热身通知显示
          _showApiWarmupNotification();
        }
      }
    } catch (e) {
      LogService.e('[WarmupMonitor/API] 查询服务器失败', e);
    }
  }

  void _showApiWarmupNotification() {
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

  /// 获取当前数据源
  String get dataSource => _useGsi ? 'GSI' : 'API';

  /// GSI 是否可用
  bool get isGsiAvailable => _useGsi;

  void dispose() {
    _scheduler.cancel(_taskId);
    _consoleStateSubscription?.cancel();
    _gameStatusSubscription?.cancel();
    _gsiSubscription?.cancel();
    if (_isWarmingUp && _currentServerAddress != null) {
      _notificationService.dismissWarmupNotification(_currentServerAddress!);
    }
    _connectedServerAddress = null;
  }
}
