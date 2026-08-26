import 'package:equatable/equatable.dart';

/// 标签分类模型
class MapTagCategory extends Equatable {
  final int id;
  final String name;
  final int sortIndex;

  const MapTagCategory({
    required this.id,
    required this.name,
    required this.sortIndex,
  });

  factory MapTagCategory.fromJson(Map<String, dynamic> json) {
    return MapTagCategory(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      sortIndex: json['sortIndex'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'sortIndex': sortIndex};
  }

  @override
  List<Object?> get props => [id, name, sortIndex];
}

/// 标签分类列表响应
class MapTagCategoryListResponse extends Equatable {
  final List<MapTagCategory> items;

  const MapTagCategoryListResponse({required this.items});

  factory MapTagCategoryListResponse.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    return MapTagCategoryListResponse(
      items: itemsList
          .map((e) => MapTagCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'items': items.map((e) => e.toJson()).toList()};
  }

  @override
  List<Object?> get props => [items];
}
