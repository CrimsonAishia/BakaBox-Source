import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/notification_api.dart';
import '../../models/notification_models.dart';
import '../../services/auth_service.dart';
import '../../services/scheduler_service.dart';
import '../../utils/log_service.dart';
import 'notification_event.dart';
import 'notification_state.dart';

/// 消息 BLoC
///
/// 负责管理消息的获取、刷新、标记已读、删除等操作
/// 支持自动刷新未读数量（默认5分钟）
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationApi _notificationApi;
  final SchedulerService _scheduler = SchedulerService();

  static const String _taskId = 'notification_auto_refresh';
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
    on<NotificationStartAutoRefresh>(_onStartAutoRefresh);
    on<NotificationStopAutoRefresh>(_onStopAutoRefresh);
    on<NotificationClearError>(_onClearError);
  }

  /// 启动自动刷新
  void _startAutoRefresh() {
    _stopAutoRefresh();
    _scheduler.register(
      ScheduledTask(
        id: _taskId,
        name: '消息未读数量自动刷新',
        interval: Intervals.fiveMinutes,
        callback: () async {
          // 检查用户是否已登录，未登录时跳过请求
          if (!AuthService.instance.isLoggedIn) {
            LogService.d('消息未读数量自动刷新跳过：用户未登录');
            return;
          }
          LogService.d('消息未读数量自动刷新触发');
          add(const NotificationFetchUnreadCount());
        },
      ),
    );
    LogService.d('消息自动刷新已启动，间隔: 5 分钟');
  }

  /// 停止自动刷新
  void _stopAutoRefresh() {
    _scheduler.cancel(_taskId);
  }

  @override
  Future<void> close() {
    _stopAutoRefresh();
    return super.close();
  }

  /// 处理获取消息列表事件
  Future<void> _onFetch(
    NotificationFetch event,
    Emitter<NotificationState> emit,
  ) async {
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
      LogService.d('开始获取消息列表');

      final response = await _notificationApi.getNotifications(
        page: event.page,
        pageSize: _pageSize,
        type: event.type,
        isRead: event.isRead,
      );

      if (response != null) {
        // 服务端 totalPages 可能不正确，根据 total 和 pageSize 计算
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

        // 获取准确的未读数量
        add(const NotificationFetchUnreadCount());
      } else {
        emit(state.copyWith(isLoading: false));
      }
    } catch (e) {
      LogService.e('获取消息列表失败: $e', e);
      emit(state.copyWith(isLoading: false, error: '获取消息失败，请稍后重试'));
    }
  }

  /// 处理刷新消息列表事件
  Future<void> _onRefresh(
    NotificationRefresh event,
    Emitter<NotificationState> emit,
  ) async {
    if (!event.silent) {
      emit(state.copyWith(isLoading: true, clearError: true));
    }

    try {
      LogService.d('开始${event.silent ? "静默" : ""}刷新消息列表');

      final response = await _notificationApi.getNotifications(
        page: 1,
        pageSize: _pageSize,
        type: state.filterType,
        isRead: state.filterIsRead,
      );

      if (response != null) {
        // 服务端 totalPages 可能不正确，根据 total 和 pageSize 计算
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
        LogService.d(
          '成功刷新消息列表，共 ${response.items.length} 条, totalPages: $totalPages',
        );

        // 获取准确的未读数量
        add(const NotificationFetchUnreadCount());
      }
    } catch (e) {
      LogService.e('刷新消息列表失败: $e', e);
      if (!event.silent) {
        emit(state.copyWith(isLoading: false, error: '刷新消息失败，请稍后重试'));
      }
    }
  }

  /// 处理加载更多事件
  Future<void> _onLoadMore(
    NotificationLoadMore event,
    Emitter<NotificationState> emit,
  ) async {
    if (state.isLoadingMore || !state.hasMore) return;

    emit(state.copyWith(isLoadingMore: true));

    try {
      final nextPage = state.currentPage + 1;
      LogService.d('加载更多消息, page: $nextPage');

      final response = await _notificationApi.getNotifications(
        page: nextPage,
        pageSize: _pageSize,
        type: state.filterType,
        isRead: state.filterIsRead,
      );

      if (response != null) {
        // 服务端 totalPages 可能不正确，根据 total 和 pageSize 计算
        final calculatedTotalPages = (response.total / _pageSize).ceil();
        final totalPages = calculatedTotalPages > 0 ? calculatedTotalPages : 1;

        // 去重：根据 id 过滤已存在的消息
        final existingIds = state.notifications.map((n) => n.id).toSet();
        final newItems = response.items
            .where((n) => !existingIds.contains(n.id))
            .toList();
        final updatedList = [...state.notifications, ...newItems];

        emit(
          state.copyWith(
            notifications: updatedList,
            // 使用请求的页码，而不是响应的页码（服务端可能不返回正确的 page）
            currentPage: nextPage,
            totalPages: totalPages,
            total: response.total,
            isLoadingMore: false,
          ),
        );
        LogService.d('成功加载更多，当前共 ${updatedList.length} 条');
      }
    } catch (e) {
      LogService.e('加载更多消息失败: $e', e);
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  /// 处理标记单个消息已读事件
  Future<void> _onMarkRead(
    NotificationMarkRead event,
    Emitter<NotificationState> emit,
  ) async {
    // 查找消息
    final index = state.notifications.indexWhere((n) => n.id == event.id);
    if (index == -1 || state.notifications[index].isRead) return;

    // 乐观更新
    final updatedList = List<NotificationItem>.from(state.notifications);
    updatedList[index] = updatedList[index].copyWith(isRead: true);
    final newUnreadCount = state.unreadCount > 0 ? state.unreadCount - 1 : 0;

    emit(
      state.copyWith(notifications: updatedList, unreadCount: newUnreadCount),
    );

    try {
      await _notificationApi.markAsRead(event.id);
      LogService.d('消息 ${event.id} 已标记为已读');
    } catch (e) {
      LogService.e('标记消息已读失败: $e', e);
      // 回滚
      emit(
        state.copyWith(
          notifications: state.notifications,
          unreadCount: state.unreadCount + 1,
        ),
      );
    }
  }

  /// 处理标记所有消息已读事件
  Future<void> _onMarkAllRead(
    NotificationMarkAllRead event,
    Emitter<NotificationState> emit,
  ) async {
    if (state.unreadCount == 0) return;

    // 乐观更新
    final updatedList = state.notifications
        .map((n) => n.isRead ? n : n.copyWith(isRead: true))
        .toList();
    final previousUnreadCount = state.unreadCount;

    emit(state.copyWith(notifications: updatedList, unreadCount: 0));

    try {
      await _notificationApi.markAllAsRead();
      LogService.d('所有消息已标记为已读');
    } catch (e) {
      LogService.e('标记所有消息已读失败: $e', e);
      // 回滚
      emit(
        state.copyWith(
          notifications: state.notifications,
          unreadCount: previousUnreadCount,
        ),
      );
    }
  }

  /// 处理删除消息事件
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
      LogService.d('消息 ${event.id} 已删除');
    } catch (e) {
      LogService.e('删除消息失败: $e', e);
      // 回滚
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

  /// 处理获取未读数量事件
  Future<void> _onFetchUnreadCount(
    NotificationFetchUnreadCount event,
    Emitter<NotificationState> emit,
  ) async {
    // 检查用户是否已登录，未登录时跳过请求
    if (!AuthService.instance.isLoggedIn) {
      LogService.d('获取未读消息数量跳过：用户未登录');
      return;
    }

    try {
      final count = await _notificationApi.getUnreadCount();
      emit(state.copyWith(unreadCount: count));
      LogService.d('未读消息数量: $count');
    } catch (e) {
      LogService.e('获取未读消息数量失败: $e', e);
    }
  }

  /// 处理启动自动刷新事件
  void _onStartAutoRefresh(
    NotificationStartAutoRefresh event,
    Emitter<NotificationState> emit,
  ) {
    _startAutoRefresh();
  }

  /// 处理停止自动刷新事件
  void _onStopAutoRefresh(
    NotificationStopAutoRefresh event,
    Emitter<NotificationState> emit,
  ) {
    _stopAutoRefresh();
    LogService.i('消息自动刷新已停止');
  }

  /// 处理清除错误事件
  void _onClearError(
    NotificationClearError event,
    Emitter<NotificationState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }
}
