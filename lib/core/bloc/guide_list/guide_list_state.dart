import 'package:equatable/equatable.dart';

import '../../models/guide_models.dart';
import 'guide_list_event.dart';

/// 攻略列表加载状态
enum GuideListStatus { initial, loading, loadingMore, success, failure }

class GuideListState extends Equatable {
  final GuideListStatus status;
  final List<GuideListItem> items;
  final List<GuideListItem> pinned;
  final GuideFilter filter;
  final GuideSortBy sortBy;
  final String keyword;
  final int total;
  final bool hasMore;
  final String? error;
  final int currentPage;

  const GuideListState({
    this.status = GuideListStatus.initial,
    this.items = const [],
    this.pinned = const [],
    this.filter = const GuideFilter.empty(),
    this.sortBy = GuideSortBy.latest,
    this.keyword = '',
    this.total = 0,
    this.hasMore = true,
    this.error,
    this.currentPage = 1,
  });

  /// 列表为空且非加载中时为 true
  bool get isEmpty => items.isEmpty && status != GuideListStatus.loading;

  /// 满足以下条件时可继续加载下一页：有更多数据 + 当前非加载中
  bool get canLoadMore =>
      hasMore &&
      status != GuideListStatus.loading &&
      status != GuideListStatus.loadingMore;

  GuideListState copyWith({
    GuideListStatus? status,
    List<GuideListItem>? items,
    List<GuideListItem>? pinned,
    GuideFilter? filter,
    GuideSortBy? sortBy,
    String? keyword,
    int? total,
    bool? hasMore,
    String? error,
    bool clearError = false,
    int? currentPage,
  }) {
    return GuideListState(
      status: status ?? this.status,
      items: items ?? this.items,
      pinned: pinned ?? this.pinned,
      filter: filter ?? this.filter,
      sortBy: sortBy ?? this.sortBy,
      keyword: keyword ?? this.keyword,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      currentPage: currentPage ?? this.currentPage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    pinned,
    filter,
    sortBy,
    keyword,
    total,
    hasMore,
    error,
    currentPage,
  ];
}
