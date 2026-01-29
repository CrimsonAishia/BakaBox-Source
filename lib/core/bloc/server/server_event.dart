import 'package:equatable/equatable.dart';
import '../../models/server_models.dart';

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
  List<Object?> get props => [address, pingInfo, mapInfo, mapRuntime, mapRuntimeError];
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
  const ServerAddServer({required this.categoryName, required this.serverAddress});
  @override
  List<Object?> get props => [categoryName, serverAddress];
}

/// 删除自定义分类
class ServerDeleteCategory extends ServerEvent {
  final String categoryName;
  const ServerDeleteCategory(this.categoryName);
  @override
  List<Object?> get props => [categoryName];
}

/// 删除自定义服务器
class ServerDeleteServer extends ServerEvent {
  final String categoryName;
  final String serverAddress;
  const ServerDeleteServer({required this.categoryName, required this.serverAddress});
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
  const ServerEditServer({
    required this.categoryName,
    required this.oldServerAddress,
    required this.newServerAddress,
  });
  @override
  List<Object?> get props => [categoryName, oldServerAddress, newServerAddress];
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
