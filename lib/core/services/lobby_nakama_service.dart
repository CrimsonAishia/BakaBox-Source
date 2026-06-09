import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nakama/nakama.dart';
import 'package:uuid/uuid.dart';

import '../models/lobby_envelope.dart' show LobbyEnvelopeParser;
import '../models/lobby_models.dart';
import '../models/nakama_config.dart';
import '../models/proto/lobby.pb.dart' as pb;
import '../services/auth_service.dart';
import '../utils/device_id_helper.dart';
import '../utils/log_service.dart';
import '../utils/platform_utils.dart';
import '../utils/storage_utils.dart';
import 'steam_user_service.dart';
import 'token_service.dart';

// ---------------------------------------------------------------------------
// Task 4.1: _NakamaClientManager
// ---------------------------------------------------------------------------

/// Nakama REST 客户端管理器（内部使用）
///
/// 封装 Nakama 客户端初始化、认证、Session 刷新和 RPC 调用。
class _NakamaClientManager {
  NakamaBaseClient? _client;
  Session? _session;
  NakamaConfig? _config;
  String? _deviceId;

  /// Session 即将过期的提前量（提前 30 秒视为过期，避免边界竞态）
  static const int _sessionExpiryBufferSeconds = 30;

  /// 初始化 Nakama 客户端
  void init(NakamaConfig config) {
    _config = config;
    _client = getNakamaClient(
      host: config.host,
      serverKey: config.serverKey,
      key: 'lobby_client',
      httpPort: config.port,
      grpcPort: config.grpcPort,
      ssl: config.ssl,
    );
    LogService.d(
      '[NakamaClientManager] 客户端已初始化: ${config.host}:${config.port}',
    );
  }

  /// 认证
  ///
  /// **统一使用设备 ID 认证**，无论用户是否登录。
  /// 登录用户在连接成功后通过 WebSocket 发送 `login` 消息升级身份。
  ///
  /// 这是因为 Nakama 的 `authenticateCustom` 不支持直接传入 JWT token，
  /// 需要服务器端实现自定义认证钩子。我们的架构是先匿名连接，再通过
  /// WebSocket 消息升级身份。
  Future<Session> authenticate({
    String? jwtToken,
    required String deviceId,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('[NakamaClientManager] 客户端未初始化');
    }

    _deviceId = deviceId;

    // 统一使用设备 ID 认证（无论是否有 JWT token）
    // JWT token 会在连接成功后通过 login 消息发送给服务器
    LogService.d(
      '[NakamaClientManager] 使用设备ID认证 (authenticateDevice), '
      'hasJwt=${jwtToken != null && jwtToken.isNotEmpty}',
    );
    _session = await client.authenticateDevice(
      deviceId: deviceId,
      create: true,
      username: null,
    );

    LogService.i(
      '[NakamaClientManager] 认证成功, userId=${_session!.userId}, '
      'expiresAt=${_session!.expiresAt}',
    );
    return _session!;
  }

  /// 刷新 Session
  ///
  /// Session 过期时刷新，刷新失败则重新认证。
  Future<Session> refreshSession({
    String? jwtToken,
    required String deviceId,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('[NakamaClientManager] 客户端未初始化');
    }

    final currentSession = _session;
    if (currentSession == null) {
      LogService.w('[NakamaClientManager] 无 Session，直接重新认证');
      return authenticate(jwtToken: jwtToken, deviceId: deviceId);
    }

    try {
      LogService.d('[NakamaClientManager] 尝试刷新 Session...');
      _session = await client.sessionRefresh(session: currentSession);
      LogService.i('[NakamaClientManager] Session 刷新成功');
      return _session!;
    } catch (e) {
      LogService.w('[NakamaClientManager] Session 刷新失败，重新认证: $e');
      return authenticate(jwtToken: jwtToken, deviceId: deviceId);
    }
  }

  /// RPC 调用（带 Session 过期自动刷新 + 401 重试）
  ///
  /// 1. 调用前检查 Session 是否即将过期，提前刷新
  /// 2. 调用失败且疑似 Session 过期（401/Unauthenticated），刷新后重试一次
  Future<String?> rpc(String id, {String? payload}) async {
    final client = _client;
    if (client == null) {
      throw StateError('[NakamaClientManager] 客户端未初始化');
    }
    if (_session == null) {
      throw StateError('[NakamaClientManager] Session 未就绪');
    }

    // 预检：Session 即将过期则提前刷新
    if (_isSessionExpiringSoon()) {
      LogService.d('[NakamaClientManager] Session 即将过期，RPC 调用前主动刷新: $id');
      await _ensureSessionFresh();
    }

    LogService.d('[NakamaClientManager] RPC 调用: $id');
    try {
      return await client.rpc(session: _session!, id: id, payload: payload);
    } catch (e) {
      // 判断是否为 Session 过期导致的认证错误（401 / Unauthenticated）
      if (_isAuthError(e)) {
        LogService.w('[NakamaClientManager] RPC $id 认证失败，尝试刷新 Session 后重试: $e');
        await _ensureSessionFresh();
        // 重试一次
        return await client.rpc(session: _session!, id: id, payload: payload);
      }
      rethrow;
    }
  }

  /// 判断 Session 是否即将过期（含提前量）
  bool _isSessionExpiringSoon() {
    final session = _session;
    if (session == null) return true;
    if (session.isExpired) return true;
    // 提前 buffer 秒视为即将过期
    final now = DateTime.now();
    final expiresAt = session.expiresAt;
    return expiresAt.difference(now).inSeconds <= _sessionExpiryBufferSeconds;
  }

  /// 确保 Session 有效：刷新或重新认证
  Future<void> _ensureSessionFresh() async {
    final deviceId = _deviceId;
    if (deviceId == null) {
      throw StateError('[NakamaClientManager] 无法刷新 Session（缺少 deviceId）');
    }
    await refreshSession(deviceId: deviceId);
  }

  /// 判断异常是否为认证/授权错误（Session 过期）
  bool _isAuthError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('unauthenticated') ||
        msg.contains('401') ||
        msg.contains('token') ||
        msg.contains('session expired') ||
        msg.contains('not authenticated');
  }

  /// 当前 Session 是否有效（未过期）
  bool get isSessionValid {
    final session = _session;
    if (session == null) return false;
    return !session.isExpired;
  }

  /// 当前 Session token
  String? get token => _session?.token;

  /// 当前 Session
  Session? get session => _session;

  /// 当前配置
  NakamaConfig? get config => _config;
}

// ---------------------------------------------------------------------------
// Task 4.2: _NakamaSocketManager
// ---------------------------------------------------------------------------

/// Nakama WebSocket 管理器（内部使用）
///
/// 管理 WebSocket 连接、Match 加入/离开和消息收发。
class _NakamaSocketManager {
  NakamaWebsocketClient? _socket;
  String? _currentMatchId;
  bool _isConnected = false;

  final StreamController<LobbyWsEvent> _matchEventController =
      StreamController<LobbyWsEvent>.broadcast();
  final StreamController<void> _disconnectController =
      StreamController<void>.broadcast();

  StreamSubscription<MatchData>? _matchDataSubscription;
  StreamSubscription<MatchPresenceEvent>? _matchPresenceSubscription;

  // === C4 应用层主动心跳 ===
  //
  // Nakama Dart SDK 1.3.0 不发送任何客户端保活帧，完全依赖系统事件循环自动回 pong。
  // 高并发广播下主 isolate 被 protobuf 解码 + Widget 重建饿死时，pong 控制帧迟到，
  // 服务端 pong_wait_ms 读超时把客户端踢掉（实测掉线根因）。
  //
  // 解决：定时主动发一条最廉价的上行消息（online.stats 只读查询，新旧服务端都支持，
  // 不产生副作用广播），持续"喂"服务端的读超时计时器。
  // 间隔 12s « 服务端 pong_wait_ms(60s)，即便连续丢 3 次仍在窗口内。
  Timer? _appHeartbeatTimer;
  static const Duration _appHeartbeatInterval = Duration(seconds: 12);

