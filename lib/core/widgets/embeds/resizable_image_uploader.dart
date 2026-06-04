import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/file_upload_service.dart';
import '../../services/image_url_service.dart';
import '../../utils/file_validation_utils.dart';
import '../../utils/log_service.dart';
import 'resizable_image_block_embed.dart';

/// 可缩放图片上传工具
///
/// 统一三种入口（工具栏点击 / 粘贴 / 拖入）的上传 + 插入逻辑，
/// 避免逻辑分叉。
class ResizableImageUploader {
  const ResizableImageUploader._();

  static final FileUploadService _uploadService = FileUploadService();

  /// 上传分类名（攻略正文图片）
  static const String categoryName = 'guide_content';

  /// 统计文档中 resizableImage 节点数量
  static int countImages(Document document) {
    final delta = document.toDelta();
    int count = 0;
    for (final op in delta.operations) {
      if (op.isInsert && op.value is Map) {
        final map = op.value as Map;
        if (map.containsKey(resizableImageEmbedType)) {
          count++;
        }
      }
    }
    return count;
  }

  /// 上传文件并在光标位置插入 resizableImage 节点
  ///
  /// 返回上传结果的 fileId 引用（成功）或 null（失败/取消）。
  ///
  /// [onError]、[onSuccess]、[onValidationFail] 为可选反馈回调。
  static Future<String?> uploadAndInsert(
    File file,
    QuillController controller, {
    int maxImages = 100,
    void Function(String message)? onError,
    void Function(String message)? onSuccess,
    void Function(String message)? onLimitReached,
  }) async {
    // 校验文件
    final validation = FileValidationUtils.validateFile(file);
    if (!validation.isValid) {
      onError?.call(validation.errorMessage ?? '文件验证失败');
      return null;
    }

    // 检查数量限制
    if (countImages(controller.document) >= maxImages) {
      onLimitReached?.call('图片数量已达上限（$maxImages 张）');
      return null;
    }

    try {
      final uploadResult = await _uploadService.uploadToImageBed(
        file,
        categoryName: categoryName,
      );

      final imageRef = ImageUrlService.createFileIdRef(uploadResult.fileId);
      final embed = ResizableImageBlockEmbed.create(src: imageRef);

      _insertEmbed(controller, embed);

      onSuccess?.call('图片已插入');
      return imageRef;
    } catch (e) {
      LogService.e('上传图片失败', e);
      onError?.call('上传失败: ${getErrorMessage(e)}');
      return null;
    }
  }

  /// 上传图片字节（来自剪贴板）并插入
  static Future<String?> uploadBytesAndInsert(
    Uint8List bytes,
    QuillController controller, {
    String extension = 'png',
    int maxImages = 100,
    void Function(String message)? onError,
    void Function(String message)? onSuccess,
    void Function(String message)? onLimitReached,
  }) async {
    if (bytes.isEmpty) return null;

    File? tempFile;
    try {
      final tempDir = await getTemporaryDirectory();
      tempFile = File(
        '${tempDir.path}/rte_${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
      await tempFile.writeAsBytes(bytes);

      return await uploadAndInsert(
        tempFile,
        controller,
        maxImages: maxImages,
        onError: onError,
        onSuccess: onSuccess,
        onLimitReached: onLimitReached,
      );
    } catch (e) {
      LogService.e('粘贴图片失败', e);
      onError?.call('粘贴图片失败');
      return null;
    } finally {
      if (tempFile != null) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// 仅上传文件，返回 fileId 引用，不插入文档（用于替换图片场景）
  static Future<String?> uploadFileOnly(
    File file, {
    void Function(String message)? onError,
  }) async {
    final validation = FileValidationUtils.validateFile(file);
    if (!validation.isValid) {
      onError?.call(validation.errorMessage ?? '文件验证失败');
      return null;
    }

    try {
      final uploadResult = await _uploadService.uploadToImageBed(
        file,
        categoryName: categoryName,
      );
      return ImageUrlService.createFileIdRef(uploadResult.fileId);
    } catch (e) {
      LogService.e('上传图片失败', e);
      onError?.call('上传失败: ${getErrorMessage(e)}');
      return null;
    }
  }

  /// 在光标位置插入 embed
  static void _insertEmbed(QuillController controller, BlockEmbed embed) {
    final docLength = controller.document.length;
    int index = controller.selection.baseOffset;
    int length = controller.selection.extentOffset - index;

    // 防御：选区无效时插入到文档末尾
    // （文档末尾保留的 '\n' 占 1 个长度，插入位置取 docLength - 1）
    if (index < 0 || index > docLength) {
      index = docLength > 0 ? docLength - 1 : 0;
      length = 0;
    }

    if (length > 0) {
      controller.replaceText(index, length, embed, null);
    } else {
      controller.document.insert(index, embed);
    }
    controller.updateSelection(
      TextSelection.collapsed(offset: index + 1),
      ChangeSource.local,
    );
  }

  /// 将异常转换为用户友好的错误信息
  static String getErrorMessage(Object error) {
    if (error is FileValidationException) return error.message;
    final errorStr = error.toString();
    if (errorStr.contains('SocketException') ||
        errorStr.contains('NetworkException') ||
        errorStr.contains('Connection')) {
      return '网络连接失败，请检查网络设置';
    }
    if (errorStr.contains('TimeoutException') || errorStr.contains('timeout')) {
      return '请求超时，请稍后重试';
    }
    if (errorStr.contains('401') || errorStr.contains('Unauthorized')) {
      return '未授权，请先登录';
    }
    if (errorStr.contains('403') || errorStr.contains('Forbidden')) {
      return '没有上传权限';
    }
    if (errorStr.contains('500') ||
        errorStr.contains('502') ||
        errorStr.contains('503')) {
      return '服务器错误，请稍后重试';
    }
    return errorStr;
  }
}
