import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import '../utils/server_time_converter.dart';
import 'map_contribution_models.dart';

part 'guide_models.g.dart';

// ─── 枚举 ───────────────────────────────────────────────────────────────────

/// 攻略状态
enum GuideStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('pending')
  pending,
  @JsonValue('published')
  published,
  @JsonValue('rejected')
  rejected,
  @JsonValue('off_shelf')
  offShelf,
  @JsonValue('deleted')
  deleted;

  String get value => switch (this) {
    GuideStatus.draft => 'draft',
    GuideStatus.pending => 'pending',
    GuideStatus.published => 'published',
    GuideStatus.rejected => 'rejected',
    GuideStatus.offShelf => 'off_shelf',
    GuideStatus.deleted => 'deleted',
  };

  String get label => switch (this) {
    GuideStatus.draft => '草稿',
    GuideStatus.pending => '待审核',
    GuideStatus.published => '已发布',
    GuideStatus.rejected => '已驳回',
    GuideStatus.offShelf => '已下架',
    GuideStatus.deleted => '已删除',
  };
}

/// 攻略排序方式
enum GuideSortBy {
  @JsonValue('latest')
  latest,
  @JsonValue('hot')
  hot,
  @JsonValue('mostLiked')
  mostLiked,
  @JsonValue('mostFavored')
  mostFavored,
  @JsonValue('mostViewed')
  mostViewed,
  @JsonValue('recommended')
  recommended;

  String get value => switch (this) {
    GuideSortBy.latest => 'latest',
    GuideSortBy.hot => 'hot',
    GuideSortBy.mostLiked => 'mostLiked',
    GuideSortBy.mostFavored => 'mostFavored',
    GuideSortBy.mostViewed => 'mostViewed',
    GuideSortBy.recommended => 'recommended',
  };

  String get label => switch (this) {
    GuideSortBy.latest => '最新',
    GuideSortBy.hot => '最热',
    GuideSortBy.mostLiked => '最多点赞',
    GuideSortBy.mostFavored => '最多收藏',
    GuideSortBy.mostViewed => '最多浏览',
    GuideSortBy.recommended => '推荐',
  };
}

/// 互动类型
enum GuideReactionType {
  @JsonValue('like')
  like,
  @JsonValue('favorite')
  favorite,
  @JsonValue('view')
  view,
  @JsonValue('share')
  share;

  String get value => switch (this) {
    GuideReactionType.like => 'like',
    GuideReactionType.favorite => 'favorite',
    GuideReactionType.view => 'view',
    GuideReactionType.share => 'share',
  };
}

/// 举报原因
enum ReportReason {
  @JsonValue('spam')
  spam,
  @JsonValue('abuse')
  abuse,
  @JsonValue('porn')
  porn,
  @JsonValue('politics')
  politics,
  @JsonValue('plagiarism')
  plagiarism,
  @JsonValue('misleading')
  misleading,
  @JsonValue('other')
  other;

  String get value => switch (this) {
    ReportReason.spam => 'spam',
    ReportReason.abuse => 'abuse',
    ReportReason.porn => 'porn',
    ReportReason.politics => 'politics',
    ReportReason.plagiarism => 'plagiarism',
    ReportReason.misleading => 'misleading',
    ReportReason.other => 'other',
  };

  String get label => switch (this) {
    ReportReason.spam => '垃圾广告',
    ReportReason.abuse => '辱骂攻击',
    ReportReason.porn => '色情低俗',
    ReportReason.politics => '政治敏感',
    ReportReason.plagiarism => '抄袭搬运',
    ReportReason.misleading => '误导信息',
    ReportReason.other => '其他',
  };
}


// ─── 数据类 ─────────────────────────────────────────────────────────────────

/// 攻略分类定义（由后端下发，客户端不硬编码）
@JsonSerializable()
class GuideCategoryDef extends Equatable {
  final String code;
  final String name;
  final String? description;
  final String? icon;
  final String? colorHex;
  @JsonKey(defaultValue: 0)
  final int sortOrder;
  @JsonKey(defaultValue: true)
  final bool isActive;
  @JsonKey(defaultValue: false)
  final bool isAdminOnly;
  @JsonKey(defaultValue: 0)
  final int count;

  const GuideCategoryDef({
    required this.code,
    required this.name,
    this.description,
    this.icon,
    this.colorHex,
    this.sortOrder = 0,
    this.isActive = true,
    this.isAdminOnly = false,
    this.count = 0,
  });

  factory GuideCategoryDef.fromJson(Map<String, dynamic> json) =>
      _$GuideCategoryDefFromJson(json);
  Map<String, dynamic> toJson() => _$GuideCategoryDefToJson(this);