  void _startAppHeartbeat() {
    _appHeartbeatTimer?.cancel();
    _appHeartbeatTimer = Timer.periodic(_appHeartbeatInterval, (_) {
      if (!_isConnected || _currentMatchId == null) return;
      try {
        final envelope = pb.LobbyEnvelope()
          ..v = 1
          ..type = 'online.stats'
          // include_users=false：轻量查询，仅维持链路活性，不拉全量用户列表
          ..onlineStatsRequest = (pb.OnlineStatsRequest()..includeUsers = false);
        sendEnvelope(envelope);
      } catch (_) {
        // 心跳失败不应影响主流程；真正断连由 onDone 处理
      }
    });
  }

  void _stopAppHeartbeat() {
    _appHeartbeatTimer?.cancel();
    _appHeartbeatTimer = null;
  }

  /// 建立 WebSocket 连接
  Future<void> connect({
    required String host,
    required int port,
    required bool ssl,
    required String token,
  }) async {
    // 防御性清理：建立新连接前，先关闭可能存在的旧连接，避免连接泄漏。
    // 由于每次使用唯一 key（NakamaWebsocketClient.init 按 key 缓存），
    // SDK 不会自动复用或关闭旧连接，必须显式断开，否则重连会不断累积新连接。
    if (_socket != null) {
      LogService.w('[NakamaSocketManager] 检测到已存在的连接，先断开旧连接再重连');
      await disconnect();
    }

    // 使用唯一 key 避免缓存问题（NakamaWebsocketClient.init 按 key 缓存）
    final key = 'lobby_${DateTime.now().millisecondsSinceEpoch}';

    LogService.d(
      '[NakamaSocketManager] 建立 WebSocket 连接: $host:$port (key=$key)',
    );

    _socket = NakamaWebsocketClient.init(
      key: key,
      host: host,
      port: port,
      ssl: ssl,
      token: token,
      onDone: _handleDisconnect,
      onError: (error) {
        LogService.e('[NakamaSocketManager] WebSocket 错误: $error');
      },
    );

    _isConnected = true;

    // 监听 onMatchData，仅处理 OpCode 1
    await _matchDataSubscription?.cancel();
    _matchDataSubscription = _socket!.onMatchData.listen(
      _handleMatchData,
      onError: (error) {
        LogService.e('[NakamaSocketManager] onMatchData 错误: $error');
      },
      onDone: () {
        LogService.w('[NakamaSocketManager] onMatchData 流已关闭');
      },
    );

    // 同时监听 onMatchPresence 用于调试（确认 WebSocket 是否正常工作）
    await _matchPresenceSubscription?.cancel();
    _matchPresenceSubscription = _socket!.onMatchPresence.listen(
      (event) {
        LogService.d(
          '[NakamaSocketManager] 收到 MatchPresence: '
          'joins=${event.joins.length}, leaves=${event.leaves.length}',
        );
      },
      onError: (error) {
        LogService.e('[NakamaSocketManager] onMatchPresence 错误: $error');
      },
    );

    LogService.i('[NakamaSocketManager] WebSocket 已连接，onMatchData 监听器已设置');
  }

  /// 断开 WebSocket 连接
  Future<void> disconnect() async {
    LogService.d('[NakamaSocketManager] 断开 WebSocket 连接');
    _isConnected = false;
    _stopAppHeartbeat(); // C4：停止心跳
    await _matchDataSubscription?.cancel();
    _matchDataSubscription = null;
    await _matchPresenceSubscription?.cancel();
    _matchPresenceSubscription = null;

    final socket = _socket;
    _socket = null;
    _currentMatchId = null;

    if (socket != null) {
      try {
        await socket.close();
      } catch (e) {
        LogService.w('[NakamaSocketManager] 关闭 WebSocket 异常: $e');
      }
    }
  }

  /// 加入 Match
  Future<Match> joinMatch(String matchId) async {
    final socket = _socket;
    if (socket == null) {
      throw StateError('[NakamaSocketManager] WebSocket 未连接');
    }

    LogService.d('[NakamaSocketManager] 加入 Match: $matchId');
    final match = await socket.joinMatch(matchId);
    _currentMatchId = matchId;
    // C4：加入 Match 后启动应用层心跳，维持链路活性
    _startAppHeartbeat();
    LogService.i(
      '[NakamaSocketManager] 已加入 Match: $matchId, presences=${match.presences.length}',
    );
    return match;
  }

  /// 离开当前 Match
  Future<void> leaveMatch() async {
    final socket = _socket;
    final matchId = _currentMatchId;
    if (socket == null || matchId == null) return;

    LogService.d('[NakamaSocketManager] 离开 Match: $matchId');
    try {
      await socket.leaveMatch(matchId);
    } catch (e) {
      LogService.w('[NakamaSocketManager] 离开 Match 异常: $e');
    }
    _currentMatchId = null;
  }

  /// 发送 Envelope 消息（OpCode 1）
  void sendEnvelope(pb.LobbyEnvelope envelope) {
    final socket = _socket;
    final matchId = _currentMatchId;
    if (socket == null || matchId == null || !_isConnected) {
      LogService.w(
        '[NakamaSocketManager] 未连接或未加入 Match，忽略发送: ${envelope.type} '
        '(socket=${socket != null}, matchId=$matchId, isConnected=$_isConnected)',
      );
      return;
    }

    try {
      final bytes = envelope.writeToBuffer();
      LogService.d(
        '[NakamaSocketManager] 发送消息: ${envelope.type}, '
        'matchId=$matchId, bytes=${bytes.length}',
      );
      socket.sendMatchData(matchId: matchId, opCode: 1, data: bytes);
      LogService.d('[NakamaSocketManager] 已发送消息: ${envelope.type}');
    } catch (e) {
      LogService.e('[NakamaSocketManager] 发送消息失败: ${envelope.type}', e);
    }
  }

  /// Match 消息流（已解码为 LobbyWsEvent，仅 OpCode 1）
  Stream<LobbyWsEvent> get onMatchEvent => _matchEventController.stream;

  /// 断开连接事件流
  Stream<void> get onDisconnect => _disconnectController.stream;

  /// 当前是否已连接
  bool get isConnected => _isConnected;

  /// 当前 matchId
  String? get currentMatchId => _currentMatchId;

  /// 处理 onMatchData 消息
  void _handleMatchData(MatchData matchData) {
    final rawBytes = matchData.data;

    // C1：热路径日志优化。
    // 旧实现无条件构造 rawHex 字符串（.take().map().join()），即便 release 模式
    // LogService.d 内部丢弃日志，参数仍被 eager 求值——200 人高峰每秒几十条消息，
    // 这是主 isolate 的隐性开销之一。仅在 debug 模式下构造昂贵日志。
    if (kDebugMode) {
      LogService.d(
        '[NakamaSocketManager][RAW] 收到 MatchData: '
        'opCode=${matchData.opCode}, '
        'matchId=${matchData.matchId}, '
        'presence=${matchData.presence?.userId}, '
        'dataLength=${rawBytes?.length ?? 0}',
      );
    }

    // 仅处理 OpCode 1
    if (matchData.opCode != 1) {
      return;
    }

    final data = rawBytes;
    if (data == null || data.isEmpty) {
      LogService.w('[NakamaSocketManager] 收到空数据的 OpCode 1 消息');
      return;
    }

    final wsEvent = LobbyEnvelopeParser.fromBytes(data);
    if (wsEvent == null) {
      if (kDebugMode) {
        LogService.w(
          '[NakamaSocketManager] Protobuf 反序列化失败，跳过 (${data.length} bytes)',
        );
      }
      return;
    }

    if (kDebugMode) {
      LogService.d('[NakamaSocketManager] 收到消息: ${wsEvent.type}');
    }
    _matchEventController.add(wsEvent);
  }

