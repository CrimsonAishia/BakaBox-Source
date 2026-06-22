import 'dart:async';

import 'package:flutter/material.dart';

import 'guide_tokens.dart';

/// 详情页顶部 2px 阅读进度条
///
/// 跟随 `ScrollController` 的 `pixels / maxScrollExtent` 更新进度，
/// 200ms easeOut 平滑过渡。到底后停留 2 秒淡出。
///
/// 用法：
/// ```dart
/// Stack(
///   children: [
///     content,
///     Positioned(
///       top: 0,
///       left: 0,
///       right: 0,
///       child: GuideReadingProgress(scrollController: _scrollController),
///     ),
///   ],
/// )
/// ```
class GuideReadingProgress extends StatefulWidget {
  /// 关联的滚动控制器
  final ScrollController scrollController;

  /// 进度条高度（默认 2px）
  final double height;

  /// 进度条颜色（默认主色）
  final Color? color;

  const GuideReadingProgress({
    super.key,
    required this.scrollController,
    this.height = 2.0,
    this.color,
  });

  @override
  State<GuideReadingProgress> createState() => _GuideReadingProgressState();
}

class _GuideReadingProgressState extends State<GuideReadingProgress>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  bool _reachedBottom = false;
  bool _fadeOut = false;
  Timer? _fadeTimer;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(GuideReadingProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _fadeTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    final controller = widget.scrollController;
    if (!controller.hasClients) return;

    final maxExtent = controller.position.maxScrollExtent;
    if (maxExtent <= 0) return;

    final newProgress = (controller.position.pixels / maxExtent).clamp(
      0.0,
      1.0,
    );

    setState(() {
      _progress = newProgress;
    });

    // 到底后启动淡出计时
    if (newProgress >= 1.0 && !_reachedBottom) {
      _reachedBottom = true;
      _fadeTimer?.cancel();
      _fadeTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _fadeOut = true);
        }
      });
    } else if (newProgress < 1.0 && _reachedBottom) {
      // 离开底部，取消淡出
      _reachedBottom = false;
      _fadeOut = false;
      _fadeTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = widget.color ?? theme.colorScheme.primary;

    return AnimatedOpacity(
      opacity: _fadeOut ? 0.0 : 1.0,
      duration: GuideTokens.durationFast,
      curve: Curves.easeOut,
      child: SizedBox(
        height: widget.height,
        child: AnimatedFractionallySizedBox(
          duration: GuideTokens.durationFast,
          curve: Curves.easeOut,
          alignment: Alignment.centerLeft,
          widthFactor: _progress,
          child: Container(
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(widget.height / 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// 带动画的 FractionallySizedBox 替代品
///
/// Flutter 内置 `FractionallySizedBox` 不支持 implicit animation，
/// 这里使用 `AnimatedContainer` 配合 `LayoutBuilder` 实现类似效果。
class AnimatedFractionallySizedBox extends StatelessWidget {
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;
  final double widthFactor;
  final Widget? child;

  const AnimatedFractionallySizedBox({
    super.key,
    required this.duration,
    required this.curve,
    required this.alignment,
    required this.widthFactor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth = constraints.maxWidth * widthFactor;
        return Align(
          alignment: alignment,
          child: AnimatedContainer(
            duration: duration,
            curve: curve,
            width: targetWidth,
            height: constraints.maxHeight,
            child: child,
          ),
        );
      },
    );
  }
}
