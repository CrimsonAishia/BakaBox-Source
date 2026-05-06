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
  /// 玩家上线（同地图或跨地图）
  online,
  /// 玩家下线（同地图或跨地图）
  offline,
  /// 玩家传送到其他地图（同地图传送离开）
  teleport,
  /// 玩家从其他地图传送进来（同地图传送到达）
  teleportIn,
}

/// 玩家通知数据模型
class PlayerNotification {
  /// 通知唯一ID
  final String id;
  /// 通知类型
  final PlayerNotificationType type;
  /// 玩家显示名称
  final String playerName;
  /// 目标地图名称（teleport 类型使用）
  final String? targetMapName;
  /// 来源地图名称（teleportIn 类型使用）
  final String? sourceMapName;
  /// 通知创建时间
  final DateTime createdAt;

  const PlayerNotification({
    required this.id,
    required this.type,
    required this.playerName,
    this.targetMapName,
    this.sourceMapName,
    required this.createdAt,
  });

  /// 生成描述文字
  String get message {
    switch (type) {
      case PlayerNotificationType.online:
        return '$playerName 上线了';
      case PlayerNotificationType.offline:
        return '$playerName 下线了';
      case PlayerNotificationType.teleport:
        return '$playerName 传送到了 ${targetMapName ?? "未知地图"}';
      case PlayerNotificationType.teleportIn:
        return '$playerName 从 ${sourceMapName ?? "其他地图"} 传送过来了';
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
  final bool isPlayersPanelOpen;
  final bool isSettingsPanelOpen;
  final double chatOpacity;
  final bool showNameplates;
  final bool showChatBubbles;
  final bool useSteamName;
  final String? transientNotice;
  /// 每次设置 transientNotice 时递增，确保相同内容也能触发 listener
  final int transientNoticeSeq;
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
  /// 设置选项的 pending 状态（用于服务器确认/拒绝）
  final Map<String, bool> pendingSettings;
  /// pending 状态的超时时间（key: 设置项名, value: 超时截止时间）
  final Map<String, DateTime> pendingSettingsTimeouts;
  /// 玩家加入/离开通知列表
  final List<PlayerNotification> playerNotifications;
  /// 被踢出原因（null 表示未被踢出）
  /// 取值：duplicate_login / device_conflict / admin_kick
  final String? kickedReason;
  /// 被踢出时服务端附带的消息（admin_kick 时有管理员填写的原因）
  final String? kickedMessage;

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
    required this.isPlayersPanelOpen,
    required this.isSettingsPanelOpen,
    required this.chatOpacity,
    required this.showNameplates,
    required this.showChatBubbles,
    required this.useSteamName,
    required this.transientNotice,
    this.transientNoticeSeq = 0,
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
    this.pendingSettings = const {},
    this.pendingSettingsTimeouts = const {},
    this.anonymousSwitchCooldownSeconds = 0,
    this.steamNameSwitchCooldownSeconds = 0,
    this.playerNotifications = const [],
    this.kickedReason,
    this.kickedMessage,
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
      isPlayersPanelOpen: false,
      isSettingsPanelOpen: false,
      chatOpacity: 0.32,
      showNameplates: true,
      showChatBubbles: true,
      useSteamName: false,
      transientNotice: null,
      transientNoticeSeq: 0,
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
      pendingSettings: {},
      pendingSettingsTimeouts: {},
      anonymousSwitchCooldownSeconds: 0,
      steamNameSwitchCooldownSeconds: 0,
      playerNotifications: [],
      kickedReason: null,
      kickedMessage: null,
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
    bool? isPlayersPanelOpen,
    bool? isSettingsPanelOpen,
    double? chatOpacity,
    bool? showNameplates,
    bool? showChatBubbles,
    bool? useSteamName,
    Object? transientNotice = _stateSentinel,
    bool clearTransientNotice = false,    Object? teleportTarget = _stateSentinel,
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
    Object? pendingSettings = _stateSentinel,
    Object? pendingSettingsTimeouts = _stateSentinel,
    int? anonymousSwitchCooldownSeconds,
    int? steamNameSwitchCooldownSeconds,
    Object? playerNotifications = _stateSentinel,
    Object? kickedReason = _stateSentinel,
    bool clearKicked = false,
    Object? kickedMessage = _stateSentinel,
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
      transientNoticeSeq: clearTransientNotice
          ? transientNoticeSeq
          : identical(transientNotice, _stateSentinel)
          ? transientNoticeSeq
          : transientNoticeSeq + 1,
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
          : Map<String, String>.from(pendingMessages as Map),
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
      kickedReason: clearKicked
          ? null
          : identical(kickedReason, _stateSentinel)
          ? this.kickedReason
          : kickedReason as String?,
      kickedMessage: clearKicked
          ? null
          : identical(kickedMessage, _stateSentinel)
          ? this.kickedMessage
          : kickedMessage as String?,
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
    isPlayersPanelOpen,
    isSettingsPanelOpen,
    chatOpacity,
    showNameplates,
    showChatBubbles,
    useSteamName,
    transientNotice,
    transientNoticeSeq,
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
    pendingSettings,
    pendingSettingsTimeouts,
    anonymousSwitchCooldownSeconds,
    steamNameSwitchCooldownSeconds,
    playerNotifications,
    kickedReason,
    kickedMessage,
  ];
}

const Object _stateSentinel = Object();
