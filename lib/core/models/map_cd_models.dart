import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'map_cd_models.g.dart';

/// 地图CD信息
@JsonSerializable()
class MapCdInfo extends Equatable {
  /// 排名
  final int rank;

  /// 地图名称
  final String mapName;

  /// 当前CD
  final int currentCd;

  /// 当前提名CD
  final int currentNominateCd;

  /// 今日运行次数
  final int dayRunCount;

  /// 本周运行次数
  final int weekRunCount;

  /// 本月运行次数
  final int monthRunCount;

  /// 最后运行时间
  final String lastRunTime;

  const MapCdInfo({
    required this.rank,
    required this.mapName,
    required this.currentCd,
    required this.currentNominateCd,
    required this.dayRunCount,
    required this.weekRunCount,
    required this.monthRunCount,
    required this.lastRunTime,
  });

  factory MapCdInfo.fromJson(Map<String, dynamic> json) =>
      _$MapCdInfoFromJson(json);

  Map<String, dynamic> toJson() => _$MapCdInfoToJson(this);

  @override
  List<Object?> get props => [
        rank,
        mapName,
        currentCd,
        currentNominateCd,
        dayRunCount,
        weekRunCount,
        monthRunCount,
        lastRunTime,
      ];
}

/// 地图CD响应
@JsonSerializable()
class MapCdResponse extends Equatable {
  @JsonKey(name: 'item')
  final MapCdInfo? item;

  const MapCdResponse({this.item});

  factory MapCdResponse.fromJson(Map<String, dynamic> json) =>
      _$MapCdResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MapCdResponseToJson(this);

  @override
  List<Object?> get props => [item];
}
