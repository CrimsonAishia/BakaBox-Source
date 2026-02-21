import 'package:equatable/equatable.dart';

/// 地图订阅模型
class MapSubscription extends Equatable {
  /// 地图代码名（如 de_dust2）
  final String mapName;

  /// 地图中文名（如 炙热沙城）
  final String mapLabel;

  /// 地图背景图 URL
  final String? mapBackground;

  /// 监控的分类名列表（空=全部 API 分类）
  final List<String> categoryNames;

  /// 是否启用 TTS 语音播报
  final bool ttsEnabled;

  /// 创建时间
  final DateTime createdAt;

  const MapSubscription({
    required this.mapName,
    required this.mapLabel,
    this.mapBackground,
    this.categoryNames = const [],
    this.ttsEnabled = false,
    required this.createdAt,
  });

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
      ttsEnabled: json['ttsEnabled'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// 转为 JSON
  Map<String, dynamic> toJson() => {
    'mapName': mapName,
    'mapLabel': mapLabel,
    'mapBackground': mapBackground,
    'categoryNames': categoryNames,
    'ttsEnabled': ttsEnabled,
    'createdAt': createdAt.toIso8601String(),
  };

  /// 复制并修改
  MapSubscription copyWith({
    String? mapName,
    String? mapLabel,
    String? mapBackground,
    List<String>? categoryNames,
    bool? ttsEnabled,
    DateTime? createdAt,
  }) {
    return MapSubscription(
      mapName: mapName ?? this.mapName,
      mapLabel: mapLabel ?? this.mapLabel,
      mapBackground: mapBackground ?? this.mapBackground,
      categoryNames: categoryNames ?? this.categoryNames,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 显示名称（中文名 + 英文名）
  String get displayName =>
      mapLabel.isNotEmpty ? '$mapLabel ($mapName)' : mapName;

  /// 是否监控全部分类
  bool get isAllCategories => categoryNames.isEmpty;

  @override
  List<Object?> get props => [
    mapName,
    mapLabel,
    mapBackground,
    categoryNames,
    ttsEnabled,
    createdAt,
  ];
}
