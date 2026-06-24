import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/toast_utils.dart';

class ServerCardMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final String? copyText;

  const ServerCardMarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.copyText,
  });

  @override
  State<ServerCardMarqueeText> createState() => _ServerCardMarqueeTextState();
}

class _ServerCardMarqueeTextState extends State<ServerCardMarqueeText> {
  ScrollController? _scrollController;
  bool _needsScroll = false;
  bool _isScrolling = false;
  double _measuredOverflowWidth = 0;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void didUpdateWidget(ServerCardMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      // 安全地重置滚动位置
      if (_scrollController != null && _scrollController!.hasClients) {
        try {
          _scrollController!.jumpTo(0);
        } catch (_) {
          // 忽略跳转失败
        }
      }
      _isScrolling = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
    }
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  double _measureOverflowWidth(BuildContext context) {
    final renderObject = context.findRenderObject();
    final viewportWidth = renderObject is RenderBox
        ? renderObject.size.width
        : 0.0;
    if (viewportWidth <= 0) return 0;

    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();

    return (textPainter.width - viewportWidth).clamp(0.0, double.infinity);
  }

  void _checkOverflow() {
    if (!mounted || _scrollController == null) return;
    if (!_scrollController!.hasClients) return;

    final measuredOverflowWidth = _measureOverflowWidth(context);
    final maxScroll = _scrollController!.position.maxScrollExtent;
    final targetOverflowWidth = measuredOverflowWidth > maxScroll
        ? measuredOverflowWidth
        : maxScroll;
    final needsScroll = targetOverflowWidth > 0;

    if (needsScroll != _needsScroll ||
        (targetOverflowWidth - _measuredOverflowWidth).abs() > 0.5) {
      setState(() {
        _needsScroll = needsScroll;
        _measuredOverflowWidth = targetOverflowWidth;
      });
    }
    if (_needsScroll && !_isScrolling) {
      _startScrolling();
    }
  }

  void _startScrolling() async {
    if (!mounted || !_needsScroll || _scrollController == null) return;
    _isScrolling = true;

    while (mounted && _needsScroll && _isScrolling) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_needsScroll || _scrollController == null) break;

      final maxScroll = _scrollController!.position.maxScrollExtent;
      final targetOffset = _measuredOverflowWidth > maxScroll
          ? _measuredOverflowWidth
          : maxScroll;
      if (targetOffset <= 0) break;

      // 滚动到末尾
      try {
        await _scrollController!.animateTo(
          targetOffset,
          duration: Duration(
            milliseconds: (targetOffset * 30).toInt().clamp(1000, 5000),
          ),
          curve: Curves.linear,
        );
      } catch (_) {
        // ScrollController 可能已被 dispose
        break;
      }

      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) break;

      // 滚动回开头
      try {
        await _scrollController!.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      } catch (_) {
        // ScrollController 可能已被 dispose
        break;
      }

      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
    }
    _isScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    final currentStyle = _isHovered
        ? widget.style.copyWith(
            color: AppColors.primary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary,
          )
        : widget.style;

    Widget content;
    // 离屏渲染（如 screenshot captureFromLongWidget）时没有 View ancestor，
    // SingleChildScrollView 内部会调用 View.of(context) 导致断言失败，
    // 此时降级为普通 Text
    if (View.maybeOf(context) == null) {
      content = Text(
        widget.text,
        style: currentStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      content = LayoutBuilder(
        builder: (context, constraints) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
          return SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Text(widget.text, style: currentStyle, maxLines: 1),
            ),
          );
        },
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(
            ClipboardData(text: widget.copyText ?? widget.text),
          );
          ToastUtils.showSuccess(context, '已复制地图名称');
        },
        child: content,
      ),
    );
  }
}
