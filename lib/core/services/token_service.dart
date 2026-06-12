// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import '../models/user_info.dart';

/// Token管理服务
class TokenService {
  static TokenService? _instance;
  static TokenService get instance {
    _instance ??= TokenService._();
    return _instance!;
  }

  TokenService._();

  String? get token => null;
  BackendUserInfo? get userInfo => null;
  bool get isTokenValid => false;

  Future<bool> exchangeToken(List<Map<String, String>> cookies, String deviceId) async {
    throw UnimplementedError('Stub');
  }

  Future<void> clearToken() async {}

  Future<bool> restoreFromLocal() async {
    return false;
  }

  Map<String, String> getAuthHeaders() => {};
}
