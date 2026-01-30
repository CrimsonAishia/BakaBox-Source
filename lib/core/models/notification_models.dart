import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'notification_models.g.dart';

/// 通知类型
class NotificationType {
  static const String all = 'all';
  static const String mapContributionAudit = 'map_contribution_audit';
  static const String keyConfigAudit = 'key_config_audit';
  static const String issueComment = 'issue_comment';

  /// 获取类型显示名称
  static String getDisplayName(String type) {
    switch (type) {
      case mapContributionAudit:
        return '地图审核';
      case keyConfigAudit:
        return '快捷键审核';
      case issueComment:
        return 'Issue评论';
      default:
        return '全部';
    }
  }
}

/// 通知项
@JsonSerializable()
class NotificationItem extends Equatable {
  @JsonKey(defaultValue: 0)
  final int id;
  @JsonKey(defaultValue: 0)
  final int userId;
  @JsonKey(defaultValue: '')
  final String type;
  @JsonKey(defaultValue: '')
  final String title;
  @JsonKey(defaultValue: '')
  final String content;
  final Map<String, dynamic>? data;
  @JsonKey(defaultValue: false)
  final bool isRead;
  final String? readAt;
  @JsonKey(defaultValue: '')
  final String createdAt;

  const NotificationItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.content,
    this.data,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      _$NotificationItemFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationItemToJson(this);

  NotificationItem copyWith({
    int? id,
    int? userId,
    String? type,
    String? title,
    String? content,
    Map<String, dynamic>? data,
    bool? isRead,
    String? readAt,
    String? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, type, title, content, data, isRead, readAt, createdAt];
}

/// 通知列表响应
@JsonSerializable()
class NotificationListResponse extends Equatable {
  @JsonKey(defaultValue: [])
  final List<NotificationItem> items;
  @JsonKey(defaultValue: 0)
  final int total;
  @JsonKey(defaultValue: 1)
  final int page;
  @JsonKey(defaultValue: 20)
  final int pageSize;
  @JsonKey(defaultValue: 0)
  final int totalPages;

  const NotificationListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) =>
      _$NotificationListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationListResponseToJson(this);

  @override
  List<Object?> get props => [items, total, page, pageSize, totalPages];
}

/// 未读数量响应
@JsonSerializable()
class UnreadCountResponse extends Equatable {
  final int count;

  const UnreadCountResponse({required this.count});

  factory UnreadCountResponse.fromJson(Map<String, dynamic> json) =>
      _$UnreadCountResponseFromJson(json);

  Map<String, dynamic> toJson() => _$UnreadCountResponseToJson(this);

  @override
  List<Object?> get props => [count];
}
