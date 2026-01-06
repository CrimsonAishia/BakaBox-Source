// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'issue_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceInfo _$DeviceInfoFromJson(Map<String, dynamic> json) => DeviceInfo(
  appVersion: json['appVersion'] as String,
  platform: json['platform'] as String,
  osVersion: json['osVersion'] as String,
  deviceModel: json['deviceModel'] as String?,
);

Map<String, dynamic> _$DeviceInfoToJson(DeviceInfo instance) =>
    <String, dynamic>{
      'appVersion': instance.appVersion,
      'platform': instance.platform,
      'osVersion': instance.osVersion,
      'deviceModel': instance.deviceModel,
    };

IssueListItem _$IssueListItemFromJson(
  Map<String, dynamic> json,
) => IssueListItem(
  id: (json['id'] as num).toInt(),
  type: json['type'] as String,
  title: json['title'] as String,
  status: json['status'] as String,
  authorName: json['authorName'] as String,
  authorAvatar: json['authorAvatar'] as String?,
  voteCount: (json['voteCount'] as num).toInt(),
  commentCount: (json['commentCount'] as num).toInt(),
  createdAt: const ServerTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: const ServerTimeConverter().fromJson(json['updatedAt'] as String),
);

Map<String, dynamic> _$IssueListItemToJson(IssueListItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'title': instance.title,
      'status': instance.status,
      'authorName': instance.authorName,
      'authorAvatar': instance.authorAvatar,
      'voteCount': instance.voteCount,
      'commentCount': instance.commentCount,
      'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
      'updatedAt': const ServerTimeConverter().toJson(instance.updatedAt),
    };

