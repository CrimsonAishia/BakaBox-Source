import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/api.dart';
import '../../api/issue_api.dart';
import '../../utils/error_utils.dart';
import '../../utils/log_service.dart';
import 'issue_event.dart';
import 'issue_state.dart';

class IssueBloc extends Bloc<IssueEvent, IssueState> {
  final IssueApi _issueApi = IssueApi();
  static const int _pageSize = 10;

  IssueBloc() : super(const IssueState()) {
    on<IssueFetch>(_onFetch);
    on<IssueFetchMine>(_onFetchMine);
    on<IssueLoadMore>(_onLoadMore);
    on<IssueRefresh>(_onRefresh);
    on<IssueSearch>(_onSearch);
    on<IssueFilterType>(_onFilterType);
    on<IssueFilterStatus>(_onFilterStatus);
    on<IssueSort>(_onSort);
    on<IssueSwitchView>(_onSwitchView);
    on<IssueClearError>(_onClearError);
    on<IssueReset>(_onReset);
    on<IssueGoToPage>(_onGoToPage);
  }

  /// 提取错误信息
  String _getErrorMessage(Object e) {
    if (e is ApiException) return e.message;
    return ErrorUtils.getErrorMessage(e);
  }

  Future<void> _onFetch(IssueFetch event, Emitter<IssueState> emit) async {
    emit(state.copyWith(
      isLoading: true,
      clearError: true,
      currentType: event.type,
      clearType: event.type == null,
      currentStatus: event.status,
      currentSort: event.sort,
      currentKeyword: event.keyword ?? '',
      showMine: false,
      currentPage: 1,
    ));

    try {
      final response = await _issueApi.getIssues(
        page: 1,
        pageSize: _pageSize,
        type: event.type,
        status: event.status,
        sort: event.sort,
        keyword: event.keyword,
      );
      emit(state.copyWith(
        issues: response.items,
        totalCount: response.total,
        hasMore: response.items.length < response.total,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isLoading: false));
      LogService.e('获取 Issue 列表失败', e);
    }
  }

  Future<void> _onFetchMine(IssueFetchMine event, Emitter<IssueState> emit) async {
    emit(state.copyWith(
      isLoading: true,
      clearError: true,
      showMine: true,
      currentPage: 1,
      currentType: event.type,
      clearType: event.type == null,
      currentStatus: event.status ?? state.currentStatus,
      currentSort: event.sort ?? state.currentSort,
    ));

    try {
      final response = await _issueApi.getMyIssues(
        page: 1,
        pageSize: _pageSize,
        type: event.type,
        status: event.status ?? state.currentStatus,
        sort: event.sort ?? state.currentSort,
      );
      emit(state.copyWith(
        issues: response.items,
        totalCount: response.total,
        hasMore: response.items.length < response.total,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isLoading: false));
      LogService.e('获取我的 Issue 列表失败', e);
    }
  }

  Future<void> _onLoadMore(IssueLoadMore event, Emitter<IssueState> emit) async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    emit(state.copyWith(isLoadingMore: true));

