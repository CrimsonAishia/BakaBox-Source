import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:path_provider/path_provider.dart';

import '../../api/api_client.dart';
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

  /// 从网络 URL 下载图片并插入
  ///
  /// 下载图片字节后，按文件头自动识别真实格式（保留动图 gif/webp 的动画），
  /// 再走与本地图片一致的「上传到图床 → 插入 resizableImage」流程，
  /// 确保正文图片统一为 fileId 引用，便于签名与缓存。
  ///
  /// 返回 fileId 引用（成功）或 null（失败/取消）。
  static Future<String?> downloadAndInsert(
    String url,
    QuillController controller, {
    int maxImages = 100,
    void Function(String message)? onError,
    void Function(String message)? onSuccess,
    void Function(String message)? onLimitReached,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      onError?.call('请输入图片链接');
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      onError?.call('请输入有效的图片链接（http/https）');
      return null;
    }

    // 数量限制（下载前先判断，避免无谓的网络请求）
    if (countImages(controller.document) >= maxImages) {
      onLimitReached?.call('图片数量已达上限（$maxImages 张）');
      return null;
    }

    File? tempFile;
    try {
      final response = await ApiClient.instance.dio.get<List<int>>(
        trimmed,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        onError?.call('图片下载失败（${response.statusCode}）');
        return null;
      }

      final bytes = Uint8List.fromList(response.data!);
      final extension = _detectImageExtension(bytes);
      if (extension == null) {
        onError?.call('链接内容不是有效的图片');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      tempFile = File(
        '${tempDir.path}/rte_net_${DateTime.now().millisecondsSinceEpoch}.$extension',
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
    } on DioException catch (e) {
      LogService.e('下载网络图片失败', e);
      onError?.call('图片下载失败: ${getErrorMessage(e)}');
      return null;
    } catch (e) {
      LogService.e('插入网络图片失败', e);
      onError?.call('插入网络图片失败: ${getErrorMessage(e)}');
      return null;
    } finally {
      if (tempFile != null) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// 按文件头（魔数）识别图片格式，返回扩展名；非图片返回 null。
  ///
  /// 支持 png / jpg / gif / webp / bmp，动图（gif / 动态 webp）格式被原样保留。
  static String? _detectImageExtension(Uint8List bytes) {
    if (bytes.length < 12) return null;

    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'jpg';
    }
    // GIF: 47 49 46 38 (GIF8)
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return 'gif';
    }
    // WebP: RIFF....WEBP
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    // BMP: 42 4D (BM)
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return 'bmp';
    }
    return null;
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
