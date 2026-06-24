// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MapTagVoteReport _$MapTagVoteReportFromJson(Map<String, dynamic> json) =>
    MapTagVoteReport(
      mapName: json['mapName'] as String,
      tagId: (json['tagId'] as num).toInt(),
      voteUserId: (json['voteUserId'] as num).toInt(),
      voteUsername: json['voteUsername'] as String,
      reason: $enumDecode(_$TagVoteReportReasonEnumMap, json['reason']),
      description: json['description'] as String?,
      evidenceImages: (json['evidenceImages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      penalties: (json['penalties'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );

Map<String, dynamic> _$MapTagVoteReportToJson(MapTagVoteReport instance) =>
    <String, dynamic>{
      'mapName': instance.mapName,
      'tagId': instance.tagId,
      'voteUserId': instance.voteUserId,
      'voteUsername': instance.voteUsername,
      'reason': _$TagVoteReportReasonEnumMap[instance.reason]!,
      'description': instance.description,
      'evidenceImages': instance.evidenceImages,
      'penalties': instance.penalties,
    };

const _$TagVoteReportReasonEnumMap = {
  TagVoteReportReason.maliciousVote: 'malicious_vote',
  TagVoteReportReason.irrelevant: 'irrelevant',
  TagVoteReportReason.other: 'other',
};
