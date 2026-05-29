import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';

import '../bloc/settings/settings_state.dart';
import '../utils/fullscreen_detector.dart';
import '../utils/log_service.dart';
import '../utils/storage_utils.dart';

/// 通知类型
enum NotificationType {
  warmup, // 热身通知
  mapChange, // 换图通知
  updateLog, // 更新日志通知
  info, // 普通信息
  mapSubscription, // 地图订阅通知
  broadcast, // 广播通知
}

/// 通知数据
class NotificationData {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final String? serverAddress;
  final String? serverName;
  final String? mapName;
  final String? mapNameCn;
  final String? mapBackground;
  final int? autoDismissSeconds;
  final Map<String, dynamic>? extraData; // 额外数据，用于传递分类名、人数等

  NotificationData({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.serverAddress,
    this.serverName,
    this.mapName,
    this.mapNameCn,
    this.mapBackground,
    this.autoDismissSeconds,
    this.extraData,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.index,
    'title': title,
    'message': message,
    'serverAddress': serverAddress,
    'serverName': serverName,
    'mapName': mapName,
    'mapNameCn': mapNameCn,
    'mapBackground': mapBackground,
    'autoDismissSeconds': autoDismissSeconds,
    'extraData': extraData,
  };

  static NotificationData fromMap(Map<String, dynamic> map) {
    // extraData 需要特殊处理，确保类型正确
    Map<String, dynamic>? extraData;
    final rawExtraData = map['extraData'];
    if (rawExtraData != null && rawExtraData is Map) {
      extraData = Map<String, dynamic>.from(rawExtraData);
    }

    return NotificationData(
      id: map['id'] as String? ?? '',
      type: NotificationType.values[map['type'] as int? ?? 0],
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      serverAddress: map['serverAddress'] as String?,
      serverName: map['serverName'] as String?,
      mapName: map['mapName'] as String?,
      mapNameCn: map['mapNameCn'] as String?,
      mapBackground: map['mapBackground'] as String?,
      autoDismissSeconds: map['autoDismissSeconds'] as int?,
      extraData: extraData,
    );
  }

  /// 单个通知窗口的参数 JSON
  String toArguments(
    int position,
    String mainWindowId, {
    double? yOffset,
    NotificationPositionType? notificationPosition,
  }) => jsonEncode({
    'windowType': 'single_notification',
    'position': position,
    'yOffset': yOffset,
    'mainWindowId': mainWindowId,
    'notificationPosition':
        notificationPosition?.index ?? NotificationPositionType.topRight.index,
    ...toMap(),
  });

  /// 检查是否是单个通知窗口
  static bool isSingleNotificationWindow(String arguments) {
    if (arguments.isEmpty) return false;
    try {
      final map = jsonDecode(arguments) as Map<String, dynamic>;
      return map['windowType'] == 'single_notification';
    } catch (e) {
      return false;
    }
  }

  /// 从窗口参数解析通知数据、位置、Y偏移量、主窗口ID和通知位置
  static (NotificationData, int, double?, String, NotificationPositionType)
  fromArguments(String arguments) {
    final map = jsonDecode(arguments) as Map<String, dynamic>;
    final position = map['position'] as int? ?? 0;
    final yOffset = map['yOffset'] as double?;
    final mainWindowId = map['mainWindowId'] as String? ?? '';
    final notificationPositionIndex =
        map['notificationPosition'] as int? ??
        NotificationPositionType.topRight.index;
    final notificationPosition =
        NotificationPositionType.values[notificationPositionIndex];
    return (
      fromMap(map),
      position,
      yOffset,
      mainWindowId,
      notificationPosition,
    );
  }
}

/// 通知窗口信息
class _NotificationWindowInfo {
  final String notificationId;
  final WindowController controller;
  final double cardHeight;
  int position;

  _NotificationWindowInfo({
    required this.notificationId,
    required this.controller,
    required this.position,
    required this.cardHeight,
  });
}

/// 通知窗口服务（单例）
/// 每个通知使用独立窗口
class NotificationWindowService {
  static final NotificationWindowService _instance =
      NotificationWindowService._internal();
  factory NotificationWindowService() => _instance;
  NotificationWindowService._internal();

  /// 活跃的通知窗口
  final Map<String, _NotificationWindowInfo> _activeWindows = {};

  /// 主窗口 ID（用于子窗口通过 IPC 通知主窗口）
  String _mainWindowId = '';

  /// 窗口创建队列（串行化窗口创建，防止并发问题）
  final List<NotificationData> _createQueue = [];
  bool _isCreating = false;

  /// 等待队列（屏幕已满时，新通知在此等待）
  final List<NotificationData> _pendingQueue = [];

  /// 当前通知位置设置
  NotificationPositionType _notificationPosition =
      NotificationPositionType.topRight;

