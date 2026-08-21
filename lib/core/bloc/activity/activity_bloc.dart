import 'dart:async';
import 'package:bloc/bloc.dart';
import '../../api/activity_api.dart';
import '../../models/activity_model.dart';
import '../../models/realtime_models.dart';
import '../../services/realtime_service.dart';
import 'activity_event.dart';
import 'activity_state.dart';
import '../../utils/log_service.dart';

export 'activity_event.dart';
export 'activity_state.dart';

class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _reconcileSubscription;

  ActivityBloc() : super(const ActivityState()) {
    on<ActivityFetch>(_onFetch);
    on<ActivityRealtimeEventReceived>(_onRealtimeEvent);

    on<ActivityFetchSingle>(_onFetchSingle);
    on<ActivityRealtimeDeleted>(_onRealtimeDeleted);

    _initRealtime();
  }

  void _initRealtime() {
    // 监听 WebSocket 对账信号，用于断线重连时重新拉取兜底
    _reconcileSubscription = RealtimeService().reconcileStream.listen((_) {
      if (!isClosed) {
        add(const ActivityFetch(silent: true));
      }
    });

    // 订阅 Activities 频道
    RealtimeService().subscribe(RealtimeChannels.activities);

    // 监听频道内事件
    _realtimeSubscription = RealtimeService()
        .events(RealtimeChannels.activities)
        .listen((event) {
          if (!isClosed) {
            add(ActivityRealtimeEventReceived(event));
          }
        });
  }

  Future<void> _onFetch(
    ActivityFetch event,
    Emitter<ActivityState> emit,
  ) async {
    if (!event.silent) {
      emit(state.copyWith(status: ActivityStatus.loading));
    }
    try {
      final activities = await ActivityApi.instance.getActivities();
      _sortActivities(activities);
      emit(
        state.copyWith(
          status: ActivityStatus.success,
          activities: activities,
          lastFetched: DateTime.now(),
        ),
      );
    } catch (e, st) {
      LogService.e('[ActivityBloc] 拉取活动失败', e, st);
      emit(state.copyWith(status: ActivityStatus.failure, error: e.toString()));
    }
  }

  void _onRealtimeEvent(
    ActivityRealtimeEventReceived event,
    Emitter<ActivityState> emit,
  ) {
    final channelEvent = event.event;
    final id = channelEvent.data['id'] as int?;
    if (id == null) return;

    switch (channelEvent.eventType) {
      case RealtimeEventTypes.activityCreated:
      case RealtimeEventTypes.activityUpdated:
        add(ActivityFetchSingle(id));
        break;
      case RealtimeEventTypes.activityDeleted:
        add(ActivityRealtimeDeleted(id));
        break;
    }
  }

  Future<void> _onFetchSingle(
    ActivityFetchSingle event,
    Emitter<ActivityState> emit,
  ) async {
    try {
      final activity = await ActivityApi.instance.getActivity(event.id);
      if (activity == null) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final isExpired = activity.endTime != null && now > activity.endTime!;
      final notStartedYet = activity.startTime > now;

      // 如果获取到的单条数据已经失效、过期或者还未开始，则从列表中移除/忽略
      if (!activity.isActive || isExpired || notStartedYet) {
        add(ActivityRealtimeDeleted(event.id));
        return;
      }

      final newActivities = List<ActivityModel>.from(state.activities);
      final index = newActivities.indexWhere((a) => a.id == activity.id);
      if (index != -1) {
        newActivities[index] = activity;
      } else {
        newActivities.add(activity);
      }

      _sortActivities(newActivities);

      emit(
        state.copyWith(
          activities: newActivities,
          status: ActivityStatus.success,
        ),
      );
    } catch (e, st) {
      LogService.e('[ActivityBloc] 获取单条活动失败 id=${event.id}', e, st);
    }
  }

  void _onRealtimeDeleted(
    ActivityRealtimeDeleted event,
    Emitter<ActivityState> emit,
  ) {
    final newActivities = state.activities
        .where((a) => a.id != event.id)
        .toList();

    emit(
      state.copyWith(activities: newActivities, status: ActivityStatus.success),
    );
  }

  void _sortActivities(List<ActivityModel> activities) {
    // 排序逻辑：置顶优先，其次按开始时间降序，最后按ID降序
    activities.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      if (a.startTime != b.startTime) {
        return b.startTime.compareTo(a.startTime);
      }
      return b.id.compareTo(a.id);
    });
  }

  @override
  Future<void> close() {
    _realtimeSubscription?.cancel();
    _reconcileSubscription?.cancel();
    RealtimeService().unsubscribe(RealtimeChannels.activities);
    return super.close();
  }
}
