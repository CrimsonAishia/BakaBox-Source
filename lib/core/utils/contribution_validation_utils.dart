import 'dart:io';

/// 地图贡献验证工具类
///
/// 提供地图名称贡献和背景图片贡献的验证功能
class ContributionValidationUtils {
  /// 地图名称最大长度
  static const int maxNameLength = 50;

  /// 地图名称最小长度
  static const int minNameLength = 2;

  /// 背景图片最大大小（5MB）
  static const int maxBackgroundImageSize = 5 * 1024 * 1024;

  /// 允许的背景图片扩展名（不区分大小写）
  static const List<String> allowedBackgroundExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  /// 允许的字符正则表达式
  /// 允许：中文、英文、数字、空格、常用标点符号
  /// - 基本标点：-_·:：!！()（）
  /// - 带圈数字：①②③④⑤⑥⑦⑧⑨⑩ 等 (U+2460-U+2473)
  /// - 带圈字母和其他符号 (U+24B6-U+24FF)
  static final RegExp _allowedCharsRegex = RegExp(
    r'^[\u4e00-\u9fa5a-zA-Z0-9\s\-_·:：!！()（）\u2460-\u24FF]+$',
  );

  /// 验证地图名称贡献
  ///
  /// 检查名称是否：
  /// - 非空
  /// - 长度在 2-50 字符之间
  /// - 只包含允许的字符
  ///
  /// 参数:
  /// - [name]: 要验证的地图名称
  ///
  /// 返回:
  /// - [ContributionValidationResult]: 包含验证结果和错误消息
  static ContributionValidationResult validateName(String name) {
    // 去除首尾空白后检查
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      return ContributionValidationResult(
        isValid: false,
        errorMessage: '地图名称不能为空',
      );
    }

    if (trimmedName.length < minNameLength) {
      return ContributionValidationResult(
        isValid: false,
        errorMessage: '地图名称不能少于 $minNameLength 个字符',
      );
    }

    if (trimmedName.length > maxNameLength) {
      return ContributionValidationResult(
        isValid: false,
        errorMessage: '地图名称不能超过 $maxNameLength 个字符',
      );
    }

    // 检查是否只包含允许的字符
    if (!_allowedCharsRegex.hasMatch(trimmedName)) {
      return ContributionValidationResult(
        isValid: false,
        errorMessage: '名称包含不支持的特殊字符',
      );
    }

    return ContributionValidationResult(isValid: true);
  }

  /// 实时验证名称（用于输入时的即时反馈）
  ///
  /// 与 validateName 不同，此方法：
  /// - 不检查最小长度（允许用户正在输入）
  /// - 只检查特殊字符和最大长度
  ///
  /// 返回 null 表示当前输入有效，返回字符串表示错误提示
  static String? validateNameRealtime(String name) {
    final trimmedName = name.trim();

    // 空字符串不报错（用户可能还没开始输入）
    if (trimmedName.isEmpty) {
      return null;
    }

    if (trimmedName.length > maxNameLength) {
      return '名称不能超过 $maxNameLength 个字符';
    }

    // 检查是否只包含允许的字符
    if (!_allowedCharsRegex.hasMatch(trimmedName)) {
      return '名称包含不支持的特殊字符';
    }

    return null;
  }

  /// 验证背景图片格式
  ///
  /// 检查文件扩展名是否为 JPG、PNG 或 WebP
  ///
  /// 参数:
  /// - [file]: 要验证的图片文件
  ///
  /// 返回:
  /// - [ContributionValidationResult]: 包含验证结果和错误消息
  static ContributionValidationResult validateImageFormat(File file) {
    final extension = _getFileExtension(file.path);

    if (!allowedBackgroundExtensions.contains(extension)) {
      return ContributionValidationResult(
        isValid: false,
        errorMessage: '不支持的图片格式，请选择 JPG、PNG 或 WebP 格式',
      );
    }

    return ContributionValidationResult(isValid: true);
  }

  /// 验证背景图片大小
  ///
  /// 检查文件大小是否小于 5MB
  ///
  /// 参数:
  /// - [file]: 要验证的图片文件
  ///
  /// 返回:
  /// - [ContributionValidationResult]: 包含验证结果和错误消息
  static ContributionValidationResult validateImageSize(File file) {
    final fileSize = file.lengthSync();

    if (fileSize == 0) {
      return ContributionValidationResult(
        isValid: false,
        errorMessage: '文件为空，请选择有效的图片文件',
      );
    }

    if (fileSize >= maxBackgroundImageSize) {
      final sizeMB = (maxBackgroundImageSize / (1024 * 1024)).toStringAsFixed(
        0,
      );
      return ContributionValidationResult(
        isValid: false,
        errorMessage: '图片大小超过限制（最大 ${sizeMB}MB）',
      );
    }

    return ContributionValidationResult(isValid: true);
  }

  /// 验证背景图片（综合验证）
  ///
  /// 同时验证图片格式和大小
  ///
  /// 参数:
  /// - [file]: 要验证的图片文件
  ///
  /// 返回:
  /// - [ContributionValidationResult]: 包含验证结果和错误消息
  static ContributionValidationResult validateBackgroundImage(File file) {
    // 验证图片格式
    final formatResult = validateImageFormat(file);
    if (!formatResult.isValid) {
      return formatResult;
    }

    // 验证图片大小
    final sizeResult = validateImageSize(file);
    if (!sizeResult.isValid) {
      return sizeResult;
    }

    return ContributionValidationResult(isValid: true);
  }

  /// 从文件路径中提取扩展名（小写）
  static String _getFileExtension(String filePath) {
    final fileName = filePath.split('/').last.split('\\').last;
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return '';
  }
}

/// 贡献验证结果
class ContributionValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ContributionValidationResult({
    required this.isValid,
    this.errorMessage,
  });

  @override
  String toString() {
    if (isValid) {
      return 'ContributionValidationResult(isValid: true)';
    } else {
      return 'ContributionValidationResult(isValid: false, errorMessage: $errorMessage)';
    }
  }
}
