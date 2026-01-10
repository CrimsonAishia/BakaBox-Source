import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/server_models.dart';
import '../../api/server_api.dart';
import '../../services/source_server_service.dart';
import '../../services/game_launcher_service.dart';
import '../../services/map_change_monitor_service.dart';
import '../../services/custom_server_service.dart';
import '../../utils/log_service.dart';
import '../../utils/error_utils.dart';
import 'server_event.dart';
import 'server_state.dart';

class ServerBloc extends Bloc<ServerEvent, ServerState> {
  // 全局 mapRuntime 缓存，key 为服务器地址
  final Map<String, MapRuntimeData> _mapRuntimeCache = {};
  final Map<String, int> _mapRuntimeLastFetchedCache = {};
  final Map<String, String> _serverMapCache = {}; // 记录服务器当前地图，用于检测换图
  int _currentRequestId = 0;
  
  // 刷新频率限制：记录每个服务器的刷新时间戳
  final Map<String, List<DateTime>> _refreshHistory = {};
  static const int _maxRefreshPerMinute = 5; // 1分钟内最多刷新5次
  static const Duration _refreshWindow = Duration(minutes: 1);

  ServerBloc() : super(const ServerState()) {
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
    on<ServerDeleteCategory>(_onDeleteCategory);
    on<ServerDeleteServer>(_onDeleteServer);
    on<ServerResetCountdown>(_onResetCountdown);
    on<ServerRefreshMapCache>(_onRefreshMapCache);
  }

  /// 重置倒计时（递增 countdownResetKey 触发 UI 重置）
  void _resetCountdown(Emitter<ServerState> emit) {
    emit(state.copyWith(countdownResetKey: state.countdownResetKey + 1));
  }

