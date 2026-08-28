// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BackendTokenResponse _$BackendTokenResponseFromJson(
  Map<String, dynamic> json,
) => BackendTokenResponse(
  accessToken: json['access_token'] as String,
  refreshToken: json['refresh_token'] as String?,
  expiresIn: (json['expires_in'] as num).toInt(),
  tokenType: json['token_type'] as String,
  userInfo: json['user_info'] == null
      ? null
      : BackendUserInfo.fromJson(json['user_info'] as Map<String, dynamic>),
);

Map<String, dynamic> _$BackendTokenResponseToJson(
  BackendTokenResponse instance,
) => <String, dynamic>{
  'access_token': instance.accessToken,
  'refresh_token': instance.refreshToken,
  'expires_in': instance.expiresIn,
  'token_type': instance.tokenType,
  'user_info': instance.userInfo,
};
