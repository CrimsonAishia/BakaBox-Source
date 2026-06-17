import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../api/env_config.dart';
import '../constants/api_constants.dart';
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


  static const String _wsPath = ApiConstants.realtimeWsPath;
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);
  static const Duration _initialReconnectDelay = Duration(seconds: 1);
  static const int _sendChannelBufferLimit = 256;

  /// 连接假死检测：每隔多久检查一次「最近是否收到过数据」
  static const Duration _livenessCheckInterval = Duration(seconds: 15);

  /// 连接假死阈值：超过该时长未收到任何帧（含 pong）判定连接死亡。
  /// 服务端 / 客户端均 30s 一次心跳，留 2.5 个周期容差，避免误判。
  static const Duration _livenessTimeout = Duration(seconds: 75);


  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  /// 连接假死检测定时器
  Timer? _livenessTimer;

  /// 最近一次收到任何服务端帧的时间（用于假死检测）
  DateTime? _lastInboundAt;

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

  /// 各频道当前本地最新版本号（用于心跳丢包对账）
  final Map<String, int> _channelVersions = {};

  /// 各频道事件流控制器
  final Map<String, StreamController<RealtimeChannelEvent>>
  _channelEventStreams = {};

  /// 连接状态流控制器
  final StreamController<RealtimeConnectionState> _connectionStateController =
      StreamController<RealtimeConnectionState>.broadcast();

  /// 强制登出流（业务侧可监听并清理本地登录态）
  final StreamController<RealtimeForceLogoutPayload> _forceLogoutController =
      StreamController<RealtimeForceLogoutPayload>.broadcast();

  /// 重连成功流（仅在断线后重新建立连接时触发，首次连接不触发）
  ///
  /// 长连接只在数据变化时推送，断线期间发生的变更不会补发。
  /// 对于「订阅时不回放 snapshot」的频道（map.info / announcements /
  /// notifications / workshop.changelog），业务侧应监听此流，
  /// 在重连成功后通过各自的 REST 接口主动对账一次，防止数据不及时。
  /// 带 snapshot 的频道（server.map.runtime / score.updates）靠重订阅自动补齐，无需处理。
  final StreamController<void> _reconnectedController =
      StreamController<void>.broadcast();

  /// 对账信号流（重连成功 + 周期性触发）
  ///
  /// 与 [reconnectedStream] 的区别：
  /// - [reconnectedStream] 仅在「断线重连」时触发一次，适合做较重的操作
  ///   （如清空整片缓存）。
  /// - [reconcileStream] 也在断线重连时触发。原本包含定时兜底逻辑（现已移除，以避免大规模 HTTP 风暴）。
  ///   change-only 频道（announcements / notifications / workshop.changelog）
  ///   的轻量 REST 对账应监听此流。
  final StreamController<void> _reconcileController =
      StreamController<void>.broadcast();

  /// 重连延迟（指数退避）
  Duration _nextReconnectDelay = _initialReconnectDelay;

  /// 是否已被 dispose
  bool _disposed = false;

  /// 是否已启动（调用 [start] 后置 true）
  bool _started = false;

  /// 是否曾经成功建立过连接（收到至少一次 welcome）
  ///
  /// 用于区分「首次连接」与「断线重连」：首次连接业务侧通常已在初始化时
  /// 加载过数据，无需重复对账；只有重连才需要补拉。
  bool _hasConnectedBefore = false;

  /// 当前连接所使用的 token（用于检测 token 变化时主动重连）
  String? _connectedToken;

  /// 自增请求 ID
  int _reqIdCounter = 0;


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

  /// 重连成功事件流（仅断线重连触发，首次连接不触发）
  ///
  /// change-only 频道的业务侧可监听此流，在重连后主动调一次 REST 对账。
  Stream<void> get reconnectedStream => _reconnectedController.stream;

  /// 对账信号流（重连成功 + 连接保持期间周期性触发）
  ///
  /// change-only 频道的轻量 REST 对账应监听此流，而非 [reconnectedStream]，
  /// 以便覆盖「无断线但丢消息」的场景。
  Stream<void> get reconcileStream => _reconcileController.stream;

  /// 启动服务（应用启动时调用一次）
  Future<void> start() async {
    if (_disposed) return;
    if (_started) return;
    _started = true;
    LogService.i('[Realtime] 服务启动');
    _connect();
  }

  /// 停止服务（弱网模式开启时调用）
  ///
  /// 与 [dispose] 不同：保留单例与流控制器，仅断开连接和清理订阅状态，
  /// 后续可以再次调用 [start] 恢复。
  Future<void> stop() async {
    if (_disposed) return;
    if (!_started) return;
    _started = false;
    LogService.i('[Realtime] 服务停止（保留单例）');

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _stopLivenessWatch();

    await _channelSubscription?.cancel();
    _channelSubscription = null;
    try {
      await _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _channel = null;

    // 清理本地订阅状态，但保留引用计数（便于 start 后自动重订阅）
    _subscribedChannels.clear();
    _pendingSubscribeChannels.clear();
    _connectedToken = null;
    // 保留 _hasConnectedBefore：stop 期间必然漏掉 change-only 频道的变更，
    // 下次 start 恢复时应按「重连」语义触发一次对账（reconnected + reconcile），
    // 而不是被当成首次连接静默跳过
    _resetReconnectDelay();

    _setConnectionState(RealtimeConnectionState.idle);
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

  /// 强制重新拉取某频道的 snapshot（用于带 snapshot 的频道做对账兜底）。
  ///
  /// 适用场景：`server.users.count` / `score.updates` / `server.map.runtime`
  /// 这类「订阅时下发 snapshot」的频道，在「连接保持但服务端丢了某条 updated/
  /// changed」（send 缓冲溢出、跨实例桥接降级）时，本地快照会长期停留在旧值。
  /// 由于没有断线，重连补订阅机制不会触发，需要业务侧监听 [reconcileStream]
  /// 主动调用本方法，让服务端重新下发一份全量 snapshot。
  ///
  /// 规则：
  /// - 未连接：直接跳过（重连后 [_resubscribeAll] 会自动补订阅并带回 snapshot）。
  /// - 频道未订阅或正在等待 sub_ack（snapshot 在途）：跳过，避免无谓请求与
  ///   `not_subscribed` 错误。
  /// - 引用计数为 0（无人订阅）：跳过。
  void requestResnapshot(String channel) {
    if (_disposed) return;
    if (!isConnected) return;
    if ((_channelRefCount[channel] ?? 0) <= 0) return;
    // 正在等待 sub_ack/snapshot，说明刚发起订阅，snapshot 即将到达，无需重复
    if (_pendingSubscribeChannels.contains(channel)) return;
    if (!_subscribedChannels.contains(channel)) return;

    LogService.d('[Realtime] 对账：请求重发 snapshot $channel');
    _sendRaw({
      'action': RealtimeClientActions.resnapshot,
      'channel': channel,
      'reqId': _nextReqId('resnap'),
    });
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
    _stopLivenessWatch();
    await _channelSubscription?.cancel();
    await _channel?.sink.close(ws_status.normalClosure);
    _channel = null;
    _channelSubscription = null;
    for (final controller in _channelEventStreams.values) {
      await controller.close();
    }
    _channelEventStreams.clear();
    _channelVersions.clear();
    await _connectionStateController.close();
    await _forceLogoutController.close();
    await _reconnectedController.close();
    await _reconcileController.close();
    _setConnectionState(RealtimeConnectionState.disposed);
  }


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
            // 期间可能已重连/清理，channel 已不是当前连接，丢弃过期回调，
            // 否则会往已关闭的 sink 发 auth，触发 "Cannot add event after closing"
            if (_channel != channel) return;
            LogService.d('[Realtime] WebSocket ready');
            // 如果有 token，连接建立后立刻 auth（服务端 welcome 阶段身份取握手帧，
            // 但握手帧的 Authorization 并非每个平台都能带上，统一用 auth 消息保证一致性）
            if (token != null && token.isNotEmpty) {
              _sendAuth(token);
            }
            _startHeartbeat();
            _startLivenessWatch();
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
    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;
      _nextReconnectDelay = _doubleDelay(_nextReconnectDelay);
      // 必须 await 清理完成再连接，否则清理协程会在新连接建立后恢复执行，
      // 把刚建好的 channel 关掉并清空引用，导致永远连不上（需重启 App）。
      await _cleanupCurrentConnection();
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
    _stopLivenessWatch();
    // 先把旧连接引用捕获到局部变量并同步置空，再做异步关闭。
    // 否则 await 期间若有 _connect() 创建了新连接，恢复后会误关新连接、清空新引用。
    final oldSubscription = _channelSubscription;
    final oldChannel = _channel;
    _channelSubscription = null;
    _channel = null;
    _subscribedChannels.clear();
    _pendingSubscribeChannels.clear();
    await oldSubscription?.cancel();
    try {
      await oldChannel?.sink.close(ws_status.goingAway);
    } catch (_) {}
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


  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendRaw({'action': RealtimeClientActions.ping});
    });
  }


  /// 启动假死检测：定期检查最近一次收到帧的时间，超过阈值则主动重连。
  ///
  /// 覆盖「TCP 半开」场景：连接看似还在，但实际已不可用，`onDone` / `onError`
  /// 迟迟不触发。靠应用层 ping + 收帧时间戳主动发现并重连。
  void _startLivenessWatch() {
    _lastInboundAt = DateTime.now();
    _livenessTimer?.cancel();
    _livenessTimer = Timer.periodic(_livenessCheckInterval, (_) {
      if (_disposed || !_started) return;
      final last = _lastInboundAt;
      if (last == null) return;
      final silence = DateTime.now().difference(last);
      if (silence > _livenessTimeout) {
        LogService.w(
          '[Realtime] 连接假死检测：${silence.inSeconds}s 未收到数据，主动重连',
        );
        // 假死时连接状态仍是 connected，必须先切到 reconnecting，
        // 否则 _connect() 会因「已连接」而直接 return
        _cleanupCurrentConnection();
        _setConnectionState(RealtimeConnectionState.reconnecting);
        _scheduleImmediateReconnect();
      }
    });
  }

  void _stopLivenessWatch() {
    _livenessTimer?.cancel();
    _livenessTimer = null;
  }


  void _onMessage(dynamic raw) {
    try {
      // 收到任何帧都刷新存活时间戳（含 pong / event / 回执），用于假死检测
      _lastInboundAt = DateTime.now();
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
        _handlePong(msg);
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
      // 携带本地 Token 发起身份升级。
      // 等待 auth_ack 后再统一恢复订阅，避免握手期间发出的 subscribe 被服务端的 auth 处理管线丢弃或清理，
      // 导致本地卡在 _pendingSubscribeChannels 永远收不到 sub_ack 和快照（比分/人数无法更新，必须重启App）
      _sendAuth(localToken);
    } else {
      // 如果已经是目标身份（或是明确的匿名访问），直接触发重连后的批量订阅恢复
      _resubscribeAll();
    }

    // 区分首次连接与断线重连：仅重连时通知业务侧主动对账一次
    if (_hasConnectedBefore) {
      LogService.i('[Realtime] 重连成功，通知业务侧对账');
      if (!_reconnectedController.isClosed) {
        _reconnectedController.add(null);
      }
      if (!_reconcileController.isClosed) {
        _reconcileController.add(null);
      }
    } else {
      _hasConnectedBefore = true;
    }
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
    // 无论是登录还是登出，服务端都有可能清理部分或全部频道（避免状态泄露），
    // 也有可能会丢弃在途的 subscribe 请求。
    // 为了防止握手阶段或原地切换身份时产生竞态，直接清空本地的订阅/等待状态，
    // 并根据当前的业务侧引用计数发起全量重新订阅。
    _subscribedChannels.clear();
    _pendingSubscribeChannels.clear();
    _resubscribeAll();
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

    if (msg.version != null) {
      _channelVersions[channel] = msg.version!;
    }

    final controller = _channelEventStreams[channel];
    if (controller == null || controller.isClosed) return;
    controller.add(
      RealtimeChannelEvent(
        channel: channel,
        eventType: eventType,
        data: data,
        timestamp: msg.timestamp,
        version: msg.version,
      ),
    );
  }

  void _handlePong(RealtimeIncomingMessage msg) {
    final data = msg.data;
    if (data == null) return;
    
    final versions = data['versions'];
    if (versions is Map) {
      for (final entry in versions.entries) {
        final channel = entry.key.toString();
        final remoteVersion = (entry.value as num?)?.toInt();
        if (remoteVersion == null) continue;
        
        final localVersion = _channelVersions[channel];
        // 如果当前频道已订阅，且本地有版本记录但落后于服务端，说明丢包了
        if (_subscribedChannels.contains(channel) && localVersion != null) {
          if (localVersion < remoteVersion) {
            LogService.w('[Realtime] 心跳对账：频道 $channel 发生丢包 (本地 $localVersion < 服务端 $remoteVersion)，强制重拉取');
            requestResnapshot(channel);
            // 立即更新为远程版本，防止在 snapshot 回来之前多次触发 resnapshot
            _channelVersions[channel] = remoteVersion;
          }
        }
      }
    }
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

    // 如果是 auth 请求失败，身份未发生变更（通常保持匿名状态）。
    // 此时需要触发订阅恢复，以保证那些非用户级（公共）频道能正常工作。
    // 否则卡在 _handleWelcome 中等待 auth_ack 的频道将永远无法被订阅。
    if (msg.reqId?.startsWith('auth_') == true) {
      LogService.w('[Realtime] auth 请求失败，回退以当前身份恢复订阅');
      _subscribedChannels.clear();
      _pendingSubscribeChannels.clear();
      _resubscribeAll();
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
    // 无论是否连接，都先同步清理本地订阅状态：
    // 退订意图一旦发出，本地立即视为「未订阅」，避免后续 subscribe 被
    // 「已订阅 / 等待 sub_ack」判定吞掉（unsub_ack 回来时 _handleUnsubAck 再清一次，幂等）。
    final wasTracked =
        _subscribedChannels.remove(channel) ||
        _pendingSubscribeChannels.remove(channel);
    if (!isConnected) {
      return;
    }
    // 没订阅过也没在途，无需向服务端发退订
    if (!wasTracked) return;
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
