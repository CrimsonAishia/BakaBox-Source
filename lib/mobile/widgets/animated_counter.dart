import 'package:flutter/material.dart';

class AnimatedCounter extends StatefulWidget {
  final int count;
  final String suffix;
  final bool isLoading;
  final String loadingText;
  final TextStyle? textStyle;

  const AnimatedCounter({
    super.key,
    required this.count,
    this.suffix = '',
    this.isLoading = false,
    this.loadingText = '加载中',
    this.textStyle,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousCount = 0;

  @override
  void initState() {
    super.initState();
    _previousCount = widget.count;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: _previousCount.toDouble(),
      end: widget.count.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _previousCount = oldWidget.count;
      _animation = Tween<double>(
        begin: _previousCount.toDouble(),
        end: widget.count.toDouble(),
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Text(widget.loadingText, style: widget.textStyle);
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${_animation.value.round()}${widget.suffix}',
          style: widget.textStyle,
        );
      },
    );
  }
}
