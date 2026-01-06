import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import '../utils/server_time_converter.dart';

part 'issue_models.g.dart';

/// Issue 类型
enum IssueType {
  @JsonValue('bug')
  bug,
  @JsonValue('feature')
  feature,
  @JsonValue('question')
  question;

  String get label => switch (this) {
    IssueType.bug => 'Bug',
    IssueType.feature => '功能建议',
    IssueType.question => '问题咨询',
  };

  String get value => switch (this) {
    IssueType.bug => 'bug',
    IssueType.feature => 'feature',
    IssueType.question => 'question',
  };
}

/// Issue 状态
enum IssueStatus {
  @JsonValue('open')
  open,
  @JsonValue('confirmed')
  confirmed,
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('resolved')
  resolved,
  @JsonValue('wontfix')
  wontfix,
  @JsonValue('duplicate')
  duplicate,
  @JsonValue('closed')
  closed;

  String get label => switch (this) {
    IssueStatus.open => '开放',
    IssueStatus.confirmed => '已确认',
    IssueStatus.inProgress => '进行中',
    IssueStatus.resolved => '已解决',
    IssueStatus.wontfix => '不修复',
    IssueStatus.duplicate => '重复',
    IssueStatus.closed => '已关闭',
  };

  bool get isOpen => this == IssueStatus.open || this == IssueStatus.confirmed || this == IssueStatus.inProgress;
}

/// 设备信息
@JsonSerializable()
class DeviceInfo extends Equatable {
  final String appVersion;
  final String platform;
  final String osVersion;
  final String? deviceModel;

