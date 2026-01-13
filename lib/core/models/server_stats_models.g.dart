// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_stats_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DailyStat _$DailyStatFromJson(Map<String, dynamic> json) => DailyStat(
  date: json['date'] as String,
  maxPlayers: (json['maxPlayers'] as num).toInt(),
  avgPlayers: (json['avgPlayers'] as num).toInt(),
);

Map<String, dynamic> _$DailyStatToJson(DailyStat instance) => <String, dynamic>{
  'date': instance.date,
  'maxPlayers': instance.maxPlayers,
  'avgPlayers': instance.avgPlayers,
};

HourlyStat _$HourlyStatFromJson(Map<String, dynamic> json) => HourlyStat(
  hour: (json['hour'] as num).toInt(),
  avgPlayers: (json['avgPlayers'] as num).toInt(),
);

Map<String, dynamic> _$HourlyStatToJson(HourlyStat instance) =>
    <String, dynamic>{'hour': instance.hour, 'avgPlayers': instance.avgPlayers};

TopServer _$TopServerFromJson(Map<String, dynamic> json) => TopServer(
  address: json['address'] as String,
  maxPlayers: (json['maxPlayers'] as num).toInt(),
  avgPlayers: (json['avgPlayers'] as num).toInt(),
);

Map<String, dynamic> _$TopServerToJson(TopServer instance) => <String, dynamic>{
  'address': instance.address,
  'maxPlayers': instance.maxPlayers,
  'avgPlayers': instance.avgPlayers,
};

TopMap _$TopMapFromJson(Map<String, dynamic> json) => TopMap(
  mapName: json['mapName'] as String,
  playCount: (json['playCount'] as num).toInt(),
  maxPlayers: (json['maxPlayers'] as num).toInt(),
  avgPlayers: (json['avgPlayers'] as num).toInt(),
);

Map<String, dynamic> _$TopMapToJson(TopMap instance) => <String, dynamic>{
  'mapName': instance.mapName,
  'playCount': instance.playCount,
  'maxPlayers': instance.maxPlayers,
  'avgPlayers': instance.avgPlayers,
};

ServerStatsResponse _$ServerStatsResponseFromJson(Map<String, dynamic> json) =>
    ServerStatsResponse(
      dailyStats:
          (json['dailyStats'] as List<dynamic>?)
              ?.map((e) => DailyStat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      hourlyStats:
          (json['hourlyStats'] as List<dynamic>?)
              ?.map((e) => HourlyStat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      topServers:
          (json['topServers'] as List<dynamic>?)
              ?.map((e) => TopServer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      topMaps:
          (json['topMaps'] as List<dynamic>?)
              ?.map((e) => TopMap.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      peakHour: (json['peakHour'] as num).toInt(),
      todayMax: (json['todayMax'] as num).toInt(),
      todayAvg: (json['todayAvg'] as num).toInt(),
      weeklyMax: (json['weeklyMax'] as num).toInt(),
      weeklyAvg: (json['weeklyAvg'] as num).toInt(),
    );

Map<String, dynamic> _$ServerStatsResponseToJson(
  ServerStatsResponse instance,
) => <String, dynamic>{
  'dailyStats': instance.dailyStats,
  'hourlyStats': instance.hourlyStats,
  'topServers': instance.topServers,
  'topMaps': instance.topMaps,
  'peakHour': instance.peakHour,
  'todayMax': instance.todayMax,
  'todayAvg': instance.todayAvg,
  'weeklyMax': instance.weeklyMax,
  'weeklyAvg': instance.weeklyAvg,
};