  @override
  List<Object?> get props => [
    code,
    name,
    description,
    icon,
    colorHex,
    sortOrder,
    isActive,
    isAdminOnly,
    count,
  ];
}

/// 攻略列表项
@JsonSerializable()
class GuideListItem extends Equatable {
  final int id;
  final String title;
  final String? summary;
  final String? coverUrl;

  /// 分类 code（对应 GuideCategoryDef.code）
  @JsonKey(name: 'category')
  final String? category;
  final String? categoryName;
  final String? categoryColorHex;

  @JsonKey(defaultValue: <String>[])
  final List<String> tags;

  /// 关联地图名称（MapInfo.mapName）
  final String? mapName;
  final String? mapLabel;
  final String? mapBackground;

  @JsonKey(defaultValue: false)
  final bool hasVideo;

  final int authorId;
  final String authorName;
  final String? authorAvatar;

  @JsonKey(defaultValue: 0)
  final int viewCount;
  @JsonKey(defaultValue: 0)
  final int likeCount;
  @JsonKey(defaultValue: 0)
  final int favoriteCount;
  @JsonKey(defaultValue: 0)
  final int commentCount;

  @JsonKey(defaultValue: false)
  final bool isLiked;
  @JsonKey(defaultValue: false)
  final bool isFavorited;
  @JsonKey(defaultValue: false)
  final bool isRecommended;
  @JsonKey(defaultValue: false)
  final bool isPinned;
  @JsonKey(defaultValue: false)
  final bool isHot;

  final GuideStatus status;

  final String? rejectReason;

  @ServerTimeConverter()
  final DateTime createdAt;
  @NullableServerTimeConverter()
  final DateTime? publishedAt;
  @ServerTimeConverter()
  final DateTime updatedAt;

  /// 删除时间（仅回收站项）
  @NullableServerTimeConverter()
  final DateTime? deletedAt;

  /// 距永久删除剩余天数（仅回收站项）
  @JsonKey(defaultValue: 0)
  final int expireDays;

  const GuideListItem({
    required this.id,
    required this.title,
    this.summary,
    this.coverUrl,
    this.category,
    this.categoryName,
    this.categoryColorHex,
    this.tags = const [],
    this.mapName,
    this.mapLabel,
    this.mapBackground,
    this.hasVideo = false,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.viewCount = 0,
    this.likeCount = 0,
    this.favoriteCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.isFavorited = false,
    this.isRecommended = false,
    this.isPinned = false,
    this.isHot = false,
    required this.status,
    this.rejectReason,
    required this.createdAt,
    this.publishedAt,
    required this.updatedAt,
    this.deletedAt,
    this.expireDays = 0,
  });

  factory GuideListItem.fromJson(Map<String, dynamic> json) =>
      _$GuideListItemFromJson(json);
  Map<String, dynamic> toJson() => _$GuideListItemToJson(this);

  @override
  List<Object?> get props => [
    id,
    title,
    summary,
    coverUrl,
    category,
    categoryName,
    categoryColorHex,
    tags,
    mapName,
    mapLabel,
    mapBackground,
    hasVideo,
    authorId,
    authorName,
    authorAvatar,
    viewCount,
    likeCount,
    favoriteCount,
    commentCount,
    isLiked,
    isFavorited,
    isRecommended,
    isPinned,
    isHot,
    status,
    rejectReason,
    createdAt,
    publishedAt,
    updatedAt,
    deletedAt,
    expireDays,
  ];
}

/// 攻略详情（继承 [GuideListItem]，增加正文、附件、目录等字段）
@JsonSerializable()
class Guide extends GuideListItem {
  final String? content;
  @JsonKey(defaultValue: <Attachment>[])
  final List<Attachment> attachments;
  @JsonKey(defaultValue: <VideoEmbed>[])
  final List<VideoEmbed> videoEmbeds;
  @JsonKey(defaultValue: <TocItem>[])
  final List<TocItem> tocItems;

  /// 关联地图详细信息（复用 map_contribution_models.dart#MapInfo）
  final MapInfo? mapInfo;

  @JsonKey(defaultValue: 0)
  final int readingTimeMin;
  @JsonKey(defaultValue: 1)
  final int version;
  @JsonKey(defaultValue: <int>[])
  final List<int> relatedGuideIds;

