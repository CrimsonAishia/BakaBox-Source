import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:file_picker/file_picker.dart';
import '../services/file_upload_service.dart';
import '../services/draft_service.dart';
import '../services/image_url_service.dart';
import '../models/upload_models.dart';
import '../utils/file_validation_utils.dart';
import '../utils/log_service.dart';
import '../utils/toast_utils.dart';
import 'image_viewer_dialog.dart';

/// 富文本编辑器组件（基于 flutter_quill）
/// 
/// 图片处理方式（类似 GitHub）：
/// - 图片上传后显示在编辑器下方的附件区域
/// - 编辑器中不嵌入图片，只保存 fileId 引用
/// - 支持点击预览、删除图片
class RichTextEditor extends StatefulWidget {
  final QuillController controller;
  final String hintText;
  final int maxLength;
  final int maxImages;
  final bool compactMode;
  final String? draftId;
  final bool enableDraftManualSave;
  final Function(List<String> imageUrls)? onImagesChanged;
  final VoidCallback? onSubmit;
  final double? minHeight;

  const RichTextEditor({
    super.key,
    required this.controller,
    this.hintText = '输入内容...',
    this.maxLength = 5000,
    this.maxImages = 5,
    this.compactMode = false,
    this.draftId,
    this.enableDraftManualSave = true,
    this.onImagesChanged,
    this.onSubmit,
    this.minHeight,
  });

  @override
  State<RichTextEditor> createState() => RichTextEditorState();
}

class RichTextEditorState extends State<RichTextEditor> {
  final FileUploadService _uploadService = FileUploadService();
  final DraftService _draftService = DraftService();
  
  /// 已上传的图片列表（存储 fileId 引用格式）
  final List<UploadedImage> _uploadedImages = [];
  
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  bool _isUploading = false;
  String? _uploadingFileName;

  /// 清空所有附件图片
  void clearImages() {
    setState(() {
      _uploadedImages.clear();
    });
    _notifyImagesChanged();
  }