  Future<void> _onFetchList(ServerFetchList event, Emitter<ServerState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      LogService.d('开始加载服务器列表');
      final serverApi = ServerApi();
      final apiCategories = await serverApi.getServerList();
      
      // 加载自定义分类
      final customCategories = await CustomServerService.loadCustomCategories();
      
      // 合并分类：自定义分类置顶
      final allCategories = [...customCategories, ...apiCategories];
      
      if (allCategories.isNotEmpty) {
        emit(state.copyWith(serverCategories: allCategories, isLoading: false));
        LogService.i('成功加载 ${customCategories.length} 个自定义分类和 ${apiCategories.length} 个 API 分类');
        
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

  Future<void> _onSelectCategory(ServerSelectCategory event, Emitter<ServerState> emit) async {
    // 如果是相同分类且服务器数量一致，跳过刷新（除非强制刷新）
    // 添加/删除服务器后，serverList 数量会变化，此时需要刷新
    final isSameCategory = state.selectedCategory?.modelName == event.category.modelName;
    final serverCountMatch = state.servers.length == event.category.serverList.length;
    
    // 只有在相同分类且服务器数量一致且非强制刷新时才跳过
    if (isSameCategory && serverCountMatch && state.servers.isNotEmpty && !event.forceRefresh) {
      return;
    }
    
    final requestId = ++_currentRequestId;
    
    final servers = event.category.serverList.map((serverItem) {
      final address = serverItem.address ?? serverItem.serverAddress;
      // 从全局缓存恢复 mapRuntime 数据
      final cachedRuntime = address != null ? _mapRuntimeCache[address] : null;
      final cachedLastFetched = address != null ? _mapRuntimeLastFetchedCache[address] : null;
      
      return ExtendedServerItem(
        serverItem: serverItem,
        isLoading: true,
        mapRuntime: cachedRuntime,
        mapRuntimeLastFetched: cachedLastFetched,
        mapRuntimeError: false,
      );
    }).toList();
    
    // 如果是空分类（自定义分类没有服务器），不显示加载状态
    final isEmptyCategory = servers.isEmpty;
    
    emit(state.copyWith(
      selectedCategory: event.category,
      servers: servers,
      isLoadingServers: !isEmptyCategory, // 空分类不显示加载状态
    ));
    
    _resetCountdown(emit);
    
    // 只有非空分类才获取服务器信息
    if (!isEmptyCategory) {
      await _fetchServersInfo(requestId, emit);
    }
  }

  Future<void> _onRefreshServers(ServerRefreshServers event, Emitter<ServerState> emit) async {
    // 如果没有选中分类或没有服务器，直接返回
    if (state.selectedCategory == null || state.servers.isEmpty) {
      return;
    }
    
    final categoryName = state.selectedCategory!.modelName ?? '';
    // 如果正在加载，直接返回（避免重复请求）
    if (state.isCategoryLoading(categoryName)) {
      return;
    }
    
    final requestId = ++_currentRequestId;
    
    final loadingCategories = Set<String>.from(state.loadingCategories)..add(categoryName);
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
      if (!emit.isDone && requestId == _currentRequestId) {
        final updatedLoadingCategories = Set<String>.from(state.loadingCategories)..remove(categoryName);
        emit(state.copyWith(loadingCategories: updatedLoadingCategories));
      }
    }
  }

  Future<void> _fetchServersInfo(int requestId, Emitter<ServerState> emit) async {
    if (state.servers.isEmpty) return;
    
    final serverApi = ServerApi();
    
    // 并行获取所有服务器信息，每个服务器独立完成后立即更新 UI
    final futures = <Future<void>>[];
    
    for (int i = 0; i < state.servers.length; i++) {
      final server = state.servers[i];
      final address = server.serverItem.address ?? server.serverItem.serverAddress;
      if (address == null) continue;
      
      // 每个服务器独立异步加载
      futures.add(_fetchSingleServerInfo(
        address: address,
        requestId: requestId,
        serverApi: serverApi,
        emit: emit,
      ));
    }
    
    // 等待所有服务器加载完成
    await Future.wait(futures);
    
    if (!emit.isDone && requestId == _currentRequestId) {
      _updateCurrentCategoryOnlineCount(emit);
      emit(state.copyWith(isLoadingServers: false));
    }
    
    _clearRecentlyUpdatedAfterDelay(requestId);
  }
  
  /// 获取单个服务器信息（异步独立执行）
  Future<void> _fetchSingleServerInfo({
    required String address,
    required int requestId,
    required ServerApi serverApi,
    required Emitter<ServerState> emit,
  }) async {
    if (requestId != _currentRequestId || emit.isDone) return;
    
    try {
      final info = await _getServerInfo(address);
      if (requestId != _currentRequestId || emit.isDone) return;
      
      // 通过地址查找当前服务器索引（并行更新时索引可能变化）
      final currentIndex = state.servers.indexWhere(
        (s) => (s.serverItem.address ?? s.serverItem.serverAddress) == address
      );
      if (currentIndex == -1) return;
      
      final currentServer = state.servers[currentIndex];
      
      if (info != null) {
        final newMap = info.map;
        final cachedMap = _serverMapCache[address];
        // 检测换图：与缓存的地图名比较
        // 过滤 graphics_settings 地图（服务器重启时的加载地图）
        final mapChanged = cachedMap != null && 
                           cachedMap != newMap && 
                           newMap != 'graphics_settings';
        final hasDataChanged = currentServer.serverData == null ||
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
          
          // 通知换图监控服务（如果该服务器在监控列表中）
          // 自定义服务器需要带上分类名
          final isCustomServer = currentServer.serverItem.isCustom;
          final categoryName = isCustomServer && state.selectedCategory != null
              ? state.selectedCategory!.modelName
              : null;
          
          // 不等待完成，避免阻塞刷新流程
          _notifyMapChange(
            address: address,
            serverName: info.name,
            oldMap: cachedMap,
            newMap: newMap,
            serverApi: serverApi,
            categoryName: categoryName,
          );
        }
        
        final updatedServer = currentServer.copyWith(
          serverData: _convertSourceServerInfo(info),
          updatedAt: DateTime.now(),
          recentlyUpdated: hasDataChanged && currentServer.serverData != null,
          isLoading: false,
          hasError: false,
          mapInfo: mapChanged ? null : currentServer.mapInfo,
          mapRuntime: mapChanged ? null : currentServer.mapRuntime,
          mapRuntimeLastFetched: mapChanged ? null : currentServer.mapRuntimeLastFetched,
          mapRuntimeError: mapChanged ? false : currentServer.mapRuntimeError,
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
          final needFetchMapInfo = mapChanged || 
              currentServer.mapInfo == null ||
              (currentMapInInfo != null && currentMapInInfo != newMap);
          if (needFetchMapInfo) {
            _fetchMapInfoAsync(address, info.map, requestId, serverApi);
          }
          // 自定义服务器不获取 mapRuntime（需要 API 交互）
          // 只有换图或没有缓存的 runtime 时才重新获取
          if (!isCustomServer && (mapChanged || (currentServer.mapRuntime == null && _mapRuntimeCache[address] == null))) {
            _fetchMapRuntimeAsync(address, info.map, requestId, serverApi);
          }
        }
      } else {
        // 服务器无法访问（维护中），清除旧数据
        _updateServerByAddress(address, currentServer.copyWith(
          isLoading: false, 
          hasError: true,
          clearServerData: true,  // 清除服务器数据
          clearMapRuntime: true,  // 清除地图运行时间
          clearMapInfo: true,     // 清除地图信息（背景图）
        ), emit);
        // 清除 runtime 缓存，但保留 _serverMapCache 以便恢复后检测换图
        _mapRuntimeCache.remove(address);
        _mapRuntimeLastFetchedCache.remove(address);
      }
    } catch (e) {
      LogService.e('加载服务器数据失败 ($address): $e', e);
      final currentIndex = state.servers.indexWhere(
        (s) => (s.serverItem.address ?? s.serverItem.serverAddress) == address
      );
      if (currentIndex != -1 && !emit.isDone) {
        // 服务器异常，清除旧数据
        _updateServerByAddress(address, state.servers[currentIndex].copyWith(
          isLoading: false, 
          hasError: true,
          clearServerData: true,
          clearMapRuntime: true,
          clearMapInfo: true,     // 清除地图信息（背景图）
        ), emit);
        // 清除 runtime 缓存，但保留 _serverMapCache 以便恢复后检测换图
        _mapRuntimeCache.remove(address);
        _mapRuntimeLastFetchedCache.remove(address);
      }
    }
  }
  
