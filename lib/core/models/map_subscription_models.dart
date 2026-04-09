import 'package:equatable/equatable.dart';

/// 地图订阅模型
class MapSubscription extends Equatable {
  /// 地图代码名（如 de_dust2）
  final String mapName;

  /// 地图中文名（如 炙热沙城）
  final String mapLabel;

  /// 地图背景图 URL
  final String? mapBackground;

  /// 监控的分类名列表（空=继承全局设置）
  final List<String> categoryNames;

  /// 指定要监控的服务器地址列表（空=继承全局设置）
  /// 格式: "IP:端口"，如 "123.45.67.89:27015"
  final List<String> serverAddresses;

  /// 创建时间
  final DateTime createdAt;

  /// 地图信息缓存时间（用于判断是否过期需要刷新）
  final DateTime? cachedAt;

  /// 缓存有效期（默认1小时）
  static const Duration cacheValidityDuration = Duration(hours: 1);

  const MapSubscription({
    required this.mapName,
    required this.mapLabel,
    this.mapBackground,
    this.categoryNames = const [],
    this.serverAddresses = const [],
    required this.createdAt,
    this.cachedAt,
  });

  /// 是否缓存已过期（需要刷新地图信息）
  bool get isCacheExpired =>
      cachedAt == null ||
      DateTime.now().difference(cachedAt!) > cacheValidityDuration;

  /// 从 JSON 创建
  factory MapSubscription.fromJson(Map<String, dynamic> json) {
    return MapSubscription(
      mapName: json['mapName'] as String,
      mapLabel: json['mapLabel'] as String? ?? '',
      mapBackground: json['mapBackground'] as String?,
      categoryNames:
          (json['categoryNames'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      serverAddresses:
          (json['serverAddresses'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      cachedAt: json['cachedAt'] != null
          ? DateTime.tryParse(json['cachedAt'] as String)
          : null,
    );
  }

  /// 转为 JSON
  Map<String, dynamic> toJson() => {
        'mapName': mapName,
        'mapLabel': mapLabel,
        'mapBackground': mapBackground,
        'categoryNames': categoryNames,
        'serverAddresses': serverAddresses,
        'createdAt': createdAt.toIso8601String(),
        'cachedAt': cachedAt?.toIso8601String(),
      };

  /// 复制并修改
  MapSubscription copyWith({
    String? mapName,
    String? mapLabel,
    String? mapBackground,
    List<String>? categoryNames,
    List<String>? serverAddresses,
    DateTime? createdAt,
    DateTime? cachedAt,
    bool clearCachedAt = false,
  }) {
    return MapSubscription(
      mapName: mapName ?? this.mapName,
      mapLabel: mapLabel ?? this.mapLabel,
      mapBackground: mapBackground ?? this.mapBackground,
      categoryNames: categoryNames ?? this.categoryNames,
      serverAddresses: serverAddresses ?? this.serverAddresses,
      createdAt: createdAt ?? this.createdAt,
      cachedAt: clearCachedAt ? null : (cachedAt ?? this.cachedAt),
    );
  }

  /// 显示名称（中文名 + 英文名）
  String get displayName =>
      mapLabel.isNotEmpty ? '$mapLabel ($mapName)' : mapName;

  /// 是否监控全部分类（空=继承全局设置）
  bool get isAllCategories => categoryNames.isEmpty;

  /// 是否监控全部服务器（空=继承全局设置）
  bool get isAllServers => serverAddresses.isEmpty;

  /// 获取分类范围描述
  String get categoryScopeText =>
      isAllCategories ? '全部分类' : '${categoryNames.length}个分类';

  /// 获取服务器范围描述
  String get serverScopeText =>
      isAllServers ? '全部服务器' : '${serverAddresses.length}个服务器';

  @override
  List<Object?> get props => [
        mapName,
        mapLabel,
        mapBackground,
        categoryNames,
        serverAddresses,
        createdAt,
        cachedAt,
      ];
}