  /// 窗口配置
  static const double windowWidth = 300.0;
  static const double normalCardHeight = 72.0;
  static const double mapCardHeight = 88.0;
  static const double updateLogCardHeight = 110.0;
  static const double cardSpacing = 8.0;
  static const double topPadding = 5.0;
  static const int maxVisibleNotifications = 5;

  /// 获取指定位置之前所有通知的总高度
  /// [isWarmup] 是否是热身通知，热身通知从 topPadding 开始，其他通知需要跳过热身区域
  double _calculateYOffset(int targetPosition, {bool isWarmup = false}) {
    // 热身通知固定从 topPadding 开始
    if (isWarmup) return topPadding;

    // 其他通知从热身区域下方开始
    // 找到 position 0 的热身通知，使用其实际高度
    final warmupInfo = _activeWindows.values
        .where((w) => w.position == 0)
        .firstOrNull;
    final warmupHeight = warmupInfo?.cardHeight ?? mapCardHeight;
    double offset = topPadding + warmupHeight + cardSpacing;

    final sortedWindows = _activeWindows.values.toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    for (final info in sortedWindows) {
      // 跳过 position 0（热身区域）
      if (info.position == 0) continue;
      if (info.position >= targetPosition) break;
      offset += info.cardHeight + cardSpacing;
    }
    return offset;
  }

  /// 计算通知的卡片高度
  double _getCardHeight(NotificationData notification) {
    if (notification.type == NotificationType.updateLog) {
      return updateLogCardHeight;
    }
    if (_isMapNotification(notification)) {
      return mapCardHeight;
    }
    return normalCardHeight;
  }

  /// 判断是否为需要分行显示地图名的通知
  bool _isMapNotification(NotificationData notification) {
    return (notification.type == NotificationType.warmup ||
            notification.type == NotificationType.mapChange ||
            notification.type == NotificationType.mapSubscription) &&
        notification.mapName != null &&
        notification.mapName!.isNotEmpty;
  }

  /// 导航回调（由主窗口设置）
  void Function(String? updateTime)? _navigateCallback;

  /// 设置主窗口 ID（由主窗口调用）
  void setMainWindowId(String windowId) {
    _mainWindowId = windowId;
    LogService.d('[NotificationWindow] Main window ID set: $windowId');
  }

  /// 设置通知位置
  void setNotificationPosition(NotificationPositionType position) {
    _notificationPosition = position;
    LogService.d(
      '[NotificationWindow] Notification position set: ${position.displayName}',
    );
  }

  /// 获取当前通知位置
  NotificationPositionType get notificationPosition => _notificationPosition;

  /// 从设置中加载通知位置
  Future<void> loadNotificationPosition() async {
    try {
      final positionIndex =
          StorageUtils.getInt('notification_position') ??
          NotificationPositionType.topRight.index;
      _notificationPosition = NotificationPositionType.values[positionIndex];
      LogService.d(
        '[NotificationWindow] Loaded notification position: ${_notificationPosition.displayName}',
      );
    } catch (e) {
      LogService.e(
        '[NotificationWindow] Failed to load notification position',
        e,
      );
    }
  }

  /// 设置导航回调（由主窗口设置）
  void setNavigateCallback(void Function(String? updateTime)? callback) {
    _navigateCallback = callback;
  }

  /// 导航到更新日志页面
  void navigateToUpdateLog(String? updateTime) {
    LogService.d('[NotificationWindow] Navigate to update log: $updateTime');
    _navigateCallback?.call(updateTime);
  }

  /// 获取下一个可用位置
  /// [isWarmup] 是否是热身通知，热身通知固定在 position 0
  int _getNextPosition({bool isWarmup = false}) {
    // 热身通知固定在 position 0
    if (isWarmup) return 0;

    // 其他通知从 position 1 开始（position 0 保留给热身通知）
    if (_activeWindows.isEmpty) return 1;
    final positions = _activeWindows.values.map((w) => w.position).toSet();
    // 从 1 到 maxVisibleNotifications（包含）查找空位
    for (int i = 1; i <= maxVisibleNotifications; i++) {
      if (!positions.contains(i)) return i;
    }
    return _activeWindows.length + 1;
  }

  /// 显示通知
  Future<void> show(NotificationData notification) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    // 检查是否已存在相同 ID 的通知（活跃窗口中）
    if (_activeWindows.containsKey(notification.id)) {
      await _updateNotification(notification);
      return;
    }

    // 检查是否已在创建队列中
    if (_createQueue.any((n) => n.id == notification.id)) {
      LogService.d(
        '[NotificationWindow] Notification ${notification.id} already in create queue',
      );
      return;
    }

