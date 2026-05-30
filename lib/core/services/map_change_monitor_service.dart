import 'dart:async';
import 'dart:convert';

import '../api/server_api.dart';
import '../utils/log_service.dart';
import '../utils/storage_utils.dart';
import 'notification_window_service.dart';
import 'realtime/realtime_server_map_runtime_channel.dart';
import 'realtime/realtime_server_users_count_channel.dart';
import 'source_server_service.dart';

/// 服务器监控数据
class ServerMonitorData {
  final String serverAddress;
  final String serverName;
  final String? categoryName; // 分类名称
  String? lastMapName;
  DateTime? lastCheckTime;

  // 上次发送通知的换图记录（用于防止重复通知）
  DateTime? _lastNotificationTime;
  String? _lastNotifiedOldMap;
  String? _lastNotifiedNewMap;

  ServerMonitorData({
    required this.serverAddress,
    required this.serverName,
    this.categoryName,
    this.lastMapName,
    this.lastCheckTime,
  });

  /// 检查是否应该发送通知（防止短时间内重复通知同一换图）
  bool shouldNotify(String oldMap, String newMap) {
    if (_lastNotificationTime == null) return true;
    if (_lastNotifiedOldMap != oldMap || _lastNotifiedNewMap != newMap) {
      return true;
    }
    final elapsed = DateTime.now().difference(_lastNotificationTime!).inSeconds;
    return elapsed > 30;
  }

  void markNotified(String oldMap, String newMap) {
    _lastNotificationTime = DateTime.now();
    _lastNotifiedOldMap = oldMap;
    _lastNotifiedNewMap = newMap;
  }
}

/// 换图监控服务（单例）
///
/// 通过 `server.map.runtime` WS 频道接收换图推送：
/// - 订阅时服务端会下发一次 snapshot，用来初始化 [_lastMapName]，避免重连后重复通知
/// - changed 事件直接驱动通知，0 轮询
class MapChangeMonitorService {
  static final MapChangeMonitorService _instance =
      MapChangeMonitorService._internal();
  factory MapChangeMonitorService() => _instance;
  MapChangeMonitorService._internal();

  /// 监控中的服务器
  final Map<String, ServerMonitorData> _monitoredServers = {};

  /// 实时频道
  final RealtimeServerMapRuntimeChannel _realtimeChannel =
      RealtimeServerMapRuntimeChannel();

  StreamSubscription<ServerMapRuntimeEvent>? _realtimeSubscription;

  /// 是否已订阅 WS 频道
  bool _realtimeSubscribed = false;

  /// 存储 key
  static const String _storageKey = 'monitored_servers';

  /// 依赖服务
  final ServerApi _serverApi = ServerApi();
  final NotificationWindowService _notificationService =
      NotificationWindowService();

  /// 监控状态流
  final _monitorStateController = StreamController<Set<String>>.broadcast();
  Stream<Set<String>> get monitorStateStream => _monitorStateController.stream;

  /// 获取监控中的服务器地址列表
  Set<String> get monitoredAddresses => _monitoredServers.keys.toSet();

  /// 检查服务器是否在监控中
  bool isMonitoring(String serverAddress) =>
      _monitoredServers.containsKey(serverAddress);

  /// 初始化服务（应用启动时调用）
  Future<void> initialize() async {
    await _loadMonitoredServers();
    _startRealtime();
    LogService.d(
      '[MapChangeMonitor] 服务已初始化，监控 ${_monitoredServers.length} 个服务器',
    );
  }

  /// 添加服务器到监控列表
  Future<void> addMonitor({
    required String serverAddress,
    required String serverName,
    String? categoryName,
    String? currentMap,
  }) async {
    if (_monitoredServers.containsKey(serverAddress)) return;

    _monitoredServers[serverAddress] = ServerMonitorData(
      serverAddress: serverAddress,
      serverName: serverName,
      categoryName: categoryName,
      lastMapName: currentMap ?? _readSnapshotMap(serverAddress),
      lastCheckTime: DateTime.now(),
    );

    await _saveMonitoredServers();
    _notifyStateChange();
    _startRealtime();

    LogService.d('[MapChangeMonitor] 添加监控: $serverAddress ($serverName)');
  }

  /// 从监控列表移除服务器
  Future<void> removeMonitor(String serverAddress) async {
    if (!_monitoredServers.containsKey(serverAddress)) return;

    _monitoredServers.remove(serverAddress);
    await _saveMonitoredServers();
    _notifyStateChange();

    if (_monitoredServers.isEmpty) {
      _stopRealtime();
    }

    LogService.d('[MapChangeMonitor] 移除监控: $serverAddress');
  }

  /// 切换监控状态
  Future<bool> toggleMonitor({
    required String serverAddress,
    required String serverName,
    String? categoryName,
    String? currentMap,
  }) async {
    if (isMonitoring(serverAddress)) {
      await removeMonitor(serverAddress);
      return false;
    } else {
      await addMonitor(
        serverAddress: serverAddress,
        serverName: serverName,
        categoryName: categoryName,
        currentMap: currentMap,
      );
      return true;
    }
  }

  // ---- 实时频道 ----

  void _startRealtime() {
    if (_realtimeSubscribed) return;
    if (_monitoredServers.isEmpty) return;

    _realtimeSubscribed = true;
    _realtimeChannel.subscribe();
    _realtimeSubscription = _realtimeChannel.events.listen(_onRealtimeEvent);
    LogService.d('[MapChangeMonitor] 实时通道已启动');
  }

  void _stopRealtime() {
    if (!_realtimeSubscribed) return;
    _realtimeSubscribed = false;
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _realtimeChannel.unsubscribe();
    LogService.d('[MapChangeMonitor] 实时通道已停止');
  }

