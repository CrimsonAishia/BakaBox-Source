import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/server_api.dart';
import '../utils/log_service.dart';
import 'notification_window_service.dart';
import 'source_server_service.dart';

/// 服务器监控数据
class ServerMonitorData {
  final String serverAddress;
  final String serverName;
  final String? categoryName;  // 分类名称
  String? lastMapName;
  String? lastMapNameCn;
  DateTime? lastCheckTime;
  bool _isChecking = false;  // 防止并发检查
  int _consecutiveFailures = 0;  // 连续失败次数
  
  // 上次发送通知的换图记录（用于防止重复通知）
  DateTime? _lastNotificationTime;
  String? _lastNotifiedOldMap;  // 记录旧地图
  String? _lastNotifiedNewMap;  // 记录新地图

  ServerMonitorData({
    required this.serverAddress,
    required this.serverName,
    this.categoryName,
    this.lastMapName,
    this.lastMapNameCn,
    this.lastCheckTime,
  });
  
  /// 检查是否应该发送通知（防止短时间内重复通知同一换图）
  bool shouldNotify(String oldMap, String newMap) {
    // 如果从未通知过，允许通知
    if (_lastNotificationTime == null) {
      return true;
    }
    
    // 如果是不同的换图组合（oldMap→newMap），允许通知
    if (_lastNotifiedOldMap != oldMap || _lastNotifiedNewMap != newMap) {
      return true;
    }
    
    // 如果是相同的换图组合，检查时间间隔（30秒内不重复通知）
    final timeSinceLastNotification = DateTime.now().difference(_lastNotificationTime!);
    return timeSinceLastNotification.inSeconds > 30;
  }
  
  /// 记录已发送通知
  void markNotified(String oldMap, String newMap) {
    _lastNotificationTime = DateTime.now();
    _lastNotifiedOldMap = oldMap;
    _lastNotifiedNewMap = newMap;
  }
  
  /// 记录查询失败
  void recordFailure() => _consecutiveFailures++;
  
  /// 重置失败计数
  void resetFailures() => _consecutiveFailures = 0;
  
  /// 是否应该跳过检查（连续失败超过3次后暂停一段时间）
  bool get shouldSkipDueToFailures => _consecutiveFailures >= 3;
}

/// 换图监控服务（单例）
/// 
/// 监控指定服务器的地图变化，当检测到换图时发送通知
class MapChangeMonitorService {
  static final MapChangeMonitorService _instance = MapChangeMonitorService._internal();
  factory MapChangeMonitorService() => _instance;
  MapChangeMonitorService._internal();

  /// 监控中的服务器
  final Map<String, ServerMonitorData> _monitoredServers = {};
  
  /// 监控定时器
  Timer? _monitorTimer;
  
  /// 是否暂停监控（服务器页面打开时暂停）
  bool _isPaused = false;
  
  /// 监控间隔（秒）- 缩短到20秒提高检测及时性
  static const int monitorIntervalSeconds = 20;
  
  /// 存储 key
  static const String _storageKey = 'monitored_servers';

  /// 依赖服务
  final ServerApi _serverApi = ServerApi();
  final NotificationWindowService _notificationService = NotificationWindowService();

  /// 监控状态流
  final _monitorStateController = StreamController<Set<String>>.broadcast();
  Stream<Set<String>> get monitorStateStream => _monitorStateController.stream;

  /// 获取监控中的服务器地址列表
  Set<String> get monitoredAddresses => _monitoredServers.keys.toSet();

  /// 检查服务器是否在监控中
  bool isMonitoring(String serverAddress) => _monitoredServers.containsKey(serverAddress);
  
  /// 是否已暂停
  bool get isPaused => _isPaused;

  /// 暂停监控（服务器页面打开时调用）
  void pauseMonitor() {
    if (_isPaused) return;
    _isPaused = true;
    _stopMonitorLoop();
    LogService.d('[MapChangeMonitor] 监控已暂停（服务器页面活跃）');
  }

  /// 恢复监控（离开服务器页面时调用）
  void resumeMonitor() {
    if (!_isPaused) return;
    _isPaused = false;
    _startMonitorLoop();
    LogService.d('[MapChangeMonitor] 监控已恢复');
  }

  /// 初始化服务（应用启动时调用）
  Future<void> initialize() async {
    await _loadMonitoredServers();
    _startMonitorLoop();
    LogService.i('[MapChangeMonitor] 服务已初始化，监控 ${_monitoredServers.length} 个服务器');
  }

