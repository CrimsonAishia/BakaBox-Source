import 'package:equatable/equatable.dart';

import '../../services/realtime/realtime_announcement_channel.dart';

/// 公告事件基类
abstract class AnnouncementEvent extends Equatable {
  const AnnouncementEvent();

  @override
  List<Object?> get props => [];
}

/// 获取公告列表事件
///
/// 触发时机：应用启动或首次进入公告页面
class AnnouncementFetch extends AnnouncementEvent {}

/// 刷新公告列表事件
///
/// 触发时机：用户手动下拉刷新或 WS 推送触发的自动刷新
///
/// [silent] 是否静默刷新（不显示 loading 状态）
class AnnouncementRefresh extends AnnouncementEvent {
  final bool silent;

  const AnnouncementRefresh({this.silent = false});

  @override
  List<Object?> get props => [silent];
}

/// 标记公告为已读事件
///
/// 触发时机：用户查看公告详情
class AnnouncementMarkAsRead extends AnnouncementEvent {
  final int announcementId;

  const AnnouncementMarkAsRead(this.announcementId);

  @override
  List<Object?> get props => [announcementId];
}

/// 清除错误状态事件
class AnnouncementClearError extends AnnouncementEvent {}

/// 启动 WS 实时订阅
class AnnouncementStartRealtime extends AnnouncementEvent {
  const AnnouncementStartRealtime();
}

/// 停止 WS 实时订阅
class AnnouncementStopRealtime extends AnnouncementEvent {
  const AnnouncementStopRealtime();
}

/// 收到公告频道推送（内部事件）
class AnnouncementRealtimeReceived extends AnnouncementEvent {
  final AnnouncementChannelEvent payload;

  const AnnouncementRealtimeReceived(this.payload);

  @override
  List<Object?> get props => [payload.kind, payload.id];
}

/// 获取公告详情事件
class AnnouncementFetchDetail extends AnnouncementEvent {
  final int announcementId;

  const AnnouncementFetchDetail(this.announcementId);

  @override
  List<Object?> get props => [announcementId];
}
