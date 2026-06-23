// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerCategory _$ServerCategoryFromJson(Map<String, dynamic> json) =>
    ServerCategory(
      modelName: json['modelName'] as String?,
      category: json['category'] as String?,
      serverList: (json['serverList'] as List<dynamic>)
          .map((e) => ServerItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      isCustom: json['isCustom'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt(),
      isFromApi: json['isFromApi'] as bool? ?? false,
      sourceApiUrl: json['sourceApiUrl'] as String?,
      sourceApiCategoryName: json['sourceApiCategoryName'] as String?,
    );

Map<String, dynamic> _$ServerCategoryToJson(ServerCategory instance) =>
    <String, dynamic>{
      'modelName': instance.modelName,
      'category': instance.category,
      'serverList': instance.serverList,
      'isCustom': instance.isCustom,
      'sortOrder': instance.sortOrder,
      'isFromApi': instance.isFromApi,
      'sourceApiUrl': instance.sourceApiUrl,
      'sourceApiCategoryName': instance.sourceApiCategoryName,
    };

ServerItem _$ServerItemFromJson(Map<String, dynamic> json) => ServerItem(
  address: json['address'] as String?,
  serverAddress: json['serverAddress'] as String?,
  serverData: json['serverData'] as Map<String, dynamic>?,
  isCustom: json['isCustom'] as bool? ?? false,
  nickname: json['nickname'] as String?,
  dataSourceMode: json['dataSourceMode'] as String?,
  sourceApiUrl: json['sourceApiUrl'] as String?,
  isDifficultySeparated: json['isDifficultySeparated'] as bool? ?? false,
);

Map<String, dynamic> _$ServerItemToJson(ServerItem instance) =>
    <String, dynamic>{
      'address': instance.address,
      'serverAddress': instance.serverAddress,
      'serverData': instance.serverData,
      'isCustom': instance.isCustom,
      'nickname': instance.nickname,
      'dataSourceMode': instance.dataSourceMode,
      'sourceApiUrl': instance.sourceApiUrl,
      'isDifficultySeparated': instance.isDifficultySeparated,
    };

ServerInfo _$ServerInfoFromJson(Map<String, dynamic> json) => ServerInfo(
  protocol: (json['Protocol'] as num?)?.toInt(),
  hostName: json['HostName'] as String?,
  map: json['Map'] as String?,
  modDir: json['ModDir'] as String?,
  modDesc: json['ModDesc'] as String?,
  appId: (json['AppID'] as num?)?.toInt(),
  players: (json['Players'] as num?)?.toInt(),
  maxPlayers: (json['MaxPlayers'] as num?)?.toInt(),
  bots: (json['Bots'] as num?)?.toInt(),
  dedicated: json['Dedicated'] as String?,
  os: json['Os'] as String?,
  password: json['Password'] as bool?,
  secure: json['Secure'] as bool?,
  version: json['Version'] as String?,
  extraDataFlags: (json['ExtraDataFlags'] as num?)?.toInt(),
  gamePort: (json['GamePort'] as num?)?.toInt(),
  steamId: json['SteamID'] as String?,
  gameTags: json['GameTags'] as String?,
  gameId: json['GameID'] as String?,
  ip: json['ip'] as String?,
  pingLatency: (json['pingLatency'] as num?)?.toInt(),
  pingStatus: json['pingStatus'] as String?,
  gameType: json['GameType'] as String?,
);

Map<String, dynamic> _$ServerInfoToJson(ServerInfo instance) =>
    <String, dynamic>{
      'Protocol': instance.protocol,
      'HostName': instance.hostName,
      'Map': instance.map,
      'ModDir': instance.modDir,
      'ModDesc': instance.modDesc,
      'AppID': instance.appId,
      'Players': instance.players,
      'MaxPlayers': instance.maxPlayers,
      'Bots': instance.bots,
      'Dedicated': instance.dedicated,
      'Os': instance.os,
      'Password': instance.password,
      'Secure': instance.secure,
      'Version': instance.version,
      'ExtraDataFlags': instance.extraDataFlags,
      'GamePort': instance.gamePort,
      'SteamID': instance.steamId,
      'GameTags': instance.gameTags,
      'GameID': instance.gameId,
      'ip': instance.ip,
      'pingLatency': instance.pingLatency,
      'pingStatus': instance.pingStatus,
      'GameType': instance.gameType,
    };

ServerPingInfo _$ServerPingInfoFromJson(Map<String, dynamic> json) =>
    ServerPingInfo(
      ip: json['ip'] as String,
      ping: (json['ping'] as num).toInt(),
      pingStatus: json['pingStatus'] as String,
    );

Map<String, dynamic> _$ServerPingInfoToJson(ServerPingInfo instance) =>
    <String, dynamic>{
      'ip': instance.ip,
      'ping': instance.ping,
      'pingStatus': instance.pingStatus,
    };

PlayerInfo _$PlayerInfoFromJson(Map<String, dynamic> json) => PlayerInfo(
  name: json['name'] as String,
  score: (json['score'] as num).toInt(),
  duration: (json['duration'] as num).toInt(),
  index: (json['index'] as num).toInt(),
);

Map<String, dynamic> _$PlayerInfoToJson(PlayerInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'score': instance.score,
      'duration': instance.duration,
      'index': instance.index,
    };

TeamScores _$TeamScoresFromJson(Map<String, dynamic> json) => TeamScores(
  ctScore: (json['ct_score'] as num?)?.toInt(),
  tScore: (json['t_score'] as num?)?.toInt(),
  dataQuality: json['data_quality'] as String?,
  mapName: json['map_name'] as String?,
);

Map<String, dynamic> _$TeamScoresToJson(TeamScores instance) =>
    <String, dynamic>{
      'ct_score': instance.ctScore,
      't_score': instance.tScore,
      'data_quality': instance.dataQuality,
      'map_name': instance.mapName,
    };

ServerDetailInfo _$ServerDetailInfoFromJson(Map<String, dynamic> json) =>
    ServerDetailInfo(
      serverInfo: ServerInfo.fromJson(
        json['server_info'] as Map<String, dynamic>,
      ),
      playerList: (json['player_list'] as List<dynamic>)
          .map((e) => PlayerInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      teams: json['teams'] == null
          ? null
          : TeamScores.fromJson(json['teams'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ServerDetailInfoToJson(ServerDetailInfo instance) =>
    <String, dynamic>{
      'server_info': instance.serverInfo,
      'player_list': instance.playerList,
      'teams': instance.teams,
    };

MapData _$MapDataFromJson(Map<String, dynamic> json) => MapData(
  id: (json['id'] as num).toInt(),
  mapName: json['mapName'] as String,
  mapLabel: json['mapLabel'] as String,
  mapUrl: json['mapUrl'] as String,
  tags:
      (json['tags'] as List<dynamic>?)
          ?.map((e) => MapTagSimple.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$MapDataToJson(MapData instance) => <String, dynamic>{
  'id': instance.id,
  'mapName': instance.mapName,
  'mapLabel': instance.mapLabel,
  'mapUrl': instance.mapUrl,
  'tags': instance.tags,
};

MapRuntimeData _$MapRuntimeDataFromJson(Map<String, dynamic> json) =>
    MapRuntimeData(
      currentRuntime: (json['currentRuntime'] as num).toInt(),
      weeklyOccurrences: (json['weeklyOccurrences'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MapRuntimeDataToJson(MapRuntimeData instance) =>
    <String, dynamic>{
      'currentRuntime': instance.currentRuntime,
      'weeklyOccurrences': instance.weeklyOccurrences,
    };

PlayerTrendInfo _$PlayerTrendInfoFromJson(Map<String, dynamic> json) =>
    PlayerTrendInfo(
      playerCount: (json['playerCount'] as num).toInt(),
      createdAt: json['createdAt'] as String,
    );

Map<String, dynamic> _$PlayerTrendInfoToJson(PlayerTrendInfo instance) =>
    <String, dynamic>{
      'playerCount': instance.playerCount,
      'createdAt': instance.createdAt,
    };

ServerSnapshot _$ServerSnapshotFromJson(Map<String, dynamic> json) =>
    ServerSnapshot(
      id: (json['id'] as num).toInt(),
      timestamp: json['timestamp'] as String,
      address: json['address'] as String,
      hostname: json['hostname'] as String,
      mapName: json['map_name'] as String,
      mapLabel: json['map_label'] as String,
      currentPlayers: (json['current_players'] as num).toInt(),
      maxPlayers: (json['max_players'] as num).toInt(),
      hasPassword: json['has_password'] as bool,
      gameType: json['game_type'] as String,
      category: json['category'] as String,
      isOnline: json['is_online'] as bool,
      createdAt: json['created_at'] as String,
      infos: (json['infos'] as List<dynamic>?)
          ?.map((e) => PlayerTrendInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      finalCtScore: (json['final_ct_score'] as num?)?.toInt(),
      finalTScore: (json['final_t_score'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ServerSnapshotToJson(ServerSnapshot instance) =>
    <String, dynamic>{
      'id': instance.id,
      'timestamp': instance.timestamp,
      'address': instance.address,
      'hostname': instance.hostname,
      'map_name': instance.mapName,
      'map_label': instance.mapLabel,
      'current_players': instance.currentPlayers,
      'max_players': instance.maxPlayers,
      'has_password': instance.hasPassword,
      'game_type': instance.gameType,
      'category': instance.category,
      'is_online': instance.isOnline,
      'created_at': instance.createdAt,
      'infos': instance.infos,
      'final_ct_score': instance.finalCtScore,
      'final_t_score': instance.finalTScore,
    };

ServerHistoryData _$ServerHistoryDataFromJson(Map<String, dynamic> json) =>
    ServerHistoryData(
      total: (json['total'] as num).toInt(),
      data: (json['data'] as List<dynamic>)
          .map((e) => ServerSnapshot.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ServerHistoryDataToJson(ServerHistoryData instance) =>
    <String, dynamic>{'total': instance.total, 'data': instance.data};