  /// 获取当前图片列表
  List<String> get imageUrls => _uploadedImages.map((img) => img.url).toList();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }
  
  void _onTextChanged() {
    if (mounted) setState(() {});
  }
  
  String _getPlainText() => widget.controller.document.toPlainText();
  int _getTextLength() => _getPlainText().trim().length;

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _scrollController.dispose();
    _draftService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(context),
        // 编辑器区域
        Expanded(child: _buildEditor(context)),
        // 底部栏（包含附件和状态信息，固定高度）
        _buildBottomBar(context, isDark),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, bool isDark) {
    final count = _getTextLength();
    final isOverLimit = count > widget.maxLength;
    final imageCount = _uploadedImages.length;
    final isImageLimit = imageCount >= widget.maxImages;
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 附件区域 + 状态信息
          Row(
            children: [
              // 左侧：添加按钮 + 图片附件列表
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      // 添加图片按钮（未达上限时显示，放在最左边）
                      if (!isImageLimit && !_isUploading) ...[
                        _buildAddImageButton(isDark),
                        if (_uploadedImages.isNotEmpty || _isUploading)
                          const SizedBox(width: 8),
                      ],
                      // 上传中的占位项
                      if (_isUploading) ...[
                        _UploadingImageItem(
                          fileName: _uploadingFileName ?? '',
                          isDark: isDark,
                        ),
                        if (_uploadedImages.isNotEmpty)
                          const SizedBox(width: 6),
                      ],
                      // 已上传的图片
                      if (_uploadedImages.isNotEmpty)
                        Expanded(
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _uploadedImages.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 6),
                            itemBuilder: (context, index) => _ImageAttachmentItem(
                              image: _uploadedImages[index],
                              isDark: isDark,
                              onTap: () => _previewImage(index),
                              onDelete: () => _removeImage(index),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 右侧：状态信息
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusChip(
                    icon: Icons.image_rounded, 
                    text: '$imageCount/${widget.maxImages}', 
                    isWarning: isImageLimit, 
                    isDark: isDark,
                  ),
                  const SizedBox(height: 4),
                  _buildStatusChip(
                    icon: null, 
                    text: '$count/${widget.maxLength}', 
                    isError: isOverLimit, 
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 添加图片按钮（带 hover 效果）
  Widget _buildAddImageButton(bool isDark) {
    return _AddImageButton(
      isDark: isDark,
      onTap: _handleImageUpload,
    );
  }

  /// 预览图片
  void _previewImage(int index) async {
    final urls = <String>[];
    for (final img in _uploadedImages) {
      try {
        final url = await ImageUrlService.instance.getSignedUrl(img.url);
        urls.add(url);
      } catch (_) {
        urls.add(img.url);
      }
    }
    if (mounted && urls.isNotEmpty) {
      ImageViewerDialog.show(context, imageUrls: urls, initialIndex: index);
    }
  }

  /// 删除图片
  void _removeImage(int index) {
    if (index < 0 || index >= _uploadedImages.length) return;
    setState(() {
      _uploadedImages.removeAt(index);
    });
    _notifyImagesChanged();
    _showSuccess('图片已删除');
  }
  
  Widget _buildStatusChip({IconData? icon, required String text, bool isWarning = false, bool isError = false, required bool isDark}) {
    Color bgColor, textColor;
    
    if (isError) {
      bgColor = isDark ? const Color(0xFFDC2626).withValues(alpha: 0.15) : const Color(0xFFFEF2F2);
      textColor = const Color(0xFFDC2626);
    } else if (isWarning) {
      bgColor = isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : const Color(0xFFFEF3C7);
      textColor = const Color(0xFFF59E0B);
    } else {
      bgColor = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F4F6);
      textColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: textColor), const SizedBox(width: 6)],
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildToolbarButton(icon: Icons.format_bold_rounded, tooltip: '粗体', attribute: Attribute.bold, isDark: isDark),
            _buildToolbarButton(icon: Icons.format_italic_rounded, tooltip: '斜体', attribute: Attribute.italic, isDark: isDark),
            if (!widget.compactMode) ...[
              _buildToolbarButton(icon: Icons.format_underline_rounded, tooltip: '下划线', attribute: Attribute.underline, isDark: isDark),
              _buildToolbarButton(icon: Icons.format_strikethrough_rounded, tooltip: '删除线', attribute: Attribute.strikeThrough, isDark: isDark),
            ],
            _buildDivider(isDark),
            QuillToolbarSelectHeaderStyleDropdownButton(controller: widget.controller, options: QuillToolbarSelectHeaderStyleDropdownButtonOptions(iconSize: 16, iconTheme: _getIconTheme(isDark))),
            _buildDivider(isDark),
            _buildToolbarButton(icon: Icons.format_list_bulleted_rounded, tooltip: '无序列表', attribute: Attribute.ul, isDark: isDark),
            _buildToolbarButton(icon: Icons.format_list_numbered_rounded, tooltip: '有序列表', attribute: Attribute.ol, isDark: isDark),
            if (!widget.compactMode) ...[
              _buildDivider(isDark),
              _buildToolbarButton(icon: Icons.format_quote_rounded, tooltip: '引用', attribute: Attribute.blockQuote, isDark: isDark),
              _buildToolbarButton(icon: Icons.code_rounded, tooltip: '代码块', attribute: Attribute.codeBlock, isDark: isDark),
              _buildDivider(isDark),
              QuillToolbarLinkStyleButton(controller: widget.controller, options: QuillToolbarLinkStyleButtonOptions(iconSize: 16, iconTheme: _getIconTheme(isDark))),
              _buildDivider(isDark),
              QuillToolbarHistoryButton(controller: widget.controller, isUndo: true, options: QuillToolbarHistoryButtonOptions(iconSize: 16, iconTheme: _getIconTheme(isDark))),
              QuillToolbarHistoryButton(controller: widget.controller, isUndo: false, options: QuillToolbarHistoryButtonOptions(iconSize: 16, iconTheme: _getIconTheme(isDark))),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildToolbarButton({required IconData icon, required String tooltip, required Attribute attribute, required bool isDark}) {
    return QuillToolbarToggleStyleButton(
      controller: widget.controller,
      attribute: attribute,
      options: QuillToolbarToggleStyleButtonOptions(iconData: icon, tooltip: tooltip, iconSize: 16, iconTheme: _getIconTheme(isDark), iconButtonFactor: 1.2),
    );
  }

  QuillIconTheme _getIconTheme(bool isDark) {
    return QuillIconTheme(
      iconButtonUnselectedData: IconButtonData(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      iconButtonSelectedData: IconButtonData(color: Colors.white, style: ButtonStyle(backgroundColor: WidgetStateProperty.all(const Color(0xFF0080FF)), shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))))),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(width: 1, height: 18, margin: const EdgeInsets.symmetric(horizontal: 4), color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB));
  }

  Widget _buildEditor(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          left: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB)),
          right: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB)),
        ),
      ),
      child: QuillEditor.basic(
        controller: widget.controller,
        focusNode: _focusNode,
        scrollController: _scrollController,
        config: QuillEditorConfig(
          placeholder: widget.hintText,
          padding: const EdgeInsets.all(16),
          autoFocus: false,
          expands: true,
          minHeight: widget.minHeight ?? 200,
          customStyles: DefaultStyles(
            paragraph: DefaultTextBlockStyle(
              TextStyle(fontSize: 15, height: 1.7, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF374151)),
              HorizontalSpacing.zero, const VerticalSpacing(6, 0), VerticalSpacing.zero, null,
            ),
            placeHolder: DefaultTextBlockStyle(
              TextStyle(fontSize: 15, height: 1.7, color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF)),
              HorizontalSpacing.zero, VerticalSpacing.zero, VerticalSpacing.zero, null,
            ),
            h1: DefaultTextBlockStyle(
              TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.5, color: isDark ? Colors.white : const Color(0xFF1F2937)),
              HorizontalSpacing.zero, const VerticalSpacing(16, 8), VerticalSpacing.zero, null,
            ),
            h2: DefaultTextBlockStyle(
              TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.5, color: isDark ? Colors.white : const Color(0xFF1F2937)),
              HorizontalSpacing.zero, const VerticalSpacing(12, 6), VerticalSpacing.zero, null,
            ),
            h3: DefaultTextBlockStyle(
              TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.5, color: isDark ? Colors.white : const Color(0xFF1F2937)),
              HorizontalSpacing.zero, const VerticalSpacing(10, 4), VerticalSpacing.zero, null,
            ),
            quote: DefaultTextBlockStyle(
              TextStyle(fontSize: 15, height: 1.6, fontStyle: FontStyle.italic, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
              HorizontalSpacing.zero, const VerticalSpacing(8, 8), VerticalSpacing.zero,
              BoxDecoration(border: Border(left: BorderSide(color: const Color(0xFF0080FF).withValues(alpha: 0.5), width: 3))),
            ),
            code: DefaultTextBlockStyle(
              TextStyle(fontSize: 13, fontFamily: 'Consolas, Monaco, monospace', color: isDark ? const Color(0xFFE879F9) : const Color(0xFFDC2626), backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6)),
              HorizontalSpacing.zero, const VerticalSpacing(8, 8), VerticalSpacing.zero,
              BoxDecoration(color: isDark ? const Color(0xFF334155) : const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB))),
            ),
            lists: DefaultListBlockStyle(
              TextStyle(fontSize: 15, height: 1.7, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF374151)),
              HorizontalSpacing.zero, const VerticalSpacing(4, 4), VerticalSpacing.zero, null, null,
            ),
            link: TextStyle(color: const Color(0xFF0080FF), decoration: TextDecoration.underline, decorationColor: const Color(0xFF0080FF).withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }

  Future<void> _handleImageUpload() async {
    if (_isUploading) {
      _showWarning('请等待当前上传完成');
      return;
    }
    
    if (_uploadedImages.length >= widget.maxImages) {
      _showError('图片数量已达上限（最多 ${widget.maxImages} 张）');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);
      final validation = FileValidationUtils.validateFile(file);
      
      if (!validation.isValid) {
        _showError(validation.errorMessage ?? '文件验证失败');
        return;
      }

      await _performUpload(file);
    } catch (e) {
      LogService.e('选择文件失败', e);
      _showError('选择文件失败，请重试');
    }
  }

  Future<void> _performUpload(File file) async {
    final fileName = file.path.split('/').last.split('\\').last;
    setState(() {
      _isUploading = true;
      _uploadingFileName = fileName;
    });

    try {
      final uploadResult = await _uploadService.uploadToImageBed(
        file,
        categoryName: 'bakabox_issues',
      );

      // 存储 fileId 引用格式
      final imageRef = ImageUrlService.createFileIdRef(uploadResult.fileId);
      final uploadedImage = UploadedImage(
        url: imageRef,
        thumbnailUrl: uploadResult.cdnUrl, // 临时URL用于预览
        fileSize: uploadResult.fileSize,
        fileName: uploadResult.fileName,
      );

      if (mounted) {
        setState(() {
          _uploadedImages.add(uploadedImage);
          _isUploading = false;
          _uploadingFileName = null;
        });
      }

      _notifyImagesChanged();
      _focusNode.requestFocus();
      _showSuccess('图片上传成功');
    } catch (e) {
      LogService.e('上传失败', e);
      
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadingFileName = null;
        });
      }
      
      _showError('上传失败: ${_getErrorMessage(e)}');
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is FileValidationException) return error.message;
    final errorStr = error.toString();
    if (errorStr.contains('SocketException') || errorStr.contains('NetworkException') || errorStr.contains('Connection')) return '网络连接失败，请检查网络设置';
    if (errorStr.contains('TimeoutException') || errorStr.contains('timeout')) return '请求超时，请稍后重试';
    if (errorStr.contains('401') || errorStr.contains('Unauthorized')) return '未授权，请先登录';
    if (errorStr.contains('403') || errorStr.contains('Forbidden')) return '没有上传权限';
    if (errorStr.contains('500') || errorStr.contains('502') || errorStr.contains('503')) return '服务器错误，请稍后重试';
    return errorStr;
  }

  void _notifyImagesChanged() {
    if (widget.onImagesChanged != null) {
      widget.onImagesChanged!(_uploadedImages.map((img) => img.url).toList());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ToastUtils.showError(context, message);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ToastUtils.showSuccess(context, message);
  }

  void _showWarning(String message) {
    if (!mounted) return;
    ToastUtils.showWarning(context, message);
  }
}

