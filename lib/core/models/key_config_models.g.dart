// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'key_config_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KeyConfig _$KeyConfigFromJson(Map<String, dynamic> json) => KeyConfig(
  id: (json['id'] as num).toInt(),
  configId: json['configId'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  categoryId: (json['categoryId'] as num).toInt(),
  category: json['category'] as String,
  icon: json['icon'] as String?,
  config: json['config'] as String,
  needsKeybind: json['needsKeybind'] as bool,
  userID: (json['userID'] as num).toInt(),
  isActive: json['isActive'] as bool,
  sort: (json['sort'] as num).toInt(),
  createdAt: const ServerTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: const ServerTimeConverter().fromJson(json['updatedAt'] as String),
  userNickname: json['userNickname'] as String?,
  userAvatar: json['userAvatar'] as String?,
  upCount: (json['upCount'] as num?)?.toInt() ?? 0,
  downCount: (json['downCount'] as num?)?.toInt() ?? 0,
  voteCount: (json['voteCount'] as num?)?.toInt() ?? 0,
  hasVoted: json['hasVoted'] as bool? ?? false,
  voteType: json['voteType'] as String?,
  isOwner: json['isOwner'] as bool? ?? false,
  auditStatus:
      $enumDecodeNullable(_$KeyConfigAuditStatusEnumMap, json['auditStatus']) ??
      KeyConfigAuditStatus.approved,
  auditRemark: json['auditRemark'] as String? ?? '',
  auditAt: const NullableServerTimeConverter().fromJson(
    json['auditAt'] as String?,
  ),
  useCount: (json['useCount'] as num?)?.toInt() ?? 0,
  commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
  editReason: json['editReason'] as String?,
  hasPendingChange: json['hasPendingChange'] as bool? ?? false,
);

Map<String, dynamic> _$KeyConfigToJson(KeyConfig instance) => <String, dynamic>{
  'id': instance.id,
  'configId': instance.configId,
  'name': instance.name,
  'description': instance.description,
  'categoryId': instance.categoryId,
  'category': instance.category,
  'icon': instance.icon,
  'config': instance.config,
  'needsKeybind': instance.needsKeybind,
  'userID': instance.userID,
  'isActive': instance.isActive,
  'sort': instance.sort,
  'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
  'updatedAt': const ServerTimeConverter().toJson(instance.updatedAt),
  'userNickname': instance.userNickname,
  'userAvatar': instance.userAvatar,
  'upCount': instance.upCount,
  'downCount': instance.downCount,
  'voteCount': instance.voteCount,
  'hasVoted': instance.hasVoted,
  'voteType': instance.voteType,
  'isOwner': instance.isOwner,
  'auditStatus': _$KeyConfigAuditStatusEnumMap[instance.auditStatus]!,
  'auditRemark': instance.auditRemark,
  'auditAt': const NullableServerTimeConverter().toJson(instance.auditAt),
  'useCount': instance.useCount,
  'commentCount': instance.commentCount,
  'editReason': instance.editReason,
  'hasPendingChange': instance.hasPendingChange,
};

const _$KeyConfigAuditStatusEnumMap = {
  KeyConfigAuditStatus.pending: 'pending',
  KeyConfigAuditStatus.approved: 'approved',
  KeyConfigAuditStatus.rejected: 'rejected',
};

