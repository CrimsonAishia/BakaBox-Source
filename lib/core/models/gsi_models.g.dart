// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gsi_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GsiGameState _$GsiGameStateFromJson(Map<String, dynamic> json) => GsiGameState(
  provider: json['provider'] == null
      ? null
      : GsiProvider.fromJson(json['provider'] as Map<String, dynamic>),
  map: json['map'] == null
      ? null
      : GsiMap.fromJson(json['map'] as Map<String, dynamic>),
  round: json['round'] == null
      ? null
      : GsiRound.fromJson(json['round'] as Map<String, dynamic>),
  player: json['player'] == null
      ? null
      : GsiPlayer.fromJson(json['player'] as Map<String, dynamic>),
  allPlayers: (json['allplayers'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, GsiPlayerInfo.fromJson(e as Map<String, dynamic>)),
  ),
  bomb: json['bomb'] == null
      ? null
      : GsiBomb.fromJson(json['bomb'] as Map<String, dynamic>),
  phaseCountdowns: json['phase_countdowns'] == null
      ? null
      : GsiPhaseCountdowns.fromJson(
          json['phase_countdowns'] as Map<String, dynamic>,
        ),
  auth: json['auth'] == null
      ? null
      : GsiAuth.fromJson(json['auth'] as Map<String, dynamic>),
);

Map<String, dynamic> _$GsiGameStateToJson(GsiGameState instance) =>
    <String, dynamic>{
      'provider': instance.provider,
      'map': instance.map,
      'round': instance.round,
      'player': instance.player,
      'allplayers': instance.allPlayers,
      'bomb': instance.bomb,
      'phase_countdowns': instance.phaseCountdowns,
      'auth': instance.auth,
    };

GsiProvider _$GsiProviderFromJson(Map<String, dynamic> json) => GsiProvider(
  name: json['name'] as String?,
  appId: (json['appid'] as num?)?.toInt(),
  version: (json['version'] as num?)?.toInt(),
  steamId: json['steamid'] as String?,
  timestamp: (json['timestamp'] as num?)?.toInt(),
);

Map<String, dynamic> _$GsiProviderToJson(GsiProvider instance) =>
    <String, dynamic>{
      'name': instance.name,
      'appid': instance.appId,
      'version': instance.version,
      'steamid': instance.steamId,
      'timestamp': instance.timestamp,
    };

GsiMap _$GsiMapFromJson(Map<String, dynamic> json) => GsiMap(
  mode: json['mode'] as String?,
  name: json['name'] as String?,
  phase: json['phase'] as String?,
  round: (json['round'] as num?)?.toInt(),
  teamCt: json['team_ct'] == null
      ? null
      : GsiTeam.fromJson(json['team_ct'] as Map<String, dynamic>),
  teamT: json['team_t'] == null
      ? null
      : GsiTeam.fromJson(json['team_t'] as Map<String, dynamic>),
  numMatchesToWinSeries: (json['num_matches_to_win_series'] as num?)?.toInt(),
  currentSpectators: (json['current_spectators'] as num?)?.toInt(),
  souvenirsTotal: (json['souvenirs_total'] as num?)?.toInt(),
);

Map<String, dynamic> _$GsiMapToJson(GsiMap instance) => <String, dynamic>{
  'mode': instance.mode,
  'name': instance.name,
  'phase': instance.phase,
  'round': instance.round,
  'team_ct': instance.teamCt,
  'team_t': instance.teamT,
  'num_matches_to_win_series': instance.numMatchesToWinSeries,
  'current_spectators': instance.currentSpectators,
  'souvenirs_total': instance.souvenirsTotal,
};

GsiTeam _$GsiTeamFromJson(Map<String, dynamic> json) => GsiTeam(
  score: (json['score'] as num?)?.toInt(),
  consecutiveRoundLosses: (json['consecutive_round_losses'] as num?)?.toInt(),
  timeoutsRemaining: (json['timeouts_remaining'] as num?)?.toInt(),
  matchesWonThisSeries: (json['matches_won_this_series'] as num?)?.toInt(),
);

Map<String, dynamic> _$GsiTeamToJson(GsiTeam instance) => <String, dynamic>{
  'score': instance.score,
  'consecutive_round_losses': instance.consecutiveRoundLosses,
  'timeouts_remaining': instance.timeoutsRemaining,
  'matches_won_this_series': instance.matchesWonThisSeries,
};

GsiRound _$GsiRoundFromJson(Map<String, dynamic> json) => GsiRound(
  phase: json['phase'] as String?,
  winTeam: json['win_team'] as String?,
  bomb: json['bomb'] as String?,
);

Map<String, dynamic> _$GsiRoundToJson(GsiRound instance) => <String, dynamic>{
  'phase': instance.phase,
  'win_team': instance.winTeam,
  'bomb': instance.bomb,
};

GsiPlayer _$GsiPlayerFromJson(Map<String, dynamic> json) => GsiPlayer(
  steamId: json['steamid'] as String?,
  name: json['name'] as String?,
  clan: json['clan'] as String?,
  team: json['team'] as String?,
  activity: json['activity'] as String?,
  observerSlot: (json['observer_slot'] as num?)?.toInt(),
  state: json['state'] == null
      ? null
      : GsiPlayerState.fromJson(json['state'] as Map<String, dynamic>),
  matchStats: json['match_stats'] == null
      ? null
      : GsiMatchStats.fromJson(json['match_stats'] as Map<String, dynamic>),
  weapons: (json['weapons'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, GsiWeapon.fromJson(e as Map<String, dynamic>)),
  ),
  position: json['position'] as String?,
  forward: json['forward'] as String?,
);

