import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:logger/logger.dart';

import '../bloc/server/server_bloc.dart';
import '../models/server_models.dart';
import '../utils/storage_utils.dart';
import '../api/server_api.dart';
import '../services/console_log_service.dart';
import '../services/source_server_service.dart';
import '../services/server_address_mapping_service.dart';
import '../services/game_status_service.dart';
import '../services/network_mode_service.dart';
import '../services/realtime/realtime_server_map_runtime_channel.dart';

String _getWaitingText() {
  try {
    final gameStatus = GameStatusService();
    // 仅当被监控的游戏（CS2）在运行但未带 -condebug 时才提示"无法监控"。
    // 独立版 CSGO / CS:Source 不在监控范围内，不应触发该提示。
    if (gameStatus.isMonitoredGameRunning && !gameStatus.isMonitorable) {
      return '无法监控游戏';
    }
  } catch (_) {}
  return '等待进入服务器';
}

class ObsServerService {
  static final ObsServerService _instance = ObsServerService._internal();
  factory ObsServerService() => _instance;
  ObsServerService._internal() {
    // 监听弱网模式切换，立即启停 OBS 数据刷新定时器
    _networkModeSubscription = NetworkModeService.instance.changes.listen((
      weakNetwork,
    ) {
      // 仅当 OBS 服务器已启动时才管理定时器
      if (_server == null) return;
      if (weakNetwork) {
        _obsRefreshTimer?.cancel();
        _obsRefreshTimer = null;
        _logger.i('[OBS] 弱网模式开启，已停止 OBS 数据刷新');
      } else {
        if (_obsRefreshTimer == null) {
          _obsRefreshTimer = Timer.periodic(_obsRefreshInterval, (_) {
            _refreshCurrentServerData();
          });
          _logger.i('[OBS] 弱网模式关闭，已恢复 OBS 数据刷新');
        }
      }
    });
  }

  HttpServer? _server;
  final List<WebSocket> _clients = [];
  final _logger = Logger();

  // ServerBloc 订阅
  ServerBloc? _serverBloc;
  StreamSubscription? _serverBlocSubscription;

  // ConsoleLogService 订阅，用于获取用户当前所在的服务器
  StreamSubscription? _consoleLogSubscription;
  String? _currentServerAddress; // 用户当前所在服务器的地址

  // server.map.runtime WS 频道订阅：用于在服务端推送换图时立即更新 OBS 推送
  // 单例频道，跟 ServerBloc / WarmupMonitorService 共享底层 WS 订阅
  final RealtimeServerMapRuntimeChannel _mapRuntimeChannel =
      RealtimeServerMapRuntimeChannel();
  StreamSubscription<ServerMapRuntimeEvent>? _mapRuntimeSubscription;
  bool _mapRuntimeSubscribed = false;

  // 弱网模式切换监听（单例随应用生命周期，不需要 cancel）
  // ignore: unused_field
  StreamSubscription<bool>? _networkModeSubscription;

  // 当前直接查询的服务器数据
  SourceServerInfo? _queriedServerInfo;

  // OBS 独立的定时器，用于轮询当前连接的服务器数据
  Timer? _obsRefreshTimer;
  static const Duration _obsRefreshInterval = Duration(seconds: 3); // 每3秒刷新一次

  // 默认布局，以免刚启动时没数据
  Map<String, dynamic> _currentLayout = {
    'elements': [
      {
        'id': 'card-1',
        'type': 'server_card',
        'x': 20.0,
        'y': 20.0,
        'scale': 1.0,
        'showMapImage': true,
        'showIp': true,
        'showPing': true,
        'showPlayers': true,
      },
      {
        'id': 'text-1',
        'type': 'text',
        'template': '当前地图: {map}',
        'x': 20.0,
        'y': 170.0, // just below the card
        'scale': 1.0,
        'color': '#FFFFFF',
        'fontSize': 24.0,
        'fontWeight': 'bold',
        'textShadow': '2px 2px 4px rgba(0,0,0,0.8)',
      },
    ],
  };

  Map<String, dynamic> _currentData = {
    'isConnected': false,
    'serverName': _getWaitingText(),
    'ping': '0',
    'players': '0/0',
    'map': '未知',
    'mapLabel': '',
  };

  /// 获取用户当前所在的服务器
  /// [serverAddress] 用户连接的服务器地址
  ExtendedServerItem? _getConnectedServer(
    List<ExtendedServerItem> servers,
    String serverAddress,
  ) {
    // 遍历服务器列表，查找与用户所在地址匹配的服务器
    for (var ext in servers) {
      final address = ext.serverItem.address ?? ext.serverItem.serverAddress;
      if (address == serverAddress) {
        return ext;
      }
    }

    // 没有找到匹配的服务器
    return null;
  }

  /// 从存储加载布局
  void _loadLayoutFromStorage() {
    try {
      final savedStr = StorageUtils.getString('obs_tool_elements');
      if (savedStr != null && savedStr.isNotEmpty) {
        final decoded = jsonDecode(savedStr);
        if (decoded is Map && decoded.containsKey('elements')) {
          _currentLayout = Map<String, dynamic>.from(decoded);
          _logger.i('[OBS] 从存储加载布局成功');
        }
      }
    } catch (e) {
      _logger.e('[OBS] 从存储加载布局失败: $e');
    }
  }

  /// 重置数据为初始状态
  void _resetCurrentData() {
    _currentData = {
      'isConnected': false,
      'serverName': _getWaitingText(),
      'ping': '0',
      'players': '0/0',
      'map': '未知',
      'mapLabel': '',
    };
    _queriedServerInfo = null;
  }

  Future<void> start() async {
    // 检查服务器是否已经运行，如果是则跳过
    if (_server != null) {
      // 验证服务器是否真的在运行
      try {
        final testSocket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          25566,
          timeout: const Duration(milliseconds: 100),
        );
        await testSocket.close();
        // 如果能连接上，说明服务器已经在运行
        _logger.i('OBS Server 已在运行中，跳过启动');
        return;
      } catch (_) {
        // 无法连接，说明服务器可能已崩溃，重置状态
        _logger.w('OBS Server 状态异常，尝试重新启动');
        _server = null;
      }
    }

    // 从存储加载布局（每次启动都需要加载）
    _loadLayoutFromStorage();

    // 重置数据为初始状态，确保重新启动时显示正确
    _resetCurrentData();