  /// 添加服务器到监控列表
  Future<void> addMonitor({
    required String serverAddress,
    required String serverName,
    String? categoryName,
    String? currentMap,
    String? currentMapCn,
  }) async {
    if (_monitoredServers.containsKey(serverAddress)) return;

    _monitoredServers[serverAddress] = ServerMonitorData(
      serverAddress: serverAddress,
      serverName: serverName,
      categoryName: categoryName,
      lastMapName: currentMap,
      lastMapNameCn: currentMapCn,
      lastCheckTime: DateTime.now(),
    );

    await _saveMonitoredServers();
    _notifyStateChange();
    
    // 如果定时器未启动，启动它
    _startMonitorLoop();
    
    LogService.i('[MapChangeMonitor] 添加监控: $serverAddress ($serverName)');
  }

  /// 从监控列表移除服务器
  Future<void> removeMonitor(String serverAddress) async {
    if (!_monitoredServers.containsKey(serverAddress)) return;

    _monitoredServers.remove(serverAddress);
    await _saveMonitoredServers();
    _notifyStateChange();
    
    // 如果没有监控的服务器，停止定时器
    if (_monitoredServers.isEmpty) {
      _stopMonitorLoop();
    }
    
    LogService.i('[MapChangeMonitor] 移除监控: $serverAddress');
  }

