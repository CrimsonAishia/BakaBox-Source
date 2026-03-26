import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'platform_utils.dart';

/// 应用目录服务 - 统一管理缓存和日志目录
/// 桌面端：我的文档/BakaBox/
/// 移动端：应用文档目录
class AppDirectoryService {
  AppDirectoryService._();

  static String? _basePath;
  static String? _cachePath;
  static String? _logsPath;
  static bool _initialized = false;

  /// 初始化目录服务
  static Future<void> init() async {
    if (_initialized) return;

    if (PlatformUtils.isDesktopPlatform) {
      // 桌面端：使用我的文档/BakaBox
      final documentsDir = await getApplicationDocumentsDirectory();
      _basePath = '${documentsDir.path}${Platform.pathSeparator}BakaBox';
    } else {
      // 移动端：使用应用文档目录
      final appDir = await getApplicationDocumentsDirectory();
      _basePath = appDir.path;
    }

    _cachePath = '$_basePath${Platform.pathSeparator}cache';
    _logsPath = '$_basePath${Platform.pathSeparator}logs';

    // 确保目录存在
    await _ensureDirectoryExists(_basePath!);
    await _ensureDirectoryExists(_cachePath!);
    await _ensureDirectoryExists(_logsPath!);

    _initialized = true;
  }

  /// 确保目录存在
  static Future<void> _ensureDirectoryExists(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// 获取基础目录路径
  static String get basePath {
    _checkInitialized();
    return _basePath!;
  }

  /// 获取缓存目录路径
  static String get cachePath {
    _checkInitialized();
    return _cachePath!;
  }

  /// 获取日志目录路径
  static String get logsPath {
    _checkInitialized();
    return _logsPath!;
  }

  /// 获取日志导出目录路径
  static String get logsExportPath {
    _checkInitialized();
    return '$_logsPath${Platform.pathSeparator}exported';
  }

  static void _checkInitialized() {
    if (!_initialized) {
      throw StateError(
        'AppDirectoryService not initialized. Call init() first.',
      );
    }
  }

  /// 获取缓存文件路径
  static String getCacheFilePath(String fileName) {
    return '$cachePath${Platform.pathSeparator}$fileName';
  }

  /// 获取日志文件路径
  static String getLogFilePath(String fileName) {
    return '$logsPath${Platform.pathSeparator}$fileName';
  }
}
