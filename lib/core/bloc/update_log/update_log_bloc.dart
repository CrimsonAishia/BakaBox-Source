import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/api.dart';
import '../../api/update_log_api.dart';
import '../../constants/api_constants.dart';
import '../../utils/error_utils.dart';
import '../../utils/log_service.dart';
import 'update_log_event.dart';
import 'update_log_state.dart';

class UpdateLogBloc extends Bloc<UpdateLogEvent, UpdateLogState> {
  final UpdateLogApi _updateLogApi = UpdateLogApi();
  int _currentPage = 1;

  UpdateLogBloc() : super(const UpdateLogState()) {
    on<UpdateLogFetch>(_onFetch);
    on<UpdateLogLoadMore>(_onLoadMore);
    on<UpdateLogSearch>(_onSearch);
    on<UpdateLogRefresh>(_onRefresh);
    on<UpdateLogClearError>(_onClearError);
    on<UpdateLogReset>(_onReset);
  }

  Future<void> _onFetch(UpdateLogFetch event, Emitter<UpdateLogState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true, currentKeyword: event.keyword));
    _currentPage = 1;

    try {
      final response = await _updateLogApi.getUpdateLogs(
        pageIndex: _currentPage,
        pageSize: ApiConstants.updateLogPageSize,
        keyword: event.keyword,
      );
      emit(state.copyWith(
        logs: response.items,
        totalCount: response.total,
        hasMore: response.items.length < response.total,
        isLoading: false,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(error: '获取更新日志失败：${e.message}', isLoading: false));
      LogService.e('API Exception: $e', e);
    } catch (e) {
      emit(state.copyWith(error: ErrorUtils.getErrorMessage(e, defaultMessage: '获取更新日志失败'), isLoading: false));
      LogService.e('Failed to fetch update logs: $e', e);
    }
  }

  Future<void> _onLoadMore(UpdateLogLoadMore event, Emitter<UpdateLogState> emit) async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    emit(state.copyWith(isLoadingMore: true));

    try {
      final nextPage = _currentPage + 1;
      final response = await _updateLogApi.getUpdateLogs(
        pageIndex: nextPage,
        pageSize: ApiConstants.updateLogPageSize,
        keyword: state.currentKeyword,
      );
      _currentPage = nextPage;
      emit(state.copyWith(
        logs: [...state.logs, ...response.items],
        hasMore: state.logs.length + response.items.length < response.total,
        isLoadingMore: false,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(error: '加载更多失败：${e.message}', isLoadingMore: false));
      LogService.e('Load more API Exception: $e', e);
    } catch (e) {
      emit(state.copyWith(error: ErrorUtils.getErrorMessage(e, defaultMessage: '加载更多失败'), isLoadingMore: false));
      LogService.e('Failed to load more update logs: $e', e);
    }
  }

  Future<void> _onSearch(UpdateLogSearch event, Emitter<UpdateLogState> emit) async {
    if (state.currentKeyword == event.keyword) return;
    add(UpdateLogFetch(event.keyword));
  }

  Future<void> _onRefresh(UpdateLogRefresh event, Emitter<UpdateLogState> emit) async {
    add(UpdateLogFetch(state.currentKeyword));
  }

  void _onClearError(UpdateLogClearError event, Emitter<UpdateLogState> emit) {
    emit(state.copyWith(clearError: true));
  }

  void _onReset(UpdateLogReset event, Emitter<UpdateLogState> emit) {
    _currentPage = 1;
    emit(const UpdateLogState());
  }
}