    // 检查是否已在等待队列中
    if (_pendingQueue.any((n) => n.id == notification.id)) {
      LogService.d(
        '[NotificationWindow] Notification ${notification.id} already in pending queue',
      );
      return;
    }

    // 如果屏幕已满（包括正在创建的），加入等待队列
    if (_activeWindows.length + _createQueue.length >=
        maxVisibleNotifications) {
      LogService.d(
        '[NotificationWindow] Screen full, adding ${notification.id} to pending queue',
      );
      _pendingQueue.add(notification);
      return;
    }

    // 加入创建队列
    _createQueue.add(notification);
    _processCreateQueue();
  }

  /// 处理创建队列（串行化窗口创建）
  Future<void> _processCreateQueue() async {
    if (_isCreating || _createQueue.isEmpty) return;

    _isCreating = true;

    while (_createQueue.isNotEmpty) {
      final notification = _createQueue.removeAt(0);

      // 再次检查是否已存在（可能在队列等待期间被创建）
      if (_activeWindows.containsKey(notification.id)) {
        await _updateNotification(notification);
        continue;
      }

      // 再次检查数量限制，如果满了就放入等待队列
      if (_activeWindows.length >= maxVisibleNotifications) {
        LogService.d(
          '[NotificationWindow] Screen full during processing, moving ${notification.id} to pending queue',
        );
        _pendingQueue.add(notification);
        continue;
      }

      await _createWindow(notification);
    }

    _isCreating = false;
  }

  /// 创建单个窗口
  Future<void> _createWindow(NotificationData notification) async {
    // 检测是否有全屏应用运行（仅 Windows）
    if (Platform.isWindows && !FullscreenDetector.instance.canCreateWindow()) {
      LogService.w(
        '[NotificationWindow] Fullscreen app detected, skipping window creation',
      );
      return;
    }

    final isWarmup = notification.type == NotificationType.warmup;
    final position = _getNextPosition(isWarmup: isWarmup);
    final yOffset = _calculateYOffset(position, isWarmup: isWarmup);

    try {
      // 创建新窗口，传递主窗口 ID、Y 偏移量和通知位置
      final controller = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: notification.toArguments(
            position,
            _mainWindowId,
            yOffset: yOffset,
            notificationPosition: _notificationPosition,
          ),
        ),
      );