  const Guide({
    required super.id,
    required super.title,
    super.summary,
    super.coverUrl,
    super.category,
    super.categoryName,
    super.categoryColorHex,
    super.tags,
    super.mapName,
    super.mapLabel,
    super.mapBackground,
    super.hasVideo,
    required super.authorId,
    required super.authorName,
    super.authorAvatar,
    super.viewCount,
    super.likeCount,
    super.favoriteCount,
    super.commentCount,
    super.isLiked,
    super.isFavorited,
    super.isRecommended,
    super.isPinned,
    super.isHot,
    required super.status,
    super.rejectReason,
    required super.createdAt,
    super.publishedAt,
    required super.updatedAt,
    super.deletedAt,
    super.expireDays,
    this.content,
    this.attachments = const [],
    this.videoEmbeds = const [],
    this.tocItems = const [],
    this.mapInfo,
    this.readingTimeMin = 0,
    this.version = 1,
    this.relatedGuideIds = const [],
  });

  factory Guide.fromJson(Map<String, dynamic> json) => _$GuideFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$GuideToJson(this);

  @override
  List<Object?> get props => [
    ...super.props,
    content,
    attachments,
    videoEmbeds,
    tocItems,
    mapInfo,
    readingTimeMin,
    version,
    relatedGuideIds,
  ];
}

/// 附件
@JsonSerializable()
class Attachment extends Equatable {
  final String fileId;
  final String url;
  final String? thumbUrl;
  final int? width;
  final int? height;
  final int? sizeBytes;
  final String? mimeType;

  const Attachment({
    required this.fileId,
    required this.url,
    this.thumbUrl,
    this.width,
    this.height,
    this.sizeBytes,
    this.mimeType,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) =>
      _$AttachmentFromJson(json);
  Map<String, dynamic> toJson() => _$AttachmentToJson(this);

  @override
  List<Object?> get props => [
    fileId,
    url,
    thumbUrl,
    width,
    height,
    sizeBytes,
    mimeType,
  ];
}

/// B 站视频嵌入
@JsonSerializable()
class VideoEmbed extends Equatable {
  final String bvid;
  final String url;
  final String? title;
  final String? coverUrl;
  final int? durationSec;

  const VideoEmbed({
    required this.bvid,
    required this.url,
    this.title,
    this.coverUrl,
    this.durationSec,
  });

  factory VideoEmbed.fromJson(Map<String, dynamic> json) =>
      _$VideoEmbedFromJson(json);
  Map<String, dynamic> toJson() => _$VideoEmbedToJson(this);

  @override
  List<Object?> get props => [bvid, url, title, coverUrl, durationSec];
}

/// 目录项
@JsonSerializable()
class TocItem extends Equatable {
  final String id;
  final int level;
  final String title;

  const TocItem({required this.id, required this.level, required this.title});

  factory TocItem.fromJson(Map<String, dynamic> json) =>
      _$TocItemFromJson(json);
  Map<String, dynamic> toJson() => _$TocItemToJson(this);

  @override
  List<Object?> get props => [id, level, title];
}

/// 攻略评论
@JsonSerializable()
class GuideComment extends Equatable {
  final int id;
  final int guideId;
  final int? parentId;
  final int? replyToId;
  final String? replyToName;
  final String content;
  @JsonKey(defaultValue: <String>[])
  final List<String> images;
  final int authorId;
  final String authorName;
  final String? authorAvatar;
  @JsonKey(defaultValue: 0)
  final int likeCount;
  @JsonKey(defaultValue: false)
  final bool isLiked;
  @JsonKey(defaultValue: 0)
  final int dislikeCount;
  @JsonKey(defaultValue: false)
  final bool isDisliked;
  @JsonKey(defaultValue: 0)
  final int replyCount;
  @JsonKey(defaultValue: <GuideComment>[])
  final List<GuideComment> replies;
  @JsonKey(defaultValue: false)
  final bool isAuthor;
  @JsonKey(defaultValue: false)
  final bool isDeleted;
  @ServerTimeConverter()
  final DateTime createdAt;

  const GuideComment({
    required this.id,
    required this.guideId,
    this.parentId,
    this.replyToId,
    this.replyToName,
    required this.content,
    this.images = const [],
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.likeCount = 0,
    this.isLiked = false,
    this.dislikeCount = 0,
    this.isDisliked = false,
    this.replyCount = 0,
    this.replies = const [],
    this.isAuthor = false,
    this.isDeleted = false,
    required this.createdAt,
  });

  factory GuideComment.fromJson(Map<String, dynamic> json) =>
      _$GuideCommentFromJson(json);
  Map<String, dynamic> toJson() => _$GuideCommentToJson(this);

