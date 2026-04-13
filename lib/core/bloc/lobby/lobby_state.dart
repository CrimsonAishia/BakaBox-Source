part of 'lobby_bloc.dart';

enum LobbyConnectionStatus { disconnected, connecting, connected, reconnecting, failed }

/// 大厅页面加载状态（区分进入页面的不同阶段）
enum LobbyPageStatus { idle, loading, ready, error }

/// 大厅 Loading 界面的加载阶段（用于显示具体进度）
enum LobbyLoadingPhase {
  /// 等待 WebSocket 连接建立
  connecting,
  /// 连接已建立，等待数据
  waiting,
  /// 正在加载素材数据
  loadingAssets,
  /// 素材加载完成，正在获取大厅状态
  loadingSnapshot,
}

/// 玩家通知类型
enum PlayerNotificationType {
  /// 玩家进入大厅
  join,
  /// 玩家离开大厅
  leave,
  /// 玩家传送到其他地图
  teleport,
}

/// 玩家通知数据模型
class PlayerNotification {
  /// 通知唯一ID
  final String id;
  /// 通知类型
  final PlayerNotificationType type;
  /// 玩家显示名称
  final String playerName;
  /// 目标地图名称（传送类型使用）
  final String? targetMapName;
  /// 通知创建时间
  final DateTime createdAt;

  const PlayerNotification({
    required this.id,
    required this.type,
    required this.playerName,
    this.targetMapName,
    required this.createdAt,
  });

  /// 生成描述文字
  String get message {
    switch (type) {
      case PlayerNotificationType.join:
        return '$playerName 进入了大厅';
      case PlayerNotificationType.leave:
        return '$playerName 离开了大厅';
      case PlayerNotificationType.teleport:
        return '$playerName 传送到了 ${targetMapName ?? "未知地图"}';
    }
  }
}

class LobbyState extends Equatable {
  final LobbyConnectionStatus connectionStatus;
  final LobbyPageStatus pageStatus;
  /// 大厅页面对应的活动文字（如"在看服务器列表"）
  final String pageActivityText;
  /// Loading 界面的具体加载阶段
  final LobbyLoadingPhase loadingPhase;
  final LobbyAssets assets;
  final List<LobbyUser> users;
  final List<LobbyMessage> messages;
  final String selectedSpriteId;
  final bool isAnonymous;
  final bool isChatActive;
  final String chatDraft;
  final bool isPlayersPanelOpen;
  final bool isSettingsPanelOpen;
  final double chatOpacity;
  final bool showNameplates;
  final bool showChatBubbles;
  final bool useSteamName;
  final String? transientNotice;
  final LobbyTeleportTarget? teleportTarget;
  final bool isTeleporting;
  final LobbyPageInfo? pageInfo;
  final bool isLoadingMore;
  /// 待重发的消息队列（messageId -> content）
  final Map<String, String> pendingMessages;
  /// 聊天冷却剩余秒数（0 表示不在冷却中）
  final int chatCooldownSeconds;
  /// 广播冷却剩余秒数（0 表示不在冷却中）
  final int broadcastCooldownSeconds;
  /// 匿名切换冷却剩余秒数（0 表示不在冷却中）
  final int anonymousSwitchCooldownSeconds;
  /// Steam名称切换冷却剩余秒数（0 表示不在冷却中）
  final int steamNameSwitchCooldownSeconds;
  /// 广播弹窗是否打开
  final bool isBroadcastDialogOpen;
  /// 当前显示询问对话框的传送门
  final LobbyPortal? nearbyPortal;
  /// 正在走向的传送门（到达后自动显示对话框）
  final LobbyPortal? pendingPortal;
  /// 传送门是否被鼠标悬停
  final bool isPortalHovered;
  /// 全服在线用户列表（用于玩家面板，从 online.stats 接口获取）
  final List<LobbyUser> allOnlineUsers;
  /// 是否正在加载全服用户列表
  final bool isLoadingAllOnlineUsers;
  /// 服务器在线总人数（定时刷新，用于玩家按钮徽章）
  final int serverOnlineCount;
  /// 是否显示广播通知窗口
  final bool showBroadcastNotifications;
  /// 设置选项的 pending 状态（用于服务器确认/拒绝）
  final Map<String, bool> pendingSettings;
  /// pending 状态的超时时间（key: 设置项名, value: 超时截止时间）
  final Map<String, DateTime> pendingSettingsTimeouts;
  /// 玩家加入/离开通知列表
  final List<PlayerNotification> playerNotifications;

