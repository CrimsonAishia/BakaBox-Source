import 'dart:async';
import 'dart:math' as math;

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../api/server_api.dart';
import '../../models/gsi_models.dart';
import '../../models/lobby_models.dart';
import '../../services/auth_service.dart';
import '../../services/console_log_service.dart';
import '../../services/game_status_service.dart';
import '../../services/gsi_service.dart';
import '../../services/lobby_asset_cache_service.dart';
import '../../services/lobby_image_cache_service.dart';
import '../../services/lobby_map_loader_service.dart';
import '../../services/lobby_nakama_service.dart';
import '../../services/notification_window_service.dart';
import '../../services/broadcast_notification_service.dart';
import '../../services/server_address_mapping_service.dart';
import '../../services/status_window_service.dart';
import '../../services/steam_user_service.dart';
import '../../utils/log_service.dart';
import '../../utils/storage_utils.dart';
import '../settings/settings_state.dart';
import '../../models/proto/lobby.pb.dart' as pb;

part 'lobby_event.dart';
part 'lobby_state.dart';

class LobbyBloc extends Bloc<LobbyEvent, LobbyState> {
  LobbyBloc({LobbyNakamaService? service, String initialActivityText = '在线'})
      : _service = service ?? LobbyNakamaService.instance,
        super(LobbyState.initial().copyWith(pageActivityText: initialActivityText)) {
    // 在构造时就订阅 WebSocket 事件
    _wsSubscription = _service.events.listen(
      (wsEvent) => add(LobbyWsEventReceived(wsEvent)),
    );

    // 订阅游戏状态变化，用于更新状态文字（在线/游戏中）
    _gameStatusSubscription = GameStatusService().statusStream.listen(
      (event) {
        if (_isDisposed) return;
        add(_LobbyGameStatusChanged(event.isRunning));
      },
    );

    // 订阅操作状态变化（挤服等），用于更新状态文字
    // 只在 isQueueing 实际变化时才触发，避免挤服过程中疯狂更新
    _operationStateSubscription = StatusWindowService().stateStream.listen(
      (event) {
        if (_isDisposed) return;
        final newIsQueueing = event.isQueueing;
        if (newIsQueueing != _lastIsQueueing) {
          _lastIsQueueing = newIsQueueing;
          add(_LobbyGameStatusChanged(GameStatusService().isGameRunning));
        }
      },
    );

    // 订阅 ConsoleLogService 状态变化，用于获取所在服务器信息
    _consoleLogSubscription = ConsoleLogService().stateStream.listen(
      (event) {
        if (_isDisposed) return;
        add(_LobbyGameStatusChanged(GameStatusService().isGameRunning));
      },
    );

    // 订阅 GSI 状态变化，用于获取游戏内详细状态
    _gsiSubscription = GsiService().stateStream.listen(
      (event) {
        if (_isDisposed) return;
        add(_LobbyGameStatusChanged(GameStatusService().isGameRunning));
      },
    );

    // 订阅 AuthService 登录状态变化
    _authStateListener = _onAuthStateChanged;
    AuthService.instance.addLoginStateListener(_authStateListener);

    on<LobbyStarted>(_onStarted);
    on<LobbySceneTapped>(_onSceneTapped);
    on<LobbyMovementTicked>(_onMovementTicked);
    on<LobbyPlayerArrived>(_onPlayerArrived);
    on<LobbyChatModeChanged>(_onChatModeChanged);
    on<LobbyChatSubmitted>(_onChatSubmitted);
    on<LobbyPlayersPanelToggled>(_onPlayersPanelToggled);
    on<LobbySettingsPanelToggled>(_onSettingsPanelToggled);
    on<LobbySpriteSelected>(_onSpriteSelected);
    on<LobbyAnonymousToggled>(_onAnonymousToggled);
    on<LobbyChatOpacityChanged>(_onChatOpacityChanged);
    on<LobbyNameplatesToggled>(_onNameplatesToggled);
    on<LobbyChatBubblesToggled>(_onChatBubblesToggled);
    on<LobbyUseSteamNameToggled>(_onUseSteamNameToggled);
    on<LobbyTransientNoticeShown>(_onTransientNoticeShown);
    on<LobbyBubbleExpired>(_onBubbleExpired);
    on<LobbyWsEventReceived>(_onWsEventReceived);
    on<LobbyPanelsDismissed>(_onPanelsDismissed);
    on<_LobbyAssetsReceived>(_onAssetsReceived);
    on<_LobbyGameStatusChanged>(_onGameStatusChanged);
    on<LobbyPageActivityChanged>(_onPageActivityChanged);
    on<LobbyTeleportStarted>(_onTeleportStarted);
    on<LobbyTeleportCompleted>(_onTeleportCompleted);
    on<_LobbySetLoadingMore>(_onSetLoadingMore);
    on<LobbyLogoutConfirmed>(_onLogoutConfirmed);
    on<_LobbyChatCooldownTick>(_onChatCooldownTick);
    on<_LobbyAnonymousSwitchCooldownTick>(_onAnonymousSwitchCooldownTick);
    on<_LobbySteamNameSwitchCooldownTick>(_onSteamNameSwitchCooldownTick);
    on<LobbyBroadcastDialogToggled>(_onBroadcastDialogToggled);
    on<LobbyBroadcastSubmitted>(_onBroadcastSubmitted);
    on<_LobbyBroadcastCooldownTick>(_onBroadcastCooldownTick);
    on<LobbyPortalEntered>(_onPortalEntered);
    on<LobbyPortalExited>(_onPortalExited);
    on<LobbyPortalHoverChanged>(_onPortalHoverChanged);
    on<LobbyPortalConfirmRequested>(_onPortalConfirmRequested);
    on<LobbyPortalClicked>(_onPortalClicked);
    on<LobbyPortalDialogShowed>(_onPortalDialogShowed);
    on<LobbyPortalDialogDismissed>(_onPortalDialogDismissed);
    on<LobbyOnlineStatsRequested>(_onOnlineStatsRequested);
    on<LobbyNotificationExpired>(_onNotificationExpired);
    on<_LobbySettingTimeout>(_onSettingTimeout);
    on<_LobbySettingsTimeoutCheck>(_onSettingsTimeoutCheck);
    on<LobbyKickedDismissed>(_onKickedDismissed);
    on<LobbyChatBubblesCleared>(_onChatBubblesCleared);
    on<LobbySnapshotRefreshRequested>(_onSnapshotRefreshRequested);
    on<_LobbyQueueStarted>(_onQueueStarted);
    on<_LobbyQueueStatusUpdated>(_onQueueStatusUpdated);
    on<_LobbyQueueReady>(_onQueueReady);
    on<_LobbyQueueExpired>(_onQueueExpired);
    on<LobbyQueueCancelled>(_onQueueCancelled);
  }

  static const double _moveSpeed = 2.8;
  static const String _selfUserId = 'self';
  static const Duration _moveDebounceInterval = Duration(milliseconds: 250);
  /// 聊天冷却时间（秒）
  static const int _chatCooldownDuration = 1;
  /// 匿名切换冷却时间（秒）
  static const int _anonymousSwitchCooldownDuration = 3;
  /// Steam名称切换冷却时间（秒）
  static const int _steamNameSwitchCooldownDuration = 3;

  final LobbyNakamaService _service;
  StreamSubscription<LobbyWsEvent>? _wsSubscription;
  StreamSubscription<GameStatusEvent>? _gameStatusSubscription;
  StreamSubscription<OperationState>? _operationStateSubscription;
  StreamSubscription<ConsoleLogState>? _consoleLogSubscription;
  StreamSubscription<GsiGameState?>? _gsiSubscription;
  Timer? _movementTimer;
  Timer? _bubbleExpiryTimer;
  Timer? _chatCooldownTimer;
  Timer? _broadcastCooldownTimer;
  Timer? _anonymousSwitchCooldownTimer;
  Timer? _steamNameSwitchCooldownTimer;

  /// 广播消息 Stream，仅在收到 broadcast.message 事件时发出
  /// GlobalBroadcastBar 订阅此 Stream 来显示右下角广播通知卡片（桌面端使用）
  final _broadcastController = StreamController<LobbyBroadcastMessage>.broadcast();
  Stream<LobbyBroadcastMessage> get broadcastStream => _broadcastController.stream;
  Timer? _settingsTimeoutTimer;
  Timer? _transientNoticeTimer;
  StreamSubscription<LobbyWsEvent>? _snapshotOnAssetsReceived;
  Timer? _assetsTimeoutTimer;
  bool _authAttemptedAfterConnect = false;
  String? _selfServerUserId;
  DateTime? _lastMoveRequestAt;
  bool _isLobbyEntered = false;
  bool _isDisposed = false;
  /// 当前地图 ID（从 join.success 中提取，用于资产加载时确定当前地图）
  String? _selfMapId;
  /// 上次发送到服务器的状态文字（用于去重，避免重复上报）
  String? _lastSentStatusText;
  /// 上次 isQueueing 状态（用于避免挤服过程中频繁触发更新）
  bool _lastIsQueueing = false;
  /// 地图名称中文标签缓存（mapName → label）
  final Map<String, String> _mapLabelCache = {};
  /// 状态文字上报防抖计时器
  Timer? _statusTextDebounceTimer;
  /// 状态文字上报防抖时间
  static const Duration _statusTextDebounceDuration = Duration(seconds: 3);

  /// 排队轮询定时器
  Timer? _queuePollTimer;
  /// 当前排队令牌
  String? _queueTicket;
  /// 排队轮询失败计数
  int _queuePollFailCount = 0;
  /// 排队自动重试延迟定时器
  Timer? _queueRetryTimer;
  /// 当前排队轮询间隔（毫秒），用于避免重复重建定时器
  int _queuePollIntervalMs = 0;

  /// 定期 snapshot 对齐定时器（presence.delta 最终一致性保障）
  Timer? _snapshotAlignTimer;

  /// AuthService 登录状态变化监听器回调
  late final LoginStateChangedCallback _authStateListener;

  /// 模型切换前的 spriteId（用于 reject 时回滚）
  String? _previousSpriteId;

  /// 处理 AuthService 登录状态变化
  void _onAuthStateChanged(bool isLoggedIn) {
    if (_isDisposed) return;

    if (isLoggedIn) {
      // 用户登录了，等待 token 就绪后发送 login 事件
      // 注意：AuthService.login() 中 _notifyLoginStateChanged 在 _exchangeBackendToken 之前调用，
      // 所以需要等待 token 交换完成
      LogService.i('[LobbyBloc] 检测到登录，等待 token 就绪后发送 login 事件');
      unawaited(_waitAndLogin());
    } else {
      // 用户登出了，重置状态并发送 logout 事件（保留连接，降级为匿名）
      LogService.i('[LobbyBloc] 检测到登出，发送 logout 事件');
      add(const LobbyLogoutConfirmed());
      unawaited(_service.logout(force: false));
    }
  }

  /// 等待 token 就绪后发送 login 事件
  Future<void> _waitAndLogin() async {
    final start = DateTime.now();
    const maxWait = Duration(seconds: 30);
    const interval = Duration(milliseconds: 200);

    while (!_service.hasValidToken) {
      if (_isDisposed) return;
      if (DateTime.now().difference(start) >= maxWait) {
        LogService.w('[LobbyBloc] 等待 token 超时，放弃 login 事件');
        return;
      }
      await Future.delayed(interval);
    }

    if (_isDisposed) return;
    // 防止与 snapshot 中的登录逻辑重复触发
    if (_authAttemptedAfterConnect) return;
    // service 层已进入大厅（_hasEnteredLobby=true）时，由 service._onAuthStateChanged 处理大厅内 login
    // 避免 bloc 层与 service 层重复发送
    if (_service.hasEnteredLobby) {
      LogService.d('[LobbyBloc] service 层已进入大厅，跳过 _waitAndLogin（由 service._onAuthStateChanged 处理）');
      return;
    }
    // service 层已在等待 login 响应（前厅内 login 已发），不重复发送
    if (_service.isLoginPending) {
      LogService.d('[LobbyBloc] service 层 login 已在进行中，跳过 _waitAndLogin');
      return;
    }
    _authAttemptedAfterConnect = true;
    LogService.i('[LobbyBloc] Token 已就绪，发送 login 事件');
    unawaited(_service.login());
  }

  Future<void> _onStarted(
    LobbyStarted event,
    Emitter<LobbyState> emit,
  ) async {
    // 重置状态，但保留 WebSocket 订阅（已在应用启动时建立）
    _authAttemptedAfterConnect = false;
    _selfServerUserId = null;
    _selfMapId = null;
    _lastSentStatusText = null;
    _previousSpriteId = null;
    _isLobbyEntered = true;
    _isDisposed = false;

    // 取消排队相关定时器
    _queuePollTimer?.cancel();
    _queuePollTimer = null;
    _queueTicket = null;
    _queuePollFailCount = 0;
    _queueRetryTimer?.cancel();
    _queueRetryTimer = null;
    _queuePollIntervalMs = 0;
    _snapshotAlignTimer?.cancel();
    _snapshotAlignTimer = null;

    // 取消上一次可能残留的 assets 监听器和超时计时器
    _snapshotOnAssetsReceived?.cancel();
    _snapshotOnAssetsReceived = null;
    _assetsTimeoutTimer?.cancel();
    _assetsTimeoutTimer = null;

    // 重置被踢标志，允许重连后的自动重连逻辑正常工作
    _service.resetKicked();

    // 确保图片缓存服务已初始化
    await LobbyImageCacheService.instance.init();

    // 主动从缓存预加载 assets 数据，解决 WebSocket 先到达但 LobbyBloc 未初始化的问题
    final cachedAssets = await _loadAssetsFromCache();

    emit(
      state.copyWith(
        selectedSpriteId: _service.loadSelectedSpriteId(),
        isAnonymous: _service.loadAnonymousMode(),
        chatOpacity: _service.loadChatOpacity(),
        showNameplates: _service.loadShowNameplates(),
        showChatBubbles: _service.loadShowChatBubbles(),
        useSteamName: _service.loadUseSteamName(),
        // 如果有缓存的 assets，先设置上
        assets: cachedAssets ?? state.assets,
        // 进入 loading 状态，显示 Loading UI
        pageStatus: LobbyPageStatus.loading,
        connectionStatus: _service.isConnected
            ? LobbyConnectionStatus.connected
            : LobbyConnectionStatus.connecting,
        // 根据连接状态设置加载阶段
        loadingPhase: _service.isConnected
            ? LobbyLoadingPhase.loadingAssets
            : LobbyLoadingPhase.connecting,
        transientNotice: '正在加载大厅数据...',
        // 清除排队状态
        clearQueue: true,
      ),
    );

    // 预加载所有已缓存的图片到内存（加速后续渲染）
    _preloadCachedImages();

    _scheduleBubbleCleanup();

    // 确保 WebSocket 已连接（移动端不在启动时连接，而是进入大厅时才连接）
    if (!_service.isConnected) {
      await _service.initialize();
    }

    // 用户已登录时，确保 login 消息会被发送：
    // - token 已就绪且 WS 已连接且未开启匿名模式：
    //   - 已进入大厅（hasEnteredLobby=true）：service 层 join.success 已处理，无需重复发送
    //   - 还在前厅（hasEnteredLobby=false）：直接发送 login，等待 login.success 后 service 层发 enter
    // - token 未就绪：等待 token 就绪后发送（_waitAndLogin 内部也会检查匿名模式和 hasEnteredLobby）
    if (AuthService.instance.isLoggedIn) {
      if (_service.hasValidToken && _service.isConnected) {
        if (!_service.hasEnteredLobby) {
          // 前厅中：直接发 login，service 层 login.success 会触发 enter
          // 但如果 service 层已经在等待 login 响应（isLoginPending），不重复发送
          if (!_service.isLoginPending) {
            LogService.i('[LobbyBloc] 用户已登录且 token 就绪（前厅中），直接发送 login 事件');
            _authAttemptedAfterConnect = true;
            unawaited(_service.login());
          } else {
            LogService.d('[LobbyBloc] 用户已登录且 token 就绪（前厅中，login 已在进行中），跳过重复发送');
            _authAttemptedAfterConnect = true;
          }
        } else {
          // 已进入大厅：service 层 join.success 已处理过 login，无需重复
          // 但需要标记 _authAttemptedAfterConnect 防止 _waitAndLogin 重复触发
          LogService.d('[LobbyBloc] 用户已登录且已进入大厅，跳过重复 login（service 层已处理）');
          _authAttemptedAfterConnect = true;
        }
      } else if (!_service.hasValidToken) {
        LogService.i('[LobbyBloc] 用户已登录但 token 未就绪，等待 token 后发送 login 事件');
        unawaited(_waitAndLogin());
      }
      // token 就绪但 WS 未连接：WS 连接后 join.success 会触发 service 层的 login，
      // 或者 snapshot 里的补发逻辑会处理。
    }

    // 进入大厅页面时才请求 assets 和 snapshot
    // 这样可以确保 URL token 在有效期内
    _requestAssetsAndSnapshot();
  }

