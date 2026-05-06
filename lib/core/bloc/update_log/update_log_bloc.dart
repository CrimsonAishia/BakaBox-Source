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
    on<UpdateLogClearError>(_onClearError);
  }

  /// 获取日志（首次加载或搜索）
  Future<void> _onFetch(
    UpdateLogFetch event,
    Emitter<UpdateLogState> emit,
  ) async {
    // 立即清空数据并显示 loading
    emit(UpdateLogState(isLoading: true, keyword: event.keyword));
    _currentPage = 1;

    try {
      final response = await _updateLogApi.getUpdateLogs(
        pageIndex: _currentPage,
        pageSize: ApiConstants.updateLogPageSize,
        keyword: event.keyword,
      );
      emit(
        UpdateLogState(
          logs: response.items,
          totalCount: response.total,
          hasMore: response.items.length < response.total,
          keyword: event.keyword,
          lastFetched: DateTime.now(),
        ),
      );
    } on ApiException catch (e) {
      emit(UpdateLogState(error: e.message, keyword: event.keyword));
      LogService.e('UpdateLogBloc fetch error', e);
    } catch (e) {
      emit(
        UpdateLogState(
          error: ErrorUtils.getErrorMessage(e, defaultMessage: '获取更新日志失败'),
          keyword: event.keyword,
        ),
      );
      LogService.e('UpdateLogBloc fetch error', e);
    }
  }

  /// 加载更多
  Future<void> _onLoadMore(
    UpdateLogLoadMore event,
    Emitter<UpdateLogState> emit,
  ) async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    emit(state.copyWith(isLoadingMore: true));

    try {
      final nextPage = _currentPage + 1;
      final response = await _updateLogApi.getUpdateLogs(
        pageIndex: nextPage,
        pageSize: ApiConstants.updateLogPageSize,
        keyword: state.keyword,
      );
      _currentPage = nextPage;
      final newLogs = [...state.logs, ...response.items];
      emit(
        state.copyWith(
          logs: newLogs,
          hasMore: newLogs.length < response.total,
          isLoadingMore: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message, isLoadingMore: false));
      LogService.e('UpdateLogBloc loadMore error', e);
    } catch (e) {
      emit(
        state.copyWith(
          error: ErrorUtils.getErrorMessage(e, defaultMessage: '加载更多失败'),
          isLoadingMore: false,
        ),
      );
      LogService.e('UpdateLogBloc loadMore error', e);
    }
  }

  void _onClearError(UpdateLogClearError event, Emitter<UpdateLogState> emit) {
    emit(state.copyWith(clearError: true));
  }
}