  /// 处理 WebSocket 断开
  void _handleDisconnect() {
    LogService.w('[NakamaSocketManager] WebSocket 已断开');
    _isConnected = false;
    _currentMatchId = null;
    // SDK 已在底层关闭连接，主动清空引用，避免后续误判 _socket != null
    // 仍持有有效连接（典型场景：服务端主动断开后客户端重连）。
    _socket = null;
    _disconnectController.add(null);
  }

  /// 释放资源
  Future<void> dispose() async {
    await _matchDataSubscription?.cancel();
    _matchDataSubscription = null;
    await _matchPresenceSubscription?.cancel();
    _matchPresenceSubscription = null;
    await disconnect();
    await _matchEventController.close();
    await _disconnectController.close();
  }
}

// ---------------------------------------------------------------------------
// Task 4.3: LobbyNakamaService — 生命周期与连接管理
// Task 4.4: 消息发送方法
// Task 4.5: 本地设置与状态属性
// Task 4.6: 传送门流程
// ---------------------------------------------------------------------------

/// 大厅 Nakama 服务
///
/// 替换 `LobbyWsService`，封装所有 Nakama SDK 交互逻辑。
/// 单例模式，生命周期跟随应用。
class LobbyNakamaService {
  LobbyNakamaService._() {
    // 注册 AuthService 登录状态监听器
    AuthService.instance.addLoginStateListener(_onAuthStateChanged);
  }

  static final LobbyNakamaService instance = LobbyNakamaService._();

  // === 内部管理器 ===
  final _clientManager = _NakamaClientManager();
  final _socketManager = _NakamaSocketManager();

  // === 存储 Key 常量（与 LobbyWsService 一致）===
  static const String keySelectedSpriteId = 'lobby_selected_sprite_id';
  static const String keyAnonymousMode = 'lobby_anonymous_mode';
  static const String keyChatOpacity = 'lobby_chat_opacity';
  static const String keyShowNameplates = 'lobby_show_nameplates';
  static const String keyShowChatBubbles = 'lobby_show_chat_bubbles';
  static const String keyUseSteamName = 'lobby_use_steam_name';

  // === 事件流 ===
  final StreamController<LobbyWsEvent> _eventController =
      StreamController<LobbyWsEvent>.broadcast();

  /// 最新的 snapshot 消息，用于新订阅者时重发
  LobbyServerEvent? _latestSnapshot;

  /// 缓存的 events stream（用于支持 snapshot 重发）
  Stream<LobbyWsEvent>? _cachedEventsStream;

  // === 连接状态 ===
  bool _isConnected = false;
  bool _isReconnecting = false;
  bool _isDisposed = false;
  bool _isKicked = false;
  bool _hasAssetsReceived = false;
  pb.AssetsResponse? _latestAssetsPayload;
  String? _deviceId;

  // === 重连 ===
  int _reconnectDelaySeconds = 2;
  static const int _maxReconnectDelaySeconds = 30;
  Timer? _reconnectTimer;

  // === C3 重连风暴熔断 ===
  // 连续失败次数；达到 _circuitBreakerThreshold 后把退避上限临时拉高到
  // _circuitBreakerMaxDelaySeconds，避免大批客户端在服务端高负载时同步高频重连
  // 形成二次雪崩。成功连接后清零。
  int _consecutiveFailures = 0;
  static const int _circuitBreakerThreshold = 8;
  static const int _circuitBreakerMaxDelaySeconds = 120;
  final Random _reconnectRandom = Random();

  // === S3 重连增量恢复 ===
  // 记录最近一次收到的 presence.delta / snapshot 的 seq。重连后 requestSnapshot
  // 携带该值，服务端可只回增量。断连时不清零（保留以便续接）；
  // 收到全量 snapshot(is_resume=false) 时更新为其 delta_seq。
  int _lastDeltaSeq = 0;

  // === Session 主动刷新 ===
  Timer? _sessionRefreshTimer;

  // === 流订阅 ===
  StreamSubscription<LobbyWsEvent>? _matchEventSubscription;
  StreamSubscription<void>? _disconnectSubscription;

  // === 传送门 ===

  /// 标记本次 joinMatch 是否由传送门触发（传送到达时跳过 enter，直接请求 snapshot）
  bool _isTeleportArrival = false;

  /// 标记是否已发送 enter（用于 login.success 后判断是否需要补发 enter）
  bool _hasEnteredLobby = false;

  /// 标记是否已发送 login 但尚未收到响应（防止前厅内重复发送 login）
  bool _isLoginPending = false;

  // =========================================================================
  // 事件流（与现有接口一致）
  // =========================================================================

  /// WebSocket 事件流，支持新订阅者获取最新的 snapshot
  Stream<LobbyWsEvent> get events {
    final latest = _latestSnapshot;
    if (latest != null) {
      _cachedEventsStream ??= Stream<LobbyWsEvent>.multi((controller) {
        controller.add(latest);
        final subscription = _eventController.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        // 外部订阅者取消时，同步取消内部订阅，避免悬空 listener 累积
        controller.onCancel = () {
          subscription.cancel();
        };
      }, isBroadcast: true);
      return _cachedEventsStream!;
    }
    return _eventController.stream;
  }

  /// 清除缓存的 events stream（snapshot 改变时调用）
  void _clearCachedEventsStream() {
    _cachedEventsStream = null;
  }

  // =========================================================================
  // 状态属性（Task 4.5）
  // =========================================================================

  /// WebSocket 连接状态
  bool get isConnected => _isConnected;

  /// 是否有有效的认证令牌
  bool get hasValidToken => TokenService.instance.isTokenValid;

  /// 是否处于被踢状态
  bool get isKicked => _isKicked;

  /// Assets 是否已到达
  bool get hasAssetsReceived => _hasAssetsReceived;

  /// 是否已发送 enter（已正式进入大厅）
  bool get hasEnteredLobby => _hasEnteredLobby;

  /// 是否正在等待 login 响应（前厅内 login 已发但未收到 login.success/failed）
  bool get isLoginPending => _isLoginPending;

  /// 获取最新的 assets payload
  pb.AssetsResponse? getLastAssetsPayload() => _latestAssetsPayload;

  /// 重置被踢状态
  void resetKicked() {
    _isKicked = false;
    LogService.i('[LobbyNakamaService] 被踢状态已重置');
  }

  // =========================================================================
  // AuthService 登录状态监听（Task 4.5）
  // =========================================================================

  /// AuthService 登录状态监听器回调
  void _onAuthStateChanged(bool isLoggedIn) {
    if (_isDisposed) return;

    if (!isLoggedIn) {
      LogService.i('[LobbyNakamaService] 检测到用户登出，发送 logout 事件');
      unawaited(logout(force: false));
    } else if (_isConnected && hasValidToken) {
      // 已连接且已进入大厅（_hasEnteredLobby=true）：大厅内 login，直接发送
      // 还在前厅（_hasEnteredLobby=false）：join.success 流程会处理，此处不重复发送
      if (_hasEnteredLobby) {
        LogService.i(
          '[LobbyNakamaService] 检测到用户登录（已连接，已进入大厅），发送 login 事件（匿名=${loadAnonymousMode()}）',
        );
        unawaited(login());
      } else {
        LogService.d(
          '[LobbyNakamaService] 检测到用户登录（已连接，前厅中），等待 join.success 流程处理',
        );
      }
    }
  }

  // =========================================================================
  // 生命周期（Task 4.3）
  // =========================================================================

  /// 当前设备类型标识
  String get _deviceType => PlatformUtils.isMobile ? 'mobile' : 'pc';

  /// 是否正在执行初始化连接流程
  bool _isInitializing = false;

  /// 初始化并连接（幂等操作）
  ///
  /// 流程：认证 → WebSocket 连接 → RPC 获取 matchId → joinMatch → 等待 join.success
  Future<void> initialize() async {
    if (_isDisposed) return;
    if (_isConnected || _isReconnecting || _isInitializing) return;

    _isInitializing = true;
    _isReconnecting = false;
    _reconnectDelaySeconds = 2;

    try {
      // 等待 token 有效后再连接
      await _waitForTokenReady();

      // 获取 deviceId
      await _ensureDeviceIdReady();

      await _doConnect();
    } finally {
      _isInitializing = false;
    }
  }

