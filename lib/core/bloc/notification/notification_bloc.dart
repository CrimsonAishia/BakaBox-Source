import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/notification_api.dart';
import '../../models/notification_models.dart';
import '../../services/auth_service.dart';
import '../../services/realtime/realtime_notifications_channel.dart';
import '../../utils/log_service.dart';
import 'notification_event.dart';
import 'notification_state.dart';

/// 消息 BLoC
///
/// 通过 `notifications` WS 频道接收新消息，未读数量由 WS 推送 + 标记已读时本地维护。
/// 仅在以下场景调用 REST：
/// - 首次进入消息页 / 切换筛选条件：`getNotifications`
/// - 操作（标记已读 / 全部已读 / 删除）：写操作 REST
/// - 应用启动 / 切换登录态后拉一次基线：`getUnreadCount`
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationApi _notificationApi;
  final RealtimeNotificationsChannel _realtimeChannel =
      RealtimeNotificationsChannel();

  StreamSubscription<NotificationItem>? _realtimeSubscription;
  bool _realtimeStarted = false;

  static const int _pageSize = 20;

  NotificationBloc({NotificationApi? notificationApi})
    : _notificationApi = notificationApi ?? NotificationApi(),
      super(const NotificationState()) {
    on<NotificationFetch>(_onFetch);
    on<NotificationRefresh>(_onRefresh);
    on<NotificationLoadMore>(_onLoadMore);
    on<NotificationMarkRead>(_onMarkRead);
    on<NotificationMarkAllRead>(_onMarkAllRead);
    on<NotificationDelete>(_onDelete);
    on<NotificationFetchUnreadCount>(_onFetchUnreadCount);
    on<NotificationStartRealtime>(_onStartRealtime);
    on<NotificationStopRealtime>(_onStopRealtime);
    on<NotificationRealtimeReceived>(_onRealtimeReceived);
    on<NotificationClearError>(_onClearError);
    on<NotificationClear>(_onClear);
  }

  @override
  Future<void> close() {
    _stopRealtime();
    return super.close();
  }

  // ---- 实时频道 ----

  void _startRealtime() {
    if (_realtimeStarted) return;
    _realtimeStarted = true;
    _realtimeChannel.subscribe();
    _realtimeSubscription = _realtimeChannel.newItemStream.listen((item) {
      if (isClosed) return;
      add(NotificationRealtimeReceived(item));
    });
    LogService.d('[NotificationBloc] 实时通道已启动');
  }

  void _stopRealtime() {
    if (!_realtimeStarted) return;
    _realtimeStarted = false;
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _realtimeChannel.unsubscribe();
    LogService.d('[NotificationBloc] 实时通道已停止');
  }

  void _onStartRealtime(
    NotificationStartRealtime event,
    Emitter<NotificationState> emit,
  ) {
    _startRealtime();
  }

  void _onStopRealtime(
    NotificationStopRealtime event,
    Emitter<NotificationState> emit,
  ) {
    _stopRealtime();
  }

  void _onRealtimeReceived(
    NotificationRealtimeReceived event,
    Emitter<NotificationState> emit,
  ) {
    final item = event.item;
    LogService.d('[NotificationBloc] 收到推送: id=${item.id} title=${item.title}');

    final filterType = state.filterType;
    final filterIsRead = state.filterIsRead;
    final matchesFilter =
        (filterType == null ||
            filterType == NotificationType.all ||
            filterType == item.type) &&
        (filterIsRead == null || filterIsRead == item.isRead);

    final updatedList = matchesFilter
        ? [item, ...state.notifications.where((n) => n.id != item.id)]
        : state.notifications;

    final newUnreadCount = item.isRead
        ? state.unreadCount
        : state.unreadCount + 1;

    emit(
      state.copyWith(
        notifications: updatedList,
        unreadCount: newUnreadCount,
        total: matchesFilter ? state.total + 1 : state.total,
      ),
    );
  }

  // ---- REST 操作 ----

  Future<void> _onFetch(
    NotificationFetch event,
    Emitter<NotificationState> emit,
  ) async {
    if (!AuthService.instance.isLoggedIn) {
      LogService.d('获取消息列表跳过：用户未登录');
      emit(state.copyWith(isLoading: false, clearError: true));
      return;
    }

    emit(
      state.copyWith(
        isLoading: true,
        clearError: true,
        filterType: event.type,
        filterIsRead: event.isRead,
        clearFilterIsRead: event.isRead == null,
      ),
    );

    try {
      final response = await _notificationApi.getNotifications(
        page: event.page,
        pageSize: _pageSize,
        type: event.type,
        isRead: event.isRead,
      );

      if (response != null) {
        final calculatedTotalPages = (response.total / _pageSize).ceil();
        final totalPages = calculatedTotalPages > 0 ? calculatedTotalPages : 1;

        emit(
          state.copyWith(
            notifications: response.items,
            currentPage: response.page,
            totalPages: totalPages,
            total: response.total,
            isLoading: false,
          ),
        );
        LogService.d('成功获取 ${response.items.length} 条消息');

        // 列表数据是当前最新值，未读数量同步刷一次
        add(const NotificationFetchUnreadCount());
      } else {
        emit(state.copyWith(isLoading: false));
      }
    } catch (e) {
      LogService.e('获取消息列表失败: $e', e);
      emit(state.copyWith(isLoading: false, error: '获取消息失败，请稍后重试'));
    }
  }

  Future<void> _onRefresh(
    NotificationRefresh event,
    Emitter<NotificationState> emit,
  ) async {
    if (!AuthService.instance.isLoggedIn) {
      LogService.d('刷新消息列表跳过：用户未登录');
      return;
    }

    if (!event.silent) {
      emit(state.copyWith(isLoading: true, clearError: true));
    }

    try {
      final response = await _notificationApi.getNotifications(
        page: 1,
        pageSize: _pageSize,
        type: state.filterType,
        isRead: state.filterIsRead,
      );

      if (response != null) {
        final calculatedTotalPages = (response.total / _pageSize).ceil();
        final totalPages = calculatedTotalPages > 0 ? calculatedTotalPages : 1;

        emit(
          state.copyWith(
            notifications: response.items,
            currentPage: response.page,
            totalPages: totalPages,
            total: response.total,
            isLoading: false,
          ),
        );

        add(const NotificationFetchUnreadCount());
      }
    } catch (e) {
      LogService.e('刷新消息列表失败: $e', e);
      if (!event.silent) {
        emit(state.copyWith(isLoading: false, error: '刷新消息失败，请稍后重试'));
      }
    }
  }

  Future<void> _onLoadMore(
    NotificationLoadMore event,
    Emitter<NotificationState> emit,
  ) async {
    if (!AuthService.instance.isLoggedIn) return;
    if (state.isLoadingMore || !state.hasMore) return;

    emit(state.copyWith(isLoadingMore: true));

    try {
      final nextPage = state.currentPage + 1;

      final response = await _notificationApi.getNotifications(
        page: nextPage,
        pageSize: _pageSize,
        type: state.filterType,
        isRead: state.filterIsRead,
      );

      if (response != null) {
        final calculatedTotalPages = (response.total / _pageSize).ceil();
        final totalPages = calculatedTotalPages > 0 ? calculatedTotalPages : 1;

        final existingIds = state.notifications.map((n) => n.id).toSet();
        final newItems = response.items
            .where((n) => !existingIds.contains(n.id))
            .toList();
        final updatedList = [...state.notifications, ...newItems];

        emit(
          state.copyWith(
            notifications: updatedList,
            currentPage: nextPage,
            totalPages: totalPages,
            total: response.total,
            isLoadingMore: false,
          ),
        );
      }
    } catch (e) {
      LogService.e('加载更多消息失败: $e', e);
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onMarkRead(
    NotificationMarkRead event,
    Emitter<NotificationState> emit,
  ) async {
    final index = state.notifications.indexWhere((n) => n.id == event.id);
    if (index == -1 || state.notifications[index].isRead) return;

    final updatedList = List<NotificationItem>.from(state.notifications);
    updatedList[index] = updatedList[index].copyWith(isRead: true);
    final newUnreadCount = state.unreadCount > 0 ? state.unreadCount - 1 : 0;

    emit(
      state.copyWith(notifications: updatedList, unreadCount: newUnreadCount),
    );

    try {
      await _notificationApi.markAsRead(event.id);
    } catch (e) {
      LogService.e('标记消息已读失败: $e', e);
      emit(
        state.copyWith(
          notifications: state.notifications,
          unreadCount: state.unreadCount + 1,
        ),
      );
    }
  }

  Future<void> _onMarkAllRead(
    NotificationMarkAllRead event,
    Emitter<NotificationState> emit,
  ) async {
    if (state.unreadCount == 0) return;

    final updatedList = state.notifications
        .map((n) => n.isRead ? n : n.copyWith(isRead: true))
        .toList();
    final previousUnreadCount = state.unreadCount;

    emit(state.copyWith(notifications: updatedList, unreadCount: 0));

    try {
      await _notificationApi.markAllAsRead();
    } catch (e) {
      LogService.e('标记所有消息已读失败: $e', e);
      emit(
        state.copyWith(
          notifications: state.notifications,
          unreadCount: previousUnreadCount,
        ),
      );
    }
  }

  Future<void> _onDelete(
    NotificationDelete event,
    Emitter<NotificationState> emit,
  ) async {
    final index = state.notifications.indexWhere((n) => n.id == event.id);
    if (index == -1) return;

    final deletedItem = state.notifications[index];
    final updatedList = List<NotificationItem>.from(state.notifications)
      ..removeAt(index);
    final newUnreadCount = !deletedItem.isRead && state.unreadCount > 0
        ? state.unreadCount - 1
        : state.unreadCount;

    emit(
      state.copyWith(
        notifications: updatedList,
        unreadCount: newUnreadCount,
        total: state.total - 1,
      ),
    );

    try {
      await _notificationApi.deleteNotification(event.id);
    } catch (e) {
      LogService.e('删除消息失败: $e', e);
      final rollbackList = List<NotificationItem>.from(updatedList)
        ..insert(index, deletedItem);
      emit(
        state.copyWith(
          notifications: rollbackList,
          unreadCount: state.unreadCount + (deletedItem.isRead ? 0 : 1),
          total: state.total + 1,
        ),
      );
    }
  }

  Future<void> _onFetchUnreadCount(
    NotificationFetchUnreadCount event,
    Emitter<NotificationState> emit,
  ) async {
    if (!AuthService.instance.isLoggedIn) {
      LogService.d('获取未读消息数量跳过：用户未登录');
      return;
    }

    try {
      final count = await _notificationApi.getUnreadCount();
      emit(state.copyWith(unreadCount: count));
    } catch (e) {
      LogService.e('获取未读消息数量失败: $e', e);
    }
  }

  void _onClearError(
    NotificationClearError event,
    Emitter<NotificationState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  void _onClear(NotificationClear event, Emitter<NotificationState> emit) {
    _stopRealtime();
    emit(const NotificationState());
    LogService.d('消息数据已清除');
  }
}