  String? _readSnapshotMap(String serverAddress) =>
      _realtimeChannel.snapshotFor(serverAddress)?.mapName;

  void _onRealtimeEvent(ServerMapRuntimeEvent event) {
    switch (event.kind) {
      case ServerMapRuntimeEventKind.snapshot:
        _onSnapshot(event.entries);
        break;
      case ServerMapRuntimeEventKind.changed:
        for (final entry in event.entries) {
          _onChanged(entry);
        }
        break;
    }
  }

  void _onSnapshot(List<ServerMapRuntimeEntry> entries) {
    // 用 snapshot 校准当前地图，但不触发通知（避免上线 / 重连时刷一波）
    for (final entry in entries) {
      final monitor = _monitoredServers[entry.serverAddress];
      if (monitor == null) continue;
      monitor.lastMapName = entry.mapName;
      monitor.lastCheckTime = DateTime.now();
    }
  }

  Future<void> _onChanged(ServerMapRuntimeEntry entry) async {
    final monitor = _monitoredServers[entry.serverAddress];
    if (monitor == null) return;

    final newMap = entry.mapName;
    final oldMap = entry.oldMapName ?? monitor.lastMapName;
    monitor.lastMapName = newMap;
    monitor.lastCheckTime = DateTime.now();

    // 过滤 graphics_settings（服务器重启时的加载地图）
    if (newMap == 'graphics_settings' || oldMap == 'graphics_settings') {
      return;
    }

    // 没有旧地图（首次接到此服务器的事件），仅记录不通知
    if (oldMap == null || oldMap.isEmpty || oldMap == newMap) {
      return;
    }

    if (!monitor.shouldNotify(oldMap, newMap)) {
      LogService.d(
        '[MapChangeMonitor] 重复换图事件，跳过通知: ${entry.serverAddress} $oldMap → $newMap',
      );
      return;
    }

    monitor.markNotified(oldMap, newMap);

    LogService.d(
      '[MapChangeMonitor] 检测到换图: ${entry.serverAddress}, $oldMap → $newMap',
    );

    // 异步获取地图信息（中文名 + 背景），失败不影响通知
    String? newMapCn;
    String? mapBackground;
    try {
      final mapInfo = await _serverApi.getMapInfo(newMap);
      newMapCn = mapInfo?.mapLabel;
      mapBackground = mapInfo?.mapUrl;
    } catch (_) {}

    int currentPlayers = 0;
    try {
      final parts = entry.serverAddress.split(':');
      if (parts.length == 2) {
        final ip = parts[0];
        final port = int.tryParse(parts[1]);
        if (port != null) {
          final serverInfo = await SourceServerService.getServerInfo(
            ip,
            port,
            timeout: 3000,
          );
          if (serverInfo != null) {
            currentPlayers = serverInfo.players;
          }
        }
      }
    } catch (_) {}

    final usersCountSnapshot = RealtimeServerUsersCountChannel().latestSnapshot;
    final usersCount = usersCountSnapshot[entry.serverAddress];

    _notificationService.showMapChangeNotification(
      serverAddress: entry.serverAddress,
      serverName: monitor.serverName,
      oldMap: oldMap,
      newMap: newMap,
      newMapCn: newMapCn,
      mapBackground: mapBackground,
      categoryName: monitor.categoryName,
      currentPlayers: currentPlayers,
      maxPlayers: entry.maxPlayers ?? 0,
      queueCount: usersCount?.queueCount ?? 0,
      warmupCount: usersCount?.warmupCount ?? 0,
    );
  }

  // ---- 持久化 ----

  /// 保存监控列表到本地存储（JSON格式）
  Future<void> _saveMonitoredServers() async {
    try {
      final List<String> data = _monitoredServers.entries.map((e) {
        final isCustomCategory =
            e.value.categoryName != null && e.value.categoryName!.isNotEmpty;
        return jsonEncode({
          'address': e.key,
          'serverName': e.value.serverName,
          'categoryName': e.value.categoryName,
          'isCustomCategory': isCustomCategory,
        });
      }).toList();
      await StorageUtils.setStringList(_storageKey, data);
    } catch (e) {
      LogService.e('[MapChangeMonitor] 保存监控列表失败', e);
    }
  }

  /// 从本地存储加载监控列表
  ///
  /// 启动时不加载之前保存的地图名，依赖 WS 的 snapshot 来校准当前地图，
  /// 避免在 changed 事件中误触发通知。
  Future<void> _loadMonitoredServers() async {
    try {
      final data = StorageUtils.getStringList(_storageKey);

      for (final item in data) {
        try {
          final map = jsonDecode(item) as Map<String, dynamic>;
          final address = map['address'] as String;
          final serverName = map['serverName'] as String;
          final isCustomCategory = map['isCustomCategory'] as bool? ?? false;
          final categoryName = isCustomCategory
              ? (map['categoryName'] as String?)
              : null;

          _monitoredServers[address] = ServerMonitorData(
            serverAddress: address,
            serverName: serverName,
            categoryName: categoryName,
            lastMapName: null,
          );
        } catch (_) {
          // 兼容旧格式: address|serverName|...
          final parts = item.split('|');
          if (parts.length >= 2) {
            _monitoredServers[parts[0]] = ServerMonitorData(
              serverAddress: parts[0],
              serverName: parts[1],
              categoryName: null,
              lastMapName: null,
            );
          }
        }
      }
    } catch (e) {
      LogService.e('[MapChangeMonitor] 加载监控列表失败', e);
    }
  }

  void _notifyStateChange() {
    if (!_monitorStateController.isClosed) {
      _monitorStateController.add(monitoredAddresses);
    }
  }

  /// 销毁服务
  void dispose() {
    _stopRealtime();
    _monitoredServers.clear();
    _monitorStateController.close();
  }
}
