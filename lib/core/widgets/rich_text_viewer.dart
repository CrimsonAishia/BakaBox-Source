import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/quill_delta_codec.dart';
import '../services/image_url_service.dart';
import 'disk_cached_image.dart';
import 'image_viewer_dialog.dart';
import 'embeds/divider_embed_builder.dart';
import 'embeds/hover_info_embed_builder.dart';
import 'embeds/resizable_image_embed_builder.dart';
import '../constants/app_colors.dart';
import 'guide/guide_toc_outline.dart';

/// 只读富文本显示组件
///
/// 用于显示 Quill Delta JSON 编码的内容
class RichTextViewer extends StatefulWidget {
  /// Delta JSON 编码的内容
  final String content;

  /// 文本样式（可选）
  final TextStyle? textStyle;

  /// 是否紧凑模式（减少间距）
  final bool compact;

  /// 是否可滚动
  final bool scrollable;

  /// 自定义 Embed 渲染器列表（如 BilibiliEmbedBuilder）
  final List<EmbedBuilder>? embedBuilders;

  /// 是否启用 TOC 切片模式
  ///
  /// 启用后，会按 h1/h2/h3 把正文切成多段独立 [QuillEditor.basic]，
  /// 每个 heading 切片外层挂 [GuideTocHeading.key]，方便外部用
  /// [Scrollable.ensureVisible] 滚动定位。
  ///
  /// 解析得到的 outline 会通过 [onOutlineChanged] 回调向外暴露。
  final bool sliceForToc;

  /// outline 变化回调（仅在 [sliceForToc]=true 时触发）
  final ValueChanged<List<GuideTocHeading>>? onOutlineChanged;

  const RichTextViewer({
    super.key,
    required this.content,
    this.textStyle,
    this.compact = false,
    this.scrollable = true,
    this.embedBuilders,
    this.sliceForToc = false,
    this.onOutlineChanged,
  });

  @override
  State<RichTextViewer> createState() => _RichTextViewerState();
}

class _RichTextViewerState extends State<RichTextViewer> {
  /// 单 editor 模式下的控制器（sliceForToc=false 时使用）
  QuillController? _controller;
  final ScrollController _scrollController = ScrollController();

  /// 切片模式下：每个切片对应一个独立 controller（内部 dispose 时释放）
  final List<QuillController> _sliceControllers = [];

  /// 切片模式产物
  GuideContentSlice? _slice;

  bool? _wasDark;

