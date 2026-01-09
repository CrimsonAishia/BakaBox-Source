import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// 检查登录状态（应用启动时）
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// 登录请求
class AuthLoginRequested extends AuthEvent {
  final String username;
  final String password;

  const AuthLoginRequested({
    required this.username,
    required this.password,
  });

  @override
  List<Object?> get props => [username, password];
}

/// 退出登录
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// 刷新用户数据
class AuthRefreshRequested extends AuthEvent {
  const AuthRefreshRequested();
}

/// 验证会话
class AuthValidateSessionRequested extends AuthEvent {
  const AuthValidateSessionRequested();
}

/// 会话过期（强制退出）
class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}

/// QQ 登录请求（通过 Cookie）
class AuthQQLoginRequested extends AuthEvent {
  final List<Map<String, String>> cookies;

  const AuthQQLoginRequested({
    required this.cookies,
  });

  @override
  List<Object?> get props => [cookies];
}
