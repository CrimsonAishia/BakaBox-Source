/// 地图配置响应模型
///
/// 结构：
///   Response
///     └── Category
///           └── Entity (实体：如「魔界妖精」「AWP」；匿名实体 name == "" 表示分类级属性)
///                 └── Property (属性：key/value/unit/originalValue/description)
class MapConfigResponse {
  final List<MapConfigCategory> categories;

  MapConfigResponse({required this.categories});

  factory MapConfigResponse.fromJson(Map<String, dynamic> json) {
    return MapConfigResponse(
      categories: (json['categories'] as List?)
              ?.map((e) =>
                  MapConfigCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class MapConfigCategory {
  final int categoryId;
  final String category;
  final List<MapConfigEntity> entities;

  MapConfigCategory({
    required this.categoryId,
    required this.category,
    required this.entities,
  });

  factory MapConfigCategory.fromJson(Map<String, dynamic> json) {
    return MapConfigCategory(
      categoryId: json['categoryId'] as int? ?? 0,
      category: json['category'] as String? ?? '',
      entities: (json['entities'] as List?)
              ?.map((e) =>
                  MapConfigEntity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <MapConfigEntity>[],
    );
  }
}

class MapConfigEntity {
  /// 实体名。空字符串表示分类级匿名实体（如「通用」下的散装属性）。
  final String name;

  /// 是否启用；false 时 UI 会灰化整块。
  final bool enabled;

  final List<MapConfigProperty> attributes;

  MapConfigEntity({
    required this.name,
    required this.enabled,
    required this.attributes,
  });

  bool get isAnonymous => name.isEmpty;

  factory MapConfigEntity.fromJson(Map<String, dynamic> json) {
    return MapConfigEntity(
      name: json['name'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      attributes: (json['attributes'] as List?)
              ?.map((e) =>
                  MapConfigProperty.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <MapConfigProperty>[],
    );
  }
}

/// 单条属性
class MapConfigProperty {
  final String key;
  final String value;
  final String? unit;
  final String? originalValue;
  final String? description;

  MapConfigProperty({
    required this.key,
    required this.value,
    this.unit,
    this.originalValue,
    this.description,
  });

  factory MapConfigProperty.fromJson(Map<String, dynamic> json) {
    return MapConfigProperty(
      key: json['key'] as String? ?? '',
      value: json['value'] as String? ?? '',
      unit: json['unit'] as String?,
      originalValue: json['originalValue'] as String?,
      description: json['description'] as String?,
    );
  }
}
