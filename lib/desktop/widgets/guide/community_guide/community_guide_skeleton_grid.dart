import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'community_guide_shimmer.dart';

/// 通用瀑布流骨架屏 sliver
///
/// 列表 / 我的中心都用同样的 SliverMasonryGrid + 阶梯渐入动画包装骨架卡片。
/// 通过 [skeletonBuilder] 注入具体的骨架卡片（社区列表 / 我的卡片各有自己的样式）。
///
/// 外层会再套一层 [CommunityGuideShimmer]，让所有骨架卡片同时有呼吸 / 扫光动画，
/// 直观地表达「正在加载」。
class CommunityGuideSkeletonGrid extends StatelessWidget {
  final int crossCount;
  final EdgeInsets padding;
  final int count;
  final WidgetBuilder skeletonBuilder;

  const CommunityGuideSkeletonGrid({
    super.key,
    required this.crossCount,
    required this.padding,
    required this.count,
    required this.skeletonBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverMasonryGrid.count(
        crossAxisCount: crossCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childCount: count,
        itemBuilder: (innerCtx, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 500),
            columnCount: crossCount,
            child: SlideAnimation(
              verticalOffset: 60.0,
              child: FadeInAnimation(
                child: CommunityGuideShimmer(
                  child: skeletonBuilder(innerCtx),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
