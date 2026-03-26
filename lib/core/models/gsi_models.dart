import 'package:json_annotation/json_annotation.dart';

part 'gsi_models.g.dart';

/// GSI 配置
class GsiConfig {
  final bool enabled;
  final int port;
  final String token;

  const GsiConfig({this.enabled = false, this.port = 59595, this.token = ''});

  GsiConfig copyWith({bool? enabled, int? port, String? token}) {
    return GsiConfig(
      enabled: enabled ?? this.enabled,
      port: port ?? this.port,
      token: token ?? this.token,
    );
  }
}

/// GSI 游戏状态数据
@JsonSerializable()
class GsiGameState {
  final GsiProvider? provider;
  final GsiMap? map;
  final GsiRound? round;
  final GsiPlayer? player;
  @JsonKey(name: 'allplayers')
  final Map<String, GsiPlayerInfo>? allPlayers;
  final GsiBomb? bomb;
  @JsonKey(name: 'phase_countdowns')
  final GsiPhaseCountdowns? phaseCountdowns;
  final GsiAuth? auth;
  @JsonKey(includeFromJson: false, includeToJson: false)
  DateTime? receivedAt;

  GsiGameState({
    this.provider,
    this.map,
    this.round,
    this.player,
    this.allPlayers,
    this.bomb,
    this.phaseCountdowns,
    this.auth,
    this.receivedAt,
  });

  factory GsiGameState.fromJson(Map<String, dynamic> json) =>
      _$GsiGameStateFromJson(json);
  Map<String, dynamic> toJson() => _$GsiGameStateToJson(this);

  // ==================== 便捷方法 ====================

  /// 玩家是否在主菜单
  bool get isInMenu => player?.activity == 'menu';

  /// 玩家是否在游戏中（playing 或有 map 数据）
  bool get isPlaying =>
      player?.activity == 'playing' || (map != null && !isInMenu);

  /// 玩家是否在输入文字（聊天框等）
  bool get isTextInput => player?.activity == 'textinput';

  /// 是否有有效的游戏数据（非主菜单状态）
  bool get hasValidGameData => map != null && !isInMenu;
}

/// 提供者信息
@JsonSerializable()
class GsiProvider {
  final String? name;
  @JsonKey(name: 'appid')
  final int? appId;
  final int? version;
  @JsonKey(name: 'steamid')
  final String? steamId;
  final int? timestamp;

  GsiProvider({
    this.name,
    this.appId,
    this.version,
    this.steamId,
    this.timestamp,
  });

  factory GsiProvider.fromJson(Map<String, dynamic> json) =>
      _$GsiProviderFromJson(json);
  Map<String, dynamic> toJson() => _$GsiProviderToJson(this);
}

/// 地图信息
@JsonSerializable()
class GsiMap {
  final String? mode;
  final String? name;
  final String? phase;
  final int? round;
  @JsonKey(name: 'team_ct')
  final GsiTeam? teamCt;
  @JsonKey(name: 'team_t')
  final GsiTeam? teamT;
  @JsonKey(name: 'num_matches_to_win_series')
  final int? numMatchesToWinSeries;
  @JsonKey(name: 'current_spectators')
  final int? currentSpectators;
  @JsonKey(name: 'souvenirs_total')
  final int? souvenirsTotal;

  GsiMap({
    this.mode,
    this.name,
    this.phase,
    this.round,
    this.teamCt,
    this.teamT,
    this.numMatchesToWinSeries,
    this.currentSpectators,
    this.souvenirsTotal,
  });

  factory GsiMap.fromJson(Map<String, dynamic> json) => _$GsiMapFromJson(json);
  Map<String, dynamic> toJson() => _$GsiMapToJson(this);
}

/// 队伍信息
@JsonSerializable()
class GsiTeam {
  final int? score;
  @JsonKey(name: 'consecutive_round_losses')
  final int? consecutiveRoundLosses;
  @JsonKey(name: 'timeouts_remaining')
  final int? timeoutsRemaining;
  @JsonKey(name: 'matches_won_this_series')
  final int? matchesWonThisSeries;

  GsiTeam({
    this.score,
    this.consecutiveRoundLosses,
    this.timeoutsRemaining,
    this.matchesWonThisSeries,
  });

  factory GsiTeam.fromJson(Map<String, dynamic> json) =>
      _$GsiTeamFromJson(json);
  Map<String, dynamic> toJson() => _$GsiTeamToJson(this);
}

/// 回合信息
@JsonSerializable()
class GsiRound {
  final String? phase;
  @JsonKey(name: 'win_team')
  final String? winTeam;
  final String? bomb;

  GsiRound({this.phase, this.winTeam, this.bomb});

  factory GsiRound.fromJson(Map<String, dynamic> json) =>
      _$GsiRoundFromJson(json);
  Map<String, dynamic> toJson() => _$GsiRoundToJson(this);
}

/// 当前玩家信息
@JsonSerializable()
class GsiPlayer {
  @JsonKey(name: 'steamid')
  final String? steamId;
  final String? name;
  final String? clan;
  final String? team;
  final String? activity;
  @JsonKey(name: 'observer_slot')
  final int? observerSlot;
  final GsiPlayerState? state;
  @JsonKey(name: 'match_stats')
  final GsiMatchStats? matchStats;
  final Map<String, GsiWeapon>? weapons;
  final String? position;
  final String? forward;

