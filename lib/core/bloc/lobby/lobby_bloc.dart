import 'dart:async';
import 'dart:math' as math;

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../models/lobby_models.dart';
import '../../services/auth_service.dart';
import '../../services/game_status_service.dart';
import '../../services/lobby_asset_cache_service.dart';
import '../../services/lobby_image_cache_service.dart';
import '../../services/lobby_map_loader_service.dart';
import '../../services/lobby_ws_service.dart';
import '../../services/notification_window_service.dart';
import '../../utils/log_service.dart';

part 'lobby_event.dart';
part 'lobby_state.dart';

class LobbyBloc extends Bloc<LobbyEvent, LobbyState> {
  LobbyBloc({LobbyWsService? service})
      : _service = service ?? LobbyWsService.instance,
        super(LobbyState.initial()) {
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

    // 订阅 AuthService 登录状态变化
    _authStateListener = _onAuthStateChanged;
    AuthService.instance.addLoginStateListener(_authStateListener);

    on<LobbyStarted>(_onStarted);
    on<LobbySceneTapped>(_onSceneTapped);
    on<LobbyMovementTicked>(_onMovementTicked);
    on<LobbyPlayerArrived>(_onPlayerArrived);
    on<LobbyChatInputChanged>(_onChatInputChanged);
    on<LobbyChatModeChanged>(_onChatModeChanged);
    on<LobbyChatSubmitted>(_onChatSubmitted);
    on<LobbyPlayersPanelToggled>(_onPlayersPanelToggled);
    on<LobbySettingsPanelToggled>(_onSettingsPanelToggled);
    on<LobbySpriteSelected>(_onSpriteSelected);
    on<LobbyAnonymousToggled>(_onAnonymousToggled);
    on<LobbyChatOpacityChanged>(_onChatOpacityChanged);
    on<LobbyNameplatesToggled>(_onNameplatesToggled);
    on<LobbyChatBubblesToggled>(_onChatBubblesToggled);
    on<LobbyTransientNoticeShown>(_onTransientNoticeShown);
    on<LobbyBubbleExpired>(_onBubbleExpired);
    on<LobbyWsEventReceived>(_onWsEventReceived);
    on<LobbyPanelsDismissed>(_onPanelsDismissed);
    on<LobbyResendMessages>(_onResendMessages);
    on<_LobbyAssetsReceived>(_onAssetsReceived);
    on<_LobbyGameStatusChanged>(_onGameStatusChanged);
    on<LobbyTeleportStarted>(_onTeleportStarted);
    on<LobbyTeleportCompleted>(_onTeleportCompleted);
    on<_LobbySetLoadingMore>(_onSetLoadingMore);
    on<LobbyLogoutConfirmed>(_onLogoutConfirmed);
    on<_LobbyChatCooldownTick>(_onChatCooldownTick);
    on<_LobbyAnonymousSwitchCooldownTick>(_onAnonymousSwitchCooldownTick);
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
    on<LobbyBroadcastNotificationsToggled>(_onBroadcastNotificationsToggled);
    on<_LobbySettingTimeout>(_onSettingTimeout);
    on<_LobbySettingsTimeoutCheck>(_onSettingsTimeoutCheck);
  }

  static const double _moveSpeed = 2.8;
  static const String _selfUserId = 'self';
  static const Duration _moveDebounceInterval = Duration(milliseconds: 250);
  /// 聊天冷却时间（秒）
  static const int _chatCooldownDuration = 1;
  /// 广播冷却时间（秒）
  static const int _broadcastCooldownDuration = 300;
  /// 匿名切换冷却时间（秒）
  static const int _anonymousSwitchCooldownDuration = 3;

  final LobbyWsService _service;
  StreamSubscription<LobbyWsEvent>? _wsSubscription;
  StreamSubscription<GameStatusEvent>? _gameStatusSubscription;
  Timer? _movementTimer;
  Timer? _bubbleExpiryTimer;
  Timer? _chatCooldownTimer;
  Timer? _broadcastCooldownTimer;
  Timer? _anonymousSwitchCooldownTimer;
  Timer? _settingsTimeoutTimer;
  StreamSubscription<LobbyWsEvent>? _snapshotOnAssetsReceived;
  bool _authAttemptedAfterConnect = false;
  String? _selfServerUserId;
  DateTime? _lastMoveRequestAt;
  bool _isLobbyEntered = false;
  bool _isDisposed = false;
  /// 当前地图 ID（从 join.success 中提取，用于资产加载时确定当前地图）
  String? _selfMapId;

  /// AuthService 登录状态变化监听器回调
  late final LoginStateChangedCallback _authStateListener;

  /// 处理 AuthService 登录状态变化
  void _onAuthStateChanged(bool isLoggedIn) {
    if (_isDisposed) return;

    if (isLoggedIn) {
      // 用户登录了，等待 token 就绪后发送 login 事件
      // 注意：AuthService.login() 中 _notifyLoginStateChanged 在 _exchangeBackendToken 之前调用，
      // 所以需要等待 token 交换完成
      LogService.i('[LobbyBloc] 检测到登录，等待 token 就绪后发送 login 事件');
      _waitAndLogin();
    } else {
      // 用户登出了，重置状态并发送 logout 事件（保留连接，降级为匿名）
      LogService.i('[LobbyBloc] 检测到登出，发送 logout 事件');
      add(const LobbyLogoutConfirmed());
      _service.logout(force: false);
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
    LogService.i('[LobbyBloc] Token 已就绪，发送 login 事件');
    _service.login();
  }

  Future<void> _onStarted(
    LobbyStarted event,
    Emitter<LobbyState> emit,
  ) async {
    // 重置状态，但保留 WebSocket 订阅（已在应用启动时建立）
    _authAttemptedAfterConnect = false;
    _selfServerUserId = null;
    _isLobbyEntered = true;
    _isDisposed = false;

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
        showBroadcastNotifications: _service.loadShowBroadcastNotifications(),
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
      ),
    );

