import 'dart:async';
import 'dart:convert';

import '../api/server_api.dart';
import '../models/map_subscription_models.dart';
import '../utils/log_service.dart';
import '../utils/storage_utils.dart';
import 'custom_server_service.dart';
import 'notification_window_service.dart';
import 'scheduler_service.dart';
import 'source_server_service.dart';
import 'tts_service.dart';

/// 地图订阅监控服务（单例）
///
/// 独立查询模式（方案 A）：
/// 通过 ServerApi 获取服务器列表，检测服务器换图并匹配订阅地图，
/// 触发通知窗口和 TTS 语音播报。
class MapSubscriptionService {
  static final MapSubscriptionService _instance =
      MapSubscriptionService._internal();
  factory MapSubscriptionService() => _instance;
  MapSubscriptionService._internal();

  /// 存储 key
  static const String _storageKeySubscriptions = 'map_subscriptions';
  static const String _storageKeyEnabled = 'map_subscription_enabled';
  static const String _storageKeyNotificationEnabled =
      'map_subscription_notification_enabled';
  static const String _storageKeyTtsEnabled = 'map_subscription_tts_enabled';
  static const String _storageKeyCooldownSeconds =
      'map_subscription_cooldown_seconds';
  static const String _storageKeyGlobalCategories =
      'map_subscription_global_categories';

  /// 任务 ID
  static const String _taskId = 'map_subscription_monitor';

  /// 默认通知冷却时间（秒）- 同时也是监控间隔
  static const int _defaultCooldownSeconds = 15;

  /// 最小冷却时间（秒）
  static const int minCooldownSeconds = 10;

  /// 最大冷却时间（秒）
  static const int maxCooldownSeconds = 60;

  /// 依赖服务
  final SchedulerService _scheduler = SchedulerService();
  final ServerApi _serverApi = ServerApi();
  final NotificationWindowService _notificationService =
      NotificationWindowService();
  final TtsService _ttsService = TtsService();

  /// 订阅列表
  List<MapSubscription> _subscriptions = [];

  /// 全局开关
  bool _isEnabled = false;

  /// 通知开关（开了才会弹出通知窗口）
  bool _isNotificationEnabled = true;

  /// 全局 TTS 开关
  bool _isTtsEnabled = false;

  /// 通知冷却时间（秒）
  int _cooldownSeconds = _defaultCooldownSeconds;

  /// 全局分类范围（空=全部分类，包括新增的）
  List<String> _globalCategories = [];

  /// 各服务器上次的地图名（key: serverAddress）
  final Map<String, String> _lastServerMaps = {};

  /// 通知冷却记录（key: "mapName_serverAddress", value: 上次通知时间）
  final Map<String, DateTime> _notificationCooldown = {};

  /// 状态变化流
  final _stateController = StreamController<void>.broadcast();
  Stream<void> get stateStream => _stateController.stream;

  /// 是否已初始化
  bool _isInitialized = false;

  // ======== 公开属性 ========

  /// 获取订阅列表
  List<MapSubscription> get subscriptions => List.unmodifiable(_subscriptions);

  /// 全局开关状态
  bool get isEnabled => _isEnabled;

  /// 通知开关状态
  bool get isNotificationEnabled => _isNotificationEnabled;

  /// 全局 TTS 开关状态
  bool get isTtsEnabled => _isTtsEnabled;

  /// 通知冷却时间（秒）
  int get cooldownSeconds => _cooldownSeconds;

  /// 全局分类范围（空=全部分类）
  List<String> get globalCategories => List.unmodifiable(_globalCategories);

  /// 是否监控全部分类（空列表表示全部）
  bool get isAllCategories => _globalCategories.isEmpty;

  /// 订阅数量
  int get subscriptionCount => _subscriptions.length;

  /// 检查地图是否已订阅
  bool isSubscribed(String mapName) =>
      _subscriptions.any((s) => s.mapName == mapName);

  // ======== 初始化 ========

