import 'package:equatable/equatable.dart';
import '../../models/update_log_models.dart';

class UpdateLogState extends Equatable {
  final List<SteamWorkChangeLog> logs;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int totalCount;
  final String currentKeyword;

  const UpdateLogState({
    this.logs = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.totalCount = 0,
    this.currentKeyword = '',
  });

  bool get isEmpty => logs.isEmpty && !isLoading;
  bool get canLoadMore => hasMore && !isLoading && !isLoadingMore;

  UpdateLogState copyWith({
    List<SteamWorkChangeLog>? logs,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
    int? totalCount,
    String? currentKeyword,
  }) {
    return UpdateLogState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      totalCount: totalCount ?? this.totalCount,
      currentKeyword: currentKeyword ?? this.currentKeyword,
    );
  }

  @override
  List<Object?> get props => [logs, isLoading, isLoadingMore, hasMore, error, totalCount, currentKeyword];
}
