import 'package:json_annotation/json_annotation.dart';

part 'server_score.g.dart';

/// 服务器比分数据模型（从 API 返回）
/// 
/// 用于存储众包聚合后的服务器比分信息
@JsonSerializable()
class ServerScore {
  @JsonKey(name: 'server_address') final String serverAddress;
  @JsonKey(name: 'ct_score') final int? ctScore;
  @JsonKey(name: 't_score') final int? tScore;
  final int? round;
  @JsonKey(name: 'map_name') final String? mapName;
  final int? confidence;
  @JsonKey(name: 'source_count') final int? sourceCount;
  @JsonKey(name: 'updated_at') final String? updatedAt;
  @JsonKey(name: 'data_quality') final String dataQuality;

  ServerScore({
    required this.serverAddress,
    this.ctScore,
    this.tScore,
    this.round,
    this.mapName,
    this.confidence,
    this.sourceCount,
    this.updatedAt,
    required this.dataQuality,
  });

  factory ServerScore.fromJson(Map<String, dynamic> json) => _$ServerScoreFromJson(json);
  Map<String, dynamic> toJson() => _$ServerScoreToJson(this);

  ServerScore copyWith({
    String? serverAddress,
    int? ctScore,
    int? tScore,
    int? round,
    String? mapName,
    int? confidence,
    int? sourceCount,
    String? updatedAt,
    String? dataQuality,
    bool clearCtScore = false,
    bool clearTScore = false,
    bool clearRound = false,
    bool clearMapName = false,
    bool clearConfidence = false,
    bool clearSourceCount = false,
    bool clearUpdatedAt = false,
  }) {
    return ServerScore(
      serverAddress: serverAddress ?? this.serverAddress,
      ctScore: clearCtScore ? null : (ctScore ?? this.ctScore),
      tScore: clearTScore ? null : (tScore ?? this.tScore),
      round: clearRound ? null : (round ?? this.round),
      mapName: clearMapName ? null : (mapName ?? this.mapName),
      confidence: clearConfidence ? null : (confidence ?? this.confidence),
      sourceCount: clearSourceCount ? null : (sourceCount ?? this.sourceCount),
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
      dataQuality: dataQuality ?? this.dataQuality,
    );
  }
}
