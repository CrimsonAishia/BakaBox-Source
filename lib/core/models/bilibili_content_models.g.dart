// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bilibili_content_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LiveRoom _$LiveRoomFromJson(Map<String, dynamic> json) => LiveRoom(
  id: json['id'] as String,
  ownerUid: json['ownerUid'] as String,
  ownerName: json['ownerName'] as String,
  ownerFace: json['ownerFace'] as String?,
  roomId: json['roomId'] as String,
  enabled: json['enabled'] as bool? ?? true,
  title: json['title'] as String?,
  coverUrl: json['coverUrl'] as String?,
  liveStatus: (json['liveStatus'] as num?)?.toInt() ?? 0,
  viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
  followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$LiveRoomToJson(LiveRoom instance) => <String, dynamic>{
  'id': instance.id,
  'ownerUid': instance.ownerUid,
  'ownerName': instance.ownerName,
  'ownerFace': instance.ownerFace,
  'roomId': instance.roomId,
  'enabled': instance.enabled,
  'title': instance.title,
  'coverUrl': instance.coverUrl,
  'liveStatus': instance.liveStatus,
  'viewCount': instance.viewCount,
  'followerCount': instance.followerCount,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};

BilibiliVideo _$BilibiliVideoFromJson(Map<String, dynamic> json) =>
    BilibiliVideo(
      id: json['id'] as String,
      ownerUid: json['ownerUid'] as String,
      ownerName: json['ownerName'] as String,
      ownerFace: json['ownerFace'] as String?,
      bvid: json['bvid'] as String,
      title: json['title'] as String?,
      coverUrl: json['coverUrl'] as String?,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      coinCount: (json['coinCount'] as num?)?.toInt() ?? 0,
      favoriteCount: (json['favoriteCount'] as num?)?.toInt() ?? 0,
      publishedAt: json['publishedAt'] == null
          ? null
          : DateTime.parse(json['publishedAt'] as String),
      duration: (json['duration'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      auditStatus: json['auditStatus'] as String?,
      auditRemark: json['auditRemark'] as String?,
      auditAt: json['auditAt'] == null
          ? null
          : DateTime.parse(json['auditAt'] as String),
      auditBy: (json['auditBy'] as num?)?.toInt(),
      categoryId: (json['categoryId'] as num?)?.toInt(),
      category: json['category'] as String?,
    );

Map<String, dynamic> _$BilibiliVideoToJson(BilibiliVideo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ownerUid': instance.ownerUid,
      'ownerName': instance.ownerName,
      'ownerFace': instance.ownerFace,
      'bvid': instance.bvid,
      'title': instance.title,
      'coverUrl': instance.coverUrl,
      'viewCount': instance.viewCount,
      'likeCount': instance.likeCount,
      'coinCount': instance.coinCount,
      'favoriteCount': instance.favoriteCount,
      'publishedAt': instance.publishedAt?.toIso8601String(),
      'duration': instance.duration,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'auditStatus': instance.auditStatus,
      'auditRemark': instance.auditRemark,
      'auditAt': instance.auditAt?.toIso8601String(),
      'auditBy': instance.auditBy,
      'categoryId': instance.categoryId,
      'category': instance.category,
    };

VideoCategory _$VideoCategoryFromJson(Map<String, dynamic> json) =>
    VideoCategory(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
    );

Map<String, dynamic> _$VideoCategoryToJson(VideoCategory instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};
