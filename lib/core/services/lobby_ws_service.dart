import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../api/env_config.dart';
import '../models/lobby_models.dart';
import '../services/auth_service.dart';
import '../utils/device_id_helper.dart';
import '../utils/log_service.dart';
import '../utils/platform_utils.dart';
import '../utils/storage_utils.dart';
import 'steam_user_service.dart';
import 'token_service.dart';

class LobbyWsService {
  LobbyWsService._() {
    // 注册 AuthService 登录状态监听器，处理大厅外的登出
    AuthService.instance.addLoginStateListener(_onAuthStateChanged);
  }

  static final LobbyWsService instance = LobbyWsService._();

  /// AuthService 登录状态监听器回调
  void _onAuthStateChanged(bool isLoggedIn) {
    if (_isDisposed) return;

    if (!isLoggedIn) {
      // 用户登出了，发送 logout 事件到服务器
      LogService.i('[LobbyWsService] 检测到用户登出，发送 logout 事件');
      logout(force: false);
    } else if (_isConnected && hasValidToken) {
      // 用户登录了，发送 login 事件
      LogService.i('[LobbyWsService] 检测到用户登录，发送 login 事件');
      login();
    }
  }

  static const String keySelectedSpriteId = 'lobby_selected_sprite_id';
  static const String keyAnonymousMode = 'lobby_anonymous_mode';
  static const String keyChatOpacity = 'lobby_chat_opacity';
  static const String keyShowNameplates = 'lobby_show_nameplates';
  static const String keyShowChatBubbles = 'lobby_show_chat_bubbles';
  static const String keyShowBroadcastNotifications = 'lobby_show_broadcast_notifications';
  static const String keyUseSteamName = 'lobby_use_steam_name';

  final StreamController<LobbyWsEvent> _eventController =
      StreamController<LobbyWsEvent>.broadcast();

  /// 最新的 snapshot 消息，用于新订阅者时重发
  LobbyWsEvent? _latestSnapshot;

  /// 缓存的 events stream（用于支持 snapshot 重发）
  Stream<LobbyWsEvent>? _cachedEventsStream;

  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  bool _isConnected = false;
  bool _isReconnecting = false;
  bool _isDisposed = false;

  /// 标记是否被服务端踢出（被踢后禁止自动重连）
  bool _isKicked = false;

  /// 标记 assets 是否已到达（用于处理先于 LobbyStarted 收到的 assets）
  bool _hasAssetsReceived = false;

  /// 缓存最新的 assets payload（原始数据，由 LobbyBloc 统一解析）
  Map<String, dynamic>? _latestAssetsPayload;

  /// 匿名用户的设备ID
  String? _deviceId;

  int _reconnectDelaySeconds = 2;
  static const int _maxReconnectDelaySeconds = 30;
  Timer? _reconnectTimer;

  /// 心跳定时器（客户端每 25 秒主动 ping 一次）
  static const int _pingIntervalSeconds = 25;
  Timer? _pingTimer;

  /// WebSocket 事件流，支持新订阅者获取最新的 snapshot
  Stream<LobbyWsEvent> get events {
    final latest = _latestSnapshot;
    if (latest != null) {
      // 缓存带 snapshot 重发的 stream
      _cachedEventsStream ??= Stream<LobbyWsEvent>.multi(
        (controller) {
          controller.add(latest);
          _eventController.stream.listen(
            controller.add,
            onError: controller.addError,
            onDone: controller.close,
          );
        },
        isBroadcast: true,
      );
      return _cachedEventsStream!;
    }
    return _eventController.stream;
  }

  /// 清除缓存的 events stream（snapshot 改变时调用）
  void _clearCachedEventsStream() {
    _cachedEventsStream = null;
  }

  /// WebSocket 连接状态
  bool get isConnected => _isConnected;

  /// 是否有有效的认证令牌
  bool get hasValidToken => TokenService.instance.isTokenValid;

  /// Assets 是否已到达（用于处理先于 LobbyStarted 收到的 assets）
  bool get hasAssetsReceived => _hasAssetsReceived;

  /// 获取最新的 assets payload（原始数据，由 LobbyBloc 统一解析）
  Map<String, dynamic>? getLastAssetsPayload() => _latestAssetsPayload;

  /// 重置被踢状态，允许重新连接
  /// 用户点击"重新登录"时调用
  void resetKicked() {
    _isKicked = false;
    LogService.i('[LobbyWsService] 被踢状态已重置');
  }

  /// 是否处于被踢状态
  bool get isKicked => _isKicked;

