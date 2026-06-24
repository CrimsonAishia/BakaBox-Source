import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'report_models.g.dart';

/// 标签投票举报原因
enum TagVoteReportReason {
  @JsonValue('malicious_vote')
  maliciousVote,
  @JsonValue('irrelevant')
  irrelevant,
  @JsonValue('other')
  other;

  String get value => switch (this) {
    TagVoteReportReason.maliciousVote => 'malicious_vote',
    TagVoteReportReason.irrelevant => 'irrelevant',
    TagVoteReportReason.other => 'other',
  };

  String get label => switch (this) {
    TagVoteReportReason.maliciousVote => '恶意刷票',
    TagVoteReportReason.irrelevant => '乱投/不相关',
    TagVoteReportReason.other => '其他',
  };
}

/// 举报弹窗返回的通用 Payload
class ReportPayload<T> extends Equatable {
  final T reason;
  final String? description;
  final List<String> evidenceImages;
  final List<String>? penalties;

  const ReportPayload({
    required this.reason,
    this.description,
    this.evidenceImages = const [],
    this.penalties,
  });

  @override
  List<Object?> get props => [reason, description, evidenceImages, penalties];
}

/// 地图标签投票举报模型
@JsonSerializable()
class MapTagVoteReport extends Equatable {
  final String mapName;
  final int tagId;
  final int voteUserId;
  final String voteUsername;
  final TagVoteReportReason reason;
  final String? description;
  @JsonKey(defaultValue: <String>[])
  final List<String> evidenceImages;
  @JsonKey(defaultValue: <String>[])
  final List<String> penalties;

  const MapTagVoteReport({
    required this.mapName,
    required this.tagId,
    required this.voteUserId,
    required this.voteUsername,
    required this.reason,
    this.description,
    this.evidenceImages = const [],
    this.penalties = const [],
  });

  factory MapTagVoteReport.fromJson(Map<String, dynamic> json) =>
      _$MapTagVoteReportFromJson(json);
  Map<String, dynamic> toJson() => _$MapTagVoteReportToJson(this);

  @override
  List<Object?> get props => [
    mapName,
    tagId,
    voteUserId,
    voteUsername,
    reason,
    description,
    evidenceImages,
    penalties,
  ];
}
