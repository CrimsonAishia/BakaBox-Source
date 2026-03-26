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

/// Response from initializing a multipart upload
///
/// API: POST /files/multipart
///
/// 响应字段:
/// - uploadId: 上传ID，后续操作需要
/// - fileKey: 文件Key
/// - fileId: 已存在文件的ID（秒传时返回）
/// - url: 已存在文件的URL（秒传时返回）
/// - isExists: 文件是否已存在
@JsonSerializable()
class InitUploadResponse extends Equatable {
  final String uploadId;
  final String fileKey;
  final int fileId;
  final String url;
  final bool isExists;

  const InitUploadResponse({
    required this.uploadId,
    required this.fileKey,
    required this.fileId,
    required this.url,
    required this.isExists,
  });

  factory InitUploadResponse.fromJson(Map<String, dynamic> json) =>
      _$InitUploadResponseFromJson(json);

  Map<String, dynamic> toJson() => _$InitUploadResponseToJson(this);

  @override
  List<Object?> get props => [uploadId, fileKey, fileId, url, isExists];
}

/// Response from uploading a single part
///
/// API: PUT /files/multipart/:uploadId/parts/:partNumber
@JsonSerializable()
class PartUploadResponse extends Equatable {
  final String etag;

  const PartUploadResponse({required this.etag});

  factory PartUploadResponse.fromJson(Map<String, dynamic> json) =>
      _$PartUploadResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PartUploadResponseToJson(this);

  @override
  List<Object?> get props => [etag];
}

/// Response from completing a multipart upload
///
/// API: POST /files/multipart/:uploadId/complete
@JsonSerializable()
class CompleteUploadResponse extends Equatable {
  final int fileId;
  final String url;

  const CompleteUploadResponse({required this.fileId, required this.url});

  factory CompleteUploadResponse.fromJson(Map<String, dynamic> json) =>
      _$CompleteUploadResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CompleteUploadResponseToJson(this);

  @override
  List<Object?> get props => [fileId, url];
}

/// Upload progress tracking
class UploadProgress extends Equatable {
  final String fileName;
  final int totalBytes;
  final int uploadedBytes;
  final double progress;
  final UploadStatus status;
  final String? error;

  const UploadProgress({
    required this.fileName,
    required this.totalBytes,
    required this.uploadedBytes,
    required this.progress,
    required this.status,
    this.error,
  });

  UploadProgress copyWith({
    String? fileName,
    int? totalBytes,
    int? uploadedBytes,
    double? progress,
    UploadStatus? status,
    String? error,
  }) {
    return UploadProgress(
      fileName: fileName ?? this.fileName,
      totalBytes: totalBytes ?? this.totalBytes,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
    fileName,
    totalBytes,
    uploadedBytes,
    progress,
    status,
    error,
  ];
}

/// Upload status enumeration
enum UploadStatus { pending, hashing, uploading, completed, failed, cancelled }

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