    // 预加载所有已缓存的图片到内存（加速后续渲染）
    _preloadCachedImages();

    _scheduleBubbleCleanup();

    // 请求服务器在线人数（BLoC 已订阅，确保徽章显示正确）
    unawaited(_service.requestOnlineStats(includeUsers: false));

    // 进入大厅页面时才请求 assets 和 snapshot
    // 这样可以确保 URL token 在有效期内
    _requestAssetsAndSnapshot();
  }

  /// 请求 assets 和 snapshot
  Future<void> _requestAssetsAndSnapshot() async {
    // 先请求 assets
    await _service.requestAssets();

    // 监听 assets 响应，然后请求 snapshot
    _snapshotOnAssetsReceived?.cancel();
    _snapshotOnAssetsReceived = _service.events.listen((wsEvent) async {
      if (wsEvent.type == 'assets') {
        _snapshotOnAssetsReceived?.cancel();
        _snapshotOnAssetsReceived = null;

        // 收到 assets 后，通过事件更新状态
        add(_LobbyAssetsReceived(wsEvent));

        // 请求 snapshot
        if (!_isDisposed && _isLobbyEntered) {
          await _service.requestSnapshot();
          // 请求广播冷却状态
          await _service.requestBroadcastCD();
        }
      }
    });
  }

  /// 请求更多分页用户
  Future<void> _loadMoreUsers(int page) async {
    if (_isDisposed || !_isLobbyEntered) return;

    // 标记正在加载更多
    add(_LobbySetLoadingMore(true));

    await _service.requestSnapshot(page: page);
  }

  /// 内部事件处理：assets 收到后更新状态并缓存
  Future<void> _onAssetsReceived(
    _LobbyAssetsReceived event,
    Emitter<LobbyState> emit,
  ) async {
    final rawAssets = _parseAssets(event.wsEvent.payload, currentMapId: _selfMapId);
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

  void _onChatInputChanged(
    LobbyChatInputChanged event,
    Emitter<LobbyState> emit,
  ) {
    emit(state.copyWith(chatDraft: event.value));
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
    final content = state.chatDraft.trim();
    if (content.isEmpty) {
      emit(state.copyWith(isChatActive: false));
      return;
    }

    // 检查冷却状态
    if (state.chatCooldownSeconds > 0) {
      emit(state.copyWith(isChatActive: false));
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

    // 添加到待重发队列
    final updatedPendingMessages = Map<String, String>.from(state.pendingMessages);
    updatedPendingMessages[myMessage.messageId] = content;

    // 立即更新自己的 lastMessage 状态，使聊天气泡和聊天栏立即显示
    // 注意：不立即清空 chatDraft，只有收到服务器确认后才清空
    final updatedUsers = state.users.map((user) {
      if (!user.isSelf) return user;
      return user.copyWith(
        lastMessage: content,
        lastMessageAt: now,
      );
    }).toList(growable: false);

    // 添加消息到消息列表（使用新列表对象触发状态更新）
    final updatedMessages = [...state.messages, myMessage];

    // 启动冷却计时器
    _startChatCooldownTimer();

    emit(
      state.copyWith(
        isChatActive: false,
        chatDraft: '', // 发送后立即清空输入框
        users: updatedUsers,
        messages: updatedMessages,
        pendingMessages: updatedPendingMessages,
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

  void _onResendMessages(
    LobbyResendMessages event,
    Emitter<LobbyState> emit,
  ) {
    if (state.pendingMessages.isEmpty) return;

    // 重发所有待重发的消息
    for (final entry in state.pendingMessages.entries) {
      _service.sendChat(entry.value);
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
    emit(
      state.copyWith(
        selectedSpriteId: event.spriteId,
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

  void _onTransientNoticeShown(
    LobbyTransientNoticeShown event,
    Emitter<LobbyState> emit,
  ) {
    emit(state.copyWith(clearTransientNotice: true));
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

  /// 根据游戏运行状态更新状态文字，并同步到服务器
  Future<void> _updateStatusTextByGameStatus(
    bool isGameRunning,
    Emitter<LobbyState> emit,
  ) async {
    final newStatusText = isGameRunning ? '游戏中' : '在线';

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
    await _service.updateStatusText(newStatusText);
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
    LogService.d('[LobbyBloc] _onWsEventReceived: type=${event.event.type}');
    switch (event.event.type) {
      case 'login.success':
        // 登录成功（用户显式登录或匿名升级登录成功后服务端返回）
        // 不再自动请求 snapshot，客户端需主动请求
        final loginUserId = event.event.payload['userId']?.toString();
        final loginNickname = event.event.payload['nickname']?.toString();
        LogService.d('[LobbyBloc] login.success: userId=$loginUserId nickname=$loginNickname '
            '_selfServerUserId=$_selfServerUserId '
            'state.users=${state.users.map((u) => '${u.userId}:${u.nickname}:isSelf=${u.isSelf}').toList()}');

        // 更新 _selfServerUserId（需要先于 presence.join 处理）
        _selfServerUserId = loginUserId;

        // 迁移 state.users 中的旧匿名自己为新登录用户
        // 旧匿名自己：userId='self', isSelf=true, isAnonymous=true
        // 新用户 serverId = loginUserId
        var migratedUsers = state.users;
        if (loginUserId != null && loginUserId != _selfUserId) {
          // 查找旧匿名自己（userId='self' 且 isSelf=true）
          final oldSelfIdx = migratedUsers.indexWhere(
            (u) => u.userId == _selfUserId && u.isSelf,
          );
          if (oldSelfIdx >= 0) {
            // 替换为新的登录用户（保留 userId='self' 但更新所有登录信息）
            final oldSelf = migratedUsers[oldSelfIdx];
            migratedUsers = [
              ...migratedUsers.sublist(0, oldSelfIdx),
              oldSelf.copyWith(
                nickname: loginNickname ?? oldSelf.nickname,
                isAnonymous: false,
                serverUserId: loginUserId,
                avatarUrl: event.event.payload['avatarUrl'] ?? oldSelf.avatarUrl,
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
        // 注意：不需要请求 assets 和 snapshot，因为：
        // 1. presence.join 已经会更新用户数据（模型切换等）
        // 2. 已有 assets 数据足够使用
        // 3. 重新请求 snapshot 可能导致用户列表不一致
        break;
      case 'login.failed':
        _authAttemptedAfterConnect = false;
        emit(
          state.copyWith(
            connectionStatus: LobbyConnectionStatus.connected,
            transientNotice: event.event.payload['reason']?.toString() ?? '登录失败，已保持匿名身份',
          ),
        );
        break;
      case 'logout.success':
        final kick = event.event.payload['kick'] == true;
        if (kick) {
          // force=true：WebSocket 连接已断开，等待重连
          emit(state.copyWith(
            connectionStatus: LobbyConnectionStatus.disconnected,
            transientNotice: '已退出登录，连接已关闭',
          ));
        } else {
          // force=false：降级为匿名用户，刷新数据
          emit(state.copyWith(
            chatDraft: '', // 退出登录后清空聊天草稿
            transientNotice: '已退出登录，保持匿名身份',
          ));
          if (_isLobbyEntered) {
            unawaited(_service.requestSnapshot());
          }
        }
        break;
      case 'ws.closed':
        if (state.connectionStatus != LobbyConnectionStatus.connecting) {
          // 断线时重置加载阶段，等待重连后重新开始
          emit(state.copyWith(
            connectionStatus: LobbyConnectionStatus.reconnecting,
            loadingPhase: LobbyLoadingPhase.connecting,
            transientNotice: '大厅连接断开，正在尝试重连...',
          ));
        }
        break;
      case 'ws.error':
        if (state.connectionStatus != LobbyConnectionStatus.connecting) {
          emit(state.copyWith(
            connectionStatus: LobbyConnectionStatus.reconnecting,
            loadingPhase: LobbyLoadingPhase.connecting,
            transientNotice: '大厅连接异常，正在尝试重连...',
          ));
        }
        break;
      case 'ws.connected':
        _authAttemptedAfterConnect = false;
        if (state.connectionStatus != LobbyConnectionStatus.connected &&
            state.connectionStatus != LobbyConnectionStatus.connecting) {
          // 构建更新参数
          final updates = <String, dynamic>{
            'connectionStatus': LobbyConnectionStatus.connected,
            'transientNotice': '大厅重连成功，正在同步数据...',
          };
          // 如果正在 loading 阶段，更新加载阶段
          if (state.pageStatus == LobbyPageStatus.loading) {
            // 判断是否已收到 assets
            final hasAssets = state.assets.mapConfig != null || state.assets.sprites.isNotEmpty;
            updates['loadingPhase'] = hasAssets
                ? LobbyLoadingPhase.loadingSnapshot
                : LobbyLoadingPhase.waiting;
          }
          emit(state.copyWith(
            connectionStatus: updates['connectionStatus'] as LobbyConnectionStatus,
            loadingPhase: updates['loadingPhase'] as LobbyLoadingPhase?,
            transientNotice: updates['transientNotice'] as String,
          ));
          // WebSocket 重连成功后，自动重发待发送的消息
          if (state.pendingMessages.isNotEmpty) {
            add(const LobbyResendMessages());
          }
          // 重连后重新请求广播冷却状态
          if (_isLobbyEntered) {
            unawaited(_service.requestBroadcastCD());
          }
        }
        break;
      case 'join.success':
        // 从 join.success 中提取用户信息和当前地图 ID
        final joinUser = event.event.payload['user'];
        if (joinUser is Map) {
          final userId = joinUser['userId']?.toString();
          if (userId != null && userId.isNotEmpty) {
            _selfServerUserId = userId;
            LogService.d('[LobbyBloc] join.success 设置 _selfServerUserId=$userId');
          }
        }
        // 保存当前地图 ID（用于后续 assets 解析时确定当前地图）
        final mapId = event.event.payload['mapId']?.toString();
        if (mapId != null && mapId.isNotEmpty) {
          _selfMapId = mapId;
          LogService.d('[LobbyBloc] join.success 设置 _selfMapId=$mapId');
        }
        // 不在这里请求 assets，等到进入大厅页面再请求（避免 URL token 过期）
        break;
      case 'assets':
        {
          // 由于是在进入大厅页面后才请求 assets，这里收到说明正在加载中
          // 实际处理在 _requestAssetsAndSnapshot 中
          final rawAssets = _parseAssets(event.event.payload, currentMapId: _selfMapId);
          final assets = _mergeAssetsWithCache(rawAssets);

          // 如果 pageStatus 已经是 ready（从 snapshot 进入），刷新 assets
          if (state.pageStatus == LobbyPageStatus.ready) {
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
          final snapshotState = _applySnapshot(event.event.payload);
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

          // 如果是匿名身份且用户已登录，发送 login 事件
          if (!_authAttemptedAfterConnect &&
              snapshotState.isAnonymous &&
              AuthService.instance.isLoggedIn &&
              _service.hasValidToken) {
            _authAttemptedAfterConnect = true;
            unawaited(_service.login());
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
        }
        break;
      case 'presence.join':
        // 尝试从 payload 中提取 userId 判断是否是自己
        final rawUserId = event.event.payload['user'] is Map
            ? event.event.payload['user']['userId']?.toString()
            : null;
        final isSelfUser = rawUserId != null && _selfServerUserId == rawUserId;
        LogService.d('[LobbyBloc] presence.join: rawUserId=$rawUserId _selfServerUserId=$_selfServerUserId '
            'isSelfUser=$isSelfUser users=${state.users.map((u) => '${u.userId}:serverId=${u.serverUserId}:${u.nickname}').toList()}');
        final user = _parseLobbyUser(
          event.event.payload['user'],
          isSelf: isSelfUser,
          serverUserId: rawUserId,
        );
        if (user == null) break;

        // 如果是自己，同步 selectedSpriteId（服务端知道用户上次用的模型）
        final newSelectedSpriteId = isSelfUser && user.spriteId.isNotEmpty
            ? user.spriteId
            : state.selectedSpriteId;

        // 构建玩家加入通知（自己加入时不显示通知）
        final newNotification = isSelfUser
            ? null
            : PlayerNotification(
                id: 'join_${DateTime.now().microsecondsSinceEpoch}',
                type: PlayerNotificationType.join,
                playerName: user.displayName,
                createdAt: DateTime.now(),
              );

        // 更新通知列表（限制最多保留20条）
        final updatedNotifications = newNotification != null
            ? [...state.playerNotifications, newNotification].take(20).toList()
            : state.playerNotifications;

        emit(
          state.copyWith(
            users: _upsertUser(state.users, user),
            selectedSpriteId: newSelectedSpriteId,
            playerNotifications: updatedNotifications,
          ),
        );
        break;
      case 'presence.leave':
        final serverUserId = event.event.payload['userId']?.toString();
        if (serverUserId == null || serverUserId.isEmpty) break;
        // 通过 serverUserId 或 userId 查找离开的用户
        final leavingUser = _findUserById(state.users, serverUserId);
        final updatedUsers = state.users
            .where((user) => user.serverUserId != serverUserId && user.userId != serverUserId)
            .toList(growable: false);

        // 获取 targetMapId 判断是传送离开还是断线离开
        final targetMapId = event.event.payload['targetMapId']?.toString();
        PlayerNotification? newNotification;
        if (leavingUser != null) {
          if (targetMapId != null && targetMapId.isNotEmpty) {
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
              type: PlayerNotificationType.leave,
              playerName: leavingUser.displayName,
              createdAt: DateTime.now(),
            );
          }
        }

        // 更新通知列表（限制最多保留20条）
        final updatedNotifications = newNotification != null
            ? [...state.playerNotifications, newNotification].take(20).toList()
            : state.playerNotifications;

        emit(
          state.copyWith(
            users: updatedUsers,
            playerNotifications: updatedNotifications,
          ),
        );
        break;
      case 'presence.update':
        final updatedUsers = _applyPresenceUpdate(state.users, event.event.payload);
        emit(state.copyWith(users: updatedUsers));
        break;
      case 'move.broadcast':
        var updatedUsers = _applyMoveBroadcast(state.users, event.event.payload);

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
        emit(
          state.copyWith(
            users: _applyMoveReject(state.users, event.event.payload),
            transientNotice: event.event.payload['reason']?.toString() ?? '移动请求被拒绝',
          ),
        );
        break;
      case 'chat.message':
        final nextState = _applyChatMessage(event.event.payload);
        LogService.d('[LobbyBloc] chat.message: users=${nextState.users.map((u) => '${u.userId}:lastMsg=${u.lastMessage != null ? '"${u.lastMessage}"' : null}').toList()}');

        // 收到服务器确认消息时，从待重发队列中移除（因为本地消息已经显示，服务器确认说明发送成功）
        final confirmedMessageId = event.event.payload['messageId']?.toString();
        final updatedPendingMessages = Map<String, String>.from(state.pendingMessages);
        if (confirmedMessageId != null) {
          updatedPendingMessages.remove(confirmedMessageId);
        }

        // 队列清空后清空 chatDraft（只有当队列变空时才清空，避免恢复用户正在编辑的内容）
        final shouldClearDraft = updatedPendingMessages.isEmpty && state.pendingMessages.isNotEmpty;

        emit(
          state.copyWith(
            users: nextState.users,
            messages: nextState.messages,
            pendingMessages: updatedPendingMessages,
            chatDraft: shouldClearDraft ? '' : state.chatDraft,
          ),
        );
        _scheduleBubbleCleanup();
        break;
      case 'chat.reject':
        // 获取最近一次发送的消息内容用于恢复
        final lastPendingContent = state.pendingMessages.isNotEmpty
            ? state.pendingMessages.values.last
            : null;

        emit(
          state.copyWith(
            transientNotice: event.event.payload['reason']?.toString() ?? '消息发送失败',
            // 清空待重发队列（不知道具体哪条被拒绝，避免重复发送）
            pendingMessages: {},
            // 恢复用户输入，让用户可以重新编辑发送
            chatDraft: lastPendingContent ?? state.chatDraft,
          ),
        );
        // 自动触发重发（延迟 1 秒后）
        // 注意：这里不重发，因为不知道具体哪条被拒绝
        break;
      case 'profile.sprite.changed':
        final nextUsers = _applySpriteChanged(state.users, event.event.payload);
        final changedSpriteId = event.event.payload['spriteId']?.toString();
        final changedUserId = event.event.payload['userId']?.toString();
        emit(
          state.copyWith(
            users: nextUsers,
            selectedSpriteId: _isSelfServerUserId(changedUserId) && changedSpriteId != null
                ? changedSpriteId
                : state.selectedSpriteId,
          ),
        );
        break;
      case 'profile.sprite.change.reject':
        final reason = event.event.payload['reason']?.toString();
        String message;
        switch (reason) {
          case 'invalid_sprite_id':
            message = '该角色外观不可用';
            break;
          case 'invalid_payload':
            message = '角色外观切换请求格式错误';
            break;
          default:
            message = '角色外观切换失败';
        }
        emit(
          state.copyWith(
            transientNotice: message,
          ),
        );
        break;
      case 'profile.anonymous.changed':
        final nextUsers = _applyAnonymousChanged(state.users, event.event.payload);
        final userId = event.event.payload['userId']?.toString();
        final isAnonymous = event.event.payload['isAnonymous'] == true;

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
      case 'profile.anonymous.change.reject':
        // 匿名设置被拒绝，回退状态
        LogService.d('[LobbyBloc] 收到 profile.anonymous.change.reject: payload=${event.event.payload}');
        final updatedPending = Map<String, bool>.from(state.pendingSettings);
        updatedPending.remove('anonymous');
        final updatedTimeouts = Map<String, DateTime>.from(state.pendingSettingsTimeouts);
        updatedTimeouts.remove('anonymous');

        final reason = event.event.payload['reason']?.toString() ?? '匿名模式设置失败';
        emit(state.copyWith(
          isAnonymous: !state.isAnonymous,
          users: state.users
              .map((user) => user.isSelf ? user.copyWith(isAnonymous: !state.isAnonymous) : user)
              .toList(growable: false),
          pendingSettings: updatedPending,
          pendingSettingsTimeouts: updatedTimeouts,
          transientNotice: reason,
        ));
        break;
      case 'system.notice':
        final notice = event.event.payload['message']?.toString();
        if (notice == null || notice.isEmpty) break;
        emit(
          state.copyWith(
            messages: [...state.messages, _buildSystemMessage(notice)],
            transientNotice: notice,
          ),
        );
        break;
      case 'system.error':
        final code = event.event.payload['code'];
        final message = event.event.payload['message']?.toString() ?? '大厅服务暂时不可用';
        emit(
          state.copyWith(
            connectionStatus: code == 409 ? LobbyConnectionStatus.disconnected : LobbyConnectionStatus.failed,
            transientNotice: message,
          ),
        );
        break;
      case 'portal.teleport':
        final portalKey = event.event.payload['portalKey']?.toString();
        final label = event.event.payload['label']?.toString() ?? '未知传送点';
        final sourceMapId = event.event.payload['sourceMapId']?.toString() ?? '';
        final targetMapId = event.event.payload['targetMapId']?.toString() ?? '';
        final targetX = _asDouble(event.event.payload['targetX']) ?? 0;
        final targetY = _asDouble(event.event.payload['targetY']) ?? 0;
        if (portalKey != null && portalKey.isNotEmpty && targetMapId.isNotEmpty) {
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

          // 主动请求 snapshot 以获取新地图的完整配置
          LogService.d('[LobbyBloc] portal.teleport: 主动请求 snapshot');

          // 尝试从已有的 maps 中找到目标地图并预加载
          // 注意：已在 _preloadPortalTargetMap 中检查 _isDisposed
          final targetMapConfig = state.assets.getMapById(targetMapId);
          if (targetMapConfig != null) {
            LogService.d('[LobbyBloc] portal.teleport: 预加载目标地图 $targetMapId');
            unawaited(LobbyMapLoaderService.instance.preloadMap(targetMapConfig));
          } else {
            LogService.d('[LobbyBloc] portal.teleport: 目标地图配置尚未加载，等待 snapshot');
          }

          unawaited(_service.requestSnapshot());
        }
        break;
      case 'portal.use.reject':
        final reject = LobbyPortalReject.fromPayload(event.event.payload);
        LogService.w('[LobbyBloc] 传送门请求被拒绝: ${reject.reasonType.displayText}');
        emit(state.copyWith(
          transientNotice: reject.reasonType.displayText,
          clearNearbyPortal: true,
          clearPendingPortal: true,
        ));
        break;
      case 'profile.statusText.broadcast':
        final userId = event.event.payload['userId']?.toString();
        final statusText = event.event.payload['statusText']?.toString();
        if (userId != null && statusText != null) {
          final normalizedUserId = _normalizeUserId(userId);
          emit(
            state.copyWith(
              users: state.users
                  .map((user) => user.userId == normalizedUserId
                      ? user.copyWith(statusText: statusText)
                      : user)
                  .toList(growable: false),
            ),
          );
        }
        break;
      case 'assets.updated':
        final updateType = event.event.payload['updateType']?.toString() ?? 'all';
        final message = event.event.payload['message']?.toString() ?? '素材已更新';
        LogService.i('[LobbyBloc] 收到素材更新通知: updateType=$updateType, message=$message');

        // 静默处理素材更新，只在日志中记录
        // 主动请求最新素材
        if (_isLobbyEntered) {
          unawaited(_service.requestAssets());
        }
        break;
      case 'broadcast.message':
        final broadcast = _parseBroadcastMessage(event.event.payload['message']);
        if (broadcast != null) {
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
          final updatedMessages = [...state.messages, broadcastLobbyMessage];

          // 如果开启了广播通知，显示通知窗口
          if (state.showBroadcastNotifications) {
            NotificationWindowService().showBroadcastNotification(
              nickname: broadcast.nickname,
              content: broadcast.content,
            );
          }

          emit(state.copyWith(messages: updatedMessages));
        }
        break;
      case 'broadcast.cd':
        final inCooldown = event.event.payload['inCooldown'] == true;
        final remainingMs = event.event.payload['remainingMs'] as int? ?? 0;
        if (inCooldown && remainingMs > 0) {
          // 服务器返回冷却中，设置剩余秒数并启动倒计时
          final remainingSeconds = (remainingMs / 1000).ceil();
          emit(state.copyWith(broadcastCooldownSeconds: remainingSeconds));
          _broadcastCooldownTimer?.cancel();
          _broadcastCooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
            add(const _LobbyBroadcastCooldownTick());
          });
        } else {
          // 不在冷却中
          emit(state.copyWith(broadcastCooldownSeconds: 0));
        }
        break;
      case 'broadcast.reject':
        final reason = event.event.payload['reason']?.toString() ?? '广播发送失败';
        final remainingMs = event.event.payload['remainingMs'] as int?;

        // 如果服务器返回了剩余冷却时间，同步更新冷却状态
        if (remainingMs != null && remainingMs > 0) {
          final remainingSeconds = (remainingMs / 1000).ceil();
          emit(state.copyWith(
            transientNotice: reason,
            broadcastCooldownSeconds: remainingSeconds,
          ));
          // 启动冷却倒计时
          _broadcastCooldownTimer?.cancel();
          _broadcastCooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
            add(const _LobbyBroadcastCooldownTick());
          });
        } else {
          emit(state.copyWith(transientNotice: reason));
        }
        break;
      case 'online.count':
        // 服务端主动推送的当前服务器在线人数
        final count = event.event.payload['count'] as int? ?? 0;
        LogService.d('[LobbyBloc] online.count: count=$count');
        emit(state.copyWith(serverOnlineCount: count));
        break;
      case 'online.stats':
        {
          final total = event.event.payload['total'] as int? ?? 0;
          final usersData = event.event.payload['users'];
          final List<LobbyUser> parsedUsers = [];

          if (usersData is List) {
            for (final item in usersData) {
              // online.stats 返回的用户列表中，每个用户的 userId 就是其唯一标识
              // 需要判断是否是自己
              final userId = item is Map ? item['userId']?.toString() : null;
              final isSelfUser = userId != null && _selfServerUserId == userId;
              final user = _parseLobbyUser(item, isSelf: isSelfUser, serverUserId: userId);
              if (user != null) {
                parsedUsers.add(user);
              }
            }
          }

          LogService.d('[LobbyBloc] online.stats: total=$total, users=${parsedUsers.length}');

          emit(state.copyWith(
            allOnlineUsers: parsedUsers,
            isLoadingAllOnlineUsers: false,
            serverOnlineCount: total,
          ));
        }
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

  // ---------------------------------------------------------------------------
  // 解析方法
  // ---------------------------------------------------------------------------

  /// 从 payload 解析 assets（地图配置 + 角色贴图）
  ///
  /// [payload] WebSocket assets 消息的 payload
  /// [skipCache] 是否跳过缓存（用于 snapshot 消息中的 assets）
  /// [currentMapId] 当前地图 ID，用于从 maps 数组中选择当前地图
  LobbyAssets _parseAssets(
    Map<String, dynamic> payload, {
    bool skipCache = false,
    String? currentMapId,
  }) {
    // 支持新的 maps 数组格式（优先）或旧的 mapConfig 格式（兼容）
    final List<LobbyMapConfig> parsedMaps = [];

    // 尝试从 maps 数组解析（新的协议格式）
    final payloadMaps = payload['maps'];
    if (payloadMaps is List) {
      for (final item in payloadMaps) {
        final mapConfig = _parseMapConfig(item);
        if (mapConfig != null) {
          parsedMaps.add(mapConfig);
        }
      }
    }

    // 兼容旧的 mapConfig 格式
    if (parsedMaps.isEmpty) {
      final mapConfig = _parseMapConfig(payload['mapConfig']);
      if (mapConfig != null) {
        parsedMaps.add(mapConfig);
      }
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
    final payloadSprites = payload['sprites'];
    if (payloadSprites is List) {
      for (final item in payloadSprites) {
        final sprite = _parseLobbySprite(item);
        if (sprite != null) {
          sprites.add(sprite);
        }
      }
    }

    // 如果 payload 中没有 sprites，保留现有的 assets
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
  /// 解析地图配置
  LobbyMapConfig? _parseMapConfig(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<dynamic, dynamic>();
    final mapId = map['mapId']?.toString();
    final backgroundUrl = (map['backgroundUrl'] ?? map['background'])?.toString();
    final width = _asDouble(map['width']);
    final height = _asDouble(map['height']);
    if (mapId == null || width == null || height == null) {
      return null;
    }

    final areas = <LobbyWalkableArea>[];
    final walkableAreas = map['walkableAreas'];
    if (walkableAreas is List) {
      for (final item in walkableAreas) {
        if (item is! Map) continue;
        final left = _asDouble(item['left']);
        final top = _asDouble(item['top']);
        final right = _asDouble(item['right']);
        final bottom = _asDouble(item['bottom']);
        if (left == null || top == null || right == null || bottom == null) {
          continue;
        }
        areas.add(LobbyWalkableArea.fromRect(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        ));
      }
    }

    // 解析传送点
    final portals = <LobbyPortal>[];
    final rawPortals = map['portals'];
    if (rawPortals is List) {
      for (final item in rawPortals) {
        if (item is! Map) continue;
        final portal = _parseLobbyPortal(item);
        if (portal != null) {
          portals.add(portal);
        }
      }
    }

    final label = map['label']?.toString() ?? mapId;
    return LobbyMapConfig(
      mapId: mapId,
      displayName: label,
      backgroundUrl: backgroundUrl,
      width: width,
      height: height,
      walkableAreas: areas.isEmpty
          ? const [LobbyWalkableArea(left: 0, top: 0, width: 1600, height: 900)]
          : areas,
      portals: portals,
    );
  }

  /// 解析传送点
  LobbyPortal? _parseLobbyPortal(Map<dynamic, dynamic> raw) {
    final key = raw['key']?.toString();
    final label = raw['label']?.toString();
    final targetMapId = raw['targetMapId']?.toString();
    final x = _asDouble(raw['x']);
    final y = _asDouble(raw['y']);
    final targetX = _asDouble(raw['targetX']) ?? 0;
    final targetY = _asDouble(raw['targetY']) ?? 0;
    if (key == null || key.isEmpty || label == null || targetMapId == null) {
      return null;
    }
    if (x == null || y == null) {
      return null;
    }

    return LobbyPortal(
      key: key,
      label: label,
      x: x,
      y: y,
      targetMapId: targetMapId,
      targetX: targetX,
      targetY: targetY,
    );
  }

  /// 解析角色贴图
  LobbySprite? _parseLobbySprite(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<dynamic, dynamic>();
    final id = map['id']?.toString();
    final label = map['label']?.toString() ?? id ?? '';
    if (id == null || id.isEmpty) return null;

    final accentColorHex = map['accentColor']?.toString();
    final accentColor = _parseHexColor(accentColorHex) ?? const Color(0xFF60A5FA);
    final isDefault = map['isDefault'] == true;

    return LobbySprite(
      id: id,
      label: label,
      accentColor: accentColor,
      spriteUrl: map['spriteUrl']?.toString(),
      previewUrl: map['previewUrl']?.toString(),
      isDefault: isDefault,
    );
  }

  /// 解析用户信息
  LobbyUser? _parseLobbyUser(
    Object? raw, {
    required bool isSelf,
    String? serverUserId,
  }) {
    if (raw is! Map) return null;
    final map = raw.cast<dynamic, dynamic>();
    final userId = map['userId']?.toString();
    final nickname = map['nickname']?.toString();
    final spriteId = map['spriteId']?.toString();
    final x = _asDouble(map['x']);
    final y = _asDouble(map['y']);
    if (userId == null || nickname == null || spriteId == null || x == null || y == null) {
      return null;
    }

    final timestamp = _parseTimestamp(map['lastMessageAt']);
    final isAnonymous = map['isAnonymous'] == true;

    return LobbyUser(
      userId: isSelf ? _selfUserId : userId,
      serverUserId: serverUserId,
      nickname: nickname,
      spriteId: spriteId,
      avatarUrl: map['avatarUrl']?.toString(),
      position: LobbyPosition(x: x, y: y),
      facing: _parseFacing(map['facing']?.toString()),
      isMoving: map['isMoving'] == true,
      isOnline: map['isOnline'] != false,
      isAnonymous: isAnonymous,
      isSelf: isSelf,
      statusText: map['statusText']?.toString(),
      lastMessage: map['lastMessage']?.toString(),
      lastMessageAt: timestamp,
    );
  }

  /// 解析消息
  LobbyMessage? _parseLobbyMessage(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<dynamic, dynamic>();
    final messageId = map['messageId']?.toString();
    final userId = map['userId']?.toString();
    final nickname = map['nickname']?.toString();
    final content = map['content']?.toString();
    final type = _parseMessageType(map['type']?.toString());
    // 如果 timestamp 解析失败，使用当前时间作为兜底，确保消息不丢失
    final timestamp = _parseTimestamp(map['timestamp']) ?? DateTime.now();
    if (messageId == null || userId == null || nickname == null || content == null) {
      return null;
    }

    return LobbyMessage(
      messageId: messageId,
      userId: userId,
      nickname: nickname,
      content: content,
      type: type,
      timestamp: timestamp,
      isAnonymous: map['isAnonymous'] == true,
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
    return value == 'system' ? LobbyMessageType.system : LobbyMessageType.user;
  }

  /// 解析时间戳
  DateTime? _parseTimestamp(Object? raw) {
    if (raw == null) return null;
    if (raw is int) {
      // 检测是否为秒级时间戳（10位数字），如果是则转换为毫秒
      if (raw > 10000000000 && raw < 100000000000) {
        return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
      }
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      final millis = int.tryParse(trimmed);
      if (millis != null) {
        // 检测秒级时间戳
        if (millis > 10000000000 && millis < 100000000000) {
          return DateTime.fromMillisecondsSinceEpoch(millis * 1000);
        }
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
      return DateTime.tryParse(trimmed);
    }
    return null;
  }

  /// 安全的 double 转换
  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // ---------------------------------------------------------------------------
  // Apply 方法（将解析结果应用到状态）
  // ---------------------------------------------------------------------------

  List<LobbyUser> _applyPresenceUpdate(
    List<LobbyUser> users,
    Map<String, dynamic> payload,
  ) {
    final serverUserId = payload['userId']?.toString();
    if (serverUserId == null || serverUserId.isEmpty) return users;
    final updates = payload['updates'];
    if (updates is! Map) return users;

    // 通过 serverUserId 或 userId 查找目标用户
    final idx = users.indexWhere(
      (u) => u.serverUserId == serverUserId || u.userId == serverUserId,
    );
    if (idx < 0) return users;

    return [
      ...users.sublist(0, idx),
      users[idx].copyWith(
        statusText: updates.containsKey('statusText')
            ? updates['statusText']?.toString()
            : users[idx].statusText,
        nickname: updates.containsKey('nickname')
            ? updates['nickname']?.toString() ?? users[idx].nickname
            : users[idx].nickname,
      ),
      ...users.sublist(idx + 1),
    ];
  }

  List<LobbyUser> _applyMoveBroadcast(
    List<LobbyUser> users,
    Map<String, dynamic> payload,
  ) {
    final serverUserId = payload['userId']?.toString();
    if (serverUserId == null || serverUserId.isEmpty) return users;
    final targetX = _asDouble(payload['targetX']);
    final targetY = _asDouble(payload['targetY']);
    if (targetX == null || targetY == null) return users;
    final target = LobbyPosition(x: targetX, y: targetY);
    final facing = _parseFacing(payload['facing']?.toString());

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
    Map<String, dynamic> payload,
  ) {
    final correctionX = _asDouble(payload['correctionX']);
    final correctionY = _asDouble(payload['correctionY']);
    if (correctionX == null || correctionY == null) return users;
    final corrected = LobbyPosition(x: correctionX, y: correctionY);

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

  _SnapshotState _applySnapshot(Map<String, dynamic> payload) {
    final selfServerUserId = payload['self']?['userId']?.toString();
    final self = _parseLobbyUser(payload['self'], isSelf: true, serverUserId: selfServerUserId);

    // selfServerUserId 必须直接从原始 payload 获取，因为 _parseLobbyUser 已经将 self 的 userId 转换为 'self'

    final users = <LobbyUser>[];
    if (self != null) {
      users.add(self);
    }

    // 注意：payload['users'] 中已经包含了当前用户（通过 userId 匹配），
    // 需要排除 self，避免渲染两个自己的角色。
    // 使用 selfServerUserId 来识别并排除。
    final payloadUsers = payload['users'];
    if (payloadUsers is List) {
      for (final item in payloadUsers) {
        // 检查是否与 self 是同一个用户（通过原始 userId 匹配）
        final itemUserId = item is Map ? item['userId']?.toString() : null;
        if (selfServerUserId != null && itemUserId == selfServerUserId) {
          continue; // 跳过 self，避免重复渲染
        }
        final user = _parseLobbyUser(item, isSelf: false, serverUserId: itemUserId);
        if (user != null) {
          users.add(user);
        }
      }
    }

    final recentMessages = <LobbyMessage>[];
    final payloadMessages = payload['recentMessages'];
    if (payloadMessages is List) {
      for (final item in payloadMessages) {
        final message = _parseLobbyMessage(item);
        if (message != null) {
          recentMessages.add(message);
        }
      }
    }

    final selectedSpriteId = state.selectedSpriteId;
    final isAnonymous = self?.isAnonymous ?? state.isAnonymous;

    // 解析分页信息
    final pageInfo = _parsePageInfo(payload['pageInfo']);

    // 解析地图配置（snapshot 中包含当前地图的完整配置）
    final rawMapConfig = payload['mapConfig'];
    LogService.d('[LobbyBloc] _applySnapshot: raw mapConfig=$rawMapConfig');
    final mapConfig = _parseMapConfig(rawMapConfig);
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

  /// 解析分页信息
  LobbyPageInfo? _parsePageInfo(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<dynamic, dynamic>();
    final currentPage = map['currentPage'] as int?;
    final totalPages = map['totalPages'] as int?;
    final pageSize = map['pageSize'] as int?;
    final totalUsers = map['totalUsers'] as int?;
    if (currentPage == null || totalPages == null || pageSize == null || totalUsers == null) {
      return null;
    }
    return LobbyPageInfo(
      currentPage: currentPage,
      totalPages: totalPages,
      pageSize: pageSize,
      totalUsers: totalUsers,
    );
  }

  _ChatState _applyChatMessage(Map<String, dynamic> payload) {
    final message = _parseLobbyMessage(payload['message']);
    if (message == null) {
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
      if (user.userId != normalizedUserId) return user;
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
    const int maxMessages = 100;
    var finalMessages = [...deduplicatedMessages, normalizedMessage];
    if (finalMessages.length > maxMessages) {
      finalMessages = finalMessages.sublist(finalMessages.length - maxMessages);
    }

    return _ChatState(
      users: updatedUsers,
      messages: finalMessages,
    );
  }

  List<LobbyUser> _applySpriteChanged(
    List<LobbyUser> users,
    Map<String, dynamic> payload,
  ) {
    final userId = payload['userId']?.toString();
    final spriteId = payload['spriteId']?.toString();
    if (userId == null || userId.isEmpty || spriteId == null || spriteId.isEmpty) {
      return users;
    }

    final normalizedUserId = _normalizeUserId(userId);
    return users.map((user) {
      if (user.userId != normalizedUserId) return user;
      return user.copyWith(spriteId: spriteId);
    }).toList(growable: false);
  }

  List<LobbyUser> _applyAnonymousChanged(
    List<LobbyUser> users,
    Map<String, dynamic> payload,
  ) {
    final userId = payload['userId']?.toString();
    if (userId == null || userId.isEmpty) return users;
    final isAnonymous = payload['isAnonymous'] == true;
    final displayNickname = payload['displayNickname']?.toString();
    final normalizedUserId = _normalizeUserId(userId);

    return users.map((user) {
      if (user.userId != normalizedUserId) return user;
      return user.copyWith(
        isAnonymous: isAnonymous,
        nickname: displayNickname ?? user.nickname,
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

    // 设置冷却状态
    emit(state.copyWith(broadcastCooldownSeconds: _broadcastCooldownDuration));

    // 发送广播
    await _service.sendBroadcast(content);

    // 启动冷却倒计时（只有在冷却时间大于0时才启动）
    if (_broadcastCooldownDuration > 0) {
      _startBroadcastCooldownTimer();
    }
  }

  void _startBroadcastCooldownTimer() {
    _broadcastCooldownTimer?.cancel();
    _broadcastCooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(const _LobbyBroadcastCooldownTick());
    });
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
    // 发送传送门使用请求
    await _service.usePortal(event.portalKey);
    // 请求发送后清除对话框状态
    emit(state.copyWith(clearNearbyPortal: true));
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

  Future<void> _onBroadcastNotificationsToggled(
    LobbyBroadcastNotificationsToggled event,
    Emitter<LobbyState> emit,
  ) async {
    const settingKey = 'broadcastNotifications';
    final updatedPending = Map<String, bool>.from(state.pendingSettings);
    updatedPending[settingKey] = event.value;

    emit(state.copyWith(
      showBroadcastNotifications: event.value,
      pendingSettings: updatedPending,
      pendingSettingsTimeouts: {
        ...state.pendingSettingsTimeouts,
        settingKey: DateTime.now().add(const Duration(seconds: 3)),
      },
    ));
    _scheduleSettingsTimeoutCheck();
    await _service.setShowBroadcastNotifications(event.value);
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
  LobbyBroadcastMessage? _parseBroadcastMessage(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<dynamic, dynamic>();
    final messageId = map['messageId']?.toString();
    final userId = map['userId']?.toString();
    final nickname = map['nickname']?.toString();
    final content = map['content']?.toString();
    final timestamp = _parseTimestamp(map['timestamp']);
    if (messageId == null || userId == null || nickname == null || content == null) {
      return null;
    }

    return LobbyBroadcastMessage(
      messageId: messageId,
      userId: userId,
      nickname: nickname,
      content: content,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  @override
  Future<void> close() async {
    _isDisposed = true;
    _snapshotOnAssetsReceived?.cancel();
    _snapshotOnAssetsReceived = null;
    _movementTimer?.cancel();
    _bubbleExpiryTimer?.cancel();
    _chatCooldownTimer?.cancel();
    _broadcastCooldownTimer?.cancel();
    _anonymousSwitchCooldownTimer?.cancel();
    _settingsTimeoutTimer?.cancel();
    await _wsSubscription?.cancel();
    await _gameStatusSubscription?.cancel();
    // 注销 AuthService 登录状态监听
    AuthService.instance.removeLoginStateListener(_authStateListener);
    // 不调用 _service.dispose()：LobbyWsService 是单例，跨 LobbyBloc 生命周期复用
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
