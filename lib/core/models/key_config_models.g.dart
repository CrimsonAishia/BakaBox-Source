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
);

Map<String, dynamic> _$KeyConfigToJson(KeyConfig instance) => <String, dynamic>{
  'id': instance.id,
  'configId': instance.configId,
  'name': instance.name,
  'description': instance.description,
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

KeyConfigCreateRequest _$KeyConfigCreateRequestFromJson(
  Map<String, dynamic> json,
) => KeyConfigCreateRequest(
  configId: json['configId'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  category: json['category'] as String,
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
  'category': instance.category,
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