Map<String, dynamic> _$GsiPlayerToJson(GsiPlayer instance) => <String, dynamic>{
  'steamid': instance.steamId,
  'name': instance.name,
  'clan': instance.clan,
  'team': instance.team,
  'activity': instance.activity,
  'observer_slot': instance.observerSlot,
  'state': instance.state,
  'match_stats': instance.matchStats,
  'weapons': instance.weapons,
  'position': instance.position,
  'forward': instance.forward,
};

GsiPlayerInfo _$GsiPlayerInfoFromJson(Map<String, dynamic> json) =>
    GsiPlayerInfo(
      name: json['name'] as String?,
      team: json['team'] as String?,
      observerSlot: (json['observer_slot'] as num?)?.toInt(),
      state: json['state'] == null
          ? null
          : GsiPlayerState.fromJson(json['state'] as Map<String, dynamic>),
      matchStats: json['match_stats'] == null
          ? null
          : GsiMatchStats.fromJson(json['match_stats'] as Map<String, dynamic>),
      position: json['position'] as String?,
      forward: json['forward'] as String?,
    );

Map<String, dynamic> _$GsiPlayerInfoToJson(GsiPlayerInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'team': instance.team,
      'observer_slot': instance.observerSlot,
      'state': instance.state,
      'match_stats': instance.matchStats,
      'position': instance.position,
      'forward': instance.forward,
    };

GsiPlayerState _$GsiPlayerStateFromJson(Map<String, dynamic> json) =>
    GsiPlayerState(
      health: (json['health'] as num?)?.toInt(),
      armor: (json['armor'] as num?)?.toInt(),
      helmet: json['helmet'] as bool?,
      flashed: (json['flashed'] as num?)?.toInt(),
      smoked: (json['smoked'] as num?)?.toInt(),
      burning: (json['burning'] as num?)?.toInt(),
      money: (json['money'] as num?)?.toInt(),
      roundKills: (json['round_kills'] as num?)?.toInt(),
      roundKillHs: (json['round_killhs'] as num?)?.toInt(),
      equipValue: (json['equip_value'] as num?)?.toInt(),
    );

Map<String, dynamic> _$GsiPlayerStateToJson(GsiPlayerState instance) =>
    <String, dynamic>{
      'health': instance.health,
      'armor': instance.armor,
      'helmet': instance.helmet,
      'flashed': instance.flashed,
      'smoked': instance.smoked,
      'burning': instance.burning,
      'money': instance.money,
      'round_kills': instance.roundKills,
      'round_killhs': instance.roundKillHs,
      'equip_value': instance.equipValue,
    };

GsiMatchStats _$GsiMatchStatsFromJson(Map<String, dynamic> json) =>
    GsiMatchStats(
      kills: (json['kills'] as num?)?.toInt(),
      assists: (json['assists'] as num?)?.toInt(),
      deaths: (json['deaths'] as num?)?.toInt(),
      mvps: (json['mvps'] as num?)?.toInt(),
      score: (json['score'] as num?)?.toInt(),
    );

Map<String, dynamic> _$GsiMatchStatsToJson(GsiMatchStats instance) =>
    <String, dynamic>{
      'kills': instance.kills,
      'assists': instance.assists,
      'deaths': instance.deaths,
      'mvps': instance.mvps,
      'score': instance.score,
    };

GsiWeapon _$GsiWeaponFromJson(Map<String, dynamic> json) => GsiWeapon(
  name: json['name'] as String?,
  paintkit: json['paintkit'] as String?,
  type: json['type'] as String?,
  state: json['state'] as String?,
  ammoClip: (json['ammo_clip'] as num?)?.toInt(),
  ammoClipMax: (json['ammo_clip_max'] as num?)?.toInt(),
  ammoReserve: (json['ammo_reserve'] as num?)?.toInt(),
);

Map<String, dynamic> _$GsiWeaponToJson(GsiWeapon instance) => <String, dynamic>{
  'name': instance.name,
  'paintkit': instance.paintkit,
  'type': instance.type,
  'state': instance.state,
  'ammo_clip': instance.ammoClip,
  'ammo_clip_max': instance.ammoClipMax,
  'ammo_reserve': instance.ammoReserve,
};

GsiBomb _$GsiBombFromJson(Map<String, dynamic> json) => GsiBomb(
  state: json['state'] as String?,
  position: json['position'] as String?,
  player: json['player'] as String?,
  countdown: json['countdown'] as String?,
);

Map<String, dynamic> _$GsiBombToJson(GsiBomb instance) => <String, dynamic>{
  'state': instance.state,
  'position': instance.position,
  'player': instance.player,
  'countdown': instance.countdown,
};

GsiPhaseCountdowns _$GsiPhaseCountdownsFromJson(Map<String, dynamic> json) =>
    GsiPhaseCountdowns(
      phase: json['phase'] as String?,
      phaseEndsIn: json['phase_ends_in'] as String?,
    );

Map<String, dynamic> _$GsiPhaseCountdownsToJson(GsiPhaseCountdowns instance) =>
    <String, dynamic>{
      'phase': instance.phase,
      'phase_ends_in': instance.phaseEndsIn,
    };

GsiAuth _$GsiAuthFromJson(Map<String, dynamic> json) =>
    GsiAuth(token: json['token'] as String?);

Map<String, dynamic> _$GsiAuthToJson(GsiAuth instance) => <String, dynamic>{
  'token': instance.token,
};
