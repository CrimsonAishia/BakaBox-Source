import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/map_contribution_api.dart';
import '../../api/server_api.dart';
import '../../models/map_contribution_models.dart';
import '../../models/map_subscription_models.dart';
import '../../services/custom_server_service.dart';
import '../../services/map_subscription_service.dart';
import '../../services/tts_service.dart';
import '../../utils/log_service.dart';

part 'map_subscription_event.dart';
part 'map_subscription_state.dart';

/// 地图订阅 BLoC
class MapSubscriptionBloc
    extends Bloc<MapSubscriptionEvent, MapSubscriptionState> {
  final MapSubscriptionService _service = MapSubscriptionService();
  final TtsService _ttsService = TtsService();
  final MapContributionApi _mapApi = MapContributionApi();
  final ServerApi _serverApi = ServerApi();

  StreamSubscription<void>? _serviceSubscription;
  StreamSubscription<TtsDownloadProgress>? _ttsProgressSubscription;

  MapSubscriptionBloc() : super(const MapSubscriptionState()) {
    on<MapSubscriptionLoad>(_onLoad);
    on<MapSubscriptionLoadCategories>(_onLoadCategories);
    on<MapSubscriptionAdd>(_onAdd);
    on<MapSubscriptionRemove>(_onRemove);
    on<MapSubscriptionUpdateScope>(_onUpdateScope);
    on<MapSubscriptionUpdateSubscriptionScope>(_onUpdateSubscriptionScope);
    on<MapSubscriptionUpdateSubscriptionServers>(_onUpdateSubscriptionServers);
    on<MapSubscriptionLoadServers>(_onLoadServers);
    on<MapSubscriptionToggleGlobal>(_onToggleGlobal);
    on<MapSubscriptionToggleNotification>(_onToggleNotification);
    on<MapSubscriptionToggleGlobalTts>(_onToggleGlobalTts);
    on<MapSubscriptionSearchMaps>(_onSearchMaps);
    on<MapSubscriptionDownloadTtsModel>(_onDownloadTtsModel);
    on<MapSubscriptionCancelTtsDownload>(_onCancelTtsDownload);
    on<MapSubscriptionDeleteTtsModel>(_onDeleteTtsModel);
    on<MapSubscriptionTtsProgressUpdate>(_onTtsProgressUpdate);
    on<MapSubscriptionSetTtsVolume>(_onSetTtsVolume);
    on<MapSubscriptionSetTtsSpeed>(_onSetTtsSpeed);
    on<MapSubscriptionSetTtsSpeakerId>(_onSetTtsSpeakerId);
    on<MapSubscriptionSelectTtsModel>(_onSelectTtsModel);
    on<MapSubscriptionImportTtsModel>(_onImportTtsModel);
    on<MapSubscriptionTestTts>(_onTestTts);
    on<MapSubscriptionSetCooldown>(_onSetCooldown);
    on<_MapSubscriptionTtsPhaseUpdate>(_onTtsPhaseUpdate);

    // 监听服务状态变化
    _serviceSubscription = _service.stateStream.listen((_) {
      add(const MapSubscriptionLoad());
    });
  }

  Future<void> _onLoad(
    MapSubscriptionLoad event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    try {
      await _service.initialize();
      await _ttsService.loadSettings();

      emit(
        state.copyWith(
          subscriptions: _service.subscriptions,
          isEnabled: _service.isEnabled,
          isNotificationEnabled: _service.isNotificationEnabled,
          isTtsEnabled: _service.isTtsEnabled,
          globalCategories: _service.globalCategories,
          isTtsModelDownloaded: _ttsService.isModelDownloaded,
          ttsVolume: _ttsService.volume,
          ttsSpeed: _ttsService.speed,
          ttsSpeakerId: _ttsService.speakerId,
          selectedTtsModelId: _ttsService.selectedModelId,
          cooldownSeconds: _service.cooldownSeconds,
          isLoading: false,
        ),
      );
    } catch (e) {
      LogService.e('[MapSubscriptionBloc] 加载失败', e);
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onLoadCategories(
    MapSubscriptionLoadCategories event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    emit(state.copyWith(isLoadingCategories: true));
    try {
      // 获取 API 分类
      final apiCategories = await _serverApi.getServerList();
      // 获取自定义分类
      final customCategories = await CustomServerService.loadCustomCategories();
      
      // 合并所有分类名称
      final allCategories = [...customCategories, ...apiCategories];
      final categoryNames = allCategories
          .where((c) => c.modelName != null && c.modelName!.isNotEmpty)
          .map((c) => c.modelName!)
          .toSet()
          .toList();
      emit(state.copyWith(
        availableCategories: categoryNames,
        isLoadingCategories: false,
      ));
    } catch (e) {
      LogService.e('[MapSubscriptionBloc] 加载分类失败', e);
      emit(state.copyWith(isLoadingCategories: false));
    }
  }

  Future<void> _onAdd(
    MapSubscriptionAdd event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    try {
      final subscription = MapSubscription(
        mapName: event.mapName,
        mapLabel: event.mapLabel,
        mapBackground: event.mapBackground,
        categoryNames: event.categoryNames,
        createdAt: DateTime.now(),
      );
      await _service.addSubscription(subscription);
      emit(state.copyWith(subscriptions: _service.subscriptions));
    } catch (e) {
      LogService.e('[MapSubscriptionBloc] 添加订阅失败', e);
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onRemove(
    MapSubscriptionRemove event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    try {
      await _service.removeSubscription(event.mapName);
      emit(state.copyWith(subscriptions: _service.subscriptions));
    } catch (e) {
      LogService.e('[MapSubscriptionBloc] 移除订阅失败', e);
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onUpdateScope(
    MapSubscriptionUpdateScope event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    try {
      await _service.setGlobalCategories(event.categoryNames);
      emit(state.copyWith(globalCategories: _service.globalCategories));
    } catch (e) {
      LogService.e('[MapSubscriptionBloc] 更新全局分类范围失败', e);
    }
  }

  Future<void> _onUpdateSubscriptionScope(
    MapSubscriptionUpdateSubscriptionScope event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    try {
      await _service.updateSubscriptionScope(event.mapName, event.categoryNames);
      emit(state.copyWith(subscriptions: _service.subscriptions));
    } catch (e) {
      LogService.e('[MapSubscriptionBloc] 更新订阅分类范围失败', e);
    }
  }

  Future<void> _onUpdateSubscriptionServers(
    MapSubscriptionUpdateSubscriptionServers event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    try {
      await _service.updateSubscriptionServers(event.mapName, event.serverAddresses);
      emit(state.copyWith(subscriptions: _service.subscriptions));
    } catch (e) {
      LogService.e('[MapSubscriptionBloc] 更新订阅服务器范围失败', e);
    }
  }

  Future<void> _onLoadServers(
    MapSubscriptionLoadServers event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    emit(state.copyWith(isLoadingServers: true));
    try {
      final servers = await _service.getAvailableServers();
      emit(state.copyWith(
        availableServers: servers,
        isLoadingServers: false,
      ));
    } catch (e) {
      LogService.e('[MapSubscriptionBloc] 加载服务器列表失败', e);
      emit(state.copyWith(isLoadingServers: false));
    }
  }

  Future<void> _onToggleGlobal(
    MapSubscriptionToggleGlobal event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    try {
      await _service.setEnabled(event.enabled);
      emit(state.copyWith(isEnabled: event.enabled));
    } catch (e) {
      LogService.e('[MapSubscriptionBloc] 切换全局开关失败', e);
    }
  }

  Future<void> _onToggleNotification(
    MapSubscriptionToggleNotification event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    try {
      await _service.setNotificationEnabled(event.enabled);
      emit(state.copyWith(isNotificationEnabled: event.enabled));
    } catch (e) {
      LogService.e('[MapSubscriptionBloc] 切换通知开关失败', e);
    }
  }

  Future<void> _onToggleGlobalTts(
    MapSubscriptionToggleGlobalTts event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    try {
      await _service.setTtsEnabled(event.enabled);
      emit(state.copyWith(isTtsEnabled: event.enabled));
    } catch (e) {
      LogService.e('[MapSubscriptionBloc] 切换全局 TTS 开关失败', e);
    }
  }

  Future<void> _onSearchMaps(
    MapSubscriptionSearchMaps event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      emit(state.copyWith(
        searchResults: [],
        isSearching: false,
        searchTotalCount: 0,
        searchPageIndex: 1,
        hasMoreSearchResults: false,
      ));
      return;
    }

    // 如果是加载更多，检查是否还有更多数据
    if (event.loadMore && !state.hasMoreSearchResults) {
      LogService.d(
        '[MapSubscriptionBloc] 加载更多被跳过：已无更多结果 (当前: ${state.searchResults.length}, 总计: ${state.searchTotalCount})',
      );
      // 更新状态，移除加载中提示
      emit(state.copyWith(isSearching: false));
      return;
    }

    // 防重入：如果正在搜索中，跳过新请求
    if (state.isSearching) {
      return;
    }

    final pageIndex = event.loadMore ? state.searchPageIndex + 1 : 1;
    const pageSize = 30;

    emit(state.copyWith(isSearching: true));

    try {
      final response = await _mapApi.getAllMaps(
        MapListRequest(
          pagination: PaginationParams(pageIndex: pageIndex, pageSize: pageSize),
          mapName: query,
        ),
      );

      final allMaps = response?.items ?? [];
      final total = response?.total ?? 0;

      // 转换为搜索结果
      final newResults = allMaps
          .map(
            (map) => MapSearchResult(
              mapName: map.mapName,
              mapLabel: map.mapLabel,
              mapBackground: map.mapBackground,
              isSubscribed: _service.isSubscribed(map.mapName),
            ),
          )
          .toList();

      // 合并结果（加载更多时追加，否则替换）
      final results = event.loadMore
          ? [...state.searchResults, ...newResults]
          : newResults;

      // 计算是否还有更多
      final hasMore = results.length < total;

      emit(state.copyWith(
        searchResults: results,
        isSearching: false,
        searchTotalCount: total,
        searchPageIndex: pageIndex,
        hasMoreSearchResults: hasMore,
      ));
    } catch (e) {
      LogService.e('[MapSubscriptionBloc] 搜索地图失败', e);
      emit(
        state.copyWith(
          isSearching: false,
          error: '搜索失败: $e',
        ),
      );
    }
  }

  Future<void> _onDownloadTtsModel(
    MapSubscriptionDownloadTtsModel event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    // 监听下载进度
    _ttsProgressSubscription?.cancel();
    _ttsProgressSubscription = _ttsService.downloadProgressStream.listen((
      progress,
    ) {
      add(MapSubscriptionTtsProgressUpdate(progress: progress));
    });

    // 开始下载（支持指定模型和加速下载）
    final success = await _ttsService.downloadModel(
      modelId: event.modelId,
      useAcceleration: event.useAcceleration,
    );
    _ttsProgressSubscription?.cancel();

    emit(
      state.copyWith(
        isTtsModelDownloaded: _ttsService.isModelDownloaded,
        ttsDownloadStatus: success
            ? TtsDownloadStatus.completed
            : TtsDownloadStatus.idle,
      ),
    );
  }

  void _onCancelTtsDownload(
    MapSubscriptionCancelTtsDownload event,
    Emitter<MapSubscriptionState> emit,
  ) {
    _ttsService.cancelDownload();
    emit(
      state.copyWith(
        ttsDownloadStatus: TtsDownloadStatus.idle,
        ttsDownloadProgress: 0.0,
      ),
    );
  }

  Future<void> _onDeleteTtsModel(
    MapSubscriptionDeleteTtsModel event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    await _ttsService.deleteModel(modelId: event.modelId);
    
    // 如果删除后没有任何已下载的模型，自动关闭 TTS 开关
    final hasAnyModel = _ttsService.isModelDownloaded;
    if (!hasAnyModel && state.isTtsEnabled) {
      await _service.setTtsEnabled(false);
    }
    
    emit(
      state.copyWith(
        isTtsModelDownloaded: hasAnyModel,
        isTtsEnabled: hasAnyModel ? state.isTtsEnabled : false,
        ttsDownloadStatus: TtsDownloadStatus.idle,
        ttsDownloadProgress: 0.0,
      ),
    );
  }

  void _onTtsProgressUpdate(
    MapSubscriptionTtsProgressUpdate event,
    Emitter<MapSubscriptionState> emit,
  ) {
    emit(
      state.copyWith(
        ttsDownloadStatus: event.progress.status,
        ttsDownloadProgress: event.progress.progress,
        error: event.progress.error,
      ),
    );
  }

  Future<void> _onSetTtsVolume(
    MapSubscriptionSetTtsVolume event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    await _ttsService.setVolume(event.volume);
    emit(state.copyWith(ttsVolume: event.volume));
  }

  Future<void> _onSetTtsSpeed(
    MapSubscriptionSetTtsSpeed event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    await _ttsService.setSpeed(event.speed);
    emit(state.copyWith(ttsSpeed: event.speed));
  }

  Future<void> _onSetTtsSpeakerId(
    MapSubscriptionSetTtsSpeakerId event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    await _ttsService.setSpeakerId(event.speakerId);
    emit(state.copyWith(ttsSpeakerId: event.speakerId));
  }

  Future<void> _onSelectTtsModel(
    MapSubscriptionSelectTtsModel event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    await _ttsService.selectModel(event.modelId);
    emit(
      state.copyWith(
        selectedTtsModelId: event.modelId,
        isTtsModelDownloaded: _ttsService.isModelDownloaded,
      ),
    );
  }

  Future<void> _onImportTtsModel(
    MapSubscriptionImportTtsModel event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    final success = await _ttsService.importLocalModel(
      sourcePath: event.sourcePath,
      modelId: event.modelId,
    );
    if (success) {
      emit(state.copyWith(isTtsModelDownloaded: _ttsService.isModelDownloaded));
    }
  }

  Future<void> _onTestTts(
    MapSubscriptionTestTts event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    emit(state.copyWith(isTtsTesting: true, ttsTestingPhase: 'generating', error: null));
    try {
      await Future.microtask(() {});
      await _ttsService.testSpeakWithCallback(
        onPlayingStart: () {
          add(const _MapSubscriptionTtsPhaseUpdate(phase: 'playing'));
        },
      );
    } catch (e) {
      LogService.e('[MapSubscriptionBloc] TTS 测试失败', e);
      emit(state.copyWith(error: 'TTS 测试失败: $e'));
    } finally {
      emit(state.copyWith(isTtsTesting: false, ttsTestingPhase: null));
    }
  }

  Future<void> _onSetCooldown(
    MapSubscriptionSetCooldown event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    await _service.setCooldownSeconds(event.seconds);
    emit(state.copyWith(cooldownSeconds: _service.cooldownSeconds));
  }

  void _onTtsPhaseUpdate(
    _MapSubscriptionTtsPhaseUpdate event,
    Emitter<MapSubscriptionState> emit,
  ) {
    emit(state.copyWith(ttsTestingPhase: event.phase));
  }

  @override
  Future<void> close() {
    _serviceSubscription?.cancel();
    _ttsProgressSubscription?.cancel();
    return super.close();
  }
}
