import 'package:equatable/equatable.dart';

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
/// 触发时机：用户手动下拉刷新或自动刷新
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
/// 
/// 触发时机：用户关闭错误提示或重试
class AnnouncementClearError extends AnnouncementEvent {}

/// 启动自动刷新事件
/// 
/// 触发时机：应用启动时
class AnnouncementStartAutoRefresh extends AnnouncementEvent {}

/// 停止自动刷新事件
/// 
/// 触发时机：应用退出或需要停止刷新时
class AnnouncementStopAutoRefresh extends AnnouncementEvent {}
