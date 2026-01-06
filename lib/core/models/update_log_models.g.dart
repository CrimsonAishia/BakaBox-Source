// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_log_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Pagination _$PaginationFromJson(Map<String, dynamic> json) => Pagination(
  pageIndex: (json['pageIndex'] as num).toInt(),
  pageSize: (json['pageSize'] as num).toInt(),
  orderBy: json['orderBy'] as String,
);

Map<String, dynamic> _$PaginationToJson(Pagination instance) =>
    <String, dynamic>{
      'pageIndex': instance.pageIndex,
      'pageSize': instance.pageSize,
      'orderBy': instance.orderBy,
    };

SteamWorkChangeLogRequest _$SteamWorkChangeLogRequestFromJson(
  Map<String, dynamic> json,
) => SteamWorkChangeLogRequest(
  pagination: Pagination.fromJson(json['pagination'] as Map<String, dynamic>),
  content: json['content'] as String,
  id: json['id'] as String,
);

Map<String, dynamic> _$SteamWorkChangeLogRequestToJson(
  SteamWorkChangeLogRequest instance,
) => <String, dynamic>{
  'pagination': instance.pagination,
  'content': instance.content,
  'id': instance.id,
};

SteamWorkChangeLog _$SteamWorkChangeLogFromJson(Map<String, dynamic> json) =>
    SteamWorkChangeLog(
      updateTime: json['updateTime'] as String,
      content: json['content'] as String,
      rawHtml: json['rawHtml'] as String,
      createdAt: json['createdAt'] as String,
      workshopItemId: (json['workshopItemId'] as num).toInt(),
    );

Map<String, dynamic> _$SteamWorkChangeLogToJson(SteamWorkChangeLog instance) =>
    <String, dynamic>{
      'updateTime': instance.updateTime,
      'content': instance.content,
      'rawHtml': instance.rawHtml,
      'createdAt': instance.createdAt,
      'workshopItemId': instance.workshopItemId,
    };

SteamWorkChangeLogResponse _$SteamWorkChangeLogResponseFromJson(
  Map<String, dynamic> json,
) => SteamWorkChangeLogResponse(
  total: (json['total'] as num).toInt(),
  items: (json['items'] as List<dynamic>)
      .map((e) => SteamWorkChangeLog.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SteamWorkChangeLogResponseToJson(
  SteamWorkChangeLogResponse instance,
) => <String, dynamic>{'total': instance.total, 'items': instance.items};
