part of 'lobby_bloc.dart';

abstract class LobbyEvent extends Equatable {
  const LobbyEvent();

  @override
  List<Object?> get props => [];
}

class LobbyStarted extends LobbyEvent {
  const LobbyStarted();
}

class LobbySceneTapped extends LobbyEvent {
  final LobbyPosition position;

  const LobbySceneTapped(this.position);

  @override
  List<Object?> get props => [position];
}

class LobbyMovementTicked extends LobbyEvent {
  const LobbyMovementTicked();
}

/// 角色到达目标时的事件（由 LobbyGame 触发）
/// 用于通知 Bloc 更新状态，避免其他角色误判为仍在移动
class LobbyPlayerArrived extends LobbyEvent {
  final String userId;
  final LobbyPosition arrivedPosition;

  const LobbyPlayerArrived(this.userId, this.arrivedPosition);

  @override
  List<Object?> get props => [userId, arrivedPosition];
}

class LobbyChatModeChanged extends LobbyEvent {
  final bool isActive;

  const LobbyChatModeChanged(this.isActive);

  @override
  List<Object?> get props => [isActive];
}

class LobbyChatSubmitted extends LobbyEvent {
  final String content;
  const LobbyChatSubmitted(this.content);

  @override
  List<Object?> get props => [content];
}

class LobbyPlayersPanelToggled extends LobbyEvent {
  const LobbyPlayersPanelToggled();
}

class LobbySettingsPanelToggled extends LobbyEvent {
  const LobbySettingsPanelToggled();
}

class LobbySpriteSelected extends LobbyEvent {
  final String spriteId;

  const LobbySpriteSelected(this.spriteId);

  @override
  List<Object?> get props => [spriteId];
}

class LobbyAnonymousToggled extends LobbyEvent {
  final bool value;

  const LobbyAnonymousToggled(this.value);

  @override
  List<Object?> get props => [value];
}

class LobbyChatOpacityChanged extends LobbyEvent {
  final double value;

  const LobbyChatOpacityChanged(this.value);

  @override
  List<Object?> get props => [value];
}

class LobbyNameplatesToggled extends LobbyEvent {
  final bool value;

  const LobbyNameplatesToggled(this.value);

  @override
  List<Object?> get props => [value];
}

class LobbyChatBubblesToggled extends LobbyEvent {
  final bool value;

  const LobbyChatBubblesToggled(this.value);

  @override
  List<Object?> get props => [value];
}

class LobbyUseSteamNameToggled extends LobbyEvent {
  final bool value;

  const LobbyUseSteamNameToggled(this.value);

  @override
  List<Object?> get props => [value];
}

class LobbyTeleportStarted extends LobbyEvent {
  final LobbyTeleportTarget target;

  const LobbyTeleportStarted(this.target);

  @override
  List<Object?> get props => [target];
}

class LobbyTeleportCompleted extends LobbyEvent {
  const LobbyTeleportCompleted();
}

class LobbyTransientNoticeShown extends LobbyEvent {
  const LobbyTransientNoticeShown();
}

class LobbyBubbleExpired extends LobbyEvent {
  const LobbyBubbleExpired();
}

/// 玩家通知过期（从显示队列中移除）
class LobbyNotificationExpired extends LobbyEvent {
  final String notificationId;