  /// 强制重新连接（被踢后使用）
  Future<void> forceReconnect() async {
    if (_isDisposed) return;
    LogService.i('[LobbyNakamaService] forceReconnect: 清理旧连接并重新连接');

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _sessionRefreshTimer?.cancel();
    _sessionRefreshTimer = null;

    // 清理旧连接
    await _matchEventSubscription?.cancel();
    _matchEventSubscription = null;
    await _disconnectSubscription?.cancel();
    _disconnectSubscription = null;
    await _socketManager.disconnect();

    _isConnected = false;
    _isReconnecting = false;
    _latestSnapshot = null;
    _latestAssetsPayload = null;
    _hasAssetsReceived = false;
    _isTeleportArrival = false;
    _hasEnteredLobby = false;
    _isLoginPending = false;
    _clearCachedEventsStream();
    _reconnectDelaySeconds = 2;
    _consecutiveFailures = 0; // C3：强制重连重置熔断计数
    // S3：forceReconnect 通常伴随本地用户列表被清空（如被踢后重连），
    // 必须重置 seq，确保重连后请求全量快照而非增量（否则会合并到空列表造成缺人）。
    _lastDeltaSeq = 0;

    await _waitForTokenReady();
    await _ensureDeviceIdReady();
    await _doConnect();
  }

  /// 释放资源
  Future<void> dispose() async {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _sessionRefreshTimer?.cancel();
    _sessionRefreshTimer = null;

    await _matchEventSubscription?.cancel();
    _matchEventSubscription = null;
    await _disconnectSubscription?.cancel();
    _disconnectSubscription = null;

    await _socketManager.dispose();

    _isConnected = false;
    _isReconnecting = false;

    // 移除 AuthService 登录状态监听器
    AuthService.instance.removeLoginStateListener(_onAuthStateChanged);
  }

  /// 等待 token 有效（最多 30 秒）
  Future<void> _waitForTokenReady() async {
    if (!AuthService.instance.isLoggedIn) {
      LogService.d('[LobbyNakamaService] 用户未登录，将以匿名身份连接');
      return;
    }

    final start = DateTime.now();
    const maxWait = Duration(seconds: 30);
    const interval = Duration(milliseconds: 200);

    while (!TokenService.instance.isTokenValid) {
      if (DateTime.now().difference(start) >= maxWait) {
        LogService.w('[LobbyNakamaService] 等待 token 超时，将以匿名身份连接');
        break;
      }
      await Future.delayed(interval);
    }

    if (TokenService.instance.isTokenValid) {
      LogService.d('[LobbyNakamaService] Token 已就绪');
    }
  }

  /// 等待 deviceId 准备就绪
  Future<void> _ensureDeviceIdReady() async {
    if (_deviceId != null) return;

    try {
      _deviceId = await DeviceIdHelper.getDeviceId();
      LogService.d('[LobbyNakamaService] deviceId 已就绪');
    } catch (e) {
      LogService.e('[LobbyNakamaService] 获取 deviceId 失败: $e');
      _deviceId ??= const Uuid().v4();
    }
  }

  /// 执行实际的连接流程
  Future<void> _doConnect() async {
    final config = NakamaConfig.fromEnv();

    try {
      // 1. 初始化客户端
      _clientManager.init(config);

      // 2. 认证
      final jwtToken =
          (AuthService.instance.isLoggedIn &&
              TokenService.instance.isTokenValid)
          ? TokenService.instance.token
          : null;

      await _clientManager.authenticate(
        jwtToken: jwtToken,
        deviceId: _deviceId!,
      );

      // 2.1. 启动 Session 主动刷新定时器
      _scheduleSessionRefresh();

      // 3. WebSocket 连接
      await _socketManager.connect(
        host: config.host,
        port: config.port,
        ssl: config.ssl,
        token: _clientManager.token!,
      );

      // 4. 监听 Match 消息和断开事件（在 joinMatch 之前设置，确保不丢失消息）
      _setupStreamListeners();

      // 5. RPC lobby_join 获取 matchId 或排队令牌（服务端自动分配地图）
      //    成功（加入 Match 或进入排队）返回 true；失败已在内部安排重连。
      await _attemptLobbyJoin();
    } catch (e, stackTrace) {
      LogService.e('[LobbyNakamaService] 连接失败', e, stackTrace);
      _emitConnectionEvent(LobbyConnectionEventType.error, error: e.toString());
      _isConnected = false;
      _sessionRefreshTimer?.cancel();
      _sessionRefreshTimer = null;
      _scheduleReconnect();
    }
  }

  /// 执行 RPC lobby_join 并根据响应加入 Match 或进入排队
  ///
  /// 抽离自 [_doConnect]，使排队过期 / 完成后能够在已建立的 WebSocket 连接上
  /// 重新发起 lobby_join（无需重连），由 [rejoinLobby] 复用。
  ///
  /// 返回 true 表示成功（加入 Match 或进入排队）；返回 false 表示失败，
  /// 失败时已发送 error 事件并安排重连。
  Future<bool> _attemptLobbyJoin() async {
    final joinResponse = await _rpcLobbyJoin();
    if (joinResponse == null) {
      LogService.e('[LobbyNakamaService] RPC lobby_join 获取响应失败');
      _emitConnectionEvent(
        LobbyConnectionEventType.error,
        error: '获取 matchId 失败',
      );
      _sessionRefreshTimer?.cancel();
      _sessionRefreshTimer = null;
      _scheduleReconnect();
      return false;
    }

    // 判断是立即进入还是排队
    if (joinResponse.matchId.isNotEmpty) {
      // 立即通过，走原有流程
      final matchId = joinResponse.matchId;

      // 加入 Match
      await _socketManager.joinMatch(matchId);

      // 只有在 joinMatch 成功后才标记为已连接并发送 connected 事件
      _isConnected = true;
      _consecutiveFailures = 0; // C3：连接成功，重置熔断计数
      _reconnectDelaySeconds = 2; // 退避重置
      _emitConnectionEvent(LobbyConnectionEventType.connected);

      LogService.i(
        '[LobbyNakamaService] lobby_join 完成，已加入 Match: $matchId，等待 join.success',
      );
      return true;
    } else if (joinResponse.ticket.isNotEmpty) {
      // 进入排队，通知 Bloc 显示排队 UI
      _isConnected = true;
      _consecutiveFailures = 0; // C3：连接成功，重置熔断计数
      _reconnectDelaySeconds = 2;
      _emitConnectionEvent(LobbyConnectionEventType.connected);

      // 发送排队事件给 Bloc
      _eventController.add(
        LobbyServerEvent(
          type: 'queue.started',
          timestamp: DateTime.now(),
          traceId: '',
          envelope: pb.LobbyEnvelope()..type = 'queue.started',
          queueTicket: joinResponse.ticket,
          queuePosition: joinResponse.position,
          queueTotal: joinResponse.queueTotal,
          queueEtaSeconds: joinResponse.etaSeconds,
          queuePollIntervalMs: joinResponse.pollIntervalMs,
        ),
      );

      LogService.i(
        '[LobbyNakamaService] 进入排队: ticket=${joinResponse.ticket}, position=${joinResponse.position}/${joinResponse.queueTotal}',
      );
      return true;
    } else {
      LogService.e(
        '[LobbyNakamaService] RPC lobby_join 返回无效响应（matchId 和 ticket 均为空）',
      );
      _emitConnectionEvent(
        LobbyConnectionEventType.error,
        error: '获取 matchId 失败',
      );
      _sessionRefreshTimer?.cancel();
      _sessionRefreshTimer = null;
      _scheduleReconnect();
      return false;
    }
  }

