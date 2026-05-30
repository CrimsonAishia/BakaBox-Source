import 'package:equatable/equatable.dart';
import '../../models/queue_user.dart';

/// 挤服用户事件基类
sealed class QueueUsersEvent extends Equatable {
  const QueueUsersEvent();

  @override
  List<Object?> get props => [];
}

// ============================================================================
// Public Events (UI triggered)
// ============================================================================

/// 连接到指定服务器的挤服 WebSocket
///
/// 当挤服窗口打开时触发，建立 WebSocket 连接
class QueueUsersConnect extends QueueUsersEvent {
  /// 服务器地址
  final String serverAddress;

  const QueueUsersConnect({required this.serverAddress});

  @override
  List<Object?> get props => [serverAddress];
}

/// 断开 WebSocket 连接
///
/// 当用户关闭挤服窗口时触发
class QueueUsersDisconnect extends QueueUsersEvent {
  const QueueUsersDisconnect();
}

/// 用户开始挤服
///
/// 当用户点击"开始挤"按钮时触发，发送 join 消息到服务器
/// 由于后端不返回当前用户，需要在客户端把自己加入列表
class QueueUsersJoin extends QueueUsersEvent {
  /// 当前用户的 odId（登录用户有值，匿名用户为空）
  final String odId;

  /// 当前用户的 visitorId（匿名用户标识）
  final String visitorId;

  /// 当前用户昵称（匿名用户为空）
  final String? nickname;

  /// 当前用户头像URL（匿名用户为空）
  final String? avatarUrl;

  const QueueUsersJoin({
    this.odId = '',
    this.visitorId = '',
    this.nickname,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [odId, visitorId, nickname, avatarUrl];
}

/// 用户停止挤服
///
/// 当用户点击"停止"按钮或关闭窗口时触发，发送 leave 消息到服务器
class QueueUsersLeave extends QueueUsersEvent {
  const QueueUsersLeave();
}

/// 用户挤服成功
///
/// 当用户成功进入服务器时触发，发送 success 消息到服务器
class QueueUsersSuccess extends QueueUsersEvent {
  const QueueUsersSuccess();
}

// ============================================================================
// Internal Events (from QueueUsersService)
// ============================================================================

/// 全量同步用户列表
///
/// 当收到服务器的 sync 消息时触发，替换整个用户列表
class QueueUsersSynced extends QueueUsersEvent {
  /// 同步的用户列表
  final List<QueueUser> users;

  const QueueUsersSynced({required this.users});

  @override
  List<Object?> get props => [users];
}

/// 新用户加入挤服
///
/// 当收到服务器的 join 消息时触发，添加用户到列表并触发淡入动画
class QueueUserJoined extends QueueUsersEvent {
  /// 加入的用户
  final QueueUser user;

  const QueueUserJoined({required this.user});

  @override
  List<Object?> get props => [user];
}

/// 用户离开挤服
///
/// 当收到服务器的 leave 消息时触发，从列表移除用户并触发淡出动画
class QueueUserLeft extends QueueUsersEvent {
  /// 用户的 odId（登录用户）
  final String odId;

  /// 用户的 visitorId（匿名用户）
  final String visitorId;

  const QueueUserLeft({required this.odId, required this.visitorId});

  @override
  List<Object?> get props => [odId, visitorId];
}

/// 用户挤服成功
///
/// 当收到服务器的 success 消息时触发，标记用户进行飞入中心动画后移除
class QueueUserSucceeded extends QueueUsersEvent {
  /// 用户的 odId（登录用户）
  final String odId;

  /// 用户的 visitorId（匿名用户）
  final String visitorId;

  const QueueUserSucceeded({required this.odId, required this.visitorId});

  @override
  List<Object?> get props => [odId, visitorId];
}

/// WebSocket 错误
///
/// 当 WebSocket 连接出错时触发
class QueueUsersError extends QueueUsersEvent {
  /// 错误信息
  final String error;

  const QueueUsersError({required this.error});

  @override
  List<Object?> get props => [error];
}

/// WebSocket 连接状态变化
///
/// 当 WebSocket 连接状态发生变化时触发
class QueueUsersConnectionChanged extends QueueUsersEvent {
  /// 是否已连接
  final bool isConnected;

  const QueueUsersConnectionChanged({required this.isConnected});

  @override
  List<Object?> get props => [isConnected];
}

/// 清除动画触发标记
///
/// UI 层在消费动画触发标记后调用，用于清除 joinedUserId、leftUserId、successUserId
class QueueUsersClearAnimationTriggers extends QueueUsersEvent {
  const QueueUsersClearAnimationTriggers();
}
