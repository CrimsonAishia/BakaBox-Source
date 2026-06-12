// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

/// 通用 HTTP 请求（非 API 接口）
class Http {
  static Future<T?> get<T>(
    String url, {
    Map<String, dynamic>? query,
    T Function(dynamic json)? fromJson,
  }) async {
    throw UnimplementedError('Stub');
  }

  static Future<T?> post<T>(
    String url, {
    dynamic body,
    Map<String, dynamic>? query,
    T Function(dynamic json)? fromJson,
  }) async {
    throw UnimplementedError('Stub');
  }

  static Future<T?> put<T>(
    String url, {
    dynamic body,
    Map<String, dynamic>? query,
    T Function(dynamic json)? fromJson,
  }) async {
    throw UnimplementedError('Stub');
  }

  static Future<T?> delete<T>(
    String url, {
    dynamic body,
    Map<String, dynamic>? query,
    T Function(dynamic json)? fromJson,
  }) async {
    throw UnimplementedError('Stub');
  }
}
