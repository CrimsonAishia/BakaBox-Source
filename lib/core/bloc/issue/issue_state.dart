import 'package:equatable/equatable.dart';
import '../../models/issue_models.dart';

class IssueState extends Equatable {
  final List<IssueListItem> issues;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int totalCount;
  final String? currentType;
  final String currentStatus;
  final String currentSort;
  final String currentKeyword;
  final bool showMine; // 是否显示我的Issue
  final int currentPage; // 当前页码
  final int pageSize; // 每页数量

  const IssueState({
    this.issues = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.totalCount = 0,
    this.currentType,
    this.currentStatus = 'open',
    this.currentSort = 'created_at DESC',
    this.currentKeyword = '',
    this.showMine = false,
    this.currentPage = 1,
    this.pageSize = 10,
  });

  bool get isEmpty => issues.isEmpty && !isLoading;
  bool get canLoadMore => hasMore && !isLoading && !isLoadingMore;
  int get totalPages => totalCount > 0 ? (totalCount / pageSize).ceil() : 1;

  IssueState copyWith({
    List<IssueListItem>? issues,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
    int? totalCount,
    String? currentType,
    bool clearType = false,
    String? currentStatus,
    String? currentSort,
    String? currentKeyword,
    bool? showMine,
    int? currentPage,
    int? pageSize,
  }) {
    return IssueState(
      issues: issues ?? this.issues,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      totalCount: totalCount ?? this.totalCount,
      currentType: clearType ? null : (currentType ?? this.currentType),
      currentStatus: currentStatus ?? this.currentStatus,
      currentSort: currentSort ?? this.currentSort,
      currentKeyword: currentKeyword ?? this.currentKeyword,
      showMine: showMine ?? this.showMine,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  @override
  List<Object?> get props => [issues, isLoading, isLoadingMore, hasMore, error, totalCount, currentType, currentStatus, currentSort, currentKeyword, showMine, currentPage, pageSize];
}