  /// 切换监控状态
  Future<bool> toggleMonitor({
    required String serverAddress,
    required String serverName,
    String? categoryName,
    String? currentMap,
    String? currentMapCn,
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
        currentMapCn: currentMapCn,
      );
      return true;
    }
  }

  /// 更新服务器的当前地图（用于初始化或手动更新）
  void updateCurrentMap(String serverAddress, String? mapName, String? mapNameCn) {
    final data = _monitoredServers[serverAddress];
    if (data != null) {
      data.lastMapName = mapName;
      data.lastMapNameCn = mapNameCn;
      data.lastCheckTime = DateTime.now();
    }
  }

  /// 发送换图通知（供外部调用，如 ServerBloc）
  /// 注意：调用前应先调用 markNotificationSent 记录状态，防止重复通知
  void sendMapChangeNotification({
    required String serverAddress,
    required String serverName,
    required String oldMap,
    required String newMap,
    String? newMapCn,
    String? mapBackground,
    String? categoryName,
  }) {
    _notificationService.showMapChangeNotification(
      serverAddress: serverAddress,
      serverName: serverName,
      oldMap: oldMap,
      newMap: newMap,
      newMapCn: newMapCn,
      mapBackground: mapBackground,
      categoryName: categoryName,
    );
  }
  
  /// 获取服务器的保存名称（用于通知显示）
  String? getSavedServerName(String serverAddress) {
    return _monitoredServers[serverAddress]?.serverName;
  }
  
  /// 标记通知已发送（供外部调用，防止重复通知）
  void markNotificationSent(String serverAddress, String oldMap, String newMap) {
    final data = _monitoredServers[serverAddress];
    if (data != null) {
      data.markNotified(oldMap, newMap);
    }
  }
  
  /// 检查是否应该发送通知（供外部调用，防止重复通知）
  bool shouldNotify(String serverAddress, String oldMap, String newMap) {
    final data = _monitoredServers[serverAddress];
    if (data == null) return false;
    return data.shouldNotify(oldMap, newMap);
  }

  /// 启动监控循环
  void _startMonitorLoop() {
    if (_monitorTimer != null) return;
    if (_monitoredServers.isEmpty) return;
    if (_isPaused) return;  // 暂停状态不启动

    _monitorTimer = Timer.periodic(
      const Duration(seconds: monitorIntervalSeconds),
      (_) => _checkAllServers(),
    );
    
    // 立即执行一次检查
    _checkAllServers();
  }

  /// 停止监控循环
  void _stopMonitorLoop() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  /// 检查所有监控的服务器
  Future<void> _checkAllServers() async {
    if (_monitoredServers.isEmpty) return;
    
    // 复制一份避免并发修改错误
    final serversToCheck = Map<String, ServerMonitorData>.from(_monitoredServers);
    
    // 并行检查所有服务器，提高效率
    await Future.wait(
      serversToCheck.entries.map((entry) async {
        // 检查服务器是否仍在监控列表中
        if (_monitoredServers.containsKey(entry.key)) {
          await _checkServer(entry.key, entry.value);
        }
      }),
      eagerError: false,  // 不因单个失败而中断其他检查
    );
  }

  /// 检查单个服务器
  Future<void> _checkServer(String serverAddress, ServerMonitorData data) async {
    // 如果连续失败次数过多，每3次检查周期才重试一次
    if (data.shouldSkipDueToFailures) {
      // 每60秒（3个周期）重试一次
      if (data.lastCheckTime != null) {
        final timeSinceLastCheck = DateTime.now().difference(data.lastCheckTime!);
        if (timeSinceLastCheck.inSeconds < 60) {
          return;
        }
      }
      // 重置失败计数，允许重试
      data.resetFailures();
    }
    
    // 防止并发检查同一服务器
    if (data._isChecking) return;
    data._isChecking = true;
    
    try {
      final parts = serverAddress.split(':');
      if (parts.length != 2) return;

      final ip = parts[0];
      final port = int.tryParse(parts[1]);
      if (port == null) return;

      final serverInfo = await SourceServerService.getServerInfo(ip, port, timeout: 5000);
      if (serverInfo == null) {
        // 记录失败，但保留 lastMapName 以便下次比较
        data.recordFailure();
        return;
      }
      
      // 查询成功，重置失败计数
      data.resetFailures();

      final newMapName = serverInfo.map;
      final oldMapName = data.lastMapName;

      // 检测换图：只有当旧地图存在且与新地图不同时才通知
      // 如果 oldMapName 为 null，说明是首次检查，只记录不通知
      // 过滤 graphics_settings 地图（服务器重启时的加载地图）
      if (oldMapName != null && 
          oldMapName.isNotEmpty && 
          oldMapName != newMapName && 
          oldMapName != 'graphics_settings' &&
          newMapName != 'graphics_settings') {
        // 检查是否应该发送通知（防止重复通知）
        if (data.shouldNotify(oldMapName, newMapName)) {
          LogService.d('[MapChangeMonitor] 检测到换图: $serverAddress, $oldMapName → $newMapName');
          
          // 先记录通知状态，防止并发重复
          data.markNotified(oldMapName, newMapName);
          
          // 获取新地图信息（中文名和背景图）
          String? newMapCn;
          String? mapBackground;
          try {
            final mapInfo = await _serverApi.getMapInfo(newMapName);
            newMapCn = mapInfo?.mapLabel;
            mapBackground = mapInfo?.mapUrl;
          } catch (e) {
            // 静默处理
          }

          // 发送换图通知
          _notificationService.showMapChangeNotification(
            serverAddress: serverAddress,
            serverName: data.serverName,
            oldMap: oldMapName,
            newMap: newMapName,
            newMapCn: newMapCn,
            mapBackground: mapBackground,
            categoryName: data.categoryName,
          );
        }
      }

      // 更新数据（graphics_settings 不更新 lastMapName，保留原地图名）
      if (newMapName != 'graphics_settings') {
        data.lastMapName = newMapName;
      }
      data.lastCheckTime = DateTime.now();
    } catch (e) {
      data.recordFailure();
      LogService.e('[MapChangeMonitor] 检查服务器异常: $serverAddress', e);
    } finally {
      data._isChecking = false;
    }
  }

  /// 保存监控列表到本地存储（JSON格式）
  Future<void> _saveMonitoredServers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> data = _monitoredServers.entries.map((e) {
        return jsonEncode({
          'address': e.key,
          'serverName': e.value.serverName,
          'categoryName': e.value.categoryName,
        });
      }).toList();
      await prefs.setStringList(_storageKey, data);
    } catch (e) {
      LogService.e('[MapChangeMonitor] 保存监控列表失败', e);
    }
  }

  /// 从本地存储加载监控列表
  /// 
  /// 注意：启动时不加载之前保存的地图名，这样首次检查只会记录当前地图而不会触发通知
  /// 只有在应用运行期间检测到地图变化时才会发送通知
  Future<void> _loadMonitoredServers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList(_storageKey) ?? [];
      
      for (final item in data) {
        try {
          // 尝试 JSON 格式解析
          final map = jsonDecode(item) as Map<String, dynamic>;
          final address = map['address'] as String;
          final serverName = map['serverName'] as String;
          final categoryName = map['categoryName'] as String?;
          
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
              categoryName: null, // 旧格式无分类名
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
    _stopMonitorLoop();
    _monitoredServers.clear();
    _monitorStateController.close();
  }
}
