import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/announcement_api.dart';
import '../../services/announcement_read_service.dart';
import '../../utils/announcement_utils.dart';
import '../../utils/log_service.dart';
import 'announcement_event.dart';
import 'announcement_state.dart';

/// 公告 BLoC
/// 
/// 负责管理公告的获取、刷新和已读状态
/// 支持自动刷新功能（默认30分钟）
class AnnouncementBloc extends Bloc<AnnouncementEvent, AnnouncementState> {
  final AnnouncementApi _announcementApi;
  final AnnouncementReadService _readService;
  
  /// 自动刷新定时器
  Timer? _autoRefreshTimer;
  
  /// 自动刷新间隔（30分钟）
  static const Duration _autoRefreshInterval = Duration(minutes: 30);

  AnnouncementBloc({
    AnnouncementApi? announcementApi,
    AnnouncementReadService? readService,
  })  : _announcementApi = announcementApi ?? AnnouncementApi(),
        _readService = readService ?? AnnouncementReadService(),
        super(const AnnouncementState()) {
    on<AnnouncementFetch>(_onFetch);
    on<AnnouncementRefresh>(_onRefresh);
    on<AnnouncementMarkAsRead>(_onMarkAsRead);
    on<AnnouncementClearError>(_onClearError);
    on<AnnouncementStartAutoRefresh>(_onStartAutoRefresh);
    on<AnnouncementStopAutoRefresh>(_onStopAutoRefresh);
  }
  
  /// 启动自动刷新
  void _startAutoRefresh() {
    _stopAutoRefresh();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (!state.isLoading) {
        LogService.d('公告自动刷新触发');
        add(AnnouncementRefresh(silent: true));
      }
    });
    LogService.d('公告自动刷新已启动，间隔: ${_autoRefreshInterval.inMinutes} 分钟');
  }
  
  /// 停止自动刷新
  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }
  
  /// 处理启动自动刷新事件
  void _onStartAutoRefresh(
    AnnouncementStartAutoRefresh event,
    Emitter<AnnouncementState> emit,
  ) {
    _startAutoRefresh();
  }
  
  /// 处理停止自动刷新事件
  void _onStopAutoRefresh(
    AnnouncementStopAutoRefresh event,
    Emitter<AnnouncementState> emit,
  ) {
    _stopAutoRefresh();
    LogService.i('公告自动刷新已停止');
  }
  
  @override
  Future<void> close() {
    _stopAutoRefresh();
    return super.close();
  }

  /// 处理获取公告事件
  Future<void> _onFetch(
    AnnouncementFetch event,
    Emitter<AnnouncementState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      LogService.d('开始获取公告列表');

      // 并行获取有效公告和置顶公告
      final results = await Future.wait([
        _announcementApi.getActiveAnnouncements(),
        _announcementApi.getStickyAnnouncements(),
      ]);

      final activeResponse = results[0];
      final stickyResponse = results[1];

      // 合并并排序公告
      final activeItems = activeResponse?.items ?? [];
      final stickyItems = stickyResponse?.items ?? [];
      final announcements = AnnouncementUtils.mergeAndSortAnnouncements(
        activeItems,
        stickyItems,
      );

      // 获取已读状态
      final readIds = await _readService.getReadIds();

      emit(state.copyWith(
        announcements: announcements,
        readIds: readIds,
        isLoading: false,
      ));

      LogService.d('成功获取 ${announcements.length} 条公告');
    } catch (e) {
      LogService.e('获取公告列表失败: $e', e);
      emit(state.copyWith(
        isLoading: false,
        error: '获取公告失败，请稍后重试',
      ));
    }
  }

  /// 处理刷新公告事件
  Future<void> _onRefresh(
    AnnouncementRefresh event,
    Emitter<AnnouncementState> emit,
  ) async {
    // 静默刷新时不显示 loading 状态
    if (!event.silent) {
      emit(state.copyWith(isLoading: true, clearError: true));
    }

    try {
      LogService.d('开始${event.silent ? "静默" : ""}刷新公告列表');

      // 并行获取有效公告和置顶公告
      final results = await Future.wait([
        _announcementApi.getActiveAnnouncements(),
        _announcementApi.getStickyAnnouncements(),
      ]);

      final activeResponse = results[0];
      final stickyResponse = results[1];

      // 合并并排序公告
      final activeItems = activeResponse?.items ?? [];
      final stickyItems = stickyResponse?.items ?? [];
      final announcements = AnnouncementUtils.mergeAndSortAnnouncements(
        activeItems,
        stickyItems,
      );

      // 保留现有的已读状态
      emit(state.copyWith(
        announcements: announcements,
        isLoading: false,
      ));

      LogService.d('成功刷新公告列表，共 ${announcements.length} 条');
    } catch (e) {
      LogService.e('刷新公告列表失败: $e', e);
      // 静默刷新时不显示错误
      if (!event.silent) {
        emit(state.copyWith(
          isLoading: false,
          error: '刷新公告失败，请稍后重试',
        ));
      }
    }
  }

  /// 处理标记已读事件
  Future<void> _onMarkAsRead(
    AnnouncementMarkAsRead event,
    Emitter<AnnouncementState> emit,
  ) async {
    // 如果已经是已读状态，直接返回
    if (state.readIds.contains(event.announcementId)) {
      return;
    }

    try {
      // 先更新本地状态（乐观更新）
      final updatedReadIds = Set<int>.from(state.readIds)
        ..add(event.announcementId);
      emit(state.copyWith(readIds: updatedReadIds));

      // 持久化到本地存储
      await _readService.markAsRead(event.announcementId);

      LogService.d('公告 ${event.announcementId} 已标记为已读');
    } catch (e) {
      LogService.e('标记公告已读失败: $e', e);
      // 标记失败时不回滚状态，因为这不是关键操作
    }
  }

  /// 处理清除错误事件
  void _onClearError(
    AnnouncementClearError event,
    Emitter<AnnouncementState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }
}
