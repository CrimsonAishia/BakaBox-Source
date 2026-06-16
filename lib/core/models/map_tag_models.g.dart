// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_tag_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MapTag _$MapTagFromJson(Map<String, dynamic> json) => MapTag(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  color: json['color'] as String?,
  contributor: json['contributor'] == null
      ? null
      : ContributorInfo.fromJson(json['contributor'] as Map<String, dynamic>),
  createdAt: const ServerTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: const ServerTimeConverter().fromJson(json['updatedAt'] as String),
  auditStatus: $enumDecodeNullable(_$AuditStatusEnumMap, json['auditStatus']),
  auditRemark: json['auditRemark'] as String?,
  isPinned: json['isPinned'] as bool?,
);

Map<String, dynamic> _$MapTagToJson(MapTag instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'color': instance.color,
  'contributor': instance.contributor,
  'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
  'updatedAt': const ServerTimeConverter().toJson(instance.updatedAt),
  'auditStatus': _$AuditStatusEnumMap[instance.auditStatus],
  'auditRemark': instance.auditRemark,
  'isPinned': instance.isPinned,
};

const _$AuditStatusEnumMap = {
  AuditStatus.pending: 'pending',
  AuditStatus.approved: 'approved',
  AuditStatus.rejected: 'rejected',
};

MapTagChangeRequest _$MapTagChangeRequestFromJson(Map<String, dynamic> json) =>
    MapTagChangeRequest(
      id: (json['id'] as num).toInt(),
      tagId: (json['tagId'] as num).toInt(),
      changeType: json['changeType'] as String,
      auditStatus: $enumDecode(_$AuditStatusEnumMap, json['auditStatus']),
    );

Map<String, dynamic> _$MapTagChangeRequestToJson(
  MapTagChangeRequest instance,
) => <String, dynamic>{
  'id': instance.id,
  'tagId': instance.tagId,
  'changeType': instance.changeType,
  'auditStatus': _$AuditStatusEnumMap[instance.auditStatus]!,
};

MapTagVoteSimple _$MapTagVoteSimpleFromJson(Map<String, dynamic> json) =>
    MapTagVoteSimple(
      id: (json['id'] as num).toInt(),
      mapName: json['mapName'] as String,
      tagId: (json['tagId'] as num).toInt(),
      tagName: json['tagName'] as String,
      voteCount: (json['voteCount'] as num).toInt(),
      upCount: (json['upCount'] as num).toInt(),
      downCount: (json['downCount'] as num).toInt(),
      hasUpvoted: json['hasUpvoted'] as bool?,
      hasDownvoted: json['hasDownvoted'] as bool?,
    );

Map<String, dynamic> _$MapTagVoteSimpleToJson(MapTagVoteSimple instance) =>
    <String, dynamic>{
      'id': instance.id,
      'mapName': instance.mapName,
      'tagId': instance.tagId,
      'tagName': instance.tagName,
      'voteCount': instance.voteCount,
      'upCount': instance.upCount,
      'downCount': instance.downCount,
      'hasUpvoted': instance.hasUpvoted,
      'hasDownvoted': instance.hasDownvoted,
    };

MapTagListSimpleResponse _$MapTagListSimpleResponseFromJson(
  Map<String, dynamic> json,
) => MapTagListSimpleResponse(
  mapName: json['mapName'] as String,
  items: (json['items'] as List<dynamic>)
      .map((e) => MapTagVoteSimple.fromJson(e as Map<String, dynamic>))
      .toList(),
  voting: json['voting'] == null
      ? null
      : MapTagVotingInfo.fromJson(json['voting'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MapTagListSimpleResponseToJson(
  MapTagListSimpleResponse instance,
) => <String, dynamic>{
  'mapName': instance.mapName,
  'items': instance.items,
  'voting': instance.voting,
};

MapTagVotingInfo _$MapTagVotingInfoFromJson(Map<String, dynamic> json) =>
    MapTagVotingInfo(
      voteThresholdSeconds: (json['voteThresholdSeconds'] as num).toInt(),
      userMapValidSeconds: (json['userMapValidSeconds'] as num).toInt(),
      canVote: json['canVote'] as bool,
    );

Map<String, dynamic> _$MapTagVotingInfoToJson(MapTagVotingInfo instance) =>
    <String, dynamic>{
      'voteThresholdSeconds': instance.voteThresholdSeconds,
      'userMapValidSeconds': instance.userMapValidSeconds,
      'canVote': instance.canVote,
    };

TagVoteResponse _$TagVoteResponseFromJson(Map<String, dynamic> json) =>
    TagVoteResponse(
      success: json['success'] as bool,
      hasVoted: json['hasVoted'] as bool,
      mapTagVote: MapTagVoteSimple.fromJson(
        json['mapTagVote'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$TagVoteResponseToJson(TagVoteResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'hasVoted': instance.hasVoted,
      'mapTagVote': instance.mapTagVote,
    };

TagUserVoteItem _$TagUserVoteItemFromJson(Map<String, dynamic> json) =>
    TagUserVoteItem(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      username: json['username'] as String,
      avatar: json['avatar'] as String,
      voteType: json['voteType'] as String,
    );

Map<String, dynamic> _$TagUserVoteItemToJson(TagUserVoteItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'username': instance.username,
      'avatar': instance.avatar,
      'voteType': instance.voteType,
    };

TagUserVotesResponse _$TagUserVotesResponseFromJson(
  Map<String, dynamic> json,
) => TagUserVotesResponse(
  mapName: json['mapName'] as String,
  tagId: (json['tagId'] as num).toInt(),
  tagName: json['tagName'] as String,
  items: (json['items'] as List<dynamic>)
      .map((e) => TagUserVoteItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$TagUserVotesResponseToJson(
  TagUserVotesResponse instance,
) => <String, dynamic>{
  'mapName': instance.mapName,
  'tagId': instance.tagId,
  'tagName': instance.tagName,
  'items': instance.items,
  'total': instance.total,
};

MapAllTagVoteItem _$MapAllTagVoteItemFromJson(Map<String, dynamic> json) =>
    MapAllTagVoteItem(
      id: (json['id'] as num).toInt(),
      tagId: (json['tagId'] as num).toInt(),
      tagName: json['tagName'] as String,
      tagColor: json['tagColor'] as String?,
      userId: (json['userId'] as num).toInt(),
      username: json['username'] as String,
      avatar: json['avatar'] as String,
      voteType: json['voteType'] as String,
    );

Map<String, dynamic> _$MapAllTagVoteItemToJson(MapAllTagVoteItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tagId': instance.tagId,
      'tagName': instance.tagName,
      'tagColor': instance.tagColor,
      'userId': instance.userId,
      'username': instance.username,
      'avatar': instance.avatar,
      'voteType': instance.voteType,
    };

MapAllTagVotesResponse _$MapAllTagVotesResponseFromJson(
  Map<String, dynamic> json,
) => MapAllTagVotesResponse(
  mapName: json['mapName'] as String,
  items: (json['items'] as List<dynamic>)
      .map((e) => MapAllTagVoteItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$MapAllTagVotesResponseToJson(
  MapAllTagVotesResponse instance,
) => <String, dynamic>{
  'mapName': instance.mapName,
  'items': instance.items,
  'total': instance.total,
};

MapTagSimple _$MapTagSimpleFromJson(Map<String, dynamic> json) =>
    MapTagSimple(name: json['name'] as String, color: json['color'] as String?);

Map<String, dynamic> _$MapTagSimpleToJson(MapTagSimple instance) =>
    <String, dynamic>{'name': instance.name, 'color': instance.color};
