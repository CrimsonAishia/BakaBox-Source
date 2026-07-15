import 'dart:io';
import 'dart:async';
import '../api/file_upload_api.dart';
import '../exceptions/app_exception.dart';
import '../models/upload_models.dart';
import '../utils/log_service.dart';
import '../utils/file_validation_utils.dart';

/// 文件上传服务
///
/// 提供文件上传功能，包括：
/// - 重试逻辑
/// - 图床上传
class FileUploadService {
  /// 最大重试次数
  static const int maxRetries = 3;

  /// 重试延迟（指数退避）
  static const Duration initialRetryDelay = Duration(seconds: 1);

  final FileUploadApi _api = FileUploadApi();

  /// 重试操作
  ///
  /// 使用指数退避策略重试操作
  Future<T> _retryOperation<T>(
    Future<T> Function() operation, {
    required String operationName,
  }) async {
    int attempt = 0;
    Duration delay = initialRetryDelay;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;

        if (attempt >= maxRetries) {
          LogService.e('$operationName 失败，已达到最大重试次数', e);
          rethrow;
        }

        LogService.w(
          '$operationName 失败，${delay.inSeconds}秒后重试 ($attempt/$maxRetries)',
        );
        await Future.delayed(delay);

        // 指数退避
        delay *= 2;
      }
    }
  }

  /// 上传图片到图床
  /// - 适用于图片文件
  Future<UploadResult> uploadToImageBed(
    File file, {
    required String categoryName,
  }) async {
    // 验证文件
    final validation = FileValidationUtils.validateFile(file);
    if (!validation.isValid) {
      throw FileValidationException(validation.errorMessage ?? '文件验证失败');
    }

    final fileName = file.path.split('/').last.split('\\').last;
    final fileSize = file.lengthSync();

    try {
      // 读取文件数据
      final fileData = await file.readAsBytes();

      // 上传到图床（带重试）
      final response = await _retryOperation(
        () => _api.uploadToImageBed(
          data: fileData,
          filename: fileName,
          categoryName: categoryName,
        ),
        operationName: '图床上传',
      );

      LogService.i('图床上传成功: $fileName');

      return UploadResult(
        fileId: response.fileId,
        url: response.url,
        cdnUrl: response.url,
        fileName: fileName,
        fileSize: fileSize,
        fileMD5: '', // 图床上传不需要 MD5
      );
    } catch (e) {
      LogService.e('图床上传失败: $fileName', e);
      rethrow;
    }
  }
}

/// 文件验证异常
class FileValidationException implements AppException {
  @override
  final String message;

  FileValidationException(this.message);
}
