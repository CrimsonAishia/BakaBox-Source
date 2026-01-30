import 'package:equatable/equatable.dart';

/// 通知事件基类
sealed class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

/// 获取通知列表
class NotificationFetch extends NotificationEvent {
  final int page;
  final String? type;
  final bool? isRead;

  const NotificationFetch({
    this.page = 1,
    this.type,
    this.isRead,
  });

  @override
  List<Object?> get props => [page, type, isRead];
}

/// 刷新通知列表
class NotificationRefresh extends NotificationEvent {
  final bool silent;

  const NotificationRefresh({this.silent = false});

  @override
  List<Object?> get props => [silent];
}

/// 加载更多通知
class NotificationLoadMore extends NotificationEvent {
  const NotificationLoadMore();
}

/// 标记单个通知已读
class NotificationMarkRead extends NotificationEvent {
  final int id;

  const NotificationMarkRead(this.id);

  @override
  List<Object?> get props => [id];
}

/// 标记所有通知已读
class NotificationMarkAllRead extends NotificationEvent {
  const NotificationMarkAllRead();
}

/// 删除通知
class NotificationDelete extends NotificationEvent {
  final int id;

  const NotificationDelete(this.id);

  @override
  List<Object?> get props => [id];
}

/// 获取未读数量
class NotificationFetchUnreadCount extends NotificationEvent {
  const NotificationFetchUnreadCount();
}

/// 启动自动刷新
class NotificationStartAutoRefresh extends NotificationEvent {
  const NotificationStartAutoRefresh();
}

/// 停止自动刷新
class NotificationStopAutoRefresh extends NotificationEvent {
  const NotificationStopAutoRefresh();
}

/// 清除错误
class NotificationClearError extends NotificationEvent {
  const NotificationClearError();
}
