// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import '../api/env_config.dart';

class ApiConstants {
  static String get serverListUrl => EnvConfig.serverListUrl;
  static String get apiBaseUrl => EnvConfig.apiBaseUrl;

  static String get updateLogUrl => '$apiBaseUrl/stub';
  static String get serverDetailUrl => '$apiBaseUrl/stub';
  static String get serverPingUrl => '$apiBaseUrl/stub';
  static String get mapRuntimeUrl => '$apiBaseUrl/stub';
  static String get mapInfoUrl => '$apiBaseUrl/stub';
  static String get startupStatsUrl => '$apiBaseUrl/stub';
  static String get serverHistoryUrl => '$apiBaseUrl/stub';
  static String get serverInfoFallbackUrl => '$apiBaseUrl/stub';

  // 私有端点路径（占位值，真实路径见私有仓库）
  static const String analyticsEventPath = '/stub';
  static const String serverInfoPath = '/stub';
  static const String realtimeWsPath = '/stub';
  static const String webServerListWsPath = '/stub';
  static String serverUsersWsPath(String encodedAddress, String roomType) =>
      '/stub/$encodedAddress?roomType=$roomType';

  static const Duration defaultTimeout = Duration(seconds: 10);
  static const Duration shortTimeout = Duration(seconds: 3);
  static const Duration uploadTimeout = Duration(seconds: 30);

  static const Duration serverListCacheDuration = Duration(hours: 2);
  static const Duration updateLogCacheDuration = Duration(minutes: 15);
  static const Duration mapInfoCacheDuration = Duration(hours: 1);

  static const int defaultPageSize = 20;
  static const int updateLogPageSize = 10;

  static const Duration minRequestInterval = Duration(milliseconds: 500);

  static String get issueListUrl => '$apiBaseUrl/stub';
  static String get issueCreateUrl => '$apiBaseUrl/stub';
  static String issueDetailUrl(int id) => '$apiBaseUrl/stub/$id';
  static String issueCloseUrl(int id) => '$apiBaseUrl/stub/$id';
  static String issueReopenUrl(int id) => '$apiBaseUrl/stub/$id';
  static String issueVoteUrl(int id) => '$apiBaseUrl/stub/$id';
  static String issueCommentsUrl(int id) => '$apiBaseUrl/stub/$id';
  static String issueCommentCreateUrl(int id) => '$apiBaseUrl/stub/$id';
  static String get myIssuesUrl => '$apiBaseUrl/stub';
}