  /// 在已建立的 WebSocket 连接上重新发起 lobby_join
  ///
  /// 用于排队过期 / 取消后的重试：此时 WebSocket 仍然连接（_isConnected=true），
  /// 但尚未加入任何 Match，因此不能走 [initialize]（会被幂等检查拦截），
  /// 也不能直接发送 assets/snapshot 请求（会因未加入 Match 被丢弃）。
  ///
  /// 若 WebSocket 已断开，则回退到完整的 [initialize] 流程。
  Future<void> rejoinLobby() async {
    if (_isDisposed) return;

    // WebSocket 未连接：走完整初始化（含认证 + 连接 + lobby_join）
    if (!_isConnected) {
      LogService.i('[LobbyNakamaService] rejoinLobby: WebSocket 未连接，走完整初始化');
      await initialize();
      return;
    }

    // 已经在某个 Match 中：无需重新 join，避免重复加入
    if (_socketManager.currentMatchId != null) {
      LogService.d('[LobbyNakamaService] rejoinLobby: 已在 Match 中，跳过重新 join');
      return;
    }

    LogService.i('[LobbyNakamaService] rejoinLobby: 在已有连接上重新发起 lobby_join');
    try {
      await _attemptLobbyJoin();
    } catch (e, stackTrace) {
      LogService.e('[LobbyNakamaService] rejoinLobby 失败', e, stackTrace);
      _emitConnectionEvent(LobbyConnectionEventType.error, error: e.toString());
      _scheduleReconnect();
    }
  }

  /// 是否已加入某个 Match（排队中尚未加入时为 false）
  bool get isInMatch => _socketManager.currentMatchId != null;

  /// 设置流监听器
  void _setupStreamListeners() {
    // 监听 Match 消息
    _matchEventSubscription?.cancel();
    _matchEventSubscription = _socketManager.onMatchEvent.listen(
      _handleMatchEvent,
      onError: (error) {
        LogService.e('[LobbyNakamaService] Match 事件流错误: $error');
      },
    );

    // 监听断开事件
    _disconnectSubscription?.cancel();
    _disconnectSubscription = _socketManager.onDisconnect.listen(
      (_) => _handleDisconnect(),
      onError: (error) {
        LogService.e('[LobbyNakamaService] 断开事件流错误: $error');
      },
    );
  }

  /// 处理 Match 消息事件
  void _handleMatchEvent(LobbyWsEvent wsEvent) {
    if (_isDisposed || _eventController.isClosed) return;

    // 只处理 LobbyServerEvent（由 _NakamaSocketManager 通过 envelope.toLobbyServerEvent() 构造）
    if (wsEvent is! LobbyServerEvent) return;

    LogService.d('[LobbyNakamaService] 收到消息: ${wsEvent.type}');

    // 收到 join.success 后按两阶段进入协议处理：
    // - 传送到达：服务端已跳过前厅，直接发送 snapshot.request
    // - 普通进入：[可选 login] → enter → snapshot.request
    if (wsEvent.type == 'join.success') {
      LogService.i('[LobbyNakamaService] 收到 join.success，开始初始化场景');
      _hasEnteredLobby = false;
      _isLoginPending = false;

      if (_isTeleportArrival) {
        // 传送到达：服务端自动跳过前厅，无需发送 enter
        _isTeleportArrival = false;
        _hasEnteredLobby = true; // 视为已进入大厅
        LogService.d('[LobbyNakamaService] 传送到达，跳过 enter，直接请求 snapshot');
        unawaited(requestSnapshot());
      } else if (AuthService.instance.isLoggedIn && hasValidToken) {
        // 已登录：先发 login（携带匿名标志），等待 login.success 后再发 enter + snapshot.request
        LogService.d(
          '[LobbyNakamaService] 用户已登录，发送 login（匿名=${loadAnonymousMode()}），等待 login.success 后发 enter',
        );
        _isLoginPending = true;
        unawaited(login());
      } else {
        // 匿名用户或未登录：直接发 enter，然后请求 snapshot
        LogService.d('[LobbyNakamaService] 匿名用户，发送 enter 进入大厅');
        unawaited(sendEnter());
        unawaited(requestSnapshot());
      }
    }

    // 收到 login.success 后，若尚未发送 enter（前厅内 login），补发 enter + snapshot.request
    if (wsEvent.type == 'login.success') {
      _isLoginPending = false;
      if (!_hasEnteredLobby) {
        LogService.i(
          '[LobbyNakamaService] 收到 login.success（前厅内），发送 enter 进入大厅',
        );
        unawaited(sendEnter());
        unawaited(requestSnapshot());
      }
    }

    // login.failed：前厅内登录失败，以匿名身份继续进入大厅
    if (wsEvent.type == 'login.failed') {
      _isLoginPending = false;
      if (!_hasEnteredLobby) {
        LogService.w(
          '[LobbyNakamaService] 收到 login.failed（前厅内），以匿名身份发送 enter 进入大厅',
        );
        unawaited(sendEnter());
        unawaited(requestSnapshot());
      }
    }

    // 收到 assets 后标记
    if (wsEvent.type == 'assets') {
      _hasAssetsReceived = true;
      _latestAssetsPayload = wsEvent.envelope.assetsResponse;
    }

    // 收到 system.kicked 后标记，禁止自动重连
    if (wsEvent.type == 'system.kicked') {
      _isKicked = true;
      LogService.w('[LobbyNakamaService] 收到 system.kicked，已禁止自动重连');
    }

    // 缓存最新的 snapshot
    if (wsEvent.type == 'snapshot') {
      _latestSnapshot = wsEvent;
      _clearCachedEventsStream();
      // S3：记录服务端返回的 delta_seq，供下次重连续接增量
      try {
        final snap = wsEvent.envelope.snapshotResponse;
        if (snap.deltaSeq.toInt() > 0) {
          _lastDeltaSeq = snap.deltaSeq.toInt();
        }
      } catch (_) {}
    }

    // S3：记录 presence.delta 的 seq（增量帧持续推进 lastDeltaSeq）
    if (wsEvent.type == 'presence.delta') {
      try {
        final delta = wsEvent.envelope.presenceDeltaResponse;
        final seq = delta.seq.toInt();
        if (seq > _lastDeltaSeq) {
          _lastDeltaSeq = seq;
        }
      } catch (_) {}
    }

    // 先将事件分发给 Bloc 层
    _eventController.add(wsEvent);

    // 传送门流程：收到 portal.teleport 后执行传送（Task 4.6）
    if (wsEvent.type == 'portal.teleport') {
      _handlePortalTeleport(wsEvent.envelope.portalTeleportResponse);
    }
  }

  /// 处理 WebSocket 断开
  void _handleDisconnect() {
    LogService.w('[LobbyNakamaService] WebSocket 已断开');
    _isConnected = false;
    _sessionRefreshTimer?.cancel();
    _sessionRefreshTimer = null;
    _latestSnapshot = null;
    _latestAssetsPayload = null;
    _hasAssetsReceived = false;
    _isTeleportArrival = false;
    _hasEnteredLobby = false;
    _isLoginPending = false;
    _clearCachedEventsStream();

    _emitConnectionEvent(LobbyConnectionEventType.closed);

    if (!_isKicked) {
      _scheduleReconnect();
    } else {
      LogService.w('[LobbyNakamaService] 被踢出状态，跳过自动重连');
    }
  }

