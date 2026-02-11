import 'package:equatable/equatable.dart';

import '../../models/server_models.dart';
import '../../services/status_window_service.dart';

/// 挤服事件基类
abstract class QueueEvent extends Equatable {
  const QueueEvent();

  @override
  List<Object?> get props => [];
}

/// 初始化挤服
class QueueInitialize extends QueueEvent {
  final String serverAddress;
  final bool isCustomServer;
  /// 初始服务器信息（可选，用于立即显示已有数据）
  final ServerInfo? initialServerInfo;
  /// 初始地图信息（可选）
  final MapData? initialMapInfo;

  const QueueInitialize(
    this.serverAddress, {
    this.isCustomServer = false,
    this.initialServerInfo,
    this.initialMapInfo,
  });

  @override
  List<Object?> get props => [serverAddress, isCustomServer, initialServerInfo, initialMapInfo];
}

/// 开始挤服
class QueueStart extends QueueEvent {
  const QueueStart();
}

/// 暂停挤服
class QueuePause extends QueueEvent {
  const QueuePause();
}

/// 设置目标人数
class QueueSetTargetPlayers extends QueueEvent {
  final int targetPlayers;

  const QueueSetTargetPlayers(this.targetPlayers);

  @override
  List<Object?> get props => [targetPlayers];
}

/// 设置线程数量
class QueueSetThreadCount extends QueueEvent {
  final int threadCount;

  const QueueSetThreadCount(this.threadCount);

  @override
  List<Object?> get props => [threadCount];
}

/// 设置自动重试
class QueueSetAutoRetry extends QueueEvent {
  final bool enable;

  const QueueSetAutoRetry(this.enable);

  @override
  List<Object?> get props => [enable];
}

/// 设置是否捐助者
class QueueSetDonator extends QueueEvent {
  final bool isDonator;

  const QueueSetDonator(this.isDonator);

  @override
  List<Object?> get props => [isDonator];
}

/// 启动游戏
class QueueLaunchGame extends QueueEvent {
  const QueueLaunchGame();
}

/// 刷新服务器信息
class QueueRefreshServerInfo extends QueueEvent {
  const QueueRefreshServerInfo();
}

/// 状态更新（内部使用）
class QueueStateUpdated extends QueueEvent {
  final OperationState state;

  const QueueStateUpdated(this.state);

  @override
  List<Object?> get props => [state];
}

/// 销毁挤服
class QueueDispose extends QueueEvent {
  const QueueDispose();
}