  const LobbyState({
    required this.connectionStatus,
    required this.pageStatus,
    this.pageActivityText = '在线',
    required this.loadingPhase,
    required this.assets,
    required this.users,
    required this.messages,
    required this.selectedSpriteId,
    required this.isAnonymous,
    required this.isChatActive,
    required this.chatDraft,
    required this.isPlayersPanelOpen,
    required this.isSettingsPanelOpen,
    required this.chatOpacity,
    required this.showNameplates,
    required this.showChatBubbles,
    required this.useSteamName,
    required this.transientNotice,
    this.teleportTarget,
    this.isTeleporting = false,
    this.pageInfo,
    this.isLoadingMore = false,
    this.pendingMessages = const {},
    this.chatCooldownSeconds = 0,
    this.broadcastCooldownSeconds = 0,
    this.isBroadcastDialogOpen = false,
    this.nearbyPortal,
    this.pendingPortal,
    this.isPortalHovered = false,
    this.allOnlineUsers = const [],
    this.isLoadingAllOnlineUsers = false,
    this.serverOnlineCount = 0,
    this.showBroadcastNotifications = true,
    this.pendingSettings = const {},
    this.pendingSettingsTimeouts = const {},
    this.anonymousSwitchCooldownSeconds = 0,
    this.steamNameSwitchCooldownSeconds = 0,
    this.playerNotifications = const [],
  });

  factory LobbyState.initial() {
    return const LobbyState(
      connectionStatus: LobbyConnectionStatus.disconnected,
      pageStatus: LobbyPageStatus.idle,
      pageActivityText: '在线',
      loadingPhase: LobbyLoadingPhase.connecting,
      assets: LobbyAssets(),
      users: <LobbyUser>[],
      messages: <LobbyMessage>[],
      selectedSpriteId: 'sprite_01',
      isAnonymous: false,
      isChatActive: false,
      chatDraft: '',
      isPlayersPanelOpen: false,
      isSettingsPanelOpen: false,
      chatOpacity: 0.32,
      showNameplates: true,
      showChatBubbles: true,
      useSteamName: false,
      transientNotice: null,
      teleportTarget: null,
      isTeleporting: false,
      pageInfo: null,
      isLoadingMore: false,
      pendingMessages: {},
      chatCooldownSeconds: 0,
      broadcastCooldownSeconds: 0,
      isBroadcastDialogOpen: false,
      allOnlineUsers: [],
      isLoadingAllOnlineUsers: false,
      serverOnlineCount: 0,
      showBroadcastNotifications: true,
      pendingSettings: {},
      pendingSettingsTimeouts: {},
      anonymousSwitchCooldownSeconds: 0,
      steamNameSwitchCooldownSeconds: 0,
      playerNotifications: [],
    );
  }

  LobbyUser? get selfUser {
    for (final user in users) {
      if (user.isSelf) return user;
    }
    return null;
  }

  LobbyMapConfig? get mapConfig => assets.mapConfig;

  List<LobbySprite> get availableSprites => assets.sprites;

  int get onlineCount => users.where((user) => user.isOnline).length;

  /// 全服在线人数
  int get totalOnlineCount => allOnlineUsers.where((user) => user.isOnline).length;

