import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../models/lobby_models.dart';
import '../utils/log_service.dart';
import 'lobby_image_cache_service.dart';

/// 地图加载状态
enum MapLoadStatus {
  /// 地图未加载
  unloaded,

  /// 正在加载
  loading,

  /// 已加载完成
  loaded,

  /// 加载失败
  error,
}

/// 地图加载状态信息
class MapLoadState {
  final String mapId;
  final MapLoadStatus status;
  final double progress;
  final String? errorMessage;

  const MapLoadState({
    required this.mapId,
    required this.status,
    this.progress = 0.0,
    this.errorMessage,
  });

  bool get isReady => status == MapLoadStatus.loaded;
  bool get isLoading => status == MapLoadStatus.loading;
  bool get isError => status == MapLoadStatus.error;

  MapLoadState copyWith({
    String? mapId,
    MapLoadStatus? status,
    double? progress,
    String? errorMessage,
  }) {
    return MapLoadState(
      mapId: mapId ?? this.mapId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() =>
      'MapLoadState(mapId: $mapId, status: $status, progress: $progress)';
}

/// Lobby 地图加载状态管理服务
///
/// 负责：
/// - 地图背景图片预加载
/// - 加载状态追踪（loading/ready/error）
/// - 提供加载状态流供 UI 订阅
///
/// 使用方式：
/// ```dart
/// // 监听地图加载状态
/// LobbyMapLoaderService.instance.getStateStream(mapId).listen((state) {
///   if (state.isReady) {
///     // 地图已准备好
///   }
/// });
///
/// // 预加载地图
/// await LobbyMapLoaderService.instance.preloadMap(mapConfig);
///
/// // 等待地图加载完成
/// await LobbyMapLoaderService.instance.waitForMapReady(mapId);
/// ```
class LobbyMapLoaderService {
  LobbyMapLoaderService._();

  static final LobbyMapLoaderService instance = LobbyMapLoaderService._();

  static const Duration _mapLoadTimeout = Duration(seconds: 10);

  /// 地图加载状态缓存：mapId -> MapLoadState
  final Map<String, MapLoadState> _stateCache = {};

  /// 状态流缓存：mapId -> BehaviorSubject
  final Map<String, BehaviorSubject<MapLoadState>> _stateSubjects = {};

  /// 正在加载的地图
  final Set<String> _loadingMaps = {};

  /// 获取地图加载状态流
  Stream<MapLoadState> getStateStream(String mapId) {
    return _getOrCreateSubject(mapId).stream;
  }

  /// 获取当前地图加载状态
  MapLoadState? getCurrentState(String mapId) {
    return _stateCache[mapId];
  }

  /// 检查地图是否已加载
  bool isMapReady(String mapId) {
    final state = _stateCache[mapId];
    return state != null && state.isReady;
  }

  /// 预加载地图
  ///
  /// 如果地图已在加载中或已加载，跳过。
  /// 返回加载是否成功。
  Future<bool> preloadMap(LobbyMapConfig mapConfig) async {
    final mapId = mapConfig.mapId;

    // 如果已加载，跳过
    if (isMapReady(mapId)) {
      LogService.d('[LobbyMapLoader] 地图已就绪: $mapId');
      return true;
    }

    // 如果正在加载，等待完成
    if (_loadingMaps.contains(mapId)) {
      LogService.d('[LobbyMapLoader] 地图正在加载中: $mapId，等待完成');
      return await waitForMapReady(mapId)
          .then((_) => true)
          .timeout(
            _mapLoadTimeout,
            onTimeout: () {
              LogService.w('[LobbyMapLoader] 等待地图加载超时: $mapId');
              return false;
            },
          );
    }

    return _doLoadMap(mapConfig);
  }

  /// 执行地图加载
  Future<bool> _doLoadMap(LobbyMapConfig mapConfig) async {
    final mapId = mapConfig.mapId;
    final backgroundUrl = mapConfig.backgroundUrl;

    _loadingMaps.add(mapId);
    _updateState(
      MapLoadState(mapId: mapId, status: MapLoadStatus.loading, progress: 0.0),
    );

    try {
      LogService.d(
        '[LobbyMapLoader] 开始加载地图: $mapId, backgroundUrl: $backgroundUrl',
      );

      // 如果没有背景 URL，认为地图配置有效但无需加载图片
      if (backgroundUrl == null || backgroundUrl.isEmpty) {
        _updateState(
          MapLoadState(
            mapId: mapId,
            status: MapLoadStatus.loaded,
            progress: 1.0,
          ),
        );
        LogService.d('[LobbyMapLoader] 地图无背景图，标记为已加载: $mapId');
        return true;
      }

      // 更新进度
      _updateState(
        MapLoadState(
          mapId: mapId,
          status: MapLoadStatus.loading,
          progress: 0.2,
        ),
      );

      // 下载图片
      final bytes = await LobbyImageCacheService.instance.downloadWithStableKey(
        backgroundUrl,
      );

      _updateState(
        MapLoadState(
          mapId: mapId,
          status: MapLoadStatus.loading,
          progress: 0.8,
        ),
      );

      if (bytes != null) {
        // 解码图片确保可用（用于验证图片有效）
        await LobbyImageCacheService.instance.getDecodedImage(backgroundUrl);

        _updateState(
          MapLoadState(
            mapId: mapId,
            status: MapLoadStatus.loaded,
            progress: 1.0,
          ),
        );

        LogService.d(
          '[LobbyMapLoader] 地图加载成功: $mapId, size: ${bytes.length} bytes',
        );
        return true;
      } else {
        // 下载失败但仍标记为已加载（允许显示默认背景）
        _updateState(
          MapLoadState(
            mapId: mapId,
            status: MapLoadStatus.loaded,
            progress: 1.0,
            errorMessage: '图片下载失败',
          ),
        );
        LogService.w('[LobbyMapLoader] 地图图片下载失败: $mapId，使用默认背景');
        return true;
      }
    } catch (e, stack) {
      LogService.e('[LobbyMapLoader] 地图加载失败: $mapId', e, stack);
      _updateState(
        MapLoadState(
          mapId: mapId,
          status: MapLoadStatus.error,
          errorMessage: e.toString(),
        ),
      );
      return false;
    } finally {
      _loadingMaps.remove(mapId);
    }
  }

  /// 等待地图加载完成
  ///
  /// 如果地图已加载，立即返回。
  /// 如果地图正在加载，等待加载完成。
  /// 如果超时，返回 false。
  Future<bool> waitForMapReady(String mapId, {Duration? timeout}) async {
    final currentState = _stateCache[mapId];
    if (currentState != null && currentState.isReady) {
      return true;
    }

    final timeoutDuration = timeout ?? _mapLoadTimeout;

    // 等待状态变化
    final subject = _getOrCreateSubject(mapId);

    try {
      await subject
          .firstWhere((state) => state.isReady || state.isError)
          .timeout(
            timeoutDuration,
            onTimeout: () {
              LogService.w('[LobbyMapLoader] 等待地图加载超时: $mapId');
              return MapLoadState(
                mapId: mapId,
                status: MapLoadStatus.error,
                errorMessage: '加载超时',
              );
            },
          );

      final finalState = _stateCache[mapId];
      return finalState?.isReady ?? false;
    } catch (e) {
      LogService.e('[LobbyMapLoader] 等待地图加载异常: $mapId', e);
      return false;
    }
  }

  /// 更新状态并通知所有监听器
  void _updateState(MapLoadState newState) {
    _stateCache[newState.mapId] = newState;

    final subject = _stateSubjects[newState.mapId];
    if (subject != null && !subject.isClosed) {
      subject.add(newState);
    }
  }

  /// 获取或创建状态流
  BehaviorSubject<MapLoadState> _getOrCreateSubject(String mapId) {
    var subject = _stateSubjects[mapId];
    if (subject == null || subject.isClosed) {
      subject = BehaviorSubject<MapLoadState>.seeded(
        _stateCache[mapId] ??
            MapLoadState(mapId: mapId, status: MapLoadStatus.unloaded),
      );
      _stateSubjects[mapId] = subject;
    }
    return subject;
  }

  /// 清除指定地图的缓存状态
  void clearState(String mapId) {
    _stateCache.remove(mapId);

    // 关闭并移除 BehaviorSubject，防止内存泄漏
    final subject = _stateSubjects.remove(mapId);
    if (subject != null && !subject.isClosed) {
      subject.close();
    }
  }

  /// 清除所有地图缓存状态
  void clearAll() {
    for (final mapId in _stateCache.keys.toList()) {
      clearState(mapId);
    }
  }

  /// 获取所有已加载的地图 ID
  List<String> get loadedMapIds {
    return _stateCache.entries
        .where((e) => e.value.isReady)
        .map((e) => e.key)
        .toList();
  }

  /// 获取正在加载的地图 ID
  List<String> get loadingMapIds {
    return _stateCache.entries
        .where((e) => e.value.isLoading)
        .map((e) => e.key)
        .toList();
  }
}
