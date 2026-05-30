import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/server_stats_api.dart';
import '../../utils/log_service.dart';
import 'server_stats_event.dart';
import 'server_stats_state.dart';

class ServerStatsBloc extends Bloc<ServerStatsEvent, ServerStatsState> {
  ServerStatsBloc() : super(const ServerStatsState()) {
    on<ServerStatsFetch>(_onFetch);
    on<ServerStatsRefresh>(_onRefresh);
  }

  Future<void> _onFetch(
    ServerStatsFetch event,
    Emitter<ServerStatsState> emit,
  ) async {
    if (state.isLoading) return;

    emit(state.copyWith(isLoading: true));

    try {
      final stats = await ServerStatsApi.getDailyStats();
      emit(
        state.copyWith(
          isLoading: false,
          stats: stats,
          lastFetched: DateTime.now(),
        ),
      );
    } catch (e) {
      LogService.e('获取服务器统计失败', e);
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onRefresh(
    ServerStatsRefresh event,
    Emitter<ServerStatsState> emit,
  ) async {
    if (state.isLoading) return;

    emit(state.copyWith(isLoading: true));

    try {
      final stats = await ServerStatsApi.getDailyStats();
      emit(
        state.copyWith(
          isLoading: false,
          stats: stats,
          lastFetched: DateTime.now(),
        ),
      );
    } catch (e) {
      LogService.e('刷新服务器统计失败', e);
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }
}
