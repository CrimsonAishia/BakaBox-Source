import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'map_tag_models.dart';

part 'server_models.g.dart';

class ServerUsersCount extends Equatable {
  final String serverAddress;
  final int queueCount;
  final int warmupCount;

  const ServerUsersCount({
    required this.serverAddress,
    this.queueCount = 0,
    this.warmupCount = 0,
  });

  factory ServerUsersCount.fromJson(Map<String, dynamic> json) {
    return ServerUsersCount(
      serverAddress: json['serverAddress'] as String? ?? '',
      queueCount: (json['queueCount'] as num?)?.toInt() ?? 0,
      warmupCount: (json['warmupCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [serverAddress, queueCount, warmupCount];
}

@JsonSerializable()
class ServerCategory extends Equatable {
  final String? modelName;
  final String? category;
  final List<ServerItem> serverList;
  @JsonKey(defaultValue: false)
  final bool isCustom; // 标记是否为用户自定义分类
  final int? sortOrder; // 自定义分类排序顺序

  @JsonKey(defaultValue: false)
  final bool isFromApi; // 标记是否来源于第三方API
  final String? sourceApiUrl; // 第三方接口URL
  final String? sourceApiCategoryName; // 第三方接口的原始分类键名（用于找回数据源，防改名失效）

  const ServerCategory({
    this.modelName,
    this.category,
    required this.serverList,
    this.isCustom = false,
    this.sortOrder,
    this.isFromApi = false,
    this.sourceApiUrl,
    this.sourceApiCategoryName,
  });

  factory ServerCategory.fromJson(Map<String, dynamic> json) =>
      _$ServerCategoryFromJson(json);
  Map<String, dynamic> toJson() => _$ServerCategoryToJson(this);

  ServerCategory copyWith({
    String? modelName,
    String? category,
    List<ServerItem>? serverList,
    bool? isCustom,
    int? sortOrder,
    bool? isFromApi,
    String? sourceApiUrl,
    String? sourceApiCategoryName,
  }) {
    return ServerCategory(
      modelName: modelName ?? this.modelName,
      category: category ?? this.category,
      serverList: serverList ?? this.serverList,
      isCustom: isCustom ?? this.isCustom,
      sortOrder: sortOrder ?? this.sortOrder,
      isFromApi: isFromApi ?? this.isFromApi,
      sourceApiUrl: sourceApiUrl ?? this.sourceApiUrl,
      sourceApiCategoryName: sourceApiCategoryName ?? this.sourceApiCategoryName,
    );
  }

  @override
  List<Object?> get props => [
    modelName,
    category,
    serverList,
    isCustom,
    sortOrder,
    isFromApi,
    sourceApiUrl,
    sourceApiCategoryName,
  ];
}

@JsonSerializable()
class ServerItem extends Equatable {
  final String? address;
  final String? serverAddress;
  final Map<String, dynamic>? serverData;
  @JsonKey(defaultValue: false)
  final bool isCustom; // 标记是否为用户自定义服务器
  final String? nickname; // 自定义服务器备注名
  final String? dataSourceMode; // 数据更新模式：'a2s' 或 'api'
  final String? sourceApiUrl; // 第三方接口URL

  const ServerItem({
    this.address,
    this.serverAddress,
    this.serverData,
    this.isCustom = false,
    this.nickname,
    this.dataSourceMode,
    this.sourceApiUrl,
  });

  factory ServerItem.fromJson(Map<String, dynamic> json) =>
      _$ServerItemFromJson(json);
  Map<String, dynamic> toJson() => _$ServerItemToJson(this);

  /// 获取显示名称：优先备注名，其次服务器名，最后地址
  String getDisplayName(String? hostName) {
    if (nickname != null && nickname!.isNotEmpty) return nickname!;
    if (hostName != null && hostName.isNotEmpty) return hostName;
    return address ?? serverAddress ?? '未知服务器';
  }

  ServerItem copyWith({
    String? address,
    String? serverAddress,
    Map<String, dynamic>? serverData,
    bool? isCustom,
    String? nickname,
    bool clearNickname = false,
    String? dataSourceMode,
    String? sourceApiUrl,
  }) {
    return ServerItem(
      address: address ?? this.address,
      serverAddress: serverAddress ?? this.serverAddress,
      serverData: serverData ?? this.serverData,
      isCustom: isCustom ?? this.isCustom,
      nickname: clearNickname ? null : (nickname ?? this.nickname),
      dataSourceMode: dataSourceMode ?? this.dataSourceMode,
      sourceApiUrl: sourceApiUrl ?? this.sourceApiUrl,
    );
  }

  @override
  List<Object?> get props => [
    address,
    serverAddress,
    serverData,
    isCustom,
    nickname,
    dataSourceMode,
    sourceApiUrl,
  ];
}

@JsonSerializable()
class ServerInfo extends Equatable {
  @JsonKey(name: 'Protocol')
  final int? protocol;
  @JsonKey(name: 'HostName')
  final String? hostName;
  @JsonKey(name: 'Map')
  final String? map;
  @JsonKey(name: 'ModDir')
  final String? modDir;
  @JsonKey(name: 'ModDesc')
  final String? modDesc;
  @JsonKey(name: 'AppID')
  final int? appId;
  @JsonKey(name: 'Players')
  final int? players;
  @JsonKey(name: 'MaxPlayers')
  final int? maxPlayers;
  @JsonKey(name: 'Bots')
  final int? bots;
  @JsonKey(name: 'Dedicated')
  final String? dedicated;
  @JsonKey(name: 'Os')
  final String? os;
  @JsonKey(name: 'Password')
  final bool? password;
  @JsonKey(name: 'Secure')
  final bool? secure;
  @JsonKey(name: 'Version')
  final String? version;
  @JsonKey(name: 'ExtraDataFlags')
  final int? extraDataFlags;
  @JsonKey(name: 'GamePort')
  final int? gamePort;
  @JsonKey(name: 'SteamID')
  final String? steamId;
  @JsonKey(name: 'GameTags')
  final String? gameTags;
  @JsonKey(name: 'GameID')
  final String? gameId;
  final String? ip;
  final int? pingLatency;
  final String? pingStatus;
  @JsonKey(name: 'GameType')
  final String? gameType;

  const ServerInfo({
    this.protocol,
    this.hostName,
    this.map,
    this.modDir,
    this.modDesc,
    this.appId,
    this.players,
    this.maxPlayers,
    this.bots,
    this.dedicated,
    this.os,
    this.password,
    this.secure,
    this.version,
    this.extraDataFlags,
    this.gamePort,
    this.steamId,
    this.gameTags,
    this.gameId,
    this.ip,
    this.pingLatency,
    this.pingStatus,
    this.gameType,
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) =>
      _$ServerInfoFromJson(json);
  Map<String, dynamic> toJson() => _$ServerInfoToJson(this);

  ServerInfo copyWith({
    int? protocol,
    String? hostName,
    String? map,
    String? modDir,
    String? modDesc,
    int? appId,
    int? players,
    int? maxPlayers,
    int? bots,
    String? dedicated,
    String? os,
    bool? password,
    bool? secure,
    String? version,
    int? extraDataFlags,
    int? gamePort,
    String? steamId,
    String? gameTags,
    String? gameId,
    String? ip,
    int? pingLatency,
    String? pingStatus,
    String? gameType,
  }) {
    return ServerInfo(
      protocol: protocol ?? this.protocol,
      hostName: hostName ?? this.hostName,
      map: map ?? this.map,
      modDir: modDir ?? this.modDir,
      modDesc: modDesc ?? this.modDesc,
      appId: appId ?? this.appId,
      players: players ?? this.players,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      bots: bots ?? this.bots,
      dedicated: dedicated ?? this.dedicated,
      os: os ?? this.os,
      password: password ?? this.password,
      secure: secure ?? this.secure,
      version: version ?? this.version,
      extraDataFlags: extraDataFlags ?? this.extraDataFlags,
      gamePort: gamePort ?? this.gamePort,
      steamId: steamId ?? this.steamId,
      gameTags: gameTags ?? this.gameTags,
      gameId: gameId ?? this.gameId,
      ip: ip ?? this.ip,
      pingLatency: pingLatency ?? this.pingLatency,
      pingStatus: pingStatus ?? this.pingStatus,
      gameType: gameType ?? this.gameType,
    );
  }

  @override
  List<Object?> get props => [
    protocol,
    hostName,
    map,
    modDir,
    modDesc,
    appId,
    players,
    maxPlayers,
    bots,
    dedicated,
    os,
    password,
    secure,
    version,
    extraDataFlags,
    gamePort,
    steamId,
    gameTags,
    gameId,
    ip,
    pingLatency,
    pingStatus,
    gameType,
  ];
}

@JsonSerializable()
class ServerPingInfo extends Equatable {
  final String ip;
  final int ping;
  final String pingStatus;

  const ServerPingInfo({
    required this.ip,
    required this.ping,
    required this.pingStatus,
  });

  factory ServerPingInfo.fromJson(Map<String, dynamic> json) =>
      _$ServerPingInfoFromJson(json);
  Map<String, dynamic> toJson() => _$ServerPingInfoToJson(this);

  @override
  List<Object?> get props => [ip, ping, pingStatus];
}

@JsonSerializable()
class PlayerInfo {
  final String name;
  final int score;
  final int duration;
  final int index;

  PlayerInfo({
    required this.name,
    required this.score,
    required this.duration,
    required this.index,
  });

  factory PlayerInfo.fromJson(Map<String, dynamic> json) =>
      _$PlayerInfoFromJson(json);
  Map<String, dynamic> toJson() => _$PlayerInfoToJson(this);
}

@JsonSerializable()
class TeamScores extends Equatable {
  @JsonKey(name: 'ct_score')
  final int? ctScore;
  @JsonKey(name: 't_score')
  final int? tScore;
  @JsonKey(name: 'data_quality')
  final String? dataQuality;

  /// 比分所属的地图名（来自比分推送的 mapName），用于换图后校验比分是否仍然有效
  @JsonKey(name: 'map_name')
  final String? mapName;

  const TeamScores({
    this.ctScore,
    this.tScore,
    this.dataQuality,
    this.mapName,
  });

  factory TeamScores.fromJson(Map<String, dynamic> json) =>
      _$TeamScoresFromJson(json);
  Map<String, dynamic> toJson() => _$TeamScoresToJson(this);

  /// 校验比分所属地图与服务器当前地图是否一致。
  ///
  /// - 任一为空时视为"无法判定"，放行（保持兼容，避免误伤）；
  /// - 同时存在时进行不区分大小写比较，不一致即为过期比分（换图后残留）。
  static bool isMapMatched(String? scoreMap, String? currentMap) {
    if (scoreMap == null || scoreMap.isEmpty) return true;
    if (currentMap == null || currentMap.isEmpty) return true;
    return scoreMap.toLowerCase() == currentMap.toLowerCase();
  }

  /// 该比分是否属于 [currentMap]（换图后用于过滤残留比分）。
  bool matchesMap(String? currentMap) => isMapMatched(mapName, currentMap);

  @override
  List<Object?> get props => [ctScore, tScore, dataQuality, mapName];
}

@JsonSerializable()
class ServerDetailInfo {
  @JsonKey(name: 'server_info')
  final ServerInfo serverInfo;
  @JsonKey(name: 'player_list')
  final List<PlayerInfo> playerList;
  final TeamScores? teams;

  ServerDetailInfo({
    required this.serverInfo,
    required this.playerList,
    this.teams,
  });

  factory ServerDetailInfo.fromJson(Map<String, dynamic> json) =>
      _$ServerDetailInfoFromJson(json);
  Map<String, dynamic> toJson() => _$ServerDetailInfoToJson(this);
}

@JsonSerializable()
class MapData extends Equatable {
  final int id;
  final String mapName;
  final String mapLabel;
  final String mapUrl;
  @JsonKey(defaultValue: <MapTagSimple>[])
  final List<MapTagSimple> tags;

  const MapData({
    required this.id,
    required this.mapName,
    required this.mapLabel,
    required this.mapUrl,
    this.tags = const [],
  });

  factory MapData.fromJson(Map<String, dynamic> json) =>
      _$MapDataFromJson(json);
  Map<String, dynamic> toJson() => _$MapDataToJson(this);

  @override
  List<Object?> get props => [id, mapName, mapLabel, mapUrl, tags];
}

@JsonSerializable()
class MapRuntimeData extends Equatable {
  final int currentRuntime;

  /// 一周内出现次数。第三方接口（如 CS2ZE）不提供该数据，此时为 null。
  final int? weeklyOccurrences;

  const MapRuntimeData({
    required this.currentRuntime,
    this.weeklyOccurrences,
  });

  factory MapRuntimeData.fromJson(Map<String, dynamic> json) =>
      _$MapRuntimeDataFromJson(json);
  Map<String, dynamic> toJson() => _$MapRuntimeDataToJson(this);

  @override
  List<Object?> get props => [currentRuntime, weeklyOccurrences];
}

@JsonSerializable()
class PlayerTrendInfo {
  final int playerCount;
  final String createdAt;

  PlayerTrendInfo({required this.playerCount, required this.createdAt});

  factory PlayerTrendInfo.fromJson(Map<String, dynamic> json) =>
      _$PlayerTrendInfoFromJson(json);
  Map<String, dynamic> toJson() => _$PlayerTrendInfoToJson(this);
}

@JsonSerializable()
class ServerSnapshot {
  final int id;
  final String timestamp;
  final String address;
  final String hostname;
  @JsonKey(name: 'map_name')
  final String mapName;
  @JsonKey(name: 'map_label')
  final String mapLabel;
  @JsonKey(name: 'current_players')
  final int currentPlayers;
  @JsonKey(name: 'max_players')
  final int maxPlayers;
  @JsonKey(name: 'has_password')
  final bool hasPassword;
  @JsonKey(name: 'game_type')
  final String gameType;
  final String category;
  @JsonKey(name: 'is_online')
  final bool isOnline;
  @JsonKey(name: 'created_at')
  final String createdAt;
  final List<PlayerTrendInfo>? infos;
  @JsonKey(name: 'final_ct_score')
  final int? finalCtScore;
  @JsonKey(name: 'final_t_score')
  final int? finalTScore;

  ServerSnapshot({
    required this.id,
    required this.timestamp,
    required this.address,
    required this.hostname,
    required this.mapName,
    required this.mapLabel,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.hasPassword,
    required this.gameType,
    required this.category,
    required this.isOnline,
    required this.createdAt,
    this.infos,
    this.finalCtScore,
    this.finalTScore,
  });

  /// 是否有终局比分
  bool get hasFinalScore => finalCtScore != null && finalTScore != null;

  factory ServerSnapshot.fromJson(Map<String, dynamic> json) =>
      _$ServerSnapshotFromJson(json);
  Map<String, dynamic> toJson() => _$ServerSnapshotToJson(this);
}

class ExtendedServerItem extends Equatable {
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
  final TeamScores? teamScores; // 新增：比分数据
  final int queueCount;
  final int warmupCount;

  const ExtendedServerItem({
    required this.serverItem,
    this.serverData,
    this.mapInfo,
    this.updatedAt,
    this.recentlyUpdated = false,
    this.isLoading = false,
    this.hasError = false,
    this.pingInfo,
    this.mapRuntime,
    this.mapRuntimeLastFetched,
    this.mapRuntimeError = false,
    this.mapRuntimeFetching = false,
    this.consecutiveFailures = 0,
    this.isOffline = false,
    this.teamScores,
    this.queueCount = 0,
    this.warmupCount = 0,
  });

  ExtendedServerItem copyWith({
    ServerItem? serverItem,
    ServerInfo? serverData,
    MapData? mapInfo,
    DateTime? updatedAt,
    bool? recentlyUpdated,
    bool? isLoading,
    bool? hasError,
    ServerPingInfo? pingInfo,
    MapRuntimeData? mapRuntime,
    int? mapRuntimeLastFetched,
    bool? mapRuntimeError,
    bool? mapRuntimeFetching,
    bool clearServerData = false,
    bool clearMapRuntime = false,
    bool clearMapInfo = false,
    int? consecutiveFailures,
    bool? isOffline,
    TeamScores? teamScores,
    bool clearTeamScores = false,
    int? queueCount,
    int? warmupCount,
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
      mapRuntimeLastFetched: clearMapRuntime
          ? null
          : (mapRuntimeLastFetched ?? this.mapRuntimeLastFetched),
      mapRuntimeError: mapRuntimeError ?? this.mapRuntimeError,
      mapRuntimeFetching: mapRuntimeFetching ?? this.mapRuntimeFetching,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      isOffline: isOffline ?? this.isOffline,
      teamScores: clearTeamScores ? null : (teamScores ?? this.teamScores),
      queueCount: queueCount ?? this.queueCount,
      warmupCount: warmupCount ?? this.warmupCount,
    );
  }

  @override
  List<Object?> get props => [
    serverItem,
    serverData,
    mapInfo,
    updatedAt,
    recentlyUpdated,
    isLoading,
    hasError,
    pingInfo,
    mapRuntime,
    mapRuntimeLastFetched,
    mapRuntimeError,
    mapRuntimeFetching,
    consecutiveFailures,
    isOffline,
    teamScores,
    queueCount,
    warmupCount,
  ];
}

@JsonSerializable()
class ServerHistoryData {
  final int total;
  final List<ServerSnapshot> data;

  ServerHistoryData({required this.total, required this.data});

  factory ServerHistoryData.fromJson(Map<String, dynamic> json) =>
      _$ServerHistoryDataFromJson(json);
  Map<String, dynamic> toJson() => _$ServerHistoryDataToJson(this);
}
