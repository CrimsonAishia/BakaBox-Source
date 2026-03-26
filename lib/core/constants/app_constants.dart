class AppConstants {
  // App Info
  static const String appName = 'BakaBox';
  // 注意：版本号请使用 AppInfoService.instance.version 获取
  static const String appDescription = 'CS2 启动器';
  static const String appAuthor = 'Aishia';
  static const String appCopyright = '© 2026 Aishia. All rights reserved.';
  static const String appWebsite = 'https://bakabox.app';

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double cardElevation = 2.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Server Status Colors
  static const String onlineColor = '#4CAF50';
  static const String offlineColor = '#F44336';
  static const String unknownColor = '#9E9E9E';

  // Refresh Intervals
  static const Duration autoRefreshInterval = Duration(seconds: 30);
  static const Duration pingUpdateInterval = Duration(seconds: 5);
}