  LobbyState copyWith({
    LobbyConnectionStatus? connectionStatus,
    LobbyPageStatus? pageStatus,
    String? pageActivityText,
    LobbyLoadingPhase? loadingPhase,
    Object? assets = _stateSentinel,
    List<LobbyUser>? users,
    List<LobbyMessage>? messages,
    String? selectedSpriteId,
    bool? isAnonymous,
    bool? isChatActive,
    String? chatDraft,
    bool? isPlayersPanelOpen,
    bool? isSettingsPanelOpen,
    double? chatOpacity,
    bool? showNameplates,
    bool? showChatBubbles,
    bool? useSteamName,
    Object? transientNotice = _stateSentinel,
    bool clearTransientNotice = false,
    Object? teleportTarget = _stateSentinel,
    bool clearTeleportTarget = false,
    bool? isTeleporting,
    Object? pageInfo = _stateSentinel,
    bool clearPageInfo = false,
    bool? isLoadingMore,
    Object? pendingMessages = _stateSentinel,
    int? chatCooldownSeconds,
    int? broadcastCooldownSeconds,
    bool? isBroadcastDialogOpen,
    Object? nearbyPortal = _stateSentinel,
    bool clearNearbyPortal = false,
    Object? pendingPortal = _stateSentinel,
    bool clearPendingPortal = false,
    bool? isPortalHovered,
    Object? allOnlineUsers = _stateSentinel,
    bool? isLoadingAllOnlineUsers,
    int? serverOnlineCount,
    bool? showBroadcastNotifications,
    Object? pendingSettings = _stateSentinel,
    Object? pendingSettingsTimeouts = _stateSentinel,
    int? anonymousSwitchCooldownSeconds,
    int? steamNameSwitchCooldownSeconds,
    Object? playerNotifications = _stateSentinel,
  }) {
    return LobbyState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      pageStatus: pageStatus ?? this.pageStatus,
      pageActivityText: pageActivityText ?? this.pageActivityText,
      loadingPhase: loadingPhase ?? this.loadingPhase,
      assets: identical(assets, _stateSentinel)
          ? this.assets
          : assets as LobbyAssets,
      users: users ?? this.users,
      messages: messages ?? this.messages,
      selectedSpriteId: selectedSpriteId ?? this.selectedSpriteId,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isChatActive: isChatActive ?? this.isChatActive,
      chatDraft: chatDraft ?? this.chatDraft,
      isPlayersPanelOpen: isPlayersPanelOpen ?? this.isPlayersPanelOpen,
      isSettingsPanelOpen: isSettingsPanelOpen ?? this.isSettingsPanelOpen,
      chatOpacity: chatOpacity ?? this.chatOpacity,
      showNameplates: showNameplates ?? this.showNameplates,
      showChatBubbles: showChatBubbles ?? this.showChatBubbles,
      useSteamName: useSteamName ?? this.useSteamName,
      transientNotice: clearTransientNotice
          ? null
          : identical(transientNotice, _stateSentinel)
          ? this.transientNotice
          : transientNotice as String?,
      teleportTarget: clearTeleportTarget
          ? null
          : identical(teleportTarget, _stateSentinel)
          ? this.teleportTarget
          : teleportTarget as LobbyTeleportTarget?,
      isTeleporting: isTeleporting ?? this.isTeleporting,
      pageInfo: clearPageInfo
          ? null
          : identical(pageInfo, _stateSentinel)
          ? this.pageInfo
          : pageInfo as LobbyPageInfo?,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      pendingMessages: identical(pendingMessages, _stateSentinel)
          ? this.pendingMessages
          : pendingMessages as Map<String, String>,
      chatCooldownSeconds: chatCooldownSeconds ?? this.chatCooldownSeconds,
      broadcastCooldownSeconds: broadcastCooldownSeconds ?? this.broadcastCooldownSeconds,
      isBroadcastDialogOpen: isBroadcastDialogOpen ?? this.isBroadcastDialogOpen,
      nearbyPortal: clearNearbyPortal
          ? null
          : identical(nearbyPortal, _stateSentinel)
          ? this.nearbyPortal
          : nearbyPortal as LobbyPortal?,
      pendingPortal: clearPendingPortal
          ? null
          : identical(pendingPortal, _stateSentinel)
          ? this.pendingPortal
          : pendingPortal as LobbyPortal?,
      isPortalHovered: isPortalHovered ?? this.isPortalHovered,
      allOnlineUsers: identical(allOnlineUsers, _stateSentinel)
          ? this.allOnlineUsers
          : allOnlineUsers as List<LobbyUser>,
      isLoadingAllOnlineUsers: isLoadingAllOnlineUsers ?? this.isLoadingAllOnlineUsers,
      serverOnlineCount: serverOnlineCount ?? this.serverOnlineCount,
      showBroadcastNotifications: showBroadcastNotifications ?? this.showBroadcastNotifications,
      pendingSettings: identical(pendingSettings, _stateSentinel)
          ? this.pendingSettings
          : pendingSettings as Map<String, bool>,
      pendingSettingsTimeouts: identical(pendingSettingsTimeouts, _stateSentinel)
          ? this.pendingSettingsTimeouts
          : pendingSettingsTimeouts as Map<String, DateTime>,
      anonymousSwitchCooldownSeconds: anonymousSwitchCooldownSeconds ?? this.anonymousSwitchCooldownSeconds,
      steamNameSwitchCooldownSeconds: steamNameSwitchCooldownSeconds ?? this.steamNameSwitchCooldownSeconds,
      playerNotifications: identical(playerNotifications, _stateSentinel)
          ? this.playerNotifications
          : playerNotifications as List<PlayerNotification>,
    );
  }

  @override
  List<Object?> get props => [
    connectionStatus,
    pageStatus,
    pageActivityText,
    loadingPhase,
    assets,
    users,
    messages,
    selectedSpriteId,
    isAnonymous,
    isChatActive,
    chatDraft,
    isPlayersPanelOpen,
    isSettingsPanelOpen,
    chatOpacity,
    showNameplates,
    showChatBubbles,
    useSteamName,
    transientNotice,
    teleportTarget,
    isTeleporting,
    pageInfo,
    isLoadingMore,
    pendingMessages,
    chatCooldownSeconds,
    broadcastCooldownSeconds,
    isBroadcastDialogOpen,
    nearbyPortal,
    pendingPortal,
    isPortalHovered,
    allOnlineUsers,
    isLoadingAllOnlineUsers,
    serverOnlineCount,
    showBroadcastNotifications,
    pendingSettings,
    pendingSettingsTimeouts,
    anonymousSwitchCooldownSeconds,
    steamNameSwitchCooldownSeconds,
    playerNotifications,
  ];
}

const Object _stateSentinel = Object();
