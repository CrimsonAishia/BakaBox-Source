import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import '../utils/server_time_converter.dart';

part 'queue_user.g.dart';

/// 挤服用户数据模型
///
/// 用于表示正在挤同一服务器的用户信息
@JsonSerializable()
class QueueUser extends Equatable {
  /// 用户ID（登录用户有值，匿名用户为空字符串）
  final String odId;

  /// 访客ID（用于匿名用户标识）
  final String visitorId;

  /// 用户昵称（匿名用户为空）
  final String? nickname;

  /// 头像URL（匿名用户为空）
  final String? avatarUrl;

  /// 是否匿名用户
  bool get isAnonymous => odId.isEmpty;

  /// 是否是当前用户（后端标记）
  final bool isSelf;

  /// 加入挤服时间
  @ServerTimeConverter()
  final DateTime joinedAt;

  const QueueUser({
    required this.odId,
    required this.visitorId,
    this.nickname,
    this.avatarUrl,
    required this.isSelf,
    required this.joinedAt,
  });

  /// 用于去重的唯一标识
  /// 登录用户返回 odId，匿名用户返回 visitorId
  String get uniqueId => odId.isNotEmpty ? odId : visitorId;

  factory QueueUser.fromJson(Map<String, dynamic> json) =>
      _$QueueUserFromJson(json);

  Map<String, dynamic> toJson() => _$QueueUserToJson(this);

  @override
  List<Object?> get props => [
    odId,
    visitorId,
    nickname,
    avatarUrl,
    isSelf,
    joinedAt,
  ];
}
