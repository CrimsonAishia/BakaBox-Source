import 'package:equatable/equatable.dart';

import '../../models/guide_models.dart';
import 'guide_mine_event.dart';

/// 我的中心加载状态
enum GuideMineStatus { initial, loading, loadingMore, success, failure }

class GuideMineState extends Equatable {
  final MineTab tab;
  final GuideStatus? statusFilter;
  final List<GuideListItem> items;
  final List<GuideDraft> drafts;
  final bool hasMore;
  final String? error;
  final GuideMineStatus status;
  final int currentPage;
  final int total;

  /// 用户统计概览（攻略数 / 总浏览 / 粉丝数 / 获赞数）
  final GuideUserStats stats;

  const GuideMineState({
    this.tab = MineTab.published,
    this.statusFilter,
    this.items = const [],
    this.drafts = const [],
    this.hasMore = true,
    this.error,
    this.status = GuideMineStatus.initial,
    this.currentPage = 1,
    this.total = 0,
    this.stats = GuideUserStats.empty,
  });

  bool get canLoadMore =>
      hasMore &&
      status != GuideMineStatus.loading &&
      status != GuideMineStatus.loadingMore;

  GuideMineState copyWith({
    MineTab? tab,
    GuideStatus? statusFilter,
    bool clearStatusFilter = false,
    List<GuideListItem>? items,
    List<GuideDraft>? drafts,
    bool? hasMore,
    String? error,
    bool clearError = false,
    GuideMineStatus? status,
    int? currentPage,
    int? total,
    GuideUserStats? stats,
  }) {
    return GuideMineState(
      tab: tab ?? this.tab,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      items: items ?? this.items,
      drafts: drafts ?? this.drafts,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      status: status ?? this.status,
      currentPage: currentPage ?? this.currentPage,
      total: total ?? this.total,
      stats: stats ?? this.stats,
    );
  }

  @override
  List<Object?> get props => [
        tab,
        statusFilter,
        items,
        drafts,
        hasMore,
        error,
        status,
        currentPage,
        total,
        stats,
      ];
}
