import 'package:equatable/equatable.dart';
import '../../models/server_models.dart';
import '../../models/server_score.dart';

abstract class ServerEvent extends Equatable {
  const ServerEvent();
  @override
  List<Object?> get props => [];
}

class ServerFetchList extends ServerEvent {}

class ServerSelectCategory extends ServerEvent {
  final ServerCategory category;
  final bool forceRefresh;
  const ServerSelectCategory(this.category, {this.forceRefresh = false});
  @override
  List<Object?> get props => [category, forceRefresh];
}

class ServerClearCategory extends ServerEvent {}

class ServerRefresh extends ServerEvent {}

class ServerStartPeriodicRefresh extends ServerEvent {}

class ServerStopPeriodicRefresh extends ServerEvent {}

class ServerPauseRefresh extends ServerEvent {}

class ServerResumeRefresh extends ServerEvent {}

class ServerLifecycleChanged extends ServerEvent {
  final bool isResumed;
  const ServerLifecycleChanged(this.isResumed);
  @override
  List<Object?> get props => [isResumed];
}

class ServerClearMapCache extends ServerEvent {
  final String? mapName;
  const ServerClearMapCache([this.mapName]);
  @override
  List<Object?> get props => [mapName];
}

class ServerConnect extends ServerEvent {
  final ExtendedServerItem server;
  final String? password;
  const ServerConnect(this.server, {this.password});
  @override
  List<Object?> get props => [server, password];
}

class ServerUpdateCategoryOnlineCounts extends ServerEvent {}

/// 无感刷新服务器列表（不显示骨架屏）
class ServerRefreshServers extends ServerEvent {}

/// 更新单个服务器的附加信息（ping、地图信息、运行时间）
class ServerUpdateSingleServer extends ServerEvent {
  final String address;
  final ServerPingInfo? pingInfo;
  final MapData? mapInfo;
  final MapRuntimeData? mapRuntime;
  final bool? mapRuntimeError;

  const ServerUpdateSingleServer({
    required this.address,
    this.pingInfo,
    this.mapInfo,
    this.mapRuntime,
    this.mapRuntimeError,
  });

  @override
  List<Object?> get props => [
    address,
    pingInfo,
    mapInfo,
    mapRuntime,
    mapRuntimeError,
  ];
}

/// 内部事件:清除 recentlyUpdated 标记
class ServerClearRecentlyUpdated extends ServerEvent {
  final int requestId;
  const ServerClearRecentlyUpdated(this.requestId);
  @override
  List<Object?> get props => [requestId];
}

/// 添加自定义分类
class ServerAddCategory extends ServerEvent {
  final String categoryName;
  const ServerAddCategory(this.categoryName);
  @override
  List<Object?> get props => [categoryName];
}

/// 添加自定义服务器到指定分类
class ServerAddServer extends ServerEvent {
  final String categoryName;
  final String serverAddress;
  final String? nickname; // 备注名
  const ServerAddServer({
    required this.categoryName,
    required this.serverAddress,
    this.nickname,
  });
  @override
  List<Object?> get props => [categoryName, serverAddress, nickname];
}

/// 批量添加完整服务器对象到分类
class ServerAddServerToCategory extends ServerEvent {
  final String categoryName;
  final ServerItem serverItem;
  final bool isFromApi;
  final String? sourceApiUrl;
  final String? sourceApiCategoryName;
  
  const ServerAddServerToCategory(
    this.categoryName,
    this.serverItem, {
    this.isFromApi = false,
    this.sourceApiUrl,
    this.sourceApiCategoryName,
  });
  @override
  List<Object?> get props => [categoryName, serverItem, isFromApi, sourceApiUrl, sourceApiCategoryName];
}

/// 删除自定义分类
class ServerDeleteCategory extends ServerEvent {
  final String categoryName;
  const ServerDeleteCategory(this.categoryName);
  @override
  List<Object?> get props => [categoryName];
}

/// 重命名自定义分类
class ServerRenameCategory extends ServerEvent {
  final String oldName;
  final String newName;
  const ServerRenameCategory({required this.oldName, required this.newName});
  @override
  List<Object?> get props => [oldName, newName];
}

/// 删除自定义服务器
class ServerDeleteServer extends ServerEvent {
  final String categoryName;
  final String serverAddress;
  const ServerDeleteServer({
    required this.categoryName,
    required this.serverAddress,
  });
  @override
  List<Object?> get props => [categoryName, serverAddress];
}

/// 重置倒计时
class ServerResetCountdown extends ServerEvent {}

/// 刷新单个地图的缓存
class ServerRefreshMapCache extends ServerEvent {
  final String address;
  final String mapName;
  const ServerRefreshMapCache({required this.address, required this.mapName});
  @override
  List<Object?> get props => [address, mapName];
}

/// 切换分类 tab（0=默认分类，1=自定义分类）
class ServerSwitchTab extends ServerEvent {
  final int tabIndex;
  const ServerSwitchTab(this.tabIndex);
  @override
  List<Object?> get props => [tabIndex];
}