KeyConfigListResponse _$KeyConfigListResponseFromJson(
  Map<String, dynamic> json,
) => KeyConfigListResponse(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => KeyConfig.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$KeyConfigListResponseToJson(
  KeyConfigListResponse instance,
) => <String, dynamic>{'items': instance.items, 'total': instance.total};

KeyConfigCategory _$KeyConfigCategoryFromJson(Map<String, dynamic> json) =>
    KeyConfigCategory(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
    );

Map<String, dynamic> _$KeyConfigCategoryToJson(KeyConfigCategory instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};

KeyConfigCreateRequest _$KeyConfigCreateRequestFromJson(
  Map<String, dynamic> json,
) => KeyConfigCreateRequest(
  configId: json['configId'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  categoryId: (json['categoryId'] as num).toInt(),
  icon: json['icon'] as String?,
  config: json['config'] as String,
  needsKeybind: json['needsKeybind'] as bool,
  isActive: json['isActive'] as bool?,
  sort: (json['sort'] as num?)?.toInt(),
);

Map<String, dynamic> _$KeyConfigCreateRequestToJson(
  KeyConfigCreateRequest instance,
) => <String, dynamic>{
  'configId': instance.configId,
  'name': instance.name,
  'description': instance.description,
  'categoryId': instance.categoryId,
  'icon': instance.icon,
  'config': instance.config,
  'needsKeybind': instance.needsKeybind,
  'isActive': instance.isActive,
  'sort': instance.sort,
};

KeyConfigVoteResponse _$KeyConfigVoteResponseFromJson(
  Map<String, dynamic> json,
) => KeyConfigVoteResponse(
  success: json['success'] as bool,
  upCount: (json['upCount'] as num?)?.toInt() ?? 0,
  downCount: (json['downCount'] as num?)?.toInt() ?? 0,
  voteCount: (json['voteCount'] as num?)?.toInt() ?? 0,
  hasVoted: json['hasVoted'] as bool,
  voteType: json['voteType'] as String?,
);

Map<String, dynamic> _$KeyConfigVoteResponseToJson(
  KeyConfigVoteResponse instance,
) => <String, dynamic>{
  'success': instance.success,
  'upCount': instance.upCount,
  'downCount': instance.downCount,
  'voteCount': instance.voteCount,
  'hasVoted': instance.hasVoted,
  'voteType': instance.voteType,
};

KeyConfigComment _$KeyConfigCommentFromJson(
  Map<String, dynamic> json,
) => KeyConfigComment(
  id: (json['id'] as num).toInt(),
  configId: (json['configId'] as num).toInt(),
  authorId: (json['authorId'] as num).toInt(),
  authorName: json['authorName'] as String,
  authorAvatar: json['authorAvatar'] as String?,
  isAdmin: json['isAdmin'] as bool? ?? false,
  content: json['content'] as String,
  images:
      (json['images'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  replyToId: (json['replyToId'] as num?)?.toInt(),
  replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
  createdAt: const ServerTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: const NullableServerTimeConverter().fromJson(
    json['updatedAt'] as String?,
  ),
);

Map<String, dynamic> _$KeyConfigCommentToJson(
  KeyConfigComment instance,
) => <String, dynamic>{
  'id': instance.id,
  'configId': instance.configId,
  'authorId': instance.authorId,
  'authorName': instance.authorName,
  'authorAvatar': instance.authorAvatar,
  'isAdmin': instance.isAdmin,
  'content': instance.content,
  'images': instance.images,
  'replyToId': instance.replyToId,
  'replyCount': instance.replyCount,
  'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
  'updatedAt': const NullableServerTimeConverter().toJson(instance.updatedAt),
};

KeyConfigCommentListResponse _$KeyConfigCommentListResponseFromJson(
  Map<String, dynamic> json,
) => KeyConfigCommentListResponse(
  total: (json['total'] as num).toInt(),
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => KeyConfigComment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$KeyConfigCommentListResponseToJson(
  KeyConfigCommentListResponse instance,
) => <String, dynamic>{'total': instance.total, 'items': instance.items};

KeyConfigCreateCommentResponse _$KeyConfigCreateCommentResponseFromJson(
  Map<String, dynamic> json,
) => KeyConfigCreateCommentResponse(
  id: (json['id'] as num).toInt(),
  content: json['content'] as String,
  createdAt: const ServerTimeConverter().fromJson(json['createdAt'] as String),
);

Map<String, dynamic> _$KeyConfigCreateCommentResponseToJson(
  KeyConfigCreateCommentResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'content': instance.content,
  'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
};

KeyConfigChangeRequest _$KeyConfigChangeRequestFromJson(
  Map<String, dynamic> json,
) => KeyConfigChangeRequest(
  id: (json['id'] as num).toInt(),
  configId: (json['configId'] as num).toInt(),
  originalConfigName: json['originalConfigName'] as String,
  changeType: $enumDecode(_$KeyConfigChangeTypeEnumMap, json['changeType']),
  editReason: json['editReason'] as String,
  auditStatus: $enumDecode(_$KeyConfigAuditStatusEnumMap, json['auditStatus']),
  auditRemark: json['auditRemark'] as String? ?? '',
  auditAt: const NullableServerTimeConverter().fromJson(
    json['auditAt'] as String?,
  ),
  pendingName: json['pendingName'] as String?,
  pendingDescription: json['pendingDescription'] as String?,
  pendingCategoryId: (json['pendingCategoryId'] as num?)?.toInt(),
  pendingCategory: json['pendingCategory'] as String?,
  pendingIcon: json['pendingIcon'] as String?,
  pendingConfig: json['pendingConfig'] as String?,
  pendingNeedsKeybind: json['pendingNeedsKeybind'] as bool?,
  pendingIsActive: json['pendingIsActive'] as bool?,
  pendingSort: (json['pendingSort'] as num?)?.toInt(),
  createdAt: const ServerTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: const ServerTimeConverter().fromJson(json['updatedAt'] as String),
);

Map<String, dynamic> _$KeyConfigChangeRequestToJson(
  KeyConfigChangeRequest instance,
) => <String, dynamic>{
  'id': instance.id,
  'configId': instance.configId,
  'originalConfigName': instance.originalConfigName,
  'changeType': _$KeyConfigChangeTypeEnumMap[instance.changeType]!,
  'editReason': instance.editReason,
  'auditStatus': _$KeyConfigAuditStatusEnumMap[instance.auditStatus]!,
  'auditRemark': instance.auditRemark,
  'auditAt': const NullableServerTimeConverter().toJson(instance.auditAt),
  'pendingName': instance.pendingName,
  'pendingDescription': instance.pendingDescription,
  'pendingCategoryId': instance.pendingCategoryId,
  'pendingCategory': instance.pendingCategory,
  'pendingIcon': instance.pendingIcon,
  'pendingConfig': instance.pendingConfig,
  'pendingNeedsKeybind': instance.pendingNeedsKeybind,
  'pendingIsActive': instance.pendingIsActive,
  'pendingSort': instance.pendingSort,
  'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
  'updatedAt': const ServerTimeConverter().toJson(instance.updatedAt),
};

const _$KeyConfigChangeTypeEnumMap = {
  KeyConfigChangeType.edit: 'edit',
  KeyConfigChangeType.delete: 'delete',
};

KeyConfigChangeRequestListResponse _$KeyConfigChangeRequestListResponseFromJson(
  Map<String, dynamic> json,
) => KeyConfigChangeRequestListResponse(
  items:
      (json['items'] as List<dynamic>?)
          ?.map(
            (e) => KeyConfigChangeRequest.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      [],
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$KeyConfigChangeRequestListResponseToJson(
  KeyConfigChangeRequestListResponse instance,
) => <String, dynamic>{'items': instance.items, 'total': instance.total};

KeyConfigUseResponse _$KeyConfigUseResponseFromJson(
  Map<String, dynamic> json,
) => KeyConfigUseResponse(useCount: (json['useCount'] as num).toInt());

Map<String, dynamic> _$KeyConfigUseResponseToJson(
  KeyConfigUseResponse instance,
) => <String, dynamic>{'useCount': instance.useCount};
