import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/announcement_api.dart';
import '../../services/announcement_read_service.dart';
import '../../services/realtime/realtime_announcement_channel.dart';
import '../../services/realtime_service.dart';
import '../../utils/announcement_utils.dart';
import '../../utils/log_service.dart';
import 'announcement_event.dart';
import 'announcement_state.dart';

/// 公告 BLoC
///
/// 通过 `announcements` WS 频道接收创建/更新/置顶变更/删除事件，
/// 收到任意事件后用 REST 重新拉一次有效公告 + 置顶公告（去掉了 30 分钟轮询）。
class AnnouncementBloc extends Bloc<AnnouncementEvent, AnnouncementState> {
  final AnnouncementApi _announcementApi;
  final AnnouncementReadService _readService;
  final RealtimeAnnouncementChannel _realtimeChannel =
      RealtimeAnnouncementChannel();

  StreamSubscription<AnnouncementChannelEvent>? _realtimeSubscription;
  StreamSubscription<void>? _reconnectedSubscription;
  bool _realtimeStarted = false;

  /// 实时事件去抖：100ms 内的多个事件合并成一次刷新
  Timer? _refreshDebounceTimer;
  static const Duration _refreshDebounce = Duration(milliseconds: 200);

  AnnouncementBloc({
    AnnouncementApi? announcementApi,
    AnnouncementReadService? readService,
  }) : _announcementApi = announcementApi ?? AnnouncementApi(),
       _readService = readService ?? AnnouncementReadService(),
       super(const AnnouncementState()) {
    on<AnnouncementFetch>(_onFetch);
    on<AnnouncementRefresh>(_onRefresh);
    on<AnnouncementMarkAsRead>(_onMarkAsRead);
    on<AnnouncementClearError>(_onClearError);
    on<AnnouncementStartRealtime>(_onStartRealtime);
    on<AnnouncementStopRealtime>(_onStopRealtime);
    on<AnnouncementRealtimeReceived>(_onRealtimeReceived);
    on<AnnouncementFetchDetail>(_onFetchDetail);
  }

  @override
  Future<void> close() {
    _stopRealtime();
    _refreshDebounceTimer?.cancel();
    return super.close();
  }

  // ---- 实时频道 ----

  void _startRealtime() {
    if (_realtimeStarted) return;
    _realtimeStarted = true;
    _realtimeChannel.subscribe();
    _realtimeSubscription = _realtimeChannel.events.listen((payload) {
      if (isClosed) return;
      add(AnnouncementRealtimeReceived(payload));
    });
    // 断线重连后，announcements 频道不回放断线期间的变更，
    // 复用去抖刷新主动对账一次（合并 200ms 内的重连抖动）
    _reconnectedSubscription = RealtimeService().reconnectedStream.listen((_) {
      if (isClosed) return;
      LogService.d('[AnnouncementBloc] 重连成功，主动对账');
      _scheduleDebouncedRefresh();
    });
    LogService.d('[AnnouncementBloc] 实时通道已启动');
  }

  void _stopRealtime() {
    if (!_realtimeStarted) return;
    _realtimeStarted = false;
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _reconnectedSubscription?.cancel();
    _reconnectedSubscription = null;
    _realtimeChannel.unsubscribe();
    LogService.d('[AnnouncementBloc] 实时通道已停止');
  }

  void _onStartRealtime(
    AnnouncementStartRealtime event,
    Emitter<AnnouncementState> emit,
  ) {
    _startRealtime();
  }

  void _onStopRealtime(
    AnnouncementStopRealtime event,
    Emitter<AnnouncementState> emit,
  ) {
    _stopRealtime();
  }

  void _onRealtimeReceived(
    AnnouncementRealtimeReceived event,
    Emitter<AnnouncementState> emit,
  ) {
    final payload = event.payload;
    LogService.d(
      '[AnnouncementBloc] 推送: kind=${payload.kind} id=${payload.id}',
    );

    // delete 事件：直接从本地列表移除，省一次列表请求
    if (payload.kind == AnnouncementChannelEventKind.deleted) {
      final updated = state.announcements
          .where((a) => a.id != payload.id)
          .toList(growable: false);
      if (updated.length != state.announcements.length) {
        emit(state.copyWith(announcements: updated));
      }
      return;
    }

    // 其余事件去抖刷新
    _scheduleDebouncedRefresh();
  }

