import 'package:json_annotation/json_annotation.dart';

part 'server_models.g.dart';

@JsonSerializable()
class ServerCategory {
  final String? modelName;
  final String? category;
  final List<ServerItem> serverList;
  @JsonKey(defaultValue: false) final bool isCustom; // 标记是否为用户自定义分类

  ServerCategory({
    this.modelName, 
    this.category, 
    required this.serverList,
    this.isCustom = false,
  });

  factory ServerCategory.fromJson(Map<String, dynamic> json) => _$ServerCategoryFromJson(json);
  Map<String, dynamic> toJson() => _$ServerCategoryToJson(this);
  
  ServerCategory copyWith({
    String? modelName,
    String? category,
    List<ServerItem>? serverList,
    bool? isCustom,
  }) {
    return ServerCategory(
      modelName: modelName ?? this.modelName,
      category: category ?? this.category,
      serverList: serverList ?? this.serverList,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}

@JsonSerializable()
class ServerItem {
  final String? address;
  final String? serverAddress;
  final Map<String, dynamic>? serverData;
  @JsonKey(defaultValue: false) final bool isCustom; // 标记是否为用户自定义服务器

  ServerItem({
    this.address, 
    this.serverAddress, 
    this.serverData,
    this.isCustom = false,
  });

  factory ServerItem.fromJson(Map<String, dynamic> json) => _$ServerItemFromJson(json);
  Map<String, dynamic> toJson() => _$ServerItemToJson(this);
  
  ServerItem copyWith({
    String? address,
    String? serverAddress,
    Map<String, dynamic>? serverData,
    bool? isCustom,
  }) {
    return ServerItem(
      address: address ?? this.address,
      serverAddress: serverAddress ?? this.serverAddress,
      serverData: serverData ?? this.serverData,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}

@JsonSerializable()
class ServerInfo {
  @JsonKey(name: 'Protocol') final int? protocol;
  @JsonKey(name: 'HostName') final String? hostName;
  @JsonKey(name: 'Map') final String? map;
  @JsonKey(name: 'ModDir') final String? modDir;
  @JsonKey(name: 'ModDesc') final String? modDesc;
  @JsonKey(name: 'AppID') final int? appId;
  @JsonKey(name: 'Players') final int? players;
  @JsonKey(name: 'MaxPlayers') final int? maxPlayers;
  @JsonKey(name: 'Bots') final int? bots;
  @JsonKey(name: 'Dedicated') final String? dedicated;
  @JsonKey(name: 'Os') final String? os;
  @JsonKey(name: 'Password') final bool? password;
  @JsonKey(name: 'Secure') final bool? secure;
  @JsonKey(name: 'Version') final String? version;
  @JsonKey(name: 'ExtraDataFlags') final int? extraDataFlags;
  @JsonKey(name: 'GamePort') final int? gamePort;
  @JsonKey(name: 'SteamID') final String? steamId;
  @JsonKey(name: 'GameTags') final String? gameTags;
  @JsonKey(name: 'GameID') final String? gameId;
  final String? ip;
  final int? pingLatency;
  final String? pingStatus;
  @JsonKey(name: 'GameType') final String? gameType;

  ServerInfo({
    this.protocol, this.hostName, this.map, this.modDir, this.modDesc, this.appId,
    this.players, this.maxPlayers, this.bots, this.dedicated, this.os, this.password,
    this.secure, this.version, this.extraDataFlags, this.gamePort, this.steamId,
    this.gameTags, this.gameId, this.ip, this.pingLatency, this.pingStatus, this.gameType,
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) => _$ServerInfoFromJson(json);
  Map<String, dynamic> toJson() => _$ServerInfoToJson(this);
}

@JsonSerializable()
class ServerPingInfo {
  final String ip;
  final int ping;
  final String pingStatus;

  ServerPingInfo({required this.ip, required this.ping, required this.pingStatus});

  factory ServerPingInfo.fromJson(Map<String, dynamic> json) => _$ServerPingInfoFromJson(json);
  Map<String, dynamic> toJson() => _$ServerPingInfoToJson(this);
}

@JsonSerializable()
class PlayerInfo {
  final String name;
  final int score;
  final int duration;
  final int index;

  PlayerInfo({required this.name, required this.score, required this.duration, required this.index});

  factory PlayerInfo.fromJson(Map<String, dynamic> json) => _$PlayerInfoFromJson(json);
  Map<String, dynamic> toJson() => _$PlayerInfoToJson(this);
}

@JsonSerializable()
class TeamScores {
  @JsonKey(name: 'ct_score') final int? ctScore;
  @JsonKey(name: 't_score') final int? tScore;

  TeamScores({this.ctScore, this.tScore});

  factory TeamScores.fromJson(Map<String, dynamic> json) => _$TeamScoresFromJson(json);
  Map<String, dynamic> toJson() => _$TeamScoresToJson(this);
}

@JsonSerializable()
class ServerDetailInfo {
  @JsonKey(name: 'server_info') final ServerInfo serverInfo;
  @JsonKey(name: 'player_list') final List<PlayerInfo> playerList;
  final TeamScores? teams;

  ServerDetailInfo({required this.serverInfo, required this.playerList, this.teams});

  factory ServerDetailInfo.fromJson(Map<String, dynamic> json) => _$ServerDetailInfoFromJson(json);
  Map<String, dynamic> toJson() => _$ServerDetailInfoToJson(this);
}

@JsonSerializable()
class MapData {
  final int id;
  final String mapName;
  final String mapLabel;
  final String mapUrl;
  final String? mapModeUrl;

  MapData({required this.id, required this.mapName, required this.mapLabel, required this.mapUrl, this.mapModeUrl});

  factory MapData.fromJson(Map<String, dynamic> json) => _$MapDataFromJson(json);
  Map<String, dynamic> toJson() => _$MapDataToJson(this);
}

@JsonSerializable()
class MapRuntimeData {
  final int currentRuntime;
  final int weeklyOccurrences;

  MapRuntimeData({required this.currentRuntime, required this.weeklyOccurrences});

  factory MapRuntimeData.fromJson(Map<String, dynamic> json) => _$MapRuntimeDataFromJson(json);
  Map<String, dynamic> toJson() => _$MapRuntimeDataToJson(this);
}

@JsonSerializable()
class PlayerTrendInfo {
  final int playerCount;
  final String createdAt;

  PlayerTrendInfo({required this.playerCount, required this.createdAt});

  factory PlayerTrendInfo.fromJson(Map<String, dynamic> json) => _$PlayerTrendInfoFromJson(json);
  Map<String, dynamic> toJson() => _$PlayerTrendInfoToJson(this);
}

@JsonSerializable()
class ServerSnapshot {
  final int id;
  final String timestamp;
  final String address;
  final String hostname;
  @JsonKey(name: 'map_name') final String mapName;
  @JsonKey(name: 'map_label') final String mapLabel;
  @JsonKey(name: 'current_players') final int currentPlayers;
  @JsonKey(name: 'max_players') final int maxPlayers;
  @JsonKey(name: 'has_password') final bool hasPassword;
  @JsonKey(name: 'game_type') final String gameType;
  final String category;
  @JsonKey(name: 'is_online') final bool isOnline;
  @JsonKey(name: 'created_at') final String createdAt;
  final List<PlayerTrendInfo>? infos;

  ServerSnapshot({
    required this.id, required this.timestamp, required this.address, required this.hostname,
    required this.mapName, required this.mapLabel, required this.currentPlayers, required this.maxPlayers,
    required this.hasPassword, required this.gameType, required this.category, required this.isOnline,
    required this.createdAt, this.infos,
  });

  factory ServerSnapshot.fromJson(Map<String, dynamic> json) => _$ServerSnapshotFromJson(json);
  Map<String, dynamic> toJson() => _$ServerSnapshotToJson(this);
}

class ExtendedServerItem {
  final ServerItem serverItem;
  final ServerInfo? serverData;
  final MapData? mapInfo;
  final DateTime? updatedAt;
  final bool recentlyUpdated;
  final bool isLoading;
  final bool hasError;
  final ServerPingInfo? pingInfo;
  final MapRuntimeData? mapRuntime;
  final int? mapRuntimeLastFetched;
  final bool mapRuntimeError;
  final bool mapRuntimeFetching;
  final int consecutiveFailures; // 连续失败次数
  final bool isOffline; // 是否离线（连续失败3次）

  ExtendedServerItem({
    required this.serverItem, this.serverData, this.mapInfo, this.updatedAt,
    this.recentlyUpdated = false, this.isLoading = false, this.hasError = false,
    this.pingInfo, this.mapRuntime, this.mapRuntimeLastFetched,
    this.mapRuntimeError = false, this.mapRuntimeFetching = false,
    this.consecutiveFailures = 0, this.isOffline = false,
  });

  ExtendedServerItem copyWith({
    ServerItem? serverItem, ServerInfo? serverData, MapData? mapInfo, DateTime? updatedAt,
    bool? recentlyUpdated, bool? isLoading, bool? hasError, ServerPingInfo? pingInfo,
    MapRuntimeData? mapRuntime, int? mapRuntimeLastFetched, bool? mapRuntimeError, bool? mapRuntimeFetching,
    bool clearServerData = false, bool clearMapRuntime = false, bool clearMapInfo = false,
    int? consecutiveFailures, bool? isOffline,
  }) {
    return ExtendedServerItem(
      serverItem: serverItem ?? this.serverItem,
      serverData: clearServerData ? null : (serverData ?? this.serverData),
      mapInfo: clearMapInfo ? null : (mapInfo ?? this.mapInfo),
      updatedAt: updatedAt ?? this.updatedAt,
      recentlyUpdated: recentlyUpdated ?? this.recentlyUpdated,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      pingInfo: pingInfo ?? this.pingInfo,
      mapRuntime: clearMapRuntime ? null : (mapRuntime ?? this.mapRuntime),
      mapRuntimeLastFetched: clearMapRuntime ? null : (mapRuntimeLastFetched ?? this.mapRuntimeLastFetched),
      mapRuntimeError: mapRuntimeError ?? this.mapRuntimeError,
      mapRuntimeFetching: mapRuntimeFetching ?? this.mapRuntimeFetching,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

@JsonSerializable()
class ServerHistoryData {
  final int total;
  final List<ServerSnapshot> data;

  ServerHistoryData({required this.total, required this.data});

  factory ServerHistoryData.fromJson(Map<String, dynamic> json) => _$ServerHistoryDataFromJson(json);
  Map<String, dynamic> toJson() => _$ServerHistoryDataToJson(this);
}