  GsiPlayer({
    this.steamId,
    this.name,
    this.clan,
    this.team,
    this.activity,
    this.observerSlot,
    this.state,
    this.matchStats,
    this.weapons,
    this.position,
    this.forward,
  });

  factory GsiPlayer.fromJson(Map<String, dynamic> json) =>
      _$GsiPlayerFromJson(json);
  Map<String, dynamic> toJson() => _$GsiPlayerToJson(this);
}

/// 所有玩家信息项
@JsonSerializable()
class GsiPlayerInfo {
  final String? name;
  final String? team;
  @JsonKey(name: 'observer_slot')
  final int? observerSlot;
  final GsiPlayerState? state;
  @JsonKey(name: 'match_stats')
  final GsiMatchStats? matchStats;
  final String? position;
  final String? forward;

  GsiPlayerInfo({
    this.name,
    this.team,
    this.observerSlot,
    this.state,
    this.matchStats,
    this.position,
    this.forward,
  });

  factory GsiPlayerInfo.fromJson(Map<String, dynamic> json) =>
      _$GsiPlayerInfoFromJson(json);
  Map<String, dynamic> toJson() => _$GsiPlayerInfoToJson(this);
}

/// 玩家状态
@JsonSerializable()
class GsiPlayerState {
  final int? health;
  final int? armor;
  final bool? helmet;
  final int? flashed;
  final int? smoked;
  final int? burning;
  final int? money;
  @JsonKey(name: 'round_kills')
  final int? roundKills;
  @JsonKey(name: 'round_killhs')
  final int? roundKillHs;
  @JsonKey(name: 'equip_value')
  final int? equipValue;

  GsiPlayerState({
    this.health,
    this.armor,
    this.helmet,
    this.flashed,
    this.smoked,
    this.burning,
    this.money,
    this.roundKills,
    this.roundKillHs,
    this.equipValue,
  });

  factory GsiPlayerState.fromJson(Map<String, dynamic> json) =>
      _$GsiPlayerStateFromJson(json);
  Map<String, dynamic> toJson() => _$GsiPlayerStateToJson(this);
}

/// 比赛统计
@JsonSerializable()
class GsiMatchStats {
  final int? kills;
  final int? assists;
  final int? deaths;
  final int? mvps;
  final int? score;

  GsiMatchStats({this.kills, this.assists, this.deaths, this.mvps, this.score});

  factory GsiMatchStats.fromJson(Map<String, dynamic> json) =>
      _$GsiMatchStatsFromJson(json);
  Map<String, dynamic> toJson() => _$GsiMatchStatsToJson(this);
}

/// 武器信息
@JsonSerializable()
class GsiWeapon {
  final String? name;
  final String? paintkit;
  final String? type;
  final String? state;
  @JsonKey(name: 'ammo_clip')
  final int? ammoClip;
  @JsonKey(name: 'ammo_clip_max')
  final int? ammoClipMax;
  @JsonKey(name: 'ammo_reserve')
  final int? ammoReserve;

  GsiWeapon({
    this.name,
    this.paintkit,
    this.type,
    this.state,
    this.ammoClip,
    this.ammoClipMax,
    this.ammoReserve,
  });

  factory GsiWeapon.fromJson(Map<String, dynamic> json) =>
      _$GsiWeaponFromJson(json);
  Map<String, dynamic> toJson() => _$GsiWeaponToJson(this);
}

/// 炸弹信息
@JsonSerializable()
class GsiBomb {
  final String? state;
  final String? position;
  final String? player;
  final String? countdown;

  GsiBomb({this.state, this.position, this.player, this.countdown});

  factory GsiBomb.fromJson(Map<String, dynamic> json) =>
      _$GsiBombFromJson(json);
  Map<String, dynamic> toJson() => _$GsiBombToJson(this);
}

/// 阶段倒计时
@JsonSerializable()
class GsiPhaseCountdowns {
  final String? phase;
  @JsonKey(name: 'phase_ends_in')
  final String? phaseEndsIn;

  GsiPhaseCountdowns({this.phase, this.phaseEndsIn});

  factory GsiPhaseCountdowns.fromJson(Map<String, dynamic> json) =>
      _$GsiPhaseCountdownsFromJson(json);
  Map<String, dynamic> toJson() => _$GsiPhaseCountdownsToJson(this);
}

/// 认证信息
@JsonSerializable()
class GsiAuth {
  final String? token;

  GsiAuth({this.token});

  factory GsiAuth.fromJson(Map<String, dynamic> json) =>
      _$GsiAuthFromJson(json);
  Map<String, dynamic> toJson() => _$GsiAuthToJson(this);
}

/// GSI 游戏数据日志
class GsiGameLog {
  final DateTime timestamp;
  final String rawJson;
  final String summary;

  GsiGameLog({
    required this.timestamp,
    required this.rawJson,
    required this.summary,
  });
}
