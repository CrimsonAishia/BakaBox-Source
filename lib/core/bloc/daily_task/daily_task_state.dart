import 'package:equatable/equatable.dart';

/// 每日任务状态
class DailyTaskState extends Equatable {
  /// 是否正在检测状态
  final bool isCheckingStatus;

  /// 是否正在签到
  final bool isCheckingIn;

  /// 是否已签到
  final bool hasCheckedIn;

  /// 签到获得的僵尸币数量
  final int? checkInRewardAmount;

  /// 是否可以摇一摇
  final bool? canShake;

  /// 是否已摇过
  final bool hasShaked;

  /// 摇一摇获得的奖励金额
  final int? shakeRewardAmount;

  const DailyTaskState({
    this.isCheckingStatus = false,
    this.isCheckingIn = false,
    this.hasCheckedIn = false,
    this.checkInRewardAmount,
    this.canShake,
    this.hasShaked = false,
    this.shakeRewardAmount,
  });

  DailyTaskState copyWith({
    bool? isCheckingStatus,
    bool? isCheckingIn,
    bool? hasCheckedIn,
    int? checkInRewardAmount,
    bool clearCheckInReward = false,
    bool? canShake,
    bool? hasShaked,
    int? shakeRewardAmount,
    bool clearShakeReward = false,
  }) {
    return DailyTaskState(
      isCheckingStatus: isCheckingStatus ?? this.isCheckingStatus,
      isCheckingIn: isCheckingIn ?? this.isCheckingIn,
      hasCheckedIn: hasCheckedIn ?? this.hasCheckedIn,
      checkInRewardAmount: clearCheckInReward
          ? null
          : (checkInRewardAmount ?? this.checkInRewardAmount),
      canShake: canShake ?? this.canShake,
      hasShaked: hasShaked ?? this.hasShaked,
      shakeRewardAmount: clearShakeReward
          ? null
          : (shakeRewardAmount ?? this.shakeRewardAmount),
    );
  }

  @override
  List<Object?> get props => [
    isCheckingStatus,
    isCheckingIn,
    hasCheckedIn,
    checkInRewardAmount,
    canShake,
    hasShaked,
    shakeRewardAmount,
  ];
}
