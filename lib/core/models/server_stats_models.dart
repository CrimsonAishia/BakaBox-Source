import 'package:json_annotation/json_annotation.dart';

part 'server_stats_models.g.dart';

/// 每日统计数据
@JsonSerializable()
class DailyStat {
  final String date;
  final int maxPlayers;
  final int avgPlayers;

  DailyStat({
    required this.date,
    required this.maxPlayers,
    required this.avgPlayers,
  });

  factory DailyStat.fromJson(Map<String, dynamic> json) => _$DailyStatFromJson(json);
  Map<String, dynamic> toJson() => _$DailyStatToJson(this);
}

/// 每小时统计数据
@JsonSerializable()
class HourlyStat {
  final int hour;
  final int avgPlayers;

  HourlyStat({required this.hour, required this.avgPlayers});

  factory HourlyStat.fromJson(Map<String, dynamic> json) => _$HourlyStatFromJson(json);
  Map<String, dynamic> toJson() => _$HourlyStatToJson(this);
}

/// 热门服务器
@JsonSerializable()
class TopServer {
  final String address;
  final int maxPlayers;
  final int avgPlayers;

  TopServer({
    required this.address,
    required this.maxPlayers,
    required this.avgPlayers,
  });

  factory TopServer.fromJson(Map<String, dynamic> json) => _$TopServerFromJson(json);
  Map<String, dynamic> toJson() => _$TopServerToJson(this);
}

/// 热门地图
@JsonSerializable()
class TopMap {
  final String mapName;
  final int playCount;
  final int maxPlayers;
  final int avgPlayers;

  TopMap({
    required this.mapName,
    required this.playCount,
    required this.maxPlayers,
    required this.avgPlayers,
  });

  factory TopMap.fromJson(Map<String, dynamic> json) => _$TopMapFromJson(json);
  Map<String, dynamic> toJson() => _$TopMapToJson(this);
}

/// 服务器统计响应
@JsonSerializable()
class ServerStatsResponse {
  @JsonKey(defaultValue: [])
  final List<DailyStat> dailyStats;

  @JsonKey(defaultValue: [])
  final List<HourlyStat> hourlyStats;

  @JsonKey(defaultValue: [])
  final List<TopServer> topServers;

  @JsonKey(defaultValue: [])
  final List<TopMap> topMaps;

  final int peakHour;
  final int todayMax;
  final int todayAvg;
  final int weeklyMax;
  final int weeklyAvg;

  ServerStatsResponse({
    required this.dailyStats,
    required this.hourlyStats,
    required this.topServers,
    required this.topMaps,
    required this.peakHour,
    required this.todayMax,
    required this.todayAvg,
    required this.weeklyMax,
    required this.weeklyAvg,
  });

  factory ServerStatsResponse.fromJson(Map<String, dynamic> json) =>
      _$ServerStatsResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ServerStatsResponseToJson(this);

  /// 空数据
  factory ServerStatsResponse.empty() => ServerStatsResponse(
        dailyStats: [],
        hourlyStats: [],
        topServers: [],
        topMaps: [],
        peakHour: 0,
        todayMax: 0,
        todayAvg: 0,
        weeklyMax: 0,
        weeklyAvg: 0,
      );
}
