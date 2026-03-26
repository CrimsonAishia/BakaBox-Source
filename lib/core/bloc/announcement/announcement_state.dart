import 'package:equatable/equatable.dart';
import '../../models/announcement_models.dart';

/// 公告状态
class AnnouncementState extends Equatable {
  /// 公告列表（已排序：置顶优先、优先级降序、创建时间降序）
  final List<AnnouncementItem> announcements;

  /// 已读公告ID集合
  final Set<int> readIds;

  /// 是否正在加载
  final bool isLoading;

  /// 错误信息
  final String? error;

  /// 当前查看的公告详情
  final AnnouncementItem? currentDetail;

  /// 是否正在加载详情
  final bool isLoadingDetail;

  const AnnouncementState({
    this.announcements = const [],
    this.readIds = const {},
    this.isLoading = false,
    this.error,
    this.currentDetail,
    this.isLoadingDetail = false,
  });

  /// 未读公告数量
  int get unreadCount {
    return announcements.where((item) => !readIds.contains(item.id)).length;
  }

  /// 检查指定公告是否已读
  bool isRead(int announcementId) => readIds.contains(announcementId);

  /// 复制状态并更新指定字段
  AnnouncementState copyWith({
    List<AnnouncementItem>? announcements,
    Set<int>? readIds,
    bool? isLoading,
    String? error,
    bool clearError = false,
    AnnouncementItem? currentDetail,
    bool clearDetail = false,
    bool? isLoadingDetail,
  }) {
    return AnnouncementState(
      announcements: announcements ?? this.announcements,
      readIds: readIds ?? this.readIds,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      currentDetail: clearDetail ? null : (currentDetail ?? this.currentDetail),
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
    );
  }

  @override
  List<Object?> get props => [
    announcements,
    readIds,
    isLoading,
    error,
    currentDetail,
    isLoadingDetail,
  ];
}