  /// 通过地址更新服务器（并行安全）
  void _updateServerByAddress(String address, ExtendedServerItem server, Emitter<ServerState> emit) {
    if (emit.isDone) return;
    final index = state.servers.indexWhere(
      (s) => (s.serverItem.address ?? s.serverItem.serverAddress) == address
    );
    if (index == -1) return;
    final servers = List<ExtendedServerItem>.from(state.servers);
    servers[index] = server;
    emit(state.copyWith(servers: servers));
  }
  
  void _clearRecentlyUpdatedAfterDelay(int requestId) {
    Future.delayed(const Duration(seconds: 2), () {
      if (requestId == _currentRequestId && state.servers.any((s) => s.recentlyUpdated)) {
        add(ServerClearRecentlyUpdated(requestId));
      }
    });
  }

  void _onClearRecentlyUpdated(ServerClearRecentlyUpdated event, Emitter<ServerState> emit) {
    if (event.requestId != _currentRequestId) return;
    final updatedServers = state.servers.map((s) => s.recentlyUpdated ? s.copyWith(recentlyUpdated: false) : s).toList();
    emit(state.copyWith(servers: updatedServers));
  }

  void _onUpdateSingleServer(ServerUpdateSingleServer event, Emitter<ServerState> emit) {
    final index = state.servers.indexWhere((s) => (s.serverItem.address ?? s.serverItem.serverAddress) == event.address);
    if (index == -1) return;
    
    final servers = List<ExtendedServerItem>.from(state.servers);
    final current = servers[index];
    
    // 更新全局缓存
    if (event.mapRuntime != null) {
      _mapRuntimeCache[event.address] = event.mapRuntime!;
      _mapRuntimeLastFetchedCache[event.address] = DateTime.now().millisecondsSinceEpoch;
    }
    
    servers[index] = current.copyWith(
      pingInfo: event.pingInfo ?? current.pingInfo,
      mapInfo: event.mapInfo ?? current.mapInfo,
      mapRuntime: event.mapRuntime ?? current.mapRuntime,
      mapRuntimeLastFetched: event.mapRuntime != null ? DateTime.now().millisecondsSinceEpoch : current.mapRuntimeLastFetched,
      mapRuntimeError: event.mapRuntimeError ?? current.mapRuntimeError,
    );
    emit(state.copyWith(servers: servers));
  }

