import 'package:equatable/equatable.dart';

import '../../models/guide_models.dart';

/// 分类加载状态
enum CategoriesStatus { initial, loading, success, failure }

class GuideCategoriesState extends Equatable {
  final CategoriesStatus status;
  final List<GuideCategoryDef> items;
  final DateTime? lastFetchedAt;
  final String? error;

  const GuideCategoriesState({
    this.status = CategoriesStatus.initial,
    this.items = const [],
    this.lastFetchedAt,
    this.error,
  });

  GuideCategoriesState copyWith({
    CategoriesStatus? status,
    List<GuideCategoryDef>? items,
    DateTime? lastFetchedAt,
    bool clearLastFetchedAt = false,
    String? error,
    bool clearError = false,
  }) {
    return GuideCategoriesState(
      status: status ?? this.status,
      items: items ?? this.items,
      lastFetchedAt: clearLastFetchedAt
          ? null
          : (lastFetchedAt ?? this.lastFetchedAt),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, items, lastFetchedAt, error];
}
