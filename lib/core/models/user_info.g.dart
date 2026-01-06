// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserInfo _$UserInfoFromJson(Map<String, dynamic> json) => UserInfo(
  username: json['username'] as String,
  uid: json['uid'] as String,
  avatar: json['avatar'] as String? ?? '',
  steamId: json['steamId'] as String?,
  steamUrl: json['steamUrl'] as String?,
  steamProfileId: json['steamProfileId'] as String?,
  credits: json['credits'] as String?,
  zombieCoins: json['zombieCoins'] as String?,
  userGroup: json['userGroup'] as String?,
);

Map<String, dynamic> _$UserInfoToJson(UserInfo instance) => <String, dynamic>{
  'username': instance.username,
  'uid': instance.uid,
  'avatar': instance.avatar,
  'steamId': instance.steamId,
  'steamUrl': instance.steamUrl,
  'steamProfileId': instance.steamProfileId,
  'credits': instance.credits,
  'zombieCoins': instance.zombieCoins,
  'userGroup': instance.userGroup,
};

BackendUserInfo _$BackendUserInfoFromJson(Map<String, dynamic> json) =>
    BackendUserInfo(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      nickname: json['nickname'] as String?,
      avatar: json['avatar'] as String?,
      zedboxUid: json['zedboxUid'] as String?,
      steamId: json['steamId'] as String?,
      steamProfileId: json['steamProfileId'] as String?,
    );

Map<String, dynamic> _$BackendUserInfoToJson(BackendUserInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'nickname': instance.nickname,
      'avatar': instance.avatar,
      'zedboxUid': instance.zedboxUid,
      'steamId': instance.steamId,
      'steamProfileId': instance.steamProfileId,
    };
