/// 地图热身配置
class MapWarmupConfig {
  /// 地图前缀
  final String prefix;
  /// 热身时间（秒）
  final int warmupSeconds;

  const MapWarmupConfig({required this.prefix, required this.warmupSeconds});
}

/// 地图热身配置常量
class MapWarmupConstants {
  MapWarmupConstants._();

  /// 地图热身配置表
  /// 根据地图前缀配置不同的热身时间
  static const List<MapWarmupConfig> configs = [
    MapWarmupConfig(prefix: 'ze_', warmupSeconds: 120),  // 僵尸逃跑
    MapWarmupConfig(prefix: 'zm_', warmupSeconds: 120),  // 僵尸模式
    // 可扩展更多配置
    // MapWarmupConfig(prefix: 'surf_', warmupSeconds: 60),
    // MapWarmupConfig(prefix: 'bhop_', warmupSeconds: 30),
  ];

  /// 默认热身时间（秒）
  static const int defaultWarmupSeconds = 120;
}
