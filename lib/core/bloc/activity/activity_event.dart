import 'package:equatable/equatable.dart';
import '../../models/realtime_models.dart';

abstract class ActivityEvent extends Equatable {
  const ActivityEvent();

  @override
  List<Object?> get props => [];
}

/// 触发获取活动列表（支持 HTTP 拉取）
class ActivityFetch extends ActivityEvent {
  final bool silent;
  const ActivityFetch({this.silent = false});

  @override
  List<Object?> get props => [silent];
}

/// 触发获取单条活动并追加/更新
class ActivityFetchSingle extends ActivityEvent {
  final int id;
  const ActivityFetchSingle(this.id);

  @override
  List<Object?> get props => [id];
}

/// 实时推送事件：活动删除
class ActivityRealtimeDeleted extends ActivityEvent {
  final int id;
  const ActivityRealtimeDeleted(this.id);

  @override
  List<Object?> get props => [id];
}

/// WebSocket 频道事件分发
class ActivityRealtimeEventReceived extends ActivityEvent {
  final RealtimeChannelEvent event;
  const ActivityRealtimeEventReceived(this.event);

  @override
  List<Object?> get props => [event];
}
