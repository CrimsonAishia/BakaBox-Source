import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter_quill/flutter_quill.dart';

import '../../services/image_url_service.dart';
import '../../utils/log_service.dart';
import '../disk_cached_image.dart';
import '../image_viewer_dialog.dart';
import 'resizable_image_block_embed.dart';
import 'resizable_image_controller.dart';
import 'resizable_image_scope.dart';
import 'resizable_image_snap.dart';
import '../../constants/app_colors.dart';

/// 可缩放图片 Quill EmbedBuilder
///
/// 功能：
/// - 渲染图片（按 width 比例、gridCol 横向定位）
/// - 编辑态：单击选中 → 顶部工具栏（对齐三键、宽度 +/-、替换、删除），双击大图预览
/// - 只读态（详情页）：悬停高亮边框 + 阴影，单击大图预览
///
/// 交互方式仅限「点击」：不支持拖拽移动、不支持鼠标拖拽缩放。
/// 大小调整通过工具栏 +/- 按钮；对齐通过工具栏三键。
///
/// [readOnly] 为 true 时仅渲染（详情页），不显示编辑工具栏。
class ResizableImageEmbedBuilder extends EmbedBuilder {
  final bool readOnly;

  /// 替换图片回调（点击工具栏「替换」时触发，返回新的 fileId 引用或 null）
  final Future<String?> Function()? onReplace;

  const ResizableImageEmbedBuilder({this.readOnly = false, this.onReplace});

  @override
  String get key => resizableImageEmbedType;

  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = ResizableImageBlockEmbed.parseData(
      embedContext.node.value.data as String,
    );

    if (data == null) {
      return const _ResizableImageFallback();
    }

    // 从 scope 获取交互协调器；只读或无 scope 时退化为纯展示
    final scope = ResizableImageScope.maybeOf(context);
    final effectiveReadOnly = readOnly || (scope?.readOnly ?? true);

    return _ResizableImageWidget(
      data: data,
      controller: embedContext.controller,
      node: embedContext.node,
      readOnly: effectiveReadOnly,
      imageController: scope?.controller,
      onReplace: onReplace,
    );
  }
}

/// 可缩放图片渲染 + 交互 Widget
class _ResizableImageWidget extends StatefulWidget {
  final ResizableImageData data;
  final QuillController controller;
  final Embed node;
  final bool readOnly;
  final ResizableImageController? imageController;
  final Future<String?> Function()? onReplace;

  const _ResizableImageWidget({
    required this.data,
    required this.controller,
    required this.node,
    required this.readOnly,
    required this.imageController,
    required this.onReplace,
  });

  @override
  State<_ResizableImageWidget> createState() => _ResizableImageWidgetState();
}

class _ResizableImageWidgetState extends State<_ResizableImageWidget> {
  String? _signedUrl;
  bool _isLoading = true;
  bool _isHovering = false;

  /// 乐观本地状态：保存最近一次提交的数据。
  ///
  /// flutter_quill 在 `replaceText` 之后不一定会同步用新数据重建 embed，
  /// 因此 `widget.data` 可能短暂滞后于真实值。若直接读取 `widget.data`，
  /// 会导致「改对齐时大小被还原」等问题。所有显示与操作都走 [_effectiveData]。
  ResizableImageData? _pendingData;

  /// 当前生效数据：优先用本地乐观值，其次实时解析文档节点，最后退回 build 时的值。
  ResizableImageData get _effectiveData {
    if (_pendingData != null) return _pendingData!;
    return _parseLiveData() ?? widget.data;
  }

