import 'package:equatable/equatable.dart';

import '../../models/notification_models.dart';

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

  const NotificationFetch({this.page = 1, this.type, this.isRead});

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

/// 获取未读数量（首次拉基线时调用一次，长连接建立后由 WS 维护）
class NotificationFetchUnreadCount extends NotificationEvent {
  const NotificationFetchUnreadCount();
}

/// 启动 WebSocket 实时推送订阅（替代旧的轮询）
class NotificationStartRealtime extends NotificationEvent {
  const NotificationStartRealtime();
}

/// 停止 WebSocket 实时推送订阅
class NotificationStopRealtime extends NotificationEvent {
  const NotificationStopRealtime();
}

/// 收到一条 WS 推送的新消息
class NotificationRealtimeReceived extends NotificationEvent {
  final NotificationItem item;

  const NotificationRealtimeReceived(this.item);

  @override
  List<Object?> get props => [item];
}

/// 清除错误
class NotificationClearError extends NotificationEvent {
  const NotificationClearError();
}

/// 清除所有消息数据（退出登录时调用）
class NotificationClear extends NotificationEvent {
  const NotificationClear();
}
