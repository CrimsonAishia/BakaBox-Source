import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'feature_status_models.g.dart';

/// 功能类型枚举
enum FeatureType {
  keyConfig, // 按键绑定
  issue, // Issue 反馈
  mapContribution, // 地图贡献
}

/// 功能类型扩展
extension FeatureTypeExtension on FeatureType {
  /// 获取 API 路径
  String get apiPath {
    switch (this) {
      case FeatureType.keyConfig:
        return 'key-config';
      case FeatureType.issue:
        return 'issue';
      case FeatureType.mapContribution:
        return 'map-contribution';
    }
  }

  /// 获取显示名称
  String get displayName {
    switch (this) {
      case FeatureType.keyConfig:
        return '按键绑定';
      case FeatureType.issue:
        return 'Issue 反馈';
      case FeatureType.mapContribution:
        return '地图贡献';
    }
  }
}

/// 功能状态响应
@JsonSerializable()
class FeatureStatus extends Equatable {
  final bool enabled;
  final String message;

  const FeatureStatus({required this.enabled, this.message = ''});

  factory FeatureStatus.fromJson(Map<String, dynamic> json) =>
      _$FeatureStatusFromJson(json);

  Map<String, dynamic> toJson() => _$FeatureStatusToJson(this);

  /// 默认启用状态（用于正常情况）
  static const FeatureStatus defaultEnabled = FeatureStatus(enabled: true);

  /// 默认禁用状态（用于 API 失败时的降级处理）
  static const FeatureStatus defaultDisabled = FeatureStatus(
    enabled: false,
    message: '服务暂时不可用，请稍后再试',
  );

  @override
  List<Object?> get props => [enabled, message];
}

/// 所有功能状态
class AllFeatureStatus extends Equatable {
  final FeatureStatus keyConfig;
  final FeatureStatus issue;
  final FeatureStatus mapContribution;

  const AllFeatureStatus({
    this.keyConfig = FeatureStatus.defaultDisabled,
    this.issue = FeatureStatus.defaultDisabled,
    this.mapContribution = FeatureStatus.defaultDisabled,
  });

  /// 默认全部禁用（API 失败时使用）
  static const AllFeatureStatus allDisabled = AllFeatureStatus();

  AllFeatureStatus copyWith({
    FeatureStatus? keyConfig,
    FeatureStatus? issue,
    FeatureStatus? mapContribution,
  }) {
    return AllFeatureStatus(
      keyConfig: keyConfig ?? this.keyConfig,
      issue: issue ?? this.issue,
      mapContribution: mapContribution ?? this.mapContribution,
    );
  }

  /// 根据功能类型获取状态
  FeatureStatus getStatus(FeatureType type) {
    switch (type) {
      case FeatureType.keyConfig:
        return keyConfig;
      case FeatureType.issue:
        return issue;
      case FeatureType.mapContribution:
        return mapContribution;
    }
  }

  @override
  List<Object?> get props => [keyConfig, issue, mapContribution];
}