  /// 实时从文档节点解析最新数据（防止 widget.data 滞后）
  ResizableImageData? _parseLiveData() {
    try {
      final raw = widget.node.value.data;
      if (raw is String) {
        return ResizableImageBlockEmbed.parseData(raw);
      }
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
    widget.imageController?.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(_ResizableImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.src != widget.data.src) {
      _loadSignedUrl();
    }
    // 同步乐观状态：
    // - 文档已追上本地值（相等）→ 清除 pending；
    // - 发生了外部变更（与上一帧 data 不同，如撤销）→ 采用新数据，清除 pending。
    if (_pendingData != null) {
      if (_sameData(widget.data, _pendingData!) ||
          !_sameData(widget.data, oldWidget.data)) {
        _pendingData = null;
      }
    }
    if (oldWidget.imageController != widget.imageController) {
      oldWidget.imageController?.removeListener(_onControllerChanged);
      widget.imageController?.addListener(_onControllerChanged);
    }
  }

  /// 比较两份图片数据的关键字段是否一致
  bool _sameData(ResizableImageData a, ResizableImageData b) {
    return a.src == b.src &&
        a.width == b.width &&
        a.gridCol == b.gridCol &&
        a.caption == b.caption &&
        a.alt == b.alt &&
        a.gridFloat == b.gridFloat;
  }

  @override
  void dispose() {
    widget.imageController?.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  /// 当前节点在文档中的偏移（每次实时获取，避免文档变更后失效）
  int? get _documentOffset {
    try {
      return widget.node.documentOffset;
    } catch (_) {
      return null;
    }
  }

  bool get _isSelected {
    final offset = _documentOffset;
    if (offset == null) return false;
    return widget.imageController?.isSelected(offset) ?? false;
  }

  Future<void> _loadSignedUrl() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final url = await ImageUrlService.instance.getSignedUrl(widget.data.src);
      if (mounted) {
        setState(() {
          _signedUrl = url;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleTap() {
    if (widget.readOnly) return;
    final offset = _documentOffset;
    if (offset == null) return;
    final ctrl = widget.imageController;
    if (ctrl == null) return;
    if (ctrl.isSelected(offset)) {
      ctrl.clearSelection();
    } else {
      ctrl.select(offset);
    }
  }

  void _handleDoubleTap() {
    if (_signedUrl == null) return;
    ImageViewerDialog.show(context, imageUrls: [_signedUrl!], initialIndex: 0);
  }

  // ─── 文档变更 ─────────────────────────────────────────────────────────

  /// 将新的图片数据写回文档
  void _commitData(ResizableImageData newData) {
    final offset = _documentOffset;
    if (offset == null) return;

    // 先乐观更新本地状态，保证 UI 立刻反映、且下一次操作基于最新值，
    // 避免 flutter_quill embed 重建滞后导致的「改对齐丢失大小」。
    setState(() => _pendingData = newData);

    final embed = ResizableImageBlockEmbed(newData.toJson());
    try {
      // 用新 embed 替换当前 1 长度的 embed 节点
      widget.controller.replaceText(
        offset,
        1,
        embed,
        TextSelection.collapsed(offset: offset + 1),
      );
      // 替换后节点 offset 不变，保持选中
      widget.imageController?.select(offset);
    } catch (e) {
      LogService.e('更新图片数据失败', e);
    }
  }

  void _deleteImage() {
    final offset = _documentOffset;
    if (offset == null) return;
    try {
      widget.controller.replaceText(
        offset,
        1,
        '',
        TextSelection.collapsed(offset: offset),
      );
      widget.imageController?.clearSelection();
    } catch (e) {
      LogService.e('删除图片失败', e);
    }
  }

  Future<void> _replaceImage() async {
    if (widget.onReplace == null) return;
    final newSrc = await widget.onReplace!.call();
    if (newSrc == null) return;
    _commitData(_effectiveData.copyWith(src: newSrc));
  }

  /// 设置对齐方式（仅改 gridCol，保留当前 width —— 修复改对齐恢复大小的问题）
  void _setAlign(int align) {
    final data = _effectiveData;
    final widthCols = ResizableImageSnap.widthToCols(data.width);
    final gridCol = ResizableImageSnap.alignToGridCol(align, widthCols);
    if (gridCol == data.gridCol) return;
    _commitData(data.copyWith(gridCol: gridCol));
  }

  /// 通过 +/- 按钮调整宽度（点击式，保持当前对齐意图）
  void _stepWidth({required bool increase}) {
    final data = _effectiveData;
    final next = ResizableImageSnap.nextSnapPoint(
      data.width,
      increase: increase,
    );
    if ((next - data.width).abs() < 0.001) return;

    final widthCols = ResizableImageSnap.widthToCols(next);
    // 保持当前对齐，重新计算 gridCol 以防越界
    final align = ResizableImageSnap.gridColToAlign(
      data.gridCol,
      ResizableImageSnap.widthToCols(data.width),
    );
    final gridCol = align >= 0
        ? ResizableImageSnap.alignToGridCol(align, widthCols)
        : data.gridCol.clamp(0, ResizableImageSnap.gridColumns - widthCols);
    _commitData(data.copyWith(width: next, gridCol: gridCol));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final parentWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        final data = _effectiveData;

        // 大小：仅由 width 决定，与对齐完全无关。
        final widthFactor = data.width.clamp(0.2, 1.0);
        final imageWidth = parentWidth * widthFactor;

        // 对齐：把 gridCol 映射为 -1(左) ~ 0(中) ~ 1(右) 的水平对齐，
        // 完全独立于宽度，不再用像素偏移计算（避免大小被对齐影响）。
        final widthCols = ResizableImageSnap.widthToCols(widthFactor);
        final maxCol = ResizableImageSnap.gridColumns - widthCols;
        final clampedCol = maxCol <= 0 ? 0 : data.gridCol.clamp(0, maxCol);
        final alignX = maxCol <= 0 ? 0.0 : (clampedCol / maxCol) * 2 - 1;

        final selected = _isSelected && !widget.readOnly;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            cursor: widget.readOnly
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 图片本体：按对齐放置，宽度独立
                Align(
                  alignment: Alignment(alignX, 0),
                  child: SizedBox(
                    width: imageWidth,
                    child: _buildImageBody(isDark, selected),
                  ),
                ),
                // 顶部工具栏：跟随图片的左/中/右对齐，同时限制在整行宽度内，
                // 既跟着图片走，又保证按钮始终可点（不会被挤出编辑区）。
                if (selected)
                  Positioned(
                    top: -2,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment(alignX, 0),
                      child: _buildToolbar(isDark, widthFactor),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageBody(bool isDark, bool selected) {
    final showHoverHighlight =
        (selected || _isHovering) && (!widget.readOnly || _isHovering);

    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: showHoverHighlight
            ? Border.all(
                color: AppColors.primary,
                width: selected || _isHovering ? 2 : 1,
              )
            : Border.all(color: Colors.transparent, width: 2),
        boxShadow: widget.readOnly && _isHovering
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildImage(isDark),
                if (_effectiveData.caption.isNotEmpty) _buildCaption(isDark),
              ],
            ),
            // 只读模式下 hover 时显示的「点击预览」遮罩提示
            if (widget.readOnly)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _isHovering ? 1.0 : 0.0,
                    child: _buildPreviewHoverOverlay(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (widget.readOnly) {
      // 只读：单击预览（光标已由外层 MouseRegion 设置为 click）
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleDoubleTap,
        child: body,
      );
    }

    // 可编辑：单击选中、双击预览（不支持任何拖拽）
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onDoubleTap: _handleDoubleTap,
        child: body,
      ),
    );
  }

  /// 只读态下 hover 时显示的「点击预览」遮罩（参考 _FileIdImage 风格）
  Widget _buildPreviewHoverOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: Icon(
        Icons.zoom_in,
        size: 32,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }

  Widget _buildImage(bool isDark) {
    if (_isLoading) {
      return _buildImagePlaceholder(isDark);
    }
    if (_signedUrl == null) {
      return const _ResizableImageFallback();
    }
    return DiskCachedImage(
      imageUrl: _signedUrl!,
      fit: BoxFit.contain,
      placeholder: _buildImagePlaceholder(isDark),
      errorWidget: const _ResizableImageFallback(),
    );
  }

  Widget _buildImagePlaceholder(bool isDark) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: isDark ? AppColors.slate700 : AppColors.gray100,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildCaption(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        _effectiveData.caption,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.slate400 : AppColors.gray500,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 顶部工具栏（对齐、宽度、替换、删除）
  Widget _buildToolbar(bool isDark, double widthFactor) {
    final align = ResizableImageSnap.gridColToAlign(
      _effectiveData.gridCol,
      ResizableImageSnap.widthToCols(widthFactor),
    );

    // 用 OverflowBox 让工具栏按内容自适应宽度，避免在 Quill 行布局给出的
    // 无限高度约束下取最大高度导致崩溃（OverflowBoxFit.deferToChild）。
    return OverflowBox(
      fit: OverflowBoxFit.deferToChild,
      minWidth: 0,
      maxWidth: double.infinity,
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate800 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toolbarBtn(
                icon: Icons.format_align_left_rounded,
                tooltip: '左对齐',
                active: align == 0,
                isDark: isDark,
                onTap: () => _setAlign(0),
              ),
              _toolbarBtn(
                icon: Icons.format_align_center_rounded,
                tooltip: '居中',
                active: align == 1,
                isDark: isDark,
                onTap: () => _setAlign(1),
              ),
              _toolbarBtn(
                icon: Icons.format_align_right_rounded,
                tooltip: '右对齐',
                active: align == 2,
                isDark: isDark,
                onTap: () => _setAlign(2),
              ),
              _toolbarDivider(isDark),
              _toolbarBtn(
                icon: Icons.remove_rounded,
                tooltip: '缩小',
                active: false,
                isDark: isDark,
                enabled: widthFactor > ResizableImageSnap.minWidth + 0.001,
                onTap: () => _stepWidth(increase: false),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 38),
                alignment: Alignment.center,
                child: Text(
                  ResizableImageSnap.formatPercent(widthFactor),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.slate200 : AppColors.gray700,
                  ),
                ),
              ),
              _toolbarBtn(
                icon: Icons.add_rounded,
                tooltip: '放大',
                active: false,
                isDark: isDark,
                enabled: widthFactor < ResizableImageSnap.maxWidth - 0.001,
                onTap: () => _stepWidth(increase: true),
              ),
              if (widget.onReplace != null) ...[
                _toolbarDivider(isDark),
                _toolbarBtn(
                  icon: Icons.swap_horiz_rounded,
                  tooltip: '替换',
                  active: false,
                  isDark: isDark,
                  onTap: _replaceImage,
                ),
              ],
              _toolbarDivider(isDark),
              _toolbarBtn(
                icon: Icons.delete_outline_rounded,
                tooltip: '删除',
                active: false,
                isDark: isDark,
                danger: true,
                onTap: _deleteImage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbarBtn({
    required IconData icon,
    required String tooltip,
    required bool active,
    required bool isDark,
    required VoidCallback onTap,
    bool enabled = true,
    bool danger = false,
  }) {
    final Color iconColor;
    if (!enabled) {
      iconColor = isDark ? AppColors.slate600 : AppColors.gray300;
    } else if (danger) {
      iconColor = AppColors.red600;
    } else if (active) {
      iconColor = Colors.white;
    } else {
      iconColor = isDark ? AppColors.slate400 : AppColors.slate500;
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 15, color: iconColor),
        ),
      ),
    );
  }

  Widget _toolbarDivider(bool isDark) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      color: isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.gray200,
    );
  }
}

/// 加载失败时的兜底 Widget
class _ResizableImageFallback extends StatelessWidget {
  const _ResizableImageFallback();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate700 : AppColors.gray100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.gray200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 20,
            color: isDark ? AppColors.slate500 : AppColors.gray400,
          ),
          const SizedBox(width: 8),
          Text(
            '图片加载失败',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.slate500 : AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }
}
