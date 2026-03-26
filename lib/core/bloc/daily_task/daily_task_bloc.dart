import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/auth_service.dart';
import '../../utils/log_service.dart';
import '../../utils/storage_utils.dart';
import 'daily_task_event.dart';
import 'daily_task_state.dart';

/// 每日任务 Bloc
///
/// 管理签到和摇一摇状态，支持跨天自动重置
class DailyTaskBloc extends Bloc<DailyTaskEvent, DailyTaskState> {
  final AuthService _authService = AuthService.instance;

  static const String _keyLastCheckDate = 'daily_task_last_check_date';
  static const String _keyCheckInReward = 'daily_task_checkin_reward';
  static const String _keyCheckInRewardDate = 'daily_task_checkin_reward_date';
  static const String _keyShakeReward = 'daily_task_shake_reward';
  static const String _keyShakeRewardDate = 'daily_task_shake_reward_date';

  DailyTaskBloc() : super(const DailyTaskState()) {
    on<DailyTaskCheckStatusRequested>(_onCheckStatusRequested);
    on<DailyTaskCheckInRequested>(_onCheckInRequested);
    on<DailyTaskShakeCompleted>(_onShakeCompleted);
    on<DailyTaskReset>(_onReset);
  }

  /// 获取当前北京时间的日期字符串 (yyyy-MM-dd)
  String _getTodayDate() {
    final utcNow = DateTime.now().toUtc();
    final beijingNow = utcNow.add(const Duration(hours: 8));
    return '${beijingNow.year}-${beijingNow.month.toString().padLeft(2, '0')}-${beijingNow.day.toString().padLeft(2, '0')}';
  }

  /// 清除本地缓存数据
  Future<void> _clearLocalCache() async {
    await StorageUtils.remove(_keyCheckInReward);
    await StorageUtils.remove(_keyCheckInRewardDate);
    await StorageUtils.remove(_keyShakeReward);
    await StorageUtils.remove(_keyShakeRewardDate);
    LogService.d('[DailyTask] 已清除本地缓存');
  }

  /// 保存签到奖励
  Future<void> _saveCheckInReward(int reward) async {
    final todayDate = _getTodayDate();
    await StorageUtils.setInt(_keyCheckInReward, reward);
    await StorageUtils.setString(_keyCheckInRewardDate, todayDate);
  }

  /// 获取今日签到奖励（如果是今天签到的）
  Future<int?> _getTodayCheckInReward() async {
    final rewardDate = StorageUtils.getString(_keyCheckInRewardDate);
    final todayDate = _getTodayDate();
    if (rewardDate == todayDate) {
      return StorageUtils.getInt(_keyCheckInReward);
    }
    return null;
  }

  /// 保存摇一摇奖励
  Future<void> _saveShakeReward(int reward) async {
    final todayDate = _getTodayDate();
    await StorageUtils.setInt(_keyShakeReward, reward);
    await StorageUtils.setString(_keyShakeRewardDate, todayDate);
  }

  /// 获取今日摇一摇奖励（如果是今天摇的）
  Future<int?> _getTodayShakeReward() async {
    final rewardDate = StorageUtils.getString(_keyShakeRewardDate);
    final todayDate = _getTodayDate();
    if (rewardDate == todayDate) {
      return StorageUtils.getInt(_keyShakeReward);
    }
    return null;
  }

