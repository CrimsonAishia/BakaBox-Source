import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'community_guide_theme.dart';

/// 通用骨架屏 shimmer 包装。
///
/// 给一组占位元素添加循环呼吸+扫光动画，明确传达"正在加载"的状态。
/// 在 [CommunityGuideCardSkeleton] / [GuideMineCardSkeleton] /
/// [GuideMineDraftCardSkeleton] 外层包裹即可生效。
class CommunityGuideShimmer extends StatelessWidget {
  final Widget child;

  const CommunityGuideShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    final highlight = colors.isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.65);

    return child
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: const Duration(milliseconds: 1400),
          color: highlight,
          angle: 0.4,
        );
  }
}