  /// 请求 assets 和 snapshot
  ///
  /// 覆盖所有竞态场景：
  /// 1. assets 在监听器注册前已到达（先注册监听器再发请求 + 缓存兜底）
  /// 2. requestAssets() 发出时 WS 未连接（assets 永远不来 → 超时重试）
  /// 3. 重复调用（取消旧监听器 + 旧超时计时器）
  /// 4. 监听器与缓存检查同时命中（_handled 防重入标志）
  Future<void> _requestAssetsAndSnapshot() async {
    // 取消旧的监听器和超时计时器，避免重复触发
    _snapshotOnAssetsReceived?.cancel();
    _snapshotOnAssetsReceived = null;
    _assetsTimeoutTimer?.cancel();
    _assetsTimeoutTimer = null;

    // 防重入：监听器回调与缓存检查可能同时命中，只处理第一次
    var handled = false;

    Future<void> handleAssetsEvent(LobbyServerEvent serverEvent) async {
      if (handled) return;
      handled = true;

      _snapshotOnAssetsReceived?.cancel();
      _snapshotOnAssetsReceived = null;
      _assetsTimeoutTimer?.cancel();
      _assetsTimeoutTimer = null;

      add(_LobbyAssetsReceived(serverEvent));

      if (!_isDisposed && _isLobbyEntered) {
        await _service.requestSnapshot();
        await _service.requestBroadcastCD();
      }
    }

    // 先注册监听器（在发请求之前），彻底消除竞态窗口
    _snapshotOnAssetsReceived = _service.events.listen((wsEvent) {
      if (wsEvent is LobbyServerEvent && wsEvent.type == 'assets') {
        handleAssetsEvent(wsEvent);
      }
    });

    // 再发送 assets 请求
    await _service.requestAssets();

    // 缓存兜底：assets 可能在监听器注册之前就已被 _wsSubscription 消费并缓存
    if (!handled && _service.hasAssetsReceived) {
      final cachedAssetsResponse = _service.getLastAssetsPayload();
      if (cachedAssetsResponse != null) {
        LogService.d('[LobbyBloc] _requestAssetsAndSnapshot: 使用缓存 assets payload');
        // 构造 LobbyServerEvent 时需要包装为 pb.LobbyEnvelope
        final cachedEnvelope = pb.LobbyEnvelope()
          ..type = 'assets'
          ..assetsResponse = cachedAssetsResponse;
        await handleAssetsEvent(LobbyServerEvent(
          type: 'assets',
          timestamp: DateTime.now(),
          traceId: '',
          envelope: cachedEnvelope,
        ));
        return;
      }
    }

    // 超时兜底：WS 未连接或服务器无响应时，15 秒后重新发起整个流程
    if (!handled) {
      _assetsTimeoutTimer = Timer(const Duration(seconds: 15), () {
        if (_isDisposed || !_isLobbyEntered) return;
        if (state.pageStatus != LobbyPageStatus.loading) return;
        LogService.w('[LobbyBloc] assets 请求超时，重新发送请求');
        _requestAssetsAndSnapshot();
      });
    }
  }

  /// 请求更多分页用户
  ///
  /// 注意：文档协议中 SnapshotRequest 无参数，分页由服务端 snapshot 响应中的
  /// PageInfo 控制。此处仅重新请求 snapshot。
  Future<void> _loadMoreUsers(int page) async {
    if (_isDisposed || !_isLobbyEntered) return;

    // 标记正在加载更多
    add(_LobbySetLoadingMore(true));

    await _service.requestSnapshot();
  }

  /// 内部事件处理：assets 收到后更新状态并缓存
  Future<void> _onAssetsReceived(
    _LobbyAssetsReceived event,
    Emitter<LobbyState> emit,
  ) async {
    final rawAssets = _parseAssets(event.serverEvent.envelope.assetsResponse, currentMapId: _selfMapId);
    final assets = _mergeAssetsWithCache(rawAssets);

    // 立即缓存 URL（后台执行）
    unawaited(_cacheAssets(assets));

    emit(
      state.copyWith(
        assets: assets,
        // 更新加载阶段为等待 snapshot
        loadingPhase: state.pageStatus == LobbyPageStatus.loading
            ? LobbyLoadingPhase.loadingSnapshot
            : state.loadingPhase,
        transientNotice: '素材已收到，正在加载大厅...',
      ),
    );
  }

  /// 从缓存预加载 assets 数据
  Future<LobbyAssets?> _loadAssetsFromCache() async {
    try {
      // 确保缓存服务已初始化
      await LobbyAssetCacheService.instance.init();

      // 检查是否有本地缓存的 assets
      if (LobbyAssetCacheService.instance.mapCacheCount > 0 ||
          LobbyAssetCacheService.instance.spriteCacheCount > 0) {
        // 从缓存构建 LobbyAssets（只有 URL，没有尺寸等动态信息）
        final cachedSprites = LobbyAssetCacheService.instance.getCachedSpriteIds();
        final cachedMapIds = LobbyAssetCacheService.instance.getCachedMapIds();

        final sprites = cachedSprites.map((id) {
          final spriteUrl = LobbyAssetCacheService.instance.getSpriteUrl(id);
          final previewUrl = LobbyAssetCacheService.instance.getPreviewUrl(id);
          return LobbySprite(
            id: id,
            label: id,
            accentColor: const Color(0xFF60A5FA),
            spriteUrl: spriteUrl,
            previewUrl: previewUrl,
          );
        }).toList();

        // 从缓存加载所有地图
        final cachedMaps = <LobbyMapConfig>[];
        for (final mapId in cachedMapIds) {
          final cachedUrl = LobbyAssetCacheService.instance.getBackgroundUrlByMapId(mapId);
          if (cachedUrl != null) {
            cachedMaps.add(LobbyMapConfig(
              mapId: mapId,
              displayName: mapId,
              backgroundUrl: cachedUrl,
              width: 1600,
              height: 900,
              walkableAreas: const [LobbyWalkableArea(left: 0, top: 0, width: 1600, height: 900)],
            ));
          }
        }

        // 默认使用第一个缓存的地图
        final cachedMap = cachedMaps.isNotEmpty ? cachedMaps.first : null;

        return LobbyAssets(mapConfig: cachedMap, maps: cachedMaps, sprites: sprites);
      }
    } catch (e) {
      LogService.e('[LobbyBloc] 预加载缓存失败', e);
    }
    return null;
  }

  /// 预加载所有已缓存的图片到内存，加速后续渲染
  Future<void> _preloadCachedImages() async {
    try {
      // 收集所有需要预加载的 URL
      final urlsToPreload = <String>[];

      // 从 URL 缓存中收集 sprites
      for (final spriteId in LobbyAssetCacheService.instance.getCachedSpriteIds()) {
        final spriteUrl = LobbyAssetCacheService.instance.getSpriteUrl(spriteId);
        if (spriteUrl != null && spriteUrl.isNotEmpty) {
          urlsToPreload.add(spriteUrl);
        }
        final previewUrl = LobbyAssetCacheService.instance.getPreviewUrl(spriteId);
        if (previewUrl != null && previewUrl.isNotEmpty) {
          urlsToPreload.add(previewUrl);
        }
      }

      // 地图背景（支持多地图）
      for (final mapId in LobbyAssetCacheService.instance.getCachedMapIds()) {
        final backgroundUrl = LobbyAssetCacheService.instance.getBackgroundUrlByMapId(mapId);
        if (backgroundUrl != null && backgroundUrl.isNotEmpty) {
          urlsToPreload.add(backgroundUrl);
        }
      }

      if (urlsToPreload.isEmpty) return;

      // 预加载到内存（不去重，让 LobbyImageCacheService 处理）
      await LobbyImageCacheService.instance.preDownloadImages(urlsToPreload);
      LogService.d('[LobbyBloc] 预加载了 ${urlsToPreload.length} 个图片到内存');
    } catch (e) {
      LogService.e('[LobbyBloc] 预加载图片失败', e);
    }
  }

  Future<void> _onSceneTapped(
    LobbySceneTapped event,
    Emitter<LobbyState> emit,
  ) async {
    final mapConfig = state.mapConfig;
    final selfUser = state.selfUser;
    if (mapConfig == null || selfUser == null) return;

    // 移动防抖：500ms 内不允许重复发送
    final now = DateTime.now();
    if (_lastMoveRequestAt != null &&
        now.difference(_lastMoveRequestAt!) < _moveDebounceInterval) {
      return;
    }

    final target = event.position.clamp(
      minX: 0,
      maxX: mapConfig.width,
      minY: 0,
      maxY: mapConfig.height,
    );

    if (!mapConfig.contains(target)) return;

    _lastMoveRequestAt = now;

    // 只设置 targetPosition，不覆盖 position/renderPosition，
    // 让 _onMovementTicked 驱动平滑移动，避免瞬移。
    final nextUser = selfUser.copyWith(
      targetPosition: target,
      isMoving: true,
      facing: _resolveFacing(selfUser.renderPosition, target),
    );

    emit(state.copyWith(users: _replaceUser(state.users, nextUser)));
    _startMovementTimer();
    await _service.sendMove(target);
  }

  void _onMovementTicked(
    LobbyMovementTicked event,
    Emitter<LobbyState> emit,
  ) {
    // 检查是否有任何用户到达了目标（组件会自行插值，只在到达时同步状态）
    bool anyStillMoving = false;
    final updatedUsers = state.users.map((user) {
      if (!user.isMoving || user.targetPosition == null) return user;
      // renderPosition 是组件当前渲染位置（来自上一次状态同步），用于判断是否到达
      final dist = _distance(user.renderPosition, user.targetPosition!);
      if (dist <= _moveSpeed) {
        // 到达：anyStillMoving 保持 false（不设为 true），timer 会在本帧末尾被取消
        final arrivedUser = user.copyWith(
          renderPosition: user.targetPosition,
          position: user.targetPosition,
          targetPosition: null,
          isMoving: false,
        );
        // 通知服务器玩家已停止移动（仅对自己有效）
        if (arrivedUser.isSelf) {
          _sendStopMovingIfNeeded();
        }
        return arrivedUser;
      }
      anyStillMoving = true;
      return user;
    }).toList(growable: false);

    emit(state.copyWith(users: updatedUsers));

    // 当所有用户都停止移动时才取消 timer
    if (!anyStillMoving) {
      _movementTimer?.cancel();
      _movementTimer = null;
    }
  }

  /// 处理角色到达目标事件（由 LobbyGame 触发）
  /// 直接更新指定用户的移动状态，避免其他角色误判
  void _onPlayerArrived(
    LobbyPlayerArrived event,
    Emitter<LobbyState> emit,
  ) {
    final userIndex = state.users.indexWhere((u) => u.userId == event.userId);
    if (userIndex == -1) return;

    final user = state.users[userIndex];
    if (!user.isMoving) return; // 已经停止，忽略

    // 直接更新该用户的状态
    final arrivedUser = user.copyWith(
      renderPosition: event.arrivedPosition,
      position: event.arrivedPosition,
      targetPosition: null,
      isMoving: false,
    );

    final updatedUsers = List<LobbyUser>.from(state.users);
    updatedUsers[userIndex] = arrivedUser;

    emit(state.copyWith(users: updatedUsers));

    // 如果是自己到达目标，通知服务器停止移动
    if (arrivedUser.isSelf) {
      _sendStopMovingIfNeeded();
    }

    debugPrint('[LobbyBloc] _onPlayerArrived: ${event.userId} isSelf=${arrivedUser.isSelf}');
  }

  bool _lastStopSent = false;

  void _sendStopMovingIfNeeded() {
    if (_lastStopSent) return;
    _lastStopSent = true;
    // 使用 microtask 避免阻塞当前帧
    Future.microtask(() {
      // 延迟重置标记，防止短时间内多次移动
      Future.delayed(const Duration(milliseconds: 500), () {
        _lastStopSent = false;
      });
    });
  }

  void _onChatModeChanged(
    LobbyChatModeChanged event,
    Emitter<LobbyState> emit,
  ) {
    emit(state.copyWith(isChatActive: event.isActive));
  }

  Future<void> _onChatSubmitted(
    LobbyChatSubmitted event,
    Emitter<LobbyState> emit,
  ) async {
    final content = event.content.trim();
    if (content.isEmpty) {
      emit(state.copyWith(isChatActive: false));
      return;
    }

    // 检查冷却状态
    if (state.chatCooldownSeconds > 0) {
      emit(state.copyWith(
        transientNotice: '发送太快了，请稍后再试',
      ));
      return;
    }

    final now = DateTime.now();
    final selfUser = state.selfUser;

    // 构建自己的消息对象
    final myMessage = LobbyMessage(
      messageId: 'local_${now.microsecondsSinceEpoch}',
      userId: selfUser?.userId ?? 'self',
      nickname: selfUser?.displayName ?? '我',
      content: content,
      type: LobbyMessageType.user,
      timestamp: now,
      isAnonymous: state.isAnonymous,
    );

    // 立即更新自己的 lastMessage 状态，使聊天气泡和聊天栏立即显示
    final updatedUsers = state.users.map((user) {
      if (!user.isSelf) return user;
      return user.copyWith(
        lastMessage: content,
        lastMessageAt: now,
      );
    }).toList(growable: false);

    // 添加消息到消息列表（使用新列表对象触发状态更新，最多保留 100 条）
    final updatedMessages = _limitMessages([...state.messages, myMessage]);

    // 启动冷却计时器
    _startChatCooldownTimer();

    emit(
      state.copyWith(
        isChatActive: false,
        users: updatedUsers,
        messages: updatedMessages,
        chatCooldownSeconds: _chatCooldownDuration,
      ),
    );

    await _service.sendChat(content);
  }

