import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/auth_service.dart';
import '../../services/scheduler_service.dart';
import '../../utils/log_service.dart';
import '../../utils/storage_utils.dart';
import 'daily_task_event.dart';
import 'daily_task_state.dart';

/// 每日任务 Bloc
///
/// 管理签到和摇一摇状态，支持跨天自动重置
class DailyTaskBloc extends Bloc<DailyTaskEvent, DailyTaskState> {
  final AuthService _authService = AuthService.instance;
  final SchedulerService _scheduler = SchedulerService();
  String? _lastCheckedDate;
  bool _isRefreshing = false; // 防止重复刷新

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
    
    // 从持久化存储中恢复上次检查日期
    _lastCheckedDate = StorageUtils.getString(_keyLastCheckDate);
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
    // 如果正在刷新，跳过本次检查
    if (_isRefreshing) return;

    final todayDate = _getBeijingDateString();

    if (_lastCheckedDate != null && _lastCheckedDate != todayDate) {
      // 直接删除所有昨天的缓存数据
      _clearYesterdayCache();
      
      _isRefreshing = true;
      add(const DailyTaskCheckStatusRequested(forceRefresh: true));
    } else if (_lastCheckedDate == null) {
      // 首次初始化：设置为今天
      _lastCheckedDate = todayDate;
      _saveCheckDate();
    }
  }

  /// 清除昨天的缓存数据
  void _clearYesterdayCache() {
    StorageUtils.remove(_keyCheckInReward);
    StorageUtils.remove(_keyCheckInRewardDate);
    StorageUtils.remove(_keyShakeReward);
    StorageUtils.remove(_keyShakeRewardDate);
  }

  /// 检查是否需要重新获取状态（跨天了）
  bool _needsRefresh() {
    final todayDate = _getBeijingDateString();
    return _lastCheckedDate != todayDate;
  }

  /// 保存检查日期
  Future<void> _saveCheckDate() async {
    final todayDate = _getBeijingDateString();
    await StorageUtils.setString(_keyLastCheckDate, todayDate);
    _lastCheckedDate = todayDate;
  }

  /// 保存签到奖励
  Future<void> _saveCheckInReward(int reward) async {
    final todayDate = _getBeijingDateString();
    await StorageUtils.setInt(_keyCheckInReward, reward);
    await StorageUtils.setString(_keyCheckInRewardDate, todayDate);
  }

  /// 获取今日签到奖励（如果是今天签到的）
  Future<int?> _getTodayCheckInReward() async {
    final rewardDate = StorageUtils.getString(_keyCheckInRewardDate);
    final todayDate = _getBeijingDateString();
    if (rewardDate == todayDate) {
      return StorageUtils.getInt(_keyCheckInReward);
    }
    return null;
  }

  /// 保存摇一摇奖励
  Future<void> _saveShakeReward(int reward) async {
    final todayDate = _getBeijingDateString();
    await StorageUtils.setInt(_keyShakeReward, reward);
    await StorageUtils.setString(_keyShakeRewardDate, todayDate);
  }

  /// 获取今日摇一摇奖励（如果是今天摇的）
  Future<int?> _getTodayShakeReward() async {
    final rewardDate = StorageUtils.getString(_keyShakeRewardDate);
    final todayDate = _getBeijingDateString();
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
      _isRefreshing = false;
      return;
    }

    // 检查是否跨天
    final needsRefresh = _needsRefresh();

    // 如果已有状态且没跨天，可以跳过（除非强制刷新）
    if (!needsRefresh && state.canShake != null && !event.forceRefresh) {
      _isRefreshing = false;
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

      // 读取今日奖励（如果缓存已被清除则为 null）
      final checkInReward = await _getTodayCheckInReward();
      final shakeReward = await _getTodayShakeReward();

      emit(state.copyWith(
        isCheckingStatus: false,
        hasCheckedIn: checkInResult.hasCheckedIn,
        checkInRewardAmount: checkInReward,
        clearCheckInReward: checkInReward == null,
        canShake: shakeResult.canShake,
        hasShaked: shakeResult.alreadyShaked,
        shakeRewardAmount: shakeReward,
        clearShakeReward: shakeReward == null,
      ));

      // 更新检查日期为今天
      await _saveCheckDate();
      
      _isRefreshing = false;
      _startCheckTask();
    } catch (e) {
      LogService.e('[DailyTask] 检查状态失败', e);
      emit(state.copyWith(isCheckingStatus: false));
      _isRefreshing = false;
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

      // 签到成功后，更新检查日期为今天
      if (result.success || result.alreadyCheckedIn) {
        await _saveCheckDate();
      }
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
    _isRefreshing = false;
    emit(const DailyTaskState());
  }

  @override
  Future<void> close() {
    _stopCheckTask();
    return super.close();
  }
}
