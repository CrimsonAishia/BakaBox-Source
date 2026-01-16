import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/scheduler_service.dart';
import '../../utils/log_service.dart';
import 'daily_task_event.dart';
import 'daily_task_state.dart';

/// 每日任务 Bloc
///
/// 管理签到和摇一摇状态，支持跨天自动重置
class DailyTaskBloc extends Bloc<DailyTaskEvent, DailyTaskState> {
  final AuthService _authService = AuthService.instance;
  final SchedulerService _scheduler = SchedulerService();
  String? _lastCheckedDate;

  static const String _keyLastCheckDate = 'daily_task_last_check_date';
  static const String _keyCheckInReward = 'daily_task_checkin_reward';
  static const String _keyCheckInRewardDate = 'daily_task_checkin_reward_date';
  static const String _keyShakeReward = 'daily_task_shake_reward';
  static const String _keyShakeRewardDate = 'daily_task_shake_reward_date';
  static const String _taskId = 'daily_task_check';

  DailyTaskBloc() : super(const DailyTaskState()) {
    on<DailyTaskCheckStatusRequested>(_onCheckStatusRequested);
    on<DailyTaskCheckInRequested>(_onCheckInRequested);
    on<DailyTaskShakeCompleted>(_onShakeCompleted);
    on<DailyTaskReset>(_onReset);
  }

  /// 获取当前北京时间的日期字符串 (yyyy-MM-dd)
  String _getBeijingDateString() {
    final utcNow = DateTime.now().toUtc();
    final beijingNow = utcNow.add(const Duration(hours: 8));
    return '${beijingNow.year}-${beijingNow.month.toString().padLeft(2, '0')}-${beijingNow.day.toString().padLeft(2, '0')}';
  }

  /// 启动跨天检查定时任务
  void _startCheckTask() {
    if (_scheduler.hasTask(_taskId)) return;

    _scheduler.register(ScheduledTask(
      id: _taskId,
      name: '每日任务跨天检查',
      interval: Intervals.oneMinute,
      callback: () async => _checkDateChange(),
    ));
  }

  /// 停止定时任务
  void _stopCheckTask() {
    _scheduler.cancel(_taskId);
  }

  /// 检查是否跨天
  void _checkDateChange() {
    final todayDate = _getBeijingDateString();
    LogService.d('[DailyTask] 跨天检查: 当前=$todayDate, 上次=$_lastCheckedDate');

    if (_lastCheckedDate != null && _lastCheckedDate != todayDate) {
      LogService.i('[DailyTask] 检测到跨天: $_lastCheckedDate -> $todayDate，自动刷新状态');
      add(const DailyTaskCheckStatusRequested(forceRefresh: true));
    }

    _lastCheckedDate = todayDate;
  }

  /// 检查是否需要重新获取状态（跨天了）
  Future<bool> _needsRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckDate = prefs.getString(_keyLastCheckDate);
    final todayDate = _getBeijingDateString();