  void _fetchMapInfoAsync(String address, String mapName, int requestId, ServerApi serverApi) {
    serverApi.getMapInfo(mapName).then((mapInfo) {
      if (requestId == _currentRequestId && mapInfo != null) {
        add(ServerUpdateSingleServer(address: address, mapInfo: mapInfo));
      }
    }).catchError((e) {
      LogService.e('加载地图信息失败 ($mapName): $e', e);
    });
  }

  void _fetchMapRuntimeAsync(String address, String mapName, int requestId, ServerApi serverApi) {
    serverApi.getMapRuntime(address, mapName).then((mapRuntime) {
      if (requestId == _currentRequestId) {
        add(ServerUpdateSingleServer(address: address, mapRuntime: mapRuntime, mapRuntimeError: mapRuntime == null));
      }
    }).catchError((e) {
      LogService.e('加载地图运行时间失败 ($address, $mapName): $e', e);
      add(ServerUpdateSingleServer(address: address, mapRuntimeError: true));
    });
  }

  Future<void> _onClearCategory(ServerClearCategory event, Emitter<ServerState> emit) async {
    emit(state.copyWith(clearSelectedCategory: true, servers: [], isLoadingServers: false));
    _resetCountdown(emit);
  }

  Future<void> _onRefresh(ServerRefresh event, Emitter<ServerState> emit) async {
    await _onFetchList(ServerFetchList(), emit);
    if (state.selectedCategory != null) {
      final updatedCategory = state.serverCategories.firstWhere(
        (cat) => cat.modelName == state.selectedCategory!.modelName,
        orElse: () => state.selectedCategory!,
      );
      add(ServerSelectCategory(updatedCategory));
    }
  }

  void _onStartPeriodicRefresh(ServerStartPeriodicRefresh event, Emitter<ServerState> emit) {
    // 只设置状态，刷新时机由 UI 倒计时进度条的 onComplete 控制
    emit(state.copyWith(isCountdownActive: true));
  }

  void _onStopPeriodicRefresh(ServerStopPeriodicRefresh event, Emitter<ServerState> emit) {
    emit(state.copyWith(isCountdownActive: false));
  }

  void _onPauseRefresh(ServerPauseRefresh event, Emitter<ServerState> emit) {
    emit(state.copyWith(isPaused: true));
  }

  void _onResumeRefresh(ServerResumeRefresh event, Emitter<ServerState> emit) {
    // 恢复时只取消暂停状态，不重置倒计时，让进度条继续之前的进度
    emit(state.copyWith(isPaused: false));
  }

