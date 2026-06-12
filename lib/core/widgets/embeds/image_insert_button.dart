import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../constants/app_colors.dart';
import '../../utils/log_service.dart';
import '../../utils/toast_utils.dart';
import '../guide/guide_tokens.dart';
import 'resizable_image_uploader.dart';
import 'toolbar_icon_button.dart';

/// 工具栏「插入图片」按钮
///
/// 点击后弹出菜单，让用户选择图片来源：
/// - 本地图片：选择文件 → 校验 → 上传到图床 → 插入 ResizableImageBlockEmbed
/// - 网络图片：输入链接 → 下载 → 识别格式（保留动图）→ 上传到图床 → 插入
///
/// 用于攻略编辑器（enableAdvancedEmbeds=true）的工具栏。
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
      onTap: _isUploading || _isAtLimit ? null : _showSourceMenu,
    );
  }

  /// 弹出「本地图片 / 网络图片」选择菜单
  Future<void> _showSourceMenu() async {
    if (_isUploading || _isAtLimit) return;

    // 以按钮自身为锚点定位菜单
    final renderBox = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(
          renderBox.size.bottomLeft(Offset.zero),
          ancestor: overlay,
        ),
        renderBox.localToGlobal(
          renderBox.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = await showMenu<_ImageSource>(
      context: context,
      position: position,
      color: isDark ? GuideTokens.dialogBgDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: [
        _buildMenuItem(
          value: _ImageSource.local,
          icon: Icons.folder_open_outlined,
          label: '本地图片',
          isDark: isDark,
        ),
        _buildMenuItem(
          value: _ImageSource.network,
          icon: Icons.link_rounded,
          label: '网络图片',
          isDark: isDark,
        ),
      ],
    );

    if (selected == null || !mounted) return;

    switch (selected) {
      case _ImageSource.local:
        await _handlePickImage();
        break;
      case _ImageSource.network:
        await _handleNetworkImage();
        break;
    }
  }

  PopupMenuItem<_ImageSource> _buildMenuItem({
    required _ImageSource value,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white : GuideTokens.textPrimaryLight;
    return PopupMenuItem<_ImageSource>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 本地图片：选择文件并上传插入
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

  /// 网络图片：输入链接 → 下载 → 上传插入
  Future<void> _handleNetworkImage() async {
    if (_isUploading || _isAtLimit) return;

    final url = await showDialog<String>(
      context: context,
      builder: (_) => const _NetworkImageInputDialog(),
    );
    if (url == null || url.trim().isEmpty || !mounted) return;

    setState(() => _isUploading = true);
    try {
      await ResizableImageUploader.downloadAndInsert(
        url,
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
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}

/// 图片来源
enum _ImageSource { local, network }

/// 网络图片链接输入对话框
class _NetworkImageInputDialog extends StatefulWidget {
  const _NetworkImageInputDialog();

  @override
  State<_NetworkImageInputDialog> createState() =>
      _NetworkImageInputDialogState();
}

class _NetworkImageInputDialogState extends State<_NetworkImageInputDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _error = '请输入图片链接');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      setState(() => _error = '请输入有效的图片链接（http/https）');
      return;
    }
    Navigator.of(context).pop(url);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? GuideTokens.dialogBgDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '插入网络图片',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : GuideTokens.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 输入框
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '粘贴图片链接，例如 https://example.com/image.png',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? GuideTokens.textSecondaryLight
                      : GuideTokens.textTertiaryLight,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.gray50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.gray200,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.gray200,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                errorText: _error,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : GuideTokens.textPrimaryLight,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _handleConfirm(),
            ),
            const SizedBox(height: 8),
            // 提示文字
            Text(
              '支持 PNG / JPG / GIF / WebP，动图将保留动画效果',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? GuideTokens.textSecondaryLight
                    : GuideTokens.textTertiaryLight,
              ),
            ),
            const SizedBox(height: 20),
            // 按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: isDark
                          ? GuideTokens.textTertiaryDark
                          : GuideTokens.textSecondaryLight,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _handleConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('确认插入'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
