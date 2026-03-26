import 'package:equatable/equatable.dart';
import '../../models/queue_user.dart';

/// 挤服用户状态
///
/// 管理用户列表、连接状态和动画触发标记
class QueueUsersState extends Equatable {
  /// 当前挤服用户列表
  final List<QueueUser> users;

  /// WebSocket 连接状态
  final bool isConnected;

  /// 是否正在连接
  final bool isConnecting;

  /// 错误信息
  final String? error;

  /// 刚加入的用户ID（用于触发淡入动画）
  final String? joinedUserId;

  /// 刚离开的用户ID（用于触发淡出动画）
  final String? leftUserId;

  /// 刚离开的用户信息（用于活动日志显示昵称）
  final QueueUser? leftUser;

  /// 刚成功的用户ID（用于触发飞入中心动画）
  final String? successUserId;

  /// 刚成功的用户信息（用于活动日志显示昵称）
  final QueueUser? successUser;

  const QueueUsersState({
    this.users = const [],
    this.isConnected = false,
    this.isConnecting = false,
    this.error,
    this.joinedUserId,
    this.leftUserId,
    this.leftUser,
    this.successUserId,
    this.successUser,
  });

  /// 当前挤服人数
  int get queueingCount => users.length;

  /// 创建初始状态
  factory QueueUsersState.initial() => const QueueUsersState();

  /// 复制并修改状态
  QueueUsersState copyWith({
    List<QueueUser>? users,
    bool? isConnected,
    bool? isConnecting,
    String? error,
    String? joinedUserId,
    String? leftUserId,
    QueueUser? leftUser,
    String? successUserId,
    QueueUser? successUser,
    bool clearError = false,
    bool clearJoinedUserId = false,
    bool clearLeftUserId = false,
    bool clearSuccessUserId = false,
  }) {
    return QueueUsersState(
      users: users ?? this.users,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      error: clearError ? null : (error ?? this.error),
      joinedUserId: clearJoinedUserId
          ? null
          : (joinedUserId ?? this.joinedUserId),
      leftUserId: clearLeftUserId ? null : (leftUserId ?? this.leftUserId),
      leftUser: clearLeftUserId ? null : (leftUser ?? this.leftUser),
      successUserId: clearSuccessUserId
          ? null
          : (successUserId ?? this.successUserId),
      successUser: clearSuccessUserId
          ? null
          : (successUser ?? this.successUser),
    );
  }

  @override
  List<Object?> get props => [
    users,
    isConnected,
    isConnecting,
    error,
    joinedUserId,
    leftUserId,
    leftUser,
    successUserId,
    successUser,
  ];
}
