import 'package:equatable/equatable.dart';

import '../../models/server_models.dart';
import '../../services/status_window_service.dart';

/// 暖服事件基类
abstract class WarmupEvent extends Equatable {
  const WarmupEvent();

  @override
  List<Object?> get props => [];
}

/// 初始化暖服
class WarmupInitialize extends WarmupEvent {
  final String serverAddress;
  final bool isCustomServer;

  /// 初始服务器信息（可选，用于立即显示已有数据）
  final ServerInfo? initialServerInfo;

  /// 初始地图信息（可选）
  final MapData? initialMapInfo;

  final String? serverName;

  const WarmupInitialize(
    this.serverAddress, {
    this.serverName,
    this.isCustomServer = false,
    this.initialServerInfo,
    this.initialMapInfo,
  });

  @override
  List<Object?> get props => [
    serverAddress,
    serverName,
    isCustomServer,
    initialServerInfo,
    initialMapInfo,
  ];
}

/// 开始暖服
class WarmupStart extends WarmupEvent {
  const WarmupStart();
}

/// 暂停/停止暖服
class WarmupPause extends WarmupEvent {
  const WarmupPause();
}

/// 设置目标人数
class WarmupSetTargetPlayers extends WarmupEvent {
  final int targetPlayers;

  const WarmupSetTargetPlayers(this.targetPlayers);

  @override
  List<Object?> get props => [targetPlayers];
}

/// 设置是否显示浮动窗口
class WarmupSetShowFloatingWindow extends WarmupEvent {
  final bool showFloatingWindow;

  const WarmupSetShowFloatingWindow(this.showFloatingWindow);

  @override
  List<Object?> get props => [showFloatingWindow];
}

/// 倒计时 tick（每秒）
class WarmupCountdownTick extends WarmupEvent {
  const WarmupCountdownTick();
}

/// 取消倒计时
class WarmupCountdownCancel extends WarmupEvent {
  const WarmupCountdownCancel();
}

/// 倒计时结束 / 手动立即加入 → 启动游戏加入服务器
class WarmupLaunchGame extends WarmupEvent {
  const WarmupLaunchGame();
}

/// 刷新服务器信息
class WarmupRefreshServerInfo extends WarmupEvent {
  const WarmupRefreshServerInfo();
}

/// 更新暖服用户数（来自 WS）
class WarmupUsersCountUpdated extends WarmupEvent {
  final int warmupUsersCount;

  const WarmupUsersCountUpdated(this.warmupUsersCount);

  @override
  List<Object?> get props => [warmupUsersCount];
}

/// 状态更新（内部使用，来自 StatusWindowService）
class WarmupStateUpdated extends WarmupEvent {
  final OperationState state;

  const WarmupStateUpdated(this.state);

  @override
  List<Object?> get props => [state];
}

/// 触发倒计时 (内部事件)
class WarmupTriggerCountdown extends WarmupEvent {
  const WarmupTriggerCountdown();
}

/// 销毁暖服
class WarmupDispose extends WarmupEvent {
  const WarmupDispose();
}
