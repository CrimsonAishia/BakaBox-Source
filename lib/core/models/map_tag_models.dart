import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import '../utils/server_time_converter.dart';
import 'map_contribution_models.dart';

part 'map_tag_models.g.dart';

/// 审核状态
enum AuditStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('approved')
  approved,
  @JsonValue('rejected')
  rejected,
}

/// 标签
@JsonSerializable()
class MapTag extends Equatable {
  final int id;
  final String name;

  /// 标签颜色，十六进制格式如 #FF5733
  final String? color;

  /// 贡献者信息
  final ContributorInfo? contributor;
  @ServerTimeConverter()
  final DateTime createdAt;
  @ServerTimeConverter()
  final DateTime updatedAt;

  /// 审核状态
  /// 外部获取的全局标签（getTagList）此字段为 null
  final AuditStatus? auditStatus;

  /// 审核备注（拒绝原因）
  final String? auditRemark;

  /// 是否置顶
  final bool? isPinned;

  const MapTag({
    required this.id,
    required this.name,
    this.color,
    this.contributor,
    required this.createdAt,
    required this.updatedAt,
    this.auditStatus,
    this.auditRemark,
    this.isPinned,
  });

  /// 将十六进制颜色字符串转换为 Color
  /// 如果 color 为 null 或格式无效，返回 null
  Color? get colorValue {
    if (color == null || color!.isEmpty) return null;
    try {
      final hex = color!.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return null;
  }

  /// 是否为审核中状态
  bool get isPending => auditStatus == AuditStatus.pending;

  /// 是否为已拒绝状态
  bool get isRejected => auditStatus == AuditStatus.rejected;

  /// 是否为已通过状态
  bool get isApproved => auditStatus == AuditStatus.approved;

  /// 是否是用户自己的标签
  bool get isUserTag => auditStatus != null;

  factory MapTag.fromJson(Map<String, dynamic> json) => _$MapTagFromJson(json);
  Map<String, dynamic> toJson() => _$MapTagToJson(this);

  @override
  List<Object?> get props => [
    id,
    name,
    color,
    contributor,
    createdAt,
    updatedAt,
    auditStatus,
    isPinned,
  ];
}

/// 标签变更申请
@JsonSerializable()
class MapTagChangeRequest extends Equatable {
  final int id;
  final int tagId;
  final String changeType; // 'edit' or 'delete'
  final AuditStatus auditStatus;
  
  const MapTagChangeRequest({
    required this.id,
    required this.tagId,
    required this.changeType,
    required this.auditStatus,
  });

  factory MapTagChangeRequest.fromJson(Map<String, dynamic> json) =>
      _$MapTagChangeRequestFromJson(json);
  Map<String, dynamic> toJson() => _$MapTagChangeRequestToJson(this);

  @override
  List<Object?> get props => [id, tagId, changeType, auditStatus];
}

/// 地图标签投票记录（GET /api/stub 接口专用）
/// 与投票响应中的 MapTagVote 不同，该接口不返回 createdAt、updatedAt、hasVoted
@JsonSerializable()
class MapTagVoteSimple extends Equatable {
  final int id;
  final String mapName;
  final int tagId;
  final String tagName;
  final int voteCount;

  /// 赞成票数
  final int upCount;

  /// 反对票数
  final int downCount;

  /// 当前用户是否投了赞成票
  final bool? hasUpvoted;

  /// 当前用户是否投了反对票
  final bool? hasDownvoted;

  const MapTagVoteSimple({
    required this.id,
    required this.mapName,
    required this.tagId,
    required this.tagName,
    required this.voteCount,
    required this.upCount,
    required this.downCount,
    this.hasUpvoted,
    this.hasDownvoted,
  });

  /// 当前用户是否投过票
  bool get hasVoted => hasUpvoted == true || hasDownvoted == true;

  factory MapTagVoteSimple.fromJson(Map<String, dynamic> json) =>
      _$MapTagVoteSimpleFromJson(json);
  Map<String, dynamic> toJson() => _$MapTagVoteSimpleToJson(this);

  MapTagVoteSimple copyWith({
    int? id,
    String? mapName,
    int? tagId,
    String? tagName,
    int? voteCount,
    int? upCount,
    int? downCount,
    bool? hasUpvoted,
    bool? hasDownvoted,
  }) {
    return MapTagVoteSimple(
      id: id ?? this.id,
      mapName: mapName ?? this.mapName,
      tagId: tagId ?? this.tagId,
      tagName: tagName ?? this.tagName,
      voteCount: voteCount ?? this.voteCount,
      upCount: upCount ?? this.upCount,
      downCount: downCount ?? this.downCount,
      hasUpvoted: hasUpvoted ?? this.hasUpvoted,
      hasDownvoted: hasDownvoted ?? this.hasDownvoted,
    );
  }

  @override
  List<Object?> get props => [
    id,
    mapName,
    tagId,
    tagName,
    voteCount,
    upCount,
    downCount,
    hasUpvoted,
    hasDownvoted,
  ];
}

/// 地图标签投票列表响应（GET /api/stub 接口专用）
@JsonSerializable()
class MapTagListSimpleResponse extends Equatable {
  final String mapName;
  final List<MapTagVoteSimple> items;

  const MapTagListSimpleResponse({required this.mapName, required this.items});

  factory MapTagListSimpleResponse.fromJson(Map<String, dynamic> json) =>
      _$MapTagListSimpleResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MapTagListSimpleResponseToJson(this);

  @override
  List<Object?> get props => [mapName, items];
}

/// 标签投票响应
@JsonSerializable()
class TagVoteResponse extends Equatable {
  final bool success;
  final bool hasVoted;
  final MapTagVoteSimple mapTagVote;

  const TagVoteResponse({
    required this.success,
    required this.hasVoted,
    required this.mapTagVote,
  });

  factory TagVoteResponse.fromJson(Map<String, dynamic> json) =>
      _$TagVoteResponseFromJson(json);
  Map<String, dynamic> toJson() => _$TagVoteResponseToJson(this);

  @override
  List<Object?> get props => [success, hasVoted, mapTagVote];
}

/// 标签模型（用于地图信息中的标签列表）
@JsonSerializable()
class MapTagSimple extends Equatable {
  final String name;

  /// 标签颜色，十六进制格式如 #FF5733
  final String? color;

  const MapTagSimple({required this.name, this.color});

  /// 将十六进制颜色字符串转换为 Color
  Color? get colorValue {
    if (color == null || color!.isEmpty) return null;
    try {
      final hex = color!.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return null;
  }

  factory MapTagSimple.fromJson(Map<String, dynamic> json) =>
      _$MapTagSimpleFromJson(json);
  Map<String, dynamic> toJson() => _$MapTagSimpleToJson(this);

  @override
  List<Object?> get props => [name, color];
}
