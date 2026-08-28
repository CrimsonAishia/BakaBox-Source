import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'user_info.dart';

part 'auth_models.g.dart';

@JsonSerializable()
class BackendTokenResponse extends Equatable {
  @JsonKey(name: 'access_token')
  final String accessToken;

  @JsonKey(name: 'refresh_token')
  final String? refreshToken;

  @JsonKey(name: 'expires_in')
  final int expiresIn;

  @JsonKey(name: 'token_type')
  final String tokenType;

  @JsonKey(name: 'user_info')
  final BackendUserInfo? userInfo;

  const BackendTokenResponse({
    required this.accessToken,
    this.refreshToken,
    required this.expiresIn,
    required this.tokenType,
    this.userInfo,
  });

  factory BackendTokenResponse.fromJson(Map<String, dynamic> json) =>
      _$BackendTokenResponseFromJson(json);

  Map<String, dynamic> toJson() => _$BackendTokenResponseToJson(this);

  @override
  List<Object?> get props => [
    accessToken,
    refreshToken,
    expiresIn,
    tokenType,
    userInfo,
  ];
}