      _activeWindows[notification.id] = _NotificationWindowInfo(
        notificationId: notification.id,
        controller: controller,
        position: position,
        cardHeight: _getCardHeight(notification),
      );
    } catch (e, stack) {
      LogService.e('[NotificationWindow] Create window error: $e\n$stack');
    }
  }

  /// 更新现有通知
  Future<void> _updateNotification(NotificationData notification) async {
    final info = _activeWindows[notification.id];
    if (info == null) return;

    try {
      await info.controller.invokeMethod(
        'updateNotification',
        notification.toMap(),
      );
    } catch (e) {
      LogService.d('[NotificationWindow] Update notification error: $e');
    }
  }

  /// 显示热身通知
  Future<void> showWarmupNotification({
    required String serverAddress,
    required String serverName,
    String? mapName,
    String? mapNameCn,
    String? mapBackground,
    int? warmupRemainingSeconds,
  }) async {
    final id = 'warmup_$serverAddress';
    // 显示格式：有中文名时 "中文名 (英文名)"，否则只显示英文名
    final mapDisplay = (mapNameCn != null && mapNameCn.isNotEmpty)
        ? '$mapNameCn ($mapName)'
        : mapName ?? '';
    final title = warmupRemainingSeconds != null && warmupRemainingSeconds > 0
        ? '热身 $warmupRemainingSeconds秒'
        : '热身中';
    await show(
      NotificationData(
        id: id,
        type: NotificationType.warmup,
        title: title,
        message: mapDisplay,
        serverAddress: serverAddress,
        serverName: serverName,
        mapName: mapName,
        mapNameCn: mapNameCn,
        mapBackground: mapBackground,
        autoDismissSeconds: warmupRemainingSeconds,
      ),
    );
  }

  /// 移除热身通知
  Future<void> dismissWarmupNotification(String serverAddress) async {
    await dismiss('warmup_$serverAddress');
  }

  /// 显示换图通知
  Future<void> showMapChangeNotification({
    required String serverAddress,
    required String serverName,
    required String oldMap,
    required String newMap,
    String? newMapCn,
    String? mapBackground,
    String? categoryName,
    int? currentPlayers,
    int? maxPlayers,
    int? queueCount,
    int? warmupCount,
  }) async {
    final id =
        'mapchange_${serverAddress}_${DateTime.now().millisecondsSinceEpoch}';
    // 显示格式：有中文名时 "中文名 (英文名)"，否则只显示英文名
    final displayName = newMapCn != null && newMapCn.isNotEmpty
        ? '$newMapCn ($newMap)'
        : newMap;
    await show(
      NotificationData(
        id: id,
        type: NotificationType.mapChange,
        title: '换图通知',
        message: displayName,
        serverAddress: serverAddress,
        serverName: serverName,
        mapName: newMap,
        mapNameCn: newMapCn,
        mapBackground: mapBackground,
        autoDismissSeconds: 15,
        extraData: {
          if (categoryName != null) 'categoryName': categoryName,
          if (currentPlayers != null) 'currentPlayers': currentPlayers,
          if (maxPlayers != null) 'maxPlayers': maxPlayers,
          if (queueCount != null) 'queueCount': queueCount,
          if (warmupCount != null) 'warmupCount': warmupCount,
        },
      ),
    );
  }

  /// 显示更新日志通知
  Future<void> showUpdateLogNotification({
    required String updateTime,
    required String content,
  }) async {
    final id = 'updatelog_${DateTime.now().millisecondsSinceEpoch}';

    // 根据内容长度计算阅读时间
    // 去除 HTML 标签后计算字符数，按每秒阅读 5 个字符计算
    final plainText = content.replaceAll(RegExp(r'<[^>]*>'), '');
    final charCount = plainText.length;
    final readingSeconds = (charCount / 5).ceil();
    // 最短 10 秒，最长 120 秒
    final autoDismissSeconds = readingSeconds.clamp(10, 120);

    await show(
      NotificationData(
        id: id,
        type: NotificationType.updateLog,
        title: '更新日志',
        message: content,
        serverName: updateTime,
        autoDismissSeconds: autoDismissSeconds,
      ),
    );
  }

  /// 显示广播通知
  Future<void> showBroadcastNotification({
    required String nickname,
    required String content,
  }) async {
    final id = 'broadcast_${DateTime.now().millisecondsSinceEpoch}';
    await show(
      NotificationData(
        id: id,
        type: NotificationType.broadcast,
        title: '广播',
        message: content,
        serverName: nickname,
        autoDismissSeconds: 30,
      ),
    );
  }

  /// 关闭通知
  Future<void> dismiss(String id) async {
    // 先从队列中移除（如果存在）
    _createQueue.removeWhere((n) => n.id == id);
    _pendingQueue.removeWhere((n) => n.id == id);

    final info = _activeWindows.remove(id);
    if (info == null) return;

    try {
      await info.controller.invokeMethod('window_close');
    } catch (e) {
      LogService.d('[NotificationWindow] Dismiss error: $e');
    }

    // 从等待队列中取出下一个通知显示（会自动填补空位）
    _showNextFromPendingQueue();
  }

  /// 通知窗口关闭回调（由主窗口 IPC 调用）
  void onNotificationWindowClosed(String notificationId) {
    final removed = _activeWindows.remove(notificationId);
    if (removed != null) {
      LogService.d(
        '[NotificationWindow] Window closed via IPC: $notificationId, remaining: ${_activeWindows.length}',
      );
      // 从等待队列中取出下一个通知显示（会自动填补空位）
      Future.microtask(() => _showNextFromPendingQueue());
    }
  }

  /// 检查热身通知是否已关闭（供 WarmupMonitorService 使用）
  bool isWarmupNotificationActive(String serverAddress) {
    final id = 'warmup_$serverAddress';
    return _activeWindows.containsKey(id) ||
        _createQueue.any((n) => n.id == id) ||
        _pendingQueue.any((n) => n.id == id);
  }

  /// 从等待队列中取出下一个通知显示
  void _showNextFromPendingQueue() {
    if (_pendingQueue.isEmpty) return;
    if (_activeWindows.length + _createQueue.length >=
        maxVisibleNotifications) {
      return;
    }

    final next = _pendingQueue.removeAt(0);
    LogService.d(
      '[NotificationWindow] Showing next from pending queue: ${next.id}',
    );

    // 加入创建队列（_getNextPosition 会自动找到空位）
    _createQueue.add(next);
    _processCreateQueue();
  }

  /// @deprecated 此方法在子窗口进程中调用无效
  void markWindowClosed(String notificationId) {
    // 子窗口应该通过 IPC 通知主窗口，此方法保留兼容性
    LogService.d(
      '[NotificationWindow] markWindowClosed (deprecated): $notificationId',
    );
  }

  /// 关闭所有通知
  Future<void> dismissAll() async {
    // 清空所有队列
    _createQueue.clear();
    _pendingQueue.clear();

    final ids = _activeWindows.keys.toList();
    for (final id in ids) {
      final info = _activeWindows.remove(id);
      if (info != null) {
        try {
          await info.controller.invokeMethod('window_close');
        } catch (e) {
          LogService.d('[NotificationWindow] Dismiss error: $e');
        }
      }
    }
  }

  void dispose() {
    dismissAll();
  }
}
