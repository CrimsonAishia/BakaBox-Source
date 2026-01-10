import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import '../utils/server_time_converter.dart';

part 'map_contribution_models.g.dart';

/// 地图贡献类型
enum ContributionType {
  @JsonValue('name')
  name,
  @JsonValue('background')
  background;

  String get value => switch (this) {
    ContributionType.name => 'name',
    ContributionType.background => 'background',
  };

  String get label => switch (this) {
    ContributionType.name => '中文名称',
    ContributionType.background => '背景图片',
  };
}

/// 投票类型
enum VoteType {
  @JsonValue('up')
  up,
  @JsonValue('down')
  down;

  String get value => switch (this) {
    VoteType.up => 'up',
    VoteType.down => 'down',
  };
}

/// 审核状态
enum AuditStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('approved')
  approved,
  @JsonValue('rejected')
  rejected;

  String get value => switch (this) {
    AuditStatus.pending => 'pending',
    AuditStatus.approved => 'approved',
    AuditStatus.rejected => 'rejected',
  };

  String get label => switch (this) {
    AuditStatus.pending => '待审核',
    AuditStatus.approved => '已通过',
    AuditStatus.rejected => '已拒绝',
  };
}

/// 贡献者信息
@JsonSerializable()
class ContributorInfo extends Equatable {
  final int userId;
  final String username;
  final String? avatar;

  const ContributorInfo({
    required this.userId,
    required this.username,
    this.avatar,
  });

  factory ContributorInfo.fromJson(Map<String, dynamic> json) =>
      _$ContributorInfoFromJson(json);
  Map<String, dynamic> toJson() => _$ContributorInfoToJson(this);

  @override
  List<Object?> get props => [userId, username, avatar];
}


/// 地图贡献
@JsonSerializable()
class MapContribution extends Equatable {
  final int id;
  final String mapName;
  final ContributionType type;
  final String content;
  /// 净票数（用于排序）
  final int voteCount;
  /// 点赞数
  @JsonKey(defaultValue: 0)
  final int upCount;
  /// 点踩数
  @JsonKey(defaultValue: 0)
  final int downCount;
  /// 贡献者信息，系统数据时为 null
  final ContributorInfo? contributor;
  final bool hasVoted;
  @JsonKey(name: 'voteType')
  final VoteType? voteType;
  final bool isOwner;
  /// 是否为系统数据（来自 Steam，不可投票）
  @JsonKey(defaultValue: false)
  final bool isSystem;
  /// 审核状态
  @JsonKey(defaultValue: AuditStatus.approved)
  final AuditStatus auditStatus;
  /// 审核备注（拒绝原因）
  @JsonKey(defaultValue: '')
  final String auditRemark;
  /// 审核时间
  @NullableServerTimeConverter()
  final DateTime? auditAt;
  @ServerTimeConverter()
  final DateTime createdAt;
  @ServerTimeConverter()
  final DateTime updatedAt;

