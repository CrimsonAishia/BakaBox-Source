import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/server_models.dart';
import '../../models/server_score.dart';
import '../../api/server_api.dart';
import '../../services/source_server_service.dart';
import '../../services/game_launcher_service.dart';
import '../../services/map_change_monitor_service.dart';
import '../../services/obs_server_service.dart';
import '../../services/realtime/realtime_score_updates_channel.dart';
import '../../services/realtime/realtime_server_map_runtime_channel.dart';
import '../../services/realtime/realtime_server_users_count_channel.dart';
import '../../services/server_category_service.dart';
import '../../services/network_mode_service.dart';
import '../../utils/log_service.dart';
import '../../utils/error_utils.dart';
import 'server_event.dart';
import 'server_state.dart';
import '../../services/custom_server_service.dart';
import '../../services/third_party_api_service.dart';

class ServerBloc extends Bloc<ServerEvent, ServerState> {
  // 全局 mapRuntime 缓存，key 为服务器地址
  final Map<String, MapRuntimeData> _mapRuntimeCache = {};
  final Map<String, int> _mapRuntimeLastFetchedCache = {};
  final Map<String, String> _serverMapCache = {}; // 记录服务器当前地图，用于检测换图
  // 全局失败计数缓存，key 为服务器地址
  final Map<String, int> _failureCountCache = {};
  int _currentRequestId = 0;

  // 分类人数查询防重入标记
  bool _isUpdatingCategoryOnlineCounts = false;

  // 分类列表定时刷新定时器（每 10 分钟静默刷新一次）
  Timer? _categoryRefreshTimer;
  static const Duration _categoryRefreshInterval = Duration(minutes: 10);

  // 刷新频率限制：记录每个服务器的刷新时间戳
  final Map<String, List<DateTime>> _refreshHistory = {};
  static const int _maxRefreshPerMinute = 5; // 1分钟内最多刷新5次

  // 指数退避重试配置
  static const List<int> _retryDelays = [1000, 2000, 4000]; // 1s, 2s, 4s
  static const int _maxRetries = 3;
  static const Duration _refreshWindow = Duration(minutes: 1);

  // 单个服务器查询超时（毫秒）
  static const int _serverQueryTimeout = 1000;

  // 单个服务器查询最大重试次数
  static const int _singleServerMaxRetries = 5;

  // 单个服务器重试间隔（毫秒）
  static const int _singleServerRetryDelayMs = 300;

  // 连续失败多少次才标记为离线（需要更高阈值）
  static const int _offlineThreshold = 5;

  // 缓存大小限制：大幅增加容量，避免单个分类服务器数量过多导致缓存被高频淘汰（Thrashing）
  static const int _maxCacheSize = 2000; // 最多缓存 2000 个服务器的数据（实际内存占用极低）

  // 比分查询防抖时间戳（仅记录用于诊断；具体值由 WS 频道维护）
  // ignore: unused_field
  DateTime? _lastScoreFetchTime;

  // 实时比分 / 换图频道
  final RealtimeScoreUpdatesChannel _scoreChannel =
      RealtimeScoreUpdatesChannel();
  final RealtimeServerMapRuntimeChannel _mapRuntimeChannel =
      RealtimeServerMapRuntimeChannel();
  final RealtimeServerUsersCountChannel _usersCountChannel =
      RealtimeServerUsersCountChannel();
  StreamSubscription<ScoreUpdateEvent>? _scoreChannelSubscription;
  StreamSubscription<ServerMapRuntimeEvent>? _mapRuntimeChannelSubscription;
  StreamSubscription<UsersCountUpdateEvent>? _usersCountChannelSubscription;
  bool _realtimeStarted = false;

  // 弱网模式切换监听
  StreamSubscription<bool>? _networkModeSubscription;

  /// 指数退避重试辅助方法
  /// [operation] 要执行的操作
  /// [requestId] 当前请求 ID，用于判断是否被取消
  /// [onRetry] 可选的回调，每次重试前调用
  Future<T?> _retryWithExponentialBackoff<T>({
    required Future<T?> Function() operation,
    required int requestId,
    Future<void> Function(int retryCount)? onRetry,
  }) async {
    for (int retryCount = 0; retryCount < _maxRetries; retryCount++) {
      // 检查是否被取消
      if (requestId != _currentRequestId) {
        return null;
      }

      try {
        final result = await operation();
        if (result != null) {
          return result;
        }
        // 如果结果为空但没有抛异常，也视为失败，需要重试
      } catch (e) {
        // 捕获异常，继续重试
      }

      // 如果还有重试次数，等待后继续
      if (retryCount < _maxRetries - 1) {
        final delay = _retryDelays[retryCount];
        LogService.d('指数退避重试: ${retryCount + 1}/$_maxRetries, 等待 ${delay}ms');
        await Future.delayed(Duration(milliseconds: delay));

        // 触发重试回调
        if (onRetry != null) {
          await onRetry(retryCount);
        }
      }
    }
    return null;
  }

  ServerBloc() : super(const ServerState()) {
    // 注册到 OBS 服务
    ObsServerService().setServerBloc(this);

    on<ServerFetchList>(_onFetchList);
    on<ServerSelectCategory>(_onSelectCategory);
    on<ServerClearCategory>(_onClearCategory);
    on<ServerRefresh>(_onRefresh);
    on<ServerRefreshServers>(_onRefreshServers);
    on<ServerStartPeriodicRefresh>(_onStartPeriodicRefresh);
    on<ServerStopPeriodicRefresh>(_onStopPeriodicRefresh);
    on<ServerPauseRefresh>(_onPauseRefresh);
    on<ServerResumeRefresh>(_onResumeRefresh);
    on<ServerLifecycleChanged>(_onLifecycleChanged);
    on<ServerClearMapCache>(_onClearMapCache);
    on<ServerConnect>(_onConnect);
    on<ServerUpdateCategoryOnlineCounts>(_onUpdateCategoryOnlineCounts);
    on<ServerUpdateSingleServer>(_onUpdateSingleServer);
    on<ServerClearRecentlyUpdated>(_onClearRecentlyUpdated);
    on<ServerAddCategory>(_onAddCategory);
    on<ServerAddServer>(_onAddServer);
    on<ServerAddServerToCategory>(_onAddServerToCategory);
    on<ServerDeleteCategory>(_onDeleteCategory);
    on<ServerRenameCategory>(_onRenameCategory);
    on<ServerDeleteServer>(_onDeleteServer);
    on<ServerResetCountdown>(_onResetCountdown);
    on<ServerRefreshMapCache>(_onRefreshMapCache);
    on<ServerSwitchTab>(_onSwitchTab);
    on<ServerEditServer>(_onEditServer);
    on<ServerUpdateEditedServer>(_onUpdateEditedServer);
    on<ServerReorderServers>(_onReorderServers);
    on<ServerReorderCategories>(_onReorderCategories);
    on<ServerForceRefresh>(_onForceRefresh);
    on<ServerRefreshCategoriesInternal>(_onRefreshCategories);
    on<ServerDismissPendingCategories>(_onDismissPendingCategories);
    on<ServerApplyScoreUpdates>(_onApplyScoreUpdates);
    on<ServerApplyUsersCountUpdates>(_onApplyUsersCountUpdates);
    on<ServerApplyMapRuntimeChange>(_onApplyMapRuntimeChange);

    // 始终订阅频道：弱网模式下 RealtimeService 处于 stopped 状态，
    // 订阅请求会被 RealtimeService 缓存，等到 start() 后自动补发。
    _startRealtime();

    // 监听弱网模式切换：开启时停掉分类静默刷新，关闭时按需恢复
    _networkModeSubscription = NetworkModeService.instance.changes.listen((
      weakNetwork,
    ) {
      if (isClosed) return;
      if (weakNetwork) {
        // 弱网开启：立即停掉 10 分钟分类刷新定时器
        _categoryRefreshTimer?.cancel();
        _categoryRefreshTimer = null;
        LogService.i('[ServerBloc] 弱网模式开启，已停止分类静默刷新');
      } else {
        // 弱网关闭：仅当用户当前正在服务器页（倒计时激活中）才恢复定时器
        // 避免用户不在服务器页时也启动定时器
        if (state.isCountdownActive && _categoryRefreshTimer == null) {
          _categoryRefreshTimer = Timer.periodic(_categoryRefreshInterval, (_) {
            add(const ServerRefreshCategoriesInternal());
          });
          LogService.i('[ServerBloc] 弱网模式关闭，已恢复分类静默刷新');
        }
      }
    });
  }

  /// 启动 WS 实时频道订阅（构造时一次性启动，close 时释放）
  void _startRealtime() {
    if (_realtimeStarted) return;
    _realtimeStarted = true;

    _scoreChannel.subscribe();
    _scoreChannelSubscription = _scoreChannel.events.listen((event) {
      if (isClosed) return;
      add(
        ServerApplyScoreUpdates(
          scores: event.scores,
          isSnapshot: event.kind == ScoreUpdateEventKind.snapshot,
        ),
      );
    });

    _mapRuntimeChannel.subscribe();
    _mapRuntimeChannelSubscription = _mapRuntimeChannel.events.listen((event) {
      if (isClosed) return;
      // snapshot 不必逐条触发；交给后续 changed 事件即可
      if (event.kind != ServerMapRuntimeEventKind.changed) return;
      for (final entry in event.entries) {
        add(
          ServerApplyMapRuntimeChange(
            serverAddress: entry.serverAddress,
            newMapName: entry.mapName,
            oldMapName: entry.oldMapName,
          ),
        );
      }
    });

    _usersCountChannel.subscribe();
    _usersCountChannelSubscription = _usersCountChannel.events.listen((event) {
      if (isClosed) return;
      add(
        ServerApplyUsersCountUpdates(
          counts: event.counts,
          isSnapshot: event.kind == UsersCountUpdateEventKind.snapshot,
        ),
      );
    });
  }

  void _stopRealtime() {
    if (!_realtimeStarted) return;
    _realtimeStarted = false;
    _scoreChannelSubscription?.cancel();
    _scoreChannelSubscription = null;
    _mapRuntimeChannelSubscription?.cancel();
    _mapRuntimeChannelSubscription = null;
    _mapRuntimeChannel.unsubscribe();
    _usersCountChannelSubscription?.cancel();
    _usersCountChannelSubscription = null;
    _usersCountChannel.unsubscribe();
  }

  /// 重置倒计时（递增 countdownResetKey 触发 UI 重置）
  void _resetCountdown(Emitter<ServerState> emit) {
    emit(state.copyWith(countdownResetKey: state.countdownResetKey + 1));
  }

