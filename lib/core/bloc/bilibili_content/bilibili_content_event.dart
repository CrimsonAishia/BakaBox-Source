import 'package:equatable/equatable.dart';
import '../../models/bilibili_content_models.dart';

/// 直播间事件
abstract class BilibiliContentEvent extends Equatable {
  const BilibiliContentEvent();

  @override
  List<Object?> get props => [];
}

/// 获取内容列表
class BilibiliContentFetchRequested extends BilibiliContentEvent {
  final bool refresh;
  final int? tabIndex;
  final int? pageIndex;

  const BilibiliContentFetchRequested({
    this.refresh = false,
    this.tabIndex,
    this.pageIndex,
  });

  @override
  List<Object?> get props => [refresh, tabIndex, pageIndex];
}

/// Tab 切换
class BilibiliContentTabChanged extends BilibiliContentEvent {
  final int tabIndex; // 0: 直播间, 1: 视频

  const BilibiliContentTabChanged(this.tabIndex);

  @override
  List<Object?> get props => [tabIndex];
}

/// 添加内容
class BilibiliContentAddRequested extends BilibiliContentEvent {
  final String contentId; // 直播间ID或BV号
  final BilibiliContentType contentType;
  final String? title;
  final String? coverUrl;
  final String? ownerUid;
  final String? ownerName;
  final String? ownerFace;
  final String? publishedAt;
  final int? duration;
  final int? categoryId; // 视频分类ID

  const BilibiliContentAddRequested({
    required this.contentId,
    required this.contentType,
    this.title,
    this.coverUrl,
    this.ownerUid,
    this.ownerName,
    this.ownerFace,
    this.publishedAt,
    this.duration,
    this.categoryId,
    this.liveStatus,
    this.popularity,
    this.followerCount,
    this.playCount,
    this.likeCount,
    this.coinCount,
    this.favoriteCount,
  });

  final int? liveStatus;
  final int? popularity;
  final int? followerCount;

  final int? playCount;
  final int? likeCount;
  final int? coinCount;
  final int? favoriteCount;

  @override
  List<Object?> get props => [
    contentId,
    contentType,
    title,
    coverUrl,
    ownerUid,
    ownerName,
    ownerFace,
    publishedAt,
    duration,
    categoryId,
    liveStatus,
    popularity,
    followerCount,
    playCount,
    likeCount,
    coinCount,
    favoriteCount,
  ];
}

/// 编辑内容
class BilibiliContentUpdateRequested extends BilibiliContentEvent {
  final String id;
  final BilibiliContentType contentType;
  // 直播间字段
  final String? roomId;
  // 视频字段
  final String? bvid;
  final String? title;
  final String? coverUrl;
  final String? ownerUid;
  final String? ownerName;
  final String? ownerFace;
  final String? publishedAt;
  final int? duration;
  final int? categoryId; // 视频分类ID

  const BilibiliContentUpdateRequested({
    required this.id,
    required this.contentType,
    this.roomId,
    this.bvid,
    this.title,
    this.coverUrl,
    this.ownerUid,
    this.ownerName,
    this.ownerFace,
    this.publishedAt,
    this.duration,
    this.categoryId,
    this.liveStatus,
    this.popularity,
    this.followerCount,
    this.playCount,
    this.likeCount,
    this.coinCount,
    this.favoriteCount,
  });

  final int? liveStatus;
  final int? popularity;
  final int? followerCount;

  final int? playCount;
  final int? likeCount;
  final int? coinCount;
  final int? favoriteCount;

  @override
  List<Object?> get props => [
    id,
    contentType,
    roomId,
    bvid,
    title,
    coverUrl,
    ownerUid,
    ownerName,
    ownerFace,
    publishedAt,
    duration,
    categoryId,
    liveStatus,
    popularity,
    followerCount,
    playCount,
    likeCount,
    coinCount,
    favoriteCount,
  ];
}

/// 启用/停用直播间
class BilibiliContentToggleLiveRoomRequested extends BilibiliContentEvent {
  final String id;
  final bool enabled;

  const BilibiliContentToggleLiveRoomRequested({
    required this.id,
    required this.enabled,
  });

  @override
  List<Object?> get props => [id, enabled];
}

/// 刷新直播状态
class BilibiliContentRefreshStatusRequested extends BilibiliContentEvent {
  const BilibiliContentRefreshStatusRequested();
}

/// 搜索过滤
class BilibiliContentSearchChanged extends BilibiliContentEvent {
  final String query;

  const BilibiliContentSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

/// 视频审核状态筛选过滤
class BilibiliContentVideoAuditFilterChanged extends BilibiliContentEvent {
  final String? auditStatus; // null = 全部, pending/approved/rejected

  const BilibiliContentVideoAuditFilterChanged(this.auditStatus);

  @override
  List<Object?> get props => [auditStatus];
}

/// 视频分类筛选过滤
class BilibiliContentVideoCategoryFilterChanged extends BilibiliContentEvent {
  final int? categoryId; // null = 全部

  const BilibiliContentVideoCategoryFilterChanged(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

/// 获取视频分类列表
class BilibiliContentFetchCategoriesRequested extends BilibiliContentEvent {
  const BilibiliContentFetchCategoriesRequested();
}

/// 获取我的内容（用户中心使用）
class BilibiliContentFetchMyRequested extends BilibiliContentEvent {
  const BilibiliContentFetchMyRequested();
}

/// 增加直播间点击数
class BilibiliContentIncreaseLiveRoomViewRequested
    extends BilibiliContentEvent {
  final String id;

  const BilibiliContentIncreaseLiveRoomViewRequested({required this.id});

  @override
  List<Object?> get props => [id];
}

/// 增加视频点击数
class BilibiliContentIncreaseVideoViewRequested extends BilibiliContentEvent {
  final String id;

  const BilibiliContentIncreaseVideoViewRequested({required this.id});

  @override
  List<Object?> get props => [id];
}

/// 清除操作结果状态（用于Toast显示后重置）
class BilibiliContentClearOperationResult extends BilibiliContentEvent {
  const BilibiliContentClearOperationResult();
}

/// 删除内容
class BilibiliContentDeleteRequested extends BilibiliContentEvent {
  final String id;
  final BilibiliContentType contentType;

  const BilibiliContentDeleteRequested({
    required this.id,
    required this.contentType,
  });

  @override
  List<Object?> get props => [id, contentType];
}

/// 修改视频排序方式
class BilibiliContentVideoSortChanged extends BilibiliContentEvent {
  final String sort; // 'view_count' 或 'newest'

  const BilibiliContentVideoSortChanged(this.sort);

  @override
  List<Object?> get props => [sort];
}
