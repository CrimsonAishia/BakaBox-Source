import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:file_picker/file_picker.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import '../services/file_upload_service.dart';
import '../services/draft_service.dart';
import '../services/image_url_service.dart';
import '../models/upload_models.dart';
import '../utils/file_validation_utils.dart';
import '../utils/log_service.dart';
import '../utils/toast_utils.dart';
import 'embeds/color_picker_button.dart';
import 'embeds/divider_embed_builder.dart';
import 'embeds/divider_insert_button.dart';
import 'embeds/hover_info_embed_builder.dart';
import 'embeds/resizable_image_block_embed.dart';
import 'embeds/resizable_image_controller.dart';
import 'embeds/resizable_image_embed_builder.dart';
import 'embeds/resizable_image_scope.dart';
import 'embeds/resizable_image_uploader.dart';
import 'image_viewer_dialog.dart';
import '../constants/app_colors.dart';

/// 图片处理模式
enum ImageMode {
  /// 附件模式：图片上传后显示在编辑器下方的附件区域（评论场景）
  attachment,

  /// 内联模式：图片上传后直接在 Quill Document 当前光标位置插入 {"image":"fileId://..."} 节点（攻略场景）
  inline,
}

/// 富文本编辑器组件（基于 flutter_quill）
///
/// 图片处理方式由 [imageMode] 控制：
/// - [ImageMode.attachment]（默认）：图片上传后显示在编辑器下方的附件区域（评论场景）
/// - [ImageMode.inline]：图片上传后直接在 Quill Document 当前光标位置插入节点（攻略场景）
///
/// 通过 [embedBuilders] 可注入自定义 Embed 渲染器（如 B 站视频卡片）。
/// 通过 [extraToolbarButtons] 可在工具栏末尾追加自定义按钮。
/// 通过 [enableHeading] 可控制 Toolbar 是否显示 H1/H2/H3 独立按钮。
///
/// [enableAdvancedEmbeds] 为 true 时（仅攻略正文场景）：
/// - 工具栏显示「插入图片」按钮
/// - 支持粘贴/拖入图片
/// - 注册 resizableImage embed
/// - 文档加载时迁移旧 image 节点
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

  /// 自定义 Embed 渲染器列表（如 BilibiliEmbedBuilder）
  final List<EmbedBuilder>? embedBuilders;

  /// 追加到工具栏末尾的自定义按钮
  final List<Widget>? extraToolbarButtons;

  /// 是否在 Toolbar 显示 H1/H2/H3 独立按钮（默认 false，使用下拉选择）
  /// 启用时 header 节点同步生成 headerId 用于 TOC 锚点
  final bool enableHeading;

  /// 图片处理模式（默认 attachment，保持现有附件区行为）
  final ImageMode imageMode;

  /// 是否启用高级 Embed 功能（默认 false，仅攻略正文启用）
  ///
  /// 启用时：工具栏图片按钮、粘贴/拖入图片、resizableImage 渲染、
  /// 旧 image 节点迁移均生效。
  /// 禁用时：保持现有行为不变，不影响 Issue/评论场景。
  final bool enableAdvancedEmbeds;

  /// 工具栏图标尺寸（默认 16）
  final double toolbarIconSize;

  /// 工具栏按钮尺寸（默认 32）
  final double toolbarButtonSize;

  const RichTextEditor({
    super.key,
    required this.controller,
    this.hintText = '输入内容...',
    this.maxLength = 2000,
    this.maxImages = 8,
    this.compactMode = false,
    this.draftId,
    this.enableDraftManualSave = true,
    this.onImagesChanged,
    this.onSubmit,
    this.minHeight,
    this.embedBuilders,
    this.extraToolbarButtons,
    this.enableHeading = false,
    this.imageMode = ImageMode.attachment,
    this.enableAdvancedEmbeds = false,
    this.toolbarIconSize = 16,
    this.toolbarButtonSize = 32,
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

  /// headerId 计数器（enableHeading=true 时使用，用于 TOC 锚点）
  int _headerIdCounter = 0;

  /// 可缩放图片选中协调器（仅 enableAdvancedEmbeds 时使用）
  late final ResizableImageController _imageController =
      ResizableImageController();

  /// 清空所有附件图片
  void clearImages() {
    setState(() {
      _uploadedImages.clear();
    });
    _notifyImagesChanged();
  }

  /// 获取当前图片列表
  List<String> get imageUrls => _uploadedImages.map((img) => img.url).toList();

  /// 获取文档中 resizableImage 的数量（供外部调用）
  int getResizableImageCount() {
    return _countResizableImages(widget.controller.document);
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
    // 当编辑器文本光标移动到非选中图片处时，取消图片选中态
    if (widget.enableAdvancedEmbeds) {
      _syncImageSelectionWithCaret();
    }
  }

  /// 同步图片选中态与文本光标
  ///
  /// 用户点击正文其它位置或开始输入时，光标会移动，
  /// 此时应取消图片的选中外框，避免「幽灵选中」。
  void _syncImageSelectionWithCaret() {
    final selectedOffset = _imageController.selectedOffset;
    if (selectedOffset == null) return;

    final sel = widget.controller.selection;
    if (!sel.isValid) return;
    // 选中后短时间内处于保护期，避免 Quill 自身移动光标导致误取消
    if (_imageController.isInSelectionGuard) return;
    // 选中图片时，约定光标位于 image 之后（offset+1）或正好在 image 上。
    // 若光标不在 [selectedOffset, selectedOffset+1] 区间，则取消选中。
    final base = sel.baseOffset;
    if (base != selectedOffset && base != selectedOffset + 1) {
      _imageController.clearSelection();
    }
  }

  /// 统计文档中 resizableImage 节点数量
  int _countResizableImages(Document document) {
    int count = 0;
    final delta = document.toDelta();
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

  String _getPlainText() => widget.controller.document.toPlainText();
  int _getTextLength() => _getPlainText().trim().length;

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _scrollController.dispose();
    _draftService.dispose();
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.compactMode) {
      // 在 compactMode 下使用 LayoutBuilder 动态决定是否显示底部栏
      // 避免键盘弹出时 Column 溢出
      return LayoutBuilder(
        builder: (context, constraints) {
          // toolbar 约 44px, bottomBar 约 70px
          // 如果可用高度不足以同时容纳三者，隐藏底部栏
          final showBottomBar = constraints.maxHeight > 180;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildToolbar(context),
              Expanded(child: _buildEditor(context)),
              if (showBottomBar) _buildBottomBar(context, isDark),
            ],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(context),
        // 编辑器区域 - 填充剩余空间
        Expanded(child: _buildEditor(context)),
        // 底部栏（包含附件和状态信息）
        _buildBottomBar(context, isDark),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, bool isDark) {
    final count = _getTextLength();
    final isOverLimit = count > widget.maxLength;
    final isNearLimit = count > (widget.maxLength * 0.9); // 90% 时警告
    final imageCount = _uploadedImages.length;
    final isImageLimit = imageCount >= widget.maxImages;

    // inline 模式下不显示附件区域，仅显示字数统计
    final isInlineMode = widget.imageMode == ImageMode.inline;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 附件区域 + 状态信息
          Row(
            children: [
              // 左侧：添加按钮 + 图片附件列表（仅 attachment 模式）
              if (!isInlineMode)
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
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 6),
                              itemBuilder: (context, index) =>
                                  _ImageAttachmentItem(
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
                )
              else
                const Spacer(),
              const SizedBox(width: 12),
              // 右侧：状态信息
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isInlineMode)
                    _buildStatusChip(
                      icon: Icons.image_rounded,
                      text: '$imageCount/${widget.maxImages}',
                      isWarning: isImageLimit,
                      isDark: isDark,
                    ),
                  if (!isInlineMode) const SizedBox(height: 4),
                  _buildStatusChip(
                    icon: null,
                    text: '$count/${widget.maxLength}',
                    isError: isOverLimit,
                    isWarning: !isOverLimit && isNearLimit,
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
    return _AddImageButton(isDark: isDark, onTap: _handleImageUpload);
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

  Widget _buildStatusChip({
    IconData? icon,
    required String text,
    bool isWarning = false,
    bool isError = false,
    required bool isDark,
  }) {
    Color bgColor, textColor;

    if (isError) {
      bgColor = isDark
          ? AppColors.red600.withValues(alpha: 0.15)
          : const Color(0xFFFEE2E2);
      textColor = AppColors.red600;
    } else if (isWarning) {
      bgColor = isDark
          ? AppColors.amber500.withValues(alpha: 0.15)
          : const Color(0xFFFEF3C7);
      textColor = AppColors.amber500;
    } else {
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : AppColors.gray100;
      textColor = isDark ? AppColors.slate400 : AppColors.gray500;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: isError
            ? Border.all(color: AppColors.red600.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 攻略专属高级套餐
    final advanced = widget.enableAdvancedEmbeds;

    final items = <Widget>[
      // ─── 基础格式 ─────────────────────────────────────────────
      _buildToolbarButton(
        icon: Icons.format_bold_rounded,
        tooltip: '粗体',
        attribute: Attribute.bold,
        isDark: isDark,
      ),
      _buildToolbarButton(
        icon: Icons.format_italic_rounded,
        tooltip: '斜体',
        attribute: Attribute.italic,
        isDark: isDark,
      ),
      if (!widget.compactMode) ...[
        _buildToolbarButton(
          icon: Icons.format_underline_rounded,
          tooltip: '下划线',
          attribute: Attribute.underline,
          isDark: isDark,
        ),
        _buildToolbarButton(
          icon: Icons.format_strikethrough_rounded,
          tooltip: '删除线',
          attribute: Attribute.strikeThrough,
          isDark: isDark,
        ),
      ],
      // 攻略专属：行内代码
      if (advanced) ...[
        _buildToolbarButton(
          icon: Icons.code_rounded,
          tooltip: '行内代码',
          attribute: Attribute.inlineCode,
          isDark: isDark,
        ),
      ],
      // 攻略专属：颜色（文字色 / 背景色）
      if (advanced) ...[
        _buildDivider(isDark),
        ColorPickerButton(controller: widget.controller, isBackground: false),
        ColorPickerButton(controller: widget.controller, isBackground: true),
      ],
      _buildDivider(isDark),
      // ─── Heading ─────────────────────────────────────────────
      if (widget.enableHeading) ...[
        _buildHeadingButton(level: 1, isDark: isDark),
        _buildHeadingButton(level: 2, isDark: isDark),
        _buildHeadingButton(level: 3, isDark: isDark),
      ] else
        QuillToolbarSelectHeaderStyleDropdownButton(
          controller: widget.controller,
          options: QuillToolbarSelectHeaderStyleDropdownButtonOptions(
            iconSize: widget.toolbarIconSize,
            iconButtonFactor: 1.0,
            iconTheme: _getDropdownIconTheme(isDark),
          ),
        ),
      // 攻略专属：字号、字体、行高 下拉
      if (advanced) ...[
        QuillToolbarFontSizeButton(
          controller: widget.controller,
          options: QuillToolbarFontSizeButtonOptions(
            tooltip: '字号',
            iconSize: widget.toolbarIconSize,
            iconButtonFactor: 1.0,
            defaultDisplayText: '字号',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.slate200
                  : AppColors.slate700,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            items: const {
              '默认': '0',
              '12': '12',
              '14': '14',
              '16': '16',
              '18': '18',
              '20': '20',
              '24': '24',
              '28': '28',
              '32': '32',
              '36': '36',
              '48': '48',
            },
          ),
        ),
        QuillToolbarFontFamilyButton(
          controller: widget.controller,
          options: QuillToolbarFontFamilyButtonOptions(
            tooltip: '字体',
            iconSize: widget.toolbarIconSize,
            iconButtonFactor: 1.0,
            iconTheme: _getDropdownIconTheme(isDark),
            defaultDisplayText: '字体',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.slate200
                  : AppColors.slate700,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            items: const {
              '默认': 'Clear',
              '宋体': 'SimSun',
              '黑体': 'SimHei',
              '楷体': 'KaiTi',
              '仿宋': 'FangSong',
              '微软雅黑': 'Microsoft YaHei',
            },
          ),
        ),
      ],
      _buildDivider(isDark),
      // ─── 列表 ─────────────────────────────────────────────────
      _buildToolbarButton(
        icon: Icons.format_list_bulleted_rounded,
        tooltip: '无序列表',
        attribute: Attribute.ul,
        isDark: isDark,
      ),
      _buildToolbarButton(
        icon: Icons.format_list_numbered_rounded,
        tooltip: '有序列表',
        attribute: Attribute.ol,
        isDark: isDark,
      ),
      // 攻略专属：任务列表、缩进、对齐
      if (advanced) ...[
        QuillToolbarToggleCheckListButton(
          controller: widget.controller,
          options: QuillToolbarToggleCheckListButtonOptions(
            iconData: Icons.checklist_rounded,
            tooltip: '任务列表',
            iconSize: widget.toolbarIconSize,
            iconButtonFactor: 1.0,
            iconTheme: _getIconTheme(isDark),
          ),
        ),
        _buildDivider(isDark),
        QuillToolbarIndentButton(
          controller: widget.controller,
          isIncrease: true,
          options: QuillToolbarIndentButtonOptions(
            iconData: Icons.format_indent_increase_rounded,
            tooltip: '增加缩进',
            iconSize: widget.toolbarIconSize,
            iconButtonFactor: 1.0,
            iconTheme: _getIconTheme(isDark),
          ),
        ),
        QuillToolbarIndentButton(
          controller: widget.controller,
          isIncrease: false,
          options: QuillToolbarIndentButtonOptions(
            iconData: Icons.format_indent_decrease_rounded,
            tooltip: '减少缩进',
            iconSize: widget.toolbarIconSize,
            iconButtonFactor: 1.0,
            iconTheme: _getIconTheme(isDark),
          ),
        ),
        _buildDivider(isDark),
        QuillToolbarToggleStyleButton(
          controller: widget.controller,
          attribute: Attribute.leftAlignment,
          options: QuillToolbarToggleStyleButtonOptions(
            iconData: Icons.format_align_left_rounded,
            tooltip: '左对齐',
            iconSize: widget.toolbarIconSize,
            iconTheme: _getIconTheme(isDark),
            iconButtonFactor: 1.0,
          ),
        ),
        QuillToolbarToggleStyleButton(
          controller: widget.controller,
          attribute: Attribute.centerAlignment,
          options: QuillToolbarToggleStyleButtonOptions(
            iconData: Icons.format_align_center_rounded,
            tooltip: '居中',
            iconSize: widget.toolbarIconSize,
            iconTheme: _getIconTheme(isDark),
            iconButtonFactor: 1.0,
          ),
        ),
        QuillToolbarToggleStyleButton(
          controller: widget.controller,
          attribute: Attribute.rightAlignment,
          options: QuillToolbarToggleStyleButtonOptions(
            iconData: Icons.format_align_right_rounded,
            tooltip: '右对齐',
            iconSize: widget.toolbarIconSize,
            iconTheme: _getIconTheme(isDark),
            iconButtonFactor: 1.0,
          ),
        ),
      ],
      // ─── 块级、链接、其它 ─────────────────────────────────────
      if (!widget.compactMode) ...[
        _buildDivider(isDark),
        _buildToolbarButton(
          icon: Icons.format_quote_rounded,
          tooltip: '引用',
          attribute: Attribute.blockQuote,
          isDark: isDark,
        ),
        _buildToolbarButton(
          icon: Icons.data_object_rounded,
          tooltip: '代码块',
          attribute: Attribute.codeBlock,
          isDark: isDark,
        ),
        _buildDivider(isDark),
        QuillToolbarLinkStyleButton(
          controller: widget.controller,
          options: QuillToolbarLinkStyleButtonOptions(
            iconSize: widget.toolbarIconSize,
            iconButtonFactor: 1.0,
            iconTheme: _getIconTheme(isDark),
          ),
        ),
        if (advanced) ...[
          DividerInsertButton(controller: widget.controller),
          QuillToolbarClearFormatButton(
            controller: widget.controller,
            options: QuillToolbarClearFormatButtonOptions(
              iconData: Icons.format_clear_rounded,
              tooltip: '清除格式',
              iconSize: widget.toolbarIconSize,
              iconButtonFactor: 1.0,
              iconTheme: _getIconTheme(isDark),
            ),
          ),
        ],
        _buildDivider(isDark),
        QuillToolbarHistoryButton(
          controller: widget.controller,
          isUndo: true,
          options: QuillToolbarHistoryButtonOptions(
            iconSize: widget.toolbarIconSize,
            iconButtonFactor: 1.0,
            iconTheme: _getIconTheme(isDark),
          ),
        ),
        QuillToolbarHistoryButton(
          controller: widget.controller,
          isUndo: false,
          options: QuillToolbarHistoryButtonOptions(
            iconSize: widget.toolbarIconSize,
            iconButtonFactor: 1.0,
            iconTheme: _getIconTheme(isDark),
          ),
        ),
      ],
      // 追加自定义工具栏按钮（如插入图片、HoverInfo、B站）
      if (widget.extraToolbarButtons != null &&
          widget.extraToolbarButtons!.isNotEmpty) ...[
        _buildDivider(isDark),
        ...widget.extraToolbarButtons!,
      ],
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.gray200,
        ),
      ),
      // compactMode（移动端/评论）保持单行横向滚动以节省纵向空间；
      // 普通模式（攻略正文等）使用 Wrap，按钮放不下时自动换行显示，避免被滚动隐藏。
      child: widget.compactMode
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: items),
            )
          : Wrap(
              spacing: 0,
              runSpacing: 0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: items,
            ),
    );
  }

  /// 构建独立的 Heading 按钮（H1/H2/H3），enableHeading=true 时使用
  /// 切换 heading 时同步生成 headerId 属性用于 TOC 锚点
  Widget _buildHeadingButton({required int level, required bool isDark}) {
    return _HeadingToggleButton(
      controller: widget.controller,
      level: level,
      isDark: isDark,
      iconTheme: _getIconTheme(isDark),
      iconSize: widget.toolbarIconSize,
      onToggle: () => _ensureHeaderId(level),
    );
  }

  /// 为当前光标所在 header 节点生成 headerId（若尚未有）
  void _ensureHeaderId(int level) {
    final selection = widget.controller.selection;
    final doc = widget.controller.document;
    // 获取当前行的样式
    final lineStyle = doc.collectStyle(selection.baseOffset, 0);
    final headerAttr = lineStyle.attributes[Attribute.header.key];
    if (headerAttr != null && headerAttr.value == level) {
      // 当前已经是该 header 级别，检查是否已有 headerId
      // headerId 通过 custom attribute 存储
      final existingId = lineStyle.attributes['headerId'];
      if (existingId == null) {
        _headerIdCounter++;
        widget.controller.formatSelection(
          Attribute('headerId', AttributeScope.block, 'h-$_headerIdCounter'),
        );
      }
    } else {
      // 正在设置为 header，生成新 headerId
      _headerIdCounter++;
      // 延迟一帧，让 header attribute 先生效
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.controller.formatSelection(
            Attribute('headerId', AttributeScope.block, 'h-$_headerIdCounter'),
          );
        }
      });
    }
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required Attribute attribute,
    required bool isDark,
  }) {
    return QuillToolbarToggleStyleButton(
      controller: widget.controller,
      attribute: attribute,
      options: QuillToolbarToggleStyleButtonOptions(
        iconData: icon,
        tooltip: tooltip,
        iconSize: widget.toolbarIconSize,
        iconTheme: _getIconTheme(isDark),
        iconButtonFactor: 1.0,
      ),
    );
  }

  QuillIconTheme _getIconTheme(bool isDark) {
    return _buildIconTheme(isDark, fixedWidth: true);
  }

  /// 下拉按钮（字号/字体/Heading 下拉/行高）专用：
  /// 不限制宽度，但保留紧凑高度和 hover 反馈。
  QuillIconTheme _getDropdownIconTheme(bool isDark) {
    return _buildIconTheme(isDark, fixedWidth: false);
  }

  QuillIconTheme _buildIconTheme(bool isDark, {required bool fixedWidth}) {
    final btnSize = widget.toolbarButtonSize;
    final constraints = fixedWidth
        ? BoxConstraints(
            minWidth: btnSize,
            maxWidth: btnSize,
            minHeight: btnSize,
            maxHeight: btnSize,
          )
        : BoxConstraints(minHeight: btnSize, maxHeight: btnSize);
    final compactStyle = ButtonStyle(
      padding: WidgetStateProperty.all(EdgeInsets.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFEFF6FF);
        }
        return null;
      }),
    );
    return QuillIconTheme(
      iconButtonUnselectedData: IconButtonData(
        color: isDark ? AppColors.slate400 : AppColors.slate500,
        padding: EdgeInsets.zero,
        constraints: constraints,
        visualDensity: VisualDensity.compact,
        style: compactStyle,
      ),
      iconButtonSelectedData: IconButtonData(
        color: Colors.white,
        padding: EdgeInsets.zero,
        constraints: constraints,
        visualDensity: VisualDensity.compact,
        style: ButtonStyle(
          padding: WidgetStateProperty.all(EdgeInsets.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          backgroundColor: WidgetStateProperty.all(AppColors.primary),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : AppColors.gray200,
    );
  }

  Widget _buildEditor(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 合并 embed builders：传入的 + resizableImage + hoverInfo（enableAdvancedEmbeds 时）
    final List<EmbedBuilder> mergedEmbedBuilders = [
      if (widget.embedBuilders != null) ...widget.embedBuilders!,
      if (widget.enableAdvancedEmbeds) ...[
        ResizableImageEmbedBuilder(
          readOnly: false,
          onReplace: _pickReplacementImage,
        ),
        const HoverInfoEmbedBuilder(),
        const DividerEmbedBuilder(),
      ],
    ];

    Widget editor = Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.gray200,
          ),
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.gray200,
          ),
        ),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: isDark ? AppColors.slate200 : AppColors.gray700,
          fontSize: 15,
          height: 1.7,
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
          minHeight: widget.compactMode ? null : (widget.minHeight ?? 200),
          embedBuilders:
              mergedEmbedBuilders.isNotEmpty ? mergedEmbedBuilders : null,
          customStyles: DefaultStyles(
            paragraph: DefaultTextBlockStyle(
              TextStyle(
                fontSize: 15,
                height: 1.7,
                color: isDark
                    ? AppColors.slate200
                    : AppColors.gray700,
              ),
              HorizontalSpacing.zero,
              const VerticalSpacing(6, 0),
              VerticalSpacing.zero,
              null,
            ),
            placeHolder: DefaultTextBlockStyle(
              TextStyle(
                fontSize: 15,
                height: 1.7,
                color: isDark
                    ? AppColors.slate500
                    : AppColors.gray400,
              ),
              HorizontalSpacing.zero,
              VerticalSpacing.zero,
              VerticalSpacing.zero,
              null,
            ),
            h1: DefaultTextBlockStyle(
              TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.5,
                color: isDark ? Colors.white : AppColors.gray800,
              ),
              HorizontalSpacing.zero,
              const VerticalSpacing(16, 8),
              VerticalSpacing.zero,
              null,
            ),
            h2: DefaultTextBlockStyle(
              TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: isDark ? Colors.white : AppColors.gray800,
              ),
              HorizontalSpacing.zero,
              const VerticalSpacing(12, 6),
              VerticalSpacing.zero,
              null,
            ),
            h3: DefaultTextBlockStyle(
              TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: isDark ? Colors.white : AppColors.gray800,
              ),
              HorizontalSpacing.zero,
              const VerticalSpacing(10, 4),
              VerticalSpacing.zero,
              null,
            ),
            quote: DefaultTextBlockStyle(
              TextStyle(
                fontSize: 15,
                height: 1.6,
                fontStyle: FontStyle.italic,
                color: isDark
                    ? AppColors.slate400
                    : AppColors.gray500,
              ),
              HorizontalSpacing.zero,
              const VerticalSpacing(8, 8),
              VerticalSpacing.zero,
              BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    width: 3,
                  ),
                ),
              ),
            ),
            code: DefaultTextBlockStyle(
              TextStyle(
                fontSize: 13,
                fontFamily: 'Consolas, Monaco, monospace',
                color: isDark
                    ? const Color(0xFFE879F9)
                    : AppColors.red600,
                backgroundColor: isDark
                    ? AppColors.slate700
                    : AppColors.gray100,
              ),
              HorizontalSpacing.zero,
              const VerticalSpacing(8, 8),
              VerticalSpacing.zero,
              BoxDecoration(
                color: isDark
                    ? AppColors.slate700
                    : AppColors.gray50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppColors.gray200,
                ),
              ),
            ),
            lists: DefaultListBlockStyle(
              TextStyle(
                fontSize: 15,
                height: 1.7,
                color: isDark
                    ? AppColors.slate200
                    : AppColors.gray700,
              ),
              HorizontalSpacing.zero,
              const VerticalSpacing(4, 4),
              VerticalSpacing.zero,
              null,
              null,
            ),
            link: TextStyle(
              color: AppColors.primary,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primary.withValues(alpha: 0.5),
            ),
            inlineCode: InlineCodeStyle(
              backgroundColor: isDark
                  ? AppColors.slate700
                  : AppColors.gray100,
              radius: const Radius.circular(4),
              style: TextStyle(
                fontFamily: 'Consolas, Monaco, monospace',
                fontSize: 14,
                color: isDark
                    ? const Color(0xFFE879F9)
                    : AppColors.red600,
              ),
            ),
          ),
        ),
      ),
      ),
    );

    // enableAdvancedEmbeds 时：包裹选中协调 Scope + 拖入支持
    if (widget.enableAdvancedEmbeds) {
      // 1. Scope 提供选中协调器
      Widget scoped = ResizableImageScope(
        controller: _imageController,
        readOnly: false,
        child: editor,
      );

      // 2. DropRegion 支持拖入图片
      return DropRegion(
        formats: const [
          Formats.png,
          Formats.jpeg,
          Formats.gif,
          Formats.webp,
        ],
        onDropOver: (event) {
          // 仅当拖入项包含图片格式时才接受
          final item = event.session.items.isNotEmpty
              ? event.session.items.first
              : null;
          if (item == null) return DropOperation.none;
          final reader = item.dataReader;
          if (reader != null &&
              (reader.canProvide(Formats.png) ||
                  reader.canProvide(Formats.jpeg) ||
                  reader.canProvide(Formats.gif) ||
                  reader.canProvide(Formats.webp))) {
            return DropOperation.copy;
          }
          return DropOperation.none;
        },
        onPerformDrop: (event) async {
          if (event.session.items.isEmpty) return;
          final reader = event.session.items.first.dataReader;
          if (reader == null) return;
          // 尝试读取图片文件
          if (reader.canProvide(Formats.png) ||
              reader.canProvide(Formats.jpeg) ||
              reader.canProvide(Formats.gif) ||
              reader.canProvide(Formats.webp)) {
            await _handleDroppedImage(reader);
          }
        },
        child: scoped,
      );
    }

    return editor;
  }

  /// 选择替换图片（供图片工具栏「替换」按钮调用）
  ///
  /// 返回新的 fileId 引用或 null（取消/失败）。
  Future<String?> _pickReplacementImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;
      final filePath = result.files.first.path;
      if (filePath == null) return null;

      final file = File(filePath);
      final validation = FileValidationUtils.validateFile(file);
      if (!validation.isValid) {
        _showError(validation.errorMessage ?? '文件验证失败');
        return null;
      }

      setState(() {
        _isUploading = true;
        _uploadingFileName = file.path.split('/').last.split('\\').last;
      });

      final ref = await ResizableImageUploader.uploadFileOnly(
        file,
        onError: _showError,
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadingFileName = null;
        });
      }
      return ref;
    } catch (e) {
      LogService.e('替换图片失败', e);
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadingFileName = null;
        });
        _showError('替换图片失败，请重试');
      }
      return null;
    }
  }

  /// 处理拖入的图片文件
  Future<void> _handleDroppedImage(DataReader reader) async {
    try {
      Uint8List? imageData;
      String extension = 'png';

      if (reader.canProvide(Formats.png)) {
        imageData = await _readDataFromReader(reader, Formats.png);
        extension = 'png';
      } else if (reader.canProvide(Formats.jpeg)) {
        imageData = await _readDataFromReader(reader, Formats.jpeg);
        extension = 'jpg';
      } else if (reader.canProvide(Formats.gif)) {
        imageData = await _readDataFromReader(reader, Formats.gif);
        extension = 'gif';
      } else if (reader.canProvide(Formats.webp)) {
        imageData = await _readDataFromReader(reader, Formats.webp);
        extension = 'webp';
      }

      if (imageData == null || imageData.isEmpty) return;

      await _uploadBytes(imageData, extension);
    } catch (e) {
      LogService.e('处理拖入图片失败', e);
      if (mounted) {
        ToastUtils.showError(context, '处理拖入图片失败');
      }
    }
  }

  /// 上传图片字节并插入（拖入 / 粘贴共用）
  Future<void> _uploadBytes(Uint8List bytes, String extension) async {
    if (_isUploading) {
      _showWarning('请等待当前上传完成');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadingFileName = '剪贴板图片';
    });

    await ResizableImageUploader.uploadBytesAndInsert(
      bytes,
      widget.controller,
      extension: extension,
      maxImages: widget.maxImages,
      onError: _showError,
      onSuccess: _showSuccess,
      onLimitReached: _showWarning,
    );

    if (mounted) {
      setState(() {
        _isUploading = false;
        _uploadingFileName = null;
      });
      _focusNode.requestFocus();
    }
  }

  /// 从 DataReader 读取指定格式的数据
  Future<Uint8List?> _readDataFromReader(
    DataReader reader,
    FileFormat format,
  ) async {
    final completer = Completer<Uint8List?>();
    reader.getFile(format, (file) async {
      try {
        final data = await file.readAll();
        if (!completer.isCompleted) completer.complete(data);
      } catch (e) {
        if (!completer.isCompleted) completer.complete(null);
      }
    }, onError: (e) {
      if (!completer.isCompleted) completer.complete(null);
    });
    return completer.future;
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
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

      if (widget.imageMode == ImageMode.inline) {
        // inline 模式：直接在光标位置插入图片节点
        final index = widget.controller.selection.baseOffset;
        widget.controller.document.insert(
          index,
          BlockEmbed.image(imageRef),
        );
        // 将光标移到图片节点之后
        widget.controller.updateSelection(
          TextSelection.collapsed(offset: index + 1),
          ChangeSource.local,
        );

        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadingFileName = null;
          });
        }
        _focusNode.requestFocus();
        _showSuccess('图片已插入');
      } else {
        // attachment 模式：添加到附件区域（现有行为）
        final uploadedImage = UploadedImage(
          url: imageRef,
          thumbnailUrl: uploadResult.cdnUrl,
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
      }
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
      if (mounted) {
        setState(() {
          _signedUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      LogService.d('加载图片签名URL失败: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _isHovering
        ? AppColors.primary
        : (widget.isDark
              ? Colors.white.withValues(alpha: 0.2)
              : AppColors.gray300);

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
            boxShadow: _isHovering
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // 图片内容
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: _isLoading
                    ? Container(
                        color: widget.isDark
                            ? AppColors.slate700
                            : AppColors.gray100,
                        child: const Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
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
                      child: Icon(
                        Icons.zoom_in_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
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
                        color: AppColors.red600,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 10,
                        color: Colors.white,
                      ),
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
      color: widget.isDark ? AppColors.slate700 : AppColors.gray100,
      child: Icon(
        Icons.broken_image_rounded,
        size: 16,
        color: widget.isDark
            ? AppColors.slate500
            : AppColors.gray400,
      ),
    );
  }
}

/// 添加图片按钮（带 hover 效果）
class _AddImageButton extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _AddImageButton({required this.isDark, required this.onTap});

  @override
  State<_AddImageButton> createState() => _AddImageButtonState();
}

class _AddImageButtonState extends State<_AddImageButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = _isHovering
        ? AppColors.primary
        : (widget.isDark
              ? Colors.white.withValues(alpha: 0.2)
              : AppColors.gray300);
    final bgColor = _isHovering
        ? (widget.isDark
              ? AppColors.primary.withValues(alpha: 0.1)
              : const Color(0xFFEFF6FF))
        : (widget.isDark
              ? Colors.white.withValues(alpha: 0.03)
              : AppColors.gray50);
    final iconColor = _isHovering
        ? AppColors.primary
        : (widget.isDark ? AppColors.slate400 : AppColors.gray400);

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
              border: Border.all(
                color: borderColor,
                width: _isHovering ? 2 : 1,
              ),
              color: bgColor,
              boxShadow: _isHovering
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.add_photo_alternate_outlined,
              size: 20,
              color: iconColor,
            ),
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

  const _UploadingImageItem({required this.fileName, required this.isDark});

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
            color: AppColors.primary.withValues(alpha: 0.5),
            width: 1,
          ),
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.1)
              : const Color(0xFFEFF6FF),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Heading 切换按钮（H1/H2/H3 独立按钮）
