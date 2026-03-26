import 'package:equatable/equatable.dart';
import '../../models/user_info.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

/// 认证状态
class AuthState extends Equatable {
  final AuthStatus status;
  final UserInfo? userInfo;
  final bool hasBackendToken;
  final String? errorMessage;
  final bool isRefreshing;

  const AuthState({
    this.status = AuthStatus.initial,
    this.userInfo,
    this.hasBackendToken = false,
    this.errorMessage,
    this.isRefreshing = false,
  });

  /// 是否已登录
  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// 是否正在加载
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    UserInfo? userInfo,
    bool? hasBackendToken,
    String? errorMessage,
    bool? isRefreshing,
  }) {
    return AuthState(
      status: status ?? this.status,
      userInfo: userInfo ?? this.userInfo,
      hasBackendToken: hasBackendToken ?? this.hasBackendToken,
      errorMessage: errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
    status,
    userInfo,
    hasBackendToken,
    errorMessage,
    isRefreshing,
  ];
}
