import 'package:flutter/material.dart';

/// 滚动文本组件 - 文本过长时自动滚动
///
/// 使用 LayoutBuilder 获取真实可用宽度，在 Stack/Positioned 等布局中
/// 也能正确计算溢出量，不依赖 findRenderObject。
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const MarqueeText({super.key, required this.text, required this.style});

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  late ScrollController _scrollController;
  bool _needsScroll = false;
  bool _isScrolling = false;
  double _measuredOverflowWidth = 0;

  /// LayoutBuilder 每次 build 时传入的最新宽度，用于 text 变化后重新检查
  double _lastKnownWidth = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // 首次检查在 LayoutBuilder 的 postFrameCallback 里触发，无需在此调用
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
      _measuredOverflowWidth = 0;
      _needsScroll = false;
      // 用上次 LayoutBuilder 记录的宽度重新检查
      if (_lastKnownWidth > 0) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _checkOverflow(_lastKnownWidth),
        );
      }
    }
  }

  @override
  void dispose() {
    _isScrolling = false;
    _scrollController.dispose();
    super.dispose();
  }

  double _measureTextWidth() {
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.width;
  }

  void _checkOverflow(double viewportWidth) {
    if (!mounted || !_scrollController.hasClients || viewportWidth <= 0) return;

    final textWidth = _measureTextWidth();
    final overflow = (textWidth - viewportWidth).clamp(0.0, double.infinity);
    // maxScrollExtent 是 Flutter 实际允许滚动的距离，以它为准
    final maxScroll = _scrollController.position.maxScrollExtent;
    final target = overflow > maxScroll ? overflow : maxScroll;
    final needsScroll = target > 0;

    if (needsScroll != _needsScroll ||
        (target - _measuredOverflowWidth).abs() > 0.5) {
      setState(() {
        _needsScroll = needsScroll;
        _measuredOverflowWidth = target;
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
      final target =
          _measuredOverflowWidth > maxScroll ? _measuredOverflowWidth : maxScroll;
      if (target <= 0) break;

      try {
        await _scrollController.animateTo(
          target,
          duration: Duration(
            milliseconds: (target * 30).toInt().clamp(1000, 5000),
          ),
          curve: Curves.linear,
        );
      } catch (_) {
        break;
      }

      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_scrollController.hasClients) break;

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
        final width = constraints.maxWidth;
        // 记录最新宽度，供 text 变化时复用
        _lastKnownWidth = width;
        // 每帧 build 后用准确宽度检查一次
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _checkOverflow(width),
        );
        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: width),
            child: Text(widget.text, style: widget.style, maxLines: 1),
          ),
        );
      },
    );
  }
}
