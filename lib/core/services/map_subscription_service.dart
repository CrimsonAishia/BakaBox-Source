import 'dart:async';
import 'dart:convert';

import '../api/server_api.dart';
import '../models/map_subscription_models.dart';
import '../models/server_models.dart';
import '../utils/log_service.dart';
import '../utils/storage_utils.dart';
import 'custom_server_service.dart';
import 'notification_window_service.dart';
import 'realtime/realtime_server_map_runtime_channel.dart';
import 'server_category_service.dart';
import 'tts_service.dart';

/// 地图订阅监控服务（单例）
///
/// 通过 `server.map.runtime` WS 频道接收换图事件：
/// - 订阅时服务端下发 snapshot，用来初始化各服务器的当前地图
/// - changed 事件直接驱动通知（命中订阅 + 范围 + 冷却）
class MapSubscriptionService {
  static final MapSubscriptionService _instance =
      MapSubscriptionService._internal();
  factory MapSubscriptionService() => _instance;
  MapSubscriptionService._internal();

  // ======== 存储 Key ========
  static const String _storageKeySubscriptions = 'map_subscriptions';
  static const String _storageKeyEnabled = 'map_subscription_enabled';
  static const String _storageKeyNotificationEnabled =
      'map_subscription_notification_enabled';
  static const String _storageKeyTtsEnabled = 'map_subscription_tts_enabled';
  static const String _storageKeyCooldownSeconds =
      'map_subscription_cooldown_seconds';
  static const String _storageKeyGlobalCategories =
      'map_subscription_global_categories';
  static const String _storageKeyNotificationCooldown =
      'map_subscription_notification_cooldown';

  // ======== 常量 ========

  /// 默认通知冷却时间（秒）
  static const int _defaultCooldownSeconds = 15;

  /// 最小冷却时间（秒）
  static const int minCooldownSeconds = 10;

  /// 最大冷却时间（秒）
  static const int maxCooldownSeconds = 60;

  // ======== 依赖服务 ========

  final ServerApi _serverApi = ServerApi();
  final NotificationWindowService _notificationService =
      NotificationWindowService();
  final TtsService _ttsService = TtsService();
  final RealtimeServerMapRuntimeChannel _realtimeChannel =
      RealtimeServerMapRuntimeChannel();

  // ======== 状态字段 ========

  /// 订阅列表
  List<MapSubscription> _subscriptions = [];

  /// 全局开关
  bool _isEnabled = false;

  /// 通知开关
  bool _isNotificationEnabled = true;

  /// 全局 TTS 开关
  bool _isTtsEnabled = false;

  /// 通知冷却时间（秒）
  int _cooldownSeconds = _defaultCooldownSeconds;

  /// 全局分类范围（空=全部分类）
  List<String> _globalCategories = [];

  /// 通知冷却记录（key: "mapName_serverAddress", value: 上次通知时间戳毫秒）
  final Map<String, int> _notificationCooldown = {};

  /// 服务器地址 → 分类名（来自分类列表）
  final Map<String, String> _serverCategoryMap = {};

  /// 服务器地址 → 显示名（来自分类列表）
  final Map<String, String> _serverNameMap = {};

  /// 是否已加载分类
  bool _categoriesLoaded = false;

  /// 状态变化流
  final _stateController = StreamController<void>.broadcast();
  Stream<void> get stateStream => _stateController.stream;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 是否已订阅 WS 频道
  bool _realtimeSubscribed = false;
  StreamSubscription<ServerMapRuntimeEvent>? _realtimeSubscription;

  // ======== 公开属性 ========

  List<MapSubscription> get subscriptions => List.unmodifiable(_subscriptions);
  bool get isEnabled => _isEnabled;
  bool get isNotificationEnabled => _isNotificationEnabled;
  bool get isTtsEnabled => _isTtsEnabled;
  int get cooldownSeconds => _cooldownSeconds;
  List<String> get globalCategories => List.unmodifiable(_globalCategories);
  bool get isAllCategories => _globalCategories.isEmpty;
  int get subscriptionCount => _subscriptions.length;

  bool isSubscribed(String mapName) =>
      _subscriptions.any((s) => s.mapName == mapName);

  // ======== 初始化 ========

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
    _cooldownSeconds = StorageUtils.getInt(_storageKeyCooldownSeconds) ??
        _defaultCooldownSeconds;
    _globalCategories = StorageUtils.getStringList(_storageKeyGlobalCategories);

    await _loadNotificationCooldown();
    await _loadServerCategoryMap();

    _isInitialized = true;

