import '../constants/map_warmup_config.dart';
import '../models/server_models.dart';

/// 地图运行时间工具类
/// 提供地图运行时间的格式化和显示功能
class MapRuntimeUtils {
  MapRuntimeUtils._();

  /// 获取地图的热身时间配置
  /// [mapName] 地图名称
  /// 返回热身时间（秒），如果地图不需要热身则返回 null
  static int? getWarmupDuration(String? mapName) {
    if (mapName == null || mapName.isEmpty) return null;

    final lowerMapName = mapName.toLowerCase();
    for (final config in MapWarmupConstants.configs) {
      if (lowerMapName.startsWith(config.prefix)) {
        return config.warmupSeconds;
      }
    }
    return null; // 不匹配任何前缀，不需要热身
  }

  /// 判断地图是否支持热身显示
  static bool supportsWarmup(String? mapName) {
    return getWarmupDuration(mapName) != null;
  }

  /// 格式化地图运行时间
  static String formatRuntime(int seconds) {
    if (seconds <= 0) return '0分';

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours >= 99) return '$hours时';
    if (hours > 0) return '$hours时$minutes分';
    if (minutes > 0) return '$minutes分';
    return '1分';
  }

  /// 计算实际运行时间（基于时间戳）
  /// [mapRuntime] 原始运行时间数据
  /// [fetchedAt] 获取时间戳（毫秒）
  /// 返回当前实际运行时间（秒）
  static int calculateCurrentRuntime(
    MapRuntimeData? mapRuntime,
    int? fetchedAt,
  ) {
    if (mapRuntime == null || fetchedAt == null) return 0;

    final elapsed = (DateTime.now().millisecondsSinceEpoch - fetchedAt) ~/ 1000;
    return mapRuntime.currentRuntime + elapsed;
  }

  /// 获取运行时间显示文本
  static String getRuntimeDisplay({
    MapRuntimeData? mapRuntime,
    int? fetchedAt,
    bool isLoading = false,
    bool hasError = false,
  }) {
    if (hasError) return '获取失败';
    if (mapRuntime == null) {
      if (isLoading) return '';
      return '加载中...';
    }

    final currentRuntime = calculateCurrentRuntime(mapRuntime, fetchedAt);
    if (currentRuntime <= 0) return '0秒';
    return formatRuntime(currentRuntime);
  }

  /// 判断服务器是否处于热身状态
  static bool isWarmingUp(
    MapRuntimeData? mapRuntime, {
    int? fetchedAt,
    String? mapName,
    bool hasError = false,
  }) {
    if (mapRuntime == null || hasError) return false;

    final warmupDuration = getWarmupDuration(mapName);
    if (warmupDuration == null) return false;

    final currentRuntime = fetchedAt != null
        ? calculateCurrentRuntime(mapRuntime, fetchedAt)
        : mapRuntime.currentRuntime;

    return currentRuntime <= warmupDuration;
  }

  /// 获取剩余热身时间（秒）
  static int getWarmupTimeRemaining(
    MapRuntimeData? mapRuntime, {
    int? fetchedAt,
    String? mapName,
  }) {
    if (mapRuntime == null) return 0;

    final warmupDuration = getWarmupDuration(mapName);
    if (warmupDuration == null) return 0;

    final currentRuntime = fetchedAt != null
        ? calculateCurrentRuntime(mapRuntime, fetchedAt)
        : mapRuntime.currentRuntime;

    if (currentRuntime > warmupDuration) return 0;
    return (warmupDuration - currentRuntime).clamp(0, warmupDuration);
  }

  /// 获取热身状态显示文本
  static String getWarmupDisplay(
    MapRuntimeData? mapRuntime, {
    int? fetchedAt,
    String? mapName,
  }) {
    final remaining = getWarmupTimeRemaining(
      mapRuntime,
      fetchedAt: fetchedAt,
      mapName: mapName,
    );
    if (remaining <= 0) return '';
    return '热身 $remaining秒';
  }

  /// 判断是否应该获取地图运行时间
  static bool shouldFetchMapRuntime(ExtendedServerItem server) {
    final hasMap =
        server.serverData?.map != null && server.serverData!.map!.isNotEmpty;
    final noRuntime = server.mapRuntime == null;
    final noError = !server.mapRuntimeError;
    final notFetching = !server.mapRuntimeFetching;
    final notLoading = !server.isLoading;

    return hasMap && noRuntime && noError && notFetching && notLoading;
  }
}
