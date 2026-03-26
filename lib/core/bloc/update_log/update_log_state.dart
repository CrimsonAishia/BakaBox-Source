import 'package:equatable/equatable.dart';
import '../../models/update_log_models.dart';

class UpdateLogState extends Equatable {
  final List<SteamWorkChangeLog> logs;
  final bool isLoading; // 首次加载或搜索中
  final bool isLoadingMore; // 加载更多中
  final bool hasMore;
  final int totalCount;
  final String keyword; // 当前搜索关键字
  final String? error;

  const UpdateLogState({
    this.logs = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.totalCount = 0,
    this.keyword = '',
    this.error,
  });

  UpdateLogState copyWith({
    List<SteamWorkChangeLog>? logs,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? totalCount,
    String? keyword,
    String? error,
    bool clearError = false,
  }) {
    return UpdateLogState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      totalCount: totalCount ?? this.totalCount,
      keyword: keyword ?? this.keyword,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    logs,
    isLoading,
    isLoadingMore,
    hasMore,
    totalCount,
    keyword,
    error,
  ];
}