  const DeviceInfo({
    required this.appVersion,
    required this.platform,
    required this.osVersion,
    this.deviceModel,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => _$DeviceInfoFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceInfoToJson(this);

  @override
  List<Object?> get props => [appVersion, platform, osVersion, deviceModel];
}

/// Issue 列表项（精简）
@JsonSerializable()
class IssueListItem extends Equatable {
  final int id;
  final String type;
  final String title;
  final String status;
  final String authorName;
  final String? authorAvatar;
  final int voteCount;
  final int commentCount;
  @ServerTimeConverter()
  final DateTime createdAt;
  @ServerTimeConverter()
  final DateTime updatedAt;

  const IssueListItem({
    required this.id,
    required this.type,
    required this.title,
    required this.status,
    required this.authorName,
    this.authorAvatar,
    required this.voteCount,
    required this.commentCount,
    required this.createdAt,
    required this.updatedAt,
  });

  IssueType get issueType => IssueType.values.firstWhere(
    (e) => e.value == type,
    orElse: () => IssueType.question,
  );

  IssueStatus get issueStatus => IssueStatus.values.firstWhere(
    (e) => e.name == status || e.toString().split('.').last == status,
    orElse: () => IssueStatus.open,
  );

  factory IssueListItem.fromJson(Map<String, dynamic> json) => _$IssueListItemFromJson(json);
  Map<String, dynamic> toJson() => _$IssueListItemToJson(this);

  @override
  List<Object?> get props => [id, type, title, status, authorName, authorAvatar, voteCount, commentCount, createdAt, updatedAt];
}

/// Issue 详情
@JsonSerializable()
class Issue extends Equatable {
  final int id;
  final int authorId;
  final String authorName;
  final String? authorAvatar;
  final String type;
  final String title;
  final String content;
  final List<String> images;
  final List<String> labels;
  final String status;
  final int voteCount;
  final int commentCount;
  final bool isVoted;
  final DeviceInfo? deviceInfo;
  @ServerTimeConverter()
  final DateTime createdAt;
  @ServerTimeConverter()
  final DateTime updatedAt;

  const Issue({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.type,
    required this.title,
    required this.content,
    this.images = const [],
    this.labels = const [],
    required this.status,
    required this.voteCount,
    required this.commentCount,
    this.isVoted = false,
    this.deviceInfo,
    required this.createdAt,
    required this.updatedAt,
  });

  IssueType get issueType => IssueType.values.firstWhere(
    (e) => e.value == type,
    orElse: () => IssueType.question,
  );

  IssueStatus get issueStatus => IssueStatus.values.firstWhere(
    (e) => e.name == status || e.toString().split('.').last == status,
    orElse: () => IssueStatus.open,
  );

  Issue copyWith({
    int? id,
    int? authorId,
    String? authorName,
    String? authorAvatar,
    String? type,
    String? title,
    String? content,
    List<String>? images,
    List<String>? labels,
    String? status,
    int? voteCount,
    int? commentCount,
    bool? isVoted,
    DeviceInfo? deviceInfo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Issue(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      images: images ?? this.images,
      labels: labels ?? this.labels,
      status: status ?? this.status,
      voteCount: voteCount ?? this.voteCount,
      commentCount: commentCount ?? this.commentCount,
      isVoted: isVoted ?? this.isVoted,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Issue.fromJson(Map<String, dynamic> json) => _$IssueFromJson(json);
  Map<String, dynamic> toJson() => _$IssueToJson(this);

  @override
  List<Object?> get props => [id, authorId, authorName, authorAvatar, type, title, content, images, labels, status, voteCount, commentCount, isVoted, deviceInfo, createdAt, updatedAt];
}

/// Issue 评论
@JsonSerializable()
class IssueComment extends Equatable {
  final int id;
  final int issueId;
  final int authorId;
  final String authorName;
  final String? authorAvatar;
  final bool isAdmin;
  final String content;
  final List<String> images;
  @ServerTimeConverter()
  final DateTime createdAt;
  @NullableServerTimeConverter()
  final DateTime? updatedAt;

  const IssueComment({
    required this.id,
    required this.issueId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.isAdmin = false,
    required this.content,
    this.images = const [],
    required this.createdAt,
    this.updatedAt,
  });

  factory IssueComment.fromJson(Map<String, dynamic> json) => _$IssueCommentFromJson(json);
  Map<String, dynamic> toJson() => _$IssueCommentToJson(this);

  @override
  List<Object?> get props => [id, issueId, authorId, authorName, authorAvatar, isAdmin, content, images, createdAt, updatedAt];
}

/// Issue 列表响应
@JsonSerializable()
class IssueListResponse extends Equatable {
  final int total;
  final List<IssueListItem> items;

  const IssueListResponse({
    required this.total,
    required this.items,
  });

  factory IssueListResponse.fromJson(Map<String, dynamic> json) =>
      _$IssueListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$IssueListResponseToJson(this);

  @override
  List<Object?> get props => [total, items];
}

/// 评论列表响应
@JsonSerializable()
class CommentListResponse extends Equatable {
  final int total;
  final List<IssueComment> items;

  const CommentListResponse({
    required this.total,
    required this.items,
  });

  factory CommentListResponse.fromJson(Map<String, dynamic> json) =>
      _$CommentListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CommentListResponseToJson(this);

  @override
  List<Object?> get props => [total, items];
}

/// Issue 列表请求
@JsonSerializable()
class IssueListRequest extends Equatable {
  final IssuePagination pagination;
  final String type;
  final String status;
  final String keyword;
  final String keywordType;

  const IssueListRequest({
    required this.pagination,
    this.type = 'all',
    this.status = 'open',
    this.keyword = '',
    this.keywordType = '',
  });

  factory IssueListRequest.fromJson(Map<String, dynamic> json) =>
      _$IssueListRequestFromJson(json);
  Map<String, dynamic> toJson() => _$IssueListRequestToJson(this);

  @override
  List<Object?> get props => [pagination, type, status, keyword, keywordType];
}

/// Issue 分页参数
@JsonSerializable()
class IssuePagination extends Equatable {
  final int pageIndex;
  final int pageSize;
  final String orderBy;

  const IssuePagination({
    required this.pageIndex,
    required this.pageSize,
    this.orderBy = 'created_at DESC',
  });

  factory IssuePagination.fromJson(Map<String, dynamic> json) =>
      _$IssuePaginationFromJson(json);
  Map<String, dynamic> toJson() => _$IssuePaginationToJson(this);

  @override
  List<Object?> get props => [pageIndex, pageSize, orderBy];
}

/// 评论列表请求
@JsonSerializable()
class CommentListRequest extends Equatable {
  final IssuePagination pagination;

  const CommentListRequest({required this.pagination});

  factory CommentListRequest.fromJson(Map<String, dynamic> json) =>
      _$CommentListRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CommentListRequestToJson(this);

  @override
  List<Object?> get props => [pagination];
}

/// 创建 Issue 请求
@JsonSerializable()
class CreateIssueRequest extends Equatable {
  final String type;
  final String title;
  final String content;
  final List<String>? images;
  final List<String>? labels;
  final DeviceInfo? deviceInfo;

  const CreateIssueRequest({
    required this.type,
    required this.title,
    required this.content,
    this.images,
    this.labels,
    this.deviceInfo,
  });

  factory CreateIssueRequest.fromJson(Map<String, dynamic> json) => _$CreateIssueRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateIssueRequestToJson(this);

  @override
  List<Object?> get props => [type, title, content, images, labels, deviceInfo];
}

/// 投票响应
@JsonSerializable()
class VoteResponse extends Equatable {
  final int voteCount;
  final bool isVoted;

  const VoteResponse({
    required this.voteCount,
    required this.isVoted,
  });

  factory VoteResponse.fromJson(Map<String, dynamic> json) => _$VoteResponseFromJson(json);
  Map<String, dynamic> toJson() => _$VoteResponseToJson(this);

  @override
  List<Object?> get props => [voteCount, isVoted];
}

/// 创建 Issue 响应（接口返回简化数据）
@JsonSerializable()
class CreateIssueResponse extends Equatable {
  final int id;
  final String title;
  final String status;

  const CreateIssueResponse({
    required this.id,
    required this.title,
    required this.status,
  });

  factory CreateIssueResponse.fromJson(Map<String, dynamic> json) => _$CreateIssueResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CreateIssueResponseToJson(this);

  @override
  List<Object?> get props => [id, title, status];
}

/// 创建评论响应（接口返回简化数据）
@JsonSerializable()
class CreateCommentResponse extends Equatable {
  final int id;
  final String content;
  @ServerTimeConverter()
  final DateTime createdAt;

  const CreateCommentResponse({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  factory CreateCommentResponse.fromJson(Map<String, dynamic> json) => _$CreateCommentResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CreateCommentResponseToJson(this);

  @override
  List<Object?> get props => [id, content, createdAt];
}
