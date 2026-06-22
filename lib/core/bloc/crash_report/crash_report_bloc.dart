import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/api.dart';
import '../../api/crash_report_api.dart';
import '../../models/crash_report_models.dart';
import '../../services/local_crash_service.dart';
import '../../utils/error_utils.dart';
import '../../utils/log_service.dart';
import 'crash_report_event.dart';
import 'crash_report_state.dart';

/// CS2 崩溃报告 Bloc
///
/// - 公开列表（远端，匿名）：`全部` 视图，按严重度 / 类别 / 关键字过滤、上拉加载更多
/// - 本地崩溃列表（本地）：`我的` 视图，扫描游戏目录下的 `.mdmp`
/// - 详情：远端 [CrashReportDetail] 或 本地 [CrashSummary]
/// - 社区面板：进入页面时拉取一次
class CrashReportBloc extends Bloc<CrashReportEvent, CrashReportState> {
  final CrashReportApi _api = CrashReportApi();
  final LocalCrashService _localService = LocalCrashService();

  /// 同步的"加载更多"在途标记：防止滚动帧在状态尚未刷新前重复触发分页请求。
  bool _loadingMore = false;

  CrashReportBloc() : super(const CrashReportState()) {
    on<CrashReportFetch>(_onFetch);
    on<CrashReportFetchMine>(_onFetchMine);
    on<CrashReportLoadLocalDetail>(_onLoadLocalDetail);
    on<CrashReportCloseLocalDetail>(_onCloseLocalDetail);
    on<CrashReportDeleteLocal>(_onDeleteLocal);
    on<CrashReportLoadMore>(_onLoadMore);
    on<CrashReportRefresh>(_onRefresh);
    on<CrashReportSwitchView>(_onSwitchView);
    on<CrashReportFilterSeverity>(_onFilterSeverity);
    on<CrashReportFilterCategory>(_onFilterCategory);
    on<CrashReportSearch>(_onSearch);
    on<CrashReportLoadDetail>(_onLoadDetail);
    on<CrashReportCloseDetail>(_onCloseDetail);
    on<CrashReportFetchStats>(_onFetchStats);
    on<CrashReportClearError>(_onClearError);
  }

  String _err(Object e) =>
      e is ApiException ? e.message : ErrorUtils.getErrorMessage(e);

  // 远端列表

  Future<void> _onFetch(
    CrashReportFetch event,
    Emitter<CrashReportState> emit,
  ) async {
    _loadingMore = false;
    emit(
      state.copyWith(
        isLoading: true,
        clearError: true,
        showMine: false,
        currentSeverity: event.severity,
        currentCategory: event.category,
        currentSort: event.sort,
        currentKeyword: event.keyword ?? '',
        currentSignature: event.signature,
        clearSignature: event.clearSignature,
        currentPage: 1,
      ),
    );
    try {
      final res = await _api.getReports(
        page: 1,
        pageSize: state.pageSize,
        severity: event.severity,
        category: event.category,
        sort: event.sort,
        keyword: event.keyword,
        signature: state.currentSignature,
      );
      emit(
        state.copyWith(
          items: res.items,
          totalCount: res.total,
          hasMore: res.items.length < res.total,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: _err(e), isLoading: false));
      LogService.e('获取崩溃报告列表失败', e);
    }
  }

