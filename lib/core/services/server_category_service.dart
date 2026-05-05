import '../api/api.dart';
import '../constants/fallback_data.dart';
import '../models/server_models.dart';
import '../utils/cache_service.dart';
import '../utils/log_service.dart';

/// 服务器分类列表服务（单例）
///
/// 统一管理 API 分类的获取逻辑，解决多处同时调用导致重复请求的问题：
/// - 防重入：同一时刻只有一个请求在飞，后续调用等待同一个 Future
/// - 内存缓存：本次运行中上一次成功的结果，网络失败时直接回退
/// - 持久化缓存：跨启动的本地缓存
/// - 硬编码兜底：所有来源均失败时的最后防线
class ServerCategoryService {
  ServerCategoryService._();
  static final ServerCategoryService instance = ServerCategoryService._();

  /// 内存缓存：本次运行中最后一次成功获取的 API 分类列表
  List<ServerCategory>? _lastSuccessfulList;

  /// 正在进行中的请求（防重入）
  Future<List<ServerCategory>>? _inFlightRequest;

  /// 获取 API 分类列表（使用缓存）
  ///
  /// 内存缓存有效时直接返回，避免重复请求（如启动时多处先后调用）。
  /// 多处并发调用时共享同一个请求 Future。
  Future<List<ServerCategory>> getApiCategories() {
    // 内存缓存有效时直接返回，避免重复请求
    if (_lastSuccessfulList != null && _lastSuccessfulList!.isNotEmpty) {
      return Future.value(_lastSuccessfulList);
    }
    // 如果已有请求在飞，直接复用
    _inFlightRequest ??= _fetchApiCategories().whenComplete(() {
      _inFlightRequest = null;
    });
    return _inFlightRequest!;
  }

  /// 强制从 API 重新获取分类列表（忽略内存缓存）
  ///
  /// 用于定时检测是否有更新，不受内存缓存影响。
  Future<List<ServerCategory>> fetchFresh() {
    // 即使有内存缓存也强制发请求，但仍然防并发
    _inFlightRequest ??= _fetchApiCategories().whenComplete(() {
      _inFlightRequest = null;
    });
    return _inFlightRequest!;
  }

  Future<List<ServerCategory>> _fetchApiCategories() async {
    // 1. 主 API（最多重试 3 次，指数退避，防止网络抖动导致获取失败）
    const maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        LogService.d('[ServerCategoryService] 从主 API 获取分类列表（第 $attempt 次）');
        final result = await Api.get<List<ServerCategory>>(
          '/api/stub',
          fromJson: (json) {
            final data = json as Map<String, dynamic>;
            final servers = data['servers'] as List?;
            if (servers == null) return <ServerCategory>[];
            return _parseList(servers);
          },
        );

        if (result != null && result.isNotEmpty) {
          LogService.i('[ServerCategoryService] 主 API 获取成功（第 $attempt 次），共 ${result.length} 个分类');
          _lastSuccessfulList = result;
          await CacheService.cacheServerList(result);
          return result;
        }
      } catch (e) {
        LogService.w('[ServerCategoryService] 主 API 第 $attempt 次请求失败: $e');
        if (attempt < maxAttempts) {
          final delay = Duration(seconds: attempt); // 1s, 2s
          LogService.d('[ServerCategoryService] ${delay.inSeconds}s 后重试...');
          await Future.delayed(delay);
        }
      }
    }
    LogService.w('[ServerCategoryService] 主 API 重试 $maxAttempts 次均失败，降级到缓存');

    // 2. 本次运行内存缓存
    if (_lastSuccessfulList != null && _lastSuccessfulList!.isNotEmpty) {
      LogService.i('[ServerCategoryService] 使用内存缓存，共 ${_lastSuccessfulList!.length} 个分类');
      return _lastSuccessfulList!;
    }

    // 3. 本地持久化缓存
    try {
      final cached = await CacheService.getCachedServerList();
      if (cached != null && cached.isNotEmpty) {
        LogService.i('[ServerCategoryService] 使用持久化缓存，共 ${cached.length} 个分类');
        _lastSuccessfulList = cached;
        return cached;
      }
    } catch (e) {
      LogService.w('[ServerCategoryService] 读取持久化缓存失败: $e');
    }

    // 4. 硬编码兜底
    LogService.w('[ServerCategoryService] 使用硬编码兜底数据');
    return FallbackData.defaultServerList;
  }

  List<ServerCategory> _parseList(List json) {
    return json
        .where((item) => item != null)
        .map((item) {
          try {
            return ServerCategory.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            LogService.e('[ServerCategoryService] 解析分类失败: $e', e);
            return null;
          }
        })
        .whereType<ServerCategory>()
        .toList();
  }

  /// 清除内存缓存（测试用）
  void clearMemoryCache() {
    _lastSuccessfulList = null;
  }
}