  /// 初始化服务
  ///
  /// 注意：StorageUtils.getBool 可能返回 null
  Future<void> initialize() async {
    if (_isInitialized) {
      LogService.d('[MapSubscription] 服务已初始化，跳过');
      return;
    }

    await _loadSubscriptions();
    _isEnabled = StorageUtils.getBool(_storageKeyEnabled);
    _isNotificationEnabled = StorageUtils.getBool(
      _storageKeyNotificationEnabled,
      defaultValue: true,
    );
    _isTtsEnabled = StorageUtils.getBool(_storageKeyTtsEnabled);
    _cooldownSeconds =
        StorageUtils.getInt(_storageKeyCooldownSeconds) ??
        _defaultCooldownSeconds;
    _globalCategories = StorageUtils.getStringList(_storageKeyGlobalCategories);
    _isInitialized = true;

    LogService.d(
      '[MapSubscription] 服务已初始化，'
      '订阅 ${_subscriptions.length} 个地图，'
      '全局开关: $_isEnabled，通知: $_isNotificationEnabled，TTS: $_isTtsEnabled',
    );

    if (_isEnabled && _subscriptions.isNotEmpty) {
      _startMonitorLoop();
    } else {
      LogService.d(
        '[MapSubscription] 初始化时未启动监控: enabled=$_isEnabled, subscriptions=${_subscriptions.length}',
      );
    }
  }

  // ======== 订阅管理 ========

  /// 添加地图订阅
  Future<void> addSubscription(MapSubscription subscription) async {
    // 检查是否已存在
    if (isSubscribed(subscription.mapName)) {
      LogService.d('[MapSubscription] 地图已订阅: ${subscription.mapName}');
      return;
    }

    _subscriptions.add(subscription);
    await _saveSubscriptions();
    _notifyStateChange();

    // 如果已启用且有订阅，启动监控
    if (_isEnabled) {
      _startMonitorLoop();
    }

    LogService.d('[MapSubscription] 添加订阅: ${subscription.displayName}');
  }

  /// 移除地图订阅
  Future<void> removeSubscription(String mapName) async {
    _subscriptions.removeWhere((s) => s.mapName == mapName);
    _notificationCooldown.removeWhere(
      (key, _) => key.startsWith('${mapName}_'),
    );
    await _saveSubscriptions();
    _notifyStateChange();

    // 如果没有订阅了，停止监控
    if (_subscriptions.isEmpty) {
      _stopMonitorLoop();
    }

    LogService.d('[MapSubscription] 移除订阅: $mapName');
  }

  /// 设置全局分类范围
  ///
  /// [categoryNames] 为空表示监控全部分类（包括新增的）
  Future<void> setGlobalCategories(List<String> categoryNames) async {
    _globalCategories = List.from(categoryNames);
    await StorageUtils.setStringList(
      _storageKeyGlobalCategories,
      _globalCategories,
    );
    _notifyStateChange();

    LogService.d(
      '[MapSubscription] 更新全局分类范围: ${categoryNames.isEmpty ? "全部（包括新增）" : categoryNames}',
    );
  }

  /// 切换全局开关
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await StorageUtils.setBool(_storageKeyEnabled, enabled);

    if (enabled && _subscriptions.isNotEmpty) {
      _startMonitorLoop();
    } else {
      _stopMonitorLoop();
      _lastServerMaps.clear();
    }

