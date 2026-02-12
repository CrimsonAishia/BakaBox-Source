// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_score.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerScore _$ServerScoreFromJson(Map<String, dynamic> json) => ServerScore(
  serverAddress: json['server_address'] as String,
  ctScore: (json['ct_score'] as num?)?.toInt(),
  tScore: (json['t_score'] as num?)?.toInt(),
  round: (json['round'] as num?)?.toInt(),
  mapName: json['map_name'] as String?,
  confidence: (json['confidence'] as num?)?.toInt(),
  sourceCount: (json['source_count'] as num?)?.toInt(),
  updatedAt: json['updated_at'] as String?,
  dataQuality: json['data_quality'] as String,
);

Map<String, dynamic> _$ServerScoreToJson(ServerScore instance) =>
    <String, dynamic>{
      'server_address': instance.serverAddress,
      'ct_score': instance.ctScore,
      't_score': instance.tScore,
      'round': instance.round,
      'map_name': instance.mapName,
      'confidence': instance.confidence,
      'source_count': instance.sourceCount,
      'updated_at': instance.updatedAt,
      'data_quality': instance.dataQuality,
    };
