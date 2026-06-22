import 'package:flutter/material.dart';

import 'guide_tokens.dart';

/// 详情页右下浮动「回到顶部」按钮
///
/// - 滚动距离 > [showThreshold] 时从右侧滑入并渐显
/// - 带描边 + hover 高亮 + 阴影
/// - 点击平滑回到顶部
///
/// 用法：
/// ```dart
/// GuideInteractionDock(
///   scrollController: _scrollController,
/// )
/// ```
class GuideInteractionDock extends StatefulWidget {
  /// 滚动控制器（用于判断显隐和回顶）
  final ScrollController scrollController;

  /// 显示阈值（滚动像素数，默认 400）
  final double showThreshold;

  const GuideInteractionDock({
    super.key,
    required this.scrollController,
    this.showThreshold = 400,
    // 以下参数为兼容性保留，不再使用
    bool isLiked = false,
    bool isFavorited = false,
    int likeCount = 0,
    int favoriteCount = 0,
    int commentCount = 0,
    VoidCallback? onLikeTap,
    VoidCallback? onFavoriteTap,
    VoidCallback? onCommentTap,
  });

  @override
  State<GuideInteractionDock> createState() => _GuideInteractionDockState();
}

class _GuideInteractionDockState extends State<GuideInteractionDock>
    with SingleTickerProviderStateMixin {
  bool _isVisible = false;
  bool _hover = false;

  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(1.5, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _opacityAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    widget.scrollController.addListener(_onScroll);
    // 初始检测
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void didUpdateWidget(GuideInteractionDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _animController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final controller = widget.scrollController;
    if (!controller.hasClients) return;

    final visible = controller.position.pixels > widget.showThreshold;
    if (visible != _isVisible) {
      _isVisible = visible;
      if (_isVisible) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  void _scrollToTop() {
    widget.scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark
        ? const Color(0xFF1A2842).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.95);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: _hover ? 0.18 : 0.10)
        : (_hover
              ? GuideTokens.borderLight
              : GuideTokens.borderLight.withValues(alpha: 0.8));
    final iconColor = _hover
        ? theme.colorScheme.primary
        : GuideTokens.textSecondary(context);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: _scrollToTop,
            child: AnimatedContainer(
              duration: GuideTokens.durationFast,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark
                          ? (_hover ? 0.40 : 0.28)
                          : (_hover ? 0.10 : 0.06),
                    ),
                    blurRadius: _hover ? 16 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: _hover ? 24 : 22,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