  void _onLifecycleChanged(ServerLifecycleChanged event, Emitter<ServerState> emit) {
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

  Future<void> _onConnect(ServerConnect event, Emitter<ServerState> emit) async {
    final address = event.server.serverItem.address ?? event.server.serverItem.serverAddress;
    if (address == null) return;

    final gameLauncher = GameLauncherService();
    try {
      final result = event.password?.isNotEmpty == true
          ? await gameLauncher.connectToPasswordServer(address, event.password!)
          : await gameLauncher.connectToServer(address);
      LogService.i(result.success ? '连接命令已发送: ${result.message}' : '连接失败: ${result.error}');
    } catch (e) {
      LogService.e('连接服务器异常: $e', e);
    }
  }

  Future<void> _onUpdateCategoryOnlineCounts(ServerUpdateCategoryOnlineCounts event, Emitter<ServerState> emit) async {
    if (state.serverCategories.isEmpty) return;
    
    final isFirstLoad = !state.hasEverLoadedOnlineCounts;
    if (isFirstLoad) emit(state.copyWith(isLoadingOnlineCounts: true));
    
    // 先重置所有分类人数为 0（避免累加到旧数据）
    final resetCounts = <String, int>{};
    for (final category in state.serverCategories) {
      final categoryName = category.modelName ?? '';
      resetCounts[categoryName] = 0;
    }
    emit(state.copyWith(categoryOnlineCounts: resetCounts));
    
    final futures = <Future<void>>[];
    
    for (final category in state.serverCategories) {
      final categoryName = category.modelName ?? '';
      
      if (categoryName == state.selectedCategory?.modelName && state.servers.any((s) => s.serverData != null)) {
        int totalOnline = state.servers.fold(0, (sum, s) => sum + (s.serverData?.players ?? 0));
        final updatedCounts = Map<String, int>.from(state.categoryOnlineCounts)..[categoryName] = totalOnline;
        emit(state.copyWith(categoryOnlineCounts: updatedCounts));
        continue;
      }
      
      futures.add(_fetchCategoryOnlineCountAsync(category, emit));
    }
    
    if (futures.isNotEmpty) await Future.wait(futures);
    
    if (!emit.isDone) {
      emit(state.copyWith(isLoadingOnlineCounts: false, hasEverLoadedOnlineCounts: true));
    }
  }

  Future<void> _fetchCategoryOnlineCountAsync(ServerCategory category, Emitter<ServerState> emit) async {
    final categoryName = category.modelName ?? '';
    
    // 并行查询所有服务器，每个服务器完成后立即累加更新
    final futures = <Future<void>>[];
    
    for (final serverItem in category.serverList) {
      final address = serverItem.address ?? serverItem.serverAddress;
      if (address != null) {
        futures.add(_fetchSingleServerOnlineCount(
          categoryName: categoryName,
          address: address,
          emit: emit,
        ));
      }
    }
    
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }
  
  /// 获取单个服务器人数并累加到分类总人数
  Future<void> _fetchSingleServerOnlineCount({
    required String categoryName,
    required String address,
    required Emitter<ServerState> emit,
  }) async {
    if (emit.isDone) return;
    
    try {
      final info = await _getServerInfo(address);
      if (info != null && !emit.isDone) {
        // 获取当前人数并累加
        final currentCount = state.categoryOnlineCounts[categoryName] ?? 0;
        final updatedCounts = Map<String, int>.from(state.categoryOnlineCounts)
          ..[categoryName] = currentCount + info.players;
        emit(state.copyWith(categoryOnlineCounts: updatedCounts));
      }
    } catch (_) {
      // 忽略单个服务器查询失败
    }
  }

  void _updateCurrentCategoryOnlineCount(Emitter<ServerState> emit) {
    if (state.selectedCategory == null) return;
    final categoryName = state.selectedCategory!.modelName ?? '';
    int totalOnline = state.servers.fold(0, (sum, s) => sum + (s.serverData?.players ?? 0));
    final updatedCounts = Map<String, int>.from(state.categoryOnlineCounts)..[categoryName] = totalOnline;
    emit(state.copyWith(categoryOnlineCounts: updatedCounts));
  }

  Future<SourceServerInfo?> _getServerInfo(String address) async {
    final parts = address.split(':');
    if (parts.length != 2) return null;
    try {
      final ip = parts[0];
      final port = int.parse(parts[1]);
      return await SourceServerService.getServerInfo(ip, port, timeout: 10000);
    } catch (e) {
      LogService.e('获取服务器信息失败 ($address): $e', e);
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
    );
  }

  Future<List<SourceServerPlayer>> getServerPlayers(String address) async {
    final parts = address.split(':');
    if (parts.length != 2) return [];
    try {
      return await SourceServerService.getServerPlayers(parts[0], int.parse(parts[1]), timeout: 3000);
    } catch (e) {
      LogService.e('获取玩家列表失败 ($address): $e', e);
      return [];
    }
  }

  /// 通知换图监控服务（如果该服务器在监控列表中）
  /// 
  /// ServerBloc 刷新频率比 MapChangeMonitor 高，所以由 ServerBloc 负责：
  /// 1. 检测换图并发送通知
  /// 2. 更新 MapChangeMonitorService 的地图缓存
  Future<void> _notifyMapChange({
    required String address,
    required String serverName,
    required String oldMap,
    required String newMap,
    required ServerApi serverApi,
    String? categoryName,
  }) async {
    final monitorService = MapChangeMonitorService();
    
    // 只有在监控列表中的服务器才处理
    if (!monitorService.isMonitoring(address)) return;
    
    // 过滤 graphics_settings（旧版本可能遗留在缓存中）
    if (oldMap == 'graphics_settings' || newMap == 'graphics_settings') {
      // 只更新地图记录，不发送通知
      if (newMap != 'graphics_settings') {
        monitorService.updateCurrentMap(address, newMap, null);
      }
      return;
    }
    
    // 检查是否应该发送通知（防止与 Monitor 重复）
    // 如果 Monitor 已经发送过相同的换图通知，则跳过
    if (!monitorService.shouldNotify(address, oldMap, newMap)) {
      // 只更新地图记录，不发送通知
      monitorService.updateCurrentMap(address, newMap, null);
      return;
    }
    
    // 优先使用传入的服务器名，如果为空则使用保存的名称
    final displayName = serverName.isNotEmpty 
        ? serverName 
        : (monitorService.getSavedServerName(address) ?? address);
    
    // 先记录通知状态，防止 Monitor 重复发送（在获取地图信息之前）
    monitorService.markNotificationSent(address, oldMap, newMap);
    
    // 更新监控服务中的地图记录
    monitorService.updateCurrentMap(address, newMap, null);
    
    // 获取新地图信息（中文名和背景图）
    String? newMapCn;
    String? mapBackground;
    try {
      final mapInfo = await serverApi.getMapInfo(newMap);
      newMapCn = mapInfo?.mapLabel;
      mapBackground = mapInfo?.mapUrl;
    } catch (e) {
      // 静默处理
    }
    
    // 发送换图通知
    monitorService.sendMapChangeNotification(
      serverAddress: address,
      serverName: displayName,
      oldMap: oldMap,
      newMap: newMap,
      newMapCn: newMapCn,
      mapBackground: mapBackground,
      categoryName: categoryName,
    );
  }

  // ========== 自定义分类和服务器管理 ==========
  
  Future<void> _onAddCategory(ServerAddCategory event, Emitter<ServerState> emit) async {
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
      
      final newCategory = await CustomServerService.addCustomCategory(event.categoryName);
      
      // 将新分类插入到列表开头（自定义分类置顶）
      final customCategories = state.serverCategories.where((c) => c.isCustom).toList();
      final apiCategories = state.serverCategories.where((c) => !c.isCustom).toList();
      final updatedCategories = [...customCategories, newCategory, ...apiCategories];
      
      emit(state.copyWith(
        serverCategories: updatedCategories,
        successMessage: '分类 "${event.categoryName}" 已添加',
      ));
      LogService.i('添加自定义分类成功: ${event.categoryName}');
    } catch (e) {
      LogService.e('添加自定义分类失败: $e', e);
      emit(state.copyWith(error: ErrorUtils.getErrorMessage(e, defaultMessage: '添加分类失败')));
    }
  }