  const LobbyNotificationExpired(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class LobbyWsEventReceived extends LobbyEvent {
  final LobbyWsEvent event;

  const LobbyWsEventReceived(this.event);

  @override
  List<Object?> get props => [event];
}

class LobbyPanelsDismissed extends LobbyEvent {
  const LobbyPanelsDismissed();
}

/// 内部事件：assets 收到后更新状态
class _LobbyAssetsReceived extends LobbyEvent {
  final LobbyServerEvent serverEvent;

  const _LobbyAssetsReceived(this.serverEvent);

  @override
  List<Object?> get props => [serverEvent];
}

/// 内部事件：设置加载更多状态
class _LobbySetLoadingMore extends LobbyEvent {
  final bool isLoadingMore;

  const _LobbySetLoadingMore(this.isLoadingMore);

  @override
  List<Object?> get props => [isLoadingMore];
}

/// 内部事件：游戏运行状态变化
class _LobbyGameStatusChanged extends LobbyEvent {
  final bool isGameRunning;

  const _LobbyGameStatusChanged(this.isGameRunning);

  @override
  List<Object?> get props => [isGameRunning];
}

/// 页面活动状态改变（在外部导航切换时触发）
class LobbyPageActivityChanged extends LobbyEvent {
  final String pageActivityText;

  const LobbyPageActivityChanged(this.pageActivityText);

  @override
  List<Object?> get props => [pageActivityText];
}

/// 内部事件：聊天冷却倒计时
class _LobbyChatCooldownTick extends LobbyEvent {
  const _LobbyChatCooldownTick();
}

/// 内部事件：匿名切换冷却倒计时
class _LobbyAnonymousSwitchCooldownTick extends LobbyEvent {
  const _LobbyAnonymousSwitchCooldownTick();
}

class _LobbySteamNameSwitchCooldownTick extends LobbyEvent {
  const _LobbySteamNameSwitchCooldownTick();
}

/// 用户退出登录后重置状态（清除用户关联信息，但保留匿名可用）
class LobbyLogoutConfirmed extends LobbyEvent {
  const LobbyLogoutConfirmed();
}

/// 切换广播弹窗显示
class LobbyBroadcastDialogToggled extends LobbyEvent {
  const LobbyBroadcastDialogToggled();
}

/// 提交广播消息
class LobbyBroadcastSubmitted extends LobbyEvent {
  final String content;

  const LobbyBroadcastSubmitted(this.content);

  @override
  List<Object?> get props => [content];
}

/// 内部事件：广播冷却倒计时
class _LobbyBroadcastCooldownTick extends LobbyEvent {
  const _LobbyBroadcastCooldownTick();
}

/// 鼠标进入传送门区域
class LobbyPortalEntered extends LobbyEvent {
  final LobbyPortal portal;

  const LobbyPortalEntered(this.portal);

  @override
  List<Object?> get props => [portal];
}

/// 鼠标离开传送门区域
class LobbyPortalExited extends LobbyEvent {
  const LobbyPortalExited();
}

/// 传送门悬停状态变化
class LobbyPortalHoverChanged extends LobbyEvent {
  final bool isHovered;

  const LobbyPortalHoverChanged(this.isHovered);

  @override
  List<Object?> get props => [isHovered];
}

/// 确认传送请求
class LobbyPortalConfirmRequested extends LobbyEvent {
  final String portalKey;

  const LobbyPortalConfirmRequested(this.portalKey);

  @override
  List<Object?> get props => [portalKey];
}

/// 点击传送门区域（由 LobbyGame 触发）
class LobbyPortalClicked extends LobbyEvent {
  final LobbyPosition clickPosition;

  const LobbyPortalClicked(this.clickPosition);

  @override
  List<Object?> get props => [clickPosition];
}

/// 显示传送门询问对话框
class LobbyPortalDialogShowed extends LobbyEvent {
  final LobbyPortal portal;

  const LobbyPortalDialogShowed(this.portal);

  @override
  List<Object?> get props => [portal];
}

/// 隐藏传送门询问对话框
class LobbyPortalDialogDismissed extends LobbyEvent {
  const LobbyPortalDialogDismissed();
}

/// 请求全服在线用户列表（用于玩家面板）
class LobbyOnlineStatsRequested extends LobbyEvent {
  const LobbyOnlineStatsRequested();
}

/// 内部事件：设置选项超时（等待服务器确认超时后触发）
class _LobbySettingTimeout extends LobbyEvent {
  final String settingKey;

  const _LobbySettingTimeout(this.settingKey);

  @override
  List<Object?> get props => [settingKey];
}

/// 内部事件：检查所有设置项的超时状态
class _LobbySettingsTimeoutCheck extends LobbyEvent {
  const _LobbySettingsTimeoutCheck();
}

/// 用户在被踢提示页面点击操作按钮（重新登录/知道了）
class LobbyKickedDismissed extends LobbyEvent {
  const LobbyKickedDismissed();
}

/// 清除所有玩家的聊天气泡状态（从后台恢复时调用）
class LobbyChatBubblesCleared extends LobbyEvent {
  const LobbyChatBubblesCleared();
}

/// 请求重新获取 snapshot（从后台恢复时调用，确保数据最新）
class LobbySnapshotRefreshRequested extends LobbyEvent {
  const LobbySnapshotRefreshRequested();
}

/// 应用从后台恢复时触发（检查排队状态 + snapshot 对齐）
class LobbyAppResumed extends LobbyEvent {
  const LobbyAppResumed();
}

/// 排队状态更新（内部事件，由轮询定时器触发）
class _LobbyQueueStatusUpdated extends LobbyEvent {
  final int position;
  final int queueTotal;
  final int etaSeconds;

  const _LobbyQueueStatusUpdated({
    required this.position,
    required this.queueTotal,
    required this.etaSeconds,
  });

  @override
  List<Object?> get props => [position, queueTotal, etaSeconds];
}

/// 排队就绪（可以进入大厅）
class _LobbyQueueReady extends LobbyEvent {
  final String matchId;

  const _LobbyQueueReady(this.matchId);

  @override
  List<Object?> get props => [matchId];
}

/// 排队过期
class _LobbyQueueExpired extends LobbyEvent {
  final String reason;

  const _LobbyQueueExpired(this.reason);

  @override
  List<Object?> get props => [reason];
}

/// 用户取消排队
class LobbyQueueCancelled extends LobbyEvent {
  const LobbyQueueCancelled();
}

/// 排队开始（从 service 层收到排队响应）
class _LobbyQueueStarted extends LobbyEvent {
  final String ticket;
  final int position;
  final int queueTotal;
  final int etaSeconds;
  final int pollIntervalMs;

  const _LobbyQueueStarted({
    required this.ticket,
    required this.position,
    required this.queueTotal,
    required this.etaSeconds,
    required this.pollIntervalMs,
  });

  @override
  List<Object?> get props => [
    ticket,
    position,
    queueTotal,
    etaSeconds,
    pollIntervalMs,
  ];
}
