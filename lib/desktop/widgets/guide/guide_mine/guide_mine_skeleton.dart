import 'package:flutter/material.dart';

import '../community_guide/community_guide_theme.dart';

/// 「我的中心」卡片骨架屏
class GuideMineCardSkeleton extends StatelessWidget {
  const GuideMineCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(height: 140, color: colors.skeletonBg),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _bar(colors, width: double.infinity, height: 10),
                const SizedBox(height: 6),
                _bar(colors, width: 160, height: 10),
                const SizedBox(height: 12),
                _bar(colors, width: 80, height: 10),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _bar(colors, width: 36, height: 14),
                    const SizedBox(width: 6),
                    _bar(colors, width: 36, height: 14),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(
    CommunityGuideColors colors, {
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.skeletonBar,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// 「我的中心」草稿卡片骨架屏（与 [GuideMineDraftCard] 对齐的横向布局）
class GuideMineDraftCardSkeleton extends StatelessWidget {
  const GuideMineDraftCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.toolbarBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.skeletonBg,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors.skeletonBar,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 140,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors.skeletonBar,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
