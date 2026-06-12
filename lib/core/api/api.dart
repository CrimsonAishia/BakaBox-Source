// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import 'package:dio/dio.dart';
import '../exceptions/app_exception.dart';

/// API 请求封装
class Api {
  static Future<T?> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic json)? fromJson,
  }) async {
    throw UnimplementedError('Stub');
  }

  static Future<T?> post<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    T Function(dynamic json)? fromJson,
    Options? options,
  }) async {
    throw UnimplementedError('Stub');
  }

  static Future<T?> put<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    T Function(dynamic json)? fromJson,
    Options? options,
  }) async {
    throw UnimplementedError('Stub');
  }

  static Future<T?> delete<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    T Function(dynamic json)? fromJson,
  }) async {
    throw UnimplementedError('Stub');
  }
}

/// API 异常
class ApiException implements AppException {
  final int code;

  @override
  final String message;

  const ApiException({required this.code, required this.message});

  @override
  String toString() => 'ApiException: [$code] $message';
}
