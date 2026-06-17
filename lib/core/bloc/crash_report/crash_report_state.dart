import 'package:equatable/equatable.dart';
import '../../models/crash_report_models.dart';
import '../../services/crash_inspector/crash_inspector.dart';
import '../../services/local_crash_service.dart';

class CrashReportState extends Equatable {
  // 公开列表（远端）
  final List<CrashReportListItem> items;
  final int totalCount;
  final int currentPage;
  final int pageSize;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final bool showMine;
  final String currentSeverity;
  final String currentCategory;
  final String currentSort;
  final String currentKeyword;
  final String? currentSignature;
  final String? error;

  // 详情：远端来自 [detail]，本地来自 [localDetail]
  final CrashReportDetail? detail;
  final bool isLoadingDetail;
  final int? selectedId;

  // 本地（"我的"）
  final List<LocalCrashFileInfo> localFiles;
  final bool isLoadingLocal;
  final String? localError;
  final String? selectedLocalPath;
  final CrashSummary? localDetail;
  final bool isLoadingLocalDetail;

  /// CS2 游戏路径是否已配置：影响"我的"空状态的提示语和 CTA。
  /// `null` 代表"还没扫过本地"，`true / false` 代表实际配置情况。
  final bool? gamePathConfigured;

  // 社区面板
  final CrashReportStats? stats;
  final bool isLoadingStats;

  const CrashReportState({
    this.items = const [],
    this.totalCount = 0,
    this.currentPage = 1,
    this.pageSize = 20,
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.showMine = true,
    this.currentSeverity = 'all',
    this.currentCategory = 'all',
    this.currentSort = 'created_at DESC',
    this.currentKeyword = '',
    this.currentSignature,
    this.error,
    this.detail,
    this.isLoadingDetail = false,
    this.selectedId,
    this.localFiles = const [],
    this.isLoadingLocal = false,
    this.localError,
    this.selectedLocalPath,
    this.localDetail,
    this.isLoadingLocalDetail = false,
    this.gamePathConfigured,
    this.stats,
    this.isLoadingStats = false,
  });

  bool get isEmpty => items.isEmpty && !isLoading;
  bool get isLocalEmpty => localFiles.isEmpty && !isLoadingLocal;
  bool get canLoadMore => hasMore && !isLoading && !isLoadingMore;
  int get totalPages =>
      totalCount > 0 ? (totalCount / pageSize).ceil() : 1;

  CrashReportState copyWith({
    List<CrashReportListItem>? items,
    int? totalCount,
    int? currentPage,
    int? pageSize,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    bool? showMine,
    String? currentSeverity,
    String? currentCategory,
    String? currentSort,
    String? currentKeyword,
    String? currentSignature,
    bool clearSignature = false,
    String? error,
    bool clearError = false,
    CrashReportDetail? detail,
    bool clearDetail = false,
    bool? isLoadingDetail,
    int? selectedId,
    bool clearSelectedId = false,
    List<LocalCrashFileInfo>? localFiles,
    bool? isLoadingLocal,
    String? localError,
    bool clearLocalError = false,
    String? selectedLocalPath,
    bool clearSelectedLocalPath = false,
    CrashSummary? localDetail,
    bool clearLocalDetail = false,
    bool? isLoadingLocalDetail,
    bool? gamePathConfigured,
    CrashReportStats? stats,
    bool? isLoadingStats,
  }) {
    return CrashReportState(
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      showMine: showMine ?? this.showMine,
      currentSeverity: currentSeverity ?? this.currentSeverity,
      currentCategory: currentCategory ?? this.currentCategory,
      currentSort: currentSort ?? this.currentSort,
      currentKeyword: currentKeyword ?? this.currentKeyword,
      currentSignature: clearSignature ? null : (currentSignature ?? this.currentSignature),
      error: clearError ? null : (error ?? this.error),
      detail: clearDetail ? null : (detail ?? this.detail),
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      selectedId: clearSelectedId ? null : (selectedId ?? this.selectedId),
      localFiles: localFiles ?? this.localFiles,
      isLoadingLocal: isLoadingLocal ?? this.isLoadingLocal,
      localError:
          clearLocalError ? null : (localError ?? this.localError),
      selectedLocalPath: clearSelectedLocalPath
          ? null
          : (selectedLocalPath ?? this.selectedLocalPath),
      localDetail:
          clearLocalDetail ? null : (localDetail ?? this.localDetail),
      isLoadingLocalDetail:
          isLoadingLocalDetail ?? this.isLoadingLocalDetail,
      gamePathConfigured: gamePathConfigured ?? this.gamePathConfigured,
      stats: stats ?? this.stats,
      isLoadingStats: isLoadingStats ?? this.isLoadingStats,
    );
  }

  @override
  List<Object?> get props => [
    items,
    totalCount,
    currentPage,
    pageSize,
    hasMore,
    isLoading,
    isLoadingMore,
    showMine,
    currentSeverity,
    currentCategory,
    currentSort,
    currentKeyword,
    currentSignature,
    error,
    detail,
    isLoadingDetail,
    selectedId,
    localFiles,
    isLoadingLocal,
    localError,
    selectedLocalPath,
    localDetail,
    isLoadingLocalDetail,
    gamePathConfigured,
    stats,
    isLoadingStats,
  ];
}