    _notifyStateChange();
    LogService.d('[MapSubscription] 全局开关: $enabled');
  }

  /// 切换通知开关
  Future<void> setNotificationEnabled(bool enabled) async {
    _isNotificationEnabled = enabled;
    await StorageUtils.setBool(_storageKeyNotificationEnabled, enabled);
    _notifyStateChange();
    LogService.d('[MapSubscription] 通知开关: $enabled');
  }

  /// 切换全局 TTS 开关
  Future<void> setTtsEnabled(bool enabled) async {
    _isTtsEnabled = enabled;
    await StorageUtils.setBool(_storageKeyTtsEnabled, enabled);
    _notifyStateChange();
    LogService.d('[MapSubscription] 全局 TTS 开关: $enabled');
  }

  /// 设置通知冷却时间（同时也是监控刷新频率）
  Future<void> setCooldownSeconds(int seconds) async {
    _cooldownSeconds = seconds.clamp(minCooldownSeconds, maxCooldownSeconds);
    await StorageUtils.setInt(_storageKeyCooldownSeconds, _cooldownSeconds);
    _notifyStateChange();
    LogService.d('[MapSubscription] 刷新频率: $_cooldownSeconds 秒');

    // 重启监控循环以应用新的刷新频率
    if (_isEnabled && _subscriptions.isNotEmpty) {
      _stopMonitorLoop();
      _startMonitorLoop();
    }
  }

  // ======== 监控逻辑 ========

  /// 启动监控循环
  void _startMonitorLoop() {
    if (_scheduler.hasTask(_taskId)) {
      LogService.d('[MapSubscription] 监控任务已存在，跳过注册');
      return;
    }
    if (_subscriptions.isEmpty || !_isEnabled) {
      LogService.d(
        '[MapSubscription] 无法启动监控: subscriptions=${_subscriptions.length}, enabled=$_isEnabled',
      );
      return;
    }

    // 使用刷新频率作为监控间隔
    final intervalSeconds = _cooldownSeconds;

    _scheduler.register(
      ScheduledTask(
        id: _taskId,
        name: '地图订阅监控',
        interval: Duration(seconds: intervalSeconds),
        callback: () async => _checkAllServers(),
        runImmediately: false, // 首次不立即执行，避免启动时误报
      ),
    );

    LogService.d('[MapSubscription] 监控循环已启动，间隔=$intervalSeconds秒');
  }

  /// 停止监控循环
  void _stopMonitorLoop() {
    _scheduler.cancel(_taskId);
    LogService.d('[MapSubscription] 监控循环已停止');
  }

  /// 检查所有服务器
  Future<void> _checkAllServers() async {
    if (_subscriptions.isEmpty || !_isEnabled) {
      LogService.d(
        '[MapSubscription] 跳过检查: subscriptions=${_subscriptions.length}, enabled=$_isEnabled',
      );
      return;
    }

    LogService.d(
      '[MapSubscription] 开始检查服务器，订阅数=${_subscriptions.length}，已记录服务器数=${_lastServerMaps.length}',
    );

    try {
      // 获取 API 分类
      final apiCategories = await _serverApi.getServerList();
      // 获取自定义分类
      final customCategories = await CustomServerService.loadCustomCategories();
      // 合并所有分类
      final categories = [...customCategories, ...apiCategories];
      LogService.d(
        '[MapSubscription] 获取到 ${categories.length} 个分类 (API: ${apiCategories.length}, 自定义: ${customCategories.length})',
      );

      int serverCount = 0;
      int validServerCount = 0;

      for (final category in categories) {
        // 检查全局分类范围（空列表表示全部分类，包括新增的）
        final categoryName = category.modelName ?? category.category ?? '';
        if (!isAllCategories && !_globalCategories.contains(categoryName)) {
          continue;
        }

        for (final server in category.serverList) {
          serverCount++;
          final serverAddress = server.address ?? server.serverAddress ?? '';
          if (serverAddress.isEmpty) continue;

          // 解析 IP 和端口
          final parts = serverAddress.split(':');
          if (parts.length != 2) continue;
          final ip = parts[0];
          final port = int.tryParse(parts[1]);
          if (port == null) continue;

          // 直接查询服务器信息
          final serverInfo = await SourceServerService.getServerInfo(
            ip,
            port,
            timeout: 3000,
          );
          if (serverInfo == null) continue;

          final currentMap = serverInfo.map;
          if (currentMap.isEmpty || currentMap == 'graphics_settings') continue;

          validServerCount++;
          final hostName = server.getDisplayName(serverInfo.name);

          final lastMap = _lastServerMaps[serverAddress];

          // 更新记录
          _lastServerMaps[serverAddress] = currentMap;

          // 调试日志：记录地图变化
          if (lastMap != null && lastMap != currentMap) {
            LogService.d(
              '[MapSubscription] 检测到换图: $serverAddress, $lastMap -> $currentMap',
            );
          }

          // 检测换图
          if (lastMap != null &&
              lastMap.isNotEmpty &&
              lastMap != currentMap &&
              lastMap != 'graphics_settings') {
            // 检查新地图是否在订阅列表中
            _checkSubscriptionMatch(
              newMap: currentMap,
              serverAddress: serverAddress,
              serverName: hostName,
              categoryName: categoryName,
              numPlayers: serverInfo.players,
              maxPlayers: serverInfo.maxPlayers,
            );
          }
        }
      }

      LogService.d(
        '[MapSubscription] 检查完成: 总服务器=$serverCount, 有效服务器=$validServerCount, 已记录=${_lastServerMaps.length}',
      );
    } catch (e) {
      LogService.e('[MapSubscription] 检查服务器失败', e);
    }
  }

  /// 检查新地图是否匹配订阅
  void _checkSubscriptionMatch({
    required String newMap,
    required String serverAddress,
    required String serverName,
    required String categoryName,
    required int numPlayers,
    required int maxPlayers,
  }) {
    for (final subscription in _subscriptions) {
      // 地图名匹配（不区分大小写）
      if (subscription.mapName.toLowerCase() != newMap.toLowerCase()) continue;

      LogService.d(
        '[MapSubscription] 地图匹配成功: ${subscription.mapName} @ $serverName ($categoryName)',
      );

      // 检查冷却
      final cooldownKey = '${newMap}_$serverAddress';
      final lastNotify = _notificationCooldown[cooldownKey];
      if (lastNotify != null) {
        final elapsed = DateTime.now().difference(lastNotify).inSeconds;
        if (elapsed < _cooldownSeconds) {
          LogService.d('[MapSubscription] 冷却中，跳过通知: $cooldownKey');
          continue;
        }
      }

      // 记录冷却
      _notificationCooldown[cooldownKey] = DateTime.now();

      LogService.i(
        '[MapSubscription] 🎯 命中订阅: '
        '${subscription.displayName} @ $serverName ($categoryName)',
      );

      // 发送通知
      _sendNotification(
        subscription: subscription,
        serverAddress: serverAddress,
        serverName: serverName,
        categoryName: categoryName,
        numPlayers: numPlayers,
        maxPlayers: maxPlayers,
      );
    }
  }

  /// 发送通知 + TTS
  Future<void> _sendNotification({
    required MapSubscription subscription,
    required String serverAddress,
    required String serverName,
    required String categoryName,
    required int numPlayers,
    required int maxPlayers,
  }) async {
    // 通知窗口（根据通知开关决定是否显示）
    if (_isNotificationEnabled) {
      final id =
          'mapsub_${subscription.mapName}_${DateTime.now().millisecondsSinceEpoch}';
      final displayName = subscription.displayName;

      await _notificationService.show(
        NotificationData(
          id: id,
          type: NotificationType.mapSubscription,
          title: '订阅提醒',
          message: displayName,
          serverAddress: serverAddress,
          serverName: serverName,
          mapName: subscription.mapName,
          mapNameCn: subscription.mapLabel,
          mapBackground: subscription.mapBackground,
          autoDismissSeconds: 60,
          extraData: {
            'categoryName': categoryName,
            'currentPlayers': numPlayers,
            'maxPlayers': maxPlayers,
          },
        ),
      );
    }

    // TTS 播报（使用全局 TTS 开关）
    if (_isTtsEnabled) {
      LogService.d(
        '[MapSubscription] TTS 开关已开启，检查可用性: isAvailable=${_ttsService.isAvailable}',
      );
      if (_ttsService.isAvailable) {
        try {
          final result = await _ttsService.speakMapAlert(
            mapLabel: subscription.mapLabel,
            mapName: subscription.mapName,
            serverName: serverName,
            categoryName: categoryName,
          );
          LogService.d('[MapSubscription] TTS 播报结果: $result');
        } catch (e) {
          LogService.e('[MapSubscription] TTS 播报失败', e);
        }
      } else {
        LogService.d('[MapSubscription] TTS 不可用，跳过播报');
      }
    } else {
      LogService.d('[MapSubscription] TTS 开关未开启');
    }
  }

  // ======== 持久化 ========

  Future<void> _saveSubscriptions() async {
    try {
      final data = _subscriptions.map((s) => jsonEncode(s.toJson())).toList();
      await StorageUtils.setStringList(_storageKeySubscriptions, data);
    } catch (e) {
      LogService.e('[MapSubscription] 保存订阅列表失败', e);
    }
  }

  Future<void> _loadSubscriptions() async {
    try {
      final data = StorageUtils.getStringList(_storageKeySubscriptions);

      _subscriptions = data
          .map((item) {
            try {
              final map = jsonDecode(item) as Map<String, dynamic>;
              return MapSubscription.fromJson(map);
            } catch (_) {
              return null;
            }
          })
          .whereType<MapSubscription>()
          .toList();
    } catch (e) {
      LogService.e('[MapSubscription] 加载订阅列表失败', e);
    }
  }

  void _notifyStateChange() {
    if (!_stateController.isClosed) {
      _stateController.add(null);
    }
  }

  /// 销毁服务
  void dispose() {
    _stopMonitorLoop();
    _subscriptions.clear();
    _lastServerMaps.clear();
    _notificationCooldown.clear();
    _stateController.close();
  }
}
