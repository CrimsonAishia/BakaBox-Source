import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/map_contribution_api.dart';
import '../../api/server_api.dart';
import '../../models/map_contribution_models.dart';
import '../../models/map_subscription_models.dart';
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
    on<MapSubscriptionToggleTts>(_onToggleTts);
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
    on<MapSubscriptionSelectTtsModel>(_onSelectTtsModel);
    on<MapSubscriptionImportTtsModel>(_onImportTtsModel);
    on<MapSubscriptionTestTts>(_onTestTts);
    on<MapSubscriptionSetCooldown>(_onSetCooldown);

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
          isTtsModelDownloaded: _ttsService.isModelDownloaded,
          ttsVolume: _ttsService.volume,
          ttsSpeed: _ttsService.speed,
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
    // 如果已有分类数据，不重复加载
    if (state.availableCategories.isNotEmpty) return;
    
    emit(state.copyWith(isLoadingCategories: true));
    try {
      final categories = await _serverApi.getServerList();
      // 使用 modelName 作为分类名称（category 字段可能为空）
      final categoryNames = categories
          .where((c) => c.modelName != null && c.modelName!.isNotEmpty && !c.isCustom)
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
      await _service.updateCategoryScope(event.mapName, event.categoryNames);
      emit(state.copyWith(subscriptions: _service.subscriptions));
    } catch (e) {
      LogService.e('[MapSubscriptionBloc] 更新分类范围失败', e);
    }
  }

  Future<void> _onToggleTts(
    MapSubscriptionToggleTts event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    try {
      await _service.toggleTts(event.mapName, event.enabled);
      emit(state.copyWith(subscriptions: _service.subscriptions));
    } catch (e) {
      LogService.e('[MapSubscriptionBloc] 切换 TTS 失败', e);
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
      emit(state.copyWith(searchResults: [], isSearching: false));
      return;
    }

    emit(state.copyWith(isSearching: true));

    try {
      // 从地图贡献 API 获取地图数据（使用搜索关键词）
      final response = await _mapApi.getAllMaps(
        MapListRequest(
          pagination: const PaginationParams(pageIndex: 1, pageSize: 50),
          mapName: query,
        ),
      );

      final allMaps = response?.items ?? [];

      // 搜索匹配
      final queryLower = query.toLowerCase();
      final results = allMaps
          .where(
            (map) =>
                map.mapName.toLowerCase().contains(queryLower) ||
                map.mapLabel.toLowerCase().contains(queryLower),
          )
          .take(20)
          .map(
            (map) => MapSearchResult(
              mapName: map.mapName,
              mapLabel: map.mapLabel,
              mapBackground: map.mapBackground,
              isSubscribed: _service.isSubscribed(map.mapName),
            ),
          )
          .toList();

      emit(state.copyWith(searchResults: results, isSearching: false));
    } catch (e) {
      LogService.e('[MapSubscriptionBloc] 搜索地图失败', e);
      emit(
        state.copyWith(
          searchResults: [],
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
    emit(
      state.copyWith(
        isTtsModelDownloaded: _ttsService.isModelDownloaded,
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
    await _ttsService.testSpeak();
  }

  Future<void> _onSetCooldown(
    MapSubscriptionSetCooldown event,
    Emitter<MapSubscriptionState> emit,
  ) async {
    await _service.setCooldownSeconds(event.seconds);
    emit(state.copyWith(cooldownSeconds: _service.cooldownSeconds));
  }

  @override
  Future<void> close() {
    _serviceSubscription?.cancel();
    _ttsProgressSubscription?.cancel();
    return super.close();
  }
}
