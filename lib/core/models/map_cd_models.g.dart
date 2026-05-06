// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_cd_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MapCdInfo _$MapCdInfoFromJson(Map<String, dynamic> json) => MapCdInfo(
  rank: (json['rank'] as num).toInt(),
  mapName: json['mapName'] as String,
  currentCd: (json['currentCd'] as num).toInt(),
  currentNominateCd: (json['currentNominateCd'] as num).toInt(),
  dayRunCount: (json['dayRunCount'] as num).toInt(),
  weekRunCount: (json['weekRunCount'] as num).toInt(),
  monthRunCount: (json['monthRunCount'] as num).toInt(),
  lastRunTime: json['lastRunTime'] as String,
);

Map<String, dynamic> _$MapCdInfoToJson(MapCdInfo instance) => <String, dynamic>{
  'rank': instance.rank,
  'mapName': instance.mapName,
  'currentCd': instance.currentCd,
  'currentNominateCd': instance.currentNominateCd,
  'dayRunCount': instance.dayRunCount,
  'weekRunCount': instance.weekRunCount,
  'monthRunCount': instance.monthRunCount,
  'lastRunTime': instance.lastRunTime,
};

MapCdResponse _$MapCdResponseFromJson(Map<String, dynamic> json) =>
    MapCdResponse(
      item: json['item'] == null
          ? null
          : MapCdInfo.fromJson(json['item'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MapCdResponseToJson(MapCdResponse instance) =>
    <String, dynamic>{'item': instance.item};
