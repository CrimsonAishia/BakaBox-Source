import 'package:json_annotation/json_annotation.dart';

part 'update_log_models.g.dart';

@JsonSerializable()
class Pagination {
  final int pageIndex;
  final int pageSize;
  final String orderBy;

  Pagination({required this.pageIndex, required this.pageSize, required this.orderBy});

  factory Pagination.fromJson(Map<String, dynamic> json) => _$PaginationFromJson(json);
  Map<String, dynamic> toJson() => _$PaginationToJson(this);
}

@JsonSerializable()
class SteamWorkChangeLogRequest {
  final Pagination pagination;
  final String content;
  final String id;

  SteamWorkChangeLogRequest({required this.pagination, required this.content, required this.id});

  factory SteamWorkChangeLogRequest.fromJson(Map<String, dynamic> json) => _$SteamWorkChangeLogRequestFromJson(json);
  Map<String, dynamic> toJson() => _$SteamWorkChangeLogRequestToJson(this);
}

@JsonSerializable()
class SteamWorkChangeLog {
  final String updateTime;
  final String content;
  final String rawHtml;
  final String createdAt;
  final int workshopItemId;

  SteamWorkChangeLog({
    required this.updateTime, required this.content, required this.rawHtml,
    required this.createdAt, required this.workshopItemId,
  });

  factory SteamWorkChangeLog.fromJson(Map<String, dynamic> json) => _$SteamWorkChangeLogFromJson(json);
  Map<String, dynamic> toJson() => _$SteamWorkChangeLogToJson(this);
}

@JsonSerializable()
class SteamWorkChangeLogResponse {
  final int total;
  final List<SteamWorkChangeLog> items;

  SteamWorkChangeLogResponse({required this.total, required this.items});

  factory SteamWorkChangeLogResponse.fromJson(Map<String, dynamic> json) => _$SteamWorkChangeLogResponseFromJson(json);
  Map<String, dynamic> toJson() => _$SteamWorkChangeLogResponseToJson(this);
}
