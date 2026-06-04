import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../utils/log_service.dart';
import '../../utils/toast_utils.dart';
import 'resizable_image_uploader.dart';
import 'toolbar_icon_button.dart';

/// 工具栏「插入图片」按钮
///
/// 用于攻略编辑器（enableAdvancedEmbeds=true）的工具栏，
/// 点击后选择图片文件 → 校验 → 上传到图床 → 插入 ResizableImageBlockEmbed。
class ImageInsertButton extends StatefulWidget {
  /// Quill 编辑器 Controller
  final QuillController controller;

  /// 最大图片数量
  final int maxImages;

  /// 获取当前文档中的图片数量
  final int Function()? getImageCount;

  const ImageInsertButton({
    super.key,
    required this.controller,
    this.maxImages = 100,
    this.getImageCount,
  });

  @override
  State<ImageInsertButton> createState() => _ImageInsertButtonState();
}

class _ImageInsertButtonState extends State<ImageInsertButton> {
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // 监听文档变化，使按钮的「达上限置灰」状态实时更新
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  int get _currentImageCount =>
      widget.getImageCount?.call() ??
      ResizableImageUploader.countImages(widget.controller.document);
  bool get _isAtLimit => _currentImageCount >= widget.maxImages;

  @override
  Widget build(BuildContext context) {
    return ToolbarIconButton(
      icon: Icons.image_outlined,
      tooltip: _isAtLimit ? '图片数量已达上限（${widget.maxImages} 张）' : '插入图片',
      loading: _isUploading,
      disabled: _isAtLimit,
      onTap: _isUploading || _isAtLimit ? null : _handlePickImage,
    );
  }

  Future<void> _handlePickImage() async {
    if (_isUploading || _isAtLimit) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) return;

      if (mounted) setState(() => _isUploading = true);

      await ResizableImageUploader.uploadAndInsert(
        File(filePath),
        widget.controller,
        maxImages: widget.maxImages,
        onError: (msg) {
          if (mounted) ToastUtils.showError(context, msg);
        },
        onSuccess: (msg) {
          if (mounted) ToastUtils.showSuccess(context, msg);
        },
        onLimitReached: (msg) {
          if (mounted) ToastUtils.showWarning(context, msg);
        },
      );
    } catch (e) {
      LogService.e('选择文件失败', e);
      if (mounted) {
        ToastUtils.showError(context, '选择文件失败，请重试');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
