// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guide_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GuideCategoryDef _$GuideCategoryDefFromJson(Map<String, dynamic> json) =>
    GuideCategoryDef(
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      colorHex: json['colorHex'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      isAdminOnly: json['isAdminOnly'] as bool? ?? false,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$GuideCategoryDefToJson(GuideCategoryDef instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'description': instance.description,
      'icon': instance.icon,
      'colorHex': instance.colorHex,
      'sortOrder': instance.sortOrder,
      'isActive': instance.isActive,
      'isAdminOnly': instance.isAdminOnly,
      'count': instance.count,
    };

GuideListItem _$GuideListItemFromJson(
  Map<String, dynamic> json,
) => GuideListItem(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  summary: json['summary'] as String?,
  coverUrl: json['coverUrl'] as String?,
  category: json['category'] as String?,
  categoryName: json['categoryName'] as String?,
  categoryColorHex: json['categoryColorHex'] as String?,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
  mapName: json['mapName'] as String?,
  mapLabel: json['mapLabel'] as String?,
  mapBackground: json['mapBackground'] as String?,
  hasVideo: json['hasVideo'] as bool? ?? false,
  authorId: (json['authorId'] as num).toInt(),
  authorName: json['authorName'] as String,
  authorAvatar: json['authorAvatar'] as String?,
  viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
  likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
  favoriteCount: (json['favoriteCount'] as num?)?.toInt() ?? 0,
  commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
  isLiked: json['isLiked'] as bool? ?? false,
  isFavorited: json['isFavorited'] as bool? ?? false,
  isRecommended: json['isRecommended'] as bool? ?? false,
  isPinned: json['isPinned'] as bool? ?? false,
  status: $enumDecode(_$GuideStatusEnumMap, json['status']),
  rejectReason: json['rejectReason'] as String?,
  createdAt: const ServerTimeConverter().fromJson(json['createdAt'] as String),
  publishedAt: const NullableServerTimeConverter().fromJson(
    json['publishedAt'] as String?,
  ),
  updatedAt: const ServerTimeConverter().fromJson(json['updatedAt'] as String),
  deletedAt: const NullableServerTimeConverter().fromJson(
    json['deletedAt'] as String?,
  ),
  expireDays: (json['expireDays'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$GuideListItemToJson(
  GuideListItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'summary': instance.summary,
  'coverUrl': instance.coverUrl,
  'category': instance.category,
  'categoryName': instance.categoryName,
  'categoryColorHex': instance.categoryColorHex,
  'tags': instance.tags,
  'mapName': instance.mapName,
  'mapLabel': instance.mapLabel,
  'mapBackground': instance.mapBackground,
  'hasVideo': instance.hasVideo,
  'authorId': instance.authorId,
  'authorName': instance.authorName,
  'authorAvatar': instance.authorAvatar,
  'viewCount': instance.viewCount,
  'likeCount': instance.likeCount,
  'favoriteCount': instance.favoriteCount,
  'commentCount': instance.commentCount,
  'isLiked': instance.isLiked,
  'isFavorited': instance.isFavorited,
  'isRecommended': instance.isRecommended,
  'isPinned': instance.isPinned,
  'status': _$GuideStatusEnumMap[instance.status]!,
  'rejectReason': instance.rejectReason,
  'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
  'publishedAt': const NullableServerTimeConverter().toJson(
    instance.publishedAt,
  ),
  'updatedAt': const ServerTimeConverter().toJson(instance.updatedAt),
  'deletedAt': const NullableServerTimeConverter().toJson(instance.deletedAt),
  'expireDays': instance.expireDays,
};

const _$GuideStatusEnumMap = {
  GuideStatus.draft: 'draft',
  GuideStatus.pending: 'pending',
  GuideStatus.published: 'published',
  GuideStatus.rejected: 'rejected',
  GuideStatus.offShelf: 'off_shelf',
  GuideStatus.deleted: 'deleted',
};

Guide _$GuideFromJson(Map<String, dynamic> json) => Guide(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  summary: json['summary'] as String?,
  coverUrl: json['coverUrl'] as String?,
  category: json['category'] as String?,
  categoryName: json['categoryName'] as String?,
  categoryColorHex: json['categoryColorHex'] as String?,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
  mapName: json['mapName'] as String?,
  mapLabel: json['mapLabel'] as String?,
  mapBackground: json['mapBackground'] as String?,
  hasVideo: json['hasVideo'] as bool? ?? false,
  authorId: (json['authorId'] as num).toInt(),
  authorName: json['authorName'] as String,
  authorAvatar: json['authorAvatar'] as String?,
  viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
  likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
  favoriteCount: (json['favoriteCount'] as num?)?.toInt() ?? 0,
  commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
  isLiked: json['isLiked'] as bool? ?? false,
  isFavorited: json['isFavorited'] as bool? ?? false,
  isRecommended: json['isRecommended'] as bool? ?? false,
  isPinned: json['isPinned'] as bool? ?? false,
  status: $enumDecode(_$GuideStatusEnumMap, json['status']),
  rejectReason: json['rejectReason'] as String?,
  createdAt: const ServerTimeConverter().fromJson(json['createdAt'] as String),
  publishedAt: const NullableServerTimeConverter().fromJson(
    json['publishedAt'] as String?,
  ),
  updatedAt: const ServerTimeConverter().fromJson(json['updatedAt'] as String),
  deletedAt: const NullableServerTimeConverter().fromJson(
    json['deletedAt'] as String?,
  ),
  expireDays: (json['expireDays'] as num?)?.toInt() ?? 0,
  content: json['content'] as String?,
  attachments:
      (json['attachments'] as List<dynamic>?)
          ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  videoEmbeds:
      (json['videoEmbeds'] as List<dynamic>?)
          ?.map((e) => VideoEmbed.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  tocItems:
      (json['tocItems'] as List<dynamic>?)
          ?.map((e) => TocItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  mapInfo: json['mapInfo'] == null
      ? null
      : MapInfo.fromJson(json['mapInfo'] as Map<String, dynamic>),
  readingTimeMin: (json['readingTimeMin'] as num?)?.toInt() ?? 0,
  version: (json['version'] as num?)?.toInt() ?? 1,
  relatedGuideIds:
      (json['relatedGuideIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      [],
);

Map<String, dynamic> _$GuideToJson(Guide instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'summary': instance.summary,
  'coverUrl': instance.coverUrl,
  'category': instance.category,
  'categoryName': instance.categoryName,
  'categoryColorHex': instance.categoryColorHex,
  'tags': instance.tags,
  'mapName': instance.mapName,
  'mapLabel': instance.mapLabel,
  'mapBackground': instance.mapBackground,
  'hasVideo': instance.hasVideo,
  'authorId': instance.authorId,
  'authorName': instance.authorName,
  'authorAvatar': instance.authorAvatar,
  'viewCount': instance.viewCount,
  'likeCount': instance.likeCount,
  'favoriteCount': instance.favoriteCount,
  'commentCount': instance.commentCount,
  'isLiked': instance.isLiked,
  'isFavorited': instance.isFavorited,
  'isRecommended': instance.isRecommended,
  'isPinned': instance.isPinned,
  'status': _$GuideStatusEnumMap[instance.status]!,
  'rejectReason': instance.rejectReason,
  'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
  'publishedAt': const NullableServerTimeConverter().toJson(
    instance.publishedAt,
  ),
  'updatedAt': const ServerTimeConverter().toJson(instance.updatedAt),
  'deletedAt': const NullableServerTimeConverter().toJson(instance.deletedAt),
  'expireDays': instance.expireDays,
  'content': instance.content,
  'attachments': instance.attachments,
  'videoEmbeds': instance.videoEmbeds,
  'tocItems': instance.tocItems,
  'mapInfo': instance.mapInfo,
  'readingTimeMin': instance.readingTimeMin,
  'version': instance.version,
  'relatedGuideIds': instance.relatedGuideIds,
};

Attachment _$AttachmentFromJson(Map<String, dynamic> json) => Attachment(
  fileId: json['fileId'] as String,
  url: json['url'] as String,
  thumbUrl: json['thumbUrl'] as String?,
  width: (json['width'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
  sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
  mimeType: json['mimeType'] as String?,
);

Map<String, dynamic> _$AttachmentToJson(Attachment instance) =>
    <String, dynamic>{
      'fileId': instance.fileId,
      'url': instance.url,
      'thumbUrl': instance.thumbUrl,
      'width': instance.width,
      'height': instance.height,
      'sizeBytes': instance.sizeBytes,
      'mimeType': instance.mimeType,
    };

VideoEmbed _$VideoEmbedFromJson(Map<String, dynamic> json) => VideoEmbed(
  bvid: json['bvid'] as String,
  url: json['url'] as String,
  title: json['title'] as String?,
  coverUrl: json['coverUrl'] as String?,
  durationSec: (json['durationSec'] as num?)?.toInt(),
);

Map<String, dynamic> _$VideoEmbedToJson(VideoEmbed instance) =>
    <String, dynamic>{
      'bvid': instance.bvid,
      'url': instance.url,
      'title': instance.title,
      'coverUrl': instance.coverUrl,
      'durationSec': instance.durationSec,
    };

TocItem _$TocItemFromJson(Map<String, dynamic> json) => TocItem(
  id: json['id'] as String,
  level: (json['level'] as num).toInt(),
  title: json['title'] as String,
);

Map<String, dynamic> _$TocItemToJson(TocItem instance) => <String, dynamic>{
  'id': instance.id,
  'level': instance.level,
  'title': instance.title,
};

GuideComment _$GuideCommentFromJson(Map<String, dynamic> json) => GuideComment(
  id: (json['id'] as num).toInt(),
  guideId: (json['guideId'] as num).toInt(),
  parentId: (json['parentId'] as num?)?.toInt(),
  replyToId: (json['replyToId'] as num?)?.toInt(),
  replyToName: json['replyToName'] as String?,
  content: json['content'] as String,
  images:
      (json['images'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  authorId: (json['authorId'] as num).toInt(),
  authorName: json['authorName'] as String,
  authorAvatar: json['authorAvatar'] as String?,
  likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
  isLiked: json['isLiked'] as bool? ?? false,
  replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
  replies:
      (json['replies'] as List<dynamic>?)
          ?.map((e) => GuideComment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  isAuthor: json['isAuthor'] as bool? ?? false,
  isDeleted: json['isDeleted'] as bool? ?? false,
  createdAt: const ServerTimeConverter().fromJson(json['createdAt'] as String),
);

Map<String, dynamic> _$GuideCommentToJson(GuideComment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'guideId': instance.guideId,
      'parentId': instance.parentId,
      'replyToId': instance.replyToId,
      'replyToName': instance.replyToName,
      'content': instance.content,
      'images': instance.images,
      'authorId': instance.authorId,
      'authorName': instance.authorName,
      'authorAvatar': instance.authorAvatar,
      'likeCount': instance.likeCount,
      'isLiked': instance.isLiked,
      'replyCount': instance.replyCount,
      'replies': instance.replies,
      'isAuthor': instance.isAuthor,
      'isDeleted': instance.isDeleted,
      'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
    };

GuideReport _$GuideReportFromJson(Map<String, dynamic> json) => GuideReport(
  targetId: (json['targetId'] as num).toInt(),
  targetType: json['targetType'] as String,
  reason: $enumDecode(_$ReportReasonEnumMap, json['reason']),
  description: json['description'] as String?,
  evidenceImages:
      (json['evidenceImages'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
);

Map<String, dynamic> _$GuideReportToJson(GuideReport instance) =>
    <String, dynamic>{
      'targetId': instance.targetId,
      'targetType': instance.targetType,
      'reason': _$ReportReasonEnumMap[instance.reason]!,
      'description': instance.description,
      'evidenceImages': instance.evidenceImages,
    };

const _$ReportReasonEnumMap = {
  ReportReason.spam: 'spam',
  ReportReason.abuse: 'abuse',
  ReportReason.porn: 'porn',
  ReportReason.politics: 'politics',
  ReportReason.plagiarism: 'plagiarism',
  ReportReason.misleading: 'misleading',
  ReportReason.other: 'other',
};

GuideDraft _$GuideDraftFromJson(Map<String, dynamic> json) => GuideDraft(
  draftId: json['draftId'] as String,
  guideId: (json['guideId'] as num?)?.toInt(),
  title: json['title'] as String?,
  coverUrl: json['coverUrl'] as String?,
  category: json['category'] as String?,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
  mapName: json['mapName'] as String?,
  summary: json['summary'] as String?,
  content: json['content'] as String?,
  videoEmbeds:
      (json['videoEmbeds'] as List<dynamic>?)
          ?.map((e) => VideoEmbed.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  version: (json['version'] as num?)?.toInt() ?? 1,
  updatedAt: const NullableServerTimeConverter().fromJson(
    json['updatedAt'] as String?,
  ),
);

Map<String, dynamic> _$GuideDraftToJson(
  GuideDraft instance,
) => <String, dynamic>{
  'draftId': instance.draftId,
  'guideId': instance.guideId,
  'title': instance.title,
  'coverUrl': instance.coverUrl,
  'category': instance.category,
  'tags': instance.tags,
  'mapName': instance.mapName,
  'summary': instance.summary,
  'content': instance.content,
  'videoEmbeds': instance.videoEmbeds,
  'version': instance.version,
  'updatedAt': const NullableServerTimeConverter().toJson(instance.updatedAt),
};

GuideUserStats _$GuideUserStatsFromJson(Map<String, dynamic> json) =>
    GuideUserStats(
      guideCount: (json['guideCount'] as num?)?.toInt() ?? 0,
      totalViews: (json['totalViews'] as num?)?.toInt() ?? 0,
      totalLikes: (json['totalLikes'] as num?)?.toInt() ?? 0,
      totalFavorites: (json['totalFavorites'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$GuideUserStatsToJson(GuideUserStats instance) =>
    <String, dynamic>{
      'guideCount': instance.guideCount,
      'totalViews': instance.totalViews,
      'totalLikes': instance.totalLikes,
      'totalFavorites': instance.totalFavorites,
    };
