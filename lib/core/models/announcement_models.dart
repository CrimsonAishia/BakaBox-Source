import 'package:json_annotation/json_annotation.dart';

part 'announcement_models.g.dart';

/// 公告项目模型
@JsonSerializable()
class AnnouncementItem {
  final int id;
  final String title;
  final String content;
  final String type; // info, success, warning, error, maintenance
  final int priority; // 优先级，数值越大越高
  final bool isActive;
  final bool isSticky; // 是否置顶
  final int? startTime; // 开始时间戳（秒）
  final int? endTime; // 结束时间戳（秒）
  final int readCount;
  final int createdAt; // 创建时间戳（秒）
  final int updatedAt; // 更新时间戳（秒）

  AnnouncementItem({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.priority,
    required this.isActive,
    required this.isSticky,
    this.startTime,
    this.endTime,
    required this.readCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AnnouncementItem.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementItemFromJson(json);
  Map<String, dynamic> toJson() => _$AnnouncementItemToJson(this);

  AnnouncementItem copyWith({
    int? id,
    String? title,
    String? content,
    String? type,
    int? priority,
    bool? isActive,
    bool? isSticky,
    int? startTime,
    int? endTime,
    int? readCount,
    int? createdAt,
    int? updatedAt,
  }) {
    return AnnouncementItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      isSticky: isSticky ?? this.isSticky,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      readCount: readCount ?? this.readCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnouncementItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          content == other.content &&
          type == other.type &&
          priority == other.priority &&
          isActive == other.isActive &&
          isSticky == other.isSticky &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          readCount == other.readCount &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      content.hashCode ^
      type.hashCode ^
      priority.hashCode ^
      isActive.hashCode ^
      isSticky.hashCode ^
      startTime.hashCode ^
      endTime.hashCode ^
      readCount.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}

/// 公告列表响应
@JsonSerializable()
class AnnouncementListResponse {
  final int total;

  @JsonKey(defaultValue: [])
  final List<AnnouncementItem> items;

  AnnouncementListResponse({required this.total, required this.items});

  factory AnnouncementListResponse.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AnnouncementListResponseToJson(this);
}
