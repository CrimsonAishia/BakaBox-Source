// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upload_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UploadResult _$UploadResultFromJson(Map<String, dynamic> json) => UploadResult(
  fileId: (json['fileId'] as num).toInt(),
  url: json['url'] as String,
  cdnUrl: json['cdnUrl'] as String,
  fileName: json['fileName'] as String,
  fileSize: (json['fileSize'] as num).toInt(),
  fileMD5: json['fileMD5'] as String,
);

Map<String, dynamic> _$UploadResultToJson(UploadResult instance) =>
    <String, dynamic>{
      'fileId': instance.fileId,
      'url': instance.url,
      'cdnUrl': instance.cdnUrl,
      'fileName': instance.fileName,
      'fileSize': instance.fileSize,
      'fileMD5': instance.fileMD5,
    };

InitUploadResponse _$InitUploadResponseFromJson(Map<String, dynamic> json) =>
    InitUploadResponse(
      uploadId: json['uploadId'] as String,
      fileKey: json['fileKey'] as String,
      fileId: (json['fileId'] as num).toInt(),
      url: json['url'] as String,
      isExists: json['isExists'] as bool,
    );

Map<String, dynamic> _$InitUploadResponseToJson(InitUploadResponse instance) =>
    <String, dynamic>{
      'uploadId': instance.uploadId,
      'fileKey': instance.fileKey,
      'fileId': instance.fileId,
      'url': instance.url,
      'isExists': instance.isExists,
    };

PartUploadResponse _$PartUploadResponseFromJson(Map<String, dynamic> json) =>
    PartUploadResponse(etag: json['etag'] as String);

Map<String, dynamic> _$PartUploadResponseToJson(PartUploadResponse instance) =>
    <String, dynamic>{'etag': instance.etag};

CompleteUploadResponse _$CompleteUploadResponseFromJson(
  Map<String, dynamic> json,
) => CompleteUploadResponse(
  fileId: (json['fileId'] as num).toInt(),
  url: json['url'] as String,
);

Map<String, dynamic> _$CompleteUploadResponseToJson(
  CompleteUploadResponse instance,
) => <String, dynamic>{'fileId': instance.fileId, 'url': instance.url};