/// 编辑自定义服务器地址
class ServerEditServer extends ServerEvent {
  final String categoryName;
  final String oldServerAddress;
  final String newServerAddress;
  final String? nickname; // 备注名
  const ServerEditServer({
    required this.categoryName,
    required this.oldServerAddress,
    required this.newServerAddress,
    this.nickname,
  });
  @override
  List<Object?> get props => [
    categoryName,
    oldServerAddress,
    newServerAddress,
    nickname,
  ];
}

/// 更新被编辑服务器的数据（内部事件）
class ServerUpdateEditedServer extends ServerEvent {
  final String serverAddress;
  final ServerInfo? serverData;
  final bool hasError;
  const ServerUpdateEditedServer({
    required this.serverAddress,
    this.serverData,
    this.hasError = false,
  });
  @override
  List<Object?> get props => [serverAddress, serverData, hasError];
}

/// 重新排序自定义服务器
class ServerReorderServers extends ServerEvent {
  final String categoryName;
  final int oldIndex;
  final int newIndex;
  const ServerReorderServers({
    required this.categoryName,
    required this.oldIndex,
    required this.newIndex,
  });
  @override
  List<Object?> get props => [categoryName, oldIndex, newIndex];
}

/// 重新排序自定义分类
class ServerReorderCategories extends ServerEvent {
  final int oldIndex;
  final int newIndex;
  const ServerReorderCategories({
    required this.oldIndex,
    required this.newIndex,
  });
  @override
  List<Object?> get props => [oldIndex, newIndex];
}

/// 强制刷新服务器列表（重置所有状态，用于手动点击刷新）
class ServerForceRefresh extends ServerEvent {}

/// 内部事件：定时刷新分类列表（静默更新，不影响当前选中分类）
/// 由 ServerBloc 内部定时器触发，不应在外部使用。
class ServerRefreshCategoriesInternal extends ServerEvent {
  const ServerRefreshCategoriesInternal();
}

/// 用户确认应用待更新的分类列表
class ServerApplyPendingCategories extends ServerEvent {
  const ServerApplyPendingCategories();
}

/// 用户忽略待更新的分类列表
class ServerDismissPendingCategories extends ServerEvent {
  const ServerDismissPendingCategories();
}

/// 内部事件：来自 `score.updates` WS 频道的比分更新
class ServerApplyScoreUpdates extends ServerEvent {
  final List<ServerScore> scores;

  /// 是否为 snapshot（true 表示需要将所有不在 snapshot 中的服务器比分清空？
  /// 实际不清，只覆盖入参里的条目，避免与本地的“无比分”状态冲突）
  final bool isSnapshot;

  const ServerApplyScoreUpdates({
    required this.scores,
    required this.isSnapshot,
  });

  @override
  List<Object?> get props => [scores, isSnapshot];
}

/// 内部事件：来自 `server.map.runtime` WS 频道的换图事件
class ServerApplyMapRuntimeChange extends ServerEvent {
  final String serverAddress;
  final String newMapName;
  final String? oldMapName;
  final int? weeklyOccurrences;
  final int? changedAt;

  const ServerApplyMapRuntimeChange({
    required this.serverAddress,
    required this.newMapName,
    this.oldMapName,
    this.weeklyOccurrences,
    this.changedAt,
  });

  @override
  List<Object?> get props => [serverAddress, newMapName, oldMapName, weeklyOccurrences, changedAt];
}

/// 内部事件：处理来自 `server.map.runtime` WS 频道的初始快照
class ServerApplyMapRuntimeSnapshot extends ServerEvent {
  const ServerApplyMapRuntimeSnapshot();
}

/// 内部事件：来自 `map.info` WS 频道的地图信息变更（背景图/标签等元数据）
///
/// 与 [ServerApplyMapRuntimeChange]（换图）不同：地图没变，只是该地图的
/// 背景/标签等元数据被后端修改。收到后立即刷新所有正在显示该地图的卡片，
/// 不必等下一个轮询周期。
class ServerApplyMapInfoChange extends ServerEvent {
  /// 地图名（已小写）
  final String mapName;

  const ServerApplyMapInfoChange({required this.mapName});

  @override
  List<Object?> get props => [mapName];
}

/// 内部事件：来自 `server.users.count` WS 频道的人数更新
class ServerApplyUsersCountUpdates extends ServerEvent {
  final List<ServerUsersCount> counts;
  final bool isSnapshot;

  const ServerApplyUsersCountUpdates({
    required this.counts,
    required this.isSnapshot,
  });

  @override
  List<Object?> get props => [counts, isSnapshot];
}

/// 清除实时数据（进入弱网模式时调用）
/// 清除所有服务器卡片上通过 Realtime 推送获得的数据（比分、人数等），
/// 避免推送停止后卡片仍显示过期的实时数据。
class ServerClearRealtimeData extends ServerEvent {}
