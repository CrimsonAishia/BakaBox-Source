import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_info.g.dart';

/// 用户信息模型
@JsonSerializable()
class UserInfo extends Equatable {
  final String username;
  final String uid;
  final String avatar;
  final String? steamId;
  final String? steamUrl;
  final String? steamProfileId;
  final String? credits;
  final String? zombieCoins;
  final String? userGroup;

  const UserInfo({
    required this.username,
    required this.uid,
    this.avatar = '',
    this.steamId,
    this.steamUrl,
    this.steamProfileId,
    this.credits,
    this.zombieCoins,
    this.userGroup,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) =>
      _$UserInfoFromJson(json);
  Map<String, dynamic> toJson() => _$UserInfoToJson(this);

  UserInfo copyWith({
    String? username,
    String? uid,
    String? avatar,
    String? steamId,
    String? steamUrl,
    String? steamProfileId,
    String? credits,
    String? zombieCoins,
    String? userGroup,
  }) {
    return UserInfo(
      username: username ?? this.username,
      uid: uid ?? this.uid,
      avatar: avatar ?? this.avatar,
      steamId: steamId ?? this.steamId,
      steamUrl: steamUrl ?? this.steamUrl,
      steamProfileId: steamProfileId ?? this.steamProfileId,
      credits: credits ?? this.credits,
      zombieCoins: zombieCoins ?? this.zombieCoins,
      userGroup: userGroup ?? this.userGroup,
    );
  }

  @override
  List<Object?> get props => [
    username,
    uid,
    avatar,
    steamId,
    steamUrl,
    steamProfileId,
    credits,
    zombieCoins,
    userGroup,
  ];
}

/// 后端用户信息
@JsonSerializable()
class BackendUserInfo extends Equatable {
  final int id;
  final String username;
  final String? nickname;
  final String? avatar;
  final String? zedboxUid;
  final String? steamId;
  final String? steamProfileId;

  const BackendUserInfo({
    required this.id,
    required this.username,
    this.nickname,
    this.avatar,
    this.zedboxUid,
    this.steamId,
    this.steamProfileId,
  });

  factory BackendUserInfo.fromJson(Map<String, dynamic> json) =>
      _$BackendUserInfoFromJson(json);
  Map<String, dynamic> toJson() => _$BackendUserInfoToJson(this);

  @override
  List<Object?> get props => [
    id,
    username,
    nickname,
    avatar,
    zedboxUid,
    steamId,
    steamProfileId,
  ];
}