    try {
      final nextPage = state.currentPage + 1;
      final response = state.showMine
          ? await _issueApi.getMyIssues(
              page: nextPage,
              pageSize: _pageSize,
              type: state.currentType,
              status: state.currentStatus,
              sort: state.currentSort,
            )
          : await _issueApi.getIssues(
              page: nextPage,
              pageSize: _pageSize,
              type: state.currentType,
              status: state.currentStatus,
              sort: state.currentSort,
              keyword: state.currentKeyword.isNotEmpty ? state.currentKeyword : null,
            );
      emit(state.copyWith(
        issues: [...state.issues, ...response.items],
        hasMore: state.issues.length + response.items.length < response.total,
        isLoadingMore: false,
        currentPage: nextPage,
      ));
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isLoadingMore: false));
      LogService.e('加载更多 Issue 失败', e);
    }
  }

  Future<void> _onRefresh(IssueRefresh event, Emitter<IssueState> emit) async {
    if (state.showMine) {
      add(IssueFetchMine(
        type: state.currentType,
        status: state.currentStatus,
        sort: state.currentSort,
      ));
    } else {
      add(IssueFetch(
        type: state.currentType,
        status: state.currentStatus,
        sort: state.currentSort,
        keyword: state.currentKeyword.isNotEmpty ? state.currentKeyword : null,
      ));
    }
  }

  Future<void> _onSearch(IssueSearch event, Emitter<IssueState> emit) async {
    if (state.currentKeyword == event.keyword) return;
    add(IssueFetch(
      type: state.currentType,
      status: state.currentStatus,
      sort: state.currentSort,
      keyword: event.keyword.isNotEmpty ? event.keyword : null,
    ));
  }

  Future<void> _onFilterType(IssueFilterType event, Emitter<IssueState> emit) async {
    if (state.currentType == event.type) return;
    if (state.showMine) {
      add(IssueFetchMine(
        type: event.type,
        status: state.currentStatus,
        sort: state.currentSort,
      ));
    } else {
      add(IssueFetch(
        type: event.type,
        status: state.currentStatus,
        sort: state.currentSort,
        keyword: state.currentKeyword.isNotEmpty ? state.currentKeyword : null,
      ));
    }
  }

  Future<void> _onFilterStatus(IssueFilterStatus event, Emitter<IssueState> emit) async {
    if (state.currentStatus == event.status) return;
    if (state.showMine) {
      add(IssueFetchMine(
        type: state.currentType,
        status: event.status,
        sort: state.currentSort,
      ));
    } else {
      add(IssueFetch(
        type: state.currentType,
        status: event.status,
        sort: state.currentSort,
        keyword: state.currentKeyword.isNotEmpty ? state.currentKeyword : null,
      ));
    }
  }

  Future<void> _onSort(IssueSort event, Emitter<IssueState> emit) async {
    if (state.currentSort == event.sort) return;
    if (state.showMine) {
      add(IssueFetchMine(
        type: state.currentType,
        status: state.currentStatus,
        sort: event.sort,
      ));
    } else {
      add(IssueFetch(
        type: state.currentType,
        status: state.currentStatus,
        sort: event.sort,
        keyword: state.currentKeyword.isNotEmpty ? state.currentKeyword : null,
      ));
    }
  }

  Future<void> _onSwitchView(IssueSwitchView event, Emitter<IssueState> emit) async {
    if (state.showMine == event.showMine) return;
    if (event.showMine) {
      add(const IssueFetchMine());
    } else {
      add(const IssueFetch());
    }
  }

  void _onClearError(IssueClearError event, Emitter<IssueState> emit) {
    emit(state.copyWith(clearError: true));
  }

  void _onReset(IssueReset event, Emitter<IssueState> emit) {
    emit(const IssueState());
  }

  Future<void> _onGoToPage(IssueGoToPage event, Emitter<IssueState> emit) async {
    if (event.page < 1 || event.page > state.totalPages || state.isLoading) return;
    if (event.page == state.currentPage) return;
    
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final response = state.showMine
          ? await _issueApi.getMyIssues(
              page: event.page,
              pageSize: _pageSize,
              type: state.currentType,
              status: state.currentStatus,
              sort: state.currentSort,
            )
          : await _issueApi.getIssues(
              page: event.page,
              pageSize: _pageSize,
              type: state.currentType,
              status: state.currentStatus,
              sort: state.currentSort,
              keyword: state.currentKeyword.isNotEmpty ? state.currentKeyword : null,
            );
      emit(state.copyWith(
        issues: response.items,
        totalCount: response.total,
        hasMore: event.page * _pageSize < response.total,
        isLoading: false,
        currentPage: event.page,
      ));
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isLoading: false));
      LogService.e('跳转页面失败', e);
    }
  }
}