  Future<void> _onLoadMore(
    CrashReportLoadMore event,
    Emitter<CrashReportState> emit,
  ) async {
    if (state.showMine) return;
    if (_loadingMore || !state.canLoadMore) return;
    _loadingMore = true;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final next = state.currentPage + 1;
      final res = await _api.getReports(
        page: next,
        pageSize: state.pageSize,
        severity: state.currentSeverity,
        category: state.currentCategory,
        sort: state.currentSort,
        keyword: state.currentKeyword.isEmpty ? null : state.currentKeyword,
        signature: state.currentSignature,
      );
      // 去重：按 id 合并，避免服务端在分页间隙插入新数据导致重复项
      final seen = state.items.map((e) => e.id).toSet();
      final appended = res.items.where((e) => seen.add(e.id)).toList();
      final merged = [...state.items, ...appended];
      emit(
        state.copyWith(
          items: merged,
          totalCount: res.total,
          hasMore: merged.length < res.total && res.items.isNotEmpty,
          isLoadingMore: false,
          currentPage: next,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: _err(e), isLoadingMore: false));
      LogService.e('崩溃报告加载更多失败', e);
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _onRefresh(
    CrashReportRefresh event,
    Emitter<CrashReportState> emit,
  ) async {
    if (state.showMine) {
      add(const CrashReportFetchMine());
    } else {
      add(
        CrashReportFetch(
          severity: state.currentSeverity,
          category: state.currentCategory,
          sort: state.currentSort,
          keyword: state.currentKeyword.isEmpty ? null : state.currentKeyword,
          signature: state.currentSignature,
        ),
      );
    }
  }

  Future<void> _onSwitchView(
    CrashReportSwitchView event,
    Emitter<CrashReportState> emit,
  ) async {
    if (state.showMine == event.showMine) return;
    if (event.showMine) {
      add(const CrashReportFetchMine());
    } else {
      emit(
        state.copyWith(
          showMine: false,
          clearSelectedLocalPath: true,
          clearLocalDetail: true,
        ),
      );
      add(
        CrashReportFetch(
          severity: state.currentSeverity,
          category: state.currentCategory,
          sort: state.currentSort,
          keyword: state.currentKeyword.isEmpty ? null : state.currentKeyword,
          signature: state.currentSignature,
        ),
      );
    }
  }

  Future<void> _onFilterSeverity(
    CrashReportFilterSeverity event,
    Emitter<CrashReportState> emit,
  ) async {
    if (state.currentSeverity == event.severity) return;
    if (state.showMine) {
      emit(state.copyWith(currentSeverity: event.severity));
      return;
    }
    add(
      CrashReportFetch(
        severity: event.severity,
        category: state.currentCategory,
        sort: state.currentSort,
        keyword: state.currentKeyword.isEmpty ? null : state.currentKeyword,
        signature: state.currentSignature,
      ),
    );
  }

  Future<void> _onFilterCategory(
    CrashReportFilterCategory event,
    Emitter<CrashReportState> emit,
  ) async {
    if (state.currentCategory == event.category) return;
    if (state.showMine) {
      emit(state.copyWith(currentCategory: event.category));
      return;
    }
    add(
      CrashReportFetch(
        severity: state.currentSeverity,
        category: event.category,
        sort: state.currentSort,
        keyword: state.currentKeyword.isEmpty ? null : state.currentKeyword,
        signature: state.currentSignature,
      ),
    );
  }

  Future<void> _onSearch(
    CrashReportSearch event,
    Emitter<CrashReportState> emit,
  ) async {
    if (state.currentKeyword == event.keyword) return;
    add(
      CrashReportFetch(
        severity: state.currentSeverity,
        category: state.currentCategory,
        sort: state.currentSort,
        keyword: event.keyword.isEmpty ? null : event.keyword,
        clearSignature: true,
      ),
    );
  }

  Future<void> _onLoadDetail(
    CrashReportLoadDetail event,
    Emitter<CrashReportState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoadingDetail: true,
        clearError: true,
        clearDetail: true,
        selectedId: event.id,
      ),
    );
    try {
      final detail = await _api.getReportDetail(event.id);
      if (detail == null) {
        emit(state.copyWith(error: '崩溃报告不存在或已删除', isLoadingDetail: false));
        return;
      }
      emit(state.copyWith(detail: detail, isLoadingDetail: false));
    } catch (e) {
      emit(state.copyWith(error: _err(e), isLoadingDetail: false));
      LogService.e('获取崩溃报告详情失败', e);
    }
  }

  void _onCloseDetail(
    CrashReportCloseDetail event,
    Emitter<CrashReportState> emit,
  ) {
    emit(state.copyWith(clearDetail: true, clearSelectedId: true));
  }

  // 本地（"我的"）

  Future<void> _onFetchMine(
    CrashReportFetchMine event,
    Emitter<CrashReportState> emit,
  ) async {
    emit(
      state.copyWith(
        showMine: true,
        isLoadingLocal: true,
        clearLocalError: true,
        clearDetail: true,
        clearSelectedId: true,
      ),
    );
    try {
      final hasPath = await _localService.hasGamePath();
      final files = hasPath
          ? await _localService.listLocalDumps()
          : <LocalCrashFileInfo>[];
      emit(
        state.copyWith(
          localFiles: files,
          isLoadingLocal: false,
          gamePathConfigured: hasPath,
        ),
      );
    } catch (e) {
      emit(state.copyWith(localError: _err(e), isLoadingLocal: false));
      LogService.e('扫描本地崩溃文件失败', e);
    }
  }

  Future<void> _onLoadLocalDetail(
    CrashReportLoadLocalDetail event,
    Emitter<CrashReportState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoadingLocalDetail: true,
        clearLocalDetail: true,
        clearLocalError: true,
        selectedLocalPath: event.path,
      ),
    );
    try {
      final summary = await _localService.analyze(event.path);
      // race-guard: 用户在解析过程中又点了别的文件 -> 丢弃这个结果
      if (state.selectedLocalPath != event.path) return;
      emit(state.copyWith(localDetail: summary, isLoadingLocalDetail: false));
    } catch (e) {
      if (state.selectedLocalPath != event.path) return;
      emit(state.copyWith(localError: _err(e), isLoadingLocalDetail: false));
      LogService.e('解析本地崩溃文件失败', e);
    }
  }

  void _onCloseLocalDetail(
    CrashReportCloseLocalDetail event,
    Emitter<CrashReportState> emit,
  ) {
    emit(state.copyWith(clearLocalDetail: true, clearSelectedLocalPath: true));
  }

  Future<void> _onDeleteLocal(
    CrashReportDeleteLocal event,
    Emitter<CrashReportState> emit,
  ) async {
    final ok = await _localService.deleteDump(event.path);
    if (!ok) {
      emit(state.copyWith(localError: '删除文件失败'));
      return;
    }
    final left = state.localFiles.where((f) => f.path != event.path).toList();
    final wasSelected = state.selectedLocalPath == event.path;
    emit(
      state.copyWith(
        localFiles: left,
        clearLocalDetail: wasSelected,
        clearSelectedLocalPath: wasSelected,
      ),
    );
  }

  // 聚合 / 杂项

  Future<void> _onFetchStats(
    CrashReportFetchStats event,
    Emitter<CrashReportState> emit,
  ) async {
    emit(state.copyWith(isLoadingStats: true));
    try {
      final remoteFuture = _api.getStats();
      final hasPathFuture = _localService.hasGamePath();
      final localFuture = _localService.listLocalDumps();
      final results = await Future.wait([
        remoteFuture,
        hasPathFuture,
        localFuture,
      ]);
      final remote = results[0] as CrashReportStats?;
      final hasPath = results[1] as bool;
      final local = results[2] as List<LocalCrashFileInfo>;
      emit(
        state.copyWith(
          stats: remote,
          localFiles: local,
          gamePathConfigured: hasPath,
          isLoadingStats: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoadingStats: false));
      LogService.w('获取崩溃报告聚合数据失败: $e');
    }
  }

  void _onClearError(
    CrashReportClearError event,
    Emitter<CrashReportState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }
}
