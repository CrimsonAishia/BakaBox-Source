import 'dart:async';
import 'dart:convert';

import '../api/server_api.dart';
import '../models/map_subscription_models.dart';
import '../models/server_models.dart';
import '../utils/log_service.dart';
import '../utils/storage_utils.dart';
import 'custom_server_service.dart';
import 'notification_window_service.dart';
import 'scheduler_service.dart';
import 'source_server_service.dart';
import 'tts_service.dart';

/// 地图订阅监控服务（单例）
///
/// 独立查询模式：
/// 通过 ServerApi 获取服务器列表，检测服务器换图并匹配订阅地图，
/// 触发通知窗口和 TTS 语音播报。
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
  static const String _storageKeyLastServerMaps =
      'map_subscription_last_server_maps';

  // ======== 常量 ========

  /// 任务 ID
  static const String _taskId = 'map_subscription_monitor';

  /// 默认通知冷却时间（秒）- 同时也是监控间隔
  static const int _defaultCooldownSeconds = 15;

  /// 最小冷却时间（秒）
  static const int minCooldownSeconds = 10;

  /// 最大冷却时间（秒）
  static const int maxCooldownSeconds = 60;

  /// 并发查询的最大并发数
  static const int _maxConcurrency = 20;

  /// 服务器查询超时时间（毫秒）
  static const int _serverQueryTimeout = 3000;

  // ======== 依赖服务 ========

  final SchedulerService _scheduler = SchedulerService();
  final ServerApi _serverApi = ServerApi();
  final NotificationWindowService _notificationService =
      NotificationWindowService();
  final TtsService _ttsService = TtsService();

  // ======== 状态字段 ========

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

  /// 通知冷却记录（key: "mapName_serverAddress", value: 上次通知时间戳毫秒）
  final Map<String, int> _notificationCooldown = {};

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

    // 加载持久化的冷却时间和地图记录
    await _loadPersistentData();

    _isInitialized = true;

    LogService.d(
      '[MapSubscription] 服务已初始化，'
      '订阅 ${_subscriptions.length} 个地图，'
      '全局开关: $_isEnabled，通知: $_isNotificationEnabled，TTS: $_isTtsEnabled，'
      '冷却记录: ${_notificationCooldown.length} 条，地图记录: ${_lastServerMaps.length} 条',
    );

    if (_isEnabled && _subscriptions.isNotEmpty) {
      // 先立即执行一次检测，填充 _lastServerMaps，避免首次换图漏报
      await _checkAllServers(initialScan: true);
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
    if (isSubscribed(subscription.mapName)) {
      LogService.d('[MapSubscription] 地图已订阅: ${subscription.mapName}');
      return;
    }

    _subscriptions.add(subscription);
    await _saveSubscriptions();
    _notifyStateChange();

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
    await _saveNotificationCooldown();

    _notifyStateChange();

    if (_subscriptions.isEmpty) {
      _stopMonitorLoop();
    }

    LogService.d('[MapSubscription] 移除订阅: $mapName');
  }

  /// 设置全局分类范围
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

  /// 更新单个订阅的分类范围
  Future<void> updateSubscriptionScope(
      String mapName, List<String> categoryNames) async {
    final index = _subscriptions.indexWhere((s) => s.mapName == mapName);
    if (index == -1) {
      LogService.w('[MapSubscription] 订阅不存在: $mapName');
      return;
    }

    _subscriptions[index] = _subscriptions[index].copyWith(
      categoryNames: List.from(categoryNames),
    );
    await _saveSubscriptions();
    _notifyStateChange();

    LogService.d(
      '[MapSubscription] 更新订阅分类范围: $mapName -> ${categoryNames.isEmpty ? "继承全局" : categoryNames}',
    );
  }

  /// 更新单个订阅的服务器范围
  Future<void> updateSubscriptionServers(
      String mapName, List<String> serverAddresses) async {
    final index = _subscriptions.indexWhere((s) => s.mapName == mapName);
    if (index == -1) {
      LogService.w('[MapSubscription] 订阅不存在: $mapName');
      return;
    }

    _subscriptions[index] = _subscriptions[index].copyWith(
      serverAddresses: List.from(serverAddresses),
    );
    await _saveSubscriptions();
    _notifyStateChange();

    LogService.d(
      '[MapSubscription] 更新订阅服务器范围: $mapName -> ${serverAddresses.isEmpty ? "继承全局" : "${serverAddresses.length}个服务器"}',
    );
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

    LogService.d('[MapSubscription] 获取到 ${result.length} 个可用服务器');
    return result;
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
      await _saveLastServerMaps();
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

    final intervalSeconds = _cooldownSeconds;

    _scheduler.register(
      ScheduledTask(
        id: _taskId,
        name: '地图订阅监控',
        interval: Duration(seconds: intervalSeconds),
        callback: () async => _checkAllServers(),
        runImmediately: false,
      ),
    );

    LogService.d('[MapSubscription] 监控循环已启动，间隔=$intervalSeconds秒');
  }

  /// 停止监控循环
  void _stopMonitorLoop() {
    _scheduler.cancel(_taskId);
    LogService.d('[MapSubscription] 监控循环已停止');
  }

  /// 加载并合并分类（提取公共逻辑）
  Future<List<ServerCategory>> _loadAndMergeCategories() async {
    final customCategories = await CustomServerService.loadCustomCategories();
    final apiCategories = await _serverApi.getServerList();
    return _mergeCategories(customCategories, apiCategories);
  }

  /// 合并自定义分类和 API 分类
  /// 
  /// 同名但不同来源的分类视为独立分类，不会合并
  /// - 自定义分类：isCustom=true
  /// - API 分类：isCustom=false（可能继承原有的 isCustom 标记）
  List<ServerCategory> _mergeCategories(
    List<ServerCategory> customCategories,
    List<ServerCategory> apiCategories,
  ) {
    final seenAddresses = <String>{};
    final categories = <ServerCategory>[];

    // 先添加自定义分类
    for (final cat in customCategories) {
      final name = cat.modelName ?? cat.category ?? '';
      if (name.isEmpty) continue;
      categories.add(cat.copyWith(isCustom: true));
      for (final server in cat.serverList) {
        final addr = server.address ?? server.serverAddress ?? '';
        if (addr.isNotEmpty) seenAddresses.add(addr);
      }
    }

    // 再添加 API 分类
    for (final cat in apiCategories) {
      final name = cat.modelName ?? cat.category ?? '';
      if (name.isEmpty) continue;

      // 只对服务器地址去重，不合并分类
      final dedupedServers = <ServerItem>[];
      for (final server in cat.serverList) {
        final addr = server.address ?? server.serverAddress ?? '';
        if (addr.isNotEmpty && !seenAddresses.contains(addr)) {
          dedupedServers.add(server);
          seenAddresses.add(addr);
        }
      }

      // 添加分类（即使同名也作为独立分类，添加后缀区分显示）
      categories.add(ServerCategory(
        modelName: cat.modelName,
        category: cat.category,
        serverList: dedupedServers,
        isCustom: false,
      ));
    }

    return categories;
  }

  /// 并发查询服务器信息（带限制）
  Future<List<_ServerQueryResult>> _queryServersConcurrently(
    List<_ServerQueryTask> tasks,
  ) async {
    if (tasks.isEmpty) return [];

    final results = <_ServerQueryResult>[];
    final futures = <Future<_ServerQueryResult>>[];

    for (final task in tasks) {
      // 使用受限的并发度
      if (futures.length >= _maxConcurrency) {
        // 等待任何一个完成
        final completed = await Future.any(futures);
        futures.removeWhere((f) => f == completed);
        if (completed.result != null) {
          results.add(completed);
        }
      }

      futures.add(_querySingleServer(task));
    }

    // 等待剩余的
    for (final future in futures) {
      final completed = await future;
      if (completed.result != null) {
        results.add(completed);
      }
    }

    return results;
  }

  /// 查询单个服务器信息
  Future<_ServerQueryResult> _querySingleServer(_ServerQueryTask task) async {
    try {
      final info = await SourceServerService.getServerInfo(
        task.ip,
        task.port,
        timeout: _serverQueryTimeout,
      );
      return _ServerQueryResult(
        task: task,
        result: info,
      );
    } catch (e) {
      return _ServerQueryResult(
        task: task,
        result: null,
        error: e.toString(),
      );
    }
  }

  /// 检查所有服务器
  Future<void> _checkAllServers({bool initialScan = false}) async {
    if (_subscriptions.isEmpty || !_isEnabled) {
      LogService.d(
        '[MapSubscription] 跳过检查: subscriptions=${_subscriptions.length}, enabled=$_isEnabled',
      );
      return;
    }

    final stopwatch = Stopwatch()..start();

    LogService.d(
      '[MapSubscription] 开始检查服务器，订阅数=${_subscriptions.length}，'
      '已记录服务器数=${_lastServerMaps.length}，首次扫描=$initialScan',
    );

    try {
      // 加载并合并分类
      final categories = await _loadAndMergeCategories();

      LogService.d(
        '[MapSubscription] 获取到 ${categories.length} 个分类 (自定义: ${categories.where((c) => c.isCustom).length})',
      );

      // 准备所有需要查询的服务器任务
      final queryTasks = <_ServerQueryTask>[];

      for (final category in categories) {
        final categoryName = category.modelName ?? category.category ?? '';
        if (categoryName.isEmpty) continue;

        // 检查全局分类范围过滤
        if (!isAllCategories && !_globalCategories.contains(categoryName)) {
          continue;
        }

        for (final server in category.serverList) {
          final serverAddress = server.address ?? server.serverAddress ?? '';
          if (serverAddress.isEmpty) continue;

          final parts = serverAddress.split(':');
          if (parts.length != 2) continue;
          final ip = parts[0];
          final port = int.tryParse(parts[1]);
          if (port == null) continue;

          queryTasks.add(_ServerQueryTask(
            serverAddress: serverAddress,
            ip: ip,
            port: port,
            categoryName: categoryName,
            serverName: server.getDisplayName(''),
            isCustomServer: server.isCustom,
          ));
        }
      }

      LogService.d('[MapSubscription] 准备并发查询 ${queryTasks.length} 个服务器...');

      // 并发查询所有服务器
      final queryResults = await _queryServersConcurrently(queryTasks);

      int validServerCount = 0;
      int changedCount = 0;

      // 处理查询结果
      for (final queryResult in queryResults) {
        final task = queryResult.task;
        final info = queryResult.result;

        if (info == null) continue;
        if (info.map.isEmpty || info.map == 'graphics_settings') continue;

        validServerCount++;
        final currentMap = info.map;
        final hostName = task.serverName.isNotEmpty
            ? task.serverName
            : info.name;

        final lastMap = _lastServerMaps[task.serverAddress];

        // 更新地图记录
        _lastServerMaps[task.serverAddress] = currentMap;

        // 调试日志
        if (lastMap != null && lastMap != currentMap) {
          changedCount++;
          LogService.d(
            '[MapSubscription] 检测到换图: ${task.serverAddress}, $lastMap -> $currentMap',
          );
        }

        // 首次扫描：预记录已订阅地图的冷却时间
        if (initialScan) {
          final matchingSubscription = _subscriptions.cast<MapSubscription?>().firstWhere(
            (s) => s!.mapName.toLowerCase() == currentMap.toLowerCase(),
            orElse: () => null,
          );

          if (matchingSubscription != null) {
            final cooldownKey = '${currentMap}_${task.serverAddress}';
            _notificationCooldown[cooldownKey] = DateTime.now().millisecondsSinceEpoch;
            LogService.d(
              '[MapSubscription] 首次扫描发现订阅地图: ${matchingSubscription.mapName} @ ${task.serverAddress}，已预记录冷却时间',
            );
          }
          continue;
        }

        // 检测换图并匹配订阅
        if (lastMap != null &&
            lastMap.isNotEmpty &&
            lastMap != currentMap &&
            lastMap != 'graphics_settings') {
          _checkSubscriptionMatch(
            newMap: currentMap,
            serverAddress: task.serverAddress,
            serverName: hostName,
            categoryName: task.categoryName,
            numPlayers: info.players,
            maxPlayers: info.maxPlayers,
          );
        }
      }

      // 保存持久化数据
      await _saveLastServerMaps();
      if (validServerCount > 0) {
        await _saveNotificationCooldown();
      }

      stopwatch.stop();
      LogService.d(
        '[MapSubscription] 检查完成: 总任务=${queryTasks.length}, '
        '有效服务器=$validServerCount, 换图=$changedCount, '
        '耗时=${stopwatch.elapsedMilliseconds}ms',
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
    final subscriptions = List<MapSubscription>.from(_subscriptions);

    for (final subscription in subscriptions) {
      // 地图名匹配（不区分大小写）
      if (subscription.mapName.toLowerCase() != newMap.toLowerCase()) {
        continue;
      }

      LogService.d(
        '[MapSubscription] 地图匹配成功: ${subscription.mapName} @ $serverName ($categoryName)',
      );

      // 检查订阅的范围设置
      // 1. 如果订阅设置了具体服务器地址，只监控这些服务器
      // 2. 如果订阅设置了分类，只监控这些分类
      // 3. 如果订阅没有设置任何限制，继承使用全局设置

      // 检查服务器范围
      if (!subscription.isAllServers) {
        if (!subscription.serverAddresses.contains(serverAddress)) {
          LogService.d(
            '[MapSubscription] 服务器不在订阅范围内: $serverAddress 不在 ${subscription.serverAddresses}',
          );
          continue;
        }
      }

      // 检查分类范围
      if (!subscription.isAllCategories) {
        if (!subscription.categoryNames.contains(categoryName)) {
          LogService.d(
            '[MapSubscription] 分类不在订阅范围内: $categoryName 不在 ${subscription.categoryNames}',
          );
          continue;
        }
      } else if (!isAllCategories) {
        // 订阅继承全局分类设置
        if (!_globalCategories.contains(categoryName)) {
          LogService.d(
            '[MapSubscription] 分类不在全局范围内: $categoryName 不在 $_globalCategories',
          );
          continue;
        }
      }

      // 通过范围检查，发送通知

      // 检查冷却
      final cooldownKey = '${newMap}_$serverAddress';
      final lastNotifyMs = _notificationCooldown[cooldownKey];

      if (lastNotifyMs != null) {
        final lastNotify = DateTime.fromMillisecondsSinceEpoch(lastNotifyMs);
        final elapsed = DateTime.now().difference(lastNotify).inSeconds;
        if (elapsed < _cooldownSeconds) {
          LogService.d('[MapSubscription] 冷却中，跳过通知: $cooldownKey (${_cooldownSeconds - elapsed}s 剩余)');
          continue;
        }
      }

      // 记录冷却
      _notificationCooldown[cooldownKey] = DateTime.now().millisecondsSinceEpoch;

      LogService.i(
        '[MapSubscription] 命中订阅: ${subscription.displayName} @ $serverName ($categoryName)',
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
    // 通知窗口
    if (_isNotificationEnabled) {
      final id = 'mapsub_${subscription.mapName}_${DateTime.now().millisecondsSinceEpoch}';
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

    // TTS 播报
    if (_isTtsEnabled) {
      LogService.d(
        '[MapSubscription] TTS 开关已开启，检查可用性: isAvailable=${_ttsService.isAvailable}',
      );
      if (_ttsService.isAvailable) {
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
      } else {
        LogService.d('[MapSubscription] TTS 不可用，跳过播报');
      }
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

  /// 加载持久化数据（冷却时间和地图记录）
  Future<void> _loadPersistentData() async {
    // 加载冷却时间
    try {
      final cooldownData = StorageUtils.getString(_storageKeyNotificationCooldown);
      if (cooldownData != null && cooldownData.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(cooldownData);
        _notificationCooldown.clear();
        for (final entry in decoded.entries) {
          if (entry.value is int) {
            // 清理过期的冷却记录（超过冷却时间2倍的直接丢弃）
            final lastNotify = DateTime.fromMillisecondsSinceEpoch(entry.value);
            final elapsed = DateTime.now().difference(lastNotify).inSeconds;
            if (elapsed < _cooldownSeconds * 2) {
              _notificationCooldown[entry.key] = entry.value;
            }
          }
        }
        LogService.d('[MapSubscription] 加载冷却记录: ${_notificationCooldown.length} 条');
      }
    } catch (e) {
      LogService.e('[MapSubscription] 加载冷却记录失败', e);
      _notificationCooldown.clear();
    }

    // 加载地图记录
    try {
      final mapsData = StorageUtils.getString(_storageKeyLastServerMaps);
      if (mapsData != null && mapsData.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(mapsData);
        _lastServerMaps.clear();
        _lastServerMaps.addAll(decoded.cast<String, String>());
        LogService.d('[MapSubscription] 加载地图记录: ${_lastServerMaps.length} 条');
      }
    } catch (e) {
      LogService.e('[MapSubscription] 加载地图记录失败', e);
      _lastServerMaps.clear();
    }
  }

  /// 保存冷却时间到持久化存储
  Future<void> _saveNotificationCooldown() async {
    try {
      final encoded = jsonEncode(_notificationCooldown);
      await StorageUtils.setString(_storageKeyNotificationCooldown, encoded);
    } catch (e) {
      LogService.e('[MapSubscription] 保存冷却记录失败', e);
    }
  }

  /// 保存地图记录到持久化存储
  Future<void> _saveLastServerMaps() async {
    try {
      final encoded = jsonEncode(_lastServerMaps);
      await StorageUtils.setString(_storageKeyLastServerMaps, encoded);
    } catch (e) {
      LogService.e('[MapSubscription] 保存地图记录失败', e);
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

// ======== 辅助类 ========

/// 服务器查询任务
class _ServerQueryTask {
  final String serverAddress;
  final String ip;
  final int port;
  final String categoryName;
  final String serverName;
  final bool isCustomServer;

  _ServerQueryTask({
    required this.serverAddress,
    required this.ip,
    required this.port,
    required this.categoryName,
    required this.serverName,
    required this.isCustomServer,
  });
}

/// 服务器查询结果
class _ServerQueryResult {
  final _ServerQueryTask task;
  final SourceServerInfo? result;
  final String? error;

  _ServerQueryResult({
    required this.task,
    required this.result,
    this.error,
  });
}