/// 图片附件项组件
class _ImageAttachmentItem extends StatefulWidget {
  final UploadedImage image;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ImageAttachmentItem({
    required this.image,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ImageAttachmentItem> createState() => _ImageAttachmentItemState();
}

class _ImageAttachmentItemState extends State<_ImageAttachmentItem> {
  String? _signedUrl;
  bool _isLoading = true;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  @override
  void didUpdateWidget(_ImageAttachmentItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.url != widget.image.url) {
      _loadSignedUrl();
    }
  }

  Future<void> _loadSignedUrl() async {
    setState(() => _isLoading = true);
    try {
      final url = await ImageUrlService.instance.getSignedUrl(widget.image.url);
      if (mounted) setState(() { _signedUrl = url; _isLoading = false; });
    } catch (e) {
      LogService.d('加载图片签名URL失败: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _isHovering 
        ? const Color(0xFF0080FF) 
        : (widget.isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFD1D5DB));
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: _isHovering ? 2 : 1,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
            boxShadow: _isHovering ? [
              BoxShadow(
                color: const Color(0xFF0080FF).withValues(alpha: 0.15),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ] : null,
          ),
          child: Stack(
            children: [
              // 图片内容
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: _isLoading
                    ? Container(
                        color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
                        child: const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0080FF)))),
                      )
                    : _signedUrl != null
                        ? Image.network(
                            _signedUrl!, 
                            fit: BoxFit.cover,
                            width: 48,
                            height: 48,
                            errorBuilder: (_, __, ___) => _buildErrorPlaceholder(),
                          )
                        : _buildErrorPlaceholder(),
              ),
              // Hover 遮罩
              if (_isHovering)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                    child: const Center(
                      child: Icon(Icons.zoom_in_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              // 删除按钮
              if (_isHovering)
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close_rounded, size: 10, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
      child: Icon(Icons.broken_image_rounded, size: 16, color: widget.isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF)),
    );
  }
}