Issue _$IssueFromJson(Map<String, dynamic> json) => Issue(
  id: (json['id'] as num).toInt(),
  authorId: (json['authorId'] as num).toInt(),
  authorName: json['authorName'] as String,
  authorAvatar: json['authorAvatar'] as String?,
  type: json['type'] as String,
  title: json['title'] as String,
  content: json['content'] as String,
  images:
      (json['images'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  labels:
      (json['labels'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  status: json['status'] as String,
  voteCount: (json['voteCount'] as num).toInt(),
  commentCount: (json['commentCount'] as num).toInt(),
  isVoted: json['isVoted'] as bool? ?? false,
  deviceInfo: json['deviceInfo'] == null
      ? null
      : DeviceInfo.fromJson(json['deviceInfo'] as Map<String, dynamic>),
  createdAt: const ServerTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: const ServerTimeConverter().fromJson(json['updatedAt'] as String),
);

Map<String, dynamic> _$IssueToJson(Issue instance) => <String, dynamic>{
  'id': instance.id,
  'authorId': instance.authorId,
  'authorName': instance.authorName,
  'authorAvatar': instance.authorAvatar,
  'type': instance.type,
  'title': instance.title,
  'content': instance.content,
  'images': instance.images,
  'labels': instance.labels,
  'status': instance.status,
  'voteCount': instance.voteCount,
  'commentCount': instance.commentCount,
  'isVoted': instance.isVoted,
  'deviceInfo': instance.deviceInfo,
  'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
  'updatedAt': const ServerTimeConverter().toJson(instance.updatedAt),
};

IssueComment _$IssueCommentFromJson(Map<String, dynamic> json) => IssueComment(
  id: (json['id'] as num).toInt(),
  issueId: (json['issueId'] as num).toInt(),
  authorId: (json['authorId'] as num).toInt(),
  authorName: json['authorName'] as String,
  authorAvatar: json['authorAvatar'] as String?,
  isAdmin: json['isAdmin'] as bool? ?? false,
  content: json['content'] as String,
  images:
      (json['images'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  createdAt: const ServerTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: const NullableServerTimeConverter().fromJson(
    json['updatedAt'] as String?,
  ),
);

Map<String, dynamic> _$IssueCommentToJson(
  IssueComment instance,
) => <String, dynamic>{
  'id': instance.id,
  'issueId': instance.issueId,
  'authorId': instance.authorId,
  'authorName': instance.authorName,
  'authorAvatar': instance.authorAvatar,
  'isAdmin': instance.isAdmin,
  'content': instance.content,
  'images': instance.images,
  'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
  'updatedAt': const NullableServerTimeConverter().toJson(instance.updatedAt),
};

IssueListResponse _$IssueListResponseFromJson(Map<String, dynamic> json) =>
    IssueListResponse(
      total: (json['total'] as num).toInt(),
      items: (json['items'] as List<dynamic>)
          .map((e) => IssueListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$IssueListResponseToJson(IssueListResponse instance) =>
    <String, dynamic>{'total': instance.total, 'items': instance.items};

CommentListResponse _$CommentListResponseFromJson(Map<String, dynamic> json) =>
    CommentListResponse(
      total: (json['total'] as num).toInt(),
      items: (json['items'] as List<dynamic>)
          .map((e) => IssueComment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CommentListResponseToJson(
  CommentListResponse instance,
) => <String, dynamic>{'total': instance.total, 'items': instance.items};

IssueListRequest _$IssueListRequestFromJson(Map<String, dynamic> json) =>
    IssueListRequest(
      pagination: IssuePagination.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
      type: json['type'] as String? ?? 'all',
      status: json['status'] as String? ?? 'open',
      keyword: json['keyword'] as String? ?? '',
      keywordType: json['keywordType'] as String? ?? '',
    );

Map<String, dynamic> _$IssueListRequestToJson(IssueListRequest instance) =>
    <String, dynamic>{
      'pagination': instance.pagination,
      'type': instance.type,
      'status': instance.status,
      'keyword': instance.keyword,
      'keywordType': instance.keywordType,
    };

IssuePagination _$IssuePaginationFromJson(Map<String, dynamic> json) =>
    IssuePagination(
      pageIndex: (json['pageIndex'] as num).toInt(),
      pageSize: (json['pageSize'] as num).toInt(),
      orderBy: json['orderBy'] as String? ?? 'created_at DESC',
    );

Map<String, dynamic> _$IssuePaginationToJson(IssuePagination instance) =>
    <String, dynamic>{
      'pageIndex': instance.pageIndex,
      'pageSize': instance.pageSize,
      'orderBy': instance.orderBy,
    };

CommentListRequest _$CommentListRequestFromJson(Map<String, dynamic> json) =>
    CommentListRequest(
      pagination: IssuePagination.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$CommentListRequestToJson(CommentListRequest instance) =>
    <String, dynamic>{'pagination': instance.pagination};

CreateIssueRequest _$CreateIssueRequestFromJson(
  Map<String, dynamic> json,
) => CreateIssueRequest(
  type: json['type'] as String,
  title: json['title'] as String,
  content: json['content'] as String,
  images: (json['images'] as List<dynamic>?)?.map((e) => e as String).toList(),
  labels: (json['labels'] as List<dynamic>?)?.map((e) => e as String).toList(),
  deviceInfo: json['deviceInfo'] == null
      ? null
      : DeviceInfo.fromJson(json['deviceInfo'] as Map<String, dynamic>),
);

Map<String, dynamic> _$CreateIssueRequestToJson(CreateIssueRequest instance) =>
    <String, dynamic>{
      'type': instance.type,
      'title': instance.title,
      'content': instance.content,
      'images': instance.images,
      'labels': instance.labels,
      'deviceInfo': instance.deviceInfo,
    };

VoteResponse _$VoteResponseFromJson(Map<String, dynamic> json) => VoteResponse(
  voteCount: (json['voteCount'] as num).toInt(),
  isVoted: json['isVoted'] as bool,
);

Map<String, dynamic> _$VoteResponseToJson(VoteResponse instance) =>
    <String, dynamic>{
      'voteCount': instance.voteCount,
      'isVoted': instance.isVoted,
    };

CreateIssueResponse _$CreateIssueResponseFromJson(Map<String, dynamic> json) =>
    CreateIssueResponse(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      status: json['status'] as String,
    );

Map<String, dynamic> _$CreateIssueResponseToJson(
  CreateIssueResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'status': instance.status,
};

CreateCommentResponse _$CreateCommentResponseFromJson(
  Map<String, dynamic> json,
) => CreateCommentResponse(
  id: (json['id'] as num).toInt(),
  content: json['content'] as String,
  createdAt: const ServerTimeConverter().fromJson(json['createdAt'] as String),
);

Map<String, dynamic> _$CreateCommentResponseToJson(
  CreateCommentResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'content': instance.content,
  'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
};
