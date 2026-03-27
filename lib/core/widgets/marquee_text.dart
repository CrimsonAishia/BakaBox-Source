import 'package:flutter/material.dart';

/// 滚动文本组件 - 文本过长时自动滚动
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const MarqueeText({super.key, required this.text, required this.style});

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _needsScroll = false;
  bool _isScrolling = false;
  double _measuredOverflowWidth = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (_scrollController.hasClients) {
        try {
          _scrollController.jumpTo(0);
        } catch (_) {}
      }
      _isScrolling = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _measureOverflowWidth(BuildContext context) {
    final renderObject = context.findRenderObject();
    final viewportWidth = renderObject is RenderBox ? renderObject.size.width : 0.0;
    if (viewportWidth <= 0) return 0;

    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();

    return (textPainter.width - viewportWidth).clamp(0.0, double.infinity);
  }

  void _checkOverflow() {
    if (!mounted || !_scrollController.hasClients) return;

    final measuredOverflowWidth = _measureOverflowWidth(context);
    final maxScroll = _scrollController.position.maxScrollExtent;
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
    if (!mounted || !_needsScroll) return;
    _isScrolling = true;

    while (mounted && _needsScroll && _isScrolling) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_needsScroll || !_scrollController.hasClients) break;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetOffset = _measuredOverflowWidth > maxScroll
          ? _measuredOverflowWidth
          : maxScroll;
      if (targetOffset <= 0) break;

      // 滚动到末尾
      try {
        await _scrollController.animateTo(
          targetOffset,
          duration: Duration(
            milliseconds: (targetOffset * 30).toInt().clamp(1000, 5000),
          ),
          curve: Curves.linear,
        );
      } catch (_) {
        break;
      }

      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_scrollController.hasClients) break;

      // 滚动回开头
      try {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      } catch (_) {
        break;
      }

      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
    }
    _isScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    if (View.maybeOf(context) == null) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Text(widget.text, style: widget.style, maxLines: 1),
          ),
        );
      },
    );
  }
}