  void _startChatCooldownTimer() {
    _chatCooldownTimer?.cancel();
    _chatCooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(const _LobbyChatCooldownTick());
    });
  }

  void _onChatCooldownTick(
    _LobbyChatCooldownTick event,
    Emitter<LobbyState> emit,
  ) {
    final newCooldown = state.chatCooldownSeconds - 1;
    if (newCooldown <= 0) {
      _chatCooldownTimer?.cancel();
      _chatCooldownTimer = null;
      emit(state.copyWith(chatCooldownSeconds: 0));
    } else {
      emit(state.copyWith(chatCooldownSeconds: newCooldown));
    }
  }

  void _startAnonymousSwitchCooldownTimer() {
    _anonymousSwitchCooldownTimer?.cancel();
    _anonymousSwitchCooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(const _LobbyAnonymousSwitchCooldownTick());
    });
  }

  void _onAnonymousSwitchCooldownTick(
    _LobbyAnonymousSwitchCooldownTick event,
    Emitter<LobbyState> emit,
  ) {
    final newCooldown = state.anonymousSwitchCooldownSeconds - 1;
    if (newCooldown <= 0) {
      _anonymousSwitchCooldownTimer?.cancel();
      _anonymousSwitchCooldownTimer = null;
      emit(state.copyWith(anonymousSwitchCooldownSeconds: 0));
    } else {
      emit(state.copyWith(anonymousSwitchCooldownSeconds: newCooldown));
    }
  }

  void _startSteamNameSwitchCooldownTimer() {
    _steamNameSwitchCooldownTimer?.cancel();
    _steamNameSwitchCooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(const _LobbySteamNameSwitchCooldownTick());
    });
  }

  void _onSteamNameSwitchCooldownTick(
    _LobbySteamNameSwitchCooldownTick event,
    Emitter<LobbyState> emit,
  ) {
    final newCooldown = state.steamNameSwitchCooldownSeconds - 1;
    if (newCooldown <= 0) {
      _steamNameSwitchCooldownTimer?.cancel();
      _steamNameSwitchCooldownTimer = null;
      emit(state.copyWith(steamNameSwitchCooldownSeconds: 0));
    } else {
      emit(state.copyWith(steamNameSwitchCooldownSeconds: newCooldown));
    }
  }

  void _onPlayersPanelToggled(
    LobbyPlayersPanelToggled event,
    Emitter<LobbyState> emit,
  ) {
    final willOpen = !state.isPlayersPanelOpen;
    emit(
      state.copyWith(
        isPlayersPanelOpen: willOpen,
        isSettingsPanelOpen: false,
      ),
    );
    // 打开面板时请求全服用户列表
    if (willOpen) {
      add(const LobbyOnlineStatsRequested());
    }
  }

  void _onSettingsPanelToggled(
    LobbySettingsPanelToggled event,
    Emitter<LobbyState> emit,
  ) {
    emit(
      state.copyWith(
        isSettingsPanelOpen: !state.isSettingsPanelOpen,
        isPlayersPanelOpen: false,
      ),
    );
  }

  Future<void> _onSpriteSelected(
    LobbySpriteSelected event,
    Emitter<LobbyState> emit,
  ) async {
    // _previousSpriteId 记录"最后一次服务端确认的 spriteId"
    // 首次切换时初始化为当前值（即服务端已确认的值）
    _previousSpriteId ??= state.selectedSpriteId;

    emit(
      state.copyWith(
        selectedSpriteId: event.spriteId,
        isSpriteChangePending: true,
        users: state.users
            .map(
              (user) => user.isSelf ? user.copyWith(spriteId: event.spriteId) : user,
            )
            .toList(growable: false),
      ),
    );
    await _service.sendSpriteChange(event.spriteId);
  }

  Future<void> _onAnonymousToggled(
    LobbyAnonymousToggled event,
    Emitter<LobbyState> emit,
  ) async {
    // 检查冷却状态
    if (state.anonymousSwitchCooldownSeconds > 0) {
      return;
    }

    const settingKey = 'anonymous';
    final updatedPending = Map<String, bool>.from(state.pendingSettings);
    updatedPending[settingKey] = event.value;

    emit(
      state.copyWith(
        isAnonymous: event.value,
        users: state.users
            .map(
              (user) => user.isSelf ? user.copyWith(isAnonymous: event.value) : user,
            )
            .toList(growable: false),
        pendingSettings: updatedPending,
        pendingSettingsTimeouts: {
          ...state.pendingSettingsTimeouts,
          settingKey: DateTime.now().add(const Duration(seconds: 3)),
        },
        // 启动冷却
        anonymousSwitchCooldownSeconds: _anonymousSwitchCooldownDuration,
      ),
    );
    _startAnonymousSwitchCooldownTimer();
    _scheduleSettingsTimeoutCheck();
    await _service.setAnonymous(event.value);
  }

  Future<void> _onChatOpacityChanged(
    LobbyChatOpacityChanged event,
    Emitter<LobbyState> emit,
  ) async {
    await _service.setChatOpacity(event.value);
    emit(state.copyWith(chatOpacity: event.value));
  }

  Future<void> _onNameplatesToggled(
    LobbyNameplatesToggled event,
    Emitter<LobbyState> emit,
  ) async {
    const settingKey = 'nameplates';
    final updatedPending = Map<String, bool>.from(state.pendingSettings);
    updatedPending[settingKey] = event.value;

    emit(
      state.copyWith(
        showNameplates: event.value,
        pendingSettings: updatedPending,
        pendingSettingsTimeouts: {
          ...state.pendingSettingsTimeouts,
          settingKey: DateTime.now().add(const Duration(seconds: 3)),
        },
      ),
    );
    _scheduleSettingsTimeoutCheck();
    await _service.setShowNameplates(event.value);
  }

  Future<void> _onChatBubblesToggled(
    LobbyChatBubblesToggled event,
    Emitter<LobbyState> emit,
  ) async {
    const settingKey = 'chatBubbles';
    final updatedPending = Map<String, bool>.from(state.pendingSettings);
    updatedPending[settingKey] = event.value;

    emit(
      state.copyWith(
        showChatBubbles: event.value,
        pendingSettings: updatedPending,
        pendingSettingsTimeouts: {
          ...state.pendingSettingsTimeouts,
          settingKey: DateTime.now().add(const Duration(seconds: 3)),
        },
      ),
    );
    _scheduleSettingsTimeoutCheck();
    await _service.setShowChatBubbles(event.value);
  }

  Future<void> _onUseSteamNameToggled(
    LobbyUseSteamNameToggled event,
    Emitter<LobbyState> emit,
  ) async {
    // 检查冷却状态
    if (state.steamNameSwitchCooldownSeconds > 0) return;

    // 开启时先检测能否获取到 Steam 用户名
    if (event.value) {
      final steamName = await SteamUserService().getCurrentUsername();
      if (steamName == null || steamName.isEmpty) {
        emit(state.copyWith(
          transientNotice: '未检测到 Steam 用户名，请确认 Steam 已登录',
        ));
        return;
      }
    }

    const settingKey = 'useSteamName';
    final updatedPending = Map<String, bool>.from(state.pendingSettings);
    updatedPending[settingKey] = event.value;

    emit(
      state.copyWith(
        useSteamName: event.value,
        pendingSettings: updatedPending,
        pendingSettingsTimeouts: {
          ...state.pendingSettingsTimeouts,
          settingKey: DateTime.now().add(const Duration(seconds: 3)),
        },
        // 启动冷却
        steamNameSwitchCooldownSeconds: _steamNameSwitchCooldownDuration,
      ),
    );
    _startSteamNameSwitchCooldownTimer();
    _scheduleSettingsTimeoutCheck();
    await _service.setUseSteamName(event.value);
  }

  void _onTransientNoticeShown(
    LobbyTransientNoticeShown event,
    Emitter<LobbyState> emit,
  ) {
    emit(state.copyWith(clearTransientNotice: true));
  }

  /// 在 bloc 内部调度 transientNotice 自动清除（超时后自动消失）
  void _scheduleTransientNoticeClear({Duration timeout = const Duration(seconds: 5)}) {
    _transientNoticeTimer?.cancel();
    _transientNoticeTimer = Timer(timeout, () {
      if (!_isDisposed && state.transientNotice != null) {
        add(const LobbyTransientNoticeShown());
      }
    });
  }

  void _onPanelsDismissed(
    LobbyPanelsDismissed event,
    Emitter<LobbyState> emit,
  ) {
    emit(
      state.copyWith(
        isPlayersPanelOpen: false,
        isSettingsPanelOpen: false,
        isChatActive: false, // 同时关闭聊天模式，避免焦点冲突
      ),
    );
  }

  void _onGameStatusChanged(
    _LobbyGameStatusChanged event,
    Emitter<LobbyState> emit,
  ) {
    _updateStatusTextByGameStatus(event.isGameRunning, emit);
  }

  void _onPageActivityChanged(
    LobbyPageActivityChanged event,
    Emitter<LobbyState> emit,
  ) {
    emit(state.copyWith(pageActivityText: event.pageActivityText));
    _updateStatusTextByGameStatus(GameStatusService().isGameRunning, emit, event.pageActivityText);
  }

  /// 根据游戏运行状态更新状态文字，并同步到服务器
  ///
  /// 优先级（从高到低）：
  /// 1. 挤服中
  /// 2. GSI 游戏状态（有意义的状态：主菜单、热身、游戏中）
  /// 3. 所在服务器（ConsoleLogService.isInServer → 服务器地址 + 地图）
  /// 4. 游戏运行中（isGameRunning → "游戏中"）
  /// 5. 其他（pageActivityText）
  Future<void> _updateStatusTextByGameStatus(
    bool isGameRunning,
    Emitter<LobbyState> emit,
    [String? pageActivityTextOverride]
  ) async {
    final activityText = pageActivityTextOverride ?? state.pageActivityText;
    final isQueueing = StatusWindowService().state.isQueueing;

    final String newStatusText;
    if (isQueueing) {
      newStatusText = '挤服中';
    } else {
      final gsiState = GsiService().latestState;
      final consoleState = ConsoleLogService().currentState;

      final gsiText = _resolveGsiStatusText(gsiState);
      if (gsiText != null) {
        newStatusText = gsiText;
      } else if (isGameRunning && consoleState.isInServer && consoleState.serverAddress.isNotEmpty) {
        // 必须同时满足 isGameRunning 才使用 consoleState，
        // 避免游戏关闭后 ConsoleLogService 状态延迟重置导致残留显示
        // 优先显示地图名，无地图时降级显示 IP
        final mapName = _resolveMapNameForServer(consoleState, gsiState);
        if (mapName != null) {
          newStatusText = '游戏中 · $mapName';
        } else {
          final displayAddress = ServerAddressMappingService().getDomainAddress(consoleState.serverAddress);
          newStatusText = '游戏中 · $displayAddress';
        }
      } else if (isGameRunning) {
        newStatusText = '游戏中';
      } else {
        newStatusText = activityText;
      }
    }

    // 去重：只在文字实际变化时才更新
    if (newStatusText == _lastSentStatusText) return;
    _lastSentStatusText = newStatusText;

    LogService.d('[StatusText] 更新状态文字: $newStatusText');

    // UI 立即更新（本地用户看到的状态不延迟）
    emit(
      state.copyWith(
        users: state.users
            .map(
              (user) => user.isSelf
                  ? user.copyWith(statusText: newStatusText)
                  : user,
            )
            .toList(growable: false),
      ),
    );

    // 服务器上报防抖：3 秒内多次变化只发送最后一次，节省带宽
    _statusTextDebounceTimer?.cancel();
    _statusTextDebounceTimer = Timer(_statusTextDebounceDuration, () {
      if (!_isDisposed) {
        _service.updateStatusText(newStatusText);
      }
    });
  }

  /// 从 GSI 状态解析有意义的状态文字，无意义时返回 null
  String? _resolveGsiStatusText(GsiGameState? gsiState) {
    if (gsiState == null) return null;

    // 游戏进程未运行时，GSI 数据一定是过期的（latestState 不会自动清空）
    if (!GameStatusService().isGameRunning) return null;

    // GSI 数据过期检查：游戏运行中但长时间没收到新数据，可能 GSI 配置异常
    final receivedAt = gsiState.receivedAt;
    if (receivedAt != null &&
        DateTime.now().difference(receivedAt) > const Duration(seconds: 60)) {
      return null;
    }

    final activity = gsiState.player?.activity;
    final mapPhase = gsiState.map?.phase;
    final mapName = gsiState.map?.name;

    // 主菜单：但如果 ConsoleLog 正在连接/加载，说明用户已经在进服务器了，
    // 此时 GSI 还没更新，不应该显示"在主菜单"
    if (activity == 'menu') {
      final consoleState = ConsoleLogService().currentState;
      if (consoleState.isConnecting || consoleState.isInServer) return null;
      return '游戏中 · 主菜单';
    }

    // 游戏中（playing 或 textinput 都算在游戏内）
    if (activity == 'playing' || activity == 'textinput') {
      // 回合结束/游戏结束阶段无意义，跳过让下层处理
      if (mapPhase == 'gameover') return null;

      // 优先从 GSI 获取地图名，如果 GSI 没有则尝试从 ConsoleLog 获取
      String? effectiveMapName = mapName;
      if (effectiveMapName == null || effectiveMapName.isEmpty) {
        effectiveMapName = ConsoleLogService().currentState.mapName;
      }
      final displayMap = _getMapDisplayName(
        effectiveMapName.isNotEmpty ? effectiveMapName : null,
      );

      // live / intermission / warmup / freezetime 等阶段
      return displayMap != null ? '游戏中 · $displayMap' : '游戏中';
    }

    return null;
  }

  /// 解析服务器场景下的地图名称
  ///
  /// 当 GSI 未提供有意义的状态（_resolveGsiStatusText 返回 null），
  /// 但 ConsoleLogService 显示用户在服务器中时，尝试从多个来源获取地图名：
  /// 1. ConsoleLogService.currentState.mapName
  /// 2. GSI 的 map.name（即使 activity 不是 playing，map 数据可能仍然有效）
  String? _resolveMapNameForServer(ConsoleLogState consoleState, GsiGameState? gsiState) {
    // 优先使用 ConsoleLog 的地图名（最可靠，直接从控制台日志解析）
    if (consoleState.mapName.isNotEmpty) {
      return _getMapDisplayName(consoleState.mapName);
    }

    // 其次尝试 GSI 的地图名（GSI 可能有延迟或处于过渡状态）
    if (gsiState != null) {
      final gsiMapName = gsiState.map?.name;
      if (gsiMapName != null && gsiMapName.isNotEmpty) {
        return _getMapDisplayName(gsiMapName);
      }
    }

    return null;
  }

  /// 获取地图显示名称（优先中文标签，其次原名）
  /// 同时异步预取标签，下次调用时直接命中缓存
  String? _getMapDisplayName(String? mapName) {
    if (mapName == null || mapName.isEmpty) return null;

    // 命中缓存直接返回
    final cached = _mapLabelCache[mapName];
    if (cached != null) return cached;

    // 缓存未命中：先用原名，同时异步拉取标签
    _fetchMapLabelAsync(mapName);
    return mapName;
  }

  /// 异步拉取地图中文标签并缓存，拉取完成后触发一次状态刷新
  Future<void> _fetchMapLabelAsync(String mapName) async {
    // 防止重复拉取（用空字符串占位表示"正在拉取"）
    if (_mapLabelCache.containsKey(mapName)) return;
    _mapLabelCache[mapName] = mapName; // 占位，避免并发重复请求

    try {
      final mapData = await ServerApi().getMapInfo(mapName);
      final label = mapData?.mapLabel;
      if (label != null && label.isNotEmpty && label != mapName) {
        _mapLabelCache[mapName] = label;
        // 标签拉取完成，重置去重缓存让下次能刷新文字
        if (_lastSentStatusText?.contains(mapName) == true) {
          _lastSentStatusText = null;
          if (!_isDisposed) {
            add(_LobbyGameStatusChanged(GameStatusService().isGameRunning));
          }
        }
      }
    } catch (_) {
      // 拉取失败保留原名，不影响主流程
    }
  }

  /// 登录成功后主动绑定 Steam ID
  ///
  /// 从 AuthService.userInfo.steamId 获取原始 Steam ID（STEAM_x:x:xxxxxxx 格式），
  /// 转换为 Steam64 ID 后发送 profile.steam.bind。
  /// 同时从 SteamUserService 获取本地 Steam 用户名一并发送。
  Future<void> _bindSteamAfterLogin() async {
    try {
      final userInfo = AuthService.instance.userInfo;
      if (userInfo == null) return;

      // steamId 是 STEAM_x:x:xxxxxxx 格式，需要转换为 Steam64 ID
      final rawSteamId = userInfo.steamId;
      if (rawSteamId == null || rawSteamId.isEmpty) {
        LogService.d('[LobbyBloc] 用户未绑定 Steam，跳过 steam bind');
        return;
      }

      // 将 STEAM_x:x:xxxxxxx 转换为 Steam64 ID
      // 公式：76561197960265728 + Y * 2^32 / 2 + Z（其中 STEAM_W:Y:Z）
      // 实际：steamId64 = 76561197960265728 + Z * 2 + Y
      final steamId64 = _convertSteamIdToSteam64(rawSteamId);
      if (steamId64 == null) {
        LogService.w('[LobbyBloc] Steam ID 格式无法解析: $rawSteamId');
        return;
      }

      // 获取本地 Steam 用户名（可选）
      final steamName = await SteamUserService().getCurrentUsername() ?? '';

      LogService.i('[LobbyBloc] 登录成功后绑定 Steam: raw=$rawSteamId id64=$steamId64, name=$steamName');
      _service.bindSteam(steamId64: steamId64, steamName: steamName);
    } catch (e) {
      LogService.w('[LobbyBloc] _bindSteamAfterLogin 异常: $e');
    }
  }

  /// 将 STEAM_W:Y:Z 格式转换为 Steam64 ID
  ///
  /// Steam64 = 76561197960265728 + Z * 2 + Y
  /// 例：STEAM_0:1:12345678 → 76561197960265728 + 12345678 * 2 + 1 = 76561198024877135
  String? _convertSteamIdToSteam64(String steamId) {
    // 匹配 STEAM_W:Y:Z 格式
    final match = RegExp(r'^STEAM_\d+:(\d+):(\d+)$').firstMatch(steamId);
    if (match == null) {
      // 如果已经是纯数字（Steam64 格式），直接验证后返回
      if (RegExp(r'^\d{10,20}$').hasMatch(steamId)) {
        return steamId;
      }
      return null;
    }

    final y = int.parse(match.group(1)!); // 0 或 1
    final z = int.parse(match.group(2)!); // 账号 ID 的一半

    // Steam64 基础值（Steam Universe 1）
    const base = 76561197960265728;
    final steam64 = base + z * 2 + y;
    return steam64.toString();
  }

  void _onTeleportStarted(
    LobbyTeleportStarted event,
    Emitter<LobbyState> emit,
  ) {
    final target = event.target;
    LogService.i('[LobbyBloc] _onTeleportStarted: target=${target.label} current isTeleporting=${state.isTeleporting}');
    emit(
      state.copyWith(
        isTeleporting: true,
        teleportTarget: target,
        transientNotice: '正在传送到 ${target.label}...',
      ),
    );
  }

  void _onTeleportCompleted(
    LobbyTeleportCompleted event,
    Emitter<LobbyState> emit,
  ) {
    LogService.i('[LobbyBloc] _onTeleportCompleted: current isTeleporting=${state.isTeleporting}');
    emit(
      state.copyWith(
        isTeleporting: false,
        clearTeleportTarget: true,
        clearTransientNotice: true,
      ),
    );
  }

  void _onSetLoadingMore(
    _LobbySetLoadingMore event,
    Emitter<LobbyState> emit,
  ) {
    emit(state.copyWith(isLoadingMore: event.isLoadingMore));
  }

  void _onBubbleExpired(
    LobbyBubbleExpired event,
    Emitter<LobbyState> emit,
  ) {
    final now = DateTime.now();
    final updatedUsers = state.users
        .map((user) {
          if (user.lastMessageAt == null) return user;
          final visible = now.difference(user.lastMessageAt!) <=
              const Duration(seconds: 8);
          if (visible) return user;
          return user.copyWith(lastMessage: null, lastMessageAt: null);
        })
        .toList(growable: false);
    emit(state.copyWith(users: updatedUsers));
  }

  void _onWsEventReceived(
    LobbyWsEventReceived event,
    Emitter<LobbyState> emit,
  ) {
    final wsEvent = event.event;
    
    switch (wsEvent) {
      case LobbyConnectionEvent(:final status, :final error):
        _handleConnectionEvent(status, error, emit);
      case LobbyServerEvent(:final type, :final envelope):
        LogService.d('[LobbyBloc] _onWsEventReceived: type=$type');
        // 排队开始事件（由 service 层构造的虚拟事件，携带 queue 字段）
        if (type == 'queue.started') {
          final serverEvent = wsEvent as LobbyServerEvent;
          if (serverEvent.queueTicket != null) {
            add(_LobbyQueueStarted(
              ticket: serverEvent.queueTicket!,
              position: serverEvent.queuePosition ?? 0,
              queueTotal: serverEvent.queueTotal ?? 0,
              etaSeconds: serverEvent.queueEtaSeconds ?? 0,
              pollIntervalMs: serverEvent.queuePollIntervalMs ?? 2000,
            ));
          }
          return;
        }
        _handleServerEvent(type, envelope, emit);
    }
  }

  void _handleConnectionEvent(
    LobbyConnectionEventType status,
    String? error,
    Emitter<LobbyState> emit,
  ) {
    switch (status) {
      case LobbyConnectionEventType.connected:
        _authAttemptedAfterConnect = false;
        {
          final wasConnecting = state.connectionStatus == LobbyConnectionStatus.connecting;
          final wasReconnecting = state.connectionStatus == LobbyConnectionStatus.reconnecting ||
              state.connectionStatus == LobbyConnectionStatus.disconnected ||
              state.connectionStatus == LobbyConnectionStatus.failed;

          if (wasConnecting || wasReconnecting) {
            emit(state.copyWith(
              connectionStatus: LobbyConnectionStatus.connected,
              loadingPhase: state.pageStatus == LobbyPageStatus.loading
                  ? LobbyLoadingPhase.loadingAssets
                  : state.loadingPhase,
              transientNotice: wasReconnecting ? '大厅重连成功，正在同步数据...' : state.transientNotice,
              // 重连时清空待重发队列，避免重复发送旧消息
              pendingMessages: const {},
            ));
            if (_isLobbyEntered) {
              unawaited(_service.requestBroadcastCD());
            }

            // 首次连接或重连成功后，只要大厅处于 loading 状态就重新请求 assets+snapshot。
            // 排队中不请求（尚未加入 Match，消息无法送达）
            if (_isLobbyEntered && state.pageStatus == LobbyPageStatus.loading && _queueTicket == null) {
              _requestAssetsAndSnapshot();
            }
          }
        }
      case LobbyConnectionEventType.closed:
        // 被踢出时不显示重连提示（由 system.kicked 处理）
        if (state.kickedReason != null) return;
        if (state.connectionStatus != LobbyConnectionStatus.connecting) {
          // 断线时重置加载阶段，等待重连后重新开始
          emit(state.copyWith(
            connectionStatus: LobbyConnectionStatus.reconnecting,
            loadingPhase: LobbyLoadingPhase.connecting,
            transientNotice: '大厅连接断开，正在尝试重连...',
          ));
        }
      case LobbyConnectionEventType.error:
        if (state.connectionStatus != LobbyConnectionStatus.connecting) {
          emit(state.copyWith(
            connectionStatus: LobbyConnectionStatus.reconnecting,
            loadingPhase: LobbyLoadingPhase.connecting,
            transientNotice: '大厅连接异常，正在尝试重连...',
          ));
        }
    }
  }

  void _handleServerEvent(
    String type,
    pb.LobbyEnvelope envelope,
    Emitter<LobbyState> emit,
  ) {
    switch (type) {
      case 'login.success':
        // 登录成功（用户显式登录或匿名升级登录成功后服务端返回）
        // 不再自动请求 snapshot，客户端需主动请求
        final loginUserId = envelope.loginSuccessResponse.userId;
        final loginNickname = envelope.loginSuccessResponse.nickname;
        LogService.d('[LobbyBloc] login.success: userId=$loginUserId nickname=$loginNickname '
            '_selfServerUserId=$_selfServerUserId '
            'state.users=${state.users.map((u) => '${u.userId}:${u.nickname}:isSelf=${u.isSelf}').toList()}');

        // 标记已完成登录，防止 snapshot 补发逻辑重复触发
        _authAttemptedAfterConnect = true;

        // 更新 _selfServerUserId（需要先于 presence.join 处理）
        _selfServerUserId = loginUserId;

        // 迁移 state.users 中的旧匿名自己为新登录用户
        // 旧匿名自己：userId='self', isSelf=true, isAnonymous=true
        // 新用户 serverId = loginUserId
        var migratedUsers = state.users;
        if (loginUserId.isNotEmpty && loginUserId != _selfUserId) {
          // 查找旧匿名自己（userId='self' 且 isSelf=true）
          final oldSelfIdx = migratedUsers.indexWhere(
            (u) => u.userId == _selfUserId && u.isSelf,
          );
          if (oldSelfIdx >= 0) {
            // 替换为新的登录用户（保留 userId='self' 但更新所有登录信息）
            // 注意：LoginSuccessResponse 没有 avatarUrl 字段，保留原有值
            final oldSelf = migratedUsers[oldSelfIdx];
            migratedUsers = [
              ...migratedUsers.sublist(0, oldSelfIdx),
              oldSelf.copyWith(
                nickname: loginNickname.isNotEmpty ? loginNickname : oldSelf.nickname,
                isAnonymous: false,
                serverUserId: loginUserId,
              ),
              ...migratedUsers.sublist(oldSelfIdx + 1),
            ];
            LogService.d('[LobbyBloc] login.success 迁移匿名自己 -> 登录用户');
          }
        }

        emit(
          state.copyWith(
            users: migratedUsers,
            isAnonymous: false,
            transientNotice: state.isAnonymous ? '身份升级成功' : '登录成功',
          ),
        );

        // 登录成功后重新上报本地活动状态
        _lastSentStatusText = null;
        _updateStatusTextByGameStatus(GameStatusService().isGameRunning, emit);

        // 登录成功后主动绑定 Steam ID
        // steamProfileId 是 Steam64 格式（纯数字），从论坛账户信息中获取
        _bindSteamAfterLogin();

        // 注意：不需要请求 assets 和 snapshot，因为：
        // 1. presence.join 已经会更新用户数据（模型切换等）
        // 2. 已有 assets 数据足够使用
        // 3. 重新请求 snapshot 可能导致用户列表不一致
        break;
      case 'login.failed':
        _authAttemptedAfterConnect = false;
        final loginFailedReason = envelope.loginFailedResponse.reason;
        final loginFailedCode = envelope.loginFailedResponse.code;

        // 手机端被拒绝：PC 端已在线（409）
        // 使用 kicked 遮罩展示，让用户明确知道原因
        if (loginFailedCode == 409 && loginFailedReason == 'pc_session_active') {
          emit(
            state.copyWith(
              connectionStatus: LobbyConnectionStatus.connected,
              kickedReason: 'pc_session_active',
              kickedMessage: 'pc_session_active',
            ),
          );
        } else {
          emit(
            state.copyWith(
              connectionStatus: LobbyConnectionStatus.connected,
              transientNotice: loginFailedReason.isNotEmpty ? loginFailedReason : '登录失败，已保持匿名身份',
            ),
          );
        }
        break;
      case 'logout.success':
        final kick = envelope.logoutSuccessResponse.kick;
        if (kick) {
          // force=true：WebSocket 连接已断开，等待重连
          emit(state.copyWith(
            connectionStatus: LobbyConnectionStatus.disconnected,
            transientNotice: '已退出登录，连接已关闭',
          ));
        } else {
          // force=false：降级为匿名用户，刷新数据
          // 取消所有冷却计时器，保持状态干净
          _chatCooldownTimer?.cancel();
          _chatCooldownTimer = null;
          _broadcastCooldownTimer?.cancel();
          _broadcastCooldownTimer = null;
          _anonymousSwitchCooldownTimer?.cancel();
          _anonymousSwitchCooldownTimer = null;
          _steamNameSwitchCooldownTimer?.cancel();
          _steamNameSwitchCooldownTimer = null;

          // 清空 selfServerUserId，避免后续 snapshot 用旧实名 ID 识别 self
          _selfServerUserId = null;
          _lastSentStatusText = null;
          // 重置登录标志，允许用户重新登录时再次发送 login
          _authAttemptedAfterConnect = false;

          emit(state.copyWith(
            chatCooldownSeconds: 0,
            broadcastCooldownSeconds: 0,
            anonymousSwitchCooldownSeconds: 0,
            steamNameSwitchCooldownSeconds: 0,
            transientNotice: '已退出登录，保持匿名身份',
          ));
          if (_isLobbyEntered) {
            unawaited(_service.requestSnapshot());
          }
        }
        break;
      case 'join.success':
        // 从 join.success 中提取用户信息和当前地图 ID
        final joinResp = envelope.joinSuccessResponse;
        if (joinResp.hasUser()) {
          final userId = joinResp.user.userId;
          if (userId.isNotEmpty) {
            _selfServerUserId = userId;
            LogService.d('[LobbyBloc] join.success 设置 _selfServerUserId=$userId');
          }

          // 服务端因设备 UUID 关联了账号，把连接识别为已登录（isAnonymous=false），
          // 但客户端实际上没有登录——立即发送 logout 纠正，降级为匿名身份。
          // 在 join.success 阶段处理比等到 snapshot 更快，避免短暂以错误身份显示。
          if (!joinResp.user.isAnonymous && !AuthService.instance.isLoggedIn) {
            LogService.w('[LobbyBloc] join.success 检测到服务端身份与客户端不一致（服务端已登录但客户端未登录），立即发送 logout 纠正');
            unawaited(_service.logout(force: false));
          }
        }
        // 保存当前地图 ID（用于后续 assets 解析时确定当前地图）
        final mapId = joinResp.mapId;
        if (mapId.isNotEmpty) {
          _selfMapId = mapId;
          LogService.d('[LobbyBloc] join.success 设置 _selfMapId=$mapId');
        }
        // 从 join.success 中获取在线人数，直接更新面板按钮徽章
        if (joinResp.onlineCount > 0) {
          LogService.d('[LobbyBloc] join.success 在线人数: ${joinResp.onlineCount}');
          emit(state.copyWith(serverOnlineCount: joinResp.onlineCount));
        }
        // 不在这里请求 assets，等到进入大厅页面再请求（避免 URL token 过期）
        
        // 加入 Match 成功后请求一次在线人数，作为初始值
        // 后续由后端每次 presence 变化时自动推送 online.stats 更新
        if (_isLobbyEntered) {
          unawaited(_service.requestOnlineStats(includeUsers: false));
        }

        // 重新同步本地活动状态（防止启动时因为网络未连接导致首次上报丢失）
        _lastSentStatusText = null;
        _updateStatusTextByGameStatus(GameStatusService().isGameRunning, emit);
        break;
      case 'assets':
        {
          // 由于是在进入大厅页面后才请求 assets，这里收到说明正在加载中
          // 实际处理在 _requestAssetsAndSnapshot 中
          final rawAssets = _parseAssets(envelope.assetsResponse);

          // 如果 pageStatus 已经是 ready（从 snapshot 进入），刷新 assets
          if (state.pageStatus == LobbyPageStatus.ready) {
            final assets = _mergeAssetsWithCache(rawAssets);
            emit(
              state.copyWith(
                assets: assets,
              ),
            );
          }
          break;
        }
      case 'snapshot':
        {
          final previousSelf = state.selfUser;
          final snapshotState = _applySnapshot(envelope.snapshotResponse);
          final previousServerUserId = _selfServerUserId;
          final nextServerUserId = snapshotState.selfServerUserId;
          _selfServerUserId = nextServerUserId;

          // 如果 snapshot 中包含 mapConfig，优先使用它作为当前地图配置
          // 同时将 snapshot 的 mapConfig 合并到 assets.maps 中（如果 maps 数组中没有该地图）
          LobbyAssets updatedAssets = state.assets;
          bool mapChanged = false;
          final wasTeleporting = state.isTeleporting;
          LogService.d('[LobbyBloc] snapshot 处理: wasTeleporting=$wasTeleporting, current pageStatus=${state.pageStatus}');
          if (snapshotState.mapConfig != null) {
            final newMapConfig = snapshotState.mapConfig!;
            mapChanged = state.assets.mapConfig?.mapId != newMapConfig.mapId;
            LogService.d('[LobbyBloc] snapshot: mapChanged=$mapChanged, oldMapId=${state.assets.mapConfig?.mapId}, newMapId=${newMapConfig.mapId}');
            // 将新地图合并到 assets.maps 中（去重）
            final existingMapIds = updatedAssets.maps.map((m) => m.mapId).toSet();
            final additionalMaps = existingMapIds.contains(newMapConfig.mapId)
                ? <LobbyMapConfig>[]
                : [newMapConfig];
            updatedAssets = LobbyAssets(
              mapConfig: newMapConfig,
              maps: [...updatedAssets.maps, ...additionalMaps],
              sprites: updatedAssets.sprites,
            );
            LogService.d('[LobbyBloc] snapshot 应用地图配置: mapId=${newMapConfig.mapId}');
          }

          final upgradedFromAnonymous =
              previousSelf != null && previousSelf.isAnonymous && !snapshotState.isAnonymous;
          final serverIdentityChanged =
              previousServerUserId != null && nextServerUserId != null && previousServerUserId != nextServerUserId;

          // 处理分页逻辑
          // 如果正在加载更多页，合并用户列表；否则替换
          final List<LobbyUser> mergedUsers;
          if (state.isLoadingMore) {
            // 合并：保留现有用户，追加新用户（去重）
            final existingUserIds = state.users.map((u) => u.userId).toSet();
            final newUsers = snapshotState.users
                .where((u) => !existingUserIds.contains(u.userId))
                .toList();
            mergedUsers = [...state.users, ...newUsers];
          } else {
            mergedUsers = snapshotState.users;
          }

          // 如果用户已登录、token 有效，且还没发送过 login，则补发。
          // 不依赖 snapshotState.isAnonymous：服务端可能因 UUID 关联账号返回 isAnonymous=false，
          // 但客户端实际上还没发过 login（例如 WS 连接时 token 尚未就绪）。
          // 同时检查 isLoginPending：service 层已在等待 login 响应时不重复发送。
          if (!_authAttemptedAfterConnect &&
              AuthService.instance.isLoggedIn &&
              _service.hasValidToken &&
              !_service.isLoginPending) {
            _authAttemptedAfterConnect = true;
            LogService.i('[LobbyBloc] snapshot 补发 login（isAnonymous=${snapshotState.isAnonymous}）');
            unawaited(_service.login());
          }

          // 服务端因设备 UUID 关联了账号，返回 isAnonymous=false，
          // 但客户端实际上没有登录——主动发送 logout 纠正服务端状态。
          // 通常 join.success 阶段已经处理，这里作为兜底二次检查。
          if (!snapshotState.isAnonymous && !AuthService.instance.isLoggedIn) {
            LogService.w('[LobbyBloc] snapshot 检测到服务端身份与客户端不一致（服务端已登录但客户端未登录），发送 logout 纠正');
            unawaited(_service.logout(force: false));
          }

          // 检查是否需要加载更多分页
          final pageInfo = snapshotState.pageInfo;
          if (pageInfo != null && pageInfo.hasMore && !state.isLoadingMore) {
            // 请求下一页
            unawaited(_loadMoreUsers(pageInfo.currentPage + 1));
          }

          // 同步 selectedSpriteId（服务端知道用户上次用的模型）
          final selfUserSpriteId = mergedUsers
              .where((u) => u.isSelf && u.spriteId.isNotEmpty)
              .firstOrNull
              ?.spriteId;
          final newSelectedSpriteId = selfUserSpriteId ?? state.selectedSpriteId;

          // snapshot 收到时 assets 已经在 _requestAssetsAndSnapshot 中处理了
          // 首次 snapshot 收到后立即进入 ready 状态，分页加载不影响页面状态
          final isFirstSnapshot = state.pageStatus == LobbyPageStatus.loading;
          final notice = upgradedFromAnonymous || serverIdentityChanged
              ? '已从匿名身份升级为登录身份'
              : (snapshotState.isAnonymous ? '大厅就绪（匿名身份）' : '大厅就绪');

          emit(
            state.copyWith(
              // 首次收到 snapshot 时进入 ready，后续分页加载不影响 pageStatus
              pageStatus: isFirstSnapshot ? LobbyPageStatus.ready : state.pageStatus,
              users: mergedUsers,
              messages: state.isLoadingMore ? state.messages : snapshotState.messages,
              selectedSpriteId: newSelectedSpriteId,
              isAnonymous: snapshotState.isAnonymous,
              transientNotice: notice,
              pageInfo: pageInfo,
              isLoadingMore: false,
              assets: updatedAssets,
            ),
          );

          // 首次进入 ready 时启动定期 snapshot 对齐（presence.delta 最终一致性保障）
          if (isFirstSnapshot) {
            _startSnapshotAlignTimer();
          }

          // 如果地图发生变化且正在传送中，等待地图加载完成后完成传送
          if (mapChanged && wasTeleporting && snapshotState.mapConfig != null) {
            final newMapId = snapshotState.mapConfig!.mapId;
            LogService.d('[LobbyBloc] 传送中，地图切换到 $newMapId，等待地图加载完成');

            // 预加载新地图
            unawaited(LobbyMapLoaderService.instance.preloadMap(snapshotState.mapConfig!));

            // 等待地图加载完成后再触发传送完成
            // 注意：使用 microtask 确保状态先更新，再进行等待
            Future.microtask(() async {
              final loaded = await LobbyMapLoaderService.instance.waitForMapReady(newMapId);
              if (loaded) {
                LogService.d('[LobbyBloc] 地图 $newMapId 加载完成，触发传送完成');
              } else {
                LogService.w('[LobbyBloc] 地图 $newMapId 加载超时，但仍触发传送完成');
              }
              add(LobbyTeleportCompleted());
            });
          }

          // 重新同步本地活动状态（防止启动时的状态更新因连接未就绪被忽略）
          _lastSentStatusText = null;
          _updateStatusTextByGameStatus(GameStatusService().isGameRunning, emit);
        }
        break;
      case 'presence.join':
        // 尝试从 protobuf 中提取 userId 判断是否是自己
        final presenceJoinResp = envelope.presenceJoinResponse;
        final rawUserId = presenceJoinResp.user.userId;
        final isSelfUser = rawUserId.isNotEmpty && _selfServerUserId == rawUserId;
        final isCrossMap = presenceJoinResp.isCrossMapNotification;
        LogService.d('[LobbyBloc] presence.join: rawUserId=$rawUserId _selfServerUserId=$_selfServerUserId '
            'isSelfUser=$isSelfUser isCrossMap=$isCrossMap users=${state.users.map((u) => '${u.userId}:serverId=${u.serverUserId}:${u.nickname}').toList()}');

        if (isCrossMap) {
          // 跨地图通知：只显示"XX 上线了"，不渲染角色，坐标字段无效
          if (!isSelfUser) {
            final nickname = presenceJoinResp.user.nickname;
            final displayName = nickname.isNotEmpty ? nickname : rawUserId;
            final newNotification = PlayerNotification(
              id: 'online_notice_${DateTime.now().microsecondsSinceEpoch}',
              type: PlayerNotificationType.online,
              playerName: displayName,
              createdAt: DateTime.now(),
            );
            final updatedNotifications =
                [...state.playerNotifications, newNotification].take(20).toList();

            // 跨地图用户也需要同步到 allOnlineUsers（面板显示全服用户）
            if (state.allOnlineUsers.isNotEmpty) {
              final crossMapUser = _parseLobbyUser(
                presenceJoinResp.user,
                isSelf: false,
                serverUserId: rawUserId,
              );
              final crossMapUpdatedAll = _upsertUserInList(state.allOnlineUsers, crossMapUser);
              emit(state.copyWith(
                playerNotifications: updatedNotifications,
                allOnlineUsers: crossMapUpdatedAll,
              ));
            } else {
              emit(state.copyWith(playerNotifications: updatedNotifications));
            }
          }
          break;
        }

        final user = _parseLobbyUser(
          presenceJoinResp.user,
          isSelf: isSelfUser,
          serverUserId: rawUserId,
        );

        // 如果是自己，同步 selectedSpriteId（服务端知道用户上次用的模型）
        final newSelectedSpriteId = isSelfUser && user.spriteId.isNotEmpty
            ? user.spriteId
            : state.selectedSpriteId;

        // 构建玩家加入通知（自己加入时不显示通知；从其他地图传送过来时显示传送通知）
        final sourceMapId = presenceJoinResp.sourceMapId;
        final isFromTeleport = sourceMapId.isNotEmpty;
        PlayerNotification? newNotification;
        if (!isSelfUser) {
          if (isFromTeleport) {
            final sourceMapName = state.assets.getMapById(sourceMapId)?.displayName ?? sourceMapId;
            newNotification = PlayerNotification(
              id: 'teleport_in_${DateTime.now().microsecondsSinceEpoch}',
              type: PlayerNotificationType.teleportIn,
              playerName: user.displayName,
              sourceMapName: sourceMapName,
              createdAt: DateTime.now(),
            );
          } else {
            newNotification = PlayerNotification(
              id: 'join_${DateTime.now().microsecondsSinceEpoch}',
              type: PlayerNotificationType.online,
              playerName: user.displayName,
              createdAt: DateTime.now(),
            );
          }
        }

        // 更新通知列表（限制最多保留20条）
        final updatedNotifications = newNotification != null
            ? [...state.playerNotifications, newNotification].take(20).toList()
            : state.playerNotifications;

        // 同步更新 allOnlineUsers：将新加入的用户插入列表（如果面板已打开）
        final updatedAllOnlineUsers = _upsertUserInList(state.allOnlineUsers, user);

        emit(
          state.copyWith(
            users: _upsertUser(state.users, user),
            selectedSpriteId: newSelectedSpriteId,
            playerNotifications: updatedNotifications,
            allOnlineUsers: updatedAllOnlineUsers,
          ),
        );
        break;
      case 'presence.leave':
        final presenceLeaveResp = envelope.presenceLeaveResponse;
        final serverUserId = presenceLeaveResp.userId;
        if (serverUserId.isEmpty) break;
        // 通过 serverUserId 或 userId 查找离开的用户
        final leavingUser = _findUserById(state.users, serverUserId);

        // 获取 targetMapId 判断是传送离开还是断线离开
        final targetMapId = presenceLeaveResp.targetMapId;
        PlayerNotification? newNotification;

        if (leavingUser == null) {
          // 该用户不在本地图场景中 → 跨地图离线通知，只显示提示
          // 尝试用 serverUserId 作为显示名（无法获取昵称时降级显示 ID）
          // 实际上跨地图用户不在 users 列表中，所以只能显示简单提示
          LogService.d('[LobbyBloc] presence.leave: 跨地图离线通知 serverUserId=$serverUserId');
          // 跨地图用户虽然不在场景中，但可能在 allOnlineUsers 中，需要同步移除
          if (state.allOnlineUsers.isNotEmpty) {
            final crossMapUpdatedAll = state.allOnlineUsers
                .where((u) => u.serverUserId != serverUserId && u.userId != serverUserId)
                .toList(growable: false);
            if (crossMapUpdatedAll.length != state.allOnlineUsers.length) {
              emit(state.copyWith(allOnlineUsers: crossMapUpdatedAll));
            }
          }
          break;
        }

        // 用户在本地图场景中，正常移除
        final updatedUsers = state.users
            .where((user) => user.serverUserId != serverUserId && user.userId != serverUserId)
            .toList(growable: false);

        if (targetMapId.isNotEmpty) {
          // 传送离开：获取目标地图名称
          final targetMapName = state.assets.getMapById(targetMapId)?.displayName ?? targetMapId;
          newNotification = PlayerNotification(
            id: 'teleport_${DateTime.now().microsecondsSinceEpoch}',
            type: PlayerNotificationType.teleport,
            playerName: leavingUser.displayName,
            targetMapName: targetMapName,
            createdAt: DateTime.now(),
          );
        } else {
          // 断线/正常离开
          newNotification = PlayerNotification(
            id: 'leave_${DateTime.now().microsecondsSinceEpoch}',
            type: PlayerNotificationType.offline,
            playerName: leavingUser.displayName,
            createdAt: DateTime.now(),
          );
        }

        // 更新通知列表（限制最多保留20条）
        final updatedNotifications =
            [...state.playerNotifications, newNotification].take(20).toList();

        // 同步更新 allOnlineUsers：移除离开的用户
        final updatedAllOnlineUsers = state.allOnlineUsers
            .where((u) => u.serverUserId != serverUserId && u.userId != serverUserId)
            .toList(growable: false);

        emit(
          state.copyWith(
            users: updatedUsers,
            playerNotifications: updatedNotifications,
            allOnlineUsers: updatedAllOnlineUsers,
          ),
        );
        break;
      case 'identity.changed':
        // 某用户登录或退出登录时，服务端向其他所有用户广播此消息
        // 需要用 oldUserId 找到该用户，并用新身份信息（newUserId、nickname、isAnonymous 等）更新
        final identityResp = envelope.identityChangedResponse;
        final oldUserId = identityResp.oldUserId;
        final newUserId = identityResp.newUserId;
        final identityNickname = identityResp.nickname;
        final identityAvatarUrl = identityResp.avatarUrl;
        final identitySpriteId = identityResp.spriteId;
        final identityIsAnonymous = identityResp.isAnonymous;
        final identityBusinessUserId = identityResp.businessUserId;

        LogService.d('[LobbyBloc] identity.changed: oldUserId=$oldUserId newUserId=$newUserId '
            'nickname=$identityNickname isAnonymous=$identityIsAnonymous businessUserId=$identityBusinessUserId');

        if (oldUserId.isEmpty && newUserId.isEmpty) break;

        // 通过 oldUserId 找到对应用户并更新其身份信息
        final identityUpdatedUsers = state.users.map((user) {
          // 匹配条件：serverUserId 或 userId 与 oldUserId 相符
          final matches = (user.serverUserId != null && user.serverUserId == oldUserId) ||
              user.userId == oldUserId;
          if (!matches) return user;

          return user.copyWith(
            nickname: identityNickname.isNotEmpty ? identityNickname : user.nickname,
            avatarUrl: identityAvatarUrl.isNotEmpty ? identityAvatarUrl : user.avatarUrl,
            spriteId: identitySpriteId.isNotEmpty ? identitySpriteId : user.spriteId,
            isAnonymous: identityIsAnonymous,
            // 更新 serverUserId 为新的 userId（退出登录后变为匿名 UUID）
            serverUserId: newUserId.isNotEmpty ? newUserId : user.serverUserId,
            // 更新 businessUserId（登出时为空字符串，登录时为新业务 ID）
            businessUserId: identityBusinessUserId.isEmpty ? null : identityBusinessUserId,
          );
        }).toList(growable: false);

        emit(state.copyWith(users: identityUpdatedUsers));
        break;
      case 'move.broadcast':
        var updatedUsers = _applyMoveBroadcast(state.users, envelope.moveBroadcastResponse);

        // 检查是否到达了 pendingPortal 附近
        final pendingPortal = state.pendingPortal;
        if (pendingPortal != null) {
          final selfUser = updatedUsers.where((u) => u.isSelf).firstOrNull;
          if (selfUser != null) {
            // 检查玩家是否到达 pendingPortal 附近
            final dx = selfUser.position.x - pendingPortal.x;
            final dy = selfUser.position.y - pendingPortal.y;
            final distanceSquared = dx * dx + dy * dy;

            const interactionRange = 120.0;
            const interactionRangeSquared = interactionRange * interactionRange;

            if (distanceSquared <= interactionRangeSquared) {
              // 到达 pendingPortal 附近，显示对话框
              emit(state.copyWith(
                users: updatedUsers,
                nearbyPortal: pendingPortal,
                clearPendingPortal: true,
              ));
              _startMovementTimer();
              return;
            }
          }
        }

        emit(state.copyWith(users: updatedUsers));
        _startMovementTimer();
        break;
      case 'move.reject':
        final moveRejectResp = envelope.moveRejectResponse;
        emit(
          state.copyWith(
            users: _applyMoveReject(state.users, moveRejectResp),
            transientNotice: moveRejectResp.reason.isNotEmpty ? moveRejectResp.reason : '移动请求被拒绝',
          ),
        );
        break;
      case 'chat.message':
        final nextState = _applyChatMessage(envelope.chatMessageResponse);
        LogService.d('[LobbyBloc] chat.message: users=${nextState.users.map((u) => '${u.userId}:lastMsg=${u.lastMessage != null ? '"${u.lastMessage}"' : null}').toList()}');

        emit(
          state.copyWith(
            users: nextState.users,
            messages: nextState.messages,
          ),
        );
        _scheduleBubbleCleanup();
        break;
      case 'chat.reject':
        final chatRejectResp = envelope.chatRejectResponse;
        emit(
          state.copyWith(
            transientNotice: chatRejectResp.reason.isNotEmpty ? chatRejectResp.reason : '消息发送失败',
          ),
        );
        // 注意：这里不重发，因为不知道具体哪条被拒绝
        break;
      case 'profile.sprite.changed':
        final spriteChangedResp = envelope.spriteChangedResponse;
        final nextUsers = _applySpriteChanged(state.users, spriteChangedResp);
        final changedSpriteId = spriteChangedResp.spriteId;
        final changedUserId = spriteChangedResp.userId;
        emit(
          state.copyWith(
            users: nextUsers,
            selectedSpriteId: _isSelfServerUserId(changedUserId) && changedSpriteId.isNotEmpty
                ? changedSpriteId
                : state.selectedSpriteId,
          ),
        );
        break;
      case 'profile.sprite.change.success':
        // 服务端确认切换成功，同步到服务端确认的 spriteId
        final successResp = envelope.spriteChangeSuccessResponse;
        final confirmedSpriteId = successResp.spriteId;

        if (confirmedSpriteId.isNotEmpty) {
          _previousSpriteId = confirmedSpriteId;

          // 如果当前 state 与服务端确认的不一致（reject 回滚后又收到了之前的 success），
          // 同步到服务端确认值
          if (state.selectedSpriteId != confirmedSpriteId) {
            emit(
              state.copyWith(
                selectedSpriteId: confirmedSpriteId,
                isSpriteChangePending: false,
                users: state.users
                    .map(
                      (user) => user.isSelf ? user.copyWith(spriteId: confirmedSpriteId) : user,
                    )
                    .toList(growable: false),
              ),
            );
          } else {
            emit(state.copyWith(isSpriteChangePending: false));
          }
        } else {
          _previousSpriteId = state.selectedSpriteId;
          emit(state.copyWith(isSpriteChangePending: false));
        }
        break;
      case 'profile.sprite.change.reject':
        final spriteRejectResp = envelope.spriteChangeRejectResponse;
        final reason = spriteRejectResp.reason;
        String message;
        switch (reason) {
          case 'invalid_sprite_id':
            message = '该角色外观不可用';
            break;
          case 'invalid_payload':
            message = '角色外观切换请求格式错误';
            break;
          case 'anonymous_user_not_allowed':
            message = '匿名用户无法更换角色外观';
            break;
          case 'rate_limited':
            message = '切换过于频繁，请稍后再试';
            break;
          default:
            message = '角色外观切换失败';
        }

        // 回滚到切换前的 spriteId
        final rollbackSpriteId = _previousSpriteId;
        _previousSpriteId = null;

        if (rollbackSpriteId != null && rollbackSpriteId != state.selectedSpriteId) {
          emit(
            state.copyWith(
              selectedSpriteId: rollbackSpriteId,
              isSpriteChangePending: false,
              users: state.users
                  .map(
                    (user) => user.isSelf ? user.copyWith(spriteId: rollbackSpriteId) : user,
                  )
                  .toList(growable: false),
              transientNotice: message,
            ),
          );
        } else {
          emit(
            state.copyWith(
              isSpriteChangePending: false,
              transientNotice: message,
            ),
          );
        }
        break;
      case 'profile.anonymous.changed':
        final anonChangedResp = envelope.anonymousChangedResponse;
        final nextUsers = _applyAnonymousChanged(state.users, anonChangedResp);
        final userId = anonChangedResp.userId;
        final isAnonymous = anonChangedResp.isAnonymous;

        // 清除 anonymous 设置项的 pending 状态
        final updatedPending = Map<String, bool>.from(state.pendingSettings);
        updatedPending.remove('anonymous');
        final updatedTimeouts = Map<String, DateTime>.from(state.pendingSettingsTimeouts);
        updatedTimeouts.remove('anonymous');

        emit(
          state.copyWith(
            users: nextUsers,
            isAnonymous: _isSelfServerUserId(userId) ? isAnonymous : state.isAnonymous,
            pendingSettings: updatedPending,
            pendingSettingsTimeouts: updatedTimeouts,
          ),
        );
        break;
      case 'system.notice':
        final systemNoticeResp = envelope.systemNoticeResponse;
        final notice = systemNoticeResp.message;
        if (notice.isEmpty) break;
        emit(
          state.copyWith(
            messages: _limitMessages([...state.messages, _buildSystemMessage(notice)]),
            transientNotice: notice,
          ),
        );
        break;
      case 'system.error':
        final systemErrorResp = envelope.systemErrorResponse;
        final code = systemErrorResp.code;
        final message = systemErrorResp.message.isNotEmpty ? systemErrorResp.message : '大厅服务暂时不可用';
        emit(
          state.copyWith(
            connectionStatus: code == 409 ? LobbyConnectionStatus.disconnected : LobbyConnectionStatus.failed,
            transientNotice: message,
          ),
        );
        break;
      case 'system.kicked':
        final systemKickedResp = envelope.systemKickedResponse;
        final reason = systemKickedResp.reason.isNotEmpty ? systemKickedResp.reason : 'unknown';
        final message = systemKickedResp.message.isNotEmpty ? systemKickedResp.message : null;
        LogService.w('[LobbyBloc] 收到 system.kicked: reason=$reason message=$message');

        // 取消所有定时器
        _movementTimer?.cancel();
        _movementTimer = null;
        _chatCooldownTimer?.cancel();
        _chatCooldownTimer = null;
        _broadcastCooldownTimer?.cancel();
        _broadcastCooldownTimer = null;
        _anonymousSwitchCooldownTimer?.cancel();
        _anonymousSwitchCooldownTimer = null;
        _steamNameSwitchCooldownTimer?.cancel();
        _steamNameSwitchCooldownTimer = null;

        emit(state.copyWith(
          connectionStatus: LobbyConnectionStatus.disconnected,
          kickedReason: reason,
          kickedMessage: message,
        ));
        break;
      case 'portal.teleport':
        final portalTeleportResp = envelope.portalTeleportResponse;
        final portalKey = portalTeleportResp.portalKey;
        final label = portalTeleportResp.label.isNotEmpty ? portalTeleportResp.label : '未知传送点';
        final sourceMapId = portalTeleportResp.sourceMapId;
        final targetMapId = portalTeleportResp.targetMapId;
        final targetX = portalTeleportResp.targetX;
        final targetY = portalTeleportResp.targetY;
        if (portalKey.isNotEmpty && targetMapId.isNotEmpty) {
          final target = LobbyTeleportTarget(
            portalKey: portalKey,
            label: label,
            sourceMapId: sourceMapId,
            targetMapId: targetMapId,
            targetX: targetX,
            targetY: targetY,
          );

          // 更新当前地图 ID（用于后续 assets 解析）
          _selfMapId = targetMapId;

          add(LobbyTeleportStarted(target));

          // 尝试从已有的 maps 中找到目标地图并预加载
          final targetMapConfig = state.assets.getMapById(targetMapId);
          if (targetMapConfig != null) {
            LogService.d('[LobbyBloc] portal.teleport: 预加载目标地图 $targetMapId');
            unawaited(LobbyMapLoaderService.instance.preloadMap(targetMapConfig));
          } else {
            LogService.d('[LobbyBloc] portal.teleport: 目标地图配置尚未加载，等待 snapshot');
          }
          // snapshot 由 join.success 触发后自动请求，不在此处主动发送
        }
        break;
      case 'portal.use.reject':
        final portalRejectResp = envelope.portalUseRejectResponse;
        final reject = LobbyPortalReject.fromProtobuf(portalRejectResp);
        LogService.w('[LobbyBloc] 传送门请求被拒绝: ${reject.reasonType.displayText}');
        emit(state.copyWith(
          // 乐观传送被拒绝，重置传送状态
          isTeleporting: false,
          clearTeleportTarget: true,
          transientNotice: reject.reasonType.displayText,
          clearNearbyPortal: true,
          clearPendingPortal: true,
        ));
        break;
      case 'profile.statusText.broadcast':
        final statusTextResp = envelope.statusTextBroadcastResponse;
        final userId = statusTextResp.userId;
        final statusText = statusTextResp.statusText;
        if (userId.isNotEmpty) {
          final normalizedUserId = _normalizeUserId(userId);
          emit(
            state.copyWith(
              users: state.users
                  .map((user) => (user.userId == normalizedUserId || user.serverUserId == userId)
                      ? user.copyWith(statusText: statusText)
                      : user)
                  .toList(growable: false),
            ),
          );
        }
        break;
      case 'profile.displayName.changed':
        final displayNameResp = envelope.displayNameChangedResponse;
        final userId = displayNameResp.userId;
        final nickname = displayNameResp.nickname;
        if (userId.isNotEmpty && nickname.isNotEmpty) {
          final normalizedUserId = _normalizeUserId(userId);
          final nextUsers = state.users.map((user) {
            return (user.userId == normalizedUserId || user.serverUserId == userId)
                ? user.copyWith(nickname: nickname)
                : user;
          }).toList(growable: false);

          Map<String, bool> updatedPending = state.pendingSettings;
          Map<String, DateTime> updatedTimeouts = state.pendingSettingsTimeouts;
          if (_isSelfServerUserId(userId)) {
            updatedPending = Map<String, bool>.from(state.pendingSettings)..remove('useSteamName');
            updatedTimeouts = Map<String, DateTime>.from(state.pendingSettingsTimeouts)..remove('useSteamName');
          }

          emit(
            state.copyWith(
              users: nextUsers,
              pendingSettings: updatedPending,
              pendingSettingsTimeouts: updatedTimeouts,
            ),
          );
        }
        break;
      case 'assets.updated':
        final assetsUpdatedResp = envelope.assetsUpdatedResponse;
        final updateType = assetsUpdatedResp.updateType.isNotEmpty ? assetsUpdatedResp.updateType : 'all';
        final message = assetsUpdatedResp.message.isNotEmpty ? assetsUpdatedResp.message : '素材已更新';
        LogService.i('[LobbyBloc] 收到素材更新通知: updateType=$updateType, message=$message');

        // 静默处理素材更新，只在日志中记录
        // 主动请求最新素材
        if (_isLobbyEntered) {
          unawaited(_service.requestAssets());
        }
        break;
      case 'broadcast.message':
        final broadcastMsgResp = envelope.broadcastMessageResponse;
        final broadcast = _parseBroadcastMessage(broadcastMsgResp.message);
        // 将广播消息转换为 LobbyMessage 并添加到聊天栏
        final broadcastLobbyMessage = LobbyMessage(
          messageId: broadcast.messageId,
          userId: broadcast.userId,
          nickname: broadcast.nickname,
          content: broadcast.content,
          type: LobbyMessageType.broadcast,
          timestamp: broadcast.timestamp,
          isAnonymous: false,
        );
        final updatedMessages = _limitMessages([...state.messages, broadcastLobbyMessage]);

        // 通过 Stream 通知 GlobalBroadcastBar 显示右下角广播通知卡片（桌面端使用）
        _broadcastController.add(broadcast);

        // 根据设置选择通知方式
        final rawIndex = StorageUtils.getInt('broadcast_notification_type') ?? 0;
        final safeIndex = rawIndex.clamp(0, BroadcastNotificationType.values.length - 1);
        final broadcastNotificationType = BroadcastNotificationType.values[safeIndex];

        if (broadcastNotificationType == BroadcastNotificationType.system) {
          unawaited(
            BroadcastNotificationService.instance.showBroadcastNotification(
              sender: broadcast.nickname,
              content: broadcast.content,
              avatarUrl: broadcast.avatarUrl,
            ),
          );
        } else {
          // 软件内浮窗通知
          NotificationWindowService().showBroadcastNotification(
            nickname: broadcast.nickname,
            content: broadcast.content,
          );
        }

        emit(state.copyWith(messages: updatedMessages));
        break;
      case 'broadcast.cd':
        final broadcastCdResp = envelope.broadcastCdResponse;
        final inCooldown = broadcastCdResp.inCooldown;
        final remainingMs = broadcastCdResp.remainingMs.toInt();
        if (inCooldown && remainingMs > 0) {
          // 取消旧的冷却倒计时
          _broadcastCooldownTimer?.cancel();
          // 服务器返回冷却中，设置剩余秒数并启动倒计时
          final remainingSeconds = (remainingMs / 1000).ceil();
          emit(state.copyWith(broadcastCooldownSeconds: remainingSeconds));
          _broadcastCooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
            add(const _LobbyBroadcastCooldownTick());
          });
        } else {
          // 不在冷却中
          _broadcastCooldownTimer?.cancel();
          _broadcastCooldownTimer = null;
          emit(state.copyWith(broadcastCooldownSeconds: 0));
        }
        break;
      case 'broadcast.reject':
        // 取消可能正在运行的冷却倒计时
        _broadcastCooldownTimer?.cancel();
        _broadcastCooldownTimer = null;

        final broadcastRejectResp = envelope.broadcastRejectResponse;
        final reason = broadcastRejectResp.reason.isNotEmpty ? broadcastRejectResp.reason : '广播发送失败';

        // 注意：BroadcastRejectResponse 只有 reason 字段，没有 remainingMs
        // 如果需要冷却时间，应该由服务器通过 broadcast.cd 消息单独发送
        emit(state.copyWith(
          transientNotice: reason,
          broadcastCooldownSeconds: 0,
        ));
        break;
      case 'online.stats':
        {
          final onlineStatsResp = envelope.onlineStatsResponse;
          final total = onlineStatsResp.total;
          final List<LobbyUser> parsedUsers = [];
          bool selfFound = false;

          for (final pbUser in onlineStatsResp.users) {
            // online.stats 返回的用户列表中，每个用户的 userId 就是其唯一标识
            // 需要判断是否是自己
            final userId = pbUser.userId;
            final isSelfUser = userId.isNotEmpty && _isSelfServerUserId(userId);
            if (isSelfUser) selfFound = true;
            final user = _parseLobbyUser(pbUser, isSelf: isSelfUser, serverUserId: userId);
            parsedUsers.add(user);
          }

          // 如果服务端返回的列表中没有自己，从本地 state.users 补充
          // 避免匿名用户或 _selfServerUserId 尚未就绪时自己从面板消失
          if (!selfFound) {
            final localSelf = state.selfUser;
            if (localSelf != null && localSelf.isOnline) {
              parsedUsers.insert(0, localSelf);
              LogService.d('[LobbyBloc] online.stats: self not found in server list, injected from local state');
            }
          }

          LogService.d('[LobbyBloc] online.stats: total=$total, users=${parsedUsers.length}, selfFound=$selfFound');

          emit(state.copyWith(
            allOnlineUsers: parsedUsers,
            isLoadingAllOnlineUsers: false,
            serverOnlineCount: total,
          ));
        }
        break;
      case 'profile.steam.bind.success':
        final steamBindResp = envelope.steamBindSuccessResponse;
        final steamId = steamBindResp.steamId;
        final steamName = steamBindResp.steamName;
        final displayNickname = steamBindResp.displayNickname;
        LogService.i('[LobbyBloc] profile.steam.bind.success: steamId=$steamId steamName=$steamName displayNickname=$displayNickname');
        // 更新自身用户的昵称（如果 displayNickname 有变化）
        if (displayNickname.isNotEmpty) {
          final updatedUsers = state.users.map((user) {
            if (user.isSelf) {
              return user.copyWith(nickname: displayNickname);
            }
            return user;
          }).toList(growable: false);
          emit(state.copyWith(users: updatedUsers));
        }
        break;
      case 'presence.delta':
        _handlePresenceDelta(envelope.presenceDeltaResponse, emit);
        break;
      case 'queue.started':
        // 排队开始事件（由 service 层构造的虚拟事件）
        // 实际处理在 _onWsEventReceived 中通过 LobbyServerEvent 的 queue 字段
        break;
    }
  }

  void _startMovementTimer() {
    _movementTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      add(const LobbyMovementTicked());
    });
  }

  void _scheduleBubbleCleanup() {
    _bubbleExpiryTimer?.cancel();
    _bubbleExpiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(const LobbyBubbleExpired());
    });
  }

  /// 通过 serverUserId 判断两个用户是否为同一人
  /// 优先用 serverUserId 唯一标识匹配；回退到 userId
  bool _matchesServerUserId(LobbyUser existing, LobbyUser target) {
    // 情况1：target 有 serverUserId，尝试用它匹配
    if (target.serverUserId != null) {
      return existing.serverUserId == target.serverUserId ||
          existing.userId == target.serverUserId ||
          existing.serverUserId == target.userId;
    }
    // 情况2：target 无 serverUserId，回退到 userId 匹配
    return existing.userId == target.userId;
  }

  /// 通过 serverUserId 或 userId 查找用户
  LobbyUser? _findUserById(List<LobbyUser> users, String serverUserId) {
    // 先用 serverUserId 查找
    for (final user in users) {
      if (user.serverUserId == serverUserId) return user;
    }
    // 回退到 userId 查找
    for (final user in users) {
      if (user.userId == serverUserId) return user;
    }
    return null;
  }

  List<LobbyUser> _replaceUser(List<LobbyUser> users, LobbyUser targetUser) {
    return users
        .map((user) => _matchesServerUserId(user, targetUser) ? targetUser : user)
        .toList(growable: false);
  }

  List<LobbyUser> _upsertUser(List<LobbyUser> users, LobbyUser targetUser) {
    final exists = users.any((user) => _matchesServerUserId(user, targetUser));
    if (!exists) {
      return [...users, targetUser];
    }
    return _replaceUser(users, targetUser);
  }

  /// 在 allOnlineUsers 列表中插入或更新用户（用于 presence.join 实时同步）
  List<LobbyUser> _upsertUserInList(List<LobbyUser> users, LobbyUser targetUser) {
    if (users.isEmpty) return users; // 面板未加载过数据时不主动插入
    return _upsertUser(users, targetUser);
  }

  // ---------------------------------------------------------------------------
  // 解析方法
  // ---------------------------------------------------------------------------

  /// 从 protobuf 解析 assets（地图配置 + 角色贴图）
  ///
  /// [pbAssets] protobuf AssetsResponse 对象
  /// [skipCache] 是否跳过缓存（用于 snapshot 消息中的 assets）
  /// [currentMapId] 当前地图 ID，用于从 maps 数组中选择当前地图
  LobbyAssets _parseAssets(
    pb.AssetsResponse pbAssets, {
    bool skipCache = false,
    String? currentMapId,
  }) {
    // 从 protobuf maps 数组解析
    final List<LobbyMapConfig> parsedMaps = [];
    for (final pbMap in pbAssets.maps) {
      final mapConfig = _parseMapConfig(pbMap);
      parsedMaps.add(mapConfig);
    }

    // 确定当前地图：如果指定了 currentMapId，从 maps 中查找；否则使用第一个
    LobbyMapConfig? currentMap;
    if (currentMapId != null) {
      currentMap = parsedMaps.cast<LobbyMapConfig?>().firstWhere(
        (m) => m?.mapId == currentMapId,
        orElse: () => parsedMaps.isNotEmpty ? parsedMaps.first : null,
      );
    } else {
      currentMap = parsedMaps.isNotEmpty ? parsedMaps.first : null;
    }
    LogService.d('[LobbyBloc] _parseAssets: currentMapId=$currentMapId resolved=${currentMap?.mapId} '
        'availableMaps=${parsedMaps.map((m) => m.mapId).toList()}');

    final sprites = <LobbySprite>[];
    for (final pbSprite in pbAssets.sprites) {
      final sprite = _parseLobbySprite(pbSprite);
      sprites.add(sprite);
    }

    // 如果 protobuf 中没有 sprites，保留现有的 assets
    final hasNewSprites = sprites.isNotEmpty;
    final existingSprites = (!hasNewSprites && state.assets.sprites.isNotEmpty)
        ? state.assets.sprites
        : sprites;

    // 合并已有的 maps（如果新的 maps 为空）
    final List<LobbyMapConfig> allMaps;
    if (parsedMaps.isEmpty && state.assets.maps.isNotEmpty) {
      allMaps = state.assets.maps;
    } else if (parsedMaps.isNotEmpty && state.assets.maps.isNotEmpty) {
      // 合并：保留新 maps，追加旧 maps 中不重复的
      final newMapIds = parsedMaps.map((m) => m.mapId).toSet();
      final additionalMaps = state.assets.maps
          .where((m) => !newMapIds.contains(m.mapId))
          .toList();
      allMaps = [...parsedMaps, ...additionalMaps];
    } else {
      allMaps = parsedMaps;
    }

    final assets = LobbyAssets(
      mapConfig: currentMap ?? state.assets.mapConfig,
      maps: allMaps,
      sprites: existingSprites,
    );

    // 缓存素材 URL 到磁盘（仅当有实际数据时）
    if (!skipCache && assets.isReady) {
      unawaited(_cacheAssets(assets));
    }

    return assets;
  }

  /// 缓存素材 URL 到磁盘（用于跨会话复用）
  Future<void> _cacheAssets(LobbyAssets assets) async {
    try {
      if (assets.sprites.isNotEmpty) {
        await LobbyAssetCacheService.instance.cacheSprites(assets.sprites);
      }
      // 缓存所有地图
      for (final mapConfig in assets.maps) {
        await LobbyAssetCacheService.instance.cacheMap(mapConfig);
      }
    } catch (e) {
      LogService.e('[LobbyBloc] 缓存素材失败', e);
    }
  }

  /// 使用缓存的 URL 补充 assets（解决 URL 过期问题）
  LobbyAssets _mergeAssetsWithCache(LobbyAssets assets) {
    // 合并 maps
    final mergedMaps = assets.maps.map((map) {
      return LobbyAssetCacheService.instance.mergeMapWithCache(map) ?? map;
    }).toList();

    // 确定当前地图
    LobbyMapConfig? currentMap;
    if (assets.mapConfig != null) {
      currentMap = LobbyAssetCacheService.instance.mergeMapWithCache(assets.mapConfig!);
    }

    return LobbyAssets(
      mapConfig: currentMap ?? assets.mapConfig,
      maps: mergedMaps,
      sprites: LobbyAssetCacheService.instance.mergeWithCache(assets.sprites),
    );
  }

  /// 将 snapshot 中的 assets（可能只有 mapConfig）与之前 assets 事件的 sprites 合并
  /// 解析地图配置（从 protobuf 类型）
  LobbyMapConfig _parseMapConfig(pb.LobbyMapConfig pbMap) {
    final areas = <LobbyWalkableArea>[];
    for (final pbArea in pbMap.walkableAreas) {
      areas.add(LobbyWalkableArea.fromRect(
        left: pbArea.left,
        top: pbArea.top,
        right: pbArea.right,
        bottom: pbArea.bottom,
      ));
    }

    // 解析传送点
    final portals = <LobbyPortal>[];
    for (final pbPortal in pbMap.portals) {
      final portal = _parseLobbyPortal(pbPortal);
      portals.add(portal);
    }

    final label = pbMap.label.isNotEmpty ? pbMap.label : pbMap.mapId;
    return LobbyMapConfig(
      mapId: pbMap.mapId,
      displayName: label,
      backgroundUrl: pbMap.backgroundUrl.isEmpty ? null : pbMap.backgroundUrl,
      width: pbMap.width,
      height: pbMap.height,
      walkableAreas: areas.isEmpty
          ? const [LobbyWalkableArea(left: 0, top: 0, width: 1600, height: 900)]
          : areas,
      portals: portals,
    );
  }

  /// 解析传送点（从 protobuf 类型）
  LobbyPortal _parseLobbyPortal(pb.LobbyPortal pbPortal) {
    return LobbyPortal(
      key: pbPortal.key,
      label: pbPortal.label,
      x: pbPortal.x,
      y: pbPortal.y,
      targetMapId: pbPortal.targetMapId,
      targetX: pbPortal.targetX,
      targetY: pbPortal.targetY,
    );
  }

  /// 解析角色贴图（从 protobuf 类型）
  LobbySprite _parseLobbySprite(pb.LobbySpriteConfig pbSprite) {
    final accentColor = _parseHexColor(pbSprite.accentColor) ?? const Color(0xFF60A5FA);

    return LobbySprite(
      id: pbSprite.id,
      label: pbSprite.label.isNotEmpty ? pbSprite.label : pbSprite.id,
      accentColor: accentColor,
      spriteUrl: pbSprite.spriteUrl.isEmpty ? null : pbSprite.spriteUrl,
      previewUrl: pbSprite.previewUrl.isEmpty ? null : pbSprite.previewUrl,
      isDefault: pbSprite.isDefault,
    );
  }

  /// 解析用户信息（从 protobuf 类型）
  LobbyUser _parseLobbyUser(
    pb.LobbyUser pbUser, {
    required bool isSelf,
    String? serverUserId,
  }) {
    return LobbyUser(
      userId: isSelf ? _selfUserId : pbUser.userId,
      serverUserId: serverUserId,
      businessUserId: pbUser.businessUserId.isEmpty ? null : pbUser.businessUserId,
      nickname: pbUser.nickname,
      spriteId: pbUser.spriteId,
      avatarUrl: pbUser.avatarUrl.isEmpty ? null : pbUser.avatarUrl,
      position: LobbyPosition(x: pbUser.x, y: pbUser.y),
      facing: _parseFacing(pbUser.facing),
      isMoving: false, // protobuf 中没有 isMoving 字段
      isOnline: pbUser.isOnline,
      isAnonymous: pbUser.isAnonymous,
      isSelf: isSelf,
      statusText: pbUser.statusText.isEmpty ? null : pbUser.statusText,
      lastMessage: pbUser.lastMessage.isEmpty ? null : pbUser.lastMessage,
      lastMessageAt: null, // protobuf 中没有 lastMessageAt 字段
    );
  }

  /// 解析消息（从 protobuf 类型）
  LobbyMessage _parseLobbyMessage(pb.LobbyMessage pbMsg) {
    final type = _parseMessageType(pbMsg.type);
    // 如果 timestamp 为 0，使用当前时间作为兜底，确保消息不丢失
    final timestamp = pbMsg.timestamp.toInt() > 0
        ? DateTime.fromMillisecondsSinceEpoch(pbMsg.timestamp.toInt())
        : DateTime.now();

    return LobbyMessage(
      messageId: pbMsg.messageId,
      userId: pbMsg.userId,
      nickname: pbMsg.nickname,
      content: pbMsg.content,
      type: type,
      timestamp: timestamp,
      isAnonymous: pbMsg.isAnonymous,
    );
  }

  /// 构建系统消息
  LobbyMessage _buildSystemMessage(String content) {
    final now = DateTime.now();
    return LobbyMessage(
      messageId: 'system_${now.microsecondsSinceEpoch}',
      userId: 'system',
      nickname: '系统',
      content: content,
      type: LobbyMessageType.system,
      timestamp: now,
    );
  }

  /// 限制消息列表最多 100 条（保留最新的）
  static const int _maxMessages = 100;
  List<LobbyMessage> _limitMessages(List<LobbyMessage> messages) {
    if (messages.length <= _maxMessages) return messages;
    return messages.sublist(messages.length - _maxMessages);
  }

  /// 解析 Hex 颜色
  Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      final value = int.tryParse('FF$cleaned', radix: 16);
      if (value != null) return Color(value);
    } else if (cleaned.length == 8) {
      final value = int.tryParse(cleaned, radix: 16);
      if (value != null) return Color(value);
    }
    return null;
  }

  /// 解析朝向
  LobbyFacing _parseFacing(String? value) {
    return switch (value) {
      'left' => LobbyFacing.left,
      'right' => LobbyFacing.right,
      'up' => LobbyFacing.up,
      'down' => LobbyFacing.down,
      _ => LobbyFacing.left,
    };
  }

  /// 解析消息类型
  LobbyMessageType _parseMessageType(String? value) {
    switch (value) {
      case 'system':
        return LobbyMessageType.system;
      case 'broadcast':
        return LobbyMessageType.broadcast;
      default:
        return LobbyMessageType.user;
    }
  }

  // ---------------------------------------------------------------------------
  // Apply 方法（将解析结果应用到状态）
  // ---------------------------------------------------------------------------

  List<LobbyUser> _applyMoveBroadcast(
    List<LobbyUser> users,
    pb.MoveBroadcastResponse pbMove,
  ) {
    final serverUserId = pbMove.userId;
    if (serverUserId.isEmpty) return users;
    final target = LobbyPosition(x: pbMove.targetX, y: pbMove.targetY);
    final facing = _parseFacing(pbMove.facing);

    // 通过 serverUserId 或 userId 查找目标用户
    final idx = users.indexWhere(
      (u) => u.serverUserId == serverUserId || u.userId == serverUserId,
    );
    if (idx < 0) return users;

    return [
      ...users.sublist(0, idx),
      users[idx].copyWith(
        targetPosition: target,
        facing: facing,
        isMoving: true,
      ),
      ...users.sublist(idx + 1),
    ];
  }

  List<LobbyUser> _applyMoveReject(
    List<LobbyUser> users,
    pb.MoveRejectResponse pbReject,
  ) {
    final corrected = LobbyPosition(x: pbReject.correctionX, y: pbReject.correctionY);

    return users.map((user) {
      if (!user.isSelf) return user;
      return user.copyWith(
        position: corrected,
        renderPosition: corrected,
        targetPosition: null,
        isMoving: false,
      );
    }).toList(growable: false);
  }

  _SnapshotState _applySnapshot(pb.SnapshotResponse pbSnapshot) {
    final selfServerUserId = pbSnapshot.hasSelf() ? pbSnapshot.self.userId : null;
    final self = pbSnapshot.hasSelf() 
        ? _parseLobbyUser(pbSnapshot.self, isSelf: true, serverUserId: selfServerUserId)
        : null;

    // selfServerUserId 必须直接从原始 protobuf 获取，因为 _parseLobbyUser 已经将 self 的 userId 转换为 'self'

    final users = <LobbyUser>[];
    if (self != null) {
      users.add(self);
    }

    // 注意：pbSnapshot.users 中已经包含了当前用户（通过 userId 匹配），
    // 需要排除 self，避免渲染两个自己的角色。
    // 使用 selfServerUserId 来识别并排除。
    for (final pbUser in pbSnapshot.users) {
      // 检查是否与 self 是同一个用户（通过原始 userId 匹配）
      final itemUserId = pbUser.userId;
      if (selfServerUserId != null && selfServerUserId.isNotEmpty && itemUserId == selfServerUserId) {
        continue; // 跳过 self，避免重复渲染
      }
      final user = _parseLobbyUser(pbUser, isSelf: false, serverUserId: itemUserId);
      users.add(user);
    }

    final recentMessages = <LobbyMessage>[];
    for (final pbMsg in pbSnapshot.recentMessages) {
      final message = _parseLobbyMessage(pbMsg);
      recentMessages.add(message);
    }

    final selectedSpriteId = state.selectedSpriteId;
    final isAnonymous = self?.isAnonymous ?? state.isAnonymous;

    // 解析分页信息
    final pageInfo = pbSnapshot.hasPageInfo() ? _parsePageInfo(pbSnapshot.pageInfo) : null;

    // 解析地图配置（snapshot 中包含当前地图的完整配置）
    final mapConfig = pbSnapshot.hasMapConfig() ? _parseMapConfig(pbSnapshot.mapConfig) : null;
    LogService.d('[LobbyBloc] _applySnapshot: parsed mapConfig.mapId=${mapConfig?.mapId}');

    return _SnapshotState(
      users: users,
      messages: recentMessages,
      selectedSpriteId: selectedSpriteId,
      isAnonymous: isAnonymous,
      selfServerUserId: selfServerUserId,
      selfNickname: self?.nickname,
      pageInfo: pageInfo,
      mapConfig: mapConfig,
    );
  }

  /// 解析分页信息（从 protobuf 类型）
  LobbyPageInfo _parsePageInfo(pb.PageInfo pbPage) {
    return LobbyPageInfo(
      currentPage: pbPage.currentPage,
      totalPages: pbPage.totalPages,
      pageSize: pbPage.pageSize,
      totalUsers: pbPage.totalUsers,
    );
  }

  _ChatState _applyChatMessage(pb.ChatMessageResponse pbChat) {
    if (!pbChat.hasMessage()) {
      return _ChatState(users: state.users, messages: state.messages);
    }
    final message = _parseLobbyMessage(pbChat.message);

    // 如果是自己发送的消息，直接忽略
    // 因为本地已经在发送时立即显示了（乐观更新）
    if (_isSelfServerUserId(message.userId)) {
      return _ChatState(users: state.users, messages: state.messages);
    }

    // 规范化消息发送者的 userId，以便与用户列表匹配
    final normalizedUserId = _normalizeUserId(message.userId);
    final normalizedMessage = LobbyMessage(
      messageId: message.messageId,
      userId: normalizedUserId,
      nickname: message.nickname,
      content: message.content,
      type: message.type,
      timestamp: message.timestamp,
      isAnonymous: message.isAnonymous,
    );

    final updatedUsers = state.users.map((user) {
      // 同时检查 userId 和 serverUserId，兼容 identity.changed 后 serverUserId 已更新的情况
      if (user.userId != normalizedUserId && user.serverUserId != message.userId) return user;
      return user.copyWith(
        lastMessage: normalizedMessage.content,
        lastMessageAt: normalizedMessage.timestamp,
        isAnonymous: normalizedMessage.isAnonymous,
        nickname: normalizedMessage.nickname,
      );
    }).toList(growable: false);

    final deduplicatedMessages = state.messages
        .where((item) => item.messageId != normalizedMessage.messageId)
        .toList(growable: false);

    // 限制消息数量，防止内存无限增长
    final finalMessages = _limitMessages([...deduplicatedMessages, normalizedMessage]);

    return _ChatState(
      users: updatedUsers,
      messages: finalMessages,
    );
  }

  List<LobbyUser> _applySpriteChanged(
    List<LobbyUser> users,
    pb.SpriteChangedResponse pbSprite,
  ) {
    final userId = pbSprite.userId;
    final spriteId = pbSprite.spriteId;
    if (userId.isEmpty || spriteId.isEmpty) {
      return users;
    }

    final normalizedUserId = _normalizeUserId(userId);
    return users.map((user) {
      if (user.userId != normalizedUserId && user.serverUserId != userId) return user;
      return user.copyWith(spriteId: spriteId);
    }).toList(growable: false);
  }

  List<LobbyUser> _applyAnonymousChanged(
    List<LobbyUser> users,
    pb.AnonymousChangedResponse pbAnon,
  ) {
    final userId = pbAnon.userId;
    if (userId.isEmpty) return users;
    final isAnonymous = pbAnon.isAnonymous;
    final displayNickname = pbAnon.displayNickname;
    final normalizedUserId = _normalizeUserId(userId);

    return users.map((user) {
      if (user.userId != normalizedUserId && user.serverUserId != userId) return user;
      return user.copyWith(
        isAnonymous: isAnonymous,
        nickname: displayNickname.isNotEmpty ? displayNickname : user.nickname,
      );
    }).toList(growable: false);
  }

  String _normalizeUserId(String userId) {
    return _isSelfServerUserId(userId) ? _selfUserId : userId;
  }

  bool _isSelfServerUserId(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    return userId == _selfUserId || userId == _selfServerUserId;
  }

  LobbyFacing _resolveFacing(LobbyPosition from, LobbyPosition to) {
    return to.x >= from.x ? LobbyFacing.right : LobbyFacing.left;
  }

  double _distance(LobbyPosition a, LobbyPosition b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return (dx * dx + dy * dy).sqrt();
  }

  void _onBroadcastDialogToggled(
    LobbyBroadcastDialogToggled event,
    Emitter<LobbyState> emit,
  ) {
    emit(state.copyWith(isBroadcastDialogOpen: !state.isBroadcastDialogOpen));
  }

  Future<void> _onBroadcastSubmitted(
    LobbyBroadcastSubmitted event,
    Emitter<LobbyState> emit,
  ) async {
    final content = event.content.trim();
    if (content.isEmpty) {
      emit(state.copyWith(isBroadcastDialogOpen: false));
      return;
    }

    // 检查冷却状态
    if (state.broadcastCooldownSeconds > 0) {
      emit(state.copyWith(isBroadcastDialogOpen: false));
      return;
    }

    // 检查是否已登录（匿名用户不能发送广播）
    if (state.isAnonymous) {
      emit(state.copyWith(
        isBroadcastDialogOpen: false,
        transientNotice: '请登录后再发送广播',
      ));
      return;
    }

    // 关闭弹窗
    emit(state.copyWith(isBroadcastDialogOpen: false));

    // 发送广播
    await _service.sendBroadcast(content);
  }

  void _onBroadcastCooldownTick(
    _LobbyBroadcastCooldownTick event,
    Emitter<LobbyState> emit,
  ) {
    final newCooldown = state.broadcastCooldownSeconds - 1;
    if (newCooldown <= 0) {
      _broadcastCooldownTimer?.cancel();
      _broadcastCooldownTimer = null;
      emit(state.copyWith(broadcastCooldownSeconds: 0));
    } else {
      emit(state.copyWith(broadcastCooldownSeconds: newCooldown));
    }
  }

  void _onPortalEntered(
    LobbyPortalEntered event,
    Emitter<LobbyState> emit,
  ) {
    // 预加载目标地图图片（玩家看到传送门对话框时，图片已在后台加载）
    _preloadPortalTargetMap(event.portal.targetMapId);

    // 只记录当前靠近的传送门，不直接显示对话框
    emit(state.copyWith(nearbyPortal: event.portal));
  }

  /// 预加载传送门目标地图
  void _preloadPortalTargetMap(String targetMapId) {
    // BLoC 已关闭时不执行预加载
    if (_isDisposed) return;

    final targetMapConfig = state.assets.getMapById(targetMapId);
    if (targetMapConfig != null) {
      LogService.d('[LobbyBloc] 预加载传送门目标地图: $targetMapId');
      unawaited(LobbyMapLoaderService.instance.preloadMap(targetMapConfig));
    }
  }

  void _onPortalExited(
    LobbyPortalExited event,
    Emitter<LobbyState> emit,
  ) {
    // 离开传送门区域时，如果对话框未打开，则清除
    if (state.nearbyPortal != null) {
      emit(state.copyWith(
        clearNearbyPortal: true,
        isPortalHovered: false,
      ));
    }
  }

  void _onPortalHoverChanged(
    LobbyPortalHoverChanged event,
    Emitter<LobbyState> emit,
  ) {
    emit(state.copyWith(isPortalHovered: event.isHovered));
  }

  Future<void> _onPortalConfirmRequested(
    LobbyPortalConfirmRequested event,
    Emitter<LobbyState> emit,
  ) async {
    // 立即设置传送中状态，让动画立即开始，无需等待服务器响应
    // 用 nearbyPortal 的信息构造临时 teleportTarget（服务器返回 portal.teleport 后会覆盖）
    final portal = state.nearbyPortal;
    if (portal != null) {
      final optimisticTarget = LobbyTeleportTarget(
        portalKey: portal.key,
        label: portal.label,
        sourceMapId: _selfMapId ?? '',
        targetMapId: portal.targetMapId,
        targetX: portal.targetX,
        targetY: portal.targetY,
      );
      emit(state.copyWith(
        isTeleporting: true,
        teleportTarget: optimisticTarget,
        clearNearbyPortal: true,
        transientNotice: '正在传送到 ${portal.label}...',
      ));
    }

    // 发送传送门使用请求
    await _service.usePortal(event.portalKey);

    // 如果 nearbyPortal 为 null（不应发生），仅清除对话框
    if (portal == null) {
      emit(state.copyWith(clearNearbyPortal: true));
    }
  }

  void _onPortalClicked(
    LobbyPortalClicked event,
    Emitter<LobbyState> emit,
  ) {
    final selfUser = state.selfUser;
    if (selfUser == null) return;

    final clickPos = event.clickPosition;

    // 查找点击位置在哪个传送门区域
    for (final portal in state.mapConfig?.portals ?? []) {
      if (portal.contains(clickPos)) {
        // 点击在传送门区域内（使用固定半径检测）
        final selfPos = selfUser.position;

        // 计算到传送门中心的距离
        final dx = selfPos.x - portal.x;
        final dy = selfPos.y - portal.y;
        final distanceSquared = dx * dx + dy * dy;

        // 传送门交互范围 = 固定半径 + 5px
        const interactionRange = kLobbyPortalRadius + 5.0;
        final interactionRangeSquared = interactionRange * interactionRange;

        if (distanceSquared <= interactionRangeSquared) {
          // 在交互范围内，直接显示询问对话框
          // 预加载目标地图（对话框显示时图片应已加载完成）
          _preloadPortalTargetMap(portal.targetMapId);

          emit(state.copyWith(
            nearbyPortal: portal,
            clearPendingPortal: true,
          ));
        } else {
          // 不在范围内，先走过去，设置 pendingPortal
          // 同时更新本地状态，让客户端开始移动
          final portalPos = portal.position;
          final nextUser = selfUser.copyWith(
            targetPosition: portalPos,
            isMoving: true,
            facing: _resolveFacing(selfUser.renderPosition, portalPos),
          );

          // 预加载目标地图（玩家走过去时图片已在后台加载）
          _preloadPortalTargetMap(portal.targetMapId);

          emit(state.copyWith(
            users: _replaceUser(state.users, nextUser),
            pendingPortal: portal,
            clearNearbyPortal: true,
          ));
          _service.sendMove(portalPos);
          _startMovementTimer();
        }
        return;
      }
    }
  }

  void _onPortalDialogShowed(
    LobbyPortalDialogShowed event,
    Emitter<LobbyState> emit,
  ) {
    emit(state.copyWith(nearbyPortal: event.portal));
  }

  void _onPortalDialogDismissed(
    LobbyPortalDialogDismissed event,
    Emitter<LobbyState> emit,
  ) {
    emit(state.copyWith(
      clearNearbyPortal: true,
      clearPendingPortal: true,
    ));
  }

  Future<void> _onOnlineStatsRequested(
    LobbyOnlineStatsRequested event,
    Emitter<LobbyState> emit,
  ) async {
    emit(state.copyWith(isLoadingAllOnlineUsers: true));
    await _service.requestOnlineStats(includeUsers: true);
  }

  /// 处理玩家通知过期（从显示队列中移除）
  void _onNotificationExpired(
    LobbyNotificationExpired event,
    Emitter<LobbyState> emit,
  ) {
    final updatedNotifications = state.playerNotifications
        .where((n) => n.id != event.notificationId)
        .toList();

    emit(state.copyWith(playerNotifications: updatedNotifications));
  }

  /// 安排设置选项超时检查
  void _scheduleSettingsTimeoutCheck() {
    _settingsTimeoutTimer?.cancel();
    _settingsTimeoutTimer = Timer(const Duration(milliseconds: 500), () {
      add(const _LobbySettingsTimeoutCheck());
    });
  }

  /// 处理设置选项超时（服务器未拒绝，视为成功）
  void _onSettingTimeout(
    _LobbySettingTimeout event,
    Emitter<LobbyState> emit,
  ) {
    // 清除该设置项的 pending 状态
    final updatedPending = Map<String, bool>.from(state.pendingSettings);
    updatedPending.remove(event.settingKey);

    final updatedTimeouts = Map<String, DateTime>.from(state.pendingSettingsTimeouts);
    updatedTimeouts.remove(event.settingKey);

    emit(state.copyWith(
      pendingSettings: updatedPending,
      pendingSettingsTimeouts: updatedTimeouts,
    ));
  }

  /// 检查所有设置项的超时状态
  void _onSettingsTimeoutCheck(
    _LobbySettingsTimeoutCheck event,
    Emitter<LobbyState> emit,
  ) {
    final now = DateTime.now();

    for (final entry in state.pendingSettingsTimeouts.entries) {
      if (now.isAfter(entry.value)) {
        // 触发该设置项的超时处理
        add(_LobbySettingTimeout(entry.key));
        return; // 一次只处理一个，避免状态修改冲突
      }
    }

    // 如果还有 pending 的设置项，继续检查
    if (state.pendingSettings.isNotEmpty) {
      _scheduleSettingsTimeoutCheck();
    }
  }

  /// 解析广播消息
  LobbyBroadcastMessage _parseBroadcastMessage(pb.LobbyBroadcastMessage pbMsg) {
    return LobbyBroadcastMessage(
      messageId: pbMsg.messageId,
      userId: pbMsg.userId,
      nickname: pbMsg.nickname,
      content: pbMsg.content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(pbMsg.timestamp.toInt()),
      avatarUrl: pbMsg.avatarUrl.isEmpty ? null : pbMsg.avatarUrl,
    );
  }

  @override
  void onChange(Change<LobbyState> change) {
    super.onChange(change);
    // 每次 transientNotice 变化时，自动调度清除（防止永久显示）
    if (change.nextState.transientNotice != null &&
        change.nextState.transientNoticeSeq != change.currentState.transientNoticeSeq) {
      _scheduleTransientNoticeClear();
    } else if (change.nextState.transientNotice == null) {
      // notice 已被清除，取消兜底 timer
      _transientNoticeTimer?.cancel();
      _transientNoticeTimer = null;
    }
  }

  @override
  Future<void> close() async {
    _isDisposed = true;
    _operationStateSubscription?.cancel();
    _consoleLogSubscription?.cancel();
    _gsiSubscription?.cancel();
    _snapshotOnAssetsReceived?.cancel();
    _snapshotOnAssetsReceived = null;
    _assetsTimeoutTimer?.cancel();
    _assetsTimeoutTimer = null;
    _movementTimer?.cancel();
    _bubbleExpiryTimer?.cancel();
    _chatCooldownTimer?.cancel();
    _broadcastCooldownTimer?.cancel();
    _anonymousSwitchCooldownTimer?.cancel();
    _steamNameSwitchCooldownTimer?.cancel();
    _settingsTimeoutTimer?.cancel();
    _transientNoticeTimer?.cancel();
    _statusTextDebounceTimer?.cancel();
    _queuePollTimer?.cancel();
    _queuePollTimer = null;
    _queueRetryTimer?.cancel();
    _queueRetryTimer = null;
    _snapshotAlignTimer?.cancel();
    _snapshotAlignTimer = null;
    await _wsSubscription?.cancel();
    await _gameStatusSubscription?.cancel();
    await _broadcastController.close();
    // 注销 AuthService 登录状态监听
    AuthService.instance.removeLoginStateListener(_authStateListener);
    // 不调用 _service.dispose()：LobbyNakamaService 是单例，跨 LobbyBloc 生命周期复用
    return super.close();
  }

  Future<void> _onLogoutConfirmed(
    LobbyLogoutConfirmed event,
    Emitter<LobbyState> emit,
  ) async {
    // 重置用户关联信息：
    // 1. 清除服务端用户ID和昵称
    // 2. 重置 selectedSpriteId 为 default sprite（避免前一个用户的模型残留）
    _selfServerUserId = null;

    // 查找 default sprite
    final defaultSprite = state.availableSprites.where((s) => s.isDefault).firstOrNull;
    final defaultSpriteId = defaultSprite?.id ?? 'sprite_01';

    emit(state.copyWith(
      selectedSpriteId: defaultSpriteId,
      isAnonymous: true,
    ));
  }

  /// 用户在被踢提示页面点击操作按钮后，重置被踢状态并重新连接
  Future<void> _onKickedDismissed(
    LobbyKickedDismissed event,
    Emitter<LobbyState> emit,
  ) async {
    final reason = state.kickedReason;
    LogService.i('[LobbyBloc] 用户确认被踢提示，reason=$reason');

    // pc_session_active：PC 端仍在线，重连必然再次被拒，不应重连
    // 只清除遮罩和被踢标志，保持当前连接状态
    // 重置 _isKicked 以便用户后续重新进入大厅时可以正常连接（PC 可能已下线）
    if (reason == 'pc_session_active') {
      _service.resetKicked();
      emit(state.copyWith(
        clearKicked: true,
        clearTransientNotice: true,
      ));
      return;
    }

    // 重置被踢标志，允许重连
    _service.resetKicked();
    _authAttemptedAfterConnect = false;
    _selfServerUserId = null;
    _selfMapId = null;

    // 设置为 disconnected，这样 ws.connected 到来时会走 wasReconnecting 分支
    // 并自动触发 _requestAssetsAndSnapshot()
    emit(state.copyWith(
      clearKicked: true,
      connectionStatus: LobbyConnectionStatus.disconnected,
      pageStatus: LobbyPageStatus.loading,
      loadingPhase: LobbyLoadingPhase.connecting,
      users: const [],
      messages: const [],
      clearTransientNotice: true,
    ));

    // 强制重新建立 WebSocket 连接
    // ws.connected 事件到来后会自动触发 assets+snapshot 请求
    await _service.forceReconnect();
  }

  /// 从后台恢复时清除所有玩家的聊天气泡状态
  void _onChatBubblesCleared(
    LobbyChatBubblesCleared event,
    Emitter<LobbyState> emit,
  ) {
    // 清除所有用户的 lastMessage 和 lastMessageAt
    // 这样 hasVisibleMessage 会返回 false，气泡会消失
    final clearedUsers = state.users.map((user) {
      return user.copyWith(lastMessage: null, lastMessageAt: null);
    }).toList();
    emit(state.copyWith(users: clearedUsers));
  }

  /// 从后台恢复时重新请求 snapshot，确保数据最新
  Future<void> _onSnapshotRefreshRequested(
    LobbySnapshotRefreshRequested event,
    Emitter<LobbyState> emit,
  ) async {
    LogService.d('[LobbyBloc] 从后台恢复，重新请求 snapshot');
    // 只请求 snapshot，不请求 assets（assets 一般不会变化）
    await _service.requestSnapshot();
  }

  // =========================================================================
  // 排队系统处理
  // =========================================================================

  /// 启动定期 snapshot 对齐定时器（每 30 秒请求一次 snapshot，确保 delta 帧最终一致性）
  void _startSnapshotAlignTimer() {
    _snapshotAlignTimer?.cancel();
    _snapshotAlignTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isDisposed || !_isLobbyEntered) return;
      if (state.pageStatus != LobbyPageStatus.ready) return;
      LogService.d('[LobbyBloc] 定期 snapshot 对齐');
      _service.requestSnapshot();
    });
  }

  /// 排队开始
  void _onQueueStarted(
    _LobbyQueueStarted event,
    Emitter<LobbyState> emit,
  ) {
    _queueTicket = event.ticket;
    _queuePollFailCount = 0;

    emit(state.copyWith(
      queueTicket: event.ticket,
      queuePosition: event.position,
      queueTotal: event.queueTotal,
      queueEtaSeconds: event.etaSeconds,
      queueExpired: false,
      loadingPhase: LobbyLoadingPhase.connecting,
      transientNotice: '服务器繁忙，正在排队中...',
    ));

    // 启动轮询定时器
    _startQueuePolling(event.pollIntervalMs);
  }

  /// 启动排队轮询
  void _startQueuePolling(int intervalMs) {
    final clamped = intervalMs.clamp(1000, 10000);
    // 避免相同间隔重复重建定时器
    if (_queuePollTimer != null && _queuePollIntervalMs == clamped) return;
    _queuePollTimer?.cancel();
    _queuePollIntervalMs = clamped;
    final interval = Duration(milliseconds: clamped);
    _queuePollTimer = Timer.periodic(interval, (_) => _pollQueueStatus());
  }

  /// 轮询排队状态
  Future<void> _pollQueueStatus() async {
    final ticket = _queueTicket;
    if (ticket == null || _isDisposed) return;

    final resp = await _service.rpcQueueStatus(ticket);
    if (resp == null) {
      _queuePollFailCount++;
      if (_queuePollFailCount >= 3) {
        // 连续 3 次轮询失败，视为网络异常
        add(const _LobbyQueueExpired('network_error'));
      }
      return;
    }

    _queuePollFailCount = 0;

    if (resp.expired) {
      add(_LobbyQueueExpired(resp.expireReason));
      return;
    }

    if (resp.ready) {
      add(_LobbyQueueReady(resp.matchId));
      return;
    }

    // 更新排队状态
    add(_LobbyQueueStatusUpdated(
      position: resp.position,
      queueTotal: resp.queueTotal,
      etaSeconds: resp.etaSeconds,
    ));

    // 服务端可能调整轮询间隔
    if (resp.pollIntervalMs > 0) {
      _startQueuePolling(resp.pollIntervalMs);
    }
  }

  /// 排队状态更新
  void _onQueueStatusUpdated(
    _LobbyQueueStatusUpdated event,
    Emitter<LobbyState> emit,
  ) {
    emit(state.copyWith(
      queuePosition: event.position,
      queueTotal: event.queueTotal,
      queueEtaSeconds: event.etaSeconds,
    ));
  }

  /// 排队就绪，可以进入大厅
  Future<void> _onQueueReady(
    _LobbyQueueReady event,
    Emitter<LobbyState> emit,
  ) async {
    _queuePollTimer?.cancel();
    _queuePollTimer = null;
    _queueTicket = null;

    emit(state.copyWith(
      clearQueue: true,
      transientNotice: '排队完成，正在进入大厅...',
      loadingPhase: LobbyLoadingPhase.loadingAssets,
    ));

    // 加入 Match
    try {
      await _service.joinMatchById(event.matchId);
      LogService.i('[LobbyBloc] 排队完成，已加入 Match: ${event.matchId}');

      // joinMatch 成功后，service 层会处理 join.success → enter → snapshot
      // 但 assets 需要 bloc 层主动请求
      _requestAssetsAndSnapshot();
    } catch (e) {
      LogService.e('[LobbyBloc] 排队完成后 joinMatch 失败: $e');
      // joinMatch 失败，重新 lobby_join
      emit(state.copyWith(
        transientNotice: '进入大厅失败，正在重试...',
      ));
      add(const LobbyStarted());
    }
  }

  /// 排队过期 — 自动重新加入（大厅是必进的，不允许用户主动退出）
  void _onQueueExpired(
    _LobbyQueueExpired event,
    Emitter<LobbyState> emit,
  ) {
    _queuePollTimer?.cancel();
    _queuePollTimer = null;
    _queueTicket = null;
    _queuePollIntervalMs = 0;

    final reason = event.reason;
    String message;
    switch (reason) {
      case 'timeout':
        message = '排队超时，正在重新加入...';
        break;
      case 'network_error':
        message = '网络异常，正在重新连接...';
        break;
      default:
        message = '排队中断，正在重新加入...';
    }

    emit(state.copyWith(
      clearQueue: true,
      transientNotice: message,
    ));

    // 自动重新加入（延迟 2 秒避免频繁重试，使用可取消的 Timer）
    _queueRetryTimer?.cancel();
    _queueRetryTimer = Timer(const Duration(seconds: 2), () {
      if (!_isDisposed && _isLobbyEntered) {
        add(const LobbyStarted());
      }
    });
  }

  /// 用户取消排队（保留接口但不暴露 UI，仅供内部或极端情况使用）
  Future<void> _onQueueCancelled(
    LobbyQueueCancelled event,
    Emitter<LobbyState> emit,
  ) async {
    final ticket = _queueTicket;
    _queuePollTimer?.cancel();
    _queuePollTimer = null;
    _queueTicket = null;

    emit(state.copyWith(
      clearQueue: true,
      transientNotice: '正在重新加入...',
    ));

    // 通知服务端取消
    if (ticket != null) {
      await _service.rpcQueueCancel(ticket);
    }

    // 自动重新加入
    add(const LobbyStarted());
  }

  // =========================================================================
  // presence.delta 处理
  // =========================================================================

  /// 处理 presence.delta 帧（批量用户进入/离开）
  void _handlePresenceDelta(
    pb.PresenceDeltaResponse delta,
    Emitter<LobbyState> emit,
  ) {
    var updatedUsers = List<LobbyUser>.from(state.users);
    final notifications = <PlayerNotification>[];

    // 1. 批量添加新用户（缓存解析结果，避免重复解析）
    final parsedJoined = <LobbyUser>[];
    for (final pbUser in delta.joined) {
      final rawUserId = pbUser.userId;
      final isSelfUser = rawUserId.isNotEmpty && _selfServerUserId == rawUserId;
      final user = _parseLobbyUser(pbUser, isSelf: isSelfUser, serverUserId: rawUserId);
      parsedJoined.add(user);

      updatedUsers = _upsertUser(updatedUsers, user);

      // 生成通知（自己不通知）
      if (!isSelfUser) {
        notifications.add(PlayerNotification(
          id: 'delta_join_${DateTime.now().microsecondsSinceEpoch}_$rawUserId',
          type: PlayerNotificationType.online,
          playerName: user.displayName,
          createdAt: DateTime.now(),
        ));
      }
    }

    // 2. 批量移除离开的用户
    for (final leftUserId in delta.leftUserIds) {
      if (leftUserId.isEmpty) continue;
      final leavingUser = _findUserById(updatedUsers, leftUserId);
      if (leavingUser != null) {
        updatedUsers = updatedUsers
            .where((u) => u.serverUserId != leftUserId && u.userId != leftUserId)
            .toList(growable: false);

        notifications.add(PlayerNotification(
          id: 'delta_leave_${DateTime.now().microsecondsSinceEpoch}_$leftUserId',
          type: PlayerNotificationType.offline,
          playerName: leavingUser.displayName,
          createdAt: DateTime.now(),
        ));
      }
    }

    // 3. 跨地图通知
    for (final crossEvent in delta.crossMapEvents) {
      if (crossEvent.isAnonymous) continue; // 匿名用户不通知
      final isSelf = crossEvent.userId.isNotEmpty && _selfServerUserId == crossEvent.userId;
      if (isSelf) continue;

      final displayName = crossEvent.nickname.isNotEmpty ? crossEvent.nickname : crossEvent.userId;
      if (crossEvent.eventType == 'join') {
        notifications.add(PlayerNotification(
          id: 'delta_cross_join_${DateTime.now().microsecondsSinceEpoch}_${crossEvent.userId}',
          type: PlayerNotificationType.online,
          playerName: displayName,
          createdAt: DateTime.now(),
        ));
      } else if (crossEvent.eventType == 'leave') {
        final targetMapName = crossEvent.targetMapId.isNotEmpty
            ? (state.assets.getMapById(crossEvent.targetMapId)?.displayName ?? crossEvent.targetMapId)
            : null;
        notifications.add(PlayerNotification(
          id: 'delta_cross_leave_${DateTime.now().microsecondsSinceEpoch}_${crossEvent.userId}',
          type: targetMapName != null ? PlayerNotificationType.teleport : PlayerNotificationType.offline,
          playerName: displayName,
          targetMapName: targetMapName,
          createdAt: DateTime.now(),
        ));
      }
    }

    // 合并通知（限制最多 20 条）
    final updatedNotifications = [...state.playerNotifications, ...notifications].take(20).toList();

    // 同步更新 allOnlineUsers（复用已解析的 joined 用户）
    var updatedAllOnline = List<LobbyUser>.from(state.allOnlineUsers);
    if (updatedAllOnline.isNotEmpty) {
      for (final user in parsedJoined) {
        updatedAllOnline = _upsertUserInList(updatedAllOnline, user);
      }
      for (final leftUserId in delta.leftUserIds) {
        updatedAllOnline = updatedAllOnline
            .where((u) => u.serverUserId != leftUserId && u.userId != leftUserId)
            .toList(growable: false);
      }
    }

    emit(state.copyWith(
      users: updatedUsers,
      playerNotifications: updatedNotifications,
      allOnlineUsers: updatedAllOnline,
    ));
  }
}

class _SnapshotState {
  final List<LobbyUser> users;
  final List<LobbyMessage> messages;
  final String selectedSpriteId;
  final bool isAnonymous;
  final String? selfServerUserId;
  final String? selfNickname;
  final LobbyPageInfo? pageInfo;
  final LobbyMapConfig? mapConfig;

  const _SnapshotState({
    required this.users,
    required this.messages,
    required this.selectedSpriteId,
    required this.isAnonymous,
    required this.selfServerUserId,
    required this.selfNickname,
    this.pageInfo,
    this.mapConfig,
  });
}

class _ChatState {
  final List<LobbyUser> users;
  final List<LobbyMessage> messages;

  const _ChatState({
    required this.users,
    required this.messages,
  });
}

extension on num {
  double sqrt() {
    final value = (this is double ? this as double : (this as int).toDouble());
    if (value < 0) return 0;
    return math.sqrt(value);
  }
}
