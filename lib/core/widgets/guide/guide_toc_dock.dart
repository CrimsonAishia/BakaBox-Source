import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'guide_toc_outline.dart';
import 'guide_tokens.dart';

/// 详情页右下浮动「目录」按钮 + 弹出式目录面板
///
/// 设计参考：Notion / VS Code Outline / 语雀。
/// - 不常驻：默认仅显示 44×44 的圆角按钮（与 [GuideInteractionDock] 同款）。
/// - 点击按钮，从按钮位置向左上方展开半透明玻璃面板（260px 宽）。
/// - 列表项按 h1/h2/h3 缩进 + 字号区分；当前阅读位置高亮（主色竖条 + 加粗）。
/// - 点击 item 平滑滚动到对应 heading 并自动收起；按 Esc 收起。
/// - 当滚动距离 < [showThreshold] 或 outline 为空时整个组件隐藏。
class GuideTocDock extends StatefulWidget {
  /// 关联的滚动控制器（用于显隐 + 当前位置匹配）
  final ScrollController scrollController;

  /// 目录条目（从 [RichTextViewer] outline 回调拿到）
  final List<GuideTocHeading> outline;

  /// 显示阈值（滚动像素数，默认 200）
  final double showThreshold;

  const GuideTocDock({
    super.key,
    required this.scrollController,
    required this.outline,
    this.showThreshold = 200,
  });

  @override
  State<GuideTocDock> createState() => _GuideTocDockState();
}

