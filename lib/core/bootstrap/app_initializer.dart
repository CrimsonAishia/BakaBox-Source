import 'package:window_manager/window_manager.dart';

import '../services/analytics_service.dart';
import '../utils/app_directory_service.dart';
import '../utils/log_service.dart';

/// 应用初始化器
/// 
/// 负责初始化各种服务和资源
class AppInitializer {
  AppInitializer._();

  /// 记录启动时间
  static void recordStartTime() {
    AnalyticsService.instance.setStartTime(DateTime.now());
  }

  /// 初始化桌面端基础服务
  static Future<void> initDesktopBase() async {
    // 初始化应用目录服务（缓存和日志目录）
    await AppDirectoryService.init();
    // 初始化 windowManager
    await windowManager.ensureInitialized();
  }

  /// 初始化主窗口服务
  static Future<void> initMainWindowServices() async {
    await LogService.init();
  }
}
