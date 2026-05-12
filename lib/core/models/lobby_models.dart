import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../services/lobby_asset_cache_service.dart';
import 'proto/lobby.pb.dart' as pb;

/// 大厅角色朝向
enum LobbyFacing { down, up, left, right }

/// 大厅角色配置（LobbySprite）
/// 角色外观由后端统一管理，通过 snapshot 中的 availableSprites 字段下发。
/// spriteUrl / previewUrl 均为后端签名的 CDN URL，带有鉴权参数。
/// 缓存时需去掉地址后面的鉴权参数，只保留路径部分作为稳定 key。
///
/// 支持两种角色渲染模式：
/// 1. 单张图片模式：使用 spriteUrl 加载单张网络图片
/// 2. 图集模式：使用 atlasUrl 加载 TexturePacker 图集，atlasImagePath 指定帧名
class LobbySprite extends Equatable {
  final String id;
  final String label;
  final Color accentColor;
  final String? spriteUrl;
  final String? previewUrl;
  final bool isDefault;
  
  // TexturePacker 图集支持（可选）
  final String? atlasUrl;        // 图集 URL（.atlas 文件路径）
  final String? atlasImagePath;  // 图集图片路径（与 atlasUrl 配合使用）
  final String? animationFrames;  // 动画帧序列（如 "frame_01,frame_02,frame_03"）
  final double? frameDuration;    // 帧间隔（秒），默认 0.1

  const LobbySprite({
    required this.id,
    required this.label,
    required this.accentColor,
    this.spriteUrl,
    this.previewUrl,
    this.isDefault = false,
    this.atlasUrl,
    this.atlasImagePath,
    this.animationFrames,
    this.frameDuration,
  });

  /// 是否使用图集模式
  bool get usesAtlas => atlasUrl != null && atlasUrl!.isNotEmpty;

  @override
  List<Object?> get props => [
    id,
    label,
    accentColor,
    spriteUrl,
    previewUrl,
    isDefault,
    atlasUrl,
    atlasImagePath,
    animationFrames,
    frameDuration,
  ];
}

/// 大厅位置模型
class LobbyPosition extends Equatable {
  final double x;
  final double y;

  const LobbyPosition({required this.x, required this.y});

  factory LobbyPosition.lerp(
    LobbyPosition from,
    LobbyPosition to,
    double t,
  ) {
    return LobbyPosition(
      x: from.x + (to.x - from.x) * t,
      y: from.y + (to.y - from.y) * t,
    );
  }

  LobbyPosition clamp({
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
  }) {
    return LobbyPosition(
      x: x.clamp(minX, maxX),
      y: y.clamp(minY, maxY),
    );
  }

  @override
  List<Object?> get props => [x, y];
}

/// 大厅用户模型（LobbyUser）
class LobbyUser extends Equatable {
  final String userId;
  final String? serverUserId;
  final String? businessUserId;
  final String nickname;
  final String spriteId;
  final String? avatarUrl;
  final LobbyPosition position;
  final LobbyPosition renderPosition;
  final LobbyPosition? targetPosition;
  final LobbyFacing facing;
  final bool isMoving;
  final bool isOnline;
  final bool isAnonymous;
  final bool isSelf;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? statusText;

  const LobbyUser({
    required this.userId,
    this.serverUserId,
    this.businessUserId,
    required this.nickname,
    required this.spriteId,
    this.avatarUrl,
    required this.position,
    LobbyPosition? renderPosition,
    this.targetPosition,
    this.facing = LobbyFacing.down,
    this.isMoving = false,
    this.isOnline = true,
    this.isAnonymous = false,
    this.isSelf = false,
    this.lastMessage,
    this.lastMessageAt,
    this.statusText,
  }) : renderPosition = renderPosition ?? position;

  String get displayName => nickname;

  bool get hasVisibleMessage {
    if (lastMessage == null || lastMessageAt == null) return false;
    return DateTime.now().difference(lastMessageAt!) <=
        const Duration(seconds: 8);
  }

