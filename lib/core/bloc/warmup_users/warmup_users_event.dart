import 'package:equatable/equatable.dart';
import '../../models/queue_user.dart';

/// 暖服用户事件基类
sealed class WarmupUsersEvent extends Equatable {
  const WarmupUsersEvent();

  @override
  List<Object?> get props => [];
}

// ============================================================================
// Public Events (UI triggered)
// ============================================================================

/// 连接到指定服务器的暖服 WebSocket
class WarmupUsersConnect extends WarmupUsersEvent {
  final String serverAddress;

  const WarmupUsersConnect({required this.serverAddress});

  @override
  List<Object?> get props => [serverAddress];
}

/// 断开 WebSocket 连接
class WarmupUsersDisconnect extends WarmupUsersEvent {
  const WarmupUsersDisconnect();
}

/// 用户开始暖服
class WarmupUsersJoin extends WarmupUsersEvent {
  final String odId;
  final String visitorId;
  final String? nickname;
  final String? avatarUrl;

  const WarmupUsersJoin({
    this.odId = '',
    this.visitorId = '',
    this.nickname,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [odId, visitorId, nickname, avatarUrl];
}

/// 用户停止暖服
class WarmupUsersLeave extends WarmupUsersEvent {
  const WarmupUsersLeave();
}

/// 用户暖服成功
class WarmupUsersSuccess extends WarmupUsersEvent {
  const WarmupUsersSuccess();
}

// ============================================================================
// Internal Events (from WarmupUsersService)
// ============================================================================

/// 全量同步用户列表
class WarmupUsersSynced extends WarmupUsersEvent {
  final List<QueueUser> users;

  const WarmupUsersSynced({required this.users});

  @override
  List<Object?> get props => [users];
}

/// 新用户加入暖服
class WarmupUserJoined extends WarmupUsersEvent {
  final QueueUser user;

  const WarmupUserJoined({required this.user});

  @override
  List<Object?> get props => [user];
}

/// 用户离开暖服
class WarmupUserLeft extends WarmupUsersEvent {
  final String odId;
  final String visitorId;

  const WarmupUserLeft({required this.odId, required this.visitorId});

  @override
  List<Object?> get props => [odId, visitorId];
}

/// 用户暖服成功（进入服务器）
class WarmupUserSucceeded extends WarmupUsersEvent {
  final String odId;
  final String visitorId;

  const WarmupUserSucceeded({required this.odId, required this.visitorId});

  @override
  List<Object?> get props => [odId, visitorId];
}

/// WebSocket 错误
class WarmupUsersError extends WarmupUsersEvent {
  final String error;

  const WarmupUsersError({required this.error});

  @override
  List<Object?> get props => [error];
}

/// WebSocket 连接状态变化
class WarmupUsersConnectionChanged extends WarmupUsersEvent {
  final bool isConnected;

  const WarmupUsersConnectionChanged({required this.isConnected});

  @override
  List<Object?> get props => [isConnected];
}

/// 清除动画触发标记
class WarmupUsersClearAnimationTriggers extends WarmupUsersEvent {
  const WarmupUsersClearAnimationTriggers();
}
