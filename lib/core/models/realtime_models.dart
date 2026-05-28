/// Zedbox 实时推送 WS 协议模型
///
/// 对应文档：docs/zedbox-realtime-ws.md
///
/// 频道列表：
/// - `server.map.runtime` 服务器换图推送（订阅时下发 snapshot）
/// - `map.info` 地图信息变更推送
/// - `score.updates` GSI 共识比分变化推送（订阅时下发 snapshot）
/// - `notifications` 个人消息推送（仅登录态）
/// - `announcements` 公告/更新日志推送
library;

/// 频道名称常量
class RealtimeChannels {
  RealtimeChannels._();

  static const String serverMapRuntime = 'server.map.runtime';
  static const String mapInfo = 'map.info';
  static const String scoreUpdates = 'score.updates';
  static const String notifications = 'notifications';
  static const String announcements = 'announcements';

  /// 所有支持的频道
  static const List<String> all = [
    serverMapRuntime,
    mapInfo,
    scoreUpdates,
    notifications,
    announcements,
  ];

  /// 需要登录的用户级频道
  static const Set<String> userScoped = {notifications};
}

/// 服务端动作（action 字段）
class RealtimeServerActions {
  RealtimeServerActions._();

  static const String welcome = 'welcome';
  static const String authAck = 'auth_ack';
  static const String subAck = 'sub_ack';
  static const String unsubAck = 'unsub_ack';
  static const String event = 'event';
  static const String pong = 'pong';
  static const String error = 'error';
  static const String forceLogout = 'force_logout';
}

/// 客户端动作
class RealtimeClientActions {
  RealtimeClientActions._();

  static const String subscribe = 'subscribe';
  static const String unsubscribe = 'unsubscribe';
  static const String auth = 'auth';
  static const String ping = 'ping';
}

/// 服务端错误码
class RealtimeErrorCodes {
  RealtimeErrorCodes._();

  static const String authRequired = 'auth_required';
  static const String invalidChannel = 'invalid_channel';
  static const String tooManyConnections = 'too_many_connections';
  static const String unknownAction = 'unknown_action';
  static const String internalError = 'internal_error';
  static const String invalidToken = 'invalid_token';
  static const String tokenRevoked = 'token_revoked';
  static const String tokenExpired = 'token_expired';
  static const String userDisabled = 'user_disabled';
}

/// 频道事件类型
class RealtimeEventTypes {
  RealtimeEventTypes._();

  static const String snapshot = 'snapshot';
  static const String changed = 'changed';
  static const String updated = 'updated';
  // notifications
  static const String created = 'new';
  // announcements
  static const String announcementCreated = 'created';
  static const String announcementUpdated = 'updated';
  static const String announcementStatusChanged = 'status_changed';
  static const String announcementStickyChanged = 'sticky_changed';
  static const String announcementDeleted = 'deleted';
}

/// 服务端 → 客户端原始消息封装
class RealtimeIncomingMessage {
  /// 顶层 action 字段（welcome / sub_ack / event / error / pong …）
  final String action;

  /// event 消息使用的频道名
  final String? channel;

  /// event 子类型（snapshot / changed / updated / new / created …）
  final String? eventType;

  /// data 负载
  final Map<String, dynamic>? data;

  /// 错误码（仅 error 消息）
  final String? error;

  /// 请求 ID（仅 sub_ack / unsub_ack / auth_ack 等回执）
  final String? reqId;

  /// 服务端时间戳（毫秒）
  final int? timestamp;

  const RealtimeIncomingMessage({
    required this.action,
    this.channel,
    this.eventType,
    this.data,
    this.error,
    this.reqId,
    this.timestamp,
  });

  factory RealtimeIncomingMessage.fromJson(Map<String, dynamic> json) {
    return RealtimeIncomingMessage(
      action: (json['action'] as String?) ?? '',
      channel: json['channel'] as String?,
      eventType: json['eventType'] as String?,
      data: _asMap(json['data']),
      error: json['error'] as String?,
      reqId: json['reqId'] as String?,
      timestamp: (json['timestamp'] as num?)?.toInt(),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}

/// 频道事件（解构后的便捷封装）
class RealtimeChannelEvent {
  /// 频道名
  final String channel;

  /// 事件类型（snapshot / changed / updated / new / created …）
  final String eventType;

  /// 负载
  final Map<String, dynamic> data;

  /// 服务端时间戳（毫秒），可能为空
  final int? timestamp;

  const RealtimeChannelEvent({
    required this.channel,
    required this.eventType,
    required this.data,
    this.timestamp,
  });

  /// 是否为快照事件
  bool get isSnapshot => eventType == RealtimeEventTypes.snapshot;

  /// 解析 snapshot 事件中的 items 数组
  List<Map<String, dynamic>> get snapshotItems {
    final items = data['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }
}

/// 连接当前身份信息（来自 welcome / auth_ack）
class RealtimeIdentity {
  final bool isAnonymous;
  final int userId;
  final String visitorId;
  final List<String> supportChannels;

  const RealtimeIdentity({
    required this.isAnonymous,
    required this.userId,
    required this.visitorId,
    required this.supportChannels,
  });

  factory RealtimeIdentity.anonymous() => const RealtimeIdentity(
        isAnonymous: true,
        userId: 0,
        visitorId: '',
        supportChannels: [],
      );

  factory RealtimeIdentity.fromJson(Map<String, dynamic> json) {
    final list = json['supportChannels'];
    return RealtimeIdentity(
      isAnonymous: json['isAnonymous'] as bool? ?? true,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      visitorId: (json['visitorId'] as String?) ?? '',
      supportChannels: list is List
          ? list.whereType<String>().toList(growable: false)
          : const [],
    );
  }
}

/// 强制登出事件 payload
class RealtimeForceLogoutPayload {
  final int userId;
  final String reason;
  final String message;

  const RealtimeForceLogoutPayload({
    required this.userId,
    required this.reason,
    required this.message,
  });

  factory RealtimeForceLogoutPayload.fromJson(Map<String, dynamic> json) {
    return RealtimeForceLogoutPayload(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      reason: (json['reason'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
    );
  }
}

/// 连接状态
enum RealtimeConnectionState {
  /// 未连接，且未启动
  idle,

  /// 正在建立连接
  connecting,

  /// 已建立连接（收到 welcome 后）
  connected,

  /// 连接断开，等待重连
  reconnecting,

  /// 已主动停止
  disposed,
}