  /// 调度重连（指数退避 + C3 随机抖动 + 熔断）
  void _scheduleReconnect() {
    if (_isDisposed) return;
    if (_isReconnecting) return;
    _isReconnecting = true;

    // C3：计算带抖动的实际延迟。
    // 基础退避 = _reconnectDelaySeconds；熔断触发后上限临时抬高，避免羊群同步重连。
    final int baseDelay = _consecutiveFailures >= _circuitBreakerThreshold
        ? _reconnectDelaySeconds.clamp(2, _circuitBreakerMaxDelaySeconds)
        : _reconnectDelaySeconds;
    // ±30% 抖动，打散大批客户端的同步重连节拍
    final double jitterFactor = 1.0 + (_reconnectRandom.nextDouble() * 0.6 - 0.3);
    final int effectiveDelay = (baseDelay * jitterFactor)
        .round()
        .clamp(1, _circuitBreakerMaxDelaySeconds);

    if (_consecutiveFailures >= _circuitBreakerThreshold) {
      LogService.w(
        '[LobbyNakamaService] 连续失败 $_consecutiveFailures 次，熔断降频重连，'
        '将在 $effectiveDelay 秒后重试（服务器繁忙）',
      );
    } else {
      LogService.w('[LobbyNakamaService] 将在 $effectiveDelay 秒后尝试重连...');
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      Duration(seconds: effectiveDelay),
      () async {
        _isReconnecting = false;
        _consecutiveFailures++; // C3：记一次重连尝试（成功后会清零）
        // 退避翻倍：熔断态用更高上限，否则用常规上限
        final int cap = _consecutiveFailures >= _circuitBreakerThreshold
            ? _circuitBreakerMaxDelaySeconds
            : _maxReconnectDelaySeconds;
        _reconnectDelaySeconds = (_reconnectDelaySeconds * 2).clamp(2, cap);

        // 重连时检查 Session 是否过期，过期则先刷新
        if (_clientManager.session != null &&
            _clientManager.session!.isExpired) {
          LogService.d('[LobbyNakamaService] Session 已过期，先刷新再重连');
          try {
            final jwtToken =
                (AuthService.instance.isLoggedIn &&
                    TokenService.instance.isTokenValid)
                ? TokenService.instance.token
                : null;
            await _clientManager.refreshSession(
              jwtToken: jwtToken,
              deviceId: _deviceId!,
            );
          } catch (e) {
            LogService.e('[LobbyNakamaService] Session 刷新失败: $e');
          }
        }

        // 清理旧的流订阅
        await _matchEventSubscription?.cancel();
        _matchEventSubscription = null;
        await _disconnectSubscription?.cancel();
        _disconnectSubscription = null;

        // 关键修复：重连前先断开旧的 WebSocket 连接，避免在服务端累积大量僵尸连接。
        // _doConnect() 会重新调用 _socketManager.connect() 建立新连接，
        // 若不先 disconnect，旧的 socket 仍保持打开状态，重试机制会持续创建新连接。
        await _socketManager.disconnect();

        await _doConnect();
      },
    );
  }

  /// 计算重连延迟（纯函数，用于属性测试）
  static int calculateReconnectDelay(int retryCount) {
    // delay = min(2 * 2^n, 30)
    final delay = 2 * (1 << retryCount.clamp(0, 30));
    return delay.clamp(2, 30);
  }

  /// 调度 Session 主动刷新定时器
  ///
  /// 在 Session 过期前主动刷新，避免 RPC 调用时才发现过期。
  /// 刷新时机 = Session 有效期的 75% 处（例如有效期 300 秒，则 225 秒后刷新）。
  /// 最少 30 秒后刷新，避免频繁刷新。
  void _scheduleSessionRefresh() {
    _sessionRefreshTimer?.cancel();
    _sessionRefreshTimer = null;

    final session = _clientManager.session;
    if (session == null) return;

    final now = DateTime.now();
    final expiresAt = session.expiresAt;
    final remainingSeconds = expiresAt.difference(now).inSeconds;

    if (remainingSeconds <= 0) {
      // 已过期，立即刷新
      LogService.w('[LobbyNakamaService] Session 已过期，立即刷新');
      unawaited(_doSessionRefresh());
      return;
    }

    // 在有效期的 75% 处刷新，最少 30 秒
    final refreshAfterSeconds = (remainingSeconds * 0.75).toInt().clamp(
      30,
      remainingSeconds - 10,
    );

    LogService.d(
      '[LobbyNakamaService] Session 剩余 ${remainingSeconds}s，'
      '将在 ${refreshAfterSeconds}s 后主动刷新',
    );

    _sessionRefreshTimer = Timer(Duration(seconds: refreshAfterSeconds), () {
      if (_isDisposed || !_isConnected) return;
      unawaited(_doSessionRefresh());
    });
  }

  /// 执行 Session 刷新并重新调度定时器
  Future<void> _doSessionRefresh() async {
    if (_isDisposed) return;
    final deviceId = _deviceId;
    if (deviceId == null) return;

    try {
      LogService.d('[LobbyNakamaService] 主动刷新 Session...');
      await _clientManager.refreshSession(deviceId: deviceId);
      LogService.i('[LobbyNakamaService] Session 主动刷新成功');
      // 刷新成功后重新调度下一次刷新
      _scheduleSessionRefresh();
    } catch (e) {
      LogService.e('[LobbyNakamaService] Session 主动刷新失败: $e');
      // 失败后 60 秒重试
      _sessionRefreshTimer?.cancel();
      _sessionRefreshTimer = Timer(const Duration(seconds: 60), () {
        if (_isDisposed || !_isConnected) return;
        unawaited(_doSessionRefresh());
      });
    }
  }

  /// 协议能力声明位掩码
  /// bit0 (0x01) = 支持 presence.delta 帧
  /// bit1 (0x02) = 支持排队协议
  /// bit2 (0x04) = 支持重连增量恢复（S3：snapshot.request 携带 lastDeltaSeq）
  static const int protocolFeatures = 0x07;

  /// RPC 调用 lobby_join 获取 Match ID 或排队令牌（带重试）
  ///
  /// 文档协议：调用 RPC "lobby_join"，携带 LobbyJoinRequest { deviceType, protocolFeatures } 的 Protobuf 编码。
  /// 服务端自动分配地图（老用户恢复上次地图，新用户进入默认地图）。
  /// 返回 Protobuf 序列化的 LobbyJoinResponse：
  ///   - matchId 非空 = 立即可进入
  ///   - matchId 为空 + ticket 非空 = 进入排队
  Future<pb.LobbyJoinResponse?> _rpcLobbyJoin() async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    // 构造 LobbyJoinRequest，携带 deviceType 和 protocolFeatures
    final reqBytes =
        (pb.LobbyJoinRequest()
              ..deviceType = _deviceType
              ..protocolFeatures = protocolFeatures)
            .writeToBuffer();
    // 服务端期望原始 Protobuf 二进制字节转成字符串
    final payload = String.fromCharCodes(reqBytes);

    for (var i = 0; i < maxRetries; i++) {
      try {
        final result = await _clientManager.rpc('lobby_join', payload: payload);
        LogService.d(
          '[LobbyNakamaService] RPC lobby_join 返回: (length=${result?.length}, isNull=${result == null}, isEmpty=${result?.isEmpty})',
        );

        if (result != null && result.isNotEmpty) {
          try {
            final bytes = result.codeUnits;
            final response = pb.LobbyJoinResponse.fromBuffer(bytes);
            final matchId = response.matchId;
            final mapId = response.mapId;
            final ticket = response.ticket;
            LogService.d(
              '[LobbyNakamaService] Protobuf 解析成功: matchId="$matchId", mapId="$mapId", ticket="$ticket"',
            );
            if (matchId.isNotEmpty || ticket.isNotEmpty) {
              return response;
            } else {
              LogService.w(
                '[LobbyNakamaService] Protobuf 解析成功但 matchId 和 ticket 均为空',
              );
            }
          } catch (e) {
            LogService.e('[LobbyNakamaService] Protobuf 解析失败: $e', e);
          }
        } else {
          LogService.w('[LobbyNakamaService] RPC lobby_join 返回空值');
        }
      } catch (e) {
        LogService.w(
          '[LobbyNakamaService] RPC lobby_join 失败 '
          '(${i + 1}/$maxRetries): $e',
        );
        if (i < maxRetries - 1) {
          await Future.delayed(retryDelay);
        }
      }
    }

