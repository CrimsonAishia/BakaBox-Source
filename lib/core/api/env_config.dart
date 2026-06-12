// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import 'package:flutter/foundation.dart';

/// 环境配置管理
class EnvConfig {
  static bool get isDev => kDebugMode;
  static String get apiBaseUrl => 'http://localhost:10000';
  static String get serverListUrl => '';

  // Nakama 服务器配置（占位值，真实配置见私有仓库）
  static String get nakamaHost => 'localhost';
  static int get nakamaPort => 7350;
  static int get nakamaGrpcPort => 7349;
  static String get nakamaServerKey => 'defaultkey';
  static bool get nakamaSsl => false;

  static String getApiUrl(String path) {
    if (path.startsWith('http')) return path;
    final base = apiBaseUrl.endsWith('/') ? apiBaseUrl.substring(0, apiBaseUrl.length - 1) : apiBaseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    return '$base$p';
  }
}
