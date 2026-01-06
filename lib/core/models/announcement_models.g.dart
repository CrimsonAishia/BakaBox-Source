// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnnouncementItem _$AnnouncementItemFromJson(Map<String, dynamic> json) =>
    AnnouncementItem(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      content: json['content'] as String,
      type: json['type'] as String,
      priority: (json['priority'] as num).toInt(),
      isActive: json['isActive'] as bool,
      isSticky: json['isSticky'] as bool,
      startTime: (json['startTime'] as num?)?.toInt(),
      endTime: (json['endTime'] as num?)?.toInt(),
      readCount: (json['readCount'] as num).toInt(),
      createdAt: (json['createdAt'] as num).toInt(),
      updatedAt: (json['updatedAt'] as num).toInt(),
    );

Map<String, dynamic> _$AnnouncementItemToJson(AnnouncementItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'content': instance.content,
      'type': instance.type,
      'priority': instance.priority,
      'isActive': instance.isActive,
      'isSticky': instance.isSticky,
      'startTime': instance.startTime,
      'endTime': instance.endTime,
      'readCount': instance.readCount,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };

AnnouncementListResponse _$AnnouncementListResponseFromJson(
  Map<String, dynamic> json,
) => AnnouncementListResponse(
  total: (json['total'] as num).toInt(),
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => AnnouncementItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$AnnouncementListResponseToJson(
  AnnouncementListResponse instance,
) => <String, dynamic>{'total': instance.total, 'items': instance.items};
