import 'package:equatable/equatable.dart';

abstract class DailyTaskEvent extends Equatable {
  const DailyTaskEvent();

  @override
  List<Object?> get props => [];
}

/// 检查每日任务状态（签到+摇一摇）
class DailyTaskCheckStatusRequested extends DailyTaskEvent {
  const DailyTaskCheckStatusRequested();
}

/// 执行签到
class DailyTaskCheckInRequested extends DailyTaskEvent {
  final String mood;

  const DailyTaskCheckInRequested({this.mood = 'kx'});

  @override
  List<Object?> get props => [mood];
}

/// 摇一摇完成
class DailyTaskShakeCompleted extends DailyTaskEvent {
  final bool success;
  final int? rewardAmount;

  const DailyTaskShakeCompleted({
    required this.success,
    this.rewardAmount,
  });

  @override
  List<Object?> get props => [success, rewardAmount];
}

/// 重置每日任务状态（登出时调用）
class DailyTaskReset extends DailyTaskEvent {
  const DailyTaskReset();
}