/// 添加图片按钮（带 hover 效果）
class _AddImageButton extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _AddImageButton({
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_AddImageButton> createState() => _AddImageButtonState();
}

class _AddImageButtonState extends State<_AddImageButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = _isHovering 
        ? const Color(0xFF0080FF) 
        : (widget.isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFD1D5DB));
    final bgColor = _isHovering
        ? (widget.isDark ? const Color(0xFF0080FF).withValues(alpha: 0.1) : const Color(0xFFEFF6FF))
        : (widget.isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF9FAFB));
    final iconColor = _isHovering
        ? const Color(0xFF0080FF)
        : (widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF9CA3AF));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: '添加图片',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: _isHovering ? 2 : 1),
              color: bgColor,
              boxShadow: _isHovering ? [
                BoxShadow(color: const Color(0xFF0080FF).withValues(alpha: 0.15), blurRadius: 8),
              ] : null,
            ),
            child: Icon(Icons.add_photo_alternate_outlined, size: 20, color: iconColor),
          ),
        ),
      ),
    );
  }
}

/// 上传中的图片占位组件
class _UploadingImageItem extends StatelessWidget {
  final String fileName;
  final bool isDark;

  const _UploadingImageItem({
    required this.fileName,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '上传中: $fileName',
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF0080FF).withValues(alpha: 0.5),
            width: 1,
          ),
          color: isDark
              ? const Color(0xFF0080FF).withValues(alpha: 0.1)
              : const Color(0xFFEFF6FF),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF0080FF),
            ),
          ),
        ),
      ),
    );
  }
}
