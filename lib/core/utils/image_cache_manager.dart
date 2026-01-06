import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'app_directory_service.dart';
import 'platform_utils.dart';

/// 自定义图片缓存管理器
/// 桌面端：使用 我的文档/bakabox/cache/images
/// 移动端：使用默认缓存目录
class AppImageCacheManager {
  static const key = 'bakaboxImageCache';

  static CacheManager? _instance;

  static CacheManager get instance {
    _instance ??= _createCacheManager();
    return _instance!;
  }

  static CacheManager _createCacheManager() {
    if (PlatformUtils.isDesktopPlatform) {
      // 桌面端：使用自定义缓存目录
      final cacheDir = p.join(AppDirectoryService.cachePath, 'images');
      // 确保目录存在
      Directory(cacheDir).createSync(recursive: true);

      return CacheManager(
        Config(
          key,
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 500,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileSystem: IOFileSystem(cacheDir),
          fileService: HttpFileService(),
        ),
      );
    } else {
      // 移动端：使用默认缓存管理器
      return DefaultCacheManager();
    }
  }

  /// 清除图片缓存
  static Future<void> clearCache() async {
    await instance.emptyCache();
  }

  /// 获取缓存目录路径（仅桌面端有效）
  static String? getCacheDirectory() {
    if (PlatformUtils.isDesktopPlatform) {
      return p.join(AppDirectoryService.cachePath, 'images');
    }
    return null;
  }

  /// 从 URL 提取稳定的缓存 key（去除查询参数）
  /// 
  /// 用于避免带鉴权参数的 URL 重复下载同一图片
  /// 
  /// 例如：
  /// - https://cdn.example.com/maps/ze_xxx.jpg?token=abc → cdn.example.com/maps/ze_xxx.jpg
  /// - https://cdn.example.com/uploads/123.png?expires=xxx → cdn.example.com/uploads/123.png
  static String extractCacheKey(String url) {
    try {
      final uri = Uri.parse(url);
      // 使用 host + path 作为 key，忽略查询参数
      return '${uri.host}${uri.path}';
    } catch (e) {
      // 解析失败时使用原 URL
      return url;
    }
  }
}
