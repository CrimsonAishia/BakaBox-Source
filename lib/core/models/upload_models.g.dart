// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upload_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UploadResult _$UploadResultFromJson(Map<String, dynamic> json) => UploadResult(
  fileId: (json['fileId'] as num).toInt(),
  url: json['url'] as String,
  fileName: json['fileName'] as String,
  fileSize: (json['fileSize'] as num).toInt(),
  fileMD5: json['fileMD5'] as String,
);

Map<String, dynamic> _$UploadResultToJson(UploadResult instance) =>
    <String, dynamic>{
      'fileId': instance.fileId,
      'url': instance.url,
      'fileName': instance.fileName,
      'fileSize': instance.fileSize,
      'fileMD5': instance.fileMD5,
    };