  const MapContribution({
    required this.id,
    required this.mapName,
    required this.type,
    required this.content,
    required this.voteCount,
    this.upCount = 0,
    this.downCount = 0,
    this.contributor,
    required this.hasVoted,
    this.voteType,
    required this.isOwner,
    this.isSystem = false,
    this.auditStatus = AuditStatus.approved,
    this.auditRemark = '',
    this.auditAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MapContribution.fromJson(Map<String, dynamic> json) =>
      _$MapContributionFromJson(json);
  Map<String, dynamic> toJson() => _$MapContributionToJson(this);

  /// 是否待审核
  bool get isPending => auditStatus == AuditStatus.pending;
  
  /// 是否已通过
  bool get isApproved => auditStatus == AuditStatus.approved;
  
  /// 是否已拒绝
  bool get isRejected => auditStatus == AuditStatus.rejected;

  /// 获取背景图片的 fileId 引用格式
  /// 
  /// 背景贡献的 content 存储的是 fileId，需要转换为 "file:xxx" 格式
  /// 以便 ImageUrlService 获取签名 URL
  String? get backgroundImageRef {
    if (type != ContributionType.background) return null;
    if (content.isEmpty) return null;
    
    // 如果已经是完整 URL，直接返回
    if (content.startsWith('http://') || content.startsWith('https://')) {
      return content;
    }
    
    // 如果已经是 file: 格式，直接返回
    if (content.startsWith('file:')) {
      return content;
    }
    
    // 尝试解析为 fileId 并转换为引用格式
    final fileId = int.tryParse(content);
    if (fileId != null) {
      return 'file:$fileId';
    }
    
    return content;
  }

  MapContribution copyWith({
    int? id,
    String? mapName,
    ContributionType? type,
    String? content,
    int? voteCount,
    int? upCount,
    int? downCount,
    ContributorInfo? contributor,
    bool clearContributor = false,
    bool? hasVoted,
    VoteType? voteType,
    bool clearVoteType = false,
    bool? isOwner,
    bool? isSystem,
    AuditStatus? auditStatus,
    String? auditRemark,
    DateTime? auditAt,
    bool clearAuditAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MapContribution(
      id: id ?? this.id,
      mapName: mapName ?? this.mapName,
      type: type ?? this.type,
      content: content ?? this.content,
      voteCount: voteCount ?? this.voteCount,
      upCount: upCount ?? this.upCount,
      downCount: downCount ?? this.downCount,
      contributor: clearContributor ? null : (contributor ?? this.contributor),
      hasVoted: hasVoted ?? this.hasVoted,
      voteType: clearVoteType ? null : (voteType ?? this.voteType),
      isOwner: isOwner ?? this.isOwner,
      isSystem: isSystem ?? this.isSystem,
      auditStatus: auditStatus ?? this.auditStatus,
      auditRemark: auditRemark ?? this.auditRemark,
      auditAt: clearAuditAt ? null : (auditAt ?? this.auditAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id, mapName, type, content, voteCount, upCount, downCount, contributor,
    hasVoted, voteType, isOwner, isSystem, auditStatus, auditRemark, auditAt,
    createdAt, updatedAt,
  ];
}

/// 地图贡献摘要（用于服务器卡片显示）
@JsonSerializable()
class MapContributionSummary extends Equatable {
  final String? topName;
  final String? topBackground;
  final int nameCount;
  final int backgroundCount;

  const MapContributionSummary({
    this.topName,
    this.topBackground,
    required this.nameCount,
    required this.backgroundCount,
  });

  factory MapContributionSummary.fromJson(Map<String, dynamic> json) =>
      _$MapContributionSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$MapContributionSummaryToJson(this);

  /// 获取背景图片的 fileId 引用格式
  /// 
  /// topBackground 存储的是 fileId，需要转换为 "file:xxx" 格式
  String? get topBackgroundRef {
    if (topBackground == null || topBackground!.isEmpty) return null;
    
    // 如果已经是完整 URL，直接返回
    if (topBackground!.startsWith('http://') || topBackground!.startsWith('https://')) {
      return topBackground;
    }
    
    // 如果已经是 file: 格式，直接返回
    if (topBackground!.startsWith('file:')) {
      return topBackground;
    }
    
    // 尝试解析为 fileId 并转换为引用格式
    final fileId = int.tryParse(topBackground!);
    if (fileId != null) {
      return 'file:$fileId';
    }
    
    return topBackground;
  }

  @override
  List<Object?> get props => [topName, topBackground, nameCount, backgroundCount];
}

/// 投票响应
@JsonSerializable()
class ContributionVoteResponse extends Equatable {
  final bool success;
  final int newVoteCount;
  /// 点赞数
  @JsonKey(defaultValue: 0)
  final int upCount;
  /// 点踩数
  @JsonKey(defaultValue: 0)
  final int downCount;
  final bool hasVoted;
  final VoteType? voteType;

  const ContributionVoteResponse({
    required this.success,
    required this.newVoteCount,
    this.upCount = 0,
    this.downCount = 0,
    required this.hasVoted,
    this.voteType,
  });

  factory ContributionVoteResponse.fromJson(Map<String, dynamic> json) =>
      _$ContributionVoteResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ContributionVoteResponseToJson(this);

  @override
  List<Object?> get props => [success, newVoteCount, upCount, downCount, hasVoted, voteType];
}
