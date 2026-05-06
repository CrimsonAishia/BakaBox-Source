import 'dart:async';
import 'dart:convert';

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
    LogService.d('[NakamaClientManager] 客户端已初始化: ${config.host}:${config.port}');
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

  /// RPC 调用
  Future<String?> rpc(String id, {String? payload}) async {
    final client = _client;
    final session = _session;
    if (client == null || session == null) {
      throw StateError('[NakamaClientManager] 客户端或 Session 未就绪');
    }

    LogService.d('[NakamaClientManager] RPC 调用: $id');
    return client.rpc(session: session, id: id, payload: payload);
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

  /// 建立 WebSocket 连接
  Future<void> connect({
    required String host,
    required int port,
    required bool ssl,
    required String token,
  }) async {
    // 使用唯一 key 避免缓存问题（NakamaWebsocketClient.init 按 key 缓存）
    final key = 'lobby_${DateTime.now().millisecondsSinceEpoch}';

    LogService.d('[NakamaSocketManager] 建立 WebSocket 连接: $host:$port (key=$key)');

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
    LogService.i('[NakamaSocketManager] 已加入 Match: $matchId, presences=${match.presences.length}');
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
      socket.sendMatchData(
        matchId: matchId,
        opCode: 1,
        data: bytes,
      );
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
    // 原始数据日志：在任何过滤逻辑之前输出，用于排查服务端是否有回包
    final rawBytes = matchData.data;
    LogService.d(
      '[NakamaSocketManager][RAW] 收到 MatchData: '
      'opCode=${matchData.opCode}, '
      'matchId=${matchData.matchId}, '
      'presence=${matchData.presence?.userId}, '
      'dataLength=${rawBytes?.length ?? 0}, '
      'rawHex=${rawBytes != null && rawBytes.isNotEmpty ? rawBytes.take(32).map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ") : "(empty)"}',
    );

    // 仅处理 OpCode 1
    if (matchData.opCode != 1) {
      LogService.d(
        '[NakamaSocketManager] 忽略非 OpCode 1 消息: opCode=${matchData.opCode}',
      );
      return;
    }

    final data = rawBytes;
    if (data == null || data.isEmpty) {
      LogService.w('[NakamaSocketManager] 收到空数据的 OpCode 1 消息');
      return;
    }

    final wsEvent = LobbyEnvelopeParser.fromBytes(data);
    if (wsEvent == null) {
      LogService.w(
        '[NakamaSocketManager] Protobuf 反序列化失败，跳过 (${data.length} bytes), '
        'rawHex=${data.take(64).map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}',
      );
      return;
    }

    LogService.d('[NakamaSocketManager] 收到消息: ${wsEvent.type}');
    _matchEventController.add(wsEvent);
  }

  /// 处理 WebSocket 断开
  void _handleDisconnect() {
    LogService.w('[NakamaSocketManager] WebSocket 已断开');
    _isConnected = false;
    _currentMatchId = null;
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

  // === 流订阅 ===
  StreamSubscription<LobbyWsEvent>? _matchEventSubscription;
  StreamSubscription<void>? _disconnectSubscription;

  // === 传送门 ===

  // =========================================================================
  // 事件流（与现有接口一致）
  // =========================================================================

  /// WebSocket 事件流，支持新订阅者获取最新的 snapshot
  Stream<LobbyWsEvent> get events {
    final latest = _latestSnapshot;
    if (latest != null) {
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
    } else if (_isConnected && hasValidToken && !loadAnonymousMode()) {
      // 已连接状态下用户登录且未开启匿名模式，直接发送 login 消息切换为实名身份
      // （未连接时会在 join.success 收到后自动处理）
      LogService.i('[LobbyNakamaService] 检测到用户登录（已连接，非匿名模式），发送 login 事件');
      unawaited(login());
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
    _clearCachedEventsStream();
    _reconnectDelaySeconds = 2;

    await _waitForTokenReady();
    await _ensureDeviceIdReady();
    await _doConnect();
  }

  /// 释放资源
  Future<void> dispose() async {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

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
      final jwtToken = (AuthService.instance.isLoggedIn && TokenService.instance.isTokenValid)
          ? TokenService.instance.token
          : null;

      await _clientManager.authenticate(
        jwtToken: jwtToken,
        deviceId: _deviceId!,
      );

      // 3. WebSocket 连接
      await _socketManager.connect(
        host: config.host,
        port: config.port,
        ssl: config.ssl,
        token: _clientManager.token!,
      );

      // 4. 监听 Match 消息和断开事件（在 joinMatch 之前设置，确保不丢失消息）
      _setupStreamListeners();

      // 5. RPC lobby_join 获取 matchId（服务端自动分配地图）
      final matchId = await _rpcLobbyJoin();
      if (matchId == null) {
        LogService.e('[LobbyNakamaService] RPC lobby_join 获取 matchId 失败');
        _emitConnectionEvent(LobbyConnectionEventType.error, error: '获取 matchId 失败');
        _scheduleReconnect();
        return;
      }

      // 6. 加入 Match
      await _socketManager.joinMatch(matchId);

      // 7. 只有在 joinMatch 成功后才标记为已连接并发送 connected 事件
      // 这样 LobbyBloc 收到 connected 事件时，matchId 已经有效，可以正常发送消息
      _isConnected = true;
      _emitConnectionEvent(LobbyConnectionEventType.connected);

      // 注意：不在此处主动发送 login 或 snapshot.request。
      // 文档流程：joinMatch → 收到 join.success → 发送 snapshot.request
      // login 事件在 _handleMatchEvent 收到 join.success 时触发（见下方处理逻辑）。

      LogService.i('[LobbyNakamaService] 初始化完成，已加入 Match: $matchId，等待 join.success');
    } catch (e, stackTrace) {
      LogService.e('[LobbyNakamaService] 连接失败', e, stackTrace);
      _emitConnectionEvent(LobbyConnectionEventType.error, error: e.toString());
      _isConnected = false;
      _scheduleReconnect();
    }
  }

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

    // 收到 join.success 后按文档流程处理：
    // 1. 若用户已登录且未开启匿名模式，发送 login 消息切换为实名身份
    // 2. 发送 snapshot.request 获取完整场景数据
    if (wsEvent.type == 'join.success') {
      LogService.i('[LobbyNakamaService] 收到 join.success，开始初始化场景');
      if (AuthService.instance.isLoggedIn && hasValidToken && !loadAnonymousMode()) {
        LogService.d('[LobbyNakamaService] 用户已登录（非匿名模式），发送 login 事件');
        unawaited(login());
      }
      // 发送 snapshot.request 获取完整场景数据
      unawaited(requestSnapshot());
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
    _latestSnapshot = null;
    _latestAssetsPayload = null;
    _hasAssetsReceived = false;
    _clearCachedEventsStream();

    _emitConnectionEvent(LobbyConnectionEventType.closed);

    if (!_isKicked) {
      _scheduleReconnect();
    } else {
      LogService.w('[LobbyNakamaService] 被踢出状态，跳过自动重连');
    }
  }

  /// 调度重连（指数退避）
  void _scheduleReconnect() {
    if (_isDisposed) return;
    if (_isReconnecting) return;
    _isReconnecting = true;

    LogService.w(
      '[LobbyNakamaService] 将在 $_reconnectDelaySeconds 秒后尝试重连...',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelaySeconds), () async {
      _isReconnecting = false;
      _reconnectDelaySeconds =
          (_reconnectDelaySeconds * 2).clamp(2, _maxReconnectDelaySeconds);

      // 重连时检查 Session 是否过期，过期则先刷新
      if (_clientManager.session != null && _clientManager.session!.isExpired) {
        LogService.d('[LobbyNakamaService] Session 已过期，先刷新再重连');
        try {
          final jwtToken =
              (AuthService.instance.isLoggedIn && TokenService.instance.isTokenValid)
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

      await _doConnect();
    });
  }

  /// 计算重连延迟（纯函数，用于属性测试）
  static int calculateReconnectDelay(int retryCount) {
    // delay = min(2 * 2^n, 30)
    final delay = 2 * (1 << retryCount.clamp(0, 30));
    return delay.clamp(2, 30);
  }

  /// RPC 调用 lobby_join 获取 Match ID（带重试）
  ///
  /// 文档协议：调用 RPC "lobby_join"，携带 LobbyJoinRequest { deviceType } 的 Protobuf 编码。
  /// 服务端自动分配地图（老用户恢复上次地图，新用户进入默认地图）。
  /// 服务端在用户加入 Match 时读取 deviceType 并记录到用户状态中。
  /// 返回 Protobuf 序列化的 LobbyJoinResponse { matchId, mapId }。
  Future<String?> _rpcLobbyJoin() async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    // 构造 LobbyJoinRequest，携带 deviceType（"mobile" 或 "pc"）
    final reqBytes = (pb.LobbyJoinRequest()..deviceType = _deviceType).writeToBuffer();
    // 服务端期望原始 Protobuf 二进制字节转成字符串
    final payload = String.fromCharCodes(reqBytes);

    for (var i = 0; i < maxRetries; i++) {
      try {
        final result = await _clientManager.rpc('lobby_join', payload: payload);
        LogService.d('[LobbyNakamaService] RPC lobby_join 返回: (length=${result?.length}, isNull=${result == null}, isEmpty=${result?.isEmpty})');

        if (result != null && result.isNotEmpty) {
          // 服务端返回的是原始 Protobuf 二进制数据
          // 将字符串的 codeUnits 转换为字节数组后解析
          try {
            final bytes = result.codeUnits;
            final response = pb.LobbyJoinResponse.fromBuffer(bytes);
            final matchId = response.matchId;
            final mapId = response.mapId;
            LogService.d('[LobbyNakamaService] Protobuf 解析成功: matchId="$matchId", mapId="$mapId"');
            if (matchId.isNotEmpty) {
              return matchId;
            } else {
              LogService.w('[LobbyNakamaService] Protobuf 解析成功但 matchId 为空');
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
  /// 文档协议：SnapshotRequest 无参数，服务端返回地图配置、用户列表、最近消息。
  Future<void> requestSnapshot() async {
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'snapshot.request'
      ..traceId = _generateTraceId()
      ..snapshotRequest = pb.SnapshotRequest();
    _sendEnvelope(envelope);
  }

  /// 发送角色外观变更
  Future<void> sendSpriteChange(String spriteId) async {
    await StorageUtils.setString(keySelectedSpriteId, spriteId);
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'profile.sprite.change'
      ..traceId = _generateTraceId()
      ..profileSpriteChangeRequest = (pb.ProfileSpriteChangeRequest()..spriteId = spriteId);
    _sendEnvelope(envelope);
  }

  /// 设置匿名状态
  Future<void> setAnonymous(bool value) async {
    await StorageUtils.setBool(keyAnonymousMode, value);
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'profile.anonymous.change'
      ..traceId = _generateTraceId()
      ..profileAnonymousChangeRequest = (pb.ProfileAnonymousChangeRequest()..isAnonymous = value);
    _sendEnvelope(envelope);
  }

  /// 更新状态文本
  Future<void> updateStatusText(String statusText) async {
    final envelope = pb.LobbyEnvelope()
      ..v = 1
      ..type = 'profile.statusText.update'
      ..traceId = _generateTraceId()
      ..profileStatusTextUpdateRequest = (pb.ProfileStatusTextUpdateRequest()..statusText = statusText);
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
      ..onlineStatsRequest = (pb.OnlineStatsRequest()..includeUsers = includeUsers);
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
        ..deviceType = _deviceType);
    _sendEnvelope(envelope);

    // 开启的情况才主动同步显示名称
    if (loadUseSteamName()) {
      _syncDisplayName();
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
      ..profileSteamBind = (pb.ProfileSteamBindRequest()
        ..steamId = steamId64
        ..steamName = steamName);
    _sendEnvelope(envelope);
  }

  /// RPC 查询 Steam 玩家信息
  ///
  /// 根据目标用户的 Nakama UUID 查询其论坛账号、游戏数据等信息。
  /// 服务端会自动查询该用户绑定的 Steam64 ID，无需客户端传递 Steam ID。
  Future<pb.SteamUserInfoResponse?> rpcSteamUserInfo(String nakamaUserId) async {
    try {
      LogService.d('[LobbyNakamaService] RPC steam_user_info: userId=$nakamaUserId');
      final reqBytes = (pb.SteamUserInfoRequest()..userId = nakamaUserId).writeToBuffer();
      // 服务端期望原始 Protobuf 二进制字节转成字符串（与 lobby_join 一致）
      final payload = String.fromCharCodes(reqBytes);
      final result = await _clientManager.rpc('steam_user_info', payload: payload);
      if (result != null && result.isNotEmpty) {
        // 响应是 base64 编码的 proto 二进制，需要先 decode
        final bytes = base64Decode(result);
        return pb.SteamUserInfoResponse.fromBuffer(bytes);
      }
      return null;
    } catch (e) {
      final errStr = e.toString();
      // 服务端序列化响应时出错（通常是数据库中存有非 UTF-8 编码的字段，如 GBK 中文）
      // 这是服务端 bug，客户端无法修复，返回特殊响应让 UI 显示友好提示
      if (errStr.contains('invalid UTF-8') || errStr.contains('marshaling')) {
        LogService.w('[LobbyNakamaService] RPC steam_user_info 服务端响应含非 UTF-8 数据: $e');
        return pb.SteamUserInfoResponse()
          ..code = -1
          ..message = '该用户的数据包含特殊字符，暂时无法显示';
      }
      LogService.e('[LobbyNakamaService] RPC steam_user_info 失败: $e');
      return null;
    }
  }

  // =========================================================================
  // 本地设置方法（Task 4.5）
  // =========================================================================

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
      _syncDisplayName();
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
  /// 3. joinMatch(target_match_id)（加入目标 Match）
  /// 4. 收到 join.success → 自动发送 snapshot.request
  Future<void> _handlePortalTeleport(pb.PortalTeleportResponse teleportResp) async {
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

    LogService.i('[LobbyNakamaService] 收到传送指令，目标地图: $targetMapId, targetMatchId: $targetMatchId');

    // 清理本地状态，准备接收新地图数据
    _hasAssetsReceived = false;
    _latestAssetsPayload = null;
    _latestSnapshot = null;
    _clearCachedEventsStream();

    try {
      // 离开当前 Match（WebSocket 连接保持）
      await _socketManager.leaveMatch();

      // 加入目标 Match（同一 WebSocket 连接）
      await _socketManager.joinMatch(targetMatchId);

      // joinMatch() resolve 后立即请求 snapshot。
      // 不依赖 join.success 作为触发条件——join.success 走 MatchData 通道，
      // 在 joinMatch() resolve 之前到达时监听器尚未注册，消息会丢失。
      // snapshot 包含 join.success 的全部信息（mapId、user、onlineCount），可完全替代。
      LogService.i('[LobbyNakamaService] 传送完成，已加入 Match: $targetMatchId，主动请求 snapshot');
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