  LobbyUser copyWith({
    String? userId,
    Object? serverUserId = _sentinel,
    Object? businessUserId = _sentinel,
    String? nickname,
    String? spriteId,
    Object? avatarUrl = _sentinel,
    LobbyPosition? position,
    LobbyPosition? renderPosition,
    Object? targetPosition = _sentinel,
    LobbyFacing? facing,
    bool? isMoving,
    bool? isOnline,
    bool? isAnonymous,
    bool? isSelf,
    Object? lastMessage = _sentinel,
    Object? lastMessageAt = _sentinel,
    Object? statusText = _sentinel,
  }) {
    return LobbyUser(
      userId: userId ?? this.userId,
      serverUserId: identical(serverUserId, _sentinel)
          ? this.serverUserId
          : serverUserId as String?,
      businessUserId: identical(businessUserId, _sentinel)
          ? this.businessUserId
          : businessUserId as String?,
      nickname: nickname ?? this.nickname,
      spriteId: spriteId ?? this.spriteId,
      avatarUrl: identical(avatarUrl, _sentinel)
          ? this.avatarUrl
          : avatarUrl as String?,
      position: position ?? this.position,
      renderPosition: renderPosition ?? this.renderPosition,
      targetPosition: identical(targetPosition, _sentinel)
          ? this.targetPosition
          : targetPosition as LobbyPosition?,
      facing: facing ?? this.facing,
      isMoving: isMoving ?? this.isMoving,
      isOnline: isOnline ?? this.isOnline,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isSelf: isSelf ?? this.isSelf,
      lastMessage: identical(lastMessage, _sentinel)
          ? this.lastMessage
          : lastMessage as String?,
      lastMessageAt: identical(lastMessageAt, _sentinel)
          ? this.lastMessageAt
          : lastMessageAt as DateTime?,
      statusText: identical(statusText, _sentinel)
          ? this.statusText
          : statusText as String?,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    serverUserId,
    businessUserId,
    nickname,
    spriteId,
    avatarUrl,
    position,
    renderPosition,
    targetPosition,
    facing,
    isMoving,
    isOnline,
    isAnonymous,
    isSelf,
    lastMessage,
    lastMessageAt,
    statusText,
  ];
}

/// 大厅消息类型
enum LobbyMessageType { user, system, broadcast }

/// 大厅消息模型（LobbyMessage）
class LobbyMessage extends Equatable {
  final String messageId;
  final String userId;
  final String nickname;
  final String content;
  final LobbyMessageType type;
  final bool isAnonymous;
  final DateTime timestamp;

  const LobbyMessage({
    required this.messageId,
    required this.userId,
    required this.nickname,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isAnonymous = false,
  });

  String get displayName {
    if (type == LobbyMessageType.system) return '系统';
    return nickname;
  }

  @override
  List<Object?> get props => [
    messageId,
    userId,
    nickname,
    content,
    type,
    isAnonymous,
    timestamp,
  ];
}

/// 大厅地图配置（LobbyMapConfig）
/// 地图背景资源由后端统一管理，客户端通过 backgroundUrl 下载并缓存。
class LobbyMapConfig extends Equatable {
  final String mapId;
  final String displayName;
  final String? backgroundUrl;
  final double width;
  final double height;
  final List<LobbyWalkableArea> walkableAreas;
  final List<LobbyPortal> portals;

  const LobbyMapConfig({
    required this.mapId,
    required this.displayName,
    this.backgroundUrl,
    required this.width,
    required this.height,
    required this.walkableAreas,
    this.portals = const [],
  });

  /// 检查坐标是否在传送点区域内，返回对应的传送点（如果有）
  LobbyPortal? getPortalAt(LobbyPosition position) {
    for (final portal in portals) {
      if (portal.contains(position)) {
        return portal;
      }
    }
    return null;
  }

  /// 检查坐标是否在任意传送点内
  bool isInPortal(LobbyPosition position) {
    return getPortalAt(position) != null;
  }

  bool contains(LobbyPosition position) {
    return walkableAreas.any((area) => area.contains(position));
  }

  @override
  List<Object?> get props => [
    mapId,
    displayName,
    backgroundUrl,
    width,
    height,
    walkableAreas,
    portals,
  ];
}

/// 可行走区域
class LobbyWalkableArea extends Equatable {
  final double left;
  final double top;
  final double width;
  final double height;

