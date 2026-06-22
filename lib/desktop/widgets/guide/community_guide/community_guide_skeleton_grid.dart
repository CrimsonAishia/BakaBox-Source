import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'community_guide_shimmer.dart';

/// 通用瀑布流骨架屏 sliver
///
/// 列表 / 我的中心都用同样的 SliverMasonryGrid 排骨架卡片。通过
/// [skeletonBuilder] 注入具体的骨架样式（社区列表 / 我的卡片各有自己的）。
///
/// 外层会再套一层 [CommunityGuideShimmer]，让所有骨架卡片同时有扫光动画，
/// 直观地表达「正在加载」。
///
/// 注意：不要在 itemBuilder 中再用 SlideAnimation / FadeInAnimation /
/// AnimateIfVisible 等会改变子项尺寸的入场动画——会与 SliverMasonryGrid 的
/// 滚动估算冲突，触发 estimatedMaxScrollOffset 断言。
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
          return CommunityGuideShimmer(child: skeletonBuilder(innerCtx));
        },
      ),
    );
  }
}
