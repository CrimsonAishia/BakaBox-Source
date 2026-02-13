// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QueueUser _$QueueUserFromJson(Map<String, dynamic> json) => QueueUser(
  odId: json['odId'] as String,
  visitorId: json['visitorId'] as String,
  nickname: json['nickname'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  isAnonymous: json['isAnonymous'] as bool,
  isSelf: json['isSelf'] as bool,
  joinedAt: const ServerTimeConverter().fromJson(json['joinedAt'] as String),
);

Map<String, dynamic> _$QueueUserToJson(QueueUser instance) => <String, dynamic>{
  'odId': instance.odId,
  'visitorId': instance.visitorId,
  'nickname': instance.nickname,
  'avatarUrl': instance.avatarUrl,
  'isAnonymous': instance.isAnonymous,
  'isSelf': instance.isSelf,
  'joinedAt': const ServerTimeConverter().toJson(instance.joinedAt),
};
