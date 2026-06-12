// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import 'package:flutter/foundation.dart';
import '../models/upload_models.dart';

class FileUrlResponse {
  final String url;
  FileUrlResponse({required this.url});
  factory FileUrlResponse.fromJson(Map<String, dynamic> json) {
    return FileUrlResponse(url: json['url'] as String? ?? '');
  }
}

class FileUploadApi {
  Future<FileUrlResponse> getFileUrl(int fileId) async {
    throw UnimplementedError('Stub');
  }

  Future<InitUploadResponse> initMultipart({
    required String fileName,
    required int fileSize,
    required String fileMD5,
    String? categoryName,
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<PartUploadResponse> uploadPart({
    required String uploadId,
    required int partNumber,
    required String fileKey,
    required Uint8List data,
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<CompleteUploadResponse> completeMultipart({
    required String uploadId,
    required String fileKey,
    required String fileMD5,
    String? categoryName,
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<void> cancelMultipart({
    required String uploadId,
    required String fileKey,
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<ImageBedUploadResponse> uploadToImageBed({
    required Uint8List data,
    required String filename,
    String? categoryName,
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<FileUrlResponse> getImageBedUrl(String path) async {
    throw UnimplementedError('Stub');
  }
}

class ImageBedUploadResponse {
  final int fileId;
  final String url;
  ImageBedUploadResponse({required this.fileId, required this.url});
  factory ImageBedUploadResponse.fromJson(Map<String, dynamic> json) {
    return ImageBedUploadResponse(
      fileId: json['fileId'] as int? ?? 0,
      url: json['url'] as String? ?? '',
    );
  }
}