  void _scheduleDebouncedRefresh() {
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer = Timer(_refreshDebounce, () {
      _refreshDebounceTimer = null;
      if (isClosed) return;
      add(const AnnouncementRefresh(silent: true));
    });
  }

  // ---- REST 操作 ----

  Future<void> _onFetch(
    AnnouncementFetch event,
    Emitter<AnnouncementState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final results = await Future.wait([
        _announcementApi.getActiveAnnouncements(),
        _announcementApi.getStickyAnnouncements(),
      ]);

      final activeResponse = results[0];
      final stickyResponse = results[1];

      final activeItems = activeResponse?.items ?? [];
      final stickyItems = stickyResponse?.items ?? [];
      final announcements = AnnouncementUtils.mergeAndSortAnnouncements(
        activeItems,
        stickyItems,
      );

      final readIds = await _readService.getReadIds();

      emit(
        state.copyWith(
          announcements: announcements,
          readIds: readIds,
          isLoading: false,
          lastFetched: DateTime.now(),
        ),
      );

      LogService.d('成功获取 ${announcements.length} 条公告');
    } catch (e) {
      LogService.e('获取公告列表失败: $e', e);
      emit(state.copyWith(isLoading: false, error: '获取公告失败，请稍后重试'));
    }
  }

  Future<void> _onRefresh(
    AnnouncementRefresh event,
    Emitter<AnnouncementState> emit,
  ) async {
    if (!event.silent) {
      emit(state.copyWith(isLoading: true, clearError: true));
    }

    try {
      final results = await Future.wait([
        _announcementApi.getActiveAnnouncements(),
        _announcementApi.getStickyAnnouncements(),
      ]);

      final activeResponse = results[0];
      final stickyResponse = results[1];

      final activeItems = activeResponse?.items ?? [];
      final stickyItems = stickyResponse?.items ?? [];
      final announcements = AnnouncementUtils.mergeAndSortAnnouncements(
        activeItems,
        stickyItems,
      );

      final readIds = await _readService.getReadIds();

      emit(
        state.copyWith(
          announcements: announcements,
          readIds: readIds,
          isLoading: false,
          lastFetched: DateTime.now(),
        ),
      );

      LogService.d('成功刷新公告列表，共 ${announcements.length} 条');
    } catch (e) {
      LogService.e('刷新公告列表失败: $e', e);
      if (!event.silent) {
        emit(state.copyWith(isLoading: false, error: '刷新公告失败，请稍后重试'));
      }
    }
  }

  Future<void> _onMarkAsRead(
    AnnouncementMarkAsRead event,
    Emitter<AnnouncementState> emit,
  ) async {
    if (state.readIds.contains(event.announcementId)) return;

    try {
      final updatedReadIds = Set<int>.from(state.readIds)
        ..add(event.announcementId);
      emit(state.copyWith(readIds: updatedReadIds));

      await _readService.markAsRead(event.announcementId);
    } catch (e) {
      LogService.e('标记公告已读失败: $e', e);
    }
  }

  void _onClearError(
    AnnouncementClearError event,
    Emitter<AnnouncementState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  Future<void> _onFetchDetail(
    AnnouncementFetchDetail event,
    Emitter<AnnouncementState> emit,
  ) async {
    emit(state.copyWith(isLoadingDetail: true, clearError: true));

    try {
      final detail = await _announcementApi.getAnnouncementDetail(
        event.announcementId,
      );

      if (detail != null) {
        emit(state.copyWith(currentDetail: detail, isLoadingDetail: false));
      } else {
        emit(state.copyWith(isLoadingDetail: false, error: '公告不存在或已被删除'));
      }
    } catch (e) {
      LogService.e('获取公告详情失败: $e', e);
      emit(state.copyWith(isLoadingDetail: false, error: '获取公告详情失败，请稍后重试'));
    }
  }
}
