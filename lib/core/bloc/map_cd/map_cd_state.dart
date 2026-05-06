import 'package:equatable/equatable.dart';
import '../../models/map_cd_models.dart';

/// 地图CD状态
class MapCdState extends Equatable {
  /// 地图CD数据缓存 (mapName -> MapCdInfo)
  final Map<String, MapCdInfo?> cdCache;

  /// 正在加载的地图集合
  final Set<String> loadingMaps;

  /// 错误信息缓存 (mapName -> errorMessage)
  final Map<String, String> errorCache;

  /// 缓存时间戳 (mapName -> DateTime)
  final Map<String, DateTime> cacheTimestamps;

  const MapCdState({
    this.cdCache = const {},
    this.loadingMaps = const {},
    this.errorCache = const {},
    this.cacheTimestamps = const {},
  });

  /// 缓存有效期（60秒，与服务端缓存一致）
  static const cacheDuration = Duration(seconds: 60);

  /// 获取地图CD信息
  MapCdInfo? getCd(String mapName) => cdCache[mapName];

  /// 是否正在加载
  bool isLoading(String mapName) => loadingMaps.contains(mapName);

  /// 获取错误信息
  String? getError(String mapName) => errorCache[mapName];

  /// 缓存是否有效
  bool isCacheValid(String mapName) {
    final timestamp = cacheTimestamps[mapName];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < cacheDuration;
  }

  /// 是否需要加载（缓存无效且未在加载中）
  bool shouldLoad(String mapName) {
    return !isCacheValid(mapName) && !isLoading(mapName);
  }

  MapCdState copyWith({
    Map<String, MapCdInfo?>? cdCache,
    Set<String>? loadingMaps,
    Map<String, String>? errorCache,
    Map<String, DateTime>? cacheTimestamps,
  }) {
    return MapCdState(
      cdCache: cdCache ?? this.cdCache,
      loadingMaps: loadingMaps ?? this.loadingMaps,
      errorCache: errorCache ?? this.errorCache,
      cacheTimestamps: cacheTimestamps ?? this.cacheTimestamps,
    );
  }

  @override
  List<Object?> get props => [cdCache, loadingMaps, errorCache, cacheTimestamps];
}
