// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playtime_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserMapPlaytime _$UserMapPlaytimeFromJson(Map<String, dynamic> json) =>
    UserMapPlaytime(
      mapName: json['mapName'] as String,
      validSeconds: (json['validSeconds'] as num).toInt(),
    );

Map<String, dynamic> _$UserMapPlaytimeToJson(UserMapPlaytime instance) =>
    <String, dynamic>{
      'mapName': instance.mapName,
      'validSeconds': instance.validSeconds,
    };

UserPlaytimeStatus _$UserPlaytimeStatusFromJson(Map<String, dynamic> json) =>
    UserPlaytimeStatus(
      totalSeconds: (json['totalSeconds'] as num).toInt(),
      validSeconds: (json['validSeconds'] as num).toInt(),
      canVote: json['canVote'] as bool,
      voteThresholdSeconds: (json['voteThresholdSeconds'] as num).toInt(),
      currentMap: json['currentMap'] == null
          ? null
          : UserMapPlaytime.fromJson(
              json['currentMap'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$UserPlaytimeStatusToJson(UserPlaytimeStatus instance) =>
    <String, dynamic>{
      'totalSeconds': instance.totalSeconds,
      'validSeconds': instance.validSeconds,
      'canVote': instance.canVote,
      'voteThresholdSeconds': instance.voteThresholdSeconds,
      'currentMap': instance.currentMap,
    };