  /// 强制重新连接（被踢后使用）
  ///
  /// 与 [initialize] 不同，此方法会先清理所有旧状态再重新连接，
  /// 不受 _isConnected / _isReconnecting 守卫限制。
  Future<void> forceReconnect() async {
    if (_isDisposed) return;
    LogService.i('[LobbyWsService] forceReconnect: 清理旧连接并重新连接');

    // 取消重连定时器
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // 关闭旧 channel（如果还存在）
    _stopPingTimer();
    await _channelSubscription?.cancel();
    _channelSubscription = null;
    try {
      await _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _channel = null;
    _isConnected = false;
    _isReconnecting = false;
    _latestSnapshot = null;
    _latestAssetsPayload = null;
    _hasAssetsReceived = false;
    _clearCachedEventsStream();
    _reconnectDelaySeconds = 2;

    // 重新连接
    await _waitForTokenReady();
    await _ensureDeviceIdReady();
    await _doConnect();
  }

  /// 初始化并连接 WebSocket（幂等操作）
  ///
  /// 会等待 TokenService 恢复完成后再连接（最多等待 30 秒），
  /// 避免每次都先匿名连接再升级。
  /// 同时获取 deviceId 用于匿名用户连接。
  Future<void> initialize() async {
    if (_isDisposed) return;
    if (_isConnected || _isReconnecting) return;
    _isReconnecting = false;
    _reconnectDelaySeconds = 2;

    // 等待 token 有效后再连接，避免匿名升级
    await _waitForTokenReady();

    // 获取 deviceId（匿名用户必填）
    await _ensureDeviceIdReady();

    await _doConnect();
  }

  /// 等待 token 有效（最多 30 秒）
  /// 注意：只有用户已登录时才等待 token，未登录则直接以匿名身份连接
  Future<void> _waitForTokenReady() async {
    // 未登录用户不需要等待 token，直接以匿名身份连接
    if (!AuthService.instance.isLoggedIn) {
      LogService.d('[LobbyWsService] 用户未登录，将以匿名身份连接');
      return;
    }

    final start = DateTime.now();
    const maxWait = Duration(seconds: 30);
    const interval = Duration(milliseconds: 200);

    while (!TokenService.instance.isTokenValid) {
      if (DateTime.now().difference(start) >= maxWait) {
        LogService.w('[LobbyWsService] 等待 token 超时，将以匿名身份连接');
        break;
      }
      // 让出主线程，避免阻塞
      await Future.delayed(interval);
    }

    if (TokenService.instance.isTokenValid) {
      LogService.d('[LobbyWsService] Token 已就绪，开始连接');
    }
  }

  /// 等待 deviceId 准备就绪
  ///
  /// [DeviceIdHelper] 内部已包含虚拟机 BIOS 占位符检测和本地持久化 fallback，
  /// 此处不再向上层 rethrow，保证连接流程不因 deviceId 获取失败而中断。
  Future<void> _ensureDeviceIdReady() async {
    if (_deviceId != null) return;

    try {
      _deviceId = await DeviceIdHelper.getDeviceId();
      LogService.d('[LobbyWsService] deviceId 已就绪');
    } catch (e) {
      LogService.e('[LobbyWsService] 获取 deviceId 失败，已启用 fallback: $e');
      // DeviceIdHelper.getDeviceId() 的 catch 中必定会生成一个 fallback UUID 并返回，
      // _deviceId 此时理论上已有值。此处再追加随机 v4 作为绝对兜底，
      // 确保即使 DeviceIdHelper 内部所有路径都失败，ID 也不会是重复的 literal 字符串。
      _deviceId ??= const Uuid().v4();
    }
  }

  /// 标记是否正在刷新 Token（避免重复刷新）
  bool _isRefreshingToken = false;

  /// 执行实际的 WebSocket 连接
  Future<void> _doConnect({bool isRetryAfterRefresh = false}) async {
    final wsUri = _buildWsUri();
    LogService.d('[LobbyWsService] 正在连接大厅 WebSocket: $wsUri');

    final authHeaders = TokenService.instance.getAuthHeaders();

    try {
      final webSocket = await WebSocket.connect(wsUri, headers: authHeaders).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('WebSocket 连接超时');
        },
      );

      _channel = IOWebSocketChannel(webSocket);
      _isConnected = true;

      await _channelSubscription?.cancel();
      _channelSubscription = _channel!.stream.listen(
        _handleRawMessage,
        onDone: _handleSocketClosed,
        onError: _handleSocketError,
        cancelOnError: false,
      );

      _startPingTimer();
      _emitWsEvent(type: 'ws.connected', payload: {});

      // WebSocket 连接成功后，如果用户已登录，发送 login 事件
      if (AuthService.instance.isLoggedIn && hasValidToken) {
        LogService.d('[LobbyWsService] WebSocket 连接成功，用户已登录，发送 login 事件');
        login();
      }
    } on WebSocketException catch (error, stackTrace) {
      // 检查是否是 401 错误（Token 过期）
      final is401 = error.message.contains('401');
      
      if (is401 && !isRetryAfterRefresh && !_isRefreshingToken && AuthService.instance.isLoggedIn) {
        // 401 错误且未重试过，尝试刷新 Token 后重连
        LogService.w('[LobbyWsService] WebSocket 连接返回 401，尝试刷新 Token...');
        _isRefreshingToken = true;
        
        try {
          final refreshed = await _tryRefreshToken();
          _isRefreshingToken = false;
          
          if (refreshed) {
            LogService.i('[LobbyWsService] Token 刷新成功，重新连接 WebSocket...');
            // Token 刷新成功，重置重连延迟
            _reconnectDelaySeconds = 2;
            // 立即重试连接
            await _doConnect(isRetryAfterRefresh: true);
            return;
          } else {
            LogService.w('[LobbyWsService] Token 刷新失败，将以匿名身份重连');
          }
        } catch (e) {
          _isRefreshingToken = false;
          LogService.e('[LobbyWsService] Token 刷新异常', e);
        }
      }
      
      LogService.e('[LobbyWsService] 连接大厅 WebSocket 失败', error, stackTrace);
      _emitWsEvent(type: 'ws.error', payload: {'error': error.toString()});
      _scheduleReconnect();
    } catch (error, stackTrace) {
      LogService.e('[LobbyWsService] 连接大厅 WebSocket 失败', error, stackTrace);
      _emitWsEvent(type: 'ws.error', payload: {'error': error.toString()});
      _scheduleReconnect();
    }
  }

  /// 尝试刷新 Token
  /// 返回 true 表示刷新成功，false 表示刷新失败
  Future<bool> _tryRefreshToken() async {
    try {
      final result = await AuthService.instance.validateAndRefreshSession(
        forceRefreshJwt: true,
      );
      
      if (result.jwtRefreshed) {
        return true;
      }
      
      // 如果需要登出（论坛会话也失效了），触发强制登出
      if (result.shouldLogout) {
        LogService.w('[LobbyWsService] 论坛会话已失效，触发强制登出');
        await AuthService.instance.forceLogout();
      }
      
      return false;
    } catch (e) {
      LogService.e('[LobbyWsService] 刷新 Token 异常', e);
      return false;
    }
  }

  /// 发送内部合成事件，让订阅者可以响应
  void _emitWsEvent({required String type, required Map<String, dynamic> payload}) {
    if (_isDisposed) return;
    _eventController.add(LobbyWsEvent(
      version: 1,
      type: type,
      timestamp: DateTime.now(),
      traceId: '${DateTime.now().microsecondsSinceEpoch}',
      payload: payload,
    ));
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    if (_isReconnecting) return;
    _isReconnecting = true;
    LogService.w('[LobbyWsService] 将在 $_reconnectDelaySeconds 秒后尝试重连...');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelaySeconds), () {
      _isReconnecting = false;
      _reconnectDelaySeconds = (_reconnectDelaySeconds * 2).clamp(2, _maxReconnectDelaySeconds);
      initialize();
    });
  }

  /// 启动心跳定时器（每 25 秒发送一次 ping）
  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(
      const Duration(seconds: _pingIntervalSeconds),
      (_) => _sendPing(),
    );
    LogService.d('[LobbyWsService] 心跳定时器已启动 (间隔 ${_pingIntervalSeconds}s)');
  }

  /// 停止心跳定时器
  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// 发送 ping 心跳
  void _sendPing() {
    if (!_isConnected) return;
    _sendEnvelope(type: 'ping', payload: {});
  }

  /// 发送登录消息（替代 auth 升级）
  /// 文档中的 login 事件：前端显式登录
  Future<void> login() async {
    final token = TokenService.instance.token;
    if (token == null || token.isEmpty) {
      LogService.w('[LobbyWsService] 当前无可用 JWT Token，忽略 login 请求');
      return;
    }

    _sendEnvelope(
      type: 'login',
      payload: {
        'token': token,
        'deviceType': _deviceType,
      },
    );

    // 开启的情况才主动同步显示名称
    if (loadUseSteamName()) {
      _syncDisplayName();
    }
  }

  /// 发送登出消息
  /// 文档中的 logout 事件：前端显式登出
  /// [force] true=直接断开连接，false=降级为匿名用户
  Future<void> logout({bool force = false}) async {
    _sendEnvelope(
      type: 'logout',
      payload: {'force': force},
    );
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopPingTimer();
    await _channelSubscription?.cancel();
    _channelSubscription = null;
    await _channel?.sink.close(ws_status.normalClosure);
    _channel = null;
    _isConnected = false;
    _isReconnecting = false;
    // 移除 AuthService 登录状态监听器
    AuthService.instance.removeLoginStateListener(_onAuthStateChanged);
  }

  Future<void> sendMove(LobbyPosition position) async {
    _sendEnvelope(
      type: 'move.request',
      payload: {
        'targetX': position.x,
        'targetY': position.y,
      },
    );
  }

  Future<void> sendChat(String content) async {
    _sendEnvelope(
      type: 'chat.send',
      payload: {'content': content},
    );
  }

  Future<void> requestAssets({List<String>? types}) async {
    final payload = types != null ? {'types': types} : <String, dynamic>{};
    _sendEnvelope(type: 'assets.request', payload: payload);
  }

  Future<void> requestSnapshot({int? page}) async {
    final payload = page != null ? {'page': page} : <String, dynamic>{};
    _sendEnvelope(type: 'snapshot.request', payload: payload);
  }

  Future<void> sendSpriteChange(String spriteId) async {
    await StorageUtils.setString(keySelectedSpriteId, spriteId);
    _sendEnvelope(
      type: 'profile.sprite.change',
      payload: {'spriteId': spriteId},
    );
  }

  Future<void> setAnonymous(bool value) async {
    await StorageUtils.setBool(keyAnonymousMode, value);
    _sendEnvelope(
      type: 'profile.anonymous.change',
      payload: {'isAnonymous': value},
    );
  }

  Future<void> updateStatusText(String statusText) async {
    _sendEnvelope(
      type: 'profile.statusText.update',
      payload: {'statusText': statusText},
    );
  }

  /// 请求使用传送门
  Future<void> usePortal(String portalKey) async {
    _sendEnvelope(
      type: 'portal.use',
      payload: {'portalKey': portalKey},
    );
  }

  Future<void> setChatOpacity(double value) async {
    await StorageUtils.setDouble(keyChatOpacity, value);
  }

  Future<void> setShowNameplates(bool value) async {
    await StorageUtils.setBool(keyShowNameplates, value);
  }

  Future<void> setShowChatBubbles(bool value) async {
    await StorageUtils.setBool(keyShowChatBubbles, value);
  }

  Future<void> setShowBroadcastNotifications(bool value) async {
    await StorageUtils.setBool(keyShowBroadcastNotifications, value);
  }

  Future<void> setUseSteamName(bool value) async {
    await StorageUtils.setBool(keyUseSteamName, value);
    if (AuthService.instance.isLoggedIn && !loadAnonymousMode()) {
      _syncDisplayName();
    }
  }

  Future<void> _syncDisplayName() async {
    final useSteamName = loadUseSteamName();
    String steamName = '';
    if (useSteamName) {
      steamName = await SteamUserService().getCurrentUsername() ?? '';
    }
    _sendEnvelope(
      type: 'profile.displayName.update',
      payload: {
        'customName': '',
        'steamName': steamName,
      },
    );
  }

  /// 发送全服广播消息
  Future<void> sendBroadcast(String content) async {
    _sendEnvelope(
      type: 'broadcast.send',
      payload: {'content': content},
    );
  }

  /// 查询广播冷却状态
  Future<void> requestBroadcastCD() async {
    _sendEnvelope(
      type: 'broadcast.cd',
      payload: {},
    );
  }

  /// 请求全服在线用户统计
  /// [includeUsers] 是否返回用户列表，false 时只返回统计数据
  /// [mapId] 可选，指定地图ID，为空则返回所有地图
  Future<void> requestOnlineStats({bool includeUsers = true, String? mapId}) async {
    _sendEnvelope(
      type: 'online.stats',
      payload: {
        'includeUsers': includeUsers,
        if (mapId != null) 'mapId': mapId,
      },
    );
  }

  String loadSelectedSpriteId({String fallback = 'sprite_01'}) {
    return StorageUtils.getString(keySelectedSpriteId, defaultValue: fallback) ??
        fallback;
  }

  bool loadAnonymousMode() {
    return StorageUtils.getBool(keyAnonymousMode, defaultValue: false);
  }

  double loadChatOpacity() {
    return StorageUtils.getDouble(keyChatOpacity, defaultValue: 0.32) ?? 0.32;
  }

  bool loadShowNameplates() {
    return StorageUtils.getBool(keyShowNameplates, defaultValue: true);
  }

  bool loadShowChatBubbles() {
    return StorageUtils.getBool(keyShowChatBubbles, defaultValue: true);
  }

  bool loadShowBroadcastNotifications() {
    return StorageUtils.getBool(keyShowBroadcastNotifications, defaultValue: true);
  }

  bool loadUseSteamName() {
    return StorageUtils.getBool(keyUseSteamName, defaultValue: false);
  }

  /// 当前设备类型标识，用于 WebSocket 连接和 login 消息
  /// PC 端为 'pc'，移动端为 'mobile'
  String get _deviceType => PlatformUtils.isMobile ? 'mobile' : 'pc';

  String _buildWsUri() {
    final baseUrl = EnvConfig.apiBaseUrl;
    final wsBase = baseUrl.replaceFirst('http', 'ws');
    final uri = '$wsBase/api/stub';

    // 所有连接都强制携带 deviceId（用于设备识别和匿名追踪）
    // fallback 兜底：anonymous-fallback（仅在极端情况下触发）
    final deviceId = _deviceId;
    if (deviceId != null && deviceId.isNotEmpty) {
      return '$uri?deviceId=$deviceId&deviceType=$_deviceType';
    }
    throw StateError('[LobbyWsService] deviceId 未就绪，无法构建 WebSocket URI');
  }

  void _handleRawMessage(dynamic raw) {
    if (raw is! String) return;

    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return;

      final wsEvent = LobbyWsEvent(
        version: json['v'] as int? ?? 1,
        type: json['type'] as String? ?? 'unknown',
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          json['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        ),
        traceId: json['traceId'] as String? ?? '',
        payload: _castPayload(json['payload']),
      );

      LogService.d('[LobbyWsService] 收到大厅消息: $wsEvent');

      // 收到 assets 后标记，避免 LobbyStarted 监听时已错过
      if (wsEvent.type == 'assets') {
        _hasAssetsReceived = true;
        // 缓存原始 payload，解析逻辑统一由 LobbyBloc 处理
        _latestAssetsPayload = wsEvent.payload;
      }

      // 收到 system.kicked 后标记，禁止自动重连
      if (wsEvent.type == 'system.kicked') {
        _isKicked = true;
        _stopPingTimer();
        LogService.w('[LobbyWsService] 收到 system.kicked，已禁止自动重连');
      }

      // 不在这里请求 assets：等到进入大厅页面再请求（避免 URL token 过期）

      // 缓存最新的 snapshot，供新订阅者使用
      if (wsEvent.type == 'snapshot') {
        _latestSnapshot = wsEvent;
        _clearCachedEventsStream(); // snapshot 改变时重建缓存的 stream
      }

      if (_isDisposed || _eventController.isClosed) return;
      _eventController.add(wsEvent);
    } catch (error, stackTrace) {
      LogService.e('[LobbyWsService] 解析大厅消息失败', error, stackTrace);
    }
  }

  void _handleSocketClosed() {
    LogService.w('[LobbyWsService] 大厅 WebSocket 已关闭');
    _channelSubscription = null;
    _channel = null;
    _isConnected = false;
    _latestSnapshot = null;
    _latestAssetsPayload = null;
    _hasAssetsReceived = false;
    _clearCachedEventsStream();
    _stopPingTimer();
    _emitWsEvent(type: 'ws.closed', payload: {});
    // 被踢出时不自动重连
    if (!_isKicked) {
      _scheduleReconnect();
    } else {
      LogService.w('[LobbyWsService] 被踢出状态，跳过自动重连');
    }
  }

  void _handleSocketError(Object error, [StackTrace? stackTrace]) {
    LogService.e('[LobbyWsService] 大厅 WebSocket 异常', error, stackTrace);
    _emitWsEvent(type: 'ws.error', payload: {'error': error.toString()});
  }

  void _sendEnvelope({
    required String type,
    required Map<String, dynamic> payload,
  }) {
    final channel = _channel;
    if (!_isConnected || channel == null) {
      LogService.w('[LobbyWsService] WebSocket 未连接，忽略发送: $type');
      return;
    }

    final envelope = <String, dynamic>{
      'v': 1,
      'type': type,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'traceId': '${DateTime.now().microsecondsSinceEpoch}',
      'payload': payload,
    };

    LogService.d('[LobbyWsService] 发送大厅消息: $envelope');

    try {
      channel.sink.add(jsonEncode(envelope));
    } catch (error, stackTrace) {
      LogService.e('[LobbyWsService] 发送大厅消息失败: $type', error, stackTrace);
    }
  }

  Map<String, dynamic> _castPayload(Object? payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) {
      return payload.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return const <String, dynamic>{};
  }
}