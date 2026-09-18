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
import 'realtime/realtime_server_users_count_channel.dart';
import 'server_category_service.dart';
import 'source_server_service.dart';
import 'tts_service.dart';

/// 自动加入事件数据
class MapSubscriptionAutoJoinEvent {
  final String serverAddress;
  final String serverName;
  final String mapName;
  final String mapLabel;
  final String? mapBackground;
  final int countdownSeconds;

  MapSubscriptionAutoJoinEvent({
    required this.serverAddress,
    required this.serverName,
    required this.mapName,
    required this.mapLabel,
    this.mapBackground,
    required this.countdownSeconds,
  });
}

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


  /// 默认通知冷却时间（秒）
  static const int _defaultCooldownSeconds = 15;

  /// 最小冷却时间（秒）
  static const int minCooldownSeconds = 10;

  /// 最大冷却时间（秒）
  static const int maxCooldownSeconds = 60;


  final ServerApi _serverApi = ServerApi();
  final NotificationWindowService _notificationService =
      NotificationWindowService();
  final TtsService _ttsService = TtsService();
  final RealtimeServerMapRuntimeChannel _realtimeChannel =
      RealtimeServerMapRuntimeChannel();


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

  /// 官方 API 提供的服务器 IP 列表，用于区分私服
  final Set<String> _apiServers = {};

  /// 本地私服轮询定时器
  Timer? _localPollTimer;

  /// 私服上一张地图缓存 (IP -> MapName)
  final Map<String, String> _localServerLastMaps = {};

  /// 是否已加载分类
  bool _categoriesLoaded = false;
  Future<void>? _loadingCategoriesFuture;

  /// 状态变化流
  final _stateController = StreamController<void>.broadcast();
  Stream<void> get stateStream => _stateController.stream;

  /// 自动加入事件流
  final _autoJoinController =
      StreamController<MapSubscriptionAutoJoinEvent>.broadcast();
  Stream<MapSubscriptionAutoJoinEvent> get autoJoinStream =>
      _autoJoinController.stream;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 是否已订阅 WS 频道
  bool _realtimeSubscribed = false;
  StreamSubscription<ServerMapRuntimeEvent>? _realtimeSubscription;


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

    await _loadNotificationCooldown();
    await _loadServerCategoryMap();

    // 监听分类列表变化，及时更新分类映射缓存
    CustomServerService.onCategoriesChanged.listen((_) {
      LogService.d('[MapSubscription] 收到自定义分类变更，使缓存失效并预加载');
      _categoriesLoaded = false;
      _loadServerCategoryMap();
    });

    ServerCategoryService.instance.onCategoriesChanged.listen((_) {
      LogService.d('[MapSubscription] 收到API分类变更，使缓存失效并预加载');
      _categoriesLoaded = false;
      _loadServerCategoryMap();
    });

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

  Future<void> updateSubscriptionAutoJoin(
    String mapName,
    bool isEnabled,
    int countdownSeconds,
  ) async {
    final index = _subscriptions.indexWhere((s) => s.mapName == mapName);
    if (index == -1) return;
    _subscriptions[index] = _subscriptions[index].copyWith(
      isAutoJoinEnabled: isEnabled,
      autoJoinCountdownSeconds: countdownSeconds,
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

    // 如果启用了本地私服轮询，重新启动定时器以应用新的时间间隔
    if (_localPollTimer != null) {
      _startLocalPolling();
    }
  }


  void _startRealtime() {
    if (_realtimeSubscribed) return;
    _realtimeSubscribed = true;
    _realtimeChannel.subscribe();
    _realtimeSubscription = _realtimeChannel.events.listen(_onRealtimeEvent);
    LogService.d('[MapSubscription] 实时通道已启动');
    _startLocalPolling();
  }

  void _stopRealtime() {
    if (!_realtimeSubscribed) return;
    _realtimeSubscribed = false;
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _realtimeChannel.unsubscribe();
    LogService.d('[MapSubscription] 实时通道已停止');
    _stopLocalPolling();
  }


  void _startLocalPolling() {
    _stopLocalPolling();
    if (!_isEnabled || _subscriptions.isEmpty) return;

    LogService.d('[MapSubscription] 启动私服本地轮询机制，间隔 $_cooldownSeconds 秒');
    // 使用用户设置的冷却时间作为轮询频率
    _localPollTimer = Timer.periodic(Duration(seconds: _cooldownSeconds), (_) {
      _pollLocalServers();
    });
    // 立即执行一次
    _pollLocalServers();
  }

  void _stopLocalPolling() {
    if (_localPollTimer != null) {
      LogService.d('[MapSubscription] 停止私服本地轮询机制');
      _localPollTimer?.cancel();
      _localPollTimer = null;
    }
  }

  Future<void> _pollLocalServers() async {
    if (!_isEnabled || _subscriptions.isEmpty) return;

    final privateServers = <String>{};

    // 收集所有在订阅范围内，且不属于官方 API 的私服地址
    for (final sub in _subscriptions) {
      if (!sub.isAllServers) {
        // 用户单独勾选的服务器
        for (final addr in sub.serverAddresses) {
          if (!_apiServers.contains(addr)) {
            privateServers.add(addr);
          }
        }
      } else {
        // 如果是全服或者范围分类监控，需要从分类中找出所有私服
        final targetCategories = sub.isAllCategories
            ? _globalCategories
            : sub.categoryNames;
        for (final entry in _serverCategoryMap.entries) {
          final addr = entry.key;
          final cat = entry.value;
          if ((sub.isAllCategories && _globalCategories.isEmpty) ||
              targetCategories.contains(cat)) {
            if (!_apiServers.contains(addr)) {
              privateServers.add(addr);
            }
          }
        }
      }
    }

    if (privateServers.isEmpty) return;

    final serverList = privateServers.toList();
    final results = <String, SourceServerInfo?>{};

    // 每次最多并发查询 10 个服务器，极度保守的网络防洪，确保打游戏时绝对 0 影响
    const chunkSize = 10;
    for (var i = 0; i < serverList.length; i += chunkSize) {
      final end = (i + chunkSize > serverList.length)
          ? serverList.length
          : i + chunkSize;
      final chunk = serverList.sublist(i, end);

      final chunkResults = await SourceServerService.batchQuery(
        chunk,
        timeout: 3000,
      );
      results.addAll(chunkResults);

      // 如果还有下一批，稍微延迟一下让网络喘口气 (300ms)
      if (end < serverList.length) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    final entries = <ServerMapRuntimeEntry>[];

    for (final entry in results.entries) {
      final addr = entry.key;
      final info = entry.value;
      if (info == null) continue;

      final newMap = info.map;
      if (newMap.isEmpty) continue;

      final oldMap = _localServerLastMaps[addr];
      if (oldMap != newMap) {
        _localServerLastMaps[addr] = newMap;

        // 首次获取（oldMap == null）不需要触发换图通知，只是记录
        if (oldMap != null) {
          entries.add(
            ServerMapRuntimeEntry(
              serverAddress: addr,
              mapName: newMap,
              oldMapName: oldMap,
              maxPlayers: info.maxPlayers,
              hostName: info.name,
            ),
          );
        }
      }
    }

    if (entries.isNotEmpty) {
      LogService.d('[MapSubscription] 本地轮询发现 ${entries.length} 台私服换图，注入虚拟事件');
      for (final entry in entries) {
        _evaluateChange(entry);
      }
    }
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

    if (oldMap == null || oldMap == newMap) {
      return;
    }

    final lowerNewMap = newMap.toLowerCase();
    final subscription = _subscriptions.cast<MapSubscription?>().firstWhere(
      (s) => s!.mapName.toLowerCase() == lowerNewMap,
      orElse: () => null,
    );

    if (subscription == null) {
      return;
    }

    // 服务器分类映射可能因为分类列表更新而变化，按需懒加载
    if (!_categoriesLoaded) {
      await _loadServerCategoryMap();
    }

    final categoryName = _serverCategoryMap[entry.serverAddress];
    final serverName =
        entry.hostName ??
        _serverNameMap[entry.serverAddress] ??
        entry.serverAddress;

    final isExplicitlySelected =
        !subscription.isAllServers &&
        subscription.serverAddresses.contains(entry.serverAddress);

    if (categoryName == null && !isExplicitlySelected) {
      // 不在我们维护的分类列表里（比如自定义分组中的私人服务器），且没有明确单独勾选它，跳过
      return;
    }

    final resolvedCategoryName = categoryName ?? '指定服务器';

    // 服务器列表范围检查：如果没有明确勾选这台服务器，且也不是监控全部服务器，则跳过
    if (!subscription.isAllServers && !isExplicitlySelected) {
      return;
    }

    // 分类范围检查：如果明确勾选了这台服务器，则无视分类条件。只有在没单独勾选时才检查分类
    if (!isExplicitlySelected) {
      if (!subscription.isAllCategories) {
        if (!subscription.categoryNames.contains(categoryName)) {
          return;
        }
      } else if (!isAllCategories) {
        if (!_globalCategories.contains(categoryName)) {
          return;
        }
      }
    }

    // 冷却
    final now = DateTime.now().millisecondsSinceEpoch;
    final cooldownKey = '${newMap}_${entry.serverAddress}';
    final lastNotifyMs = _notificationCooldown[cooldownKey];
    if (lastNotifyMs != null) {
      final elapsed = (now - lastNotifyMs) ~/ 1000;
      if (elapsed < _cooldownSeconds) {
        return;
      }
    }

    _notificationCooldown[cooldownKey] = DateTime.now().millisecondsSinceEpoch;
    await _saveNotificationCooldown();

    // 获取玩家数量和排队数量
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

    LogService.i(
      '[MapSubscription] 命中订阅: ${subscription.displayName} @ $serverName ($resolvedCategoryName)',
    );

    if (subscription.isAutoJoinEnabled) {
      _autoJoinController.add(
        MapSubscriptionAutoJoinEvent(
          serverAddress: entry.serverAddress,
          serverName: serverName,
          mapName: subscription.mapName,
          mapLabel: subscription.mapLabel,
          mapBackground: subscription.mapBackground,
          countdownSeconds: subscription.autoJoinCountdownSeconds,
        ),
      );
    }

    _sendNotification(
      subscription: subscription,
      serverAddress: entry.serverAddress,
      serverName: serverName,
      categoryName: resolvedCategoryName,
      numPlayers: currentPlayers,
      maxPlayers: entry.maxPlayers ?? 0,
      queueCount: usersCount?.queueCount ?? 0,
      warmupCount: usersCount?.warmupCount ?? 0,
    ).catchError((e) {
      LogService.e('[MapSubscription] 发送通知异常', e);
    });
  }

  Future<void> _sendNotification({
    required MapSubscription subscription,
    required String serverAddress,
    required String serverName,
    required String categoryName,
    required int numPlayers,
    required int maxPlayers,
    required int queueCount,
    required int warmupCount,
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
            'currentPlayers': numPlayers,
            'maxPlayers': maxPlayers,
            'queueCount': queueCount,
            'warmupCount': warmupCount,
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


  Future<List<ServerCategory>> _loadAndMergeCategories() async {
    final customCategories = await CustomServerService.loadCustomCategories();
    final apiCategories = await ServerCategoryService.instance
        .getApiCategories();
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

  Future<void> _loadServerCategoryMap() {
    if (_categoriesLoaded && _loadingCategoriesFuture == null) {
      return Future.value();
    }

    _loadingCategoriesFuture ??= _loadServerCategoryMapInternal().whenComplete(
      () {
        _loadingCategoriesFuture = null;
      },
    );

    return _loadingCategoriesFuture!;
  }

  Future<void> _loadServerCategoryMapInternal() async {
    try {
      final apiCategories = await ServerCategoryService.instance
          .getApiCategories();
      _apiServers.clear();
      for (final cat in apiCategories) {
        for (final server in cat.serverList) {
          final addr = server.address ?? server.serverAddress ?? '';
          if (addr.isNotEmpty) _apiServers.add(addr);
        }
      }

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
      final Map<String, dynamic>? decoded = StorageUtils.getMap(
        _storageKeyNotificationCooldown,
      );
      if (decoded != null) {
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
      await StorageUtils.setMap(
        _storageKeyNotificationCooldown,
        _notificationCooldown,
      );
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
    _autoJoinController.close();
  }
}
