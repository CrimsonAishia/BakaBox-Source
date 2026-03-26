import 'dart:io';

/// 文件验证工具类
///
/// 提供文件类型、大小、数量验证功能
class FileValidationUtils {
  /// 允许的图片文件扩展名（不区分大小写）
  static const List<String> allowedImageExtensions = [
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
  ];

  /// 单个文件最大大小（10MB）
  static const int maxFileSize = 10 * 1024 * 1024;

  /// Issue 最大图片数量
  static const int maxImagesForIssue = 8;

  /// 评论最大图片数量
  static const int maxImagesForComment = 5;

  /// 验证文件类型
  ///
  /// 检查文件扩展名是否在允许的图片类型列表中
  ///
  /// 返回:
  /// - [ValidationResult]: 包含验证结果和错误消息
  static ValidationResult validateFileType(File file) {
    final fileName = file.path.split('/').last.split('\\').last;
    final extension = fileName.split('.').last.toLowerCase();

    if (!allowedImageExtensions.contains(extension)) {
      return ValidationResult(
        isValid: false,
        errorMessage: '不支持的文件格式，请选择图片文件（PNG、JPG、GIF、WEBP）',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// 验证文件大小
  ///
  /// 检查文件大小是否超过限制
  ///
  /// 返回:
  /// - [ValidationResult]: 包含验证结果和错误消息
  static ValidationResult validateFileSize(File file) {
    final fileSize = file.lengthSync();

    if (fileSize > maxFileSize) {
      final sizeMB = (maxFileSize / (1024 * 1024)).toStringAsFixed(0);
      return ValidationResult(
        isValid: false,
        errorMessage: '文件大小超过限制（最大 ${sizeMB}MB）',
      );
    }

    if (fileSize == 0) {
      return ValidationResult(isValid: false, errorMessage: '文件为空，请选择有效的文件');
    }

    return ValidationResult(isValid: true);
  }

  /// 验证图片数量
  ///
  /// 检查已上传的图片数量是否超过限制
  ///
  /// 参数:
  /// - [currentCount]: 当前已上传的图片数量
  /// - [isIssue]: 是否为 Issue（true=Issue, false=评论）
  ///
  /// 返回:
  /// - [ValidationResult]: 包含验证结果和错误消息
  static ValidationResult validateImageCount(
    int currentCount, {
    required bool isIssue,
  }) {
    final maxCount = isIssue ? maxImagesForIssue : maxImagesForComment;
    final context = isIssue ? 'Issue' : '评论';

    if (currentCount >= maxCount) {
      return ValidationResult(
        isValid: false,
        errorMessage: '图片数量超过限制（$context 最多 $maxCount 张）',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// 验证文件（综合验证）
  ///
  /// 同时验证文件类型和大小
  ///
  /// 返回:
  /// - [ValidationResult]: 包含验证结果和错误消息
  static ValidationResult validateFile(File file) {
    // 验证文件类型
    final typeResult = validateFileType(file);
    if (!typeResult.isValid) {
      return typeResult;
    }

    // 验证文件大小
    final sizeResult = validateFileSize(file);
    if (!sizeResult.isValid) {
      return sizeResult;
    }

    return ValidationResult(isValid: true);
  }

  /// 格式化文件大小
  ///
  /// 将字节数转换为人类可读的格式
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// 获取文件扩展名
  ///
  /// 从文件路径中提取扩展名（小写）
  static String getFileExtension(String filePath) {
    final fileName = filePath.split('/').last.split('\\').last;
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return '';
  }
}

/// 验证结果
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult({required this.isValid, this.errorMessage});

  @override
  String toString() {
    if (isValid) {
      return 'ValidationResult(isValid: true)';
    } else {
      return 'ValidationResult(isValid: false, errorMessage: $errorMessage)';
    }
  }
}