/// 切换 heading 时触发 [onToggle] 以生成 headerId
class _HeadingToggleButton extends StatelessWidget {
  final QuillController controller;
  final int level;
  final bool isDark;
  final QuillIconTheme iconTheme;
  final VoidCallback onToggle;
  final double iconSize;

  const _HeadingToggleButton({
    required this.controller,
    required this.level,
    required this.isDark,
    required this.iconTheme,
    required this.onToggle,
    this.iconSize = 16,
  });

  Attribute get _headerAttribute {
    switch (level) {
      case 1:
        return Attribute.h1;
      case 2:
        return Attribute.h2;
      case 3:
        return Attribute.h3;
      default:
        return Attribute.h1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return QuillToolbarToggleStyleButton(
      controller: controller,
      attribute: _headerAttribute,
      options: QuillToolbarToggleStyleButtonOptions(
        iconData: _getIcon(),
        tooltip: 'H$level',
        iconSize: iconSize,
        iconTheme: iconTheme,
        iconButtonFactor: 1.0,
        afterButtonPressed: onToggle,
      ),
    );
  }

  IconData _getIcon() {
    switch (level) {
      case 1:
        return Icons.looks_one_rounded;
      case 2:
        return Icons.looks_two_rounded;
      case 3:
        return Icons.looks_3_rounded;
      default:
        return Icons.looks_one_rounded;
    }
  }
}
