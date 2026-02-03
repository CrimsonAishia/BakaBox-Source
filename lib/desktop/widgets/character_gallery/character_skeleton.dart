import 'package:flutter/material.dart';
import 'character_gallery_theme.dart';

/// 骨架屏方块组件
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final baseColor = widget.baseColor ?? scrollBrown.withValues(alpha: 0.08);
    final highlightColor = widget.highlightColor ?? scrollBrown.withValues(alpha: 0.15);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}


/// 详情面板骨架屏
class DetailPanelSkeleton extends StatelessWidget {
  const DetailPanelSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final cardBg = CharacterGalleryTheme.getOverlayColor(context, alpha: 0.3);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 预览图骨架
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: CharacterGalleryTheme.getGold(context).withValues(alpha: 0.3),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SkeletonBox(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 0,
                  baseColor: scrollBrown.withValues(alpha: 0.08),
                  highlightColor: scrollBrown.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 预览按钮骨架
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              4,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SkeletonBox(
                  width: 36,
                  height: 36,
                  baseColor: scrollBrown.withValues(alpha: 0.1),
                  highlightColor: scrollBrown.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 名称区域骨架
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(
                width: 18,
                height: 18,
                borderRadius: 2,
                baseColor: CharacterGalleryTheme.getVermillion(context).withValues(alpha: 0.2),
                highlightColor: CharacterGalleryTheme.getVermillion(context).withValues(alpha: 0.35),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(
                      width: 140,
                      height: 26,
                      baseColor: scrollBrown.withValues(alpha: 0.12),
                      highlightColor: scrollBrown.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 4),
                    SkeletonBox(
                      width: 100,
                      height: 14,
                      borderRadius: 2,
                      baseColor: scrollBrown.withValues(alpha: 0.06),
                      highlightColor: scrollBrown.withValues(alpha: 0.12),
                    ),
                  ],
                ),
              ),
              SkeletonBox(
                width: 75,
                height: 18,
                baseColor: CharacterGalleryTheme.getGold(context).withValues(alpha: 0.15),
                highlightColor: CharacterGalleryTheme.getGold(context).withValues(alpha: 0.25),
              ),
              const SizedBox(width: 8),
              SkeletonBox(
                width: 50,
                height: 22,
                baseColor: scrollBrown.withValues(alpha: 0.08),
                highlightColor: scrollBrown.withValues(alpha: 0.15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 角色介绍分隔线骨架
          _buildDividerSkeleton(scrollBrown),
          const SizedBox(height: 12),
          // 描述文字骨架
          ...List.generate(
            4,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SkeletonBox(
                width: i == 3 ? 180 : double.infinity,
                height: 16,
                borderRadius: 2,
                baseColor: scrollBrown.withValues(alpha: 0.06),
                highlightColor: scrollBrown.withValues(alpha: 0.12),
              ),
            ),
          ),
          // 符卡系统分隔线骨架
          _buildDividerSkeleton(scrollBrown, hasTrailing: true),
          const SizedBox(height: 12),
          // 符卡卡片骨架
          ...List.generate(2, (i) => _buildSkillCardSkeleton(context, scrollBrown, cardBg)),
        ],
      ),
    );
  }

  Widget _buildDividerSkeleton(Color scrollBrown, {bool hasTrailing = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Container(width: 30, height: 2, color: scrollBrown.withValues(alpha: 0.15)),
          const SizedBox(width: 8),
          SkeletonBox(
            width: 56,
            height: 16,
            borderRadius: 2,
            baseColor: scrollBrown.withValues(alpha: 0.12),
            highlightColor: scrollBrown.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 2, color: scrollBrown.withValues(alpha: 0.08))),
          if (hasTrailing) ...[
            const SizedBox(width: 8),
            SkeletonBox(
              width: 70,
              height: 24,
              baseColor: scrollBrown.withValues(alpha: 0.08),
              highlightColor: scrollBrown.withValues(alpha: 0.15),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSkillCardSkeleton(BuildContext context, Color scrollBrown, Color cardBg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border.all(color: scrollBrown.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(
                  width: 40,
                  height: 20,
                  baseColor: CharacterGalleryTheme.getVermillion(context).withValues(alpha: 0.1),
                  highlightColor: CharacterGalleryTheme.getVermillion(context).withValues(alpha: 0.2),
                ),
                const SizedBox(width: 8),
                SkeletonBox(
                  width: 80,
                  height: 18,
                  borderRadius: 2,
                  baseColor: scrollBrown.withValues(alpha: 0.1),
                  highlightColor: scrollBrown.withValues(alpha: 0.18),
                ),
                const Spacer(),
                SkeletonBox(
                  width: 50,
                  height: 22,
                  baseColor: scrollBrown.withValues(alpha: 0.06),
                  highlightColor: scrollBrown.withValues(alpha: 0.12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SkeletonBox(
              width: double.infinity,
              height: 14,
              borderRadius: 2,
              baseColor: scrollBrown.withValues(alpha: 0.06),
              highlightColor: scrollBrown.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SkeletonBox(
                  width: 50,
                  height: 14,
                  borderRadius: 2,
                  baseColor: scrollBrown.withValues(alpha: 0.06),
                  highlightColor: scrollBrown.withValues(alpha: 0.12),
                ),
                const SizedBox(width: 12),
                SkeletonBox(
                  width: 60,
                  height: 14,
                  borderRadius: 2,
                  baseColor: CharacterGalleryTheme.getVermillion(context).withValues(alpha: 0.08),
                  highlightColor: CharacterGalleryTheme.getVermillion(context).withValues(alpha: 0.15),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


/// 符卡加载骨架屏
class SpellCardsLoadingSkeleton extends StatelessWidget {
  const SpellCardsLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final cardBg = CharacterGalleryTheme.getOverlayColor(context, alpha: 0.3);

    return Column(
      children: List.generate(
        2,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border.all(color: scrollBrown.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SkeletonBox(
                    width: 40,
                    height: 20,
                    baseColor: CharacterGalleryTheme.getVermillion(context).withValues(alpha: 0.1),
                    highlightColor: CharacterGalleryTheme.getVermillion(context).withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 8),
                  SkeletonBox(
                    width: 80,
                    height: 18,
                    borderRadius: 2,
                    baseColor: scrollBrown.withValues(alpha: 0.1),
                    highlightColor: scrollBrown.withValues(alpha: 0.18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SkeletonBox(
                width: double.infinity,
                height: 14,
                borderRadius: 2,
                baseColor: scrollBrown.withValues(alpha: 0.06),
                highlightColor: scrollBrown.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SkeletonBox(
                    width: 50,
                    height: 14,
                    borderRadius: 2,
                    baseColor: scrollBrown.withValues(alpha: 0.06),
                    highlightColor: scrollBrown.withValues(alpha: 0.12),
                  ),
                  const SizedBox(width: 12),
                  SkeletonBox(
                    width: 60,
                    height: 14,
                    borderRadius: 2,
                    baseColor: CharacterGalleryTheme.getVermillion(context).withValues(alpha: 0.08),
                    highlightColor: CharacterGalleryTheme.getVermillion(context).withValues(alpha: 0.15),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
