// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feature_status_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FeatureStatus _$FeatureStatusFromJson(Map<String, dynamic> json) =>
    FeatureStatus(
      enabled: json['enabled'] as bool,
      message: json['message'] as String? ?? '',
    );

Map<String, dynamic> _$FeatureStatusToJson(FeatureStatus instance) =>
    <String, dynamic>{'enabled': instance.enabled, 'message': instance.message};
