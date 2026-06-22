import 'package:equatable/equatable.dart';
import '../../models/queue_user.dart';

/// 暖服用户状态
class WarmupUsersState extends Equatable {
  /// 用户列表
  final List<QueueUser> users;

  /// 是否已连接
  final bool isConnected;

  /// 是否正在连接
  final bool isConnecting;

  /// 错误信息
  final String? error;

  /// 刚加入的用户ID（触发淡入动画）
  final String? joinedUserId;

  /// 刚离开的用户ID（触发淡出动画）
  final String? leftUserId;

  /// 刚离开的用户信息（用于活动日志）
  final QueueUser? leftUser;

  /// 刚成功的用户ID（触发飞入动画）
  final String? successUserId;

  /// 刚成功的用户信息（用于活动日志）
  final QueueUser? successUser;

  const WarmupUsersState({
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

  factory WarmupUsersState.initial() => const WarmupUsersState();

  WarmupUsersState copyWith({
    List<QueueUser>? users,
    bool? isConnected,
    bool? isConnecting,
    String? error,
    bool clearError = false,
    String? joinedUserId,
    bool clearJoinedUserId = false,
    String? leftUserId,
    QueueUser? leftUser,
    bool clearLeftUserId = false,
    String? successUserId,
    QueueUser? successUser,
    bool clearSuccessUserId = false,
  }) {
    return WarmupUsersState(
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