    if (lastCheckDate != todayDate) {
      LogService.d('[DailyTask] 跨天检测: 上次=$lastCheckDate, 今天=$todayDate, 需要刷新');
      return true;
    }
    return false;
  }

  /// 保存检查日期
  Future<void> _saveCheckDate() async {
    final prefs = await SharedPreferences.getInstance();
    final todayDate = _getBeijingDateString();
    await prefs.setString(_keyLastCheckDate, todayDate);
    _lastCheckedDate = todayDate;
  }

  /// 保存签到奖励
  Future<void> _saveCheckInReward(int reward) async {
    final prefs = await SharedPreferences.getInstance();
    final todayDate = _getBeijingDateString();
    await prefs.setInt(_keyCheckInReward, reward);
    await prefs.setString(_keyCheckInRewardDate, todayDate);
  }

  /// 获取今日签到奖励（如果是今天签到的）
  Future<int?> _getTodayCheckInReward() async {
    final prefs = await SharedPreferences.getInstance();
    final rewardDate = prefs.getString(_keyCheckInRewardDate);
    final todayDate = _getBeijingDateString();
    if (rewardDate == todayDate) {
      return prefs.getInt(_keyCheckInReward);
    }
    return null;
  }

  /// 保存摇一摇奖励
  Future<void> _saveShakeReward(int reward) async {
    final prefs = await SharedPreferences.getInstance();
    final todayDate = _getBeijingDateString();
    await prefs.setInt(_keyShakeReward, reward);
    await prefs.setString(_keyShakeRewardDate, todayDate);
  }

  /// 获取今日摇一摇奖励（如果是今天摇的）
  Future<int?> _getTodayShakeReward() async {
    final prefs = await SharedPreferences.getInstance();
    final rewardDate = prefs.getString(_keyShakeRewardDate);
    final todayDate = _getBeijingDateString();
    if (rewardDate == todayDate) {
      return prefs.getInt(_keyShakeReward);
    }
    return null;
  }

  Future<void> _onCheckStatusRequested(
    DailyTaskCheckStatusRequested event,
    Emitter<DailyTaskState> emit,
  ) async {
    if (!_authService.isLoggedIn) return;

    // 检查是否跨天，如果跨天则强制刷新
    final needsRefresh = await _needsRefresh();

    // 如果已有状态且没跨天，可以跳过（除非强制刷新）
    if (!needsRefresh && state.canShake != null && !event.forceRefresh) {
      LogService.d('[DailyTask] 状态未跨天，跳过刷新');
      // 确保定时任务在运行
      _startCheckTask();
      return;
    }

    emit(state.copyWith(isCheckingStatus: true));

    try {
      // 并行检查签到和摇一摇状态
      final results = await Future.wait([
        _authService.checkCheckInStatus(),
        _authService.checkShakeStatus(),
      ]);

      final checkInResult = results[0] as CheckInStatusResult;
      final shakeResult = results[1] as ShakeStatusResult;

      // 获取今日签到奖励（如果之前在 App 内签到过）
      final checkInReward = await _getTodayCheckInReward();
      // 获取今日摇一摇奖励（如果之前在 App 内摇过）
      final shakeReward = await _getTodayShakeReward();

      emit(state.copyWith(
        isCheckingStatus: false,
        hasCheckedIn: checkInResult.hasCheckedIn,
        checkInRewardAmount: checkInReward,
        clearCheckInReward: checkInReward == null,
        canShake: shakeResult.canShake,
        hasShaked: shakeResult.alreadyShaked,
        shakeRewardAmount: shakeReward ?? shakeResult.rewardAmount,
        clearShakeReward: shakeReward == null && shakeResult.rewardAmount == null,
      ));

      // 保存检查日期并启动定时任务
      await _saveCheckDate();
      _startCheckTask();
    } catch (e) {
      LogService.e('[DailyTask] 检查状态失败', e);
      emit(state.copyWith(isCheckingStatus: false));
      // 即使失败也启动定时任务，下次检查时重试
      _startCheckTask();
    }
  }

  Future<void> _onCheckInRequested(
    DailyTaskCheckInRequested event,
    Emitter<DailyTaskState> emit,
  ) async {
    if (!_authService.isLoggedIn) return;

    emit(state.copyWith(isCheckingIn: true));

    try {
      final result = await _authService.checkIn(mood: event.mood);

      // 保存签到奖励
      if (result.rewardAmount != null) {
        await _saveCheckInReward(result.rewardAmount!);
      }

      emit(state.copyWith(
        isCheckingIn: false,
        hasCheckedIn: result.success || result.alreadyCheckedIn,
        checkInRewardAmount: result.rewardAmount,
      ));
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
      // 保存摇一摇奖励
      if (event.rewardAmount != null) {
        await _saveShakeReward(event.rewardAmount!);
      }

      emit(state.copyWith(
        canShake: false,
        hasShaked: true,
        shakeRewardAmount: event.rewardAmount,
      ));
    }
  }

  Future<void> _onReset(
    DailyTaskReset event,
    Emitter<DailyTaskState> emit,
  ) async {
    _stopCheckTask();
    _lastCheckedDate = null;
    emit(const DailyTaskState());
  }

  @override
  Future<void> close() {
    _stopCheckTask();
    return super.close();
  }
}
