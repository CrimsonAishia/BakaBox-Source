import 'package:equatable/equatable.dart';
import '../../models/notification_models.dart';

/// 消息状态
class NotificationState extends Equatable {
  /// 消息列表
  final List<NotificationItem> notifications;

  /// 未读数量
  final int unreadCount;

  /// 当前页码
  final int currentPage;

  /// 总页数
  final int totalPages;

  /// 总数量
  final int total;

  /// 是否正在加载
  final bool isLoading;

  /// 是否正在加载更多
  final bool isLoadingMore;

  /// 错误信息
  final String? error;

  /// 筛选类型
  final String? filterType;

  /// 筛选已读状态
  final bool? filterIsRead;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.currentPage = 1,
    this.totalPages = 1,
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.filterType,
    this.filterIsRead,
  });

  /// 是否有更多数据
  bool get hasMore => currentPage < totalPages;

  /// 是否有未读通知
  bool get hasUnread => unreadCount > 0;

  NotificationState copyWith({
    List<NotificationItem>? notifications,
    int? unreadCount,
    int? currentPage,
    int? totalPages,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? filterType,
    bool? filterIsRead,
    bool clearError = false,
    bool clearFilterIsRead = false,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      filterType: filterType ?? this.filterType,
      filterIsRead: clearFilterIsRead
          ? null
          : (filterIsRead ?? this.filterIsRead),
    );
  }

  @override
  List<Object?> get props => [
    notifications,
    unreadCount,
    currentPage,
    totalPages,
    total,
    isLoading,
    isLoadingMore,
    error,
    filterType,
    filterIsRead,
  ];
}