class _GuideTocDockState extends State<GuideTocDock>
    with SingleTickerProviderStateMixin {
  bool _isVisible = false;
  bool _hover = false;
  bool _open = false;
  int _activeIndex = 0;

  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _opacityAnimation;

  final FocusNode _panelFocus = FocusNode(debugLabel: 'guide-toc-panel');

  /// 把面板挂到 Overlay 层，规避祖先 Stack/Column 的命中区域裁剪。
  final OverlayPortalController _portalController = OverlayPortalController();

  /// 把面板的位置锚定到按钮，跟随按钮位置变化。
  final LayerLink _buttonLink = LayerLink();

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void didUpdateWidget(GuideTocDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
    if (oldWidget.outline.length != widget.outline.length) {
      _activeIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateActive());
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _animController.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.outline.isEmpty) {
      if (_isVisible) {
        _isVisible = false;
        _animController.reverse();
      }
      return;
    }
    final controller = widget.scrollController;
    if (!controller.hasClients) return;

    final visible = controller.position.pixels > widget.showThreshold;
    if (visible != _isVisible) {
      _isVisible = visible;
      if (_isVisible) {
        _animController.forward();
      } else {
        _animController.reverse();
        if (_open) {
          _open = false;
          _portalController.hide();
          if (mounted) setState(() {});
        }
      }
    }
    _updateActive();
  }

  /// 根据各 heading 的当前位置，找到「最后一个已经滚过顶部触发线」的 heading。
  ///
  /// 触发线设为视口顶部 + 120px：超过这个线说明 heading 已经接近顶部或在上方，
  /// 算作「正在阅读」。如果没有任何 heading 滚过触发线，默认高亮第一个。
  void _updateActive() {
    if (widget.outline.isEmpty) return;
    const threshold = 120.0;
    int newActive = 0;
    for (var i = 0; i < widget.outline.length; i++) {
      final ctx = widget.outline[i].key.currentContext;
      if (ctx == null) continue;
      final ro = ctx.findRenderObject();
      if (ro is! RenderBox || !ro.attached) continue;
      final dy = ro.localToGlobal(Offset.zero).dy;
      if (dy <= threshold) {
        newActive = i;
      } else {
        break;
      }
    }
    if (newActive != _activeIndex) {
      setState(() => _activeIndex = newActive);
    }
  }

  void _togglePanel() {
    setState(() => _open = !_open);
    if (_open) {
      _portalController.show();
      _panelFocus.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateActive());
    } else {
      _portalController.hide();
    }
  }

  void _closePanel() {
    if (_open) {
      setState(() => _open = false);
      _portalController.hide();
    }
  }

  Future<void> _scrollToHeading(GuideTocHeading h) async {
    final ctx = h.key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      // 顶部留 8% 视口高度的安全距离，避免被滚动指示器遮挡
      alignment: 0.08,
    );
    if (mounted) _closePanel();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.outline.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark
        ? const Color(0xFF1A2842).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.95);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: _hover || _open ? 0.18 : 0.10)
        : (_hover || _open
              ? GuideTokens.borderLight
              : GuideTokens.borderLight.withValues(alpha: 0.8));
    final iconColor = (_hover || _open)
        ? theme.colorScheme.primary
        : GuideTokens.textSecondary(context);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: CompositedTransformTarget(
          link: _buttonLink,
          child: OverlayPortal(
            controller: _portalController,
            overlayChildBuilder: (overlayCtx) => _buildOverlayPanel(overlayCtx),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: GestureDetector(
                onTap: _togglePanel,
                behavior: HitTestBehavior.opaque,
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
                              ? (_hover || _open ? 0.40 : 0.28)
                              : (_hover || _open ? 0.10 : 0.06),
                        ),
                        blurRadius: _hover || _open ? 16 : 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.format_list_bulleted_rounded,
                      size: _hover || _open ? 22 : 20,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 在 Overlay 层渲染面板：先铺一层透明遮罩用于「点击外部关闭」，
  /// 再用 [CompositedTransformFollower] 把面板锚定到按钮的左上方。
  Widget _buildOverlayPanel(BuildContext overlayCtx) {
    return Stack(
      children: [
        // 透明全屏遮罩，捕获面板外的点击/按下事件用于关闭
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closePanel,
          ),
        ),
        // 锚定到按钮：面板的右下角对齐按钮的右上角，向上展开
        CompositedTransformFollower(
          link: _buttonLink,
          showWhenUnlinked: false,
          // targetAnchor: 按钮上的锚点（按钮顶边右端）
          targetAnchor: Alignment.topRight,
          // followerAnchor: 面板上的锚点（面板底边右端）
          followerAnchor: Alignment.bottomRight,
          // 与按钮顶部留 8px 间距
          offset: const Offset(0, -8),
          child: _buildPanel(
            overlayCtx,
            Theme.of(overlayCtx).brightness == Brightness.dark,
          ),
        ),
      ],
    );
  }

  Widget _buildPanel(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final maxPanelHeight = MediaQuery.of(context).size.height * 0.55;

    return Focus(
      focusNode: _panelFocus,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _closePanel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, t, child) {
          // 注意：不能在外层包 Opacity，否则会把 BackdropFilter 关进离屏缓冲，
          // 模糊会失效。这里只用 Transform（不会建离屏层），淡入交给内部的
          // AnimatedOpacity 处理。
          return Transform.translate(
            offset: Offset(0, (1 - t) * 8),
            child: Transform.scale(
              alignment: Alignment.bottomRight,
              scale: 0.96 + 0.04 * t,
              child: child,
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(GuideTokens.radius12),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: GuideTokens.glassBlurSigma,
              sigmaY: GuideTokens.glassBlurSigma,
            ),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, opacity, child) {
                return Opacity(opacity: opacity, child: child);
              },
              child: Container(
                width: 280,
                constraints: BoxConstraints(maxHeight: maxPanelHeight),
                decoration: BoxDecoration(
                  color: GuideTokens.glassSurface(context),
                  borderRadius: BorderRadius.circular(GuideTokens.radius12),
                  border: Border.all(
                    color: GuideTokens.glassBorder(context),
                    width: 1,
                  ),
                  boxShadow: GuideTokens.shadowMd,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPanelHeader(context, theme),
                    Container(height: 1, color: GuideTokens.divider(context)),
                    Flexible(child: _buildPanelList(context, theme)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelHeader(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GuideTokens.space16,
        GuideTokens.space12,
        GuideTokens.space8,
        GuideTokens.space12,
      ),
      child: Row(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: GuideTokens.space8),
          Text(
            '目录',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: GuideTokens.textPrimary(context),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: GuideTokens.space8),
          Text(
            '${widget.outline.length}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: GuideTokens.textTertiary(context),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: _closePanel,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: GuideTokens.textTertiary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelList(BuildContext context, ThemeData theme) {
    return Scrollbar(
      thumbVisibility: false,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: GuideTokens.space8),
        shrinkWrap: true,
        itemCount: widget.outline.length,
        itemBuilder: (context, i) {
          final h = widget.outline[i];
          final isActive = i == _activeIndex;
          return _TocItem(
            heading: h,
            isActive: isActive,
            onTap: () => _scrollToHeading(h),
          );
        },
      ),
    );
  }
}

/// 目录条目
class _TocItem extends StatefulWidget {
  final GuideTocHeading heading;
  final bool isActive;
  final VoidCallback onTap;

  const _TocItem({
    required this.heading,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_TocItem> createState() => _TocItemState();
}

class _TocItemState extends State<_TocItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // 缩进：h1 = 0, h2 = 14, h3 = 28
    final indent = (widget.heading.level - 1) * 14.0;

    // 字号 / 字重：h1 略大粗，h3 较轻
    final fontSize = switch (widget.heading.level) {
      1 => 13.5,
      2 => 13.0,
      _ => 12.5,
    };
    final activeWeight = widget.heading.level == 1
        ? FontWeight.w700
        : FontWeight.w600;
    final normalWeight = widget.heading.level == 1
        ? FontWeight.w600
        : FontWeight.w500;
    final fontWeight = widget.isActive ? activeWeight : normalWeight;

    final color = widget.isActive
        ? primary
        : (_hover
              ? GuideTokens.textPrimary(context)
              : GuideTokens.textSecondary(context));

    final bg = widget.isActive
        ? primary.withValues(alpha: 0.10)
        : (_hover ? primary.withValues(alpha: 0.06) : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: GuideTokens.durationFast,
          margin: const EdgeInsets.symmetric(
            horizontal: GuideTokens.space8,
            vertical: 1,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 左侧主色竖条（仅 active）
              AnimatedContainer(
                duration: GuideTokens.durationFast,
                width: 3,
                height: 16,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: widget.isActive ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 6 + indent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 7,
                    horizontal: 4,
                  ),
                  child: Text(
                    widget.heading.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                      color: color,
                      height: 1.35,
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
}
