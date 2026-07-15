import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'upload_models.g.dart';

/// Result of a successful file upload
@JsonSerializable()
class UploadResult extends Equatable {
  final int fileId;
  final String url;
  final String cdnUrl;
  final String fileName;
  final int fileSize;
  final String fileMD5;

  const UploadResult({
    required this.fileId,
    required this.url,
    required this.cdnUrl,
    required this.fileName,
    required this.fileSize,
    required this.fileMD5,
  });

  factory UploadResult.fromJson(Map<String, dynamic> json) =>
      _$UploadResultFromJson(json);

  Map<String, dynamic> toJson() => _$UploadResultToJson(this);

  @override
  List<Object?> get props => [fileId, url, cdnUrl, fileName, fileSize, fileMD5];
}

/// 已上传图片信息
class UploadedImage {
  /// 图片 URL
  final String url;

  /// 缩略图 URL（可选）
  final String? thumbnailUrl;

  /// 文件大小（字节）
  final int fileSize;

  /// 文件名
  final String fileName;

  const UploadedImage({
    required this.url,
    this.thumbnailUrl,
    required this.fileSize,
    required this.fileName,
  });

  /// 格式化文件大小
  String get formattedSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
