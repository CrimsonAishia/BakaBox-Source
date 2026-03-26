import 'dart:async';
import '../api/file_upload_api.dart';
import '../utils/log_service.dart';

/// 图片URL缓存项
class _CacheEntry {
  final String url;
  final DateTime expireAt;

  _CacheEntry(this.url, this.expireAt);

  bool get isExpired => DateTime.now().isAfter(expireAt);
}

/// 图片URL服务
///
/// 管理 fileId 到签名URL的映射
/// - 缓存URL，避免重复请求
/// - 自动处理URL过期（提前10分钟刷新）
///
/// 使用方式：
/// ```dart
/// // 存储时使用 fileId 格式: "file:123"
/// final imageRef = "file:$fileId";
///
/// // 显示时获取签名URL
/// final signedUrl = await ImageUrlService.instance.getSignedUrl(imageRef);
/// ```
class ImageUrlService {
  static final ImageUrlService instance = ImageUrlService._();
  ImageUrlService._();

  final FileUploadApi _api = FileUploadApi();

  /// URL缓存 (fileId -> CacheEntry)
  final Map<int, _CacheEntry> _cache = {};

  /// 缓存有效期（50分钟，比实际1小时提前10分钟）
  static const Duration _cacheDuration = Duration(minutes: 50);

  /// 判断是否是 fileId 引用格式
  static bool isFileIdRef(String url) {
    return url.startsWith('file:');
  }

  /// 从引用格式提取 fileId
  static int? parseFileId(String ref) {
    if (!isFileIdRef(ref)) return null;
    return int.tryParse(ref.substring(5));
  }

  /// 创建 fileId 引用格式
  static String createFileIdRef(int fileId) {
    return 'file:$fileId';
  }

  /// 获取签名URL
  ///
  /// [ref] 可以是：
  /// - fileId引用格式: "file:123"
  /// - 普通URL: 直接返回
  Future<String> getSignedUrl(String ref) async {
    // 如果不是 fileId 引用，直接返回
    if (!isFileIdRef(ref)) {
      return ref;
    }

    final fileId = parseFileId(ref);
    if (fileId == null) {
      LogService.w('无效的 fileId 引用: $ref');
      return ref;
    }

    return await getSignedUrlById(fileId);
  }

  /// 通过 fileId 获取签名URL
  Future<String> getSignedUrlById(int fileId) async {
    // 检查缓存
    final cached = _cache[fileId];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    // 请求新的签名URL
    try {
      final response = await _api.getFileUrl(fileId);
      final url = response.url;

      // 缓存
      _cache[fileId] = _CacheEntry(url, DateTime.now().add(_cacheDuration));

      return url;
    } catch (e) {
      LogService.e('获取签名URL失败: $fileId', e);
      // 如果有过期的缓存，仍然返回（可能还能用）
      if (cached != null) {
        return cached.url;
      }
      rethrow;
    }
  }

  /// 批量获取签名URL
  Future<Map<String, String>> getSignedUrls(List<String> refs) async {
    final result = <String, String>{};

    for (final ref in refs) {
      try {
        result[ref] = await getSignedUrl(ref);
      } catch (e) {
        // 失败的保持原值
        result[ref] = ref;
      }
    }

    return result;
  }

  /// 预加载URL（不等待结果）
  void preload(List<String> refs) {
    for (final ref in refs) {
      if (isFileIdRef(ref)) {
        getSignedUrl(ref).catchError((_) => ref);
      }
    }
  }

  /// 清除缓存
  void clearCache() {
    _cache.clear();
  }

  /// 清除过期缓存
  void clearExpiredCache() {
    _cache.removeWhere((_, entry) => entry.isExpired);
  }
}
