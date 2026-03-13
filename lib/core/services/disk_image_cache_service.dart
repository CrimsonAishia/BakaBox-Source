import 'dart:io';
import 'dart:typed_data';
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

  /// 验证图片字节数据是否有效
  ///
  /// 检查文件头和最小长度，排除空图片或非图片数据
  bool _validateImageBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      return false;
    }

    // 最小有效图片大小：通常大于 100 字节（很小的占位图除外）
    // 这里允许小文件，因为有些 1x1 的 GIF/PNG 是有效的
    if (bytes.length < 4) {
      return false;
    }

    // 检查文件头（魔数）
    final firstBytes = bytes.sublist(0, 8);

    // JPEG: FF D8 FF
    if (firstBytes[0] == 0xFF && firstBytes[1] == 0xD8 && firstBytes[2] == 0xFF) {
      return true;
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (firstBytes[0] == 0x89 && firstBytes[1] == 0x50 && firstBytes[2] == 0x4E && firstBytes[3] == 0x47) {
      return true;
    }

    // GIF: 47 49 46 38 (GIF8)
    if (firstBytes[0] == 0x47 && firstBytes[1] == 0x49 && firstBytes[2] == 0x46 && firstBytes[3] == 0x38) {
      return true;
    }

    // WebP: RIFF....WEBP 或 RIFF....VP8L
    if (firstBytes[0] == 0x52 && firstBytes[1] == 0x49 && firstBytes[2] == 0x46 && firstBytes[3] == 0x46) {
      // 需要验证是 WebP 格式
      if (bytes.length >= 12) {
        // Lossy WebP: RIFF....WEBP
        if (bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
          return true;
        }
        // Lossless WebP: RIFF....VP8L
        if (bytes[8] == 0x56 && bytes[9] == 0x50 && bytes[10] == 0x38 && bytes[11] == 0x4C) {
          return true;
        }
        // Animated WebP: RIFF....WEBP (with ANIM chunk)
        // 也以 WEBP 开头，已被上面的检测覆盖
      }
    }

    // BMP: 42 4D (BM)
    if (firstBytes[0] == 0x42 && firstBytes[1] == 0x4D) {
      return true;
    }

    // ICO: 00 00 01 00 或 00 00 02 00
    if (firstBytes[0] == 0x00 && firstBytes[1] == 0x00 && (firstBytes[2] == 0x01 || firstBytes[2] == 0x02) && firstBytes[3] == 0x00) {
      return true;
    }

    return false;
  }

  /// 验证缓存文件是否为有效图片
  ///
  /// 如果文件无效，删除并返回 false
  Future<bool> _validateAndFixCacheFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final bytes = await file.readAsBytes();

      // 检查文件是否为空
      if (bytes.isEmpty) {
        LogService.w('[DiskImageCacheService] Detected empty image file, removing: $filePath');
        await file.delete();
        return false;
      }

      // 验证图片格式
      if (!_validateImageBytes(bytes)) {
        LogService.w('[DiskImageCacheService] Detected invalid/corrupt image file, removing: $filePath');
        await file.delete();
        return false;
      }

      return true;
    } catch (e) {
      LogService.e('[DiskImageCacheService] Error validating cache file: $filePath', e);
      try {
        await File(filePath).delete();
      } catch (_) {}
      return false;
    }
  }

  /// 获取图片文件
  ///
  /// 优先从磁盘读取，如果不存在则下载并保存到磁盘。
  /// 返回本地文件，如果下载失败或图片无效返回 null。
  /// 读取时会自动检测并清理失效图片（如空图片或损坏的图片）。
  Future<File?> getImage(String url, {int maxRetries = 1}) async {
    if (url.isEmpty) return null;

    await _ensureCacheDir();

    final filePath = getCacheFilePath(url);
    final file = File(filePath);

    // 如果文件已存在，验证并返回
    if (await file.exists()) {
      // 验证缓存文件是否为有效图片，无效则删除
      if (await _validateAndFixCacheFile(filePath)) {
        return file;
      }
      // 文件无效已被删除，需要重新下载
    }

    // 下载图片，支持重试
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        Map<String, String> headers = {};
        if (url.contains('hdslb.com') || url.contains('bilibili.com')) {
          headers['Referer'] = 'https://www.bilibili.com';
          headers['User-Agent'] =
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
        }

        final response = await _dio.get<List<int>>(
          url,
          options: Options(
            headers: headers,
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final bytes = Uint8List.fromList(response.data!);

          // 验证下载的图片是否有效
          if (!_validateImageBytes(bytes)) {
            LogService.w('[DiskImageCacheService] Downloaded invalid image, ${attempt < maxRetries ? "retrying" : "giving up"}: $url');
            if (attempt < maxRetries) {
              await Future.delayed(const Duration(milliseconds: 500));
              continue;
            }
            return null;
          }

          // 保存到磁盘
          await file.writeAsBytes(bytes);
          LogService.d('[DiskImageCacheService] Cached image: $url (${bytes.length} bytes)');
          return file;
        }
      } catch (e) {
        if (attempt < maxRetries) {
          LogService.w('[DiskImageCacheService] Download failed, retrying ($attempt + 1/$maxRetries): $url');
          await Future.delayed(const Duration(milliseconds: 500));
        } else {
          LogService.e('[DiskImageCacheService] Failed to download image after ${maxRetries + 1} attempts: $url', e);
        }
      }
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
