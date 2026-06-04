import 'package:equatable/equatable.dart';

abstract class GuideCategoriesEvent extends Equatable {
  const GuideCategoriesEvent();

  @override
  List<Object?> get props => [];
}

/// 加载分类列表
///
/// [force] 为 true 时绕过 30 分钟内存缓存
class LoadCategories extends GuideCategoriesEvent {
  final bool force;

  const LoadCategories({this.force = false});

  @override
  List<Object?> get props => [force];
}
