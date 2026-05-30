import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../api/env_config.dart';
import '../models/realtime_models.dart';
import '../utils/log_service.dart';
import 'auth_service.dart';
import 'token_service.dart';

/// Zedbox 实时推送 WebSocket 服务（单例）
///
/// - 单条 WS 连接复用所有频道
/// - 自动重连（指数退避：1s → 2s → 4s → 8s → 16s → 30s）
/// - 心跳保活（30s）
/// - 引用计数式订阅（多个调用方订阅同一频道只发一次 `subscribe`）
/// - 登录/登出时通过 `auth` 消息原地切换身份，无需重连
/// - 暴露每频道的事件流（`events(channel)`）和连接状态流（`connectionStream`）
///
/// 全程被动消费：
/// - 业务侧不直接调用 send；通过 `subscribe(channel)` / `unsubscribe(channel)` 维护订阅
/// - 频道事件通过 `events(channel).listen(...)` 接收
class RealtimeService {
  RealtimeService._internal() {
    AuthService.instance.addLoginStateListener(_onLoginStateChanged);
  }

  static final RealtimeService _instance = RealtimeService._internal();

  factory RealtimeService() => _instance;

  // ---- 配置常量 ----

  static const String _wsPath = '/api/stub';
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);
  static const Duration _initialReconnectDelay = Duration(seconds: 1);
  static const int _sendChannelBufferLimit = 256;

  // ---- 内部状态 ----

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  /// 当前连接状态
  RealtimeConnectionState _connectionState = RealtimeConnectionState.idle;

  /// 当前身份（来自最近一次 welcome / auth_ack）
  RealtimeIdentity _identity = RealtimeIdentity.anonymous();

  /// 服务端支持的频道（从 welcome / auth_ack 中获取，空集合表示尚未握手）
  Set<String> _supportedChannels = const {};

  /// 引用计数：channel -> 订阅次数
  final Map<String, int> _channelRefCount = {};

  /// 已发送 subscribe 且收到 sub_ack 的频道
  final Set<String> _subscribedChannels = {};

  /// 已发送 subscribe 但尚未收到 sub_ack 的频道
  final Set<String> _pendingSubscribeChannels = {};

  /// 各频道事件流控制器
  final Map<String, StreamController<RealtimeChannelEvent>>
  _channelEventStreams = {};

  /// 连接状态流控制器
  final StreamController<RealtimeConnectionState> _connectionStateController =
      StreamController<RealtimeConnectionState>.broadcast();

  /// 强制登出流（业务侧可监听并清理本地登录态）
  final StreamController<RealtimeForceLogoutPayload> _forceLogoutController =
      StreamController<RealtimeForceLogoutPayload>.broadcast();

  /// 重连延迟（指数退避）
  Duration _nextReconnectDelay = _initialReconnectDelay;

  /// 是否已被 dispose
  bool _disposed = false;

  /// 是否已启动（调用 [start] 后置 true）
  bool _started = false;

  /// 当前连接所使用的 token（用于检测 token 变化时主动重连）
  String? _connectedToken;

  /// 自增请求 ID
  int _reqIdCounter = 0;

  // ---- 公共 API ----

  /// 当前连接状态
  RealtimeConnectionState get connectionState => _connectionState;

  /// 是否已建立连接（收到 welcome 后）
  bool get isConnected => _connectionState == RealtimeConnectionState.connected;

  /// 当前身份信息（welcome / auth_ack）
  RealtimeIdentity get identity => _identity;

  /// 服务端支持的频道列表
  Set<String> get supportedChannels => Set.unmodifiable(_supportedChannels);

  /// 连接状态变化流
  Stream<RealtimeConnectionState> get connectionStream =>
      _connectionStateController.stream;

  /// 强制登出事件流（服务端 force_logout）
  Stream<RealtimeForceLogoutPayload> get forceLogoutStream =>
      _forceLogoutController.stream;

  /// 启动服务（应用启动时调用一次）
  Future<void> start() async {
    if (_disposed) return;
    if (_started) return;
    _started = true;
    LogService.i('[Realtime] 服务启动');
    _connect();
  }

  /// 获取指定频道的事件流（可重复订阅，多个监听者共享同一底层订阅）
  ///
  /// 调用方需要自行管理订阅生命周期，确保用 [subscribe] 注册引用计数：
  ///
  /// ```dart
  /// RealtimeService().subscribe(RealtimeChannels.notifications);
  /// final sub = RealtimeService()
  ///     .events(RealtimeChannels.notifications)
  ///     .listen(onEvent);
  /// // 退出时
  /// await sub.cancel();
  /// RealtimeService().unsubscribe(RealtimeChannels.notifications);
  /// ```
  Stream<RealtimeChannelEvent> events(String channel) {
    final controller = _channelEventStreams.putIfAbsent(
      channel,
      () => StreamController<RealtimeChannelEvent>.broadcast(),
    );
    return controller.stream;
  }

  /// 订阅频道（引用计数 + 1）
  ///
  /// 第一次订阅会发送 `subscribe` 消息；后续仅累加引用计数。
  /// 如果 WS 尚未连接，会在握手完成后自动补发。
  void subscribe(String channel) {
    if (_disposed) return;
    final newCount = (_channelRefCount[channel] ?? 0) + 1;
    _channelRefCount[channel] = newCount;
    if (newCount == 1) {
      _sendSubscribeIfPossible(channel);
    }
  }

  /// 取消订阅（引用计数 - 1，归零时发送 `unsubscribe`）
  void unsubscribe(String channel) {
    if (_disposed) return;
    final current = _channelRefCount[channel] ?? 0;
    if (current <= 0) return;
    final newCount = current - 1;
    if (newCount > 0) {
      _channelRefCount[channel] = newCount;
      return;
    }
    _channelRefCount.remove(channel);
    _sendUnsubscribeIfPossible(channel);
  }

  /// 释放服务（应用退出时调用）
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    LogService.i('[Realtime] 服务释放');
    AuthService.instance.removeLoginStateListener(_onLoginStateChanged);
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    await _channelSubscription?.cancel();
    await _channel?.sink.close(ws_status.normalClosure);
    _channel = null;
    _channelSubscription = null;
    for (final controller in _channelEventStreams.values) {
      await controller.close();
    }
    _channelEventStreams.clear();
    await _connectionStateController.close();
    await _forceLogoutController.close();
    _setConnectionState(RealtimeConnectionState.disposed);
  }

  // ---- 连接管理 ----

  void _connect() {
    if (_disposed) return;
    if (_connectionState == RealtimeConnectionState.connecting ||
        _connectionState == RealtimeConnectionState.connected) {
      return;
    }

    _setConnectionState(RealtimeConnectionState.connecting);

    final token = TokenService.instance.token;
    _connectedToken = token;
    final uri = _buildWsUri();

    LogService.i(
      '[Realtime] 正在连接: $uri (token=${token != null ? "yes" : "no"})',
    );

    try {
      // 优先使用带 token 的 protocols 头（部分场景 Cookie/Authorization 在握手阶段不会带上）
      // 注：服务端文档明确支持 Authorization 头或 access_token Cookie；
      // 多平台（Web/桌面）下我们优先依赖 query 参数 + 随后发送 auth 消息绑定身份。
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      // 等待 ready 后再开始监听，避免连接尚未就绪时发消息
      channel.ready
          .then((_) {
            if (_disposed) return;
            LogService.d('[Realtime] WebSocket ready');
            // 如果有 token，连接建立后立刻 auth（服务端 welcome 阶段身份取握手帧，
            // 但握手帧的 Authorization 并非每个平台都能带上，统一用 auth 消息保证一致性）
            if (token != null && token.isNotEmpty) {
              _sendAuth(token);
            }
            _startHeartbeat();
          })
          .catchError((Object e, StackTrace st) {
            LogService.e('[Realtime] WebSocket ready 失败', e, st);
          });

      _channelSubscription = channel.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e, st) {
      LogService.e('[Realtime] 连接异常', e, st);
      _scheduleReconnect();
    }
  }

  Uri _buildWsUri() {
    final base = Uri.parse(EnvConfig.apiBaseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: _wsPath,
    );
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _setConnectionState(RealtimeConnectionState.reconnecting);
    _reconnectTimer?.cancel();
    final delay = _nextReconnectDelay;
    LogService.w('[Realtime] ${delay.inMilliseconds}ms 后重连');
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      _nextReconnectDelay = _doubleDelay(_nextReconnectDelay);
      _cleanupCurrentConnection();
      _connect();
    });
  }

  Duration _doubleDelay(Duration current) {
    final ms = current.inMilliseconds * 2;
    final next = Duration(milliseconds: ms);
    return next > _maxReconnectDelay ? _maxReconnectDelay : next;
  }

  void _resetReconnectDelay() {
    _nextReconnectDelay = _initialReconnectDelay;
  }

  Future<void> _cleanupCurrentConnection() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _channelSubscription?.cancel();
    _channelSubscription = null;
    try {
      await _channel?.sink.close(ws_status.goingAway);
    } catch (_) {}
    _channel = null;
    _subscribedChannels.clear();
    _pendingSubscribeChannels.clear();
  }

  void _onError(Object error, StackTrace stackTrace) {
    LogService.e('[Realtime] 流错误', error, stackTrace);
  }

  void _onDone() {
    if (_disposed) return;
    final code = _channel?.closeCode;
    final reason = _channel?.closeReason;
    LogService.w('[Realtime] 连接关闭 code=$code reason=$reason');
    _scheduleReconnect();
  }

  // ---- 心跳 ----

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendRaw({'action': RealtimeClientActions.ping});
    });
  }

  // ---- 收发消息 ----

  void _onMessage(dynamic raw) {
    try {
      if (raw is! String) {
        // 服务端只发 JSON 文本帧，忽略其他类型
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;

      final msg = RealtimeIncomingMessage.fromJson(decoded);
      _dispatch(msg);
    } catch (e, st) {
      LogService.e('[Realtime] 解析消息失败', e, st);
    }
  }

  void _dispatch(RealtimeIncomingMessage msg) {
    switch (msg.action) {
      case RealtimeServerActions.welcome:
        _handleWelcome(msg);
        break;
      case RealtimeServerActions.authAck:
        _handleAuthAck(msg);
        break;
      case RealtimeServerActions.subAck:
        _handleSubAck(msg);
        break;
      case RealtimeServerActions.unsubAck:
        _handleUnsubAck(msg);
        break;
      case RealtimeServerActions.event:
        _handleEvent(msg);
        break;
      case RealtimeServerActions.pong:
        // 静默处理
        break;
      case RealtimeServerActions.error:
        _handleError(msg);
        break;
      case RealtimeServerActions.forceLogout:
        _handleForceLogout(msg);
        break;
      default:
        LogService.d('[Realtime] 未知 action: ${msg.action}');
    }
  }

  void _handleWelcome(RealtimeIncomingMessage msg) {
    final data = msg.data;
    if (data != null) {
      _identity = RealtimeIdentity.fromJson(data);
      _supportedChannels = _identity.supportChannels.toSet();
    }
    _setConnectionState(RealtimeConnectionState.connected);
    _resetReconnectDelay();
    LogService.i(
      '[Realtime] welcome anonymous=${_identity.isAnonymous} userId=${_identity.userId}',
    );

    // 兜底：握手阶段如果 TokenService 还没就绪导致服务端把我们当匿名，
    // 但本地此时已经有有效 token，则补发一次 auth 切换身份
    final localToken = TokenService.instance.token;
    final hasLocalToken = localToken != null && localToken.isNotEmpty;
    if (_identity.isAnonymous && hasLocalToken) {
      _sendAuth(localToken);
    }

    // 重连后补发所有引用计数 > 0 的频道订阅
    _resubscribeAll();
  }

  void _handleAuthAck(RealtimeIncomingMessage msg) {
    final data = msg.data;
    if (data != null) {
      _identity = RealtimeIdentity.fromJson(data);
      _supportedChannels = _identity.supportChannels.toSet();
    }
    LogService.i(
      '[Realtime] auth_ack anonymous=${_identity.isAnonymous} userId=${_identity.userId} reqId=${msg.reqId}',
    );
    // 服务端会自动退订用户级频道：清理本地状态并按需重新订阅
    final userChannels = RealtimeChannels.userScoped;
    for (final channel in userChannels) {
      _subscribedChannels.remove(channel);
      _pendingSubscribeChannels.remove(channel);
    }
    // 如果当前已登录，业务侧仍然持有这些频道的引用计数，重新订阅
    if (!_identity.isAnonymous) {
      for (final channel in userChannels) {
        if ((_channelRefCount[channel] ?? 0) > 0) {
          _sendSubscribeIfPossible(channel);
        }
      }
    }
  }

  void _handleSubAck(RealtimeIncomingMessage msg) {
    final channel = msg.channel;
    if (channel == null) return;
    _pendingSubscribeChannels.remove(channel);
    _subscribedChannels.add(channel);
    LogService.d('[Realtime] sub_ack: $channel');
  }

  void _handleUnsubAck(RealtimeIncomingMessage msg) {
    final channel = msg.channel;
    if (channel == null) return;
    _subscribedChannels.remove(channel);
    _pendingSubscribeChannels.remove(channel);
    LogService.d('[Realtime] unsub_ack: $channel');
  }

  void _handleEvent(RealtimeIncomingMessage msg) {
    final channel = msg.channel;
    final eventType = msg.eventType;
    final data = msg.data;
    if (channel == null || eventType == null || data == null) return;

    final controller = _channelEventStreams[channel];
    if (controller == null || controller.isClosed) return;
    controller.add(
      RealtimeChannelEvent(
        channel: channel,
        eventType: eventType,
        data: data,
        timestamp: msg.timestamp,
      ),
    );
  }

  void _handleError(RealtimeIncomingMessage msg) {
    final code = msg.error;
    final channel = msg.channel;
    LogService.w(
      '[Realtime] error code=$code channel=$channel reqId=${msg.reqId}',
    );

    if (code == RealtimeErrorCodes.authRequired && channel != null) {
      _pendingSubscribeChannels.remove(channel);
      // auth_required：保留引用计数，登录后会自动补发订阅
    }
  }

  void _handleForceLogout(RealtimeIncomingMessage msg) {
    final data = msg.data;
    if (data == null) return;
    final payload = RealtimeForceLogoutPayload.fromJson(data);
    LogService.w('[Realtime] force_logout reason=${payload.reason}');
    if (!_forceLogoutController.isClosed) {
      _forceLogoutController.add(payload);
    }
    // 服务端已把连接降级为匿名 + 清空用户级订阅，本地状态同步
    _identity = RealtimeIdentity(
      isAnonymous: true,
      userId: 0,
      visitorId: _identity.visitorId,
      supportChannels: _identity.supportChannels,
    );
    for (final channel in RealtimeChannels.userScoped) {
      _subscribedChannels.remove(channel);
      _pendingSubscribeChannels.remove(channel);
    }
  }

  // ---- 订阅 / 鉴权辅助 ----

  void _resubscribeAll() {
    final pendingChannels = _channelRefCount.keys.toList();
    if (pendingChannels.isEmpty) return;
    LogService.d('[Realtime] 重新订阅 ${pendingChannels.length} 个频道');
    for (final channel in pendingChannels) {
      _sendSubscribeIfPossible(channel);
    }
  }

  void _sendSubscribeIfPossible(String channel) {
    if (!isConnected) return;
    if (_subscribedChannels.contains(channel) ||
        _pendingSubscribeChannels.contains(channel)) {
      return;
    }
    if (RealtimeChannels.userScoped.contains(channel) &&
        _identity.isAnonymous) {
      // 用户级频道未登录时不发，等登录后再补
      LogService.d('[Realtime] 用户未登录，延迟订阅: $channel');
      return;
    }
    final reqId = _nextReqId('sub');
    _pendingSubscribeChannels.add(channel);
    _sendRaw({
      'action': RealtimeClientActions.subscribe,
      'channel': channel,
      'reqId': reqId,
    });
  }

  void _sendUnsubscribeIfPossible(String channel) {
    if (!isConnected) {
      _subscribedChannels.remove(channel);
      _pendingSubscribeChannels.remove(channel);
      return;
    }
    final reqId = _nextReqId('unsub');
    _sendRaw({
      'action': RealtimeClientActions.unsubscribe,
      'channel': channel,
      'reqId': reqId,
    });
  }

  void _sendAuth(String token) {
    final reqId = _nextReqId('auth');
    _sendRaw({
      'action': RealtimeClientActions.auth,
      'token': token,
      'reqId': reqId,
    });
  }

  void _sendRaw(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) return;
    try {
      final encoded = jsonEncode(payload);
      // 简单防爆：消息过长时截断日志，但仍然发送
      if (encoded.length > _sendChannelBufferLimit) {
        LogService.d(
          '[Realtime] send (${encoded.length}b) ${payload['action']}',
        );
      }
      channel.sink.add(encoded);
    } catch (e, st) {
      LogService.e('[Realtime] 发送消息失败', e, st);
    }
  }

  String _nextReqId(String prefix) {
    _reqIdCounter += 1;
    return '${prefix}_$_reqIdCounter';
  }

  void _setConnectionState(RealtimeConnectionState next) {
    if (_connectionState == next) return;
    _connectionState = next;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(next);
    }
  }

  // ---- 登录状态联动 ----

  void _onLoginStateChanged(bool isLoggedIn) {
    if (_disposed) return;
    if (!_started) return;

    final newToken = TokenService.instance.token;

    // 已建立连接：原地切换身份
    if (isConnected) {
      // 已登出场景：发送空 token
      _sendAuth(newToken ?? '');
      _connectedToken = newToken;
      return;
    }

    // 还没连接：触发连接 / 等待重连后再 auth
    if (_connectedToken != newToken) {
      _connectedToken = newToken;
      // 强制重连让握手阶段也带上新身份
      if (_channel != null) {
        _cleanupCurrentConnection();
      }
      _scheduleImmediateReconnect();
    }
  }

  void _scheduleImmediateReconnect() {
    _reconnectTimer?.cancel();
    _resetReconnectDelay();
    _reconnectTimer = Timer(Duration.zero, () {
      _reconnectTimer = null;
      _connect();
    });
  }
}