  Future<void> _onAddServer(ServerAddServer event, Emitter<ServerState> emit) async {
    try {
      final updatedCategory = await CustomServerService.addServerToCategory(
        event.categoryName,
        event.serverAddress,
      );
      
      // 更新分类列表
      final categoryIndex = state.serverCategories.indexWhere(
        (c) => c.modelName == event.categoryName,
      );
      
      if (categoryIndex != -1) {
        final updatedCategories = List<ServerCategory>.from(state.serverCategories);
        updatedCategories[categoryIndex] = updatedCategory;
        
        // 如果当前选中的是该分类，同时更新 selectedCategory
        final isCurrentCategory = state.selectedCategory?.modelName == event.categoryName;
        
        emit(state.copyWith(
          serverCategories: updatedCategories,
          selectedCategory: isCurrentCategory ? updatedCategory : state.selectedCategory,
          successMessage: '服务器 "${event.serverAddress}" 已添加',
        ));
        
        // 如果当前选中的是该分类，刷新服务器列表（强制刷新）
        if (isCurrentCategory) {
          add(ServerSelectCategory(updatedCategory, forceRefresh: true));
        }
        
        LogService.i('添加服务器成功: ${event.serverAddress} -> ${event.categoryName}');
      }
    } catch (e) {
      LogService.e('添加服务器失败: $e', e);
      emit(state.copyWith(error: ErrorUtils.getErrorMessage(e, defaultMessage: '添加服务器失败')));
    }
  }

