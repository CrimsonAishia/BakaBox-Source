import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../api/api_client.dart';
import '../utils/app_directory_service.dart';
import '../utils/log_service.dart';

/// 磁盘图片缓存服务
/// 
/// 提供纯磁盘缓存方案，不使用内存缓存，以减少内存占用。
/// 图片下载后直接保存到磁盘，读取时从磁盘加载。
class DiskImageCacheService {
  DiskImageCacheService._();
  
  static final DiskImageCacheService _instance = DiskImageCacheService._();
  static DiskImageCacheService get instance => _instance;
  
  static const String _cacheSubDir = 'images';
  
  /// 复用 ApiClient 的 Dio 实例，减少内存占用
  Dio get _dio => ApiClient.instance.dio;
  
  /// 获取缓存目录路径
  String get _cacheDir => p.join(AppDirectoryService.cachePath, _cacheSubDir);
  
  /// 确保缓存目录存在
  Future<void> _ensureCacheDir() async {
    final dir = Directory(_cacheDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }
  
  /// 从 URL 生成稳定的缓存文件名
  /// 
  /// 使用 URL 的 host + path 部分生成 MD5 哈希作为文件名，
  /// 忽略查询参数（如鉴权 token），确保同一图片只缓存一次。
  String _generateCacheFileName(String url) {
    final stableKey = extractCacheKey(url);
    final hash = md5.convert(utf8.encode(stableKey)).toString();
    // 尝试保留原始扩展名
    final extension = _extractExtension(url);
    return extension.isNotEmpty ? '$hash$extension' : hash;
  }
  
  /// 从 URL 提取文件扩展名
  String _extractExtension(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final lastDot = path.lastIndexOf('.');
      if (lastDot != -1 && lastDot < path.length - 1) {
        final ext = path.substring(lastDot).toLowerCase();
        // 只保留常见图片扩展名
        if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext)) {
          return ext;
        }
      }
    } catch (_) {}
    return '.jpg'; // 默认扩展名
  }
  
  /// 从 URL 提取稳定的缓存 key（去除查询参数）
  /// 
  /// 用于避免带鉴权参数的 URL 重复下载同一图片
  static String extractCacheKey(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.host}${uri.path}';
    } catch (e) {
      return url;
    }
  }
  
  /// 获取缓存文件路径
  /// 
  /// 根据 URL 生成对应的本地文件路径
  String getCacheFilePath(String url) {
    final fileName = _generateCacheFileName(url);
    return p.join(_cacheDir, fileName);
  }
  
  /// 检查图片是否已缓存
  Future<bool> isCached(String url) async {
    final filePath = getCacheFilePath(url);
    return File(filePath).exists();
  }

  /// 获取图片文件
  /// 
  /// 优先从磁盘读取，如果不存在则下载并保存到磁盘。
  /// 返回本地文件，如果下载失败返回 null。
  Future<File?> getImage(String url) async {
    if (url.isEmpty) return null;
    
    await _ensureCacheDir();
    
    final filePath = getCacheFilePath(url);
    final file = File(filePath);
    
    // 如果文件已存在，直接返回
    if (await file.exists()) {
      return file;
    }
    
    // 下载图片
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        // 保存到磁盘
        await file.writeAsBytes(response.data!);
        return file;
      }
    } catch (e) {
      LogService.e('[DiskImageCacheService] Failed to download image: $url', e);
    }
    
    return null;
  }
  
  /// 同步检查图片是否已缓存
  bool isCachedSync(String url) {
    final filePath = getCacheFilePath(url);
    return File(filePath).existsSync();
  }
  
  /// 同步获取缓存文件（如果存在）
  File? getCachedFileSync(String url) {
    final filePath = getCacheFilePath(url);
    final file = File(filePath);
    return file.existsSync() ? file : null;
  }
  
  /// 清除所有缓存
  Future<void> clearCache() async {
    try {
      final dir = Directory(_cacheDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
        LogService.i('[DiskImageCacheService] Cache cleared successfully');
      }
    } catch (e) {
      LogService.e('[DiskImageCacheService] Failed to clear cache', e);
    }
  }
  
  /// 获取缓存大小（字节）
  Future<int> getCacheSize() async {
    try {
      final dir = Directory(_cacheDir);
      if (!await dir.exists()) return 0;
      
      int totalSize = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      LogService.e('[DiskImageCacheService] Failed to get cache size', e);
      return 0;
    }
  }
  
  /// 获取缓存文件数量
  Future<int> getCacheCount() async {
    try {
      final dir = Directory(_cacheDir);
      if (!await dir.exists()) return 0;
      
      int count = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          count++;
        }
      }
      return count;
    } catch (e) {
      LogService.e('[DiskImageCacheService] Failed to get cache count', e);
      return 0;
    }
  }
}
