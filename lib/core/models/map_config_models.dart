class MapConfigCategory {
  final int categoryId;
  final String category;
  final List<MapConfigProperty> properties;

  MapConfigCategory({
    required this.categoryId,
    required this.category,
    required this.properties,
  });

  factory MapConfigCategory.fromJson(Map<String, dynamic> json) {
    return MapConfigCategory(
      categoryId: json['categoryId'] as int? ?? 0,
      category: json['category'] as String? ?? '',
      properties: (json['properties'] as List?)
              ?.map((e) => MapConfigProperty.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class MapConfigProperty {
  final String key;
  final String value;
  final String? originalValue;
  final String? description;

  MapConfigProperty({
    required this.key,
    required this.value,
    this.originalValue,
    this.description,
  });

  factory MapConfigProperty.fromJson(Map<String, dynamic> json) {
    return MapConfigProperty(
      key: json['key'] as String? ?? '',
      value: json['value'] as String? ?? '',
      originalValue: json['originalValue'] as String?,
      description: json['description'] as String?,
    );
  }
}

class MapConfigResponse {
  final List<MapConfigCategory> categories;

  MapConfigResponse({required this.categories});

  factory MapConfigResponse.fromJson(Map<String, dynamic> json) {
    return MapConfigResponse(
      categories: (json['categories'] as List?)
              ?.map((e) => MapConfigCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