    LogService.d(
      '[MapSubscription] 服务已初始化，订阅 ${_subscriptions.length} 个地图，'
      '全局开关: $_isEnabled，通知: $_isNotificationEnabled，TTS: $_isTtsEnabled，'
      '冷却记录: ${_notificationCooldown.length} 条',
    );

    if (_isEnabled && _subscriptions.isNotEmpty) {
      _startRealtime();
    }
  }

  // ======== 订阅管理 ========

  Future<void> addSubscription(MapSubscription subscription) async {
    if (isSubscribed(subscription.mapName)) {
      LogService.d('[MapSubscription] 地图已订阅: ${subscription.mapName}');
      return;
    }

    _subscriptions.add(subscription);
    await _saveSubscriptions();
    _notifyStateChange();

    if (_isEnabled) _startRealtime();

    LogService.d('[MapSubscription] 添加订阅: ${subscription.displayName}');
  }

  Future<void> removeSubscription(String mapName) async {
    _subscriptions.removeWhere((s) => s.mapName == mapName);
    _notificationCooldown.removeWhere(
      (key, _) => key.startsWith('${mapName}_'),
    );
    await _saveSubscriptions();
    await _saveNotificationCooldown();

    _notifyStateChange();

    if (_subscriptions.isEmpty) _stopRealtime();

    LogService.d('[MapSubscription] 移除订阅: $mapName');
  }

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

  Future<void> updateSubscriptionScope(
    String mapName,
    List<String> categoryNames,
  ) async {
    final index = _subscriptions.indexWhere((s) => s.mapName == mapName);
    if (index == -1) return;
    _subscriptions[index] = _subscriptions[index].copyWith(
      categoryNames: List.from(categoryNames),
    );
    await _saveSubscriptions();
    _notifyStateChange();
  }

  Future<void> updateSubscriptionServers(
    String mapName,
    List<String> serverAddresses,
  ) async {
    final index = _subscriptions.indexWhere((s) => s.mapName == mapName);
    if (index == -1) return;
    _subscriptions[index] = _subscriptions[index].copyWith(
      serverAddresses: List.from(serverAddresses),
    );
    await _saveSubscriptions();
    _notifyStateChange();
  }

  /// 刷新所有过期的订阅地图信息
  Future<void> refreshExpiredSubscriptions() async {
    final expiredSubscriptions = _subscriptions
        .where((s) => s.isCacheExpired)
        .toList();

    if (expiredSubscriptions.isEmpty) return;

    int updatedCount = 0;
    for (final sub in expiredSubscriptions) {
      try {
        final mapInfo = await _serverApi.getMapInfo(sub.mapName);
        if (mapInfo != null) {
          final index = _subscriptions.indexWhere(
            (s) => s.mapName == sub.mapName,
          );
          if (index != -1) {
            _subscriptions[index] = sub.copyWith(
              mapLabel: mapInfo.mapLabel,
              mapBackground: mapInfo.mapUrl,
              cachedAt: DateTime.now(),
            );
            updatedCount++;
          }
        }
      } catch (e) {
        LogService.e('[MapSubscription] 刷新订阅地图信息失败: ${sub.mapName}', e);
      }
    }

    if (updatedCount > 0) {
      await _saveSubscriptions();
      _notifyStateChange();
    }
  }

  /// 获取所有可用服务器列表
  Future<Map<String, String>> getAvailableServers() async {
    final categories = await _loadAndMergeCategories();
    final result = <String, String>{};
    final seenAddresses = <String>{};

    for (final category in categories) {
      final categoryName = category.modelName ?? category.category ?? '';
      for (final server in category.serverList) {
        final serverAddress = server.address ?? server.serverAddress ?? '';
        if (serverAddress.isEmpty) continue;
        if (seenAddresses.contains(serverAddress)) continue;
        seenAddresses.add(serverAddress);
        final displayName = '${server.getDisplayName('')} ($categoryName)';
        result[serverAddress] = displayName;
      }
    }
    return result;
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await StorageUtils.setBool(_storageKeyEnabled, enabled);

    if (enabled && _subscriptions.isNotEmpty) {
      _startRealtime();
    } else {
      _stopRealtime();
    }

    _notifyStateChange();
  }

  Future<void> setNotificationEnabled(bool enabled) async {
    _isNotificationEnabled = enabled;
    await StorageUtils.setBool(_storageKeyNotificationEnabled, enabled);
    _notifyStateChange();
  }

  Future<void> setTtsEnabled(bool enabled) async {
    _isTtsEnabled = enabled;
    await StorageUtils.setBool(_storageKeyTtsEnabled, enabled);
    _notifyStateChange();
  }

  Future<void> setCooldownSeconds(int seconds) async {
    _cooldownSeconds = seconds.clamp(minCooldownSeconds, maxCooldownSeconds);
    await StorageUtils.setInt(_storageKeyCooldownSeconds, _cooldownSeconds);
    _notifyStateChange();
  }

  // ======== 实时频道 ========

  void _startRealtime() {
    if (_realtimeSubscribed) return;
    _realtimeSubscribed = true;
    _realtimeChannel.subscribe();
    _realtimeSubscription = _realtimeChannel.events.listen(_onRealtimeEvent);
    LogService.d('[MapSubscription] 实时通道已启动');
  }

  void _stopRealtime() {
    if (!_realtimeSubscribed) return;
    _realtimeSubscribed = false;
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _realtimeChannel.unsubscribe();
    LogService.d('[MapSubscription] 实时通道已停止');
  }

  void _onRealtimeEvent(ServerMapRuntimeEvent event) {
    if (!_isEnabled || _subscriptions.isEmpty) return;

    if (event.kind == ServerMapRuntimeEventKind.snapshot) {
      // snapshot 不触发通知，只用来对齐冷却时间，避免重连后立即推一遍
      for (final entry in event.entries) {
        final cooldownKey = '${entry.mapName}_${entry.serverAddress}';
        _notificationCooldown.putIfAbsent(
          cooldownKey,
          () => DateTime.now().millisecondsSinceEpoch,
        );
      }
      return;
    }

    for (final entry in event.entries) {
      _evaluateChange(entry);
    }
  }

  Future<void> _evaluateChange(ServerMapRuntimeEntry entry) async {
    final newMap = entry.mapName;
    final oldMap = entry.oldMapName;
    if (newMap.isEmpty ||
        newMap == 'graphics_settings' ||
        oldMap == 'graphics_settings') {
      return;
    }

    if (oldMap == null || oldMap == newMap) return;

    final lowerNewMap = newMap.toLowerCase();
    final subscription = _subscriptions
        .cast<MapSubscription?>()
        .firstWhere(
          (s) => s!.mapName.toLowerCase() == lowerNewMap,
          orElse: () => null,
        );

    if (subscription == null) return;

    // 服务器分类映射可能因为分类列表更新而变化，按需懒加载
    if (!_categoriesLoaded) {
      await _loadServerCategoryMap();
    }

    final categoryName = _serverCategoryMap[entry.serverAddress];
    final serverName = entry.hostName ??
        _serverNameMap[entry.serverAddress] ??
        entry.serverAddress;

    if (categoryName == null) {
      // 不在我们维护的分类列表里（比如自定义分组中的私人服务器），跳过
      LogService.d(
        '[MapSubscription] 服务器不在已知分类，跳过: ${entry.serverAddress}',
      );
      return;
    }

    // 范围检查
    if (!subscription.isAllServers &&
        !subscription.serverAddresses.contains(entry.serverAddress)) {
      return;
    }

    if (!subscription.isAllCategories) {
      if (!subscription.categoryNames.contains(categoryName)) return;
    } else if (!isAllCategories) {
      if (!_globalCategories.contains(categoryName)) return;
    }

    // 冷却
    final cooldownKey = '${newMap}_${entry.serverAddress}';
    final lastNotifyMs = _notificationCooldown[cooldownKey];
    if (lastNotifyMs != null) {
      final elapsed = DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(lastNotifyMs))
              .inSeconds;
      if (elapsed < _cooldownSeconds) {
        LogService.d(
          '[MapSubscription] 冷却中，跳过通知: $cooldownKey (${_cooldownSeconds - elapsed}s 剩余)',
        );
        return;
      }
    }

    _notificationCooldown[cooldownKey] = DateTime.now().millisecondsSinceEpoch;
    await _saveNotificationCooldown();

    LogService.i(
      '[MapSubscription] 命中订阅: ${subscription.displayName} @ $serverName ($categoryName)',
    );

    await _sendNotification(
      subscription: subscription,
      serverAddress: entry.serverAddress,
      serverName: serverName,
      categoryName: categoryName,
      maxPlayers: entry.maxPlayers ?? 0,
    );
  }

  Future<void> _sendNotification({
    required MapSubscription subscription,
    required String serverAddress,
    required String serverName,
    required String categoryName,
    required int maxPlayers,
  }) async {
    if (_isNotificationEnabled) {
      final id =
          'mapsub_${subscription.mapName}_${DateTime.now().millisecondsSinceEpoch}';
      await _notificationService.show(
        NotificationData(
          id: id,
          type: NotificationType.mapSubscription,
          title: '订阅提醒',
          message: subscription.displayName,
          serverAddress: serverAddress,
          serverName: serverName,
          mapName: subscription.mapName,
          mapNameCn: subscription.mapLabel,
          mapBackground: subscription.mapBackground,
          autoDismissSeconds: 60,
          extraData: {
            'categoryName': categoryName,
            'currentPlayers': 0,
            'maxPlayers': maxPlayers,
          },
        ),
      );
    }

    if (_isTtsEnabled && _ttsService.isAvailable) {
      try {
        await _ttsService.speakMapAlert(
          mapLabel: subscription.mapLabel,
          mapName: subscription.mapName,
          serverName: serverName,
          categoryName: categoryName,
        );
      } catch (e) {
        LogService.e('[MapSubscription] TTS 播报失败', e);
      }
    }
  }

  // ======== 分类映射 ========

  Future<List<ServerCategory>> _loadAndMergeCategories() async {
    final customCategories = await CustomServerService.loadCustomCategories();
    final apiCategories =
        await ServerCategoryService.instance.getApiCategories();
    return _mergeCategories(customCategories, apiCategories);
  }

  /// 合并自定义分类和 API 分类
  List<ServerCategory> _mergeCategories(
    List<ServerCategory> customCategories,
    List<ServerCategory> apiCategories,
  ) {
    final seenAddresses = <String>{};
    final categories = <ServerCategory>[];

    for (final cat in customCategories) {
      final name = cat.modelName ?? cat.category ?? '';
      if (name.isEmpty) continue;
      categories.add(cat.copyWith(isCustom: true));
      for (final server in cat.serverList) {
        final addr = server.address ?? server.serverAddress ?? '';
        if (addr.isNotEmpty) seenAddresses.add(addr);
      }
    }

    for (final cat in apiCategories) {
      final name = cat.modelName ?? cat.category ?? '';
      if (name.isEmpty) continue;

      final dedupedServers = <ServerItem>[];
      for (final server in cat.serverList) {
        final addr = server.address ?? server.serverAddress ?? '';
        if (addr.isNotEmpty && !seenAddresses.contains(addr)) {
          dedupedServers.add(server);
          seenAddresses.add(addr);
        }
      }

      categories.add(
        ServerCategory(
          modelName: cat.modelName,
          category: cat.category,
          serverList: dedupedServers,
          isCustom: false,
        ),
      );
    }

    return categories;
  }

  Future<void> _loadServerCategoryMap() async {
    try {
      final categories = await _loadAndMergeCategories();
      _serverCategoryMap.clear();
      _serverNameMap.clear();
      for (final category in categories) {
        final categoryName = category.modelName ?? category.category ?? '';
        if (categoryName.isEmpty) continue;
        for (final server in category.serverList) {
          final addr = server.address ?? server.serverAddress ?? '';
          if (addr.isEmpty) continue;
          _serverCategoryMap.putIfAbsent(addr, () => categoryName);
          if (server.nickname != null && server.nickname!.isNotEmpty) {
            _serverNameMap[addr] = server.nickname!;
          }
        }
      }
      _categoriesLoaded = true;
      LogService.d(
        '[MapSubscription] 加载分类映射: ${_serverCategoryMap.length} 个服务器',
      );
    } catch (e) {
      LogService.e('[MapSubscription] 加载分类映射失败', e);
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

  Future<void> _loadNotificationCooldown() async {
    try {
      final cooldownData = StorageUtils.getString(
        _storageKeyNotificationCooldown,
      );
      if (cooldownData != null && cooldownData.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(cooldownData);
        _notificationCooldown.clear();
        for (final entry in decoded.entries) {
          if (entry.value is int) {
            final lastNotify = DateTime.fromMillisecondsSinceEpoch(entry.value);
            final elapsed = DateTime.now().difference(lastNotify).inSeconds;
            if (elapsed < _cooldownSeconds * 2) {
              _notificationCooldown[entry.key] = entry.value;
            }
          }
        }
      }
    } catch (e) {
      LogService.e('[MapSubscription] 加载冷却记录失败', e);
      _notificationCooldown.clear();
    }
  }

  Future<void> _saveNotificationCooldown() async {
    try {
      final encoded = jsonEncode(_notificationCooldown);
      await StorageUtils.setString(_storageKeyNotificationCooldown, encoded);
    } catch (e) {
      LogService.e('[MapSubscription] 保存冷却记录失败', e);
    }
  }

  void _notifyStateChange() {
    if (!_stateController.isClosed) {
      _stateController.add(null);
    }
  }

  void dispose() {
    _stopRealtime();
    _subscriptions.clear();
    _notificationCooldown.clear();
    _stateController.close();
  }
}
