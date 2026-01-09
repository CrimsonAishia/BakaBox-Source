import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/quill_delta_codec.dart';

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

  const RichTextViewer({
    super.key,
    required this.content,
    this.textStyle,
    this.compact = false,
  });

  @override
  State<RichTextViewer> createState() => _RichTextViewerState();
}

class _RichTextViewerState extends State<RichTextViewer> {
  late QuillController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(RichTextViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _initController();
    }
  }

  void _initController() {
    final document = QuillDeltaCodec.decode(widget.content);
    _controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final baseTextStyle = widget.textStyle ?? TextStyle(
      fontSize: 15,
      height: 1.7,
      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF374151),
    );

    return QuillEditor.basic(
      controller: _controller,
      scrollController: _scrollController,
      config: QuillEditorConfig(
        showCursor: false,
        autoFocus: false,
        expands: false,
        padding: EdgeInsets.zero,
        onLaunchUrl: _handleLaunchUrl,
        customStyles: _buildStyles(isDark, baseTextStyle),
      ),
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
          color: isDark ? Colors.white : const Color(0xFF1F2937),
        ),
        HorizontalSpacing.zero,
        widget.compact ? const VerticalSpacing(12, 6) : const VerticalSpacing(16, 8),
        VerticalSpacing.zero,
        null,
      ),
      h2: DefaultTextBlockStyle(
        TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.5,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
        ),
        HorizontalSpacing.zero,
        widget.compact ? const VerticalSpacing(10, 4) : const VerticalSpacing(12, 6),
        VerticalSpacing.zero,
        null,
      ),
      h3: DefaultTextBlockStyle(
        TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.5,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
        ),
        HorizontalSpacing.zero,
        widget.compact ? const VerticalSpacing(8, 4) : const VerticalSpacing(10, 4),
        VerticalSpacing.zero,
        null,
      ),
      quote: DefaultTextBlockStyle(
        TextStyle(
          fontSize: baseTextStyle.fontSize,
          height: 1.6,
          fontStyle: FontStyle.italic,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
        ),
        HorizontalSpacing.zero,
        const VerticalSpacing(8, 8),
        VerticalSpacing.zero,
        BoxDecoration(
          border: Border(
            left: BorderSide(
              color: const Color(0xFF0080FF).withValues(alpha: 0.5),
              width: 3,
            ),
          ),
        ),
      ),
      code: DefaultTextBlockStyle(
        TextStyle(
          fontSize: 13,
          fontFamily: 'Consolas, Monaco, monospace',
          color: isDark ? const Color(0xFFE879F9) : const Color(0xFFDC2626),
          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
        ),
        HorizontalSpacing.zero,
        const VerticalSpacing(8, 8),
        VerticalSpacing.zero,
        BoxDecoration(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB),
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
      link: TextStyle(
        color: const Color(0xFF0080FF),
        decoration: TextDecoration.underline,
        decorationColor: const Color(0xFF0080FF).withValues(alpha: 0.5),
      ),
    );
  }
}
