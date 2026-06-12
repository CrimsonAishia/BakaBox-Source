// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import '../models/user_info.dart';

/// 登录状态变化回调
typedef LoginStateChangedCallback = void Function(bool isLoggedIn);

/// 认证服务
class AuthService {
  static AuthService? _instance;
  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }

  AuthService._();

  final List<LoginStateChangedCallback> _loginStateListeners = [];

  void addLoginStateListener(LoginStateChangedCallback listener) {
    _loginStateListeners.add(listener);
  }

  void removeLoginStateListener(LoginStateChangedCallback listener) {
    _loginStateListeners.remove(listener);
  }

  bool get isLoggedIn => false;
  UserInfo? get userInfo => null;

  Future<LoginResult> login(String username, String password, {String? captchaToken}) async {
    throw UnimplementedError('Stub');
  }

  Future<LoginResult> loginWithCookies(List<Map<String, String>> cookieList) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> logout() async {
    throw UnimplementedError('Stub');
  }

  Future<void> forceLogout() async {
    throw UnimplementedError('Stub');
  }

  Future<bool?> validateForumSession() async {
    throw UnimplementedError('Stub');
  }

  Future<SessionValidationResult> validateAndRefreshSession({bool forceRefreshJwt = false}) async {
    throw UnimplementedError('Stub');
  }

  Future<UserInfo?> refreshUserStats() async {
    throw UnimplementedError('Stub');
  }

  Future<CheckInResult> checkIn({String mood = 'kx'}) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> restoreFromLocal() async {
    return false;
  }

  Map<String, dynamic> getLoginStatus() => {};

  Future<ShakeStatusResult> checkShakeStatus() async {
    throw UnimplementedError('Stub');
  }

  Future<ShakeResult> doShake() async {
    throw UnimplementedError('Stub');
  }

  Future<CheckInStatusResult> checkCheckInStatus() async {
    throw UnimplementedError('Stub');
  }
}

class Cookie {
  final String name;
  final String value;
  Cookie(this.name, this.value);
}

class LoginResult {
  final bool success;
  final String message;
  final UserInfo? userInfo;

  LoginResult({required this.success, required this.message, this.userInfo});
}

class SessionValidationResult {
  final bool forumValid;
  final bool jwtValid;
  final bool jwtRefreshed;
  final bool shouldLogout;
  final String message;

  SessionValidationResult({
    required this.forumValid,
    required this.jwtValid,
    this.jwtRefreshed = false,
    required this.shouldLogout,
    required this.message,
  });
}

class CheckInResult {
  final bool success;
  final String message;
  final bool alreadyCheckedIn;
  final int? rewardAmount;

  CheckInResult({required this.success, required this.message, this.alreadyCheckedIn = false, this.rewardAmount});
}

class ShakeStatusResult {
  final bool canShake;
  final bool alreadyShaked;
  final String message;
  final int? rewardAmount;

  ShakeStatusResult({required this.canShake, this.alreadyShaked = false, required this.message, this.rewardAmount});
}

class ShakeResult {
  final bool success;
  final String message;
  final bool alreadyShaked;
  final int? rewardAmount;

  ShakeResult({required this.success, required this.message, this.alreadyShaked = false, this.rewardAmount});
}

class CheckInStatusResult {
  final bool hasCheckedIn;
  final String message;

  CheckInStatusResult({required this.hasCheckedIn, required this.message});
}
