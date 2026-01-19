import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/feature_status_api.dart';
import '../../models/feature_status_models.dart';
import '../../services/scheduler_service.dart';
import '../../utils/log_service.dart';
import 'feature_status_event.dart';
import 'feature_status_state.dart';

class FeatureStatusBloc extends Bloc<FeatureStatusEvent, FeatureStatusState> {
  final FeatureStatusApi _api = FeatureStatusApi();

  static const String _taskId = 'feature_status_refresh';

  FeatureStatusBloc() : super(const FeatureStatusState()) {
    on<FeatureStatusLoad>(_onLoad);
    on<FeatureStatusRefresh>(_onRefresh);
    on<FeatureStatusRefreshSingle>(_onRefreshSingle);
    on<FeatureStatusStartPeriodicRefresh>(_onStartPeriodicRefresh);
    on<FeatureStatusStopPeriodicRefresh>(_onStopPeriodicRefresh);
  }

  Future<void> _onLoad(
    FeatureStatusLoad event,
    Emitter<FeatureStatusState> emit,
  ) async {
    // 如果已经在加载中，避免重复请求
    if (state.loadState == FeatureStatusLoadState.loading) {
      LogService.d('功能状态正在加载中，跳过重复请求');
      return;
    }

    emit(state.copyWith(loadState: FeatureStatusLoadState.loading));

    try {
      final allStatus = await _api.getAllFeatureStatus();

      emit(state.copyWith(
        loadState: FeatureStatusLoadState.loaded,
        status: allStatus,
        lastUpdated: DateTime.now(),
      ));

      LogService.d('功能状态加载完成: '
          'keyConfig=${allStatus.keyConfig.enabled}, '
          'issue=${allStatus.issue.enabled}, '
          'mapContribution=${allStatus.mapContribution.enabled}');
    } catch (e) {
      LogService.e('加载功能状态失败', e);
      emit(state.copyWith(
        loadState: FeatureStatusLoadState.error,
        errorMessage: '加载功能状态失败',
      ));
    }
  }

  Future<void> _onRefresh(
    FeatureStatusRefresh event,
    Emitter<FeatureStatusState> emit,
  ) async {
    // 静默刷新，不改变 loading 状态
    try {
      final allStatus = await _api.getAllFeatureStatus();

      emit(state.copyWith(
        loadState: FeatureStatusLoadState.loaded,
        status: allStatus,
        lastUpdated: DateTime.now(),
      ));

      LogService.d('功能状态刷新完成');
    } catch (e) {
      LogService.e('刷新功能状态失败', e);
      // 刷新失败时保留旧状态，不更新 errorMessage 避免打扰用户
    }
  }

  Future<void> _onRefreshSingle(
    FeatureStatusRefreshSingle event,
    Emitter<FeatureStatusState> emit,
  ) async {
    try {
      final featureStatus = await _api.getFeatureStatus(event.feature);

      AllFeatureStatus newStatus;
      switch (event.feature) {
        case FeatureType.keyConfig:
          newStatus = state.status.copyWith(keyConfig: featureStatus);
          break;
        case FeatureType.issue:
          newStatus = state.status.copyWith(issue: featureStatus);
          break;
        case FeatureType.mapContribution:
          newStatus = state.status.copyWith(mapContribution: featureStatus);
          break;
      }

      emit(state.copyWith(
        status: newStatus,
        lastUpdated: DateTime.now(),
      ));

      LogService.d(
          '功能状态刷新: ${event.feature.displayName}=${featureStatus.enabled}');
    } catch (e) {
      LogService.e('刷新单个功能状态失败: ${event.feature.displayName}', e);
    }
  }

  void _onStartPeriodicRefresh(
    FeatureStatusStartPeriodicRefresh event,
    Emitter<FeatureStatusState> emit,
  ) {
    SchedulerService().register(ScheduledTask(
      id: _taskId,
      name: '功能状态刷新',
      interval: Intervals.fiveMinutes,
      callback: () async {
        // 检查 Bloc 是否已关闭，避免内存泄漏
        if (!isClosed) {
          add(FeatureStatusRefresh());
        }
      },
    ));
  }

  void _onStopPeriodicRefresh(
    FeatureStatusStopPeriodicRefresh event,
    Emitter<FeatureStatusState> emit,
  ) {
    SchedulerService().cancel(_taskId);
  }

  @override
  Future<void> close() {
    SchedulerService().cancel(_taskId);
    return super.close();
  }
}