  const LobbyWalkableArea({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// 右边界（兼容协议格式）
  double get right => left + width;

  /// 下边界（兼容协议格式）
  double get bottom => top + height;

  /// 从协议格式创建（使用 left/top/right/bottom）
  factory LobbyWalkableArea.fromRect({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    return LobbyWalkableArea(
      left: left,
      top: top,
      width: right - left,
      height: bottom - top,
    );
  }

  bool contains(LobbyPosition position) {
    return position.x >= left &&
        position.x <= left + width &&
        position.y >= top &&
        position.y <= top + height;
  }

  @override
  List<Object?> get props => [left, top, width, height];
}


/// 传送门固定半径（前端统一使用此大小检测碰撞）
/// 协议说明：传送门大小由前端固定（统一尺寸），服务端只传位置坐标
const double kLobbyPortalRadius = 30.0;

/// 传送点配置
class LobbyPortal extends Equatable {
  final String key;
  final String label;
  final double x;
  final double y;
  final String targetMapId;
  final double targetX;
  final double targetY;

  const LobbyPortal({
    required this.key,
    required this.label,
    required this.x,
    required this.y,
    required this.targetMapId,
    required this.targetX,
    required this.targetY,
  });

  /// 传送门位置
  LobbyPosition get position => LobbyPosition(x: x, y: y);

  /// 目标位置
  LobbyPosition get targetPosition => LobbyPosition(x: targetX, y: targetY);

  /// 目标位置是否已设定（0 表示服务端将自动计算出生点）
  bool get hasTargetPosition => targetX != 0 || targetY != 0;

  /// 检查坐标是否在传送门碰撞范围内（使用固定半径）
  bool contains(LobbyPosition position) {
    final dx = position.x - x;
    final dy = position.y - y;
    return (dx * dx + dy * dy) <= kLobbyPortalRadius * kLobbyPortalRadius;
  }

  @override
  List<Object?> get props => [key, label, x, y, targetMapId, targetX, targetY];
}

/// 传送目标信息
class LobbyTeleportTarget extends Equatable {
  final String portalKey;
  final String label;
  final String sourceMapId;
  final String targetMapId;
  final double targetX;
  final double targetY;

  const LobbyTeleportTarget({
    required this.portalKey,
    required this.label,
    required this.sourceMapId,
    required this.targetMapId,
    required this.targetX,
    required this.targetY,
  });

  LobbyPosition get position => LobbyPosition(x: targetX, y: targetY);

  @override
  List<Object?> get props => [portalKey, label, sourceMapId, targetMapId, targetX, targetY];
}

/// 大厅 WebSocket 事件基类（sealed class）
///
/// 拆分为两种事件：
/// - [LobbyServerEvent]：服务端 protobuf 消息
/// - [LobbyConnectionEvent]：客户端连接状态事件
sealed class LobbyWsEvent extends Equatable {
  const LobbyWsEvent();
}

/// 服务端 protobuf 消息事件
///
/// 携带完整的 protobuf 信封，Bloc 层直接访问强类型字段。
class LobbyServerEvent extends LobbyWsEvent {
  final String type;
  final DateTime timestamp;
  final String traceId;
  final pb.LobbyEnvelope envelope;

  /// 排队相关字段（仅 type='queue.started' 或 'queue.status' 时有效）
  final String? queueTicket;
  final int? queuePosition;
  final int? queueTotal;
  final int? queueEtaSeconds;
  final int? queuePollIntervalMs;

  const LobbyServerEvent({
    required this.type,
    required this.timestamp,
    required this.traceId,
    required this.envelope,
    this.queueTicket,
    this.queuePosition,
    this.queueTotal,
    this.queueEtaSeconds,
    this.queuePollIntervalMs,
  });

  @override
  List<Object?> get props => [type, timestamp, traceId];
}

/// 连接状态枚举
enum LobbyConnectionEventType { connected, closed, error }

/// 客户端连接状态事件
class LobbyConnectionEvent extends LobbyWsEvent {
  final LobbyConnectionEventType status;
  final String? error;

  const LobbyConnectionEvent({
    required this.status,
    this.error,
  });

  @override
  List<Object?> get props => [status, error];
}

/// 传送门拒绝原因
enum LobbyPortalRejectReason {
  invalidPayload,
  portalNotFound,
  unknown,
}

extension LobbyPortalRejectReasonExt on LobbyPortalRejectReason {
  static LobbyPortalRejectReason fromString(String? reason) {
    switch (reason) {
      case 'invalid_payload':
        return LobbyPortalRejectReason.invalidPayload;
      case 'portal_not_found':
        return LobbyPortalRejectReason.portalNotFound;
      default:
        return LobbyPortalRejectReason.unknown;
    }
  }

  String get displayText {
    switch (this) {
      case LobbyPortalRejectReason.invalidPayload:
        return '请求参数无效';
      case LobbyPortalRejectReason.portalNotFound:
        return '传送门不存在';
      case LobbyPortalRejectReason.unknown:
        return '传送失败';
    }
  }
}

/// 传送门拒绝事件模型
class LobbyPortalReject extends Equatable {
  final String reason;
  final LobbyPortalRejectReason reasonType;

  const LobbyPortalReject({
    required this.reason,
    required this.reasonType,
  });

  factory LobbyPortalReject.fromPayload(Map<String, dynamic> payload) {
    final reason = payload['reason']?.toString() ?? 'unknown';
    return LobbyPortalReject(
      reason: reason,
      reasonType: LobbyPortalRejectReasonExt.fromString(reason),
    );
  }

  factory LobbyPortalReject.fromProtobuf(pb.PortalUseRejectResponse pbReject) {
    final reason = pbReject.reason.isNotEmpty ? pbReject.reason : 'unknown';
    return LobbyPortalReject(
      reason: reason,
      reasonType: LobbyPortalRejectReasonExt.fromString(reason),
    );
  }

  @override
  List<Object?> get props => [reason, reasonType];
}

const Object _sentinel = Object();

/// 大厅快照分页信息
/// 当用户数超过 pageSize 时，服务端返回分页信息
class LobbyPageInfo extends Equatable {
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final int totalUsers;

  const LobbyPageInfo({
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.totalUsers,
  });

  /// 是否还有更多页面
  bool get hasMore => totalPages > 0 && currentPage < totalPages - 1;

  /// 是否需要分页（总用户数超过一页大小）
  bool get needsPagination => totalUsers > pageSize;

  @override
  List<Object?> get props => [currentPage, totalPages, pageSize, totalUsers];
}

/// 大厅素材数据（由 join.success 后立即请求的 assets 消息填充）
/// 在渲染大厅界面之前必须完成此数据的加载。
class LobbyAssets extends Equatable {
  /// 当前地图配置（从 maps 数组中根据当前 mapId 确定）
  final LobbyMapConfig? mapConfig;
  /// 所有可用地图配置数组
  final List<LobbyMapConfig> maps;
  final List<LobbySprite> sprites;

  const LobbyAssets({
    this.mapConfig,
    this.maps = const [],
    this.sprites = const [],
  });

  bool get isReady => (mapConfig != null || maps.isNotEmpty) && sprites.isNotEmpty;

  /// 根据 mapId 获取地图配置
  ///
  /// 返回的地图配置使用稳定的 backgroundUrl（从缓存获取，去掉鉴权参数）
  /// 确保后续查询缓存时 URL 能正确匹配
  LobbyMapConfig? getMapById(String mapId) {
    final map = maps.cast<LobbyMapConfig?>().firstWhere(
      (m) => m?.mapId == mapId,
      orElse: () => null,
    );
    if (map == null) return null;

    // 使用 LobbyAssetCacheService 获取稳定的 URL（直接取缓存，不做比较）
    final stableBackgroundUrl = LobbyAssetCacheService.instance.getBackgroundUrlByMapId(mapId);

    // 如果缓存中没有稳定的 URL，使用原始 URL
    if (stableBackgroundUrl == null || stableBackgroundUrl.isEmpty) {
      return map;
    }

    // 返回使用稳定 URL 的地图配置
    return LobbyMapConfig(
      mapId: map.mapId,
      displayName: map.displayName,
      backgroundUrl: stableBackgroundUrl,
      width: map.width,
      height: map.height,
      walkableAreas: map.walkableAreas,
      portals: map.portals,
    );
  }

  @override
  List<Object?> get props => [mapConfig, maps, sprites];
}

/// 全服广播消息模型
class LobbyBroadcastMessage extends Equatable {
  final String messageId;
  final String userId;
  final String nickname;
  final String content;
  final DateTime timestamp;
  final String? avatarUrl;

  const LobbyBroadcastMessage({
    required this.messageId,
    required this.userId,
    required this.nickname,
    required this.content,
    required this.timestamp,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [messageId, userId, nickname, content, timestamp, avatarUrl];
}
