import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'community_guide_theme.dart';

/// 可滚动分类条（hover 时左右两侧出现箭头 + 渐隐遮罩）
class CommunityGuideCategoryRow extends StatefulWidget {
  final List<Widget> children;

  const CommunityGuideCategoryRow({super.key, required this.children});

  @override
  State<CommunityGuideCategoryRow> createState() =>
      _CommunityGuideCategoryRowState();
}

class _CommunityGuideCategoryRowState
    extends State<CommunityGuideCategoryRow> {
  final ScrollController _ctrl = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_updateState);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateState());
  }

  @override
  void didUpdateWidget(covariant CommunityGuideCategoryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateState());
  }

  @override
  void dispose() {
    _ctrl.removeListener(_updateState);
    _ctrl.dispose();
    super.dispose();
  }

  void _updateState() {
    if (!_ctrl.hasClients) return;
    final pos = _ctrl.position;
    final left = pos.pixels > 1.0;
    final right = pos.pixels < pos.maxScrollExtent - 1.0;
    if (left != _canScrollLeft || right != _canScrollRight) {
      setState(() {
        _canScrollLeft = left;
        _canScrollRight = right;
      });
    }
  }

  void _scrollBy(double delta) {
    if (!_ctrl.hasClients) return;
    final target = (_ctrl.offset + delta).clamp(
      0.0,
      _ctrl.position.maxScrollExtent,
    );
    _ctrl.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              ScrollConfiguration(
                behavior: const _NoGlowScrollBehavior(),
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent && _ctrl.hasClients) {
                      final delta = event.scrollDelta.dy;
                      final target = (_ctrl.offset + delta).clamp(
                        0.0,
                        _ctrl.position.maxScrollExtent,
                      );
                      _ctrl.jumpTo(target);
                    }
                  },
                  child: SingleChildScrollView(
                    controller: _ctrl,
                    scrollDirection: Axis.horizontal,
                    child: Row(children: widget.children),
                  ),
                ),
              ),
              if (_canScrollLeft)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 36,
                  child: IgnorePointer(
                    ignoring: !_hovering,
                    child: _EdgeFader(
                      alignment: Alignment.centerLeft,
                      visible: _hovering,
                      icon: Icons.chevron_left,
                      onTap: () => _scrollBy(-160),
                    ),
                  ),
                ),
              if (_canScrollRight)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 36,
                  child: IgnorePointer(
                    ignoring: !_hovering,
                    child: _EdgeFader(
                      alignment: Alignment.centerRight,
                      visible: _hovering,
                      icon: Icons.chevron_right,
                      onTap: () => _scrollBy(160),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EdgeFader extends StatelessWidget {
  final Alignment alignment;
  final bool visible;
  final IconData icon;
  final VoidCallback onTap;

  const _EdgeFader({
    required this.alignment,
    required this.visible,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    final colors = CommunityGuideColors.of(context);
    final fadeColor = colors.isDark
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.85);
    final btnBg = colors.isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.10);
    final btnIconColor = colors.iconPrimary;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: visible ? 1.0 : 0.0,
      child: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
                end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
                colors: [fadeColor, Colors.transparent],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          Align(
            alignment: alignment,
            child: Material(
              color: btnBg,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Icon(icon, size: 16, color: btnIconColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

/// 单个分类按钮（hover/active 状态自适应主题）
class CommunityGuideCategoryChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const CommunityGuideCategoryChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? colors.accentBlue : colors.chipInactiveBg,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : colors.chipInactiveText,
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