  GuideComment copyWith({
    int? id,
    int? guideId,
    int? parentId,
    int? replyToId,
    String? replyToName,
    String? content,
    List<String>? images,
    int? authorId,
    String? authorName,
    String? authorAvatar,
    int? likeCount,
    bool? isLiked,
    bool? isDisliked,
    int? dislikeCount,
    int? replyCount,
    List<GuideComment>? replies,
    bool? isAuthor,
    bool? isDeleted,
    DateTime? createdAt,
  }) {
    return GuideComment(
      id: id ?? this.id,
      guideId: guideId ?? this.guideId,
      parentId: parentId ?? this.parentId,
      replyToId: replyToId ?? this.replyToId,
      replyToName: replyToName ?? this.replyToName,
      content: content ?? this.content,
      images: images ?? this.images,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      isDisliked: isDisliked ?? this.isDisliked,
      dislikeCount: dislikeCount ?? this.dislikeCount,
      replyCount: replyCount ?? this.replyCount,
      replies: replies ?? this.replies,
      isAuthor: isAuthor ?? this.isAuthor,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    guideId,
    parentId,
    replyToId,
    replyToName,
    content,
    images,
    authorId,
    authorName,
    authorAvatar,
    likeCount,
    isLiked,
    isDisliked,
    dislikeCount,
    replyCount,
    replies,
    isAuthor,
    isDeleted,
    createdAt,
  ];
}

/// 攻略举报
@JsonSerializable()
class GuideReport extends Equatable {
  final int targetId;
  final String targetType;
  final ReportReason reason;
  final String? description;
  @JsonKey(defaultValue: <String>[])
  final List<String> evidenceImages;

  const GuideReport({
    required this.targetId,
    required this.targetType,
    required this.reason,
    this.description,
    this.evidenceImages = const [],
  });

  factory GuideReport.fromJson(Map<String, dynamic> json) =>
      _$GuideReportFromJson(json);
  Map<String, dynamic> toJson() => _$GuideReportToJson(this);

  @override
  List<Object?> get props => [
    targetId,
    targetType,
    reason,
    description,
    evidenceImages,
  ];
}

/// 攻略草稿
@JsonSerializable()
class GuideDraft extends Equatable {
  final String draftId;
  final int? guideId;
  final String? title;
  final String? coverUrl;

  /// 分类 code（对应 GuideCategoryDef.code）
  @JsonKey(name: 'category')
  final String? category;

  @JsonKey(defaultValue: <String>[])
  final List<String> tags;

  /// 关联地图名称（MapInfo.mapName）
  final String? mapName;

  final String? summary;
  final String? content;
  @JsonKey(defaultValue: <VideoEmbed>[])
  final List<VideoEmbed> videoEmbeds;
  @JsonKey(defaultValue: 1)
  final int version;
  @NullableServerTimeConverter()
  final DateTime? updatedAt;

  const GuideDraft({
    required this.draftId,
    this.guideId,
    this.title,
    this.coverUrl,
    this.category,
    this.tags = const [],
    this.mapName,
    this.summary,
    this.content,
    this.videoEmbeds = const [],
    this.version = 1,
    this.updatedAt,
  });

  factory GuideDraft.fromJson(Map<String, dynamic> json) =>
      _$GuideDraftFromJson(json);
  Map<String, dynamic> toJson() => _$GuideDraftToJson(this);

  @override
  List<Object?> get props => [
    draftId,
    guideId,
    title,
    coverUrl,
    category,
    tags,
    mapName,
    summary,
    content,
    videoEmbeds,
    version,
    updatedAt,
  ];
}

/// 我的中心 — 用户统计概览
///
/// 字段缺失时按 0 兜底，前端不应阻塞渲染。
@JsonSerializable()
class GuideUserStats extends Equatable {
  /// 已发布攻略总数
  @JsonKey(defaultValue: 0)
  final int guideCount;

  /// 累计浏览量（聚合所有已发布攻略）
  @JsonKey(defaultValue: 0)
  final int totalViews;

  /// 累计获赞数（聚合所有已发布攻略）
  @JsonKey(defaultValue: 0)
  final int totalLikes;

  /// 累计收藏数（聚合所有已发布攻略）
  @JsonKey(defaultValue: 0)
  final int totalFavorites;

  const GuideUserStats({
    this.guideCount = 0,
    this.totalViews = 0,
    this.totalLikes = 0,
    this.totalFavorites = 0,
  });

  factory GuideUserStats.fromJson(Map<String, dynamic> json) =>
      _$GuideUserStatsFromJson(json);
  Map<String, dynamic> toJson() => _$GuideUserStatsToJson(this);

  static const empty = GuideUserStats();

  @override
  List<Object?> get props => [
    guideCount,
    totalViews,
    totalLikes,
    totalFavorites,
  ];
}