  Future<void> _onCheckStatusRequested(
    DailyTaskCheckStatusRequested event,
    Emitter<DailyTaskState> emit,
  ) async {
    if (!_authService.isLoggedIn) {
      LogService.d('[DailyTask] 用户未登录，跳过状态检查');
      return;
    }

    LogService.d('[DailyTask] 开始检查状态');

    final todayDate = _getTodayDate();
    final lastCheckDate = StorageUtils.getString(_keyLastCheckDate);

    // 检查是否跨天
    final isCrossDay = lastCheckDate != null && lastCheckDate != todayDate;

    if (isCrossDay) {
      LogService.d('[DailyTask] 检测到跨天：$lastCheckDate -> $todayDate');
      await _clearLocalCache();
      emit(const DailyTaskState()); // 重置状态
    }

    // 如果同一天内已经检查过且有状态，跳过重复检查（优化性能）
    // 注意：跨天后需要重新检查，所以这里用 !isCrossDay
    if (!isCrossDay && lastCheckDate == todayDate && state.canShake != null) {
      LogService.d('[DailyTask] 今日已检查过状态，跳过重复请求');
      return;
    }

    emit(state.copyWith(isCheckingStatus: true));

    try {
      // 并行检查签到和摇一摇状态（服务器是唯一真相来源）
      final results = await Future.wait([
        _authService.checkCheckInStatus(),
        _authService.checkShakeStatus(),
      ]);

      // 请求后再次检查用户是否还登录
      if (!_authService.isLoggedIn) {
        LogService.d('[DailyTask] 请求过程中用户已登出，忽略结果');
        emit(state.copyWith(isCheckingStatus: false));
        return;
      }

      final checkInResult = results[0] as CheckInStatusResult;
      final shakeResult = results[1] as ShakeStatusResult;

      LogService.d(
        '[DailyTask] 服务器返回：hasCheckedIn=${checkInResult.hasCheckedIn}, canShake=${shakeResult.canShake}, hasShaked=${shakeResult.alreadyShaked}',
      );

      // 读取今日奖励缓存
      final checkInReward = await _getTodayCheckInReward();
      final shakeReward = await _getTodayShakeReward();

      LogService.d(
        '[DailyTask] 本地缓存：checkInReward=$checkInReward, shakeReward=$shakeReward',
      );

      // 摇一摇奖励逻辑：
      // 1. 如果本地有缓存 → 使用缓存
      // 2. 如果本地没有缓存但已摇过 → 使用服务器返回的金额并保存
      // 3. 如果未摇过 → 不显示金额（即使服务器返回了预设金额）
      int? finalShakeReward = shakeReward;
      if (shakeReward == null &&
          shakeResult.alreadyShaked &&
          shakeResult.rewardAmount != null) {
        // 已摇过但本地没有缓存，使用服务器返回的金额并保存
        finalShakeReward = shakeResult.rewardAmount;
        await _saveShakeReward(finalShakeReward!);
        LogService.d('[DailyTask] 已摇过但无缓存，保存服务器返回的奖励：$finalShakeReward');
      }

      emit(
        state.copyWith(
          isCheckingStatus: false,
          hasCheckedIn: checkInResult.hasCheckedIn,
          checkInRewardAmount: checkInReward,
          clearCheckInReward: checkInReward == null,
          canShake: shakeResult.canShake,
          hasShaked: shakeResult.alreadyShaked,
          shakeRewardAmount: finalShakeReward,
          clearShakeReward: finalShakeReward == null,
        ),
      );

      // 更新检查日期（确保成功后才更新）
      await StorageUtils.setString(_keyLastCheckDate, todayDate);
      LogService.d('[DailyTask] 状态检查完成，已更新检查日期：$todayDate');
    } catch (e) {
      LogService.e('[DailyTask] 检查状态失败', e);
      emit(state.copyWith(isCheckingStatus: false));
      // 注意：失败时不更新 _keyLastCheckDate，下次会重试
    }
  }

  Future<void> _onCheckInRequested(
    DailyTaskCheckInRequested event,
    Emitter<DailyTaskState> emit,
  ) async {
    if (!_authService.isLoggedIn) return;

    emit(state.copyWith(isCheckingIn: true));

    try {
      // 记录签到时的日期
      final checkInDate = _getTodayDate();

      final result = await _authService.checkIn(mood: event.mood);

      // 签到成功后，检查是否跨天了
      final currentDate = _getTodayDate();
      if (checkInDate != currentDate) {
        LogService.w(
          '[DailyTask] 签到过程中检测到跨天（$checkInDate -> $currentDate），忽略本次结果',
        );
        emit(state.copyWith(isCheckingIn: false));
        // 不触发状态检查，避免覆盖用户正在查看的状态
        // 用户下次展开列表时会自动检测跨天
        return;
      }

      // 保存签到奖励（带日期标记）
      if (result.rewardAmount != null) {
        await _saveCheckInReward(result.rewardAmount!);
      }

      emit(
        state.copyWith(
          isCheckingIn: false,
          hasCheckedIn: result.success || result.alreadyCheckedIn,
          checkInRewardAmount: result.rewardAmount,
        ),
      );

      LogService.i('[DailyTask] 签到成功，奖励：${result.rewardAmount}');
    } catch (e) {
      LogService.e('[DailyTask] 签到失败', e);
      emit(state.copyWith(isCheckingIn: false));
    }
  }

  Future<void> _onShakeCompleted(
    DailyTaskShakeCompleted event,
    Emitter<DailyTaskState> emit,
  ) async {
    if (event.success) {
      // 使用 lastCheckDate 来判断是否跨天（而不是 shakeRewardDate）
      final lastCheckDate = StorageUtils.getString(_keyLastCheckDate);
      final currentDate = _getTodayDate();

      if (lastCheckDate != null && lastCheckDate != currentDate) {
        LogService.w(
          '[DailyTask] 摇一摇过程中检测到跨天（$lastCheckDate -> $currentDate），忽略本次结果',
        );
        // 不触发状态检查，避免覆盖用户正在查看的状态
        // 用户下次展开列表时会自动检测跨天
        return;
      }

      // 保存摇一摇奖励（带日期标记）
      if (event.rewardAmount != null) {
        await _saveShakeReward(event.rewardAmount!);
      }

      emit(
        state.copyWith(
          canShake: false,
          hasShaked: true,
          shakeRewardAmount: event.rewardAmount,
        ),
      );

      LogService.i('[DailyTask] 摇一摇成功，奖励：${event.rewardAmount}');
    }
  }

  Future<void> _onReset(
    DailyTaskReset event,
    Emitter<DailyTaskState> emit,
  ) async {
    // 清除所有缓存数据
    await StorageUtils.remove(_keyLastCheckDate);
    await StorageUtils.remove(_keyCheckInReward);
    await StorageUtils.remove(_keyCheckInRewardDate);
    await StorageUtils.remove(_keyShakeReward);
    await StorageUtils.remove(_keyShakeRewardDate);

    emit(const DailyTaskState());
    LogService.d('[DailyTask] 已重置每日任务状态');
  }
}
