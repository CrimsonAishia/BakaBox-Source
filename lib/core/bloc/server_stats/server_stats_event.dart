import 'package:equatable/equatable.dart';

abstract class ServerStatsEvent extends Equatable {
  const ServerStatsEvent();

  @override
  List<Object?> get props => [];
}

/// 获取统计数据
class ServerStatsFetch extends ServerStatsEvent {
  const ServerStatsFetch();
}

/// 刷新统计数据
class ServerStatsRefresh extends ServerStatsEvent {
  const ServerStatsRefresh();
}
