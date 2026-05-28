import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/realtime_models.dart';
import '../../services/auth_service.dart';
import '../../services/realtime_service.dart';
import '../../services/scheduler_service.dart';
import '../../services/token_service.dart';
import '../../utils/error_utils.dart';
import '../../utils/log_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// 认证 Bloc
///
/// 负责用户登录、登出、会话验证等认证相关状态管理
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService = AuthService.instance;
  final SchedulerService _scheduler = SchedulerService();
  StreamSubscription<RealtimeForceLogoutPayload>? _forceLogoutSubscription;

  static const _taskIdSessionValidation = 'auth_session_validation';
  static const _taskIdStatsRefresh = 'auth_stats_refresh';

  AuthBloc() : super(const AuthState()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthQQLoginRequested>(_onQQLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthRefreshRequested>(_onRefreshRequested);
    on<AuthValidateSessionRequested>(_onValidateSessionRequested);
    on<AuthSessionExpired>(_onSessionExpired);

    // 监听 WS 强制登出事件
    _forceLogoutSubscription =
        RealtimeService().forceLogoutStream.listen((payload) {
      LogService.w(
        '[AuthBloc] 收到 force_logout reason=${payload.reason} '
        'message=${payload.message}',
      );
      add(const AuthSessionExpired());
    });
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final restored = await _authService.restoreFromLocal();

      if (restored && _authService.isLoggedIn) {
        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            userInfo: _authService.userInfo,
            hasBackendToken: TokenService.instance.isTokenValid,
          ),
        );

        _startTimers();

        // 延迟验证会话
        Future.delayed(const Duration(seconds: 3), () {
          add(const AuthValidateSessionRequested());
        });
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } catch (e) {
      LogService.e('检查登录状态失败', e);
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final result = await _authService.login(
        event.username,
        event.password,
        captchaToken: event.captchaToken,
      );

      if (result.success) {
        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            userInfo: result.userInfo,
            hasBackendToken: TokenService.instance.isTokenValid,
          ),
        );

        _startTimers();

        // 登录成功后立即刷新一次统计信息
        Future.delayed(const Duration(milliseconds: 500), () {
          add(const AuthRefreshRequested());
        });
      } else {
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage: result.message,
          ),
        );
      }
    } catch (e) {
      LogService.e('登录失败', e);
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: ErrorUtils.getErrorMessage(e, defaultMessage: '登录失败'),
        ),
      );
    }
  }

  Future<void> _onQQLoginRequested(
    AuthQQLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final result = await _authService.loginWithCookies(event.cookies);

      if (result.success) {
        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            userInfo: result.userInfo,
            hasBackendToken: TokenService.instance.isTokenValid,
          ),
        );

        _startTimers();

        Future.delayed(const Duration(milliseconds: 500), () {
          add(const AuthRefreshRequested());
        });
      } else {
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage: result.message,
          ),
        );
      }
    } catch (e) {
      LogService.e('QQ登录失败', e);
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: ErrorUtils.getErrorMessage(e, defaultMessage: 'QQ登录失败'),
        ),
      );
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      _stopTimers();
      await _authService.logout();

      emit(const AuthState(status: AuthStatus.unauthenticated));
    } catch (e) {
      LogService.e('退出登录失败', e);
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> _onRefreshRequested(
    AuthRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (!state.isAuthenticated) return;

    emit(state.copyWith(isRefreshing: true));

    try {
      // 只刷新用户统计信息，会话验证由专门的定时器处理
      final userInfo = await _authService.refreshUserStats();

      emit(
        state.copyWith(
          userInfo: userInfo,
          hasBackendToken: TokenService.instance.isTokenValid,
          isRefreshing: false,
        ),
      );
    } catch (e) {
      LogService.e('刷新用户数据失败', e);
      emit(state.copyWith(isRefreshing: false));
    }
  }

  Future<void> _onValidateSessionRequested(
    AuthValidateSessionRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (!state.isAuthenticated) return;

    try {
      final result = await _authService.validateAndRefreshSession();

      if (result.shouldLogout) {
        add(const AuthSessionExpired());
        return;
      }

      emit(state.copyWith(hasBackendToken: TokenService.instance.isTokenValid));
    } catch (e) {
      LogService.e('验证会话失败', e);
    }
  }

  Future<void> _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    _stopTimers();
    await _authService.forceLogout();

    emit(
      const AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: '账号已过期，请重新关联',
      ),
    );
  }

  void _startTimers() {
    _stopTimers();

    // 会话验证定时器（每5分钟）
    _scheduler.register(
      ScheduledTask(
        id: _taskIdSessionValidation,
        name: '会话验证',
        interval: Intervals.fiveMinutes,
        callback: () async => add(const AuthValidateSessionRequested()),
      ),
    );

    // 统计信息刷新定时器（每5分钟）
    _scheduler.register(
      ScheduledTask(
        id: _taskIdStatsRefresh,
        name: '统计信息刷新',
        interval: Intervals.fiveMinutes,
        callback: () async => add(const AuthRefreshRequested()),
      ),
    );

    LogService.d('认证定时器已启动');
  }

  void _stopTimers() {
    _scheduler.cancel(_taskIdSessionValidation);
    _scheduler.cancel(_taskIdStatsRefresh);

    LogService.d('认证定时器已停止');
  }

  @override
  Future<void> close() {
    _stopTimers();
    _forceLogoutSubscription?.cancel();
    return super.close();
  }
}
