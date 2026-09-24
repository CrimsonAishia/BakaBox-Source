import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../utils/app_directory_service.dart';
import '../utils/log_service.dart';

/// Lobby 素材图片缓存服务
///
/// 负责下载并持久化存储大厅所需的图片资源：
/// - 地图背景图
/// - 角色贴图
///
/// 存储策略：
/// - 图片存储在文件系统（Documents/BakaBox/cache/lobby_images/）
/// - 使用稳定的文件名（基于 URL 的 hash）
/// - 下载完成后立即缓存，支持后续直接加载
///
/// 加载策略：
/// - 优先从本地文件系统加载
/// - 本地不存在则下载后缓存
/// - 内存缓存提高频繁访问的效率
class LobbyImageCacheService {
  LobbyImageCacheService._();

  static final LobbyImageCacheService instance = LobbyImageCacheService._();

  static const String _cacheDirName = 'lobby_images';
  static const String _urlMappingFile = 'url_mapping.json';

  bool _initialized = false;
  Future<void>? _initFuture;

  /// 是否已初始化
  bool get isInitialized => _initialized;

  /// HTTP 客户端
  Dio? _dio;

  /// 最大内存缓存数量
  static const int _maxMemoryCacheCount = 20;

  /// 内存缓存：URL -> Uint8List (LRU 策略)
  final LinkedHashMap<String, Uint8List> _memoryCache =
      LinkedHashMap<String, Uint8List>();

  /// 并发请求合并：URL -> Future
  final Map<String, Future<Uint8List?>> _pendingTasks = {};

  /// 磁盘映射表：稳定 URL -> 文件名
  final Map<String, String> _diskMapping = {};

  /// 写入 LRU 缓存
  void _addMemoryCache(String key, Uint8List value) {
    _memoryCache.remove(key);
    _memoryCache[key] = value;
    if (_memoryCache.length > _maxMemoryCacheCount) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
  }

  /// 读取 LRU 缓存
  Uint8List? _getMemoryCache(String key) {
    if (_memoryCache.containsKey(key)) {
      final value = _memoryCache.remove(key)!;
      _memoryCache[key] = value; // 移到末尾，标记为最近使用
      return value;
    }
    return null;
  }

  /// 初始化服务
  Future<void> init() {
    if (_initialized) return Future.value();
    _initFuture ??= _doInit().whenComplete(() => _initFuture = null);
    return _initFuture!;
  }

  Future<void> _doInit() async {
    if (_initialized) return;

    try {
      _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      await _ensureCacheDir();
      await _loadDiskMapping();

      _initialized = true;
      if (LogService.enableLobbyDebugLog) {
        LogService.d('[LobbyImageCache] 初始化完成，缓存目录: ${_getCacheDir()}');
      }
    } catch (e) {
      LogService.e('[LobbyImageCache] 初始化失败', e);
    }
  }

