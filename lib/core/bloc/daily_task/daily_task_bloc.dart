import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../utils/log_service.dart';
import 'daily_task_event.dart';
import 'daily_task_state.dart';

/// 每日任务 Bloc
///
/// 管理签到和摇一摇状态，支持跨天自动重置
class DailyTaskBloc extends Bloc<DailyTaskEvent, DailyTaskState> {
  final AuthService _authService = AuthService.instance;
  Timer? _checkTimer;
  String? _lastCheckedDate;
  
  static const String _keyLastCheckDate = 'daily_task_last_check_date';
  // 每分钟检查一次是否跨天
  static const Duration _checkInterval = Duration(minutes: 1);

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

  /// 启动跨天检查定时器
  void _startCheckTimer() {
    _stopCheckTimer();
    
    _checkTimer = Timer.periodic(_checkInterval, (_) {
      _checkDateChange();
    });
    
    LogService.d('每日任务跨天检查定时器已启动，间隔: ${_checkInterval.inMinutes}分钟');
  }

  /// 停止定时器
  void _stopCheckTimer() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// 检查是否跨天
  void _checkDateChange() {
    final todayDate = _getBeijingDateString();
    
    if (_lastCheckedDate != null && _lastCheckedDate != todayDate) {
      LogService.i('检测到跨天: $_lastCheckedDate -> $todayDate，自动刷新每日任务状态');
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
      LogService.d('每日任务跨天检测: 上次=$lastCheckDate, 今天=$todayDate, 需要刷新');
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

  Future<void> _onCheckStatusRequested(
    DailyTaskCheckStatusRequested event,
    Emitter<DailyTaskState> emit,
  ) async {
    if (!_authService.isLoggedIn) return;

    // 检查是否跨天，如果跨天则强制刷新
    final needsRefresh = await _needsRefresh();
    
    // 如果已有状态且没跨天，可以跳过（除非强制刷新）
    // 用 canShake 判断是否已获取过状态（它是 nullable 的，初始为 null）
    if (!needsRefresh && state.canShake != null && !event.forceRefresh) {
      LogService.d('每日任务状态未跨天，跳过刷新');
      // 确保定时器在运行
      if (_checkTimer == null) _startCheckTimer();
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

      emit(state.copyWith(
        isCheckingStatus: false,
        hasCheckedIn: checkInResult.hasCheckedIn,
        canShake: shakeResult.canShake,
        hasShaked: shakeResult.alreadyShaked,
        shakeRewardAmount: shakeResult.rewardAmount,
      ));

      // 保存检查日期并启动定时器
      await _saveCheckDate();
      _startCheckTimer();
    } catch (e) {
      LogService.e('检查每日任务状态失败', e);
      emit(state.copyWith(isCheckingStatus: false));
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

      emit(state.copyWith(
        isCheckingIn: false,
        hasCheckedIn: result.success || result.alreadyCheckedIn,
      ));
    } catch (e) {
      LogService.e('签到失败', e);
      emit(state.copyWith(isCheckingIn: false));
    }
  }

  Future<void> _onShakeCompleted(
    DailyTaskShakeCompleted event,
    Emitter<DailyTaskState> emit,
  ) async {
    if (event.success) {
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
    _stopCheckTimer();
    _lastCheckedDate = null;
    emit(const DailyTaskState());
  }

  @override
  Future<void> close() {
    _stopCheckTimer();
    return super.close();
  }
}
