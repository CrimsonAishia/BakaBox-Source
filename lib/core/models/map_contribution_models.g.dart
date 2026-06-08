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

MapInfo _$MapInfoFromJson(Map<String, dynamic> json) => MapInfo(
  mapName: json['mapName'] as String,
  mapLabel: json['mapLabel'] as String? ?? '',
  mapBackground: json['mapBackground'] as String?,
  contribCount: (json['contribCount'] as num?)?.toInt() ?? 0,
  nameCount: (json['nameCount'] as num?)?.toInt() ?? 0,
  backgroundCount: (json['backgroundCount'] as num?)?.toInt() ?? 0,
  tags:
      (json['tags'] as List<dynamic>?)
          ?.map((e) => MapTagSimple.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  guideCount: (json['guideCount'] as num?)?.toInt(),
);

Map<String, dynamic> _$MapInfoToJson(MapInfo instance) => <String, dynamic>{
  'mapName': instance.mapName,
  'mapLabel': instance.mapLabel,
  'mapBackground': instance.mapBackground,
  'contribCount': instance.contribCount,
  'nameCount': instance.nameCount,
  'backgroundCount': instance.backgroundCount,
  'tags': instance.tags,
  'guideCount': instance.guideCount,
};

MapContributionGroup _$MapContributionGroupFromJson(
  Map<String, dynamic> json,
) => MapContributionGroup(
  mapInfo: MapInfo.fromJson(json['mapInfo'] as Map<String, dynamic>),
  items: (json['items'] as List<dynamic>)
      .map((e) => MapContribution.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$MapContributionGroupToJson(
  MapContributionGroup instance,
) => <String, dynamic>{'mapInfo': instance.mapInfo, 'items': instance.items};

PaginationParams _$PaginationParamsFromJson(Map<String, dynamic> json) =>
    PaginationParams(
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      orderBy: json['orderBy'] as String? ?? 'created_at DESC',
    );

Map<String, dynamic> _$PaginationParamsToJson(PaginationParams instance) =>
    <String, dynamic>{
      'pageIndex': instance.pageIndex,
      'pageSize': instance.pageSize,
      'orderBy': instance.orderBy,
    };

MapContributionListRequest _$MapContributionListRequestFromJson(
  Map<String, dynamic> json,
) => MapContributionListRequest(
  pagination: PaginationParams.fromJson(
    json['pagination'] as Map<String, dynamic>,
  ),
  mapName: json['mapName'] as String?,
  type: json['type'] as String?,
  userId: (json['userId'] as num?)?.toInt(),
  auditStatus: json['auditStatus'] as String?,
  keyword: json['keyword'] as String?,
  keywordType: json['keywordType'] as String?,
  startAt: json['startAt'] as String?,
  endAt: json['endAt'] as String?,
);

Map<String, dynamic> _$MapContributionListRequestToJson(
  MapContributionListRequest instance,
) => <String, dynamic>{
  'pagination': instance.pagination,
  'mapName': instance.mapName,
  'type': instance.type,
  'userId': instance.userId,
  'auditStatus': instance.auditStatus,
  'keyword': instance.keyword,
  'keywordType': instance.keywordType,
  'startAt': instance.startAt,
  'endAt': instance.endAt,
};

MapContributionListResponse _$MapContributionListResponseFromJson(
  Map<String, dynamic> json,
) => MapContributionListResponse(
  total: (json['total'] as num).toInt(),
  groups: (json['groups'] as List<dynamic>)
      .map((e) => MapContributionGroup.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$MapContributionListResponseToJson(
  MapContributionListResponse instance,
) => <String, dynamic>{'total': instance.total, 'groups': instance.groups};

MapListResponse _$MapListResponseFromJson(Map<String, dynamic> json) =>
    MapListResponse(
      total: (json['total'] as num).toInt(),
      items: (json['items'] as List<dynamic>)
          .map((e) => MapInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$MapListResponseToJson(MapListResponse instance) =>
    <String, dynamic>{'total': instance.total, 'items': instance.items};

MapListRequest _$MapListRequestFromJson(Map<String, dynamic> json) =>
    MapListRequest(
      pagination: PaginationParams.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
      mapName: json['mapName'] as String?,
      mapType: json['mapType'] as String?,
    );

Map<String, dynamic> _$MapListRequestToJson(MapListRequest instance) =>
    <String, dynamic>{
      'pagination': instance.pagination,
      'mapName': instance.mapName,
      'mapType': instance.mapType,
    };

MapHistoryPlayerInfo _$MapHistoryPlayerInfoFromJson(
  Map<String, dynamic> json,
) => MapHistoryPlayerInfo(
  playerCount: (json['playerCount'] as num).toInt(),
  createdAt: const ServerTimeConverter().fromJson(json['createdAt'] as String),
);

Map<String, dynamic> _$MapHistoryPlayerInfoToJson(
  MapHistoryPlayerInfo instance,
) => <String, dynamic>{
  'playerCount': instance.playerCount,
  'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
};

MapHistoryRecord _$MapHistoryRecordFromJson(
  Map<String, dynamic> json,
) => MapHistoryRecord(
  id: (json['id'] as num).toInt(),
  address: json['address'] as String,
  mapName: json['mapName'] as String,
  maxPlayers: (json['maxPlayers'] as num).toInt(),
  createdAt: const ServerTimeConverter().fromJson(json['createdAt'] as String),
  infos:
      (json['infos'] as List<dynamic>?)
          ?.map((e) => MapHistoryPlayerInfo.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  finalCtScore: (json['finalCtScore'] as num?)?.toInt(),
  finalTScore: (json['finalTScore'] as num?)?.toInt(),
);

Map<String, dynamic> _$MapHistoryRecordToJson(MapHistoryRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'address': instance.address,
      'mapName': instance.mapName,
      'maxPlayers': instance.maxPlayers,
      'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
      'infos': instance.infos,
      'finalCtScore': instance.finalCtScore,
      'finalTScore': instance.finalTScore,
    };

MapHistoryResponse _$MapHistoryResponseFromJson(Map<String, dynamic> json) =>
    MapHistoryResponse(
      total: (json['total'] as num).toInt(),
      data:
          (json['data'] as List<dynamic>?)
              ?.map((e) => MapHistoryRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MapHistoryResponseToJson(MapHistoryResponse instance) =>
    <String, dynamic>{'total': instance.total, 'data': instance.data};

MapHistoryRequest _$MapHistoryRequestFromJson(Map<String, dynamic> json) =>
    MapHistoryRequest(
      mapName: json['mapName'] as String,
      pagination: PaginationParams.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$MapHistoryRequestToJson(MapHistoryRequest instance) =>
    <String, dynamic>{
      'mapName': instance.mapName,
      'pagination': instance.pagination,
    };