  /// 确保缓存目录存在
  Future<void> _ensureCacheDir() async {
    final dir = Directory(_getCacheDir());
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// 获取缓存目录路径
  String _getCacheDir() {
    return '${AppDirectoryService.cachePath}${'/'}$_cacheDirName'.replaceAll(
      '/',
      Platform.pathSeparator,
    );
  }

  /// 从 URL 生成稳定的文件名
  String _urlToFileName(String url) {
    final hash = url.hashCode.abs().toRadixString(16);
    final extension = _getExtension(url);
    return 'img_$hash$extension';
  }

  /// 去掉 URL 后的鉴权参数，保留路径作为稳定 key
  String _stripAuthParams(String url) {
    final qIndex = url.indexOf('?');
    if (qIndex < 0) return url;
    return url.substring(0, qIndex);
  }

  /// 从 URL 获取文件扩展名
  String _getExtension(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '.png';

    final path = uri.path.toLowerCase();
    if (path.endsWith('.png')) return '.png';
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return '.jpg';
    if (path.endsWith('.gif')) return '.gif';
    if (path.endsWith('.webp')) return '.webp';
    if (path.endsWith('.bmp')) return '.bmp';

    return '.png';
  }

  /// 加载磁盘映射表
  Future<void> _loadDiskMapping() async {
    try {
      final file = File(
        '${_getCacheDir()}${'/'}$_urlMappingFile'.replaceAll(
          '/',
          Platform.pathSeparator,
        ),
      );
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          Uri.splitQueryString(content).map((k, v) => MapEntry(k, v)),
        );
        for (final entry in data.entries) {
          _diskMapping[entry.key] = entry.value;
        }
        if (LogService.enableLobbyDebugLog) {
          LogService.d('[LobbyImageCache] 加载了 ${_diskMapping.length} 个磁盘映射');
        }
      }
    } catch (e) {
      LogService.e('[LobbyImageCache] 加载映射表失败', e);
    }
  }

  /// 保存磁盘映射表
  Future<void> _saveDiskMapping() async {
    try {
      final file = File(
        '${_getCacheDir()}${'/'}$_urlMappingFile'.replaceAll(
          '/',
          Platform.pathSeparator,
        ),
      );
      final content = _diskMapping.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');
      await file.writeAsString(content);
    } catch (e) {
      LogService.e('[LobbyImageCache] 保存映射表失败', e);
    }
  }

  /// 预下载所有图片（用于进入大厅前缓存）
  ///
  /// [urls] 要下载的 URL 列表（支持带鉴权参数的原始 URL）
  /// [onProgress] 下载进度回调 (completed, total)
  ///
  /// 策略：
  /// - 如果 URL 已缓存（用稳定 URL 查找），跳过
  /// - 否则用原始 URL 下载，然后用稳定 URL 作为 key 存储
  Future<void> preDownloadImages(
    List<String> urls, {
    void Function(int completed, int total)? onProgress,
  }) async {
    if (!_initialized) await init();
    if (urls.isEmpty) return;

    // 去重（避免重复下载）
    final uniqueUrls = urls.toSet().toList();
    final urlsToDownload = <String>[];

    for (final url in uniqueUrls) {
      if (url.isEmpty) continue;
      // 用稳定 URL 检查是否已缓存
      if (await hasLocalCache(url)) continue;
      urlsToDownload.add(url);
    }

    if (urlsToDownload.isEmpty) {
      if (LogService.enableLobbyDebugLog) {
        LogService.d('[LobbyImageCache] 所有图片已缓存');
      }
      onProgress?.call(uniqueUrls.length, uniqueUrls.length);
      return;
    }

    if (LogService.enableLobbyDebugLog) {
      LogService.d('[LobbyImageCache] 需下载 ${urlsToDownload.length} 张图片');
    }

    int completed = 0;
    final total = urlsToDownload.length;

    for (final url in urlsToDownload) {
      final success = await downloadWithStableKey(url);
      if (success != null) {
        completed++;
      } else {
        // 下载失败，记录但不影响整体进度
        if (LogService.enableLobbyDebugLog) {
          LogService.d('[LobbyImageCache] 跳过失败图片: $url');
        }
      }
      onProgress?.call(completed, total);
    }

    if (LogService.enableLobbyDebugLog) {
      LogService.d(
        '[LobbyImageCache] 预下载完成: $completed/$total (失败 ${total - completed})',
      );
    }
  }

  /// 下载并缓存图片（兼容旧方法，统一转调 getImage 走并发合并逻辑）
  ///
  /// 返回缓存后的数据，如果失败返回 null
  Future<Uint8List?> downloadWithStableKey(String rawUrl) async {
    return getImage(rawUrl);
  }

  /// 下载并缓存图片（保留旧方法兼容）
  ///
  /// 返回缓存后的数据，如果失败返回 null
  Future<Uint8List?> downloadAndCache(String url) async {
    return getImage(url);
  }

  /// 检查本地缓存是否存在
  ///
  /// 会自动去掉 URL 的鉴权参数，用稳定 URL 查找
  Future<bool> hasLocalCache(String url) async {
    if (!_initialized) await init();
    if (url.isEmpty) return false;

    // 转换为稳定 URL
    final stableUrl = _stripAuthParams(url);

    // 内存缓存
    if (_memoryCache.containsKey(stableUrl)) return true;

    // 磁盘缓存
    final fileName = _diskMapping[stableUrl];
    if (fileName != null) {
      final file = File(
        '${_getCacheDir()}${'/'}$fileName'.replaceAll(
          '/',
          Platform.pathSeparator,
        ),
      );
      if (await file.exists()) return true;
    }

    return false;
  }

  /// 从磁盘加载图片
  Future<Uint8List?> _loadFromDisk(String stableUrl) async {
    final fileName = _diskMapping[stableUrl];
    if (fileName == null) return null;

    try {
      final file = File(
        '${_getCacheDir()}${'/'}$fileName'.replaceAll(
          '/',
          Platform.pathSeparator,
        ),
      );
      if (!await file.exists()) {
        // 文件不存在，移除映射
        _diskMapping.remove(stableUrl);
        return null;
      }

      return await file.readAsBytes();
    } catch (e) {
      LogService.e('[LobbyImageCache] 读取磁盘缓存失败: $stableUrl', e);
      return null;
    }
  }

  /// 保存图片到磁盘
  Future<void> _saveToDisk(String stableUrl, Uint8List data) async {
    final fileName = _urlToFileName(stableUrl);
    final file = File(
      '${_getCacheDir()}${'/'}$fileName'.replaceAll(
        '/',
        Platform.pathSeparator,
      ),
    );

    try {
      await file.writeAsBytes(data);
      _diskMapping[stableUrl] = fileName;
      await _saveDiskMapping();
      if (LogService.enableLobbyDebugLog) {
        LogService.d('[LobbyImageCache] 已缓存: $fileName');
      }
    } catch (e) {
      LogService.e('[LobbyImageCache] 保存磁盘缓存失败: $stableUrl', e);
    }
  }

  /// 获取图片数据（优先本地缓存）
  ///
  /// 如果本地有缓存直接返回，否则下载后返回。
  /// 会自动去掉 URL 的鉴权参数，用稳定 URL 查找和存储。
  Future<Uint8List?> getImage(String url) async {
    if (!_initialized) await init();
    if (url.isEmpty) return null;

    // 转换为稳定 URL
    final stableUrl = _stripAuthParams(url);

    // 检查是否有并发加载任务
    if (_pendingTasks.containsKey(stableUrl)) {
      return await _pendingTasks[stableUrl];
    }

    // 创建新加载任务
    final task = _executeGetImageTask(stableUrl, url);
    _pendingTasks[stableUrl] = task;

    try {
      return await task;
    } finally {
      _pendingTasks.remove(stableUrl);
    }
  }

  /// 执行获取图片的具体逻辑（缓存或下载）
  Future<Uint8List?> _executeGetImageTask(
    String stableUrl,
    String rawUrl,
  ) async {
    // 内存缓存
    final cached = _getMemoryCache(stableUrl);
    if (cached != null) {
      return cached;
    }

    // 磁盘缓存
    final diskData = await _loadFromDisk(stableUrl);
    if (diskData != null) {
      _addMemoryCache(stableUrl, diskData);
      return diskData;
    }

    // 下载
    return _downloadImage(stableUrl, rawUrl);
  }

  /// 执行真实的网络下载与本地存储
  Future<Uint8List?> _downloadImage(String stableUrl, String rawUrl) async {
    if (LogService.enableLobbyDebugLog) {
      LogService.d('[LobbyImageCache] 下载图片: $rawUrl -> 稳定URL: $stableUrl');
    }
    try {
      final response = await _dio!.get<List<int>>(
        rawUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data == null) {
        LogService.e('[LobbyImageCache] 下载数据为空: $rawUrl');
        return null;
      }

      final bytes = Uint8List.fromList(response.data!);

      // 用稳定 URL 保存到磁盘
      await _saveToDisk(stableUrl, bytes);

      // 放入 LRU 内存缓存
      _addMemoryCache(stableUrl, bytes);

      if (LogService.enableLobbyDebugLog) {
        LogService.d('[LobbyImageCache] 下载并缓存成功: $stableUrl');
      }
      return bytes;
    } catch (e) {
      LogService.e('[LobbyImageCache] 下载失败: $rawUrl', e);
      return null;
    }
  }

  /// 解码图片为 ui.Image
  ///
  /// 可以传入 [targetWidth] 和 [targetHeight] 限制解码后的内存占用
  Future<ui.Image?> getDecodedImage(
    String url, {
    int? targetWidth,
    int? targetHeight,
  }) async {
    final bytes = await getImage(url);
    if (bytes == null) return null;

    try {
      if (targetWidth != null || targetHeight != null) {
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: targetWidth,
          targetHeight: targetHeight,
          allowUpscaling: false, // 像素风游戏：禁止放大图片，防止低像素原图被双线性模糊插值
        );
        final frame = await codec.getNextFrame();
        return frame.image;
      } else {
        return await decodeImageFromList(bytes) as ui.Image?;
      }
    } catch (e) {
      LogService.e('[LobbyImageCache] 解码图片失败: $url', e);
      return null;
    }
  }

  /// 清除所有图片缓存
  Future<void> clearAll() async {
    // 清除内存缓存
    _memoryCache.clear();
    _pendingTasks.clear();

    // 清除磁盘缓存
    try {
      final dir = Directory(_getCacheDir());
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await _ensureCacheDir();
    } catch (e) {
      LogService.e('[LobbyImageCache] 清除磁盘缓存失败', e);
    }

    // 清除映射表
    _diskMapping.clear();
    await _saveDiskMapping();

    LogService.i('[LobbyImageCache] 已清除所有图片缓存');
  }

  /// 仅清除内存缓存（不清除磁盘文件缓存）
  /// 用于在应用切入后台或页面被回收时释放内存
  void clearMemoryCache() {
    _memoryCache.clear();
    if (LogService.enableLobbyDebugLog) {
      LogService.d('[LobbyImageCache] 已清理内存缓存');
    }
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    return {
      'memoryCacheCount': _memoryCache.length,
      'pendingTasksCount': _pendingTasks.length,
      'diskCacheCount': _diskMapping.length,
      'cacheDir': _getCacheDir(),
    };
  }

  /// 预热缓存：由于已移除内存缓存，此方法仅保留空实现以避免严重内存泄漏
  Future<void> warmupMemoryCache() async {
    if (LogService.enableLobbyDebugLog) {
      LogService.d('[LobbyImageCache] 预热内存缓存逻辑已移除，由引擎自行管理');
    }
  }
}