    return null;
  }

  /// RPC 调用 lobby_queue_status 查询排队状态
  Future<pb.QueueStatusResponse?> rpcQueueStatus(String ticket) async {
    try {
      final reqBytes = (pb.QueueStatusRequest()..ticket = ticket)
          .writeToBuffer();
      final payload = String.fromCharCodes(reqBytes);
      final result = await _clientManager.rpc(
        'lobby_queue_status',
        payload: payload,
      );
      if (result != null && result.isNotEmpty) {
        final bytes = result.codeUnits;
        return pb.QueueStatusResponse.fromBuffer(bytes);
      }
    } catch (e) {
      LogService.w('[LobbyNakamaService] RPC lobby_queue_status 失败: $e');
    }
    return null;
  }

  /// RPC 调用 lobby_queue_cancel 取消排队
  Future<void> rpcQueueCancel(String ticket) async {
    try {
      final reqBytes = (pb.QueueCancelRequest()..ticket = ticket)
          .writeToBuffer();
      final payload = String.fromCharCodes(reqBytes);
      await _clientManager.rpc('lobby_queue_cancel', payload: payload);
      LogService.i('[LobbyNakamaService] 排队已取消: ticket=$ticket');
    } catch (e) {
      LogService.w('[LobbyNakamaService] RPC lobby_queue_cancel 失败: $e');
    }
  }

  /// 排队完成后加入 Match（公开方法，供 Bloc 调用）
  Future<void> joinMatchById(String matchId) async {
    await _socketManager.joinMatch(matchId);
    _isConnected = true;
    LogService.i('[LobbyNakamaService] 排队完成，已加入 Match: $matchId');
  }

  /// 发送连接状态事件
  void _emitConnectionEvent(LobbyConnectionEventType status, {String? error}) {
    if (_isDisposed || _eventController.isClosed) return;
    _eventController.add(LobbyConnectionEvent(status: status, error: error));
  }

  /// 发送 Protobuf Envelope 消息的内部方法
  void _sendEnvelope(pb.LobbyEnvelope envelope) {
    _socketManager.sendEnvelope(envelope);
  }

  /// 生成 traceId
  String _generateTraceId() => '${DateTime.now().microsecondsSinceEpoch}';

  // =========================================================================
  // 消息发送方法（Task 4.4）- 使用 Protobuf 类型
  // =========================================================================

  /// 宣告正式进入大厅（两阶段进入协议第二步）
  ///
  /// 文档协议：joinMatch 成功并完成身份确认后，客户端必须发送此消息，
  /// 服务端才会将用户正式加入大厅并向其他人广播 presence.join。
  /// 传送到达时不需要发送（服务端自动跳过前厅）。
  Future<void> sendEnter() async {
    _hasEnteredLobby = true;
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'enter'
      ..traceId = _generateTraceId()
      ..enterRequest = (pb.EnterRequest()..protocolFeatures = protocolFeatures);
    _sendEnvelope(envelope);
    LogService.i(
      '[LobbyNakamaService] 已发送 enter（protocolFeatures=0x${protocolFeatures.toRadixString(16)}），正式进入大厅',
    );
  }

  /// 发送移动请求
  Future<void> sendMove(LobbyPosition position) async {
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'move.request'
      ..traceId = _generateTraceId()
      ..moveRequest = (pb.MoveRequest()
        ..targetX = position.x
        ..targetY = position.y);
    _sendEnvelope(envelope);
  }

  /// 发送聊天消息
  Future<void> sendChat(String content) async {
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'chat.send'
      ..traceId = _generateTraceId()
      ..chatSendRequest = (pb.ChatSendRequest()..content = content);
    _sendEnvelope(envelope);
  }

  /// 请求素材资源
  ///
  /// 文档协议：AssetsRequest 无参数，服务端返回所有地图配置和角色外观配置。
  Future<void> requestAssets() async {
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'assets.request'
      ..traceId = _generateTraceId()
      ..assetsRequest = pb.AssetsRequest();
    _sendEnvelope(envelope);
  }

  /// 请求快照
  ///
  /// [fullSync]=true：强制请求全量快照（lastDeltaSeq=0），用于需要整表对齐的场景
  ///   （分页加载、delta 异常对齐、身份变更后重拉、传送到达）。
  /// [fullSync]=false（默认）：携带 _lastDeltaSeq，允许服务端 S3 增量恢复，
  ///   用于断线重连后只补增量，降低解码压力。
  Future<void> requestSnapshot({bool fullSync = false}) async {
    final seq = fullSync ? 0 : _lastDeltaSeq;
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'snapshot.request'
      ..traceId = _generateTraceId()
      ..snapshotRequest = (pb.SnapshotRequest()..lastDeltaSeq = Int64(seq));
    _sendEnvelope(envelope);
  }

  /// 发送角色外观变更
  Future<void> sendSpriteChange(String spriteId) async {
    await StorageUtils.setString(keySelectedSpriteId, spriteId);
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'profile.sprite.change'
      ..traceId = _generateTraceId()
      ..profileSpriteChangeRequest = (pb.ProfileSpriteChangeRequest()
        ..spriteId = spriteId);
    _sendEnvelope(envelope);
  }

  /// 设置匿名状态
  Future<void> setAnonymous(bool value) async {
    await StorageUtils.setBool(keyAnonymousMode, value);
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'profile.anonymous.change'
      ..traceId = _generateTraceId()
      ..profileAnonymousChangeRequest = (pb.ProfileAnonymousChangeRequest()
        ..isAnonymous = value);
    _sendEnvelope(envelope);

    // 如果是关闭匿名模式，且启用了 Steam 名称，主动同步一次
    if (!value && loadUseSteamName()) {
      unawaited(_syncDisplayName());
    }
  }

  /// 更新状态文本
  Future<void> updateStatusText(String statusText) async {
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'profile.statusText.update'
      ..traceId = _generateTraceId()
      ..profileStatusTextUpdateRequest = (pb.ProfileStatusTextUpdateRequest()
        ..statusText = statusText);
    _sendEnvelope(envelope);
  }

  /// 请求使用传送门
  ///
  /// 文档协议：发送 portal.use { portalKey }，
  /// 成功后服务端返回 portal.teleport 并 MatchKick 断开连接。
  Future<void> usePortal(String portalKey) async {
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'portal.use'
      ..traceId = _generateTraceId()
      ..portalUseRequest = (pb.PortalUseRequest()..portalKey = portalKey);
    _sendEnvelope(envelope);
  }

  /// 发送全服广播消息
  Future<void> sendBroadcast(String content) async {
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'broadcast.send'
      ..traceId = _generateTraceId()
      ..broadcastSendRequest = (pb.BroadcastSendRequest()..content = content);
    _sendEnvelope(envelope);
  }

  /// 查询广播冷却状态
  Future<void> requestBroadcastCD() async {
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'broadcast.cd'
      ..traceId = _generateTraceId()
      ..broadcastCdRequest = pb.BroadcastCDRequest();
    _sendEnvelope(envelope);
  }

  /// 请求全服在线用户统计
  Future<void> requestOnlineStats({bool includeUsers = true}) async {
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'online.stats'
      ..traceId = _generateTraceId()
      ..onlineStatsRequest = (pb.OnlineStatsRequest()
        ..includeUsers = includeUsers);
    _sendEnvelope(envelope);
  }

  /// 发送登录消息
  Future<void> login() async {
    final token = TokenService.instance.token;
    if (token == null || token.isEmpty) {
      LogService.w('[LobbyNakamaService] 当前无可用 JWT Token，忽略 login 请求');
      return;
    }

    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'login'
      ..traceId = _generateTraceId()
      ..loginRequest = (pb.LoginRequest()
        ..token = token
        ..deviceType = _deviceType
        ..isAnonymous = loadAnonymousMode());
    _sendEnvelope(envelope);

    // 开启的情况才主动同步显示名称
    if (loadUseSteamName()) {
      unawaited(_syncDisplayName());
    }
  }

  /// 发送登出消息
  Future<void> logout({bool force = false}) async {
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'logout'
      ..traceId = _generateTraceId()
      ..logoutRequest = (pb.LogoutRequest()..force = force);
    _sendEnvelope(envelope);
  }

  /// 同步显示名称（Steam 名称）
  Future<void> _syncDisplayName() async {
    final useSteamName = loadUseSteamName();
    String steamName = '';
    if (useSteamName) {
      steamName = await SteamUserService().getCurrentUsername() ?? '';
    }
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'profile.displayName.update'
      ..traceId = _generateTraceId()
      ..profileDisplayNameUpdateRequest = (pb.ProfileDisplayNameUpdateRequest()
        ..customName = ''
        ..steamName = steamName);
    _sendEnvelope(envelope);
  }

  /// 更新显示名称
  ///
  /// 文档协议：优先级 customName > steamName > accountNickname。
  /// 匿名用户不可修改。
  Future<void> updateDisplayName({
    String customName = '',
    String steamName = '',
  }) async {
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'profile.displayName.update'
      ..traceId = _generateTraceId()
      ..profileDisplayNameUpdateRequest = (pb.ProfileDisplayNameUpdateRequest()
        ..customName = customName
        ..steamName = steamName);
    _sendEnvelope(envelope);
  }

  /// 绑定 Steam ID
  ///
  /// 文档协议：将 Steam 64位 ID 与当前账号绑定，同时可选更新 Steam 昵称。
  /// 必须是已登录的实名用户。
  void bindSteam({required String steamId64, String steamName = ''}) {
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'profile.steam.bind'
      ..traceId = _generateTraceId()
      ..profileSteamBindRequest = (pb.ProfileSteamBindRequest()
        ..steamId = steamId64
        ..steamName = steamName);
    _sendEnvelope(envelope);
  }

  /// RPC 查询 Steam 玩家信息
  ///
  /// 根据目标用户的 Nakama UUID 查询其论坛账号、游戏数据等信息。
  /// 服务端会自动查询该用户绑定的 Steam64 ID，无需客户端传递 Steam ID。
  Future<pb.SteamUserInfoResponse?> rpcSteamUserInfo(
    String nakamaUserId,
  ) async {
    try {
      LogService.d(
        '[LobbyNakamaService] RPC steam_user_info: userId=$nakamaUserId',
      );
      final reqBytes = (pb.SteamUserInfoRequest()..userId = nakamaUserId)
          .writeToBuffer();
      // 服务端期望原始 Protobuf 二进制字节转成字符串（与 lobby_join 一致）
      final payload = String.fromCharCodes(reqBytes);
      final result = await _clientManager.rpc(
        'steam_user_info',
        payload: payload,
      );
      if (result != null && result.isNotEmpty) {
        // 响应是 base64 编码的 proto 二进制，需要先 decode
        final bytes = base64Decode(result);
        return pb.SteamUserInfoResponse.fromBuffer(bytes);
      }
      return null;
    } catch (e) {
      LogService.e('[LobbyNakamaService] RPC steam_user_info 失败: $e');
      return null;
    }
  }

  /// RPC 查询玩家库存统计
  ///
  /// 根据目标用户的 Nakama UUID 查询其库存物品统计信息（皮肤、法术、弹幕等数量及总价值）。
  /// 服务端会自动查询该用户绑定的 Steam64 ID，无需客户端传递 Steam ID。
  Future<pb.InventoryStatsResponse?> rpcInventoryStats(
    String nakamaUserId,
  ) async {
    try {
      LogService.d(
        '[LobbyNakamaService] RPC inventory_stats: userId=$nakamaUserId',
      );
      final reqBytes = (pb.InventoryStatsRequest()..userId = nakamaUserId)
          .writeToBuffer();
      final payload = String.fromCharCodes(reqBytes);
      final result = await _clientManager.rpc(
        'inventory_stats',
        payload: payload,
      );
      if (result != null && result.isNotEmpty) {
        final bytes = base64Decode(result);
        return pb.InventoryStatsResponse.fromBuffer(bytes);
      }
      return null;
    } catch (e) {
      LogService.e('[LobbyNakamaService] RPC inventory_stats 失败: $e');
      return null;
    }
  }

  // =========================================================================
  // 本地设置方法（Task 4.5）
  // =========================================================================

  String loadSelectedSpriteId({String fallback = 'sprite_01'}) {
    return StorageUtils.getString(
          keySelectedSpriteId,
          defaultValue: fallback,
        ) ??
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

  bool loadUseSteamName() {
    return StorageUtils.getBool(keyUseSteamName, defaultValue: false);
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

  Future<void> setUseSteamName(bool value) async {
    await StorageUtils.setBool(keyUseSteamName, value);
    if (AuthService.instance.isLoggedIn && !loadAnonymousMode()) {
      unawaited(_syncDisplayName());
    }
  }

  // =========================================================================
  // 传送门流程
  // =========================================================================

  /// 处理传送门传送
  ///
  /// 协议流程（WebSocket 连接保持不变，只切换 Match）：
  /// 1. 收到 portal.teleport，取出 target_match_id
  /// 2. leaveMatch（离开当前 Match）
  /// 3. 设置 _isTeleportArrival=true（join.success 后跳过 enter）
  /// 4. joinMatch(target_match_id)（加入目标 Match）
  /// 5. 收到 join.success → 检测到传送到达，跳过 enter，直接发送 snapshot.request
  Future<void> _handlePortalTeleport(
    pb.PortalTeleportResponse teleportResp,
  ) async {
    final targetMapId = teleportResp.targetMapId;
    final targetMatchId = teleportResp.targetMatchId;

    if (targetMapId.isEmpty) {
      LogService.e('[LobbyNakamaService] portal.teleport 缺少 targetMapId');
      return;
    }
    if (targetMatchId.isEmpty) {
      LogService.e('[LobbyNakamaService] portal.teleport 缺少 targetMatchId');
      return;
    }

    LogService.i(
      '[LobbyNakamaService] 收到传送指令，目标地图: $targetMapId, targetMatchId: $targetMatchId',
    );

    // 清理本地状态，准备接收新地图数据
    _hasAssetsReceived = false;
    _latestAssetsPayload = null;
    _latestSnapshot = null;
    _clearCachedEventsStream();

    // S3 关键修复：传送是跨 Match（跨地图）切换，目标地图有独立的 deltaSeq 序列。
    // 必须重置 _lastDeltaSeq，否则会带着源地图的 seq 请求目标地图的快照，
    // 触发错误的增量恢复（本地仍是源地图用户列表，叠加目标地图增量 → 幽灵用户/缺人）。
    // 重置为 0 → requestSnapshot 请求全量，目标地图整表替换（正确行为）。
    _lastDeltaSeq = 0;

    try {
      // 离开当前 Match（WebSocket 连接保持）
      await _socketManager.leaveMatch();

      // 标记本次 joinMatch 为传送到达（join.success 后跳过 enter，直接请求 snapshot）
      _isTeleportArrival = true;
      _hasEnteredLobby = false;

      // 加入目标 Match（同一 WebSocket 连接）
      await _socketManager.joinMatch(targetMatchId);

      // 传送到达时，join.success 会触发 _handleMatchEvent，
      // 由于 _isTeleportArrival=true，会跳过 enter 直接请求 snapshot。
      // 此处额外调用 requestSnapshot() 作为兜底，防止 join.success 在监听器
      // 注册前到达导致消息丢失（snapshot 请求是幂等的，重复发送无副作用）。
      LogService.i(
        '[LobbyNakamaService] 传送完成，已加入 Match: $targetMatchId，发送 snapshot 兜底请求',
      );
      await requestSnapshot();
    } catch (e, stackTrace) {
      LogService.e('[LobbyNakamaService] 传送失败', e, stackTrace);
      _emitConnectionEvent(
        LobbyConnectionEventType.error,
        error: '传送失败: ${e.toString()}',
      );
      _scheduleReconnect();
    }
  }
}
