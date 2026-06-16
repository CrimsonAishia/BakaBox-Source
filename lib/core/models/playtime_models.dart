import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'playtime_models.g.dart';

/// 当前用户在指定地图的累计游玩时长
///
/// 由 `GET /zedbox/user/playtime/me?mapName=xxx` 返回，未登录或未传 mapName 时为 null。
@JsonSerializable()
class UserMapPlaytime extends Equatable {
  /// 地图原名（如 de_dust2）
  final String mapName;

  /// 该地图的累计有效秒数
  final int validSeconds;

  const UserMapPlaytime({required this.mapName, required this.validSeconds});

  factory UserMapPlaytime.fromJson(Map<String, dynamic> json) =>
      _$UserMapPlaytimeFromJson(json);

  Map<String, dynamic> toJson() => _$UserMapPlaytimeToJson(this);

  @override
  List<Object?> get props => [mapName, validSeconds];
}

/// 当前用户的游玩时长 / 投票门槛状态
///
/// 由 `POST /zedbox/user/playtime/heartbeat` 与 `GET /zedbox/user/playtime/me`
/// 共用响应结构。`currentMap` 仅在请求 `me` 时传入 `mapName` 才会返回。
///
/// 门槛只用于「投票」（赞 / 踩）。新建 / 修改 / 删除标签有审核流程把关，
/// 与乱投票无关，不设时长门槛。
@JsonSerializable()
class UserPlaytimeStatus extends Equatable {
  /// 服务端实际记录的累计秒数
  final int totalSeconds;

  /// 计入门槛的有效秒数（过滤掉超日上限等）
  final int validSeconds;

  /// 当日有效秒数（UTC+8 当天）
  final int todayValidSeconds;

  /// 是否达到投票门槛
  final bool canVote;

  /// 当前生效的投票门槛（秒）
  final int voteThresholdSeconds;

  /// 仅在请求时传入 mapName 才会返回；表示当前用户在该地图的累计有效秒数
  final UserMapPlaytime? currentMap;

  const UserPlaytimeStatus({
    required this.totalSeconds,
    required this.validSeconds,
    required this.todayValidSeconds,
    required this.canVote,
    required this.voteThresholdSeconds,
    this.currentMap,
  });

  /// 距离投票门槛还差多少秒（已达标返回 0）
  int get secondsUntilCanVote {
    if (canVote) return 0;
    final diff = voteThresholdSeconds - validSeconds;
    return diff > 0 ? diff : 0;
  }

  factory UserPlaytimeStatus.fromJson(Map<String, dynamic> json) =>
      _$UserPlaytimeStatusFromJson(json);

  Map<String, dynamic> toJson() => _$UserPlaytimeStatusToJson(this);

  UserPlaytimeStatus copyWith({
    int? totalSeconds,
    int? validSeconds,
    int? todayValidSeconds,
    bool? canVote,
    int? voteThresholdSeconds,
    UserMapPlaytime? currentMap,
  }) {
    return UserPlaytimeStatus(
      totalSeconds: totalSeconds ?? this.totalSeconds,
      validSeconds: validSeconds ?? this.validSeconds,
      todayValidSeconds: todayValidSeconds ?? this.todayValidSeconds,
      canVote: canVote ?? this.canVote,
      voteThresholdSeconds: voteThresholdSeconds ?? this.voteThresholdSeconds,
      currentMap: currentMap ?? this.currentMap,
    );
  }

  @override
  List<Object?> get props => [
    totalSeconds,
    validSeconds,
    todayValidSeconds,
    canVote,
    voteThresholdSeconds,
    currentMap,
  ];
}
