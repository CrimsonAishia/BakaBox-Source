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

/// 地图标签投票记录（列表接口专用）
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

  /// 是否有票数（任何人投的赞成/反对票）
  bool get hasAnyVotes => voteCount != 0 || (upCount + downCount) > 0;

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

/// 地图标签投票列表响应（列表接口专用）
@JsonSerializable()
class MapTagListSimpleResponse extends Equatable {
  final String mapName;
  final List<MapTagVoteSimple> items;

  /// 投票门槛信息（游玩时长 / 是否可投票）
  /// 详见 `docs/playtime-voting.md`，旧后端不返回时为 null
  final MapTagVotingInfo? voting;

  const MapTagListSimpleResponse({
    required this.mapName,
    required this.items,
    this.voting,
  });

  factory MapTagListSimpleResponse.fromJson(Map<String, dynamic> json) =>
      _$MapTagListSimpleResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MapTagListSimpleResponseToJson(this);

  @override
  List<Object?> get props => [mapName, items, voting];
}

/// 标签投票门槛信息
///
/// 由后端按当前用户的游玩时长 + 风控状态综合判定，前端不要再用本地数据
/// 自行计算 `canVote`，应直接信任后端结果。
@JsonSerializable()
class MapTagVotingInfo extends Equatable {
  /// 投票所需累计有效秒数
  final int voteThresholdSeconds;

  /// 当前用户在本图的累计有效秒数（未登录为 0）
  ///
  /// 投票门槛只看「本图」时长，不再使用总时长。
  final int userMapValidSeconds;

  /// 服务端最终判断（综合登录 / 时长 / 封禁）
  final bool canVote;

  const MapTagVotingInfo({
    required this.voteThresholdSeconds,
    required this.userMapValidSeconds,
    required this.canVote,
  });

  /// 距离投票门槛还差多少秒（已达标返回 0）
  int get secondsUntilCanVote {
    if (canVote) return 0;
    final diff = voteThresholdSeconds - userMapValidSeconds;
    return diff > 0 ? diff : 0;
  }

  factory MapTagVotingInfo.fromJson(Map<String, dynamic> json) =>
      _$MapTagVotingInfoFromJson(json);
  Map<String, dynamic> toJson() => _$MapTagVotingInfoToJson(this);

  @override
  List<Object?> get props => [
    voteThresholdSeconds,
    userMapValidSeconds,
    canVote,
  ];
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

/// 标签用户投票记录（单条）
@JsonSerializable()
class TagUserVoteItem extends Equatable {
  final int id;
  final int userId;
  final String username;
  final String avatar;
  final String voteType;

  const TagUserVoteItem({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatar,
    required this.voteType,
  });

  bool get isUpvote => voteType == 'up';

  factory TagUserVoteItem.fromJson(Map<String, dynamic> json) =>
      _$TagUserVoteItemFromJson(json);
  Map<String, dynamic> toJson() => _$TagUserVoteItemToJson(this);

  @override
  List<Object?> get props => [id, userId, username, avatar, voteType];
}

/// 标签用户投票记录响应
@JsonSerializable()
class TagUserVotesResponse extends Equatable {
  final String mapName;
  final int tagId;
  final String tagName;
  final List<TagUserVoteItem> items;
  final int total;

  const TagUserVotesResponse({
    required this.mapName,
    required this.tagId,
    required this.tagName,
    required this.items,
    required this.total,
  });

  factory TagUserVotesResponse.fromJson(Map<String, dynamic> json) =>
      _$TagUserVotesResponseFromJson(json);
  Map<String, dynamic> toJson() => _$TagUserVotesResponseToJson(this);

  @override
  List<Object?> get props => [mapName, tagId, tagName, items, total];
}

/// 地图所有标签投票记录（单条）
@JsonSerializable()
class MapAllTagVoteItem extends Equatable {
  final int id;
  final int tagId;
  final String tagName;
  final String? tagColor;
  final int userId;
  final String username;
  final String avatar;
  final String voteType;

  const MapAllTagVoteItem({
    required this.id,
    required this.tagId,
    required this.tagName,
    this.tagColor,
    required this.userId,
    required this.username,
    required this.avatar,
    required this.voteType,
  });

  bool get isUpvote => voteType == 'up';

  /// 将十六进制颜色字符串转换为 Color
  Color? get tagColorValue {
    if (tagColor == null || tagColor!.isEmpty) return null;
    try {
      final hex = tagColor!.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return null;
  }

  factory MapAllTagVoteItem.fromJson(Map<String, dynamic> json) =>
      _$MapAllTagVoteItemFromJson(json);
  Map<String, dynamic> toJson() => _$MapAllTagVoteItemToJson(this);

  @override
  List<Object?> get props => [
    id,
    tagId,
    tagName,
    tagColor,
    userId,
    username,
    avatar,
    voteType,
  ];
}

/// 地图所有标签投票记录响应
@JsonSerializable()
class MapAllTagVotesResponse extends Equatable {
  final String mapName;
  final List<MapAllTagVoteItem> items;
  final int total;

  const MapAllTagVotesResponse({
    required this.mapName,
    required this.items,
    required this.total,
  });

  factory MapAllTagVotesResponse.fromJson(Map<String, dynamic> json) =>
      _$MapAllTagVotesResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MapAllTagVotesResponseToJson(this);

  @override
  List<Object?> get props => [mapName, items, total];
}

/// 标签模型（用于地图信息中的标签列表）
@JsonSerializable()
class MapTagSimple extends Equatable {
  final String name;

  /// 标签颜色，十六进制格式如 #FF5733
  final String? color;

  @JsonKey(name: 'is_official')
  final bool? isOfficial;

  const MapTagSimple({required this.name, this.color, this.isOfficial});

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
  List<Object?> get props => [name, color, isOfficial];
}
