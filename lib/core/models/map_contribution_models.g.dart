// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_contribution_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ContributorInfo _$ContributorInfoFromJson(Map<String, dynamic> json) =>
    ContributorInfo(
      userId: (json['userId'] as num).toInt(),
      username: json['username'] as String,
      avatar: json['avatar'] as String?,
    );

Map<String, dynamic> _$ContributorInfoToJson(ContributorInfo instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'username': instance.username,
      'avatar': instance.avatar,
    };

MapContribution _$MapContributionFromJson(
  Map<String, dynamic> json,
) => MapContribution(
  id: (json['id'] as num).toInt(),
  mapName: json['mapName'] as String,
  type: $enumDecode(_$ContributionTypeEnumMap, json['type']),
  content: json['content'] as String,
  voteCount: (json['voteCount'] as num).toInt(),
  upCount: (json['upCount'] as num?)?.toInt() ?? 0,
  downCount: (json['downCount'] as num?)?.toInt() ?? 0,
  contributor: json['contributor'] == null
      ? null
      : ContributorInfo.fromJson(json['contributor'] as Map<String, dynamic>),
  hasVoted: json['hasVoted'] as bool,
  voteType: $enumDecodeNullable(_$VoteTypeEnumMap, json['voteType']),
  isOwner: json['isOwner'] as bool,
  isSystem: json['isSystem'] as bool? ?? false,
  auditStatus:
      $enumDecodeNullable(_$AuditStatusEnumMap, json['auditStatus']) ??
      AuditStatus.approved,
  auditRemark: json['auditRemark'] as String? ?? '',
  auditAt: const NullableServerTimeConverter().fromJson(
    json['auditAt'] as String?,
  ),
  createdAt: const ServerTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: const ServerTimeConverter().fromJson(json['updatedAt'] as String),
);

Map<String, dynamic> _$MapContributionToJson(MapContribution instance) =>
    <String, dynamic>{
      'id': instance.id,
      'mapName': instance.mapName,
      'type': _$ContributionTypeEnumMap[instance.type]!,
      'content': instance.content,
      'voteCount': instance.voteCount,
      'upCount': instance.upCount,
      'downCount': instance.downCount,
      'contributor': instance.contributor,
      'hasVoted': instance.hasVoted,
      'voteType': _$VoteTypeEnumMap[instance.voteType],
      'isOwner': instance.isOwner,
      'isSystem': instance.isSystem,
      'auditStatus': _$AuditStatusEnumMap[instance.auditStatus]!,
      'auditRemark': instance.auditRemark,
      'auditAt': const NullableServerTimeConverter().toJson(instance.auditAt),
      'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
      'updatedAt': const ServerTimeConverter().toJson(instance.updatedAt),
    };

const _$ContributionTypeEnumMap = {
  ContributionType.name: 'name',
  ContributionType.background: 'background',
};

const _$VoteTypeEnumMap = {VoteType.up: 'up', VoteType.down: 'down'};

const _$AuditStatusEnumMap = {
  AuditStatus.pending: 'pending',
  AuditStatus.approved: 'approved',
  AuditStatus.rejected: 'rejected',
};

MapContributionSummary _$MapContributionSummaryFromJson(
  Map<String, dynamic> json,
) => MapContributionSummary(
  topName: json['topName'] as String?,
  topBackground: json['topBackground'] as String?,
  nameCount: (json['nameCount'] as num).toInt(),
  backgroundCount: (json['backgroundCount'] as num).toInt(),
);

Map<String, dynamic> _$MapContributionSummaryToJson(
  MapContributionSummary instance,
) => <String, dynamic>{
  'topName': instance.topName,
  'topBackground': instance.topBackground,
  'nameCount': instance.nameCount,
  'backgroundCount': instance.backgroundCount,
};

ContributionVoteResponse _$ContributionVoteResponseFromJson(
  Map<String, dynamic> json,
) => ContributionVoteResponse(
  success: json['success'] as bool,
  newVoteCount: (json['newVoteCount'] as num).toInt(),
  upCount: (json['upCount'] as num?)?.toInt() ?? 0,
  downCount: (json['downCount'] as num?)?.toInt() ?? 0,
  hasVoted: json['hasVoted'] as bool,
  voteType: $enumDecodeNullable(_$VoteTypeEnumMap, json['voteType']),
);

Map<String, dynamic> _$ContributionVoteResponseToJson(
  ContributionVoteResponse instance,
) => <String, dynamic>{
  'success': instance.success,
  'newVoteCount': instance.newVoteCount,
  'upCount': instance.upCount,
  'downCount': instance.downCount,
  'hasVoted': instance.hasVoted,
  'voteType': _$VoteTypeEnumMap[instance.voteType],
};