  Future<void> _onFetchList(
    ServerFetchList event,
    Emitter<ServerState> emit,
  ) async {
    // 防重入：已在加载中则忽略
    if (state.isLoading) return;

    emit(state.copyWith(isLoading: true, error: null));
    try {
      final apiCategories = await ServerCategoryService.instance
          .getApiCategories();

      // 加载自定义分类
      final customCategories = await CustomServerService.loadCustomCategories();

      // 合并分类：自定义分类置顶
      final allCategories = [...customCategories, ...apiCategories];

      if (allCategories.isNotEmpty) {
        emit(state.copyWith(serverCategories: allCategories, isLoading: false));
        LogService.i(
          '成功加载 ${customCategories.length} 个自定义分类和 ${apiCategories.length} 个 API 分类',
        );

        // 移动端不自动选择第一个分类，让用户手动选择
        // 桌面端会在 UI 层处理自动选择逻辑
        add(ServerUpdateCategoryOnlineCounts());
      } else {
        emit(state.copyWith(isLoading: false, error: '未获取到服务器数据'));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: '加载服务器列表失败'));
      LogService.e('加载服务器列表失败: $e', e);
    }
  }

  Future<void> _onAddServerToCategory(
    ServerAddServerToCategory event,
    Emitter<ServerState> emit,
  ) async {
    try {
      final updatedCategory = await CustomServerService.addServerItemToCategory(
        event.categoryName,
        event.serverItem,
        isFromApi: event.isFromApi,
        sourceApiUrl: event.sourceApiUrl,
        sourceApiCategoryName: event.sourceApiCategoryName,
      );

      // 更新分类列表
      final categoryIndex = state.serverCategories.indexWhere(
        (c) => c.modelName == event.categoryName,
      );

      final updatedCategories = List<ServerCategory>.from(state.serverCategories);
      
      if (categoryIndex != -1) {
        updatedCategories[categoryIndex] = updatedCategory;
      } else {
        // 如果找不到说明是新分类
        updatedCategories.add(updatedCategory);
      }

      emit(state.copyWith(
        serverCategories: updatedCategories,
        successMessage: '已添加 ${event.serverItem.nickname ?? event.serverItem.serverAddress}',
      ));

      // 如果当前选中的是这个分类，顺便刷新一下
      if (state.selectedCategory?.modelName == event.categoryName) {
        add(ServerSelectCategory(updatedCategory, forceRefresh: true));
      }
    } catch (e) {
      LogService.e('添加服务器对象失败: $e', e);
      // 忽略单个添加的错误或者合并成统一提示
    }
  }

  Future<void> _onSelectCategory(
    ServerSelectCategory event,
    Emitter<ServerState> emit,
  ) async {
    // 如果是相同分类且服务器数量一致，跳过刷新（除非强制刷新）
    // 添加/删除服务器后，serverList 数量会变化，此时需要刷新
    final isSameCategory =
        state.selectedCategory?.modelName == event.category.modelName;
    final serverCountMatch =
        state.servers.length == event.category.serverList.length;

    // 只有在相同分类且服务器数量一致且非强制刷新时才跳过
    if (isSameCategory &&
        serverCountMatch &&
        state.servers.isNotEmpty &&
        !event.forceRefresh) {
      return;
    }

    // 切换分类时重置比分查询时间，确保新分类能立即获取比分
    if (!isSameCategory) {
      _lastScoreFetchTime = null;
    }

    final requestId = ++_currentRequestId;

    final servers = event.category.serverList.map((serverItem) {
      final address = serverItem.address ?? serverItem.serverAddress;
      // 从全局缓存恢复 mapRuntime 数据
      final cachedRuntime = address != null ? _mapRuntimeCache[address] : null;
      final cachedLastFetched = address != null
          ? _mapRuntimeLastFetchedCache[address]
          : null;
      // 从全局缓存恢复失败计数（仅用于记录，不直接标记离线）
      final cachedFailures = address != null
          ? (_failureCountCache[address] ?? 0)
          : 0;

      return ExtendedServerItem(
        serverItem: serverItem,
        isLoading: true,
        mapRuntime: cachedRuntime,
        mapRuntimeLastFetched: cachedLastFetched,
        mapRuntimeError: false,
        consecutiveFailures: cachedFailures,
        // 不在查询前标记离线，让 _fetchServersInfo 决定
        // 这样可以避免缓存的失败计数导致服务器在查询前就显示离线
        isOffline: false,
      );
    }).toList();

    // 如果是空分类（自定义分类没有服务器），不显示加载状态
    final isEmptyCategory = servers.isEmpty;

    emit(
      state.copyWith(
        selectedCategory: event.category,
        servers: servers,
        isLoadingServers: !isEmptyCategory, // 空分类不显示加载状态
        loadingPhase: LoadingPhase.loadingA2S,
        loadingStartTime: DateTime.now(),
      ),
    );

    _resetCountdown(emit);

    // 只有非空分类才获取服务器信息
    if (!isEmptyCategory) {
      await _fetchServersInfo(requestId, emit);
    }
  }

  Future<void> _onRefreshServers(
    ServerRefreshServers event,
    Emitter<ServerState> emit,
  ) async {
    // 如果没有选中分类或没有服务器，直接返回
    if (state.selectedCategory == null || state.servers.isEmpty) {
      return;
    }

    final categoryName = state.selectedCategory!.modelName ?? '';
    // 如果正在加载，直接返回（避免重复请求）
    if (state.isCategoryLoading(categoryName)) {
      LogService.d('分类 $categoryName 正在加载中，跳过刷新');
      return;
    }

    final requestId = ++_currentRequestId;

    final loadingCategories = Set<String>.from(state.loadingCategories)
      ..add(categoryName);
    emit(state.copyWith(loadingCategories: loadingCategories));

    // 异步执行，10秒超时，但需要等待完成以保持 emit 有效
    try {
      await _fetchServersInfo(requestId, emit).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          LogService.d('服务器刷新超时（10秒），强制结束');
        },
      );
    } catch (e) {
      LogService.e('服务器刷新异常: $e', e);
    } finally {
      // 无论成功、失败、超时，都要清除 loading 状态
      // 注意：即使 requestId 不匹配（用户切换了分类），也要清除当前分类的 loading 状态
      // 否则会导致该分类永远处于 loading 状态，无法再次刷新
      if (!emit.isDone) {
        final updatedLoadingCategories = Set<String>.from(
          state.loadingCategories,
        )..remove(categoryName);
        emit(state.copyWith(loadingCategories: updatedLoadingCategories));
      }
    }
  }

  Future<void> _fetchServersInfo(
    int requestId,
    Emitter<ServerState> emit,
  ) async {
    if (state.servers.isEmpty) return;

    final serverApi = ServerApi();

    // 收集所有需要查询的服务器地址（使用 Set 去重，防止同一服务器被添加多次导致查询冲突）
    final a2sServerAddresses = <String>{};
    final apiServerAddresses = <String>{};
    
    for (final server in state.servers) {
      final address =
          server.serverItem.address ?? server.serverItem.serverAddress;
      if (address != null) {
        if (server.serverItem.dataSourceMode == 'api') {
          apiServerAddresses.add(address);
        } else {
          a2sServerAddresses.add(address);
        }
      }
    }

    if (a2sServerAddresses.isEmpty && apiServerAddresses.isEmpty) return;

    if (requestId != _currentRequestId || emit.isDone) return;
    
    // 异步拉取第三方 API 数据
    Future<void> fetchApiServers() async {
      if (apiServerAddresses.isEmpty) return;
      try {
        final apiMap = await ThirdPartyApiService.fetchCS2ZeServersMap();
        if (requestId != _currentRequestId || emit.isDone) return;

        for (final address in apiServerAddresses) {
          final apiServerData = apiMap[address];
          
          final currentIndex = state.servers.indexWhere(
            (s) => (s.serverItem.address ?? s.serverItem.serverAddress) == address,
          );
          if (currentIndex == -1) continue;
          
          final currentServer = state.servers[currentIndex];
          
          if (apiServerData != null) {
            // 解析出 API 数据
            final hasDataChanged =
                currentServer.serverData == null ||
                currentServer.serverData!.players != apiServerData.players ||
                currentServer.serverData!.map != apiServerData.map;
            
            // 我们重用 server_models 里面的机制，把 API 数据转为 ServerInfo
            final info = apiServerData.toServerInfo();

            final mapChanged =
                currentServer.serverData != null &&
                currentServer.serverData!.map != info.map;

            _failureCountCache[address] = 0; // 重置失败计数

            final updatedServer = currentServer.copyWith(
              serverData: info,
              updatedAt: DateTime.now(),
              recentlyUpdated: hasDataChanged && currentServer.serverData != null,
              isLoading: false,
              hasError: false,
              consecutiveFailures: 0,
              mapInfo: mapChanged ? null : currentServer.mapInfo,
            );

            _updateServerByAddress(address, updatedServer, emit);

            // 获取背景图信息 (如果第三方API提供了图片，我们可以封装一个 MapData)
            if (apiServerData.imageUrl != null) {
               final fakeMapData = MapData(
                 id: 0,
                 mapName: info.map ?? '',
                 mapLabel: apiServerData.mapCn ?? info.map ?? '',
                 mapUrl: apiServerData.imageUrl!,
               );
               add(ServerUpdateSingleServer(address: address, mapInfo: fakeMapData));
            } else if (info.map != null && (mapChanged || currentServer.mapInfo == null)) {
               _fetchMapInfoAsync(address, info.map!, requestId, serverApi);
            }
          } else {
            // 未找到数据，视为离线或错误
            final newFailureCount = currentServer.consecutiveFailures + 1;
            final isNowOffline = newFailureCount >= _offlineThreshold;
            _failureCountCache[address] = newFailureCount;
            
            if (isNowOffline) {
              _updateServerByAddress(
                address,
                currentServer.copyWith(
                  isLoading: false,
                  hasError: true,
                  consecutiveFailures: newFailureCount,
                  isOffline: true,
                  clearServerData: true,
                  clearMapInfo: true,
                ),
                emit,
              );
            } else {
              _updateServerByAddress(
                address,
                currentServer.copyWith(
                  isLoading: false,
                  hasError: true,
                  consecutiveFailures: newFailureCount,
                ),
                emit,
              );
            }
          }
        }
      } catch (e) {
        LogService.e('批量加载 API 服务器失败: $e', e);
        // 标记所有 API 服务器为错误
        for (final address in apiServerAddresses) {
           final currentIndex = state.servers.indexWhere(
            (s) => (s.serverItem.address ?? s.serverItem.serverAddress) == address,
          );
          if (currentIndex != -1 && !emit.isDone) {
            final currentServer = state.servers[currentIndex];
            final newFailureCount = currentServer.consecutiveFailures + 1;
            _failureCountCache[address] = newFailureCount;
            _updateServerByAddress(
              address,
              currentServer.copyWith(
                isLoading: false,
                hasError: true,
                consecutiveFailures: newFailureCount,
              ),
              emit,
            );
          }
        }
      }
    }

    // 并行执行 A2S 和 API
    await Future.wait([
      Future.wait(
        a2sServerAddresses.map(
          (address) => _fetchSingleServerInfo(
            address: address,
            requestId: requestId,
            serverApi: serverApi,
            emit: emit,
          ),
        ),
        eagerError: false,
      ),
      fetchApiServers(),
    ]);

    // 比分数据由 `score.updates` WS 频道推送：
    // - 订阅时服务端会下发 snapshot
    // - 后续单条 updated 事件会自动更新 servers
    // 这里只在加载阶段切换到 completed，并复用频道现有的 snapshot 给已加载的服务器赋初值
    if (!emit.isDone && requestId == _currentRequestId) {
      emit(state.copyWith(loadingPhase: LoadingPhase.completed));
      _applyScoreSnapshotForCurrentServers(emit);
      _applyUsersCountSnapshotForCurrentServers(emit);
    }

    if (!emit.isDone && requestId == _currentRequestId) {
      _updateCurrentCategoryOnlineCount(emit);
      emit(
        state.copyWith(
          isLoadingServers: false,
          lastRefreshTime: DateTime.now(), // 记录刷新时间
        ),
      );
    }

    _clearRecentlyUpdatedAfterDelay(requestId);
  }

  /// 将单条比分应用到服务器，返回应用后的服务器实例。
  ///
  /// 满足以下任一条件时，原样返回（不产生新实例，便于调用方用 [identical] 判断是否变化）：
  /// - 比分为空或缺少 CT/T 分数；
  /// - 比分所属地图与服务器当前地图不一致（换图后残留的旧比分）；
  /// - 比分与现有比分完全相同（避免无意义的 emit）。
  ExtendedServerItem _applyScoreToServer(
    ExtendedServerItem server,
    ServerScore? score,
  ) {
    if (score == null || score.ctScore == null || score.tScore == null) {
      return server;
    }
    if (!TeamScores.isMapMatched(score.mapName, server.serverData?.map)) {
      return server;
    }
    final next = TeamScores(
      ctScore: score.ctScore,
      tScore: score.tScore,
      dataQuality: score.dataQuality,
      mapName: score.mapName,
    );
    if (server.teamScores == next) return server;
    return server.copyWith(teamScores: next);
  }

  /// 用 [RealtimeScoreUpdatesChannel] 缓存的最新 snapshot 给当前服务器赋初值。
  ///
  /// 比分通过 WS 推送（订阅时下发 snapshot + 后续 updated 事件），
  /// 这里只是在切换分类后立刻把已有的 snapshot 应用到本地服务器上，避免空窗。
  void _applyScoreSnapshotForCurrentServers(Emitter<ServerState> emit) {
    if (state.servers.isEmpty) return;
    final snapshot = _scoreChannel.latestSnapshot;
    if (snapshot.isEmpty) return;

    bool changed = false;
    final updatedServers = state.servers.map((server) {
      final address =
          server.serverItem.address ?? server.serverItem.serverAddress;
      if (address == null) return server;
      final updated = _applyScoreToServer(server, snapshot[address]);
      if (!identical(updated, server)) changed = true;
      return updated;
    }).toList();

    if (!changed) return;
    if (emit.isDone) return;
    emit(state.copyWith(servers: updatedServers));
    _lastScoreFetchTime = DateTime.now();
  }

  void _applyUsersCountSnapshotForCurrentServers(Emitter<ServerState> emit) {
    if (state.servers.isEmpty) return;
    final snapshot = _usersCountChannel.latestSnapshot;

    // 注意：server.users.count 的 snapshot 只包含人数 > 0 的服务器，
    // 所以「不在 snapshot 中」= 该服务器当前排队/暖服人数为 0。
    // 这里必须把不在 snapshot 中的服务器归零，否则会残留上一次的 +N，
    // 表现为人数显示不正常。语义需与 _onApplyUsersCountUpdates 的 snapshot 分支一致。
    bool changed = false;
    final updatedServers = state.servers.map((server) {
      final address =
          server.serverItem.address ?? server.serverItem.serverAddress;
      if (address == null) return server;

      final count = snapshot[address];
      final queueCount = count?.queueCount ?? 0;
      final warmupCount = count?.warmupCount ?? 0;

      if (server.queueCount == queueCount &&
          server.warmupCount == warmupCount) {
        return server;
      }
      changed = true;
      return server.copyWith(
        queueCount: queueCount,
        warmupCount: warmupCount,
      );
    }).toList();

    if (!changed) return;
    if (emit.isDone) return;
    emit(state.copyWith(servers: updatedServers));
  }

  /// 获取单个服务器信息（异步独立执行）
  /// 注意：此方法处理的是服务器信息查询的失败，不影响离线状态判定
  /// 离线状态只在刷新周期结束后根据连续失败次数判定
  Future<void> _fetchSingleServerInfo({
    required String address,
    required int requestId,
    required ServerApi serverApi,
    required Emitter<ServerState> emit,
  }) async {
    if (requestId != _currentRequestId || emit.isDone) return;

    try {
      // 带重试的服务器信息查询：超时由 _getServerInfo 内部统一控制（_serverQueryTimeout），最多重试 3 次
      SourceServerInfo? info;
      for (int retry = 0; retry < _singleServerMaxRetries; retry++) {
        if (requestId != _currentRequestId || emit.isDone) return;
        // 超时逻辑由 _getServerInfo 内部的 SourceServerService.getServerInfo(timeout:) 控制
        // 超时时底层会抛异常，_getServerInfo 的 catch 捕获后返回 null
        info = await _getServerInfo(address);
        if (info != null) break; // 成功则退出重试
        if (retry < _singleServerMaxRetries - 1) {
          LogService.d(
            '服务器查询失败，准备重试 ($address)，第 ${retry + 1}/$_singleServerMaxRetries 次',
          );
          // 还有重试机会，等待后再试
          await Future.delayed(
            const Duration(milliseconds: _singleServerRetryDelayMs),
          );
          if (requestId != _currentRequestId || emit.isDone) return;
        }
      }

      if (requestId != _currentRequestId || emit.isDone) return;

      // 通过地址查找当前服务器索引（并行更新时索引可能变化）
      final currentIndex = state.servers.indexWhere(
        (s) => (s.serverItem.address ?? s.serverItem.serverAddress) == address,
      );
      if (currentIndex == -1) return;

      final currentServer = state.servers[currentIndex];

      if (info != null) {
        final newMap = info.map;
        final cachedMap = _serverMapCache[address];
        // 检测换图：与缓存的地图名比较
        // 过滤 graphics_settings 地图（服务器重启时的加载地图）
        final mapChanged =
            cachedMap != null &&
            cachedMap != newMap &&
            newMap != 'graphics_settings';
        final hasDataChanged =
            currentServer.serverData == null ||
            currentServer.serverData!.players != info.players ||
            currentServer.serverData!.map != info.map;

        // 更新地图缓存（graphics_settings 不更新缓存，保留原地图名）
        if (newMap != 'graphics_settings') {
          _serverMapCache[address] = newMap;
        }

        // 如果换图了，清除该服务器的 runtime 缓存
        if (mapChanged) {
          _mapRuntimeCache.remove(address);
          _mapRuntimeLastFetchedCache.remove(address);
        }

        // 成功获取数据，重置失败计数
        // 注意：不再自动判定离线，离线状态在刷新周期结束后统一判定
        _failureCountCache[address] = 0; // 更新全局缓存
        final updatedServer = currentServer.copyWith(
          serverData: _convertSourceServerInfo(info),
          updatedAt: DateTime.now(),
          recentlyUpdated: hasDataChanged && currentServer.serverData != null,
          isLoading: false,
          hasError: false,
          consecutiveFailures: 0,
          // 不再自动标记 isOffline，让数据保留以便显示
          // 离线判定逻辑移到刷新周期结束后
          mapInfo: mapChanged ? null : currentServer.mapInfo,
          mapRuntime: mapChanged ? null : currentServer.mapRuntime,
          mapRuntimeLastFetched: mapChanged
              ? null
              : currentServer.mapRuntimeLastFetched,
          mapRuntimeError: mapChanged ? false : currentServer.mapRuntimeError,
          clearTeamScores: mapChanged,
        );

        _updateServerByAddress(address, updatedServer, emit);

        // graphics_settings 是服务器启动中的加载地图，不获取其背景图
        final isCustomServer = currentServer.serverItem.isCustom;
        final isValidMap = newMap != 'graphics_settings';

        if (isValidMap) {
          // 需要获取背景图的情况：
          // 1. 换图了（mapChanged）
          // 2. 没有背景图数据
          // 3. 当前背景图对应的地图与新地图不同（从 graphics_settings 恢复或首次加载后地图变化）
          final currentMapInInfo = currentServer.serverData?.map;
          final needFetchMapInfo =
              mapChanged ||
              currentServer.mapInfo == null ||
              (currentMapInInfo != null && currentMapInInfo != newMap);
          if (needFetchMapInfo) {
            _fetchMapInfoAsync(address, info.map, requestId, serverApi);
          }
          // 自定义服务器不获取 mapRuntime（需要 API 交互）
          // 只有换图或没有缓存的 runtime 时才重新获取
          if (!isCustomServer &&
              (mapChanged ||
                  (currentServer.mapRuntime == null &&
                      _mapRuntimeCache[address] == null))) {
            _fetchMapRuntimeAsync(address, info.map, requestId, serverApi);
          }
        }
      } else {
        // 服务器无法访问，增加失败计数
        final newFailureCount = currentServer.consecutiveFailures + 1;
        final isNowOffline =
            newFailureCount >= _offlineThreshold; // 使用配置的阈值判定离线
        _failureCountCache[address] = newFailureCount; // 更新全局缓存

        // 只有当真正达到离线阈值时才更新服务器状态
        // 这样可以保留上一次成功的数据，直到确认离线才清除
        if (isNowOffline) {
          _updateServerByAddress(
            address,
            currentServer.copyWith(
              isLoading: false,
              hasError: true,
              consecutiveFailures: newFailureCount,
              isOffline: true,
              clearServerData: true, // 离线时清除服务器数据
              clearMapRuntime: true, // 离线时清除地图运行时间
              clearMapInfo: true, // 离线时清除地图信息（背景图）
            ),
            emit,
          );

          // 离线时清除 runtime 缓存，但保留 _serverMapCache 以便恢复后检测换图
          _mapRuntimeCache.remove(address);
          _mapRuntimeLastFetchedCache.remove(address);
        } else {
          // 未达到离线阈值，只更新失败计数，保留现有数据
          // 这样服务器仍然显示最后一次成功的数据
          _updateServerByAddress(
            address,
            currentServer.copyWith(
              isLoading: false,
              hasError: true,
              consecutiveFailures: newFailureCount,
              // 不更新 isOffline，不清除数据
            ),
            emit,
          );
        }
      }
    } catch (e) {
      LogService.e('加载服务器数据失败 ($address): $e', e);
      final currentIndex = state.servers.indexWhere(
        (s) => (s.serverItem.address ?? s.serverItem.serverAddress) == address,
      );
      if (currentIndex != -1 && !emit.isDone) {
        final currentServer = state.servers[currentIndex];
        // 服务器异常，增加失败计数
        final newFailureCount = currentServer.consecutiveFailures + 1;
        final isNowOffline = newFailureCount >= _offlineThreshold;
        _failureCountCache[address] = newFailureCount; // 更新全局缓存

        // 只有当真正达到离线阈值时才更新服务器状态
        if (isNowOffline) {
          _updateServerByAddress(
            address,
            currentServer.copyWith(
              isLoading: false,
              hasError: true,
              consecutiveFailures: newFailureCount,
              isOffline: true,
              clearServerData: true,
              clearMapRuntime: true,
              clearMapInfo: true,
            ),
            emit,
          );

          _mapRuntimeCache.remove(address);
          _mapRuntimeLastFetchedCache.remove(address);
        } else {
          // 未达到离线阈值，只更新失败计数，保留现有数据
          _updateServerByAddress(
            address,
            currentServer.copyWith(
              isLoading: false,
              hasError: true,
              consecutiveFailures: newFailureCount,
            ),
            emit,
          );
        }
      }
    }
  }

  /// 通过地址更新所有匹配的服务器（并行安全）
  void _updateServerByAddress(
    String address,
    ExtendedServerItem server,
    Emitter<ServerState> emit,
  ) {
    if (emit.isDone) return;

    final servers = List<ExtendedServerItem>.from(state.servers);
    bool changed = false;

    for (int i = 0; i < servers.length; i++) {
      if ((servers[i].serverItem.address ??
              servers[i].serverItem.serverAddress) ==
          address) {
        // 保留原有的 serverItem（如自定义分组的 remark/nickname），其余部分同步
        servers[i] = server.copyWith(serverItem: servers[i].serverItem);
        changed = true;
      }
    }

    if (changed) {
      emit(state.copyWith(servers: servers));
    }
  }

  void _clearRecentlyUpdatedAfterDelay(int requestId) {
    Future.delayed(const Duration(seconds: 2), () {
      if (isClosed) return;
      if (requestId == _currentRequestId &&
          state.servers.any((s) => s.recentlyUpdated)) {
        add(ServerClearRecentlyUpdated(requestId));
      }
    });
  }

  void _onClearRecentlyUpdated(
    ServerClearRecentlyUpdated event,
    Emitter<ServerState> emit,
  ) {
    if (event.requestId != _currentRequestId) return;
    final updatedServers = state.servers
        .map((s) => s.recentlyUpdated ? s.copyWith(recentlyUpdated: false) : s)
        .toList();
    emit(state.copyWith(servers: updatedServers));
  }

  void _onUpdateSingleServer(
    ServerUpdateSingleServer event,
    Emitter<ServerState> emit,
  ) {
    final index = state.servers.indexWhere(
      (s) =>
          (s.serverItem.address ?? s.serverItem.serverAddress) == event.address,
    );
    if (index == -1) return;

    final servers = List<ExtendedServerItem>.from(state.servers);
    final current = servers[index];

    // 更新全局缓存
    if (event.mapRuntime != null) {
      _mapRuntimeCache[event.address] = event.mapRuntime!;
      _mapRuntimeLastFetchedCache[event.address] =
          DateTime.now().millisecondsSinceEpoch;
      _trimCacheIfNeeded();
    }

    servers[index] = current.copyWith(
      pingInfo: event.pingInfo ?? current.pingInfo,
      mapInfo: event.mapInfo ?? current.mapInfo,
      mapRuntime: event.mapRuntime ?? current.mapRuntime,
      mapRuntimeLastFetched: event.mapRuntime != null
          ? DateTime.now().millisecondsSinceEpoch
          : current.mapRuntimeLastFetched,
      mapRuntimeError: event.mapRuntimeError ?? current.mapRuntimeError,
    );
    emit(state.copyWith(servers: servers));
  }

  void _fetchMapInfoAsync(
    String address,
    String mapName,
    int requestId,
    ServerApi serverApi,
  ) {
    _retryWithExponentialBackoff<MapData>(
          operation: () => serverApi.getMapInfo(mapName),
          requestId: requestId,
        )
        .then((mapInfo) {
          if (isClosed) return;
          if (requestId == _currentRequestId && mapInfo != null) {
            add(ServerUpdateSingleServer(address: address, mapInfo: mapInfo));
          }
        })
        .catchError((e) {
          LogService.e('加载地图信息失败 ($mapName): $e', e);
        });
  }

  void _fetchMapRuntimeAsync(
    String address,
    String mapName,
    int requestId,
    ServerApi serverApi,
  ) {
    _retryWithExponentialBackoff<MapRuntimeData>(
          operation: () => serverApi.getMapRuntime(address, mapName),
          requestId: requestId,
        )
        .then((mapRuntime) {
          if (isClosed) return;
          if (requestId == _currentRequestId) {
            add(
              ServerUpdateSingleServer(
                address: address,
                mapRuntime: mapRuntime,
                mapRuntimeError: mapRuntime == null,
              ),
            );
          }
        })
        .catchError((e) {
          LogService.e('加载地图运行时间失败 ($address, $mapName): $e', e);
          if (!isClosed) {
            add(
              ServerUpdateSingleServer(address: address, mapRuntimeError: true),
            );
          }
        });
  }

  Future<void> _onClearCategory(
    ServerClearCategory event,
    Emitter<ServerState> emit,
  ) async {
    emit(
      state.copyWith(
        clearSelectedCategory: true,
        servers: [],
        isLoadingServers: false,
      ),
    );
    _resetCountdown(emit);
  }

  Future<void> _onRefresh(
    ServerRefresh event,
    Emitter<ServerState> emit,
  ) async {
    await _onFetchList(ServerFetchList(), emit);
    if (state.selectedCategory != null) {
      final updatedCategory = state.serverCategories.firstWhere(
        (cat) => cat.modelName == state.selectedCategory!.modelName,
        orElse: () => state.selectedCategory!,
      );
      add(ServerSelectCategory(updatedCategory));
    }
  }

  void _onStartPeriodicRefresh(
    ServerStartPeriodicRefresh event,
    Emitter<ServerState> emit,
  ) {
    // 弱网模式下：不启动倒计时，不启动后台静默刷新
    if (NetworkModeService.instance.weakNetwork) {
      emit(state.copyWith(isCountdownActive: false));
      _categoryRefreshTimer?.cancel();
      _categoryRefreshTimer = null;
      return;
    }

    // 只设置状态，刷新时机由 UI 倒计时进度条的 onComplete 控制
    emit(state.copyWith(isCountdownActive: true));

    // 启动分类列表定时刷新（每 10 分钟静默更新一次）
    _categoryRefreshTimer?.cancel();
    _categoryRefreshTimer = Timer.periodic(_categoryRefreshInterval, (_) {
      add(const ServerRefreshCategoriesInternal());
    });
  }

  void _onStopPeriodicRefresh(
    ServerStopPeriodicRefresh event,
    Emitter<ServerState> emit,
  ) {
    emit(state.copyWith(isCountdownActive: false));
    _categoryRefreshTimer?.cancel();
    _categoryRefreshTimer = null;
  }

  void _onPauseRefresh(ServerPauseRefresh event, Emitter<ServerState> emit) {
    emit(state.copyWith(isPaused: true));
  }

  void _onResumeRefresh(ServerResumeRefresh event, Emitter<ServerState> emit) {
    // 弱网模式下：不自动刷新，仅取消暂停状态
    if (NetworkModeService.instance.weakNetwork) {
      emit(state.copyWith(isPaused: false));
      return;
    }

    // 根据当前页面选择对应的最后刷新时间
    final DateTime? lastRefresh;
    if (state.selectedCategory != null) {
      lastRefresh = state.lastRefreshTime;
    } else {
      lastRefresh = state.onlineCountsLastFetched ?? state.lastRefreshTime;
    }

    // 判断离开时间是否过长（超过10秒视为数据过期）
    final isDataStale =
        lastRefresh == null ||
        DateTime.now().difference(lastRefresh).inSeconds > 10;

    if (isDataStale) {
      // 数据过期：立即刷新数据并重置倒计时
      emit(
        state.copyWith(
          isPaused: false,
          countdownResetKey: state.countdownResetKey + 1,
        ),
      );
      // 根据当前页面状态触发对应的刷新
      if (state.selectedCategory != null) {
        add(ServerRefreshServers());
      } else {
        add(ServerUpdateCategoryOnlineCounts());
      }
    } else {
      // 数据仍然新鲜：只取消暂停，让倒计时继续
      emit(state.copyWith(isPaused: false));
    }
  }

  void _onLifecycleChanged(
    ServerLifecycleChanged event,
    Emitter<ServerState> emit,
  ) {
    if (event.isResumed) {
      add(ServerResumeRefresh());
    } else {
      add(ServerPauseRefresh());
    }
  }

  void _onClearMapCache(ServerClearMapCache event, Emitter<ServerState> emit) {
    final serverApi = ServerApi();
    if (event.mapName != null) {
      serverApi.clearMapInfoCacheForMap(event.mapName!);
    } else {
      serverApi.clearMapInfoCache();
    }
  }

  Future<void> _onConnect(
    ServerConnect event,
    Emitter<ServerState> emit,
  ) async {
    final address =
        event.server.serverItem.address ??
        event.server.serverItem.serverAddress;
    if (address == null) return;

    final gameLauncher = GameLauncherService();
    // 获取服务器的游戏类型与 AppID
    final gameType = event.server.serverData?.gameType;
    final appId = event.server.serverData?.appId;

    try {
      final result = event.password?.isNotEmpty == true
          ? await gameLauncher.connectToPasswordServer(
              address,
              event.password!,
              gameType: gameType,
              appId: appId,
            )
          : await gameLauncher.connectToServer(
              address,
              gameType: gameType,
              appId: appId,
            );

      if (result.success) {
        LogService.i('连接命令已发送: ${result.message}');
        emit(
          state.copyWith(
            successMessage: result.message,
            needCsgoLegacy: false,
            needManualLaunch: false,
          ),
        );
      } else {
        LogService.w('连接失败: ${result.error}');
        emit(
          state.copyWith(
            error: result.error,
            needCsgoLegacy: result.needCsgoLegacy,
            needManualLaunch: result.needManualLaunch,
          ),
        );
      }
    } catch (e) {
      LogService.e('连接服务器异常: $e', e);
      emit(
        state.copyWith(
          error: '连接服务器异常',
          needCsgoLegacy: false,
          needManualLaunch: false,
        ),
      );
    }
  }

  Future<void> _onUpdateCategoryOnlineCounts(
    ServerUpdateCategoryOnlineCounts event,
    Emitter<ServerState> emit,
  ) async {
    if (state.serverCategories.isEmpty) return;

    // 防重入：如果正在更新，直接返回，避免多次触发导致人数翻倍
    if (_isUpdatingCategoryOnlineCounts) return;
    _isUpdatingCategoryOnlineCounts = true;

    try {
      final isFirstLoad = !state.hasEverLoadedOnlineCounts;
      if (isFirstLoad) emit(state.copyWith(isLoadingOnlineCounts: true));

      // 记录当前选中分类名
      final selectedCategoryName = state.selectedCategory?.modelName;

      // 为所有分类初始化 categoryOnlineCounts 默认值（如果还没有记录）
      final currentCounts = Map<String, int>.from(state.categoryOnlineCounts);
      for (final category in state.serverCategories) {
        final categoryName = category.modelName ?? '';
        if (!currentCounts.containsKey(categoryName)) {
          currentCounts[categoryName] = 0;
        }
      }

      // 先 emit 初始化的数据
      if (!emit.isDone && isFirstLoad) {
        emit(
          state.copyWith(
            categoryOnlineCounts: currentCounts,
            isLoadingOnlineCounts: true,
            hasEverLoadedOnlineCounts: true,
          ),
        );
      }

      // 所有的待查询地址和所属分类映射（仅非选中分类）
      final pendingAddresses = <String>{};
      final categoryAddressesMap = <String, Set<String>>{};

      for (final category in state.serverCategories) {
        final categoryName = category.modelName ?? '';

        // 跳过当前选中的分类，由 _updateCurrentCategoryOnlineCount 负责更新
        // 避免与 _fetchServersInfo 并发查询导致数据覆盖
        if (categoryName == selectedCategoryName) {
          // 如果已有服务器数据，立即更新；否则保留现有值，等待 _fetchServersInfo 完成
          if (state.servers.any((s) => s.serverData != null)) {
            final totalOnline = _calcCurrentCategoryOnlineCount();
            if (!emit.isDone) {
              final latestCounts = Map<String, int>.from(
                state.categoryOnlineCounts,
              );
              latestCounts[categoryName] = totalOnline;
              emit(state.copyWith(categoryOnlineCounts: latestCounts));
            }
          }
          continue;
        }

        final uniqueAddresses = <String>{};
        for (final serverItem in category.serverList) {
          final address = serverItem.address ?? serverItem.serverAddress;
          if (address != null && address.isNotEmpty) {
            uniqueAddresses.add(address);
            pendingAddresses.add(address);
          }
        }
        categoryAddressesMap[categoryName] = uniqueAddresses;
      }

      // 非选中分类：每台服务器查完立即累加到对应分类并 emit，实现实时增长效果
      // serverPlayers 作为本轮查询结果的共享缓冲，用于计算分类总人数
      final serverPlayers = <String, int>{};

      // 构建地址 → 所属分类名的反向映射，方便查完一台立即定位分类
      final addressToCategoryName = <String, String>{};
      for (final entry in categoryAddressesMap.entries) {
        for (final addr in entry.value) {
          addressToCategoryName[addr] = entry.key;
        }
      }

      // 并发控制：分批请求（20 个一批），防止并发爆 UDP 端口
      // 每台服务器查完后立即更新对应分类的人数，不等整批完成
      const batchSize = 20;
      final addressList = pendingAddresses.toList();

      for (int i = 0; i < addressList.length; i += batchSize) {
        if (emit.isDone) break;
        final end = (i + batchSize < addressList.length)
            ? i + batchSize
            : addressList.length;
        final batch = addressList.sublist(i, end);

        await Future.wait(
          batch.map((address) async {
            final count = await _fetchSingleServerPlayerCount(address);
            serverPlayers[address] = count;

            // 查完一台立即更新对应分类的人数（累加效果）
            if (emit.isDone) return;
            final categoryName = addressToCategoryName[address];
            if (categoryName == null) return;

            // 重新累加该分类当前已查完的所有服务器人数
            final addressSet = categoryAddressesMap[categoryName]!;
            int total = 0;
            for (final addr in addressSet) {
              total += serverPlayers[addr] ?? 0; // 未查完的地址贡献 0，查完后会再次更新
            }

            // 只有人数实际变化时才 emit，避免无意义的 UI 重建
            final currentTotal = state.categoryOnlineCounts[categoryName] ?? 0;
            if (total == currentTotal) return;

            final latestCounts = Map<String, int>.from(
              state.categoryOnlineCounts,
            )..[categoryName] = total;
            emit(state.copyWith(categoryOnlineCounts: latestCounts));
          }),
          eagerError: false,
        );
      }

      // 所有查询完成，关闭加载状态（仅首次加载时需要）并记录刷新时间
      if (!emit.isDone) {
        if (isFirstLoad) {
          emit(
            state.copyWith(
              isLoadingOnlineCounts: false,
              onlineCountsLastFetched: DateTime.now(),
            ),
          );
        } else {
          emit(state.copyWith(onlineCountsLastFetched: DateTime.now()));
        }
      }
    } catch (e) {
      LogService.e('批量更新分类在线人数失败: $e', e);
      if (!emit.isDone) {
        emit(state.copyWith(isLoadingOnlineCounts: false));
      }
    } finally {
      _isUpdatingCategoryOnlineCounts = false;
    }
  }

  /// 获取单个服务器人数（用于非选中分类的独立查询）
  /// 失败返回 0（服务器无响应即视为 0 人）
  Future<int> _fetchSingleServerPlayerCount(String address) async {
    final parts = address.split(':');
    if (parts.length != 2) return 0;

    final ip = parts[0];
    final port = int.parse(parts[1]);

    for (int retry = 0; retry < _singleServerMaxRetries; retry++) {
      try {
        final info = await SourceServerService.getServerInfo(
          ip,
          port,
          timeout: _serverQueryTimeout,
        );
        if (info != null) {
          return info.players;
        }
      } catch (e) {
        // 捕获异常，准备重试
      }

      if (retry < _singleServerMaxRetries - 1) {
        await Future.delayed(
          const Duration(milliseconds: _singleServerRetryDelayMs),
        );
      }
    }

    return 0;
  }

  /// 计算当前选中分类的在线人数
  ///
  /// 累加规则：
  /// - 有 serverData（在线）：使用实时人数
  /// - 无 serverData 且已确认离线（isOffline == true）：贡献 0
  /// - 无 serverData 但未达到离线阈值（网络抖动中）：使用 serverPlayerCache 中的上次成功值
  int _calcCurrentCategoryOnlineCount() {
    int total = 0;
    for (final s in state.servers) {
      if (s.serverData != null) {
        // 在线：使用实时人数
        total += s.serverData!.players ?? 0;
      } else if (!s.isOffline) {
        // 未达到离线阈值（网络抖动）：使用缓存的上次成功值
        final addr = s.serverItem.address ?? s.serverItem.serverAddress;
        if (addr != null) {
          total += state.serverPlayerCache[addr] ?? 0;
        }
      }
      // isOffline == true：贡献 0，不累加
    }
    return total;
  }

  void _updateCurrentCategoryOnlineCount(Emitter<ServerState> emit) {
    if (state.selectedCategory == null) return;
    final categoryName = state.selectedCategory!.modelName ?? '';

    // 先将本轮成功获取到数据的服务器人数写入缓存
    final updatedCache = Map<String, int>.from(state.serverPlayerCache);
    for (final s in state.servers) {
      final addr = s.serverItem.address ?? s.serverItem.serverAddress;
      if (addr != null && s.serverData != null) {
        updatedCache[addr] = s.serverData!.players ?? 0;
      }
    }

    // 计算分类总人数（使用更新后的缓存）
    int totalOnline = 0;
    for (final s in state.servers) {
      if (s.serverData != null) {
        totalOnline += s.serverData!.players ?? 0;
      } else if (!s.isOffline) {
        // 网络抖动中（未达到离线阈值）：保留上次成功的人数
        final addr = s.serverItem.address ?? s.serverItem.serverAddress;
        if (addr != null) {
          totalOnline += updatedCache[addr] ?? 0;
        }
      }
      // isOffline == true：贡献 0
    }

    final updatedCounts = Map<String, int>.from(state.categoryOnlineCounts)
      ..[categoryName] = totalOnline;
    emit(
      state.copyWith(
        categoryOnlineCounts: updatedCounts,
        serverPlayerCache: updatedCache,
      ),
    );
  }

  Future<SourceServerInfo?> _getServerInfo(String address) async {
    final parts = address.split(':');
    if (parts.length != 2) return null;
    try {
      final ip = parts[0];
      final port = int.parse(parts[1]);
      return await SourceServerService.getServerInfo(
        ip,
        port,
        timeout: _serverQueryTimeout,
      );
    } catch (e) {
      // LogService.e('获取服务器信息失败 ($address): $e', e);
      return null;
    }
  }

  ServerInfo _convertSourceServerInfo(SourceServerInfo sourceInfo) {
    return ServerInfo(
      hostName: sourceInfo.name,
      map: sourceInfo.map,
      players: sourceInfo.players,
      maxPlayers: sourceInfo.maxPlayers,
      gameType: sourceInfo.gameType,
      pingLatency: sourceInfo.ping,
      appId: sourceInfo.appId,
    );
  }

  Future<List<SourceServerPlayer>> getServerPlayers(String address) async {
    final parts = address.split(':');
    if (parts.length != 2) return [];
    try {
      return await SourceServerService.getServerPlayers(
        parts[0],
        int.parse(parts[1]),
        timeout: 3000,
      );
    } catch (e) {
      LogService.e('获取玩家列表失败 ($address): $e', e);
      return [];
    }
  }

  // ========== 自定义分类和服务器管理 ==========

  Future<void> _onAddCategory(
    ServerAddCategory event,
    Emitter<ServerState> emit,
  ) async {
    try {
      // 检查是否与现有分类（包括 API 分类）重名
      final existingCategory = state.serverCategories.firstWhere(
        (c) => c.modelName == event.categoryName,
        orElse: () => ServerCategory(modelName: null, serverList: []),
      );

      if (existingCategory.modelName != null) {
        emit(state.copyWith(error: '分类 "${event.categoryName}" 已存在'));
        LogService.w('添加自定义分类失败: 分类名已存在');
        return;
      }

      final newCategory = await CustomServerService.addCustomCategory(
        event.categoryName,
      );

      // 将新分类插入到列表开头（自定义分类置顶）
      final customCategories = state.serverCategories
          .where((c) => c.isCustom)
          .toList();
      final apiCategories = state.serverCategories
          .where((c) => !c.isCustom)
          .toList();
      final updatedCategories = [
        ...customCategories,
        newCategory,
        ...apiCategories,
      ];

      emit(
        state.copyWith(
          serverCategories: updatedCategories,
          successMessage: '分类 "${event.categoryName}" 已添加',
        ),
      );
      LogService.i('添加自定义分类成功: ${event.categoryName}');
    } catch (e) {
      LogService.e('添加自定义分类失败: $e', e);
      emit(
        state.copyWith(
          error: ErrorUtils.getErrorMessage(e, defaultMessage: '添加分类失败'),
        ),
      );
    }
  }

  Future<void> _onAddServer(
    ServerAddServer event,
    Emitter<ServerState> emit,
  ) async {
    try {
      final updatedCategory = await CustomServerService.addServerToCategory(
        event.categoryName,
        event.serverAddress,
        nickname: event.nickname,
      );

      // 更新分类列表
      final categoryIndex = state.serverCategories.indexWhere(
        (c) => c.modelName == event.categoryName,
      );

      if (categoryIndex != -1) {
        final updatedCategories = List<ServerCategory>.from(
          state.serverCategories,
        );
        updatedCategories[categoryIndex] = updatedCategory;

        // 如果当前选中的是该分类，同时更新 selectedCategory
        final isCurrentCategory =
            state.selectedCategory?.modelName == event.categoryName;

        emit(
          state.copyWith(
            serverCategories: updatedCategories,
            selectedCategory: isCurrentCategory
                ? updatedCategory
                : state.selectedCategory,
            successMessage: '服务器 "${event.serverAddress}" 已添加',
          ),
        );

        // 如果当前选中的是该分类，刷新服务器列表（强制刷新）
        if (isCurrentCategory) {
          add(ServerSelectCategory(updatedCategory, forceRefresh: true));
        }

        LogService.i(
          '添加服务器成功: ${event.serverAddress} -> ${event.categoryName}',
        );
      }
    } catch (e) {
      LogService.e('添加服务器失败: $e', e);
      emit(
        state.copyWith(
          error: ErrorUtils.getErrorMessage(e, defaultMessage: '添加服务器失败'),
        ),
      );
    }
  }

  Future<void> _onDeleteCategory(
    ServerDeleteCategory event,
    Emitter<ServerState> emit,
  ) async {
    try {
      // 先取消该分类下所有服务器的换图监控
      final monitorService = MapChangeMonitorService();
      final categoryToDelete = state.serverCategories.firstWhere(
        (c) => c.modelName == event.categoryName,
        orElse: () => ServerCategory(modelName: '', serverList: []),
      );

      for (final server in categoryToDelete.serverList) {
        final address = server.address ?? server.serverAddress;
        if (address != null) {
          // 清理该服务器的所有缓存
          _failureCountCache.remove(address);
          _mapRuntimeCache.remove(address);
          _mapRuntimeLastFetchedCache.remove(address);
          _serverMapCache.remove(address);

          if (monitorService.isMonitoring(address)) {
            await monitorService.removeMonitor(address);
            LogService.i('删除分类时取消换图监控: $address');
          }
        }
      }

      await CustomServerService.deleteCustomCategory(event.categoryName);

      final updatedCategories = state.serverCategories
          .where((c) => c.modelName != event.categoryName)
          .toList();

      // 清理该分类的在线人数记录和人数缓存
      final updatedOnlineCounts = Map<String, int>.from(
        state.categoryOnlineCounts,
      )..remove(event.categoryName);

      // 清理该分类所有服务器的人数缓存
      final updatedPlayerCache = Map<String, int>.from(state.serverPlayerCache);
      for (final server in categoryToDelete.serverList) {
        final address = server.address ?? server.serverAddress;
        if (address != null) updatedPlayerCache.remove(address);
      }

      emit(
        state.copyWith(
          serverCategories: updatedCategories,
          categoryOnlineCounts: updatedOnlineCounts,
          serverPlayerCache: updatedPlayerCache,
          successMessage: '分类 "${event.categoryName}" 已删除',
        ),
      );

      // 如果删除的是当前选中的分类，清除选中状态
      if (state.selectedCategory?.modelName == event.categoryName) {
        add(ServerClearCategory());
      }

      LogService.i('删除自定义分类成功: ${event.categoryName}');
    } catch (e) {
      LogService.e('删除自定义分类失败: $e', e);
      emit(
        state.copyWith(
          error: ErrorUtils.getErrorMessage(e, defaultMessage: '删除分类失败'),
        ),
      );
    }
  }

  Future<void> _onRenameCategory(
    ServerRenameCategory event,
    Emitter<ServerState> emit,
  ) async {
    try {
      final updatedCategory = await CustomServerService.renameCustomCategory(
        event.oldName,
        event.newName,
      );

      // 更新分类列表
      final updatedCategories = state.serverCategories.map((c) {
        if (c.modelName == event.oldName) {
          return updatedCategory;
        }
        return c;
      }).toList();

      // 更新在线人数记录的 key
      final updatedOnlineCounts = Map<String, int>.from(
        state.categoryOnlineCounts,
      );
      if (updatedOnlineCounts.containsKey(event.oldName)) {
        final count = updatedOnlineCounts.remove(event.oldName);
        if (count != null) {
          updatedOnlineCounts[event.newName] = count;
        }
      }

      // 如果重命名的是当前选中的分类，更新选中状态
      ServerCategory? newSelectedCategory = state.selectedCategory;
      if (state.selectedCategory?.modelName == event.oldName) {
        newSelectedCategory = updatedCategory;
      }

      emit(
        state.copyWith(
          serverCategories: updatedCategories,
          categoryOnlineCounts: updatedOnlineCounts,
          selectedCategory: newSelectedCategory,
          successMessage: '分类已重命名为 "${event.newName}"',
        ),
      );

      LogService.i('重命名自定义分类成功: ${event.oldName} -> ${event.newName}');
    } catch (e) {
      LogService.e('重命名自定义分类失败: $e', e);
      emit(
        state.copyWith(
          error: ErrorUtils.getErrorMessage(e, defaultMessage: '重命名分类失败'),
        ),
      );
    }
  }

  Future<void> _onDeleteServer(
    ServerDeleteServer event,
    Emitter<ServerState> emit,
  ) async {
    try {
      // 清理该服务器的所有缓存
      _failureCountCache.remove(event.serverAddress);
      _mapRuntimeCache.remove(event.serverAddress);
      _mapRuntimeLastFetchedCache.remove(event.serverAddress);
      _serverMapCache.remove(event.serverAddress);
      // 清理人数缓存，避免同一 IP 重新添加时读到旧值
      final updatedPlayerCache = Map<String, int>.from(state.serverPlayerCache)
        ..remove(event.serverAddress);

      // 取消该服务器的换图监控（如果有）
      final monitorService = MapChangeMonitorService();
      if (monitorService.isMonitoring(event.serverAddress)) {
        await monitorService.removeMonitor(event.serverAddress);
        LogService.i('删除服务器时取消换图监控: ${event.serverAddress}');
      }

      final updatedCategory =
          await CustomServerService.deleteServerFromCategory(
            event.categoryName,
            event.serverAddress,
          );

      // 更新分类列表
      final categoryIndex = state.serverCategories.indexWhere(
        (c) => c.modelName == event.categoryName,
      );

      if (categoryIndex != -1) {
        final updatedCategories = List<ServerCategory>.from(
          state.serverCategories,
        );
        updatedCategories[categoryIndex] = updatedCategory;

        // 重新计算该分类的在线人数（排除被删除的服务器）
        final updatedOnlineCounts = Map<String, int>.from(
          state.categoryOnlineCounts,
        );
        if (state.selectedCategory?.modelName == event.categoryName) {
          // 从当前服务器列表中排除被删除的服务器，重新计算人数
          // 使用与 _updateCurrentCategoryOnlineCount 一致的逻辑：
          // 在线用实时值，抖动中用缓存值，确认离线贡献 0
          final remainingServers = state.servers.where(
            (s) =>
                (s.serverItem.address ?? s.serverItem.serverAddress) !=
                event.serverAddress,
          );
          int newCount = 0;
          for (final s in remainingServers) {
            if (s.serverData != null) {
              newCount += s.serverData!.players ?? 0;
            } else if (!s.isOffline) {
              final addr = s.serverItem.address ?? s.serverItem.serverAddress;
              if (addr != null) {
                newCount += updatedPlayerCache[addr] ?? 0;
              }
            }
          }
          updatedOnlineCounts[event.categoryName] = newCount;
        }

        emit(
          state.copyWith(
            serverCategories: updatedCategories,
            categoryOnlineCounts: updatedOnlineCounts,
            serverPlayerCache: updatedPlayerCache,
            successMessage: '服务器 "${event.serverAddress}" 已删除',
          ),
        );

        // 如果当前选中的是该分类，刷新服务器列表（强制刷新）
        if (state.selectedCategory?.modelName == event.categoryName) {
          add(ServerSelectCategory(updatedCategory, forceRefresh: true));
        }

        LogService.i(
          '删除服务器成功: ${event.serverAddress} <- ${event.categoryName}',
        );
      }
    } catch (e) {
      LogService.e('删除服务器失败: $e', e);
      emit(
        state.copyWith(
          error: ErrorUtils.getErrorMessage(e, defaultMessage: '删除服务器失败'),
        ),
      );
    }
  }

  void _onResetCountdown(
    ServerResetCountdown event,
    Emitter<ServerState> emit,
  ) {
    // 重置倒计时：先关闭再开启，并递增 key 触发 UI 重建
    emit(
      state.copyWith(
        isCountdownActive: true,
        countdownResetKey: state.countdownResetKey + 1,
      ),
    );
  }

  Future<void> _onRefreshMapCache(
    ServerRefreshMapCache event,
    Emitter<ServerState> emit,
  ) async {
    // 防抖：如果该地图正在刷新，直接返回
    if (state.isMapRefreshing(event.address)) {
      return;
    }

    // 频率限制检查
    final now = DateTime.now();
    final history = _refreshHistory[event.address] ?? [];

    // 清理1分钟之前的记录
    history.removeWhere((time) => now.difference(time) > _refreshWindow);

    // 检查是否超过限制
    if (history.length >= _maxRefreshPerMinute) {
      LogService.w('刷新频率超限: ${event.address} (${history.length}次/分钟)');
      // 设置错误信息，UI 会显示 toast 提示
      emit(state.copyWith(error: '刷新过于频繁，请稍后再试'));
      // 清除错误信息（5秒后，与 toast 显示时长一致）
      Future.delayed(const Duration(seconds: 5), () {
        if (!emit.isDone) {
          emit(state.copyWith(error: null));
        }
      });
      return;
    }

    // 记录本次刷新时间
    history.add(now);
    _refreshHistory[event.address] = history;

    // 添加到刷新集合
    final refreshingMaps = Set<String>.from(state.refreshingMaps)
      ..add(event.address);
    emit(state.copyWith(refreshingMaps: refreshingMaps));

    // 记录开始时间
    final startTime = DateTime.now();

    try {
      final serverApi = ServerApi();

      // 直接从 API 获取最新地图信息（不清除缓存）
      final mapInfo = await serverApi.refreshMapInfo(event.mapName);

      if (mapInfo != null && !emit.isDone) {
        // 更新服务器的地图信息
        add(ServerUpdateSingleServer(address: event.address, mapInfo: mapInfo));
        LogService.i('地图信息已更新: ${event.mapName}');
      }
    } finally {
      // 确保至少显示1秒的加载动画
      final elapsed = DateTime.now().difference(startTime);
      final remainingTime = const Duration(seconds: 1) - elapsed;

      if (remainingTime.inMilliseconds > 0) {
        await Future.delayed(remainingTime);
      }

      // 移除刷新状态
      if (!emit.isDone) {
        final updatedRefreshingMaps = Set<String>.from(state.refreshingMaps)
          ..remove(event.address);
        emit(state.copyWith(refreshingMaps: updatedRefreshingMaps));
      }
    }
  }

  /// 清理过大的缓存，保留最近使用的数据
  void _trimCacheIfNeeded() {
    if (_mapRuntimeCache.length <= _maxCacheSize) return;

    // 按最后获取时间排序，移除最旧的条目
    final sortedEntries = _mapRuntimeLastFetchedCache.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final toRemove = sortedEntries
        .take(_mapRuntimeCache.length - _maxCacheSize)
        .map((e) => e.key)
        .toList();

    for (final key in toRemove) {
      _mapRuntimeCache.remove(key);
      _mapRuntimeLastFetchedCache.remove(key);
      _serverMapCache.remove(key);
      _failureCountCache.remove(key);
    }

    LogService.d('清理 ServerBloc 缓存: 移除 ${toRemove.length} 条旧数据');
  }

  /// 切换分类 tab
  void _onSwitchTab(ServerSwitchTab event, Emitter<ServerState> emit) {
    emit(state.copyWith(selectedTabIndex: event.tabIndex));

    // 检查当前选中的分类是否在新 tab 中
    final currentCategory = state.selectedCategory;
    if (currentCategory != null) {
      final isInNewTab = event.tabIndex == 0
          ? !currentCategory
                .isCustom // 默认 tab：检查是否为 API 分类
          : currentCategory.isCustom; // 自定义 tab：检查是否为自定义分类

      // 如果当前分类不在新 tab 中，自动选择新 tab 的第一个分类
      if (!isInNewTab) {
        final newTabCategories = event.tabIndex == 0
            ? state.serverCategories.where((c) => !c.isCustom).toList()
            : state.serverCategories.where((c) => c.isCustom).toList();

        if (newTabCategories.isNotEmpty) {
          add(ServerSelectCategory(newTabCategories.first));
        } else {
          // 新 tab 没有分类，清除选中状态
          add(ServerClearCategory());
        }
      }
    }
  }

  /// 编辑自定义服务器地址
  Future<void> _onEditServer(
    ServerEditServer event,
    Emitter<ServerState> emit,
  ) async {
    try {
      // 清理旧地址的缓存
      _failureCountCache.remove(event.oldServerAddress);
      _mapRuntimeCache.remove(event.oldServerAddress);
      _mapRuntimeLastFetchedCache.remove(event.oldServerAddress);
      _serverMapCache.remove(event.oldServerAddress);
      // 清理旧地址的人数缓存
      if (state.serverPlayerCache.containsKey(event.oldServerAddress)) {
        emit(
          state.copyWith(
            serverPlayerCache: Map<String, int>.from(state.serverPlayerCache)
              ..remove(event.oldServerAddress),
          ),
        );
      }

      // 取消旧地址的换图监控（如果有）
      final monitorService = MapChangeMonitorService();
      if (monitorService.isMonitoring(event.oldServerAddress)) {
        await monitorService.removeMonitor(event.oldServerAddress);
        LogService.i('编辑服务器时取消换图监控: ${event.oldServerAddress}');
      }

      final updatedCategory = await CustomServerService.editServerInCategory(
        event.categoryName,
        event.oldServerAddress,
        event.newServerAddress,
        nickname: event.nickname,
      );

      // 更新分类列表
      final categoryIndex = state.serverCategories.indexWhere(
        (c) => c.modelName == event.categoryName,
      );

      if (categoryIndex != -1) {
        final updatedCategories = List<ServerCategory>.from(
          state.serverCategories,
        );
        updatedCategories[categoryIndex] = updatedCategory;

        // 如果当前选中的是该分类，只更新被编辑的服务器，而不是刷新整个列表
        if (state.selectedCategory?.modelName == event.categoryName) {
          final servers = List<ExtendedServerItem>.from(state.servers);
          final serverIndex = servers.indexWhere(
            (s) =>
                (s.serverItem.address ?? s.serverItem.serverAddress) ==
                event.oldServerAddress,
          );

          if (serverIndex != -1) {
            // 创建新的 ServerItem，保留备注名
            final newServerItem = ServerItem(
              address: event.newServerAddress,
              serverAddress: event.newServerAddress,
              isCustom: true,
              nickname: event.nickname,
            );

            // 创建新的 ExtendedServerItem，标记为加载中以触发数据获取
            servers[serverIndex] = ExtendedServerItem(
              serverItem: newServerItem,
              isLoading: true,
              serverData: null, // 清空旧数据
              mapInfo: null,
              mapRuntime: null,
            );

            emit(
              state.copyWith(
                serverCategories: updatedCategories,
                selectedCategory: updatedCategory,
                servers: servers,
                successMessage: '服务器已更新',
              ),
            );

            // 异步获取被编辑服务器的数据（不阻塞 UI）
            _fetchEditedServerData(event.newServerAddress, serverIndex);
          } else {
            emit(
              state.copyWith(
                serverCategories: updatedCategories,
                selectedCategory: updatedCategory,
                successMessage: '服务器已更新',
              ),
            );
          }
        } else {
          emit(
            state.copyWith(
              serverCategories: updatedCategories,
              successMessage: '服务器已更新',
            ),
          );
        }

        LogService.i(
          '编辑服务器成功: ${event.oldServerAddress} -> ${event.newServerAddress}',
        );
      }
    } catch (e) {
      LogService.e('编辑服务器失败: $e', e);
      emit(
        state.copyWith(
          error: ErrorUtils.getErrorMessage(e, defaultMessage: '编辑服务器失败'),
        ),
      );
    }
  }

  /// 异步获取被编辑服务器的数据
  void _fetchEditedServerData(String serverAddress, int serverIndex) async {
    try {
      // 获取服务器数据
      final info = await _getServerInfo(serverAddress);

      if (isClosed) return;

      // 检查服务器是否还在列表中且地址匹配
      if (serverIndex >= state.servers.length) return;
      final currentServer = state.servers[serverIndex];
      if ((currentServer.serverItem.address ??
              currentServer.serverItem.serverAddress) !=
          serverAddress) {
        return;
      }

      if (info != null) {
        final serverData = _convertSourceServerInfo(info);

        // 使用 add 发送更新事件，而不是直接 emit（因为这是异步方法）
        add(
          ServerUpdateEditedServer(
            serverAddress: serverAddress,
            serverData: serverData,
          ),
        );

        // 获取地图信息
        final mapName = info.map;
        if (mapName != 'graphics_settings') {
          final serverApi = ServerApi();
          serverApi
              .getMapInfo(mapName)
              .then((mapInfo) {
                if (isClosed) return;
                if (mapInfo != null) {
                  add(
                    ServerUpdateSingleServer(
                      address: serverAddress,
                      mapInfo: mapInfo,
                    ),
                  );
                }
              })
              .catchError((e) {
                LogService.e('获取地图信息失败: $e', e);
              });
        }
      } else {
        // 获取失败
        if (!isClosed) {
          add(
            ServerUpdateEditedServer(
              serverAddress: serverAddress,
              serverData: null,
              hasError: true,
            ),
          );
        }
      }
    } catch (e) {
      LogService.e('获取服务器数据失败: $serverAddress, $e', e);
      if (!isClosed) {
        add(
          ServerUpdateEditedServer(
            serverAddress: serverAddress,
            serverData: null,
            hasError: true,
          ),
        );
      }
    }
  }

  /// 处理被编辑服务器的数据更新
  void _onUpdateEditedServer(
    ServerUpdateEditedServer event,
    Emitter<ServerState> emit,
  ) {
    final index = state.servers.indexWhere(
      (s) =>
          (s.serverItem.address ?? s.serverItem.serverAddress) ==
          event.serverAddress,
    );
    if (index == -1) return;

    final servers = List<ExtendedServerItem>.from(state.servers);
    final current = servers[index];

    servers[index] = current.copyWith(
      isLoading: false,
      serverData: event.serverData,
      hasError: event.hasError,
    );

    emit(state.copyWith(servers: servers));
  }

  /// 重新排序自定义服务器
  Future<void> _onReorderServers(
    ServerReorderServers event,
    Emitter<ServerState> emit,
  ) async {
    // 先进行乐观更新（立即更新 UI），避免与 ReorderableListView 动画冲突
    if (state.selectedCategory?.modelName == event.categoryName) {
      final servers = List<ExtendedServerItem>.from(state.servers);
      if (event.oldIndex >= 0 &&
          event.oldIndex < servers.length &&
          event.newIndex >= 0 &&
          event.newIndex < servers.length) {
        final item = servers.removeAt(event.oldIndex);
        servers.insert(event.newIndex, item);

        // 立即更新服务器列表顺序
        emit(state.copyWith(servers: servers));
      }
    }

    // 然后异步保存到存储
    try {
      final updatedCategory =
          await CustomServerService.reorderServersInCategory(
            event.categoryName,
            event.oldIndex,
            event.newIndex,
          );

      // 更新分类列表
      final categoryIndex = state.serverCategories.indexWhere(
        (c) => c.modelName == event.categoryName,
      );

      if (categoryIndex != -1) {
        final updatedCategories = List<ServerCategory>.from(
          state.serverCategories,
        );
        updatedCategories[categoryIndex] = updatedCategory;

        emit(
          state.copyWith(
            serverCategories: updatedCategories,
            selectedCategory:
                state.selectedCategory?.modelName == event.categoryName
                ? updatedCategory
                : state.selectedCategory,
          ),
        );

        LogService.i('重新排序服务器成功: ${event.oldIndex} -> ${event.newIndex}');
      }
    } catch (e) {
      LogService.e('重新排序服务器失败: $e', e);
      // 如果保存失败，回滚 UI 状态
      if (state.selectedCategory?.modelName == event.categoryName) {
        final servers = List<ExtendedServerItem>.from(state.servers);
        if (event.newIndex >= 0 &&
            event.newIndex < servers.length &&
            event.oldIndex >= 0 &&
            event.oldIndex <= servers.length) {
          final item = servers.removeAt(event.newIndex);
          servers.insert(event.oldIndex, item);
          emit(
            state.copyWith(
              servers: servers,
              error: ErrorUtils.getErrorMessage(e, defaultMessage: '排序失败'),
            ),
          );
        } else {
          emit(
            state.copyWith(
              error: ErrorUtils.getErrorMessage(e, defaultMessage: '排序失败'),
            ),
          );
        }
      } else {
        emit(
          state.copyWith(
            error: ErrorUtils.getErrorMessage(e, defaultMessage: '排序失败'),
          ),
        );
      }
    }
  }

  /// 重新排序自定义分类
  Future<void> _onReorderCategories(
    ServerReorderCategories event,
    Emitter<ServerState> emit,
  ) async {
    // 先进行乐观更新，避免与 ReorderableListView 动画冲突
    final customCategories = state.serverCategories
        .where((c) => c.isCustom)
        .toList();

    if (event.oldIndex >= 0 &&
        event.oldIndex < customCategories.length &&
        event.newIndex >= 0 &&
        event.newIndex < customCategories.length) {
      // 创建新的分类列表副本
      final updatedCustomCategories = List<ServerCategory>.from(
        customCategories,
      );
      final item = updatedCustomCategories.removeAt(event.oldIndex);
      updatedCustomCategories.insert(event.newIndex, item);

      // 为每个分类更新 sortOrder
      for (var i = 0; i < updatedCustomCategories.length; i++) {
        updatedCustomCategories[i] = updatedCustomCategories[i].copyWith(
          sortOrder: i,
        );
      }

      // 更新整个分类列表（保留默认分类，更新自定义分类的顺序）
      final allCategories = <ServerCategory>[];
      // 添加默认分类（保持原顺序）
      allCategories.addAll(state.serverCategories.where((c) => !c.isCustom));
      // 添加排序后的自定义分类
      allCategories.addAll(updatedCustomCategories);

      // 立即更新 UI
      emit(state.copyWith(serverCategories: allCategories));

      // 然后异步保存到存储
      try {
        await CustomServerService.reorderCategories(
          updatedCustomCategories
              .map((c) => c.modelName)
              .whereType<String>()
              .toList(),
        );

        LogService.i('重新排序分类成功: ${event.oldIndex} -> ${event.newIndex}');
      } catch (e) {
        LogService.e('重新排序分类失败: $e', e);
        // 如果保存失败，回滚 UI 状态
        emit(
          state.copyWith(
            serverCategories: state.serverCategories,
            error: ErrorUtils.getErrorMessage(e, defaultMessage: '排序失败'),
          ),
        );
      }
    }
  }

  /// 强制刷新：重置所有状态，用于手动点击刷新时恢复正常
  Future<void> _onForceRefresh(
    ServerForceRefresh event,
    Emitter<ServerState> emit,
  ) async {
    if (state.selectedCategory == null) return;

    // 1. 强制清除所有 loading 状态
    final clearedLoadingCategories = <String>{};

    // 2. 递增 requestId，取消所有进行中的请求
    final requestId = ++_currentRequestId;

    // 3. 重置防重入标记
    _isUpdatingCategoryOnlineCounts = false;

    // 4. 重置比分查询时间，确保强制刷新后能立即重新获取比分
    _lastScoreFetchTime = null;

    // 5. 清除当前分类所有服务器的失败计数缓存（解决离线状态残留问题）
    for (final server in state.servers) {
      final address =
          server.serverItem.address ?? server.serverItem.serverAddress;
      if (address != null) {
        _failureCountCache.remove(address);
      }
    }

    // 6. 重置服务器列表为加载状态
    // 保留 serverData/mapInfo/teamScores，避免卡片切换为骨架屏
    // 骨架屏切换会导致 MouseRegion 的 hover 状态丢失（Flutter widget 重建问题）
    final servers = state.servers.map((server) {
      final address =
          server.serverItem.address ?? server.serverItem.serverAddress;
      return ExtendedServerItem(
        serverItem: server.serverItem,
        isLoading: true,
        // 保留现有的服务器数据和地图信息（避免骨架屏闪烁）
        serverData: server.serverData,
        mapInfo: server.mapInfo,
        // 保留 ping 信息，避免强制刷新后丢失
        pingInfo: server.pingInfo,
        // 保留缓存的数据
        mapRuntime: address != null ? _mapRuntimeCache[address] : null,
        mapRuntimeLastFetched: address != null
            ? _mapRuntimeLastFetchedCache[address]
            : null,
        mapRuntimeError: false,
        consecutiveFailures: 0,
        isOffline: false,
        // 保留比分数据，新数据到来后会覆盖
        teamScores: server.teamScores,
      );
    }).toList();

    // 5. 发射重置后的状态
    emit(
      state.copyWith(
        servers: servers,
        isLoadingServers: servers.isNotEmpty,
        loadingCategories: clearedLoadingCategories,
        error: null,
        successMessage: null,
        loadingPhase: LoadingPhase.loadingA2S,
        loadingStartTime: DateTime.now(),
      ),
    );

    LogService.i('强制刷新：已重置所有状态，开始重新加载服务器数据');

    // 6. 重新获取服务器信息
    if (servers.isNotEmpty) {
      try {
        await _fetchServersInfo(requestId, emit);
      } catch (e) {
        LogService.e('强制刷新异常: $e', e);
        if (!emit.isDone) {
          emit(state.copyWith(isLoadingServers: false, error: '刷新失败，请重试'));
        }
      } finally {
        // 兜底：确保 isLoadingServers 不会永远卡在 true
        if (!emit.isDone && state.isLoadingServers) {
          emit(state.copyWith(isLoadingServers: false));
        }
      }
    }
  }

  @override
  Future<void> close() {
    // 清理所有缓存
    _mapRuntimeCache.clear();
    _mapRuntimeLastFetchedCache.clear();
    _serverMapCache.clear();
    _failureCountCache.clear();
    _refreshHistory.clear();
    _categoryRefreshTimer?.cancel();
    _categoryRefreshTimer = null;
    _networkModeSubscription?.cancel();
    _networkModeSubscription = null;
    _stopRealtime();
    return super.close();
  }

  /// 处理 WS 推送的比分更新事件
  ///
  /// snapshot：服务端订阅时下发的全量列表，逐条覆盖本地服务器的 teamScores
  /// updated：单条增量更新
  void _onApplyScoreUpdates(
    ServerApplyScoreUpdates event,
    Emitter<ServerState> emit,
  ) {
    if (state.servers.isEmpty || event.scores.isEmpty) return;

    final byAddress = <String, ServerScore>{};
    for (final score in event.scores) {
      if (score.serverAddress.isEmpty) continue;
      byAddress[score.serverAddress] = score;
    }
    if (byAddress.isEmpty) return;

    bool changed = false;
    final updatedServers = state.servers.map((server) {
      final address =
          server.serverItem.address ?? server.serverItem.serverAddress;
      if (address == null) return server;
      final updated = _applyScoreToServer(server, byAddress[address]);
      if (!identical(updated, server)) changed = true;
      return updated;
    }).toList();

    if (!changed) return;
    emit(state.copyWith(servers: updatedServers));
    _lastScoreFetchTime = DateTime.now();
  }

  void _onApplyUsersCountUpdates(
    ServerApplyUsersCountUpdates event,
    Emitter<ServerState> emit,
  ) {
    if (state.servers.isEmpty) return;

    final updates = <String, ServerUsersCount>{};
    for (final c in event.counts) {
      updates[c.serverAddress] = c;
    }

    bool changed = false;
    final updatedServers = state.servers.map((server) {
      final address =
          server.serverItem.address ?? server.serverItem.serverAddress;
      if (address == null) return server;

      ServerUsersCount count;
      if (event.isSnapshot) {
        count =
            updates[address] ??
            ServerUsersCount(
              serverAddress: address,
              queueCount: 0,
              warmupCount: 0,
            );
      } else {
        if (!updates.containsKey(address)) return server;
        count = updates[address]!;
      }

      if (server.queueCount == count.queueCount &&
          server.warmupCount == count.warmupCount) {
        return server;
      }
      changed = true;
      return server.copyWith(
        queueCount: count.queueCount,
        warmupCount: count.warmupCount,
      );
    }).toList();

    if (changed) {
      emit(state.copyWith(servers: updatedServers));
    }
  }

  /// 处理 WS 推送的换图事件：清缓存 + 刷新地图信息和运行时间
  Future<void> _onApplyMapRuntimeChange(
    ServerApplyMapRuntimeChange event,
    Emitter<ServerState> emit,
  ) async {
    if (state.servers.isEmpty) return;
    final index = state.servers.indexWhere(
      (s) =>
          (s.serverItem.address ?? s.serverItem.serverAddress) ==
          event.serverAddress,
    );
    if (index == -1) return;
    if (event.newMapName.isEmpty || event.newMapName == 'graphics_settings') {
      return;
    }

    // 清掉旧的 mapRuntime / mapInfo 缓存，让 UI 立即知道地图变了
    _mapRuntimeCache.remove(event.serverAddress);
    _mapRuntimeLastFetchedCache.remove(event.serverAddress);
    _serverMapCache[event.serverAddress] = event.newMapName;

    final servers = List<ExtendedServerItem>.from(state.servers);
    final current = servers[index];
    servers[index] = current.copyWith(
      clearMapRuntime: true,
      clearMapInfo: true,
      mapRuntimeError: false,
      clearTeamScores: true,
    );
    emit(state.copyWith(servers: servers));

    // 异步重新拉地图信息和运行时间
    final serverApi = ServerApi();
    final requestId = _currentRequestId;
    _fetchMapInfoAsync(
      event.serverAddress,
      event.newMapName,
      requestId,
      serverApi,
    );
    _fetchMapRuntimeAsync(
      event.serverAddress,
      event.newMapName,
      requestId,
      serverApi,
    );
  }

  /// 内部事件：定时静默检测分类列表是否有变化
  ///
  /// 检测到变化时不直接替换，而是暂存到 pendingCategories，
  /// 由 UI 层显示提示，用户确认后再应用。
  Future<void> _onRefreshCategories(
    ServerRefreshCategoriesInternal event,
    Emitter<ServerState> emit,
  ) async {
    try {
      final apiCategories = await ServerCategoryService.instance.fetchFresh();
      if (apiCategories.isEmpty || emit.isDone) return;

      // 分类尚未加载完成时不触发更新提示（避免首次加载前误报）
      if (state.serverCategories.isEmpty) return;

      // 比较分类结构是否有变化（按 modelName 比较）
      final oldApiNames = state.serverCategories
          .where((c) => !c.isCustom)
          .map((c) => c.modelName)
          .toSet();
      final newApiNames = apiCategories.map((c) => c.modelName).toSet();
      final categoriesChanged =
          oldApiNames.length != newApiNames.length ||
          !oldApiNames.containsAll(newApiNames);

      // 比较各分类的服务器列表是否有变化（新增/删除服务器 IP）
      bool serverListChanged = false;
      if (!categoriesChanged) {
        for (final newCat in apiCategories) {
          final oldCat = state.serverCategories.firstWhere(
            (c) => c.modelName == newCat.modelName,
            orElse: () => newCat,
          );
          final oldAddresses = oldCat.serverList
              .map((s) => s.address ?? s.serverAddress)
              .toSet();
          final newAddresses = newCat.serverList
              .map((s) => s.address ?? s.serverAddress)
              .toSet();
          if (oldAddresses.length != newAddresses.length ||
              !oldAddresses.containsAll(newAddresses)) {
            serverListChanged = true;
            break;
          }
        }
      }

      if (!categoriesChanged && !serverListChanged) return;
      if (emit.isDone) return;

      // 有变化：保留自定义分类，合并新的 API 分类，暂存到 pendingCategories
      final customCategories = state.serverCategories
          .where((c) => c.isCustom)
          .toList();
      final pending = [...customCategories, ...apiCategories];

      emit(state.copyWith(pendingCategories: pending));
      LogService.i('检测到分类列表有更新，等待用户确认');
    } catch (e) {
      LogService.w('定时检测分类列表失败（静默忽略）: $e');
    }
  }

  /// 用户忽略待更新的分类列表
  void _onDismissPendingCategories(
    ServerDismissPendingCategories event,
    Emitter<ServerState> emit,
  ) {
    emit(state.copyWith(clearPendingCategories: true));
  }
}