  Future<void> _onDeleteCategory(ServerDeleteCategory event, Emitter<ServerState> emit) async {
    try {
      // 先取消该分类下所有服务器的换图监控
      final monitorService = MapChangeMonitorService();
      final categoryToDelete = state.serverCategories.firstWhere(
        (c) => c.modelName == event.categoryName,
        orElse: () => ServerCategory(modelName: '', serverList: []),
      );
      
      for (final server in categoryToDelete.serverList) {
        final address = server.address ?? server.serverAddress;
        if (address != null && monitorService.isMonitoring(address)) {
          await monitorService.removeMonitor(address);
          LogService.i('删除分类时取消换图监控: $address');
        }
      }
      
      await CustomServerService.deleteCustomCategory(event.categoryName);
      
      final updatedCategories = state.serverCategories
          .where((c) => c.modelName != event.categoryName)
          .toList();
      
      // 清理该分类的在线人数记录
      final updatedOnlineCounts = Map<String, int>.from(state.categoryOnlineCounts)
        ..remove(event.categoryName);
      
      emit(state.copyWith(
        serverCategories: updatedCategories,
        categoryOnlineCounts: updatedOnlineCounts,
        successMessage: '分类 "${event.categoryName}" 已删除',
      ));
      
      // 如果删除的是当前选中的分类，清除选中状态
      if (state.selectedCategory?.modelName == event.categoryName) {
        add(ServerClearCategory());
      }
      
      LogService.i('删除自定义分类成功: ${event.categoryName}');
    } catch (e) {
      LogService.e('删除自定义分类失败: $e', e);
      emit(state.copyWith(error: ErrorUtils.getErrorMessage(e, defaultMessage: '删除分类失败')));
    }
  }

  Future<void> _onDeleteServer(ServerDeleteServer event, Emitter<ServerState> emit) async {
    try {
      // 先取消该服务器的换图监控（如果有）
      final monitorService = MapChangeMonitorService();
      if (monitorService.isMonitoring(event.serverAddress)) {
        await monitorService.removeMonitor(event.serverAddress);
        LogService.i('删除服务器时取消换图监控: ${event.serverAddress}');
      }
      
      final updatedCategory = await CustomServerService.deleteServerFromCategory(
        event.categoryName,
        event.serverAddress,
      );
      
      // 更新分类列表
      final categoryIndex = state.serverCategories.indexWhere(
        (c) => c.modelName == event.categoryName,
      );
      
      if (categoryIndex != -1) {
        final updatedCategories = List<ServerCategory>.from(state.serverCategories);
        updatedCategories[categoryIndex] = updatedCategory;
        
        // 重新计算该分类的在线人数（排除被删除的服务器）
        final updatedOnlineCounts = Map<String, int>.from(state.categoryOnlineCounts);
        if (state.selectedCategory?.modelName == event.categoryName) {
          // 从当前服务器列表中排除被删除的服务器，重新计算人数
          final remainingServers = state.servers.where(
            (s) => (s.serverItem.address ?? s.serverItem.serverAddress) != event.serverAddress
          );
          final newCount = remainingServers.fold(0, (sum, s) => sum + (s.serverData?.players ?? 0));
          updatedOnlineCounts[event.categoryName] = newCount;
        }
        
        emit(state.copyWith(
          serverCategories: updatedCategories,
          categoryOnlineCounts: updatedOnlineCounts,
          successMessage: '服务器 "${event.serverAddress}" 已删除',
        ));
        
        // 如果当前选中的是该分类，刷新服务器列表（强制刷新）
        if (state.selectedCategory?.modelName == event.categoryName) {
          add(ServerSelectCategory(updatedCategory, forceRefresh: true));
        }
        
        LogService.i('删除服务器成功: ${event.serverAddress} <- ${event.categoryName}');
      }
    } catch (e) {
      LogService.e('删除服务器失败: $e', e);
      emit(state.copyWith(error: ErrorUtils.getErrorMessage(e, defaultMessage: '删除服务器失败')));
    }
  }

  void _onResetCountdown(ServerResetCountdown event, Emitter<ServerState> emit) {
    // 重置倒计时：先关闭再开启，并递增 key 触发 UI 重建
    emit(state.copyWith(
      isCountdownActive: true,
      countdownResetKey: state.countdownResetKey + 1,
    ));
  }

  Future<void> _onRefreshMapCache(ServerRefreshMapCache event, Emitter<ServerState> emit) async {
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
    final refreshingMaps = Set<String>.from(state.refreshingMaps)..add(event.address);
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
        final updatedRefreshingMaps = Set<String>.from(state.refreshingMaps)..remove(event.address);
        emit(state.copyWith(refreshingMaps: updatedRefreshingMaps));
      }
    }
  }
}
