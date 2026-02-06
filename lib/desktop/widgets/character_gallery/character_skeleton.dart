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
    final cardBg = CharacterGalleryTheme.getOverlayColor(context, alpha: 0.5);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 预览图区域
          _buildPreviewSectionSkeleton(context, scrollBrown),
          const SizedBox(height: 20),
          // 名称区域
          _buildNameSectionSkeleton(context, scrollBrown),
          const SizedBox(height: 16),
          // 角色介绍分隔线
          _buildSectionDividerSkeleton(scrollBrown, '角色介绍'),
          const SizedBox(height: 12),
          // 描述文字
          ...List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SkeletonBox(
                width: i == 2 ? 200 : double.infinity,
                height: 14,
                borderRadius: 2,
                baseColor: scrollBrown.withValues(alpha: 0.06),
                highlightColor: scrollBrown.withValues(alpha: 0.12),
              ),
            ),
          ),
          // 符卡系统分隔线
          _buildSectionDividerSkeleton(scrollBrown, '符卡系统'),
          const SizedBox(height: 12),
          // 符卡分组标题 - 被动技能
          _buildGroupHeaderSkeleton(scrollBrown, const Color(0xFF4A7C59)),
          const SizedBox(height: 8),
          _buildSkillCardSkeleton(context, scrollBrown, cardBg),
          const SizedBox(height: 16),
          // 符卡分组标题 - 大符卡
          _buildGroupHeaderSkeleton(scrollBrown, CharacterGalleryTheme.getGold(context)),
          const SizedBox(height: 8),
          _buildSkillCardSkeleton(context, scrollBrown, cardBg),
          const SizedBox(height: 16),
          // 符卡分组标题 - 小符卡
          _buildGroupHeaderSkeleton(scrollBrown, CharacterGalleryTheme.getVermillion(context)),
          const SizedBox(height: 8),
          _buildSkillCardSkeleton(context, scrollBrown, cardBg),
          _buildSkillCardSkeleton(context, scrollBrown, cardBg),
          // 底部留白
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  /// 预览图区域骨架
  Widget _buildPreviewSectionSkeleton(BuildContext context, Color scrollBrown) {
    return Column(
      children: [
        // 预览图
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
        // 预览位置按钮（正、左、右、背）
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['正', '左', '右', '背'].map((label) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: scrollBrown.withValues(alpha: 0.2),
                  ),
                ),
                child: SkeletonBox(
                  width: 36,
                  height: 36,
                  borderRadius: 4,
                  baseColor: scrollBrown.withValues(alpha: 0.06),
                  highlightColor: scrollBrown.withValues(alpha: 0.12),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 名称区域骨架
  Widget _buildNameSectionSkeleton(BuildContext context, Color scrollBrown) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ◆ 符号
        SkeletonBox(
          width: 18,
          height: 18,
          borderRadius: 2,
          baseColor: CharacterGalleryTheme.getVermillion(context).withValues(alpha: 0.2),
          highlightColor: CharacterGalleryTheme.getVermillion(context).withValues(alpha: 0.35),
        ),
        const SizedBox(width: 8),
        // 名称和英文名
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(
                width: 120,
                height: 22,
                baseColor: scrollBrown.withValues(alpha: 0.12),
                highlightColor: scrollBrown.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 4),
              SkeletonBox(
                width: 80,
                height: 12,
                borderRadius: 2,
                baseColor: scrollBrown.withValues(alpha: 0.06),
                highlightColor: scrollBrown.withValues(alpha: 0.12),
              ),
            ],
          ),
        ),
        // 来源徽章
        SkeletonBox(
          width: 60,
          height: 24,
          borderRadius: 4,
          baseColor: CharacterGalleryTheme.getGold(context).withValues(alpha: 0.15),
          highlightColor: CharacterGalleryTheme.getGold(context).withValues(alpha: 0.25),
        ),
      ],
    );
  }

  /// 分隔线骨架（模拟 SectionDivider）
  Widget _buildSectionDividerSkeleton(Color scrollBrown, String title) {
    final titleWidth = title.length * 14.0;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Container(width: 30, height: 2, color: scrollBrown.withValues(alpha: 0.15)),
          const SizedBox(width: 8),
          SkeletonBox(
            width: titleWidth,
            height: 16,
            borderRadius: 2,
            baseColor: scrollBrown.withValues(alpha: 0.12),
            highlightColor: scrollBrown.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 2, color: scrollBrown.withValues(alpha: 0.08))),
        ],
      ),
    );
  }

  /// 符卡分组标题骨架
  Widget _buildGroupHeaderSkeleton(Color scrollBrown, Color accentColor) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 6),
        SkeletonBox(
          width: 56,
          height: 13,
          borderRadius: 2,
          baseColor: accentColor.withValues(alpha: 0.15),
          highlightColor: accentColor.withValues(alpha: 0.25),
        ),
      ],
    );
  }

  /// 技能卡片骨架
  Widget _buildSkillCardSkeleton(BuildContext context, Color scrollBrown, Color cardBg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: scrollBrown.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：类型标签 + 名称 + 编辑按钮
          Row(
            children: [
              // 类型标签
              SkeletonBox(
                width: 44,
                height: 20,
                baseColor: CharacterGalleryTheme.getVermillion(context).withValues(alpha: 0.1),
                highlightColor: CharacterGalleryTheme.getVermillion(context).withValues(alpha: 0.2),
              ),
              const SizedBox(width: 8),
              // 名称
              SkeletonBox(
                width: 100,
                height: 16,
                borderRadius: 2,
                baseColor: scrollBrown.withValues(alpha: 0.1),
                highlightColor: scrollBrown.withValues(alpha: 0.18),
              ),
              const Spacer(),
              // 编辑按钮
              SkeletonBox(
                width: 44,
                height: 20,
                baseColor: scrollBrown.withValues(alpha: 0.06),
                highlightColor: scrollBrown.withValues(alpha: 0.12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 描述
          SkeletonBox(
            width: double.infinity,
            height: 13,
            borderRadius: 2,
            baseColor: scrollBrown.withValues(alpha: 0.06),
            highlightColor: scrollBrown.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 8),
          // 属性行：冷却、伤害、消耗
          Row(
            children: [
              _buildStatItemSkeleton(scrollBrown, CharacterGalleryTheme.getCooldownColor(context)),
              const SizedBox(width: 12),
              _buildStatItemSkeleton(scrollBrown, CharacterGalleryTheme.getDamageColor(context)),
              const SizedBox(width: 12),
              _buildStatItemSkeleton(scrollBrown, CharacterGalleryTheme.getBCostColor(context)),
            ],
          ),
        ],
      ),
    );
  }

  /// 属性项骨架（图标+标签+数值）
  Widget _buildStatItemSkeleton(Color scrollBrown, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 图标
        SkeletonBox(
          width: 16,
          height: 16,
          borderRadius: 2,
          baseColor: color.withValues(alpha: 0.15),
          highlightColor: color.withValues(alpha: 0.25),
        ),
        const SizedBox(width: 4),
        // 标签
        SizedBox(
          width: 36,
          child: SkeletonBox(
            width: 28,
            height: 13,
            borderRadius: 2,
            baseColor: color.withValues(alpha: 0.1),
            highlightColor: color.withValues(alpha: 0.18),
          ),
        ),
        // 数值
        SkeletonBox(
          width: 24,
          height: 14,
          borderRadius: 2,
          baseColor: color.withValues(alpha: 0.12),
          highlightColor: color.withValues(alpha: 0.2),
        ),
      ],
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