  @override
  void initState() {
    super.initState();
    // 延迟到 didChangeDependencies 初始化，以获取 Theme 模式
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_wasDark != isDark) {
      _wasDark = isDark;
      _disposeControllers();
      _rebuildContent(isDark);
    }
  }

  @override
  void didUpdateWidget(RichTextViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content ||
        oldWidget.sliceForToc != widget.sliceForToc) {
      _disposeControllers();
      _rebuildContent(
        _wasDark ?? Theme.of(context).brightness == Brightness.dark,
      );
    }
  }

  void _rebuildContent(bool isDark) {
    final adaptedContent = _adaptDeltaJsonColors(widget.content, isDark);

    if (widget.sliceForToc) {
      final slice = GuideTocSlicer.slice(adaptedContent);
      _slice = slice;
      for (final chunk in slice.chunks) {
        _sliceControllers.add(_makeController(chunk.deltaJson));
      }
      // 通知外部 outline（在下一帧避免 build 期间 setState）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onOutlineChanged?.call(slice.outline);
        }
      });
    } else {
      _controller = _makeController(adaptedContent);
    }
  }

  /// 核心动态颜色自适应算法：根据当前亮暗模式和颜色的感知亮度（Luminance/Lightness），动态反转或调整不合时宜的死颜色。
  String _adaptDeltaJsonColors(String content, bool isDark) {
    if (content.trim().isEmpty) return content;
    try {
      final json = jsonDecode(content);
      if (json is List) {
        for (var op in json) {
          if (op is Map && op.containsKey('attributes')) {
            final attrs = op['attributes'];
            if (attrs is Map) {
              if (attrs.containsKey('color')) {
                attrs['color'] = _adaptColorStr(
                  attrs['color'].toString(),
                  isDark,
                  false,
                );
              }
              if (attrs.containsKey('background')) {
                attrs['background'] = _adaptColorStr(
                  attrs['background'].toString(),
                  isDark,
                  true,
                );
              }
            }
          }
        }
        return jsonEncode(json);
      }
    } catch (_) {}
    return content;
  }

  String _adaptColorStr(String colorStr, bool isDark, bool isBackground) {
    if (!colorStr.startsWith('#')) return colorStr;
    try {
      var hex = colorStr.replaceFirst('#', '');
      if (hex.length == 3) {
        hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
      }
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      if (hex.length != 8) return colorStr;

      final color = Color(int.parse(hex, radix: 16));
      final hsl = HSLColor.fromColor(color);

      if (isDark) {
        if (!isBackground) {
          // 暗色模式文字：如果太暗（亮度 < 0.4），提升亮度
          if (hsl.lightness < 0.4) {
            final newL = (1.0 - hsl.lightness).clamp(0.6, 1.0);
            final newColor = hsl.withLightness(newL).toColor();
            return '#${newColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
          }
        } else {
          // 暗色模式背景：如果太亮（亮度 > 0.6），降低亮度
          if (hsl.lightness > 0.6) {
            final newL = (1.0 - hsl.lightness).clamp(0.1, 0.4);
            final newColor = hsl.withLightness(newL).toColor();
            return '#${newColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
          }
        }
      } else {
        if (!isBackground) {
          // 亮色模式文字：如果太亮（亮度 > 0.7），降低亮度
          if (hsl.lightness > 0.7) {
            final newL = (1.0 - hsl.lightness).clamp(0.1, 0.4);
            final newColor = hsl.withLightness(newL).toColor();
            return '#${newColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
          }
        } else {
          // 亮色模式背景：如果太暗（亮度 < 0.3），提升亮度
          if (hsl.lightness < 0.3) {
            final newL = (1.0 - hsl.lightness).clamp(0.6, 1.0);
            final newColor = hsl.withLightness(newL).toColor();
            return '#${newColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
          }
        }
      }
    } catch (_) {}
    return colorStr;
  }

  QuillController _makeController(String deltaJson) {
    final document = QuillDeltaCodec.decode(deltaJson);
    return QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  void _disposeControllers() {
    _controller?.dispose();
    _controller = null;
    for (final c in _sliceControllers) {
      c.dispose();
    }
    _sliceControllers.clear();
    _slice = null;
  }

  @override
  void dispose() {
    _disposeControllers();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseTextStyle =
        widget.textStyle ??
        TextStyle(
          fontSize: 15,
          height: 1.7,
          color: isDark ? AppColors.slate200 : AppColors.gray700,
        );

    // 合并 embed builders：传入的 + 始终注册 resizableImage / legacy image / hoverInfo / divider 只读版
    final List<EmbedBuilder> mergedEmbedBuilders = [
      if (widget.embedBuilders != null) ...widget.embedBuilders!,
      const ResizableImageEmbedBuilder(readOnly: true),
      const _LegacyImageEmbedBuilder(),
      const HoverInfoEmbedBuilder(),
      const DividerEmbedBuilder(),
    ];

    if (widget.sliceForToc && _slice != null) {
      return _buildSliced(
        slice: _slice!,
        embedBuilders: mergedEmbedBuilders,
        isDark: isDark,
        baseTextStyle: baseTextStyle,
      );
    }

    return _buildSingleEditor(
      controller: _controller!,
      scrollController: _scrollController,
      embedBuilders: mergedEmbedBuilders,
      isDark: isDark,
      baseTextStyle: baseTextStyle,
    );
  }

  /// 单 Editor 渲染（默认模式）
  Widget _buildSingleEditor({
    required QuillController controller,
    required ScrollController scrollController,
    required List<EmbedBuilder> embedBuilders,
    required bool isDark,
    required TextStyle baseTextStyle,
  }) {
    return QuillEditor.basic(
      controller: controller,
      scrollController: scrollController,
      config: QuillEditorConfig(
        scrollable: widget.scrollable,
        showCursor: false,
        autoFocus: false,
        expands: false,
        padding: EdgeInsets.zero,
        onLaunchUrl: _handleLaunchUrl,
        embedBuilders: embedBuilders,
        customStyles: _buildStyles(isDark, baseTextStyle),
      ),
    );
  }

  /// 切片渲染（TOC 模式）
  ///
  /// 每个切片用独立 [QuillEditor.basic] 渲染。heading 切片外层包一层
  /// `KeyedSubtree` 挂 [GuideTocHeading.key]，方便 [Scrollable.ensureVisible]
  /// 精确定位。各 editor 内部不再独立滚动（外层 SingleChildScrollView 接管）。
  Widget _buildSliced({
    required GuideContentSlice slice,
    required List<EmbedBuilder> embedBuilders,
    required bool isDark,
    required TextStyle baseTextStyle,
  }) {
    final children = <Widget>[];
    for (var i = 0; i < slice.chunks.length; i++) {
      final chunk = slice.chunks[i];
      final controller = _sliceControllers[i];
      final editor = IgnorePointer(
        ignoring: false,
        child: QuillEditor.basic(
          controller: controller,
          // 切片模式下，editor 自身不滚动（外层 SingleChildScrollView 已托管）
          config: QuillEditorConfig(
            showCursor: false,
            autoFocus: false,
            expands: false,
            scrollable: false,
            padding: EdgeInsets.zero,
            onLaunchUrl: _handleLaunchUrl,
            embedBuilders: embedBuilders,
            customStyles: _buildStyles(isDark, baseTextStyle),
          ),
        ),
      );
      if (chunk.isHeading) {
        children.add(KeyedSubtree(key: chunk.heading!.key, child: editor));
      } else {
        children.add(editor);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Future<void> _handleLaunchUrl(String? url) async {
    if (url == null || url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // 忽略打开链接失败
    }
  }

  DefaultStyles _buildStyles(bool isDark, TextStyle baseTextStyle) {
    final verticalSpacing = widget.compact
        ? const VerticalSpacing(4, 0)
        : const VerticalSpacing(6, 0);

    return DefaultStyles(
      paragraph: DefaultTextBlockStyle(
        baseTextStyle,
        HorizontalSpacing.zero,
        verticalSpacing,
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
        widget.compact
            ? const VerticalSpacing(12, 6)
            : const VerticalSpacing(16, 8),
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
        widget.compact
            ? const VerticalSpacing(10, 4)
            : const VerticalSpacing(12, 6),
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
        widget.compact
            ? const VerticalSpacing(8, 4)
            : const VerticalSpacing(10, 4),
        VerticalSpacing.zero,
        null,
      ),
      quote: DefaultTextBlockStyle(
        TextStyle(
          fontSize: baseTextStyle.fontSize,
          height: 1.6,
          fontStyle: FontStyle.italic,
          color: isDark ? AppColors.slate400 : AppColors.gray500,
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
          color: isDark ? const Color(0xFFE879F9) : AppColors.red600,
          backgroundColor: isDark ? AppColors.slate700 : AppColors.gray100,
        ),
        HorizontalSpacing.zero,
        const VerticalSpacing(8, 8),
        VerticalSpacing.zero,
        BoxDecoration(
          color: isDark ? AppColors.slate700 : AppColors.gray50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.gray200,
          ),
        ),
      ),
      lists: DefaultListBlockStyle(
        baseTextStyle,
        HorizontalSpacing.zero,
        const VerticalSpacing(4, 4),
        VerticalSpacing.zero,
        null,
        null,
      ),
      // leading 控制列表符号（• / 1.）的文字样式，
      // 必须与 lists 的 height 保持一致才能垂直对齐
      leading: DefaultTextBlockStyle(
        baseTextStyle,
        HorizontalSpacing.zero,
        VerticalSpacing.zero,
        VerticalSpacing.zero,
        null,
      ),
      link: TextStyle(
        color: AppColors.primary,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.primary.withValues(alpha: 0.5),
      ),
      inlineCode: InlineCodeStyle(
        backgroundColor: isDark ? AppColors.slate700 : AppColors.gray100,
        radius: const Radius.circular(4),
        style: TextStyle(
          fontFamily: 'Consolas, Monaco, monospace',
          fontSize: 14,
          color: isDark ? const Color(0xFFE879F9) : AppColors.red600,
        ),
      ),
    );
  }
}

/// 兼容标准的 "image" Embed 类型（后台历史数据可能包含标准图片类型）
class _LegacyImageEmbedBuilder extends EmbedBuilder {
  const _LegacyImageEmbedBuilder();

  @override
  String get key => 'image';

  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final String url = embedContext.node.value.data.toString();
    final attributes = embedContext.node.style.attributes;
    return _LegacyImageWidget(url: url, attributes: attributes);
  }
}

class _LegacyImageWidget extends StatefulWidget {
  final String url;
  final Map<String, Attribute> attributes;
  const _LegacyImageWidget({required this.url, required this.attributes});
  @override
  State<_LegacyImageWidget> createState() => _LegacyImageWidgetState();
}

class _LegacyImageWidgetState extends State<_LegacyImageWidget> {
  String? _signedUrl;
  bool _isLoading = true;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  @override
  void didUpdateWidget(_LegacyImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadSignedUrl();
    }
  }

  Future<void> _loadSignedUrl() async {
    try {
      final url = await ImageUrlService.instance.getSignedUrl(widget.url);
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
    if (_signedUrl == null) return;
    ImageViewerDialog.show(context, imageUrls: [_signedUrl!], initialIndex: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_signedUrl == null) {
      return const SizedBox.shrink();
    }

    Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          DiskCachedImage(imageUrl: _signedUrl!, fit: BoxFit.contain),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _isHovering ? 1.0 : 0.0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.zoom_in,
                    size: 32,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    double? width;
    double? widthFactor;
    double? height;

    final widthAttr = widget.attributes['width']?.value?.toString();
    final heightAttr = widget.attributes['height']?.value?.toString();
    final styleAttr = widget.attributes['style']?.value?.toString();

    void parseDimension(
      String? str,
      void Function(double) setPx,
      void Function(double) setPct,
    ) {
      if (str == null || str.isEmpty) return;
      if (str.endsWith('%')) {
        final val = double.tryParse(str.substring(0, str.length - 1));
        if (val != null) setPct(val / 100.0);
      } else if (str.endsWith('px')) {
        final val = double.tryParse(str.substring(0, str.length - 2));
        if (val != null) setPx(val);
      } else {
        final val = double.tryParse(str);
        if (val != null) setPx(val);
      }
    }

    // 优先从直接属性读取
    parseDimension(widthAttr, (v) => width = v, (v) => widthFactor = v);
    parseDimension(
      heightAttr,
      (v) => height = v,
      (_) {},
    ); // 忽略 heightFactor，防止滚动视图崩溃

    // 如果直接属性没找到，尝试从 style 字符串提取
    if (styleAttr != null) {
      if (width == null && widthFactor == null) {
        final widthMatch = RegExp(r'width:\s*([^;]+)').firstMatch(styleAttr);
        if (widthMatch != null) {
          parseDimension(
            widthMatch.group(1)?.trim(),
            (v) => width = v,
            (v) => widthFactor = v,
          );
        }
      }
      if (height == null) {
        final heightMatch = RegExp(r'height:\s*([^;]+)').firstMatch(styleAttr);
        if (heightMatch != null) {
          parseDimension(
            heightMatch.group(1)?.trim(),
            (v) => height = v,
            (_) {},
          );
        }
      }
    }

    // 应用尺寸约束
    if (widthFactor != null && widthFactor! > 0) {
      image = FractionallySizedBox(widthFactor: widthFactor, child: image);
    } else if (width != null || height != null) {
      image = SizedBox(width: width, height: height, child: image);
    }

    image = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: image,
      ),
    );

    // 解析对齐方式
    AlignmentGeometry alignment = Alignment.center; // 默认居中
    if (styleAttr != null) {
      if (styleAttr.contains('float: right')) {
        alignment = Alignment.centerRight;
      } else if (styleAttr.contains('float: left')) {
        alignment = Alignment.centerLeft;
      } else if (styleAttr.contains('margin: auto')) {
        alignment = Alignment.center;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Align(alignment: alignment, child: image),
    );
  }
}