    // 初始化地址映射服务
    await ServerAddressMappingService().load();

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 25566);
      _logger.i('OBS Server running on http://127.0.0.1:25566/obs');

      // 订阅 ConsoleLogService 获取用户当前所在的服务器地址
      _subscribeToConsoleLog();

      // 订阅 ServerBloc 数据
      _subscribeToServerBloc();

      // 订阅 server.map.runtime 频道：服务端推送换图时立即更新 OBS
      _subscribeToMapRuntime();

      // 启动独立的 OBS 数据刷新定时器（不依赖全局刷新）
      _startObsRefreshTimer();

      // 立即刷新一次数据，确保客户端连接时能收到最新数据
      // 使用 await 确保数据刷新完成后再接受连接
      await _refreshCurrentServerData();

      _server!.listen((HttpRequest request) {
        if (request.uri.path == '/obs' || request.uri.path == '/') {
          _serveHtml(request);
        } else if (request.uri.path == '/ws') {
          WebSocketTransformer.upgrade(request)
              .then((WebSocket ws) {
                _clients.add(ws);
                // Send initial state immediately
                ws.add(
                  jsonEncode({
                    'type': 'init',
                    'layout': _currentLayout,
                    'data': _currentData,
                  }),
                );

                ws.listen(
                  (message) {
                    // 处理客户端消息（如果需要）
                  },
                  onDone: () {
                    _clients.remove(ws);
                    _logger.i('[OBS] WebSocket 客户端断开连接');
                  },
                  onError: (e) {
                    _clients.remove(ws);
                    _logger.e('[OBS] WebSocket 错误: $e');
                  },
                );
              })
              .catchError((e) {
                _logger.e('WebSocket upgrade failed: $e');
                request.response.statusCode = HttpStatus.internalServerError;
                request.response.close();
              });
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.close();
        }
      });
    } catch (e) {
      _logger.e('Failed to start OBS Server: $e');
    }
  }

  /// 设置 ServerBloc 实例并订阅数据
  void setServerBloc(ServerBloc serverBloc) {
    _serverBloc = serverBloc;
    // 无论服务器是否启动，都尝试订阅数据
    // 这样即使 HTTP 服务失败，数据订阅仍然可以工作
    _subscribeToServerBloc();
    // 同时订阅 ConsoleLogService，确保状态变化能被监听
    _subscribeToConsoleLog();
  }

  /// 订阅 ConsoleLogService 获取用户当前所在的服务器地址
  void _subscribeToConsoleLog() {
    _consoleLogSubscription?.cancel();
    _consoleLogSubscription = null;

    final consoleLogService = ConsoleLogService();

    // 订阅状态变化
    _consoleLogSubscription = consoleLogService.stateStream.listen(
      (state) {
        // 更新内部存储的服务器地址
        if (state.isInServer && state.serverAddress.isNotEmpty) {
          // 用户在服务器中，检查地址是否变化
          if (_currentServerAddress != state.serverAddress) {
            _currentServerAddress = state.serverAddress;
            _logger.i('[OBS] 用户进入服务器: $_currentServerAddress');
            _refreshCurrentServerData();
          }
        } else {
          // 用户不在服务器中（离开服务器或回到主菜单）
          // 检查是否需要重置状态（无论是 null 还是空字符串都重置）
          if (_currentServerAddress != null &&
              _currentServerAddress!.isNotEmpty) {
            _logger.i('[OBS] 用户离开服务器');
            _currentServerAddress = null;
            _refreshCurrentServerData();
          }
        }
      },
      onError: (error) {
        _logger.e('[OBS] ConsoleLogService 订阅出错: $error');
      },
    );

    _logger.i('[OBS] 已订阅 ConsoleLogService');
  }

  /// 刷新 ConsoleLog 状态
  /// 当 ConsoleLogService 启动后调用，确保获取到用户当前所在的服务器
  void refreshConsoleLogStatus() {
    _subscribeToConsoleLog();

    // 强制重置为初始状态，等待 ConsoleLogService 解析完历史日志后再更新
    _currentData['isConnected'] = false;
    _currentData['serverName'] = _getWaitingText();
    _currentData['ping'] = '0';
    _currentData['players'] = '0/0';
    _currentData['map'] = '未知';
    _currentData['ip'] = '';
    _currentData['runtime'] = '';
    _currentData['mapName'] = '';
    _currentData['mapUrl'] = '';
    _currentData['mapLabel'] = '';
    _broadcast();

    // ConsoleLogService 启动后会分析历史日志并更新状态
    // 等待足够长的时间让 ConsoleLogService 解析日志
    Future.delayed(const Duration(seconds: 3), () async {
      await _refreshCurrentServerData();
      // 同时广播当前数据，确保 OBS 客户端能收到
      _broadcast();
    });
  }

  /// 订阅 ServerBloc 数据
  void _subscribeToServerBloc() {
    _serverBlocSubscription?.cancel();
    _serverBlocSubscription = null;

    if (_serverBloc == null) {
      _logger.w('[OBS] ServerBloc 未设置，无法订阅数据');
      return;
    }

    _serverBlocSubscription = _serverBloc!.stream.listen(
      (state) {
        // 使用统一的刷新逻辑，会正确处理 ConsoleLogService 的状态
        _refreshCurrentServerData();
      },
      onError: (error) {
        _logger.e('[OBS] ServerBloc 订阅出错: $error');
      },
      onDone: () {
        _logger.w('[OBS] ServerBloc 流已关闭');
      },
    );

    _logger.i('[OBS] 已订阅 ServerBloc 数据');
  }

  /// 订阅 server.map.runtime 频道
  ///
  /// 服务端在玩家所在服务器换图时会推 `changed` 事件，比 A2S 轮询更及时。
  /// 收到当前服务器的换图后，立即把 OBS 推送的地图字段（map / mapName / mapLabel /
  /// mapUrl）更新成新地图，避免推流端要等到下一轮 A2S 才看到新数据。
  void _subscribeToMapRuntime() {
    if (_mapRuntimeSubscribed) return;
    _mapRuntimeSubscribed = true;
    _mapRuntimeChannel.subscribe();
    _mapRuntimeSubscription = _mapRuntimeChannel.events.listen(
      _onMapRuntimeEvent,
      onError: (error) {
        _logger.e('[OBS] map.runtime 频道出错: $error');
      },
    );
    _logger.i('[OBS] 已订阅 server.map.runtime 频道');
  }

  void _unsubscribeFromMapRuntime() {
    if (!_mapRuntimeSubscribed) return;
    _mapRuntimeSubscribed = false;
    _mapRuntimeSubscription?.cancel();
    _mapRuntimeSubscription = null;
    _mapRuntimeChannel.unsubscribe();
  }

  /// 处理 server.map.runtime 推送
  void _onMapRuntimeEvent(ServerMapRuntimeEvent event) {
    // snapshot 仅用于初始化频道缓存，不主动改 OBS 数据；
    // 真正的换图通过后续 changed 事件触发。
    if (event.kind != ServerMapRuntimeEventKind.changed) return;

    // 没有连接到任何服务器时不处理
    final myAddress = _currentServerAddress;
    if (myAddress == null || myAddress.isEmpty) return;

    // 已被显式清空显示（游戏未运行 / stop 等场景）：不处理推送，
    // 避免广播一个 isCleared=true 但 map 是新地图的奇怪中间状态。
    if (_currentData['isCleared'] == true) return;

    // 推送里的 serverAddress 是域名形式，本地存的是从游戏日志解析出的 IP。
    // 这里把本地地址也映射成域名再做对比，跟 WarmupMonitorService 保持一致。
    final addressMapping = ServerAddressMappingService();
    final myDomain = addressMapping.getDomainAddress(myAddress);

    for (final entry in event.entries) {
      if (entry.serverAddress != myDomain && entry.serverAddress != myAddress) {
        continue;
      }
      _applyRealtimeMapChange(entry);
      break;
    }
  }

  /// 应用 WS 推送的换图：更新 _currentData 中的地图字段并广播
  Future<void> _applyRealtimeMapChange(ServerMapRuntimeEntry entry) async {
    final newMap = entry.mapName;
    if (newMap.isEmpty) return;

    // 跟现有数据一致就跳过，避免重复广播
    if (_currentData['map'] == newMap && _currentData['mapName'] == newMap) {
      return;
    }

    _logger.i(
      '[OBS] 收到 WS 换图推送: ${_currentData['map']} -> $newMap @${entry.serverAddress}',
    );

    _currentData['map'] = newMap;
    _currentData['mapName'] = newMap;

    // 换图后 runtime 应当重置；交给后续矫正 / A2S 刷新填新值
    _currentData['runtime'] = '';

    // 已缓存的查询结果里 map 字段过期了，置空，让下一次 A2S 一定推新数据
    _queriedServerInfo = null;

    // 优先用 ServerBloc 列表里的地图缓存（含译名 + 背景），没有再回落到 API
    MapData? cachedMapData;
    if (_serverBloc != null) {
      final state = _serverBloc!.state;
      final listServer = _getConnectedServer(state.servers, entry.serverAddress)
          ?? _getConnectedServer(state.servers, _currentServerAddress!);
      final mapInfo = listServer?.mapInfo;
      if (mapInfo != null &&
          mapInfo.mapLabel.isNotEmpty &&
          // 列表缓存的 mapInfo 必须就是新地图
          (listServer?.serverData?.map == newMap ||
              mapInfo.mapName == newMap)) {
        cachedMapData = mapInfo;
      }
    }

    if (cachedMapData != null) {
      _currentData['mapUrl'] = cachedMapData.mapUrl;
      _currentData['mapLabel'] = cachedMapData.mapLabel;
      _broadcast();
    } else {
      // 先广播一次让 OBS 端尽快显示新地图原名（即使没有译名 / 背景图）
      _currentData['mapUrl'] = '';
      _currentData['mapLabel'] = '';
      _broadcast();
      // 再异步拉地图详情，拿到后再广播一次。
      // 注意：API 回包期间用户可能已经离开服务器、换图、或被 stop()/clearDisplay() 清空，
      // 此时 _fetchMapInfo 会写入 _currentData 但我们不能广播，否则会出现"等待进入服务器
      // + 旧地图背景"这种诡异组合。回来后只在状态没变的前提下广播。
      await _fetchMapInfo(newMap);
      if (_currentData['map'] == newMap &&
          _currentData['isCleared'] != true &&
          _currentData['isConnected'] == true) {
        _broadcast();
      }
    }
  }

  void _serveHtml(HttpRequest request) {
    request.response
      ..headers.contentType = ContentType.html
      ..write(_htmlContent)
      ..close();
  }

  void updateLayout(Map<String, dynamic> layout) {
    _currentLayout = layout;
    _broadcast();
  }

  void updateData(Map<String, dynamic> data) {
    _currentData = {..._currentData, ...data};
    _broadcast();
  }

  /// 更新运行时间和比分数据
  void updateRuntimeData({
    String? runtime,
    int? ctScore,
    int? tScore,
    String? mapName,
  }) {
    _currentData = {
      ..._currentData,
      if (runtime != null) 'runtime': runtime,
      if (ctScore != null) 'ctScore': ctScore,
      if (tScore != null) 'tScore': tScore,
      if (mapName != null) 'mapName': mapName,
    };
    _broadcast();
  }

  void _broadcast() {
    final msg = jsonEncode({
      'type': 'update',
      'layout': _currentLayout,
      'data': _currentData,
    });
    for (var ws in _clients) {
      try {
        ws.add(msg);
      } catch (e) {
        // Ignore dead sockets
      }
    }
  }

  /// 检查 OBS 服务是否正在运行
  bool get isRunning => _server != null;

  /// 清空 OBS 显示（退出程序时调用）
  void clearDisplay() {
    // 广播清空信号，让 OBS 隐藏所有内容
    _currentData['isConnected'] = false;
    _currentData['serverName'] = '';
    _currentData['ping'] = '0';
    _currentData['players'] = '0/0';
    _currentData['map'] = '';
    _currentData['ip'] = '';
    _currentData['runtime'] = '';
    _currentData['mapName'] = '';
    _currentData['mapUrl'] = '';
    _currentData['mapLabel'] = '';
    _currentData['isCleared'] = true; // 标记为已清空
    _broadcast();
  }

  Future<void> stop() async {
    // 记录当前是否有活动连接需要广播清空信号
    // 有客户端连接 或 当前显示的是连接状态时才需要广播
    final bool needsBroadcast =
        _clients.isNotEmpty ||
        _currentData['isConnected'] == true ||
        _currentData['serverName']?.isNotEmpty == true;

    // 只有确实有需要广播的情况时才广播清空信号
    if (needsBroadcast) {
      // 广播清空信号，让 OBS 隐藏所有内容
      _currentData['isConnected'] = false;
      _currentData['serverName'] = '';
      _currentData['ping'] = '0';
      _currentData['players'] = '0/0';
      _currentData['map'] = '';
      _currentData['ip'] = '';
      _currentData['runtime'] = '';
      _currentData['mapName'] = '';
      _currentData['mapUrl'] = '';
      _currentData['mapLabel'] = '';
      _currentData['isCleared'] = true; // 标记为已清空
      _broadcast();
    }

    // 停止 OBS 刷新定时器
    _obsRefreshTimer?.cancel();
    _obsRefreshTimer = null;

    // 停止定时矫正定时器
    _correctionTimer?.cancel();
    _correctionTimer = null;

    // 取消 ConsoleLogService 订阅
    _consoleLogSubscription?.cancel();
    _consoleLogSubscription = null;
    _currentServerAddress = null;

    // 取消 server.map.runtime 频道订阅
    _unsubscribeFromMapRuntime();

    // 取消 ServerBloc 订阅
    _serverBlocSubscription?.cancel();
    _serverBlocSubscription = null;
    _serverBloc = null;

    // 清理查询结果
    _queriedServerInfo = null;

    // 关闭所有 WebSocket 客户端连接
    for (var ws in _clients) {
      try {
        await ws.close();
      } catch (e) {
        // 忽略关闭错误
      }
    }
    _clients.clear();

    // 关闭 HTTP 服务器
    if (_server != null) {
      try {
        await _server!.close(force: true);
      } catch (e) {
        _logger.w('关闭 OBS Server 时出错: $e');
      }
      _server = null;
    }
  }

  /// 启动独立的 OBS 数据刷新定时器
  /// 只轮询当前连接的服务器数据，不依赖全局刷新机制
  void _startObsRefreshTimer() {
    _obsRefreshTimer?.cancel();
    // 弱网模式下不启动 OBS 自动刷新（仍然保留矫正定时器作为长周期兜底）
    if (NetworkModeService.instance.weakNetwork) {
      _logger.i('[OBS] 弱网模式开启，跳过 OBS 自动数据刷新');
      _startCorrectionTimer();
      return;
    }
    _obsRefreshTimer = Timer.periodic(_obsRefreshInterval, (_) {
      _refreshCurrentServerData();
    });

    // 启动定时矫正定时器（作为额外保障，防止状态不同步）
    _startCorrectionTimer();
  }

  /// 定时矫正定时器
  Timer? _correctionTimer;
  static const Duration _correctionInterval = Duration(
    seconds: 30,
  ); // 每 30 秒矫正一次

  /// 启动定时矫正定时器
  /// 定期检查并矫正服务器状态，防止状态不同步
  void _startCorrectionTimer() {
    _correctionTimer?.cancel();
    _correctionTimer = Timer.periodic(_correctionInterval, (_) {
      _correctServerState();
    });
    _logger.d('[OBS] 启动定时矫正定时器，每 $_correctionInterval 检查一次');
  }

  /// 矫正服务器状态
  /// 比较 OBS 记录的服务器地址和 ConsoleLogService 报告的服务器地址
  /// 如果不一致，强制刷新数据
  Future<void> _correctServerState() async {
    try {
      final consoleLogService = ConsoleLogService();
      final consoleState = consoleLogService.currentState;
      final consoleAddress = consoleState.serverAddress;
      final isInServerFromConsole =
          consoleState.isInServer && consoleAddress.isNotEmpty;

      // 获取 OBS 当前记录的地址
      final obsAddress = _currentData['ip'] ?? '';

      if (isInServerFromConsole) {
        // 用户应该在服务器中
        if (obsAddress.isEmpty) {
          // OBS 显示不在服务器，但 ConsoleLog 报告在服务器
          // 这可能是状态同步延迟，强制刷新
          _logger.i('[OBS] 矫正：检测到用户在服务器中但 OBS 未显示，强制刷新');
          await _refreshCurrentServerData();
        } else {
          // 两者都显示在服务器中，检查地址是否一致
          // 需要比较原始地址（去除域名映射）
          final addressMapping = ServerAddressMappingService();
          final consoleDisplayAddress = addressMapping.getDomainAddress(
            consoleAddress,
          );

          if (obsAddress != consoleDisplayAddress) {
            // 地址不一致，说明服务器切换了但 OBS 没更新
            _logger.i(
              '[OBS] 矫正：检测到服务器切换 ($obsAddress -> $consoleDisplayAddress)，强制刷新',
            );
            await _refreshCurrentServerData();
          }
        }
      } else {
        // 用户应该不在服务器中
        if (_currentData['isConnected'] == true || obsAddress.isNotEmpty) {
          // OBS 显示在服务器，但 ConsoleLog 报告不在服务器
          _logger.i('[OBS] 矫正：检测到用户已离开服务器但 OBS 仍显示，强制重置');
          _queriedServerInfo = null;
          _currentData['isConnected'] = false;
          _currentData['serverName'] = _getWaitingText();
          _currentData['ping'] = '0';
          _currentData['players'] = '0/0';
          _currentData['map'] = '未知';
          _currentData['ip'] = '';
          _currentData['runtime'] = '';
          _currentData['mapName'] = '';
          _currentData['mapUrl'] = '';
          _currentData['mapLabel'] = '';
          _broadcast();
        }
      }
    } catch (e) {
      _logger.e('[OBS] 矫正过程出错: $e');
    }
  }

  /// 刷新当前连接的服务器数据
  Future<void> _refreshCurrentServerData() async {
    // 检查游戏是否正在运行
    bool isGameRunning = false;
    try {
      isGameRunning = GameStatusService().isGameRunning;
    } catch (_) {}

    if (!isGameRunning) {
      // 游戏已关闭，直接清空显示
      if (_currentData['isCleared'] != true) {
        _logger.i('[OBS] 检测到游戏已关闭，清空 OBS 显示');
        clearDisplay();
      }
      return;
    }

    // 获取 ConsoleLogService 状态
    final consoleLogService = ConsoleLogService();
    final consoleState = consoleLogService.currentState;
    final isInServerFromConsole =
        consoleState.isInServer && consoleState.serverAddress.isNotEmpty;

    if (!isInServerFromConsole) {
      // 用户没有在服务器中，显示"等待进入服务器"或"无法监控游戏"
      final targetWaitingText = _getWaitingText();
      if (_currentData['isConnected'] == true ||
          _queriedServerInfo != null ||
          _currentData['serverName'] != targetWaitingText ||
          _currentData['isCleared'] == true) {
        _queriedServerInfo = null;
        _currentData['isConnected'] = false;
        _currentData['isCleared'] = false;
        // 修改为显示等待进入服务器提示
        _currentData['serverName'] = targetWaitingText;
        _currentData['ping'] = '0';
        _currentData['players'] = '0/0';
        _currentData['map'] = '未知';
        _currentData['ip'] = '';
        _currentData['runtime'] = '';
        _currentData['mapName'] = '';
        _currentData['mapUrl'] = '';
        _currentData['mapLabel'] = '';
        _broadcast();
      }
      return;
    }

    // 用户在服务器中，直接用 A2S 查询
    final serverAddress = consoleState.serverAddress;

    // 查找列表中是否有该服务器（用于获取备注名）
    ExtendedServerItem? listServer;
    if (_serverBloc != null) {
      final state = _serverBloc!.state;
      listServer = _getConnectedServer(state.servers, serverAddress);
    }

    // 统一用 A2S 查询
    await _queryServerDirectly(serverAddress, listServer);
  }

  /// 直接用 A2S 查询服务器数据
  /// [listServer] 如果服务器在列表中，传入以获取备注名
  Future<void> _queryServerDirectly(
    String address, [
    ExtendedServerItem? listServer,
  ]) async {
    try {
      final parts = address.split(':');
      if (parts.length != 2) return;

      final ip = parts[0];
      final port = int.tryParse(parts[1]);
      if (port == null) return;

      final info = await SourceServerService.getServerInfo(
        ip,
        port,
        timeout: 3000,
      );
      if (info != null) {
        final prevInfo = _queriedServerInfo;
        final prevAddress = _currentData['ip']; // 获取之前查询的地址

        // 使用域名映射后的地址进行比较
        final addressMapping = ServerAddressMappingService();
        final currentDisplayAddress = addressMapping.getDomainAddress(address);

        _queriedServerInfo = info;

        // 检查数据是否有变化
        // 关键：必须检查地址是否变化！否则服务器切换时如果数据相同不会更新
        final dataChanged =
            prevInfo == null ||
            prevAddress != currentDisplayAddress ||
            prevInfo.name != info.name ||
            prevInfo.map != info.map ||
            prevInfo.players != info.players ||
            prevInfo.maxPlayers != info.maxPlayers ||
            _currentData['isCleared'] == true;

        if (dataChanged) {
          // 推送完整数据
          _currentData['isConnected'] = true;
          _currentData['isCleared'] = false;
          // 清除错误状态
          _currentData.remove('error');
          _currentData.remove('errorCode');
          // 优先使用列表中的备注名
          final displayName =
              listServer?.serverItem.getDisplayName(info.name) ?? info.name;
          _currentData['serverName'] = displayName;

          // 使用域名映射服务将 IP 转换为域名
          _currentData['ip'] = currentDisplayAddress;

          _currentData['ping'] = info.ping.toString();
          _currentData['players'] = '${info.players}/${info.maxPlayers}';
          _currentData['map'] = info.map;
          _currentData['mapName'] = info.map;
          _currentData['runtime'] = '';

          // 先获取地图译名，等待完成后再广播（避免时序问题）
          if (listServer?.mapInfo != null &&
              listServer!.mapInfo!.mapLabel.isNotEmpty) {
            _currentData['mapUrl'] = listServer.mapInfo!.mapUrl;
            _currentData['mapLabel'] = listServer.mapInfo!.mapLabel;
            _logger.d(
              '[OBS] 使用缓存地图信息: ${info.map}, 译名: ${_currentData['mapLabel']}',
            );
          } else {
            _logger.d('[OBS] 开始获取地图信息: ${info.map}');
            await _fetchMapInfo(info.map);
          }

          _currentData['isListServer'] = listServer != null;
          _broadcast();
          _logger.d(
            '[OBS] 查询服务器完成: $currentDisplayAddress, 玩家: ${info.players}/${info.maxPlayers}, 地图: ${info.map}, 译名: ${_currentData['mapLabel']}',
          );
        }
      }
    } catch (e) {
      _logger.e('[OBS] 查询服务器失败: $address, 错误: $e');
      // 设置错误状态，让 OBS 端可以显示
      _currentData['isConnected'] = false;
      _currentData['serverName'] = '查询失败';
      _currentData['error'] = '无法连接到服务器';
      _currentData['errorCode'] = 'CONNECTION_FAILED';
      _currentData['errorDetail'] = e.toString(); // 添加详细错误信息
      _broadcast();
    }
  }

  /// 获取地图信息（译名和背景图）
  /// 返回地图数据，由调用方负责广播
  Future<MapData?> _fetchMapInfo(String mapName) async {
    try {
      _logger.d('[OBS] 开始请求地图信息 API: $mapName');
      final serverApi = ServerApi();
      final mapData = await serverApi.refreshMapInfo(mapName);
      _logger.d('[OBS] 地图 API 返回: mapData=$mapData');
      if (mapData != null) {
        _currentData['mapUrl'] = mapData.mapUrl;
        _currentData['mapLabel'] = mapData.mapLabel;
        _logger.d(
          '[OBS] 地图信息已获取: $mapName, 译名: ${mapData.mapLabel}, URL: ${mapData.mapUrl}',
        );
        return mapData;
      } else {
        _logger.w('[OBS] 地图 API 返回 null: $mapName');
        _currentData['mapUrl'] = '';
        _currentData['mapLabel'] = '';
        return null;
      }
    } catch (e) {
      _logger.e('[OBS] 获取地图信息失败: $mapName, $e');
      _currentData['mapUrl'] = '';
      _currentData['mapLabel'] = '';
      return null;
    }
  }

  // 内置的 HTML 内容，不依赖外部文件，方便直接运行
  static const String _htmlContent = r'''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>BakaBox OBS Overlay</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400;500;600;700&display=swap');
    
    body { 
      margin: 0; 
      background: transparent; 
      overflow: hidden; 
      font-family: 'Segoe UI', 'Noto Sans SC', Tahoma, Geneva, Verdana, sans-serif; 
    }
    .widget-element { 
      position: absolute; 
      white-space: pre-wrap;
      transition: left 0.1s linear, top 0.1s linear, transform 0.1s linear;
      transform-origin: top left;
    }
    
    /* Server Card - 完全匹配 ServerCard.dart */
    .server-card {
      position: relative;
      width: 450px;
      height: 140px;
      border-radius: 6px;
      border: 2px solid rgba(0, 128, 255, 0.6);
      box-shadow: 0 2px 4px rgba(0,0,0,0.1), 0 0 0 rgba(0,0,0,0);
      background-color: #1e1e1e;
      overflow: hidden;
    }
    .server-card.hover { border-color: rgba(0, 128, 255, 0.8); }
    .server-card.warming { border-color: rgba(255, 165, 0, 0.8); box-shadow: 0 0 8px rgba(255, 165, 0, 0.5); }
    .server-card.queueing { border-color: rgba(34, 197, 94, 0.8); box-shadow: 0 0 12px rgba(34, 197, 94, 0.4); }
    .bg-layer { position: absolute; top: 0; left: 0; right: 0; bottom: 0; background-size: cover; background-position: center; transition: background-image 0.5s ease; }
    .gradient-layer { position: absolute; top: 0; left: 0; right: 0; bottom: 0; background: linear-gradient(to bottom, rgba(0,0,0,0.1) 0%, rgba(0,0,0,0.2) 30%, rgba(0,0,0,0.6) 100%); }
    
    /* 左侧内容区域 */
    .card-left {
      position: absolute;
      left: 17px;
      top: 17px;
      right: 120px;
      display: flex;
      flex-direction: column;
      gap: 12px;
      z-index: 10;
    }
    
    /* 服务器名称 */
    .card-title {
      font-weight: bold; color: white;
      text-shadow: 0 1px 3px black, 0 0 8px black, 1px 1px 0 black, -1px -1px 0 black;
      white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
      max-width: 280px;
    }
    
    /* 地图行 */
    .card-map-row {
      display: flex;
      align-items: center;
      gap: 0;
    }
    .card-map-label {
      color: white;
      text-shadow: 0 1px 2px black, 0 0 6px black;
    }
    .card-map-name {
      color: white;
      text-shadow: 0 1px 2px black, 0 0 6px black;
      max-width: 200px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    
    /* 地址行 - 地址 + 分隔符 + ping */
    .card-address-row {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .card-address {
      font-family: 'Consolas', 'Monaco', monospace; color: white;
      text-shadow: 0 1px 2px black, 0 0 6px black;
      max-width: 220px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .card-separator {
      color: rgba(255,255,255,0.3);
      flex-shrink: 0;
    }
    
    /* 右侧内容区域 */
    .card-right {
      position: absolute;
      right: 17px;
      top: 17px;
      display: flex;
      flex-direction: column;
      align-items: flex-end;
      gap: 6px;
      z-index: 10;
    }
    
    /* 玩家数量 - 白色圆角卡片 */
    .players-badge {
      background: white;
      border-radius: 6px;
      padding: 8px 10px;
      display: flex;
      align-items: baseline;
      gap: 2px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.2), 0 2px 4px rgba(0,0,0,0.1);
      border: 1px solid rgba(255,255,255,0.3);
    }
    .players-current { font-size: 28px; font-weight: bold; color: #0080FF; line-height: 1; }
    .players-sep { font-size: 18px; font-weight: 300; color: #9CA3AF; }
    .players-max { font-size: 16px; font-weight: 600; color: #6B7280; }
    
    /* 玩家状态 */
    .players-badge.full { background: #FEEAEA; }
    .players-badge.full .players-current { color: #F44336; }
    .players-badge.near-full { background: #FFF9E6; }
    .players-badge.near-full .players-current { color: #FF9800; }
    
    /* 运行时间信息 */
    .runtime-badge {
      background: white;
      border-radius: 6px;
      padding: 6px 10px;
      display: flex;
      flex-direction: column;
      align-items: flex-start;
      gap: 2px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.2), 0 2px 4px rgba(0,0,0,0.1);
      border: 1px solid rgba(255,255,255,0.3);
    }
    .runtime-time {
      font-size: 11px; font-weight: 600; color: #1F2937;
      display: flex;
      align-items: center;
      gap: 4px;
    }
    .runtime-time-icon { font-size: 12px; }
    .runtime-score {
      font-size: 11px; font-weight: 500;
      display: flex;
      align-items: center;
      gap: 4px;
    }
    .score-ct { color: #3B82F6; }
    .score-t { color: #EAB308; }
    .score-zombie { color: #22C55E; }
    .score-zombie2 { color: #EF4444; }
    .score-sep { color: #6B7280; margin: 0 2px; }
    
    /* 延迟徽章 */
    .ping-badge {
      padding: 2px 6px; border-radius: 4px; font-size: 12px; font-weight: 600;
    }
    .ping-badge-good { background: rgba(0, 208, 132, 0.1); color: #00D084; box-shadow: 0 0 8px rgba(0, 208, 132, 0.3); }
    .ping-badge-medium { background: rgba(82, 196, 26, 0.1); color: #52C41A; box-shadow: 0 0 8px rgba(82, 196, 26, 0.3); }
    .ping-badge-warning { background: rgba(250, 173, 20, 0.1); color: #FAAD14; box-shadow: 0 0 8px rgba(250, 173, 20, 0.3); }
    .ping-badge-poor { background: rgba(255, 122, 69, 0.1); color: #FF7A45; box-shadow: 0 0 8px rgba(255, 122, 69, 0.3); }
    .ping-badge-bad { background: rgba(255, 77, 79, 0.1); color: #FF4D4F; box-shadow: 0 0 8px rgba(255, 77, 79, 0.3); }
    .ping-badge-unknown { background: rgba(153, 153, 153, 0.1); color: #999999; }
  </style>
</head>
<body>
  <div id="container"></div>
  <script>
    const container = document.getElementById('container');
    let ws = null;
    let reconnectAttempts = 0;
    let heartbeatTimer = null;
    let isConnecting = false;
    
    function connect() {
      // 防止重复创建连接
      if (isConnecting && ws && ws.readyState === WebSocket.CONNECTING) {
        return;
      }
      
      // 如果已有连接且状态正常，不重连
      if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
        return;
      }
      
      isConnecting = true;
      
      // 清理旧连接
      if (ws) {
        try {
          ws.onclose = null;
          ws.onerror = null;
          ws.onopen = null;
          ws.onmessage = null;
          if (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING) {
            ws.close();
          }
        } catch (e) {
          console.log('[OBS WebSocket] 清理旧连接:', e);
        }
      }
      
      try {
        ws = new WebSocket('ws://127.0.0.1:25566/ws');
        
        ws.onopen = () => {
          console.log('[OBS WebSocket] 连接成功');
          isConnecting = false;
          reconnectAttempts = 0;
          // 连接成功后立即请求最新数据
          startHeartbeat();
        };
        
        ws.onmessage = (event) => {
          const msg = JSON.parse(event.data);
          console.log('[OBS WebSocket] 收到消息:', msg);
          console.log('[OBS WebSocket] mapLabel:', msg.data?.mapLabel);
          console.log('[OBS WebSocket] map:', msg.data?.map);
          if (msg.type === 'update' || msg.type === 'init') {
            render(msg.layout, msg.data);
          }
        };

        ws.onerror = (error) => {
          console.log('[OBS WebSocket] 错误:', error);
          isConnecting = false;
        };

        ws.onclose = (event) => {
          console.log('[OBS WebSocket] 连接关闭, code:', event.code, 'reason:', event.reason);
          isConnecting = false;
          stopHeartbeat();
          
          // 如果不是正常关闭，则尝试重连
          if (event.code !== 1000) {
            // 使用指数退避策略重连
            const delay = Math.min(1000 * Math.pow(2, reconnectAttempts), 30000);
            reconnectAttempts++;
            console.log('[OBS WebSocket] 准备重连, 延迟:', delay, 'ms, 尝试次数:', reconnectAttempts);
            setTimeout(connect, delay);
          }
        };
      } catch (e) {
        console.log('[OBS WebSocket] 创建连接失败:', e);
        isConnecting = false;
        setTimeout(connect, 2000);
      }
    }
    
    // 启动心跳检测
    function startHeartbeat() {
      stopHeartbeat();
      heartbeatTimer = setInterval(() => {
        if (ws && ws.readyState === WebSocket.OPEN) {
          // 发送心跳
          try {
            ws.send(JSON.stringify({ type: 'ping' }));
            console.log('[OBS WebSocket] 发送心跳');
          } catch (e) {
            console.log('[OBS WebSocket] 发送心跳失败:', e);
          }
        }
      }, 15000); // 每15秒发送一次心跳
    }
    
    // 停止心跳检测
    function stopHeartbeat() {
      if (heartbeatTimer) {
        clearInterval(heartbeatTimer);
        heartbeatTimer = null;
      }
    }
    
    // 页面可见性变化时，尝试重新连接
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') {
        console.log('[OBS WebSocket] 页面变为可见，检测连接状态');
        if (!ws || ws.readyState !== WebSocket.OPEN) {
          reconnectAttempts = 0; // 重置重连计数
          connect();
        }
      }
    });
    
    // 页面加载完成后立即尝试连接
    window.addEventListener('load', () => {
      console.log('[OBS WebSocket] 页面加载完成');
      connect();
    });
    
    // 页面卸载时清理连接
    window.addEventListener('beforeunload', () => {
      stopHeartbeat();
      if (ws) {
        ws.close(1000);
      }
    });

    // 转换十六进制颜色为 rgba 格式
    // 支持 #RRGGBB 和 #AARRGGBB 格式
    function convertHexToRgba(hexColor) {
      if (!hexColor) return null;
      
      // 移除 # 号
      hexColor = hexColor.replace('#', '');
      
      let r, g, b, a = 1;
      
      if (hexColor.length === 6) {
        // #RRGGBB 格式
        r = parseInt(hexColor.substring(0, 2), 16);
        g = parseInt(hexColor.substring(2, 4), 16);
        b = parseInt(hexColor.substring(4, 6), 16);
        a = 1;
      } else if (hexColor.length === 8) {
        // #AARRGGBB 格式（Dart 存储格式，alpha 在前）
        a = parseInt(hexColor.substring(0, 2), 16) / 255;
        r = parseInt(hexColor.substring(2, 4), 16);
        g = parseInt(hexColor.substring(4, 6), 16);
        b = parseInt(hexColor.substring(6, 8), 16);
      } else {
        return null;
      }
      
      return 'rgba(' + r + ',' + g + ',' + b + ',' + a.toFixed(2) + ')';
    }

    function getPingColor(ping) {
      if (ping === null || ping === undefined || ping === '???') return 'unknown';
      const p = parseInt(ping) || 0;
      if (p < 50) return 'good';
      if (p < 100) return 'medium';
      if (p < 150) return 'warning';
      if (p < 300) return 'poor';
      return 'bad';
    }

    function getPlayersClass(players, maxPlayers) {
      const current = parseInt(players) || 0;
      const max = parseInt(maxPlayers) || 0;
      if (max > 0 && current >= max) return 'full';
      if (max > 0 && current >= max * 0.8) return 'near-full';
      return '';
    }

    function parsePlayers(playersStr) {
      if (!playersStr) return { current: 0, max: 0 };
      const parts = playersStr.split('/');
      return { current: parseInt(parts[0]) || 0, max: parseInt(parts[1]) || 0 };
    }

    // 判断是否为僵尸逃跑/感染地图
    function isZombieMap(mapName) {
      if (!mapName) return false;
      const lower = mapName.toLowerCase();
      return lower.startsWith('ze_') || lower.startsWith('zm_');
    }

    function render(layout, data) {
      if (!layout || !layout.elements) return;
      container.innerHTML = '';
      
      // 如果收到清空信号（软件退出），完全隐藏内容
      if (data.isCleared) {
        return;
      }
      
      layout.elements.forEach(el => {
        const wrapper = document.createElement('div');
        wrapper.className = 'widget-element';
        wrapper.style.left = el.x + 'px';
        wrapper.style.top = el.y + 'px';
        wrapper.style.transform = 'scale(' + (el.scale || 1.0) + ')';
        
        if (el.type === 'server_card') {
           const card = document.createElement('div');
           card.className = 'server-card';
           
           let bgStyle = '';
           if (el.showMapImage !== false) {
              if (data.mapUrl) {
                 bgStyle = "background-image: url('" + data.mapUrl + "');";
              } else {
                 // 没有地图背景时使用默认背景
                 bgStyle = "background-image: url('assets/images/default-map-bg.jpg');";
              }
           }
           if (el.bgBlur) {
              bgStyle += " filter: blur(" + el.bgBlur + "px);";
           }
           
           let gradOpacity = el.gradientOpacity !== undefined ? el.gradientOpacity : 0.6;
           let gradStyle = "background: linear-gradient(to bottom, rgba(0,0,0,0.1) 0%, rgba(0,0,0,0.2) 30%, rgba(0,0,0," + gradOpacity + ") 100%);";

           // 未连接时显示"等待进入服务器"
           const serverName = data.isConnected ? (data.serverName || '未连接') : (data.serverName || '等待进入服务器');
           const ip = data.ip || '';
           const playersStr = data.players || '0/0';
           const mapRaw = data.map || '未知地图';
           const mapName = (data.mapLabel && data.mapLabel !== mapRaw) 
               ? data.mapLabel + '(' + mapRaw + ')' 
               : mapRaw;
           const mapUrl = data.mapUrl || '';
           
           const players = parsePlayers(playersStr);
           const playersClass = getPlayersClass(players.current, players.max);
           
           const showTitle = el.showTitle !== false;
           const showIp = el.showIp !== false;
           const showPlayers = el.showPlayers !== false;
           const showMap = el.showMap !== false;
           
           // 文字大小配置
           const titleFontSize = el.titleFontSize || 20;
           const mapFontSize = el.mapFontSize || 16;
           const ipFontSize = el.ipFontSize || 15;

           // 构建左侧内容
           let leftContent = '';
           if (showTitle) {
             leftContent += '<div class="card-title" style="font-size:' + titleFontSize + 'px;">' + serverName + '</div>';
           }
           if (showMap) {
             leftContent += '<div class="card-map-row"><span class="card-map-label" style="font-size:' + mapFontSize + 'px;">地图：</span><span class="card-map-name" style="font-size:' + mapFontSize + 'px;">' + mapName + '</span></div>';
           }
           if (showIp) {
             leftContent += '<div class="card-address-row"><span class="card-address" style="font-size:' + ipFontSize + 'px;">' + ip + '</span></div>';
           }
           
           // 构建右侧内容
           let rightContent = '';
           if (showPlayers) {
             rightContent += '<div class="players-badge ' + playersClass + '">' +
               '<span class="players-current">' + players.current + '</span>' +
               '<span class="players-sep">/</span>' +
               '<span class="players-max">' + players.max + '</span>' +
             '</div>';
           }

           card.innerHTML = 
              '<div class="bg-layer" style="' + bgStyle + '"></div>' +
              '<div class="gradient-layer" style="' + gradStyle + '"></div>' +
              '<div class="card-left">' + leftContent + '</div>' +
              '<div class="card-right">' + rightContent + '</div>';
           
           wrapper.appendChild(card);
        } else if (el.type === 'text') {
           // 转换文本颜色为 rgba 格式
           wrapper.style.color = convertHexToRgba(el.textColor || el.color) || '#FFFFFF';
           if (el.showBackground !== false) {
             // 转换十六进制颜色为 rgba 格式（支持 #RRGGBB 和 #AARRGGBB 格式）
             wrapper.style.backgroundColor = convertHexToRgba(el.backgroundColor) || 'rgba(0,0,0,0.5)';
             // 使用动态的内边距和圆角设置
             const paddingVal = el.padding !== undefined ? el.padding : 12;
             wrapper.style.padding = paddingVal + 'px';
             const radiusVal = el.borderRadius !== undefined ? el.borderRadius : 8;
             wrapper.style.borderRadius = radiusVal + 'px';
           }
           wrapper.style.fontSize = (el.fontSize || 24) + 'px';
           wrapper.style.fontWeight = el.fontWeight || 'normal';
           // 处理斜体
           if (el.fontStyle === 'italic') {
             wrapper.style.fontStyle = 'italic';
           } else {
             wrapper.style.fontStyle = 'normal';
           }
           // 处理下划线
           if (el.decoration === 'underline') {
             wrapper.style.textDecoration = 'underline';
           }
           // 处理对齐方式
           if (el.textAlign === 'center') {
             wrapper.style.textAlign = 'center';
           } else if (el.textAlign === 'right') {
             wrapper.style.textAlign = 'right';
           } else {
             wrapper.style.textAlign = 'left';
           }
          // 处理文字阴影
          if (el.showTextShadow !== false) {
            const shadowBlur = el.shadowBlur !== undefined ? el.shadowBlur : 4;
            const shadowOffset = el.shadowOffset !== undefined ? el.shadowOffset : 2;
            const shadowColor = 'rgba(0,0,0,0.5)';
            // 根据scale调整阴影偏移和模糊，抵消CSS transform scale的影响
            const scale = el.scale || 1.0;
            const adjustedOffset = shadowOffset / scale;
            const adjustedBlur = shadowBlur / scale;
            wrapper.style.textShadow = adjustedOffset + 'px ' + adjustedOffset + 'px ' + adjustedBlur + 'px ' + shadowColor;
          }
          // 处理文字描边 - 使用 text-shadow 模拟外描边，避免侵入文字
          if (el.showTextStroke) {
            const strokeWidth = el.strokeWidth !== undefined ? el.strokeWidth : 2;
            const strokeColor = convertHexToRgba(el.strokeColor) || '#000000';
            // 使用 text-shadow 多层叠加模拟外描边效果
            // 这样描边只会在文字外侧，不会侵入文字内部
            const w = strokeWidth;
            const color = strokeColor;
            wrapper.style.textShadow = 
              color + ' ' + w + 'px 0 0, ' +      // 右
              color + ' -' + w + 'px 0 0, ' +     // 左
              color + ' 0 ' + w + 'px 0, ' +      // 下
              color + ' 0 -' + w + 'px 0, ' +     // 上
              color + ' ' + w + 'px ' + w + 'px 0, ' +   // 右下
              color + ' -' + w + 'px ' + w + 'px 0, ' +  // 左下
              color + ' ' + w + 'px -' + w + 'px 0, ' +   // 右上
              color + ' -' + w + 'px -' + w + 'px 0';    // 左上
          }
           
           let text = el.template || '';
           
           // 特殊处理 {map} 变量，显示译名+原名
           const mapRaw = data.map || '未知地图';
           const mapDisplay = (data.mapLabel && data.mapLabel !== mapRaw) 
               ? data.mapLabel + '(' + mapRaw + ')' 
               : mapRaw;
           text = text.replace(/{map}/g, mapDisplay);
           
           for (const key in data) {
             const regex = new RegExp('{' + key + '}', 'g');
             text = text.replace(regex, data[key] || '');
           }
           // 清理未识别的变量占位符
           text = text.replace(/{[^}]+}/g, '');
           wrapper.innerHTML = text; 
        }
        
        container.appendChild(wrapper);
      });
    }

    connect();
  </script>
</body>
</html>''';
}
