import 'package:flutter/material.dart';

import 'guide_tokens.dart';

/// 攻略卡片骨架屏
///
/// 与 `GuideArticleCard` 尺寸严格一致的 shimmer 加载占位，
/// 防止首屏加载时产生布局抖动。
///
/// 结构：封面区域（16:9）+ 标题行 + 标签行 + 作者行。
///
/// 用法：
/// ```dart
/// // 在 SliverGrid 中渲染 6 张骨架卡
/// SliverGrid.count(
///   crossAxisCount: 3,
///   children: List.generate(6, (_) => const GuideCardSkeleton()),
/// )
/// ```
class GuideCardSkeleton extends StatefulWidget {
  const GuideCardSkeleton({super.key});

  @override
  State<GuideCardSkeleton> createState() => _GuideCardSkeletonState();
}

class _GuideCardSkeletonState extends State<GuideCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: GuideTokens.borderRadius16,
        border: Border.all(
          color: GuideTokens.divider(context),
          width: 1.5,
        ),
        boxShadow: GuideTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面区域（与真实卡片的 16:9 封面一致）
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(GuideTokens.radius16),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildShimmerBlock(isDark),
            ),
          ),

          // 内容区域
          Padding(
            padding: GuideTokens.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行 1
                _buildShimmerLine(isDark, widthFactor: 0.9, height: 14),
                const SizedBox(height: GuideTokens.space4),
                // 标题行 2
                _buildShimmerLine(isDark, widthFactor: 0.6, height: 14),
                const SizedBox(height: GuideTokens.space12),

                // 标签行
                Row(
                  children: [
                    _buildShimmerPill(isDark, width: 48),
                    const SizedBox(width: GuideTokens.space4),
                    _buildShimmerPill(isDark, width: 56),
                    const SizedBox(width: GuideTokens.space4),
                    _buildShimmerPill(isDark, width: 40),
                  ],
                ),
                const SizedBox(height: GuideTokens.space12),

                // 作者 + 数据行
                Row(
                  children: [
                    // 作者名占位
                    Expanded(
                      flex: 25,
                      child: _buildShimmerLine(isDark, widthFactor: 1.0, height: 12),
                    ),
                    const Spacer(flex: 45),
                    // 互动数据占位
                    Expanded(
                      flex: 30,
                      child: _buildShimmerLine(isDark, widthFactor: 1.0, height: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerBlock(bool isDark) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: isDark
                  ? [
                      GuideTokens.fallbackBgDark,
                      GuideTokens.shimmerHighlightDark,
                      GuideTokens.fallbackBgDark,
                    ]
                  : [
                      GuideTokens.fallbackBgLight,
                      GuideTokens.shimmerHighlightLight,
                      GuideTokens.fallbackBgLight,
                    ],
              stops: [
                _shimmerAnimation.value - 1,
                _shimmerAnimation.value,
                _shimmerAnimation.value + 1,
              ].map((s) => s.clamp(0.0, 1.0)).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerLine(bool isDark, {
    required double widthFactor,
    required double height,
  }) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return FractionallySizedBox(
          widthFactor: widthFactor,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: isDark
                    ? [
                        GuideTokens.fallbackBgDark,
                        GuideTokens.shimmerHighlightDark,
                        GuideTokens.fallbackBgDark,
                      ]
                    : [
                        GuideTokens.fallbackBgLight,
                        GuideTokens.shimmerHighlightLight,
                        GuideTokens.fallbackBgLight,
                      ],
                stops: [
                  (_shimmerAnimation.value - 1).clamp(0.0, 1.0),
                  _shimmerAnimation.value.clamp(0.0, 1.0),
                  (_shimmerAnimation.value + 1).clamp(0.0, 1.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerPill(bool isDark, {required double width}) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: width,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: GuideTokens.borderRadius8,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: isDark
                  ? [
                      GuideTokens.fallbackBgDark,
                      GuideTokens.shimmerHighlightDark,
                      GuideTokens.fallbackBgDark,
                    ]
                  : [
                      GuideTokens.fallbackBgLight,
                      GuideTokens.shimmerHighlightLight,
                      GuideTokens.fallbackBgLight,
                    ],
              stops: [
                (_shimmerAnimation.value - 1).clamp(0.0, 1.0),
                _shimmerAnimation.value.clamp(0.0, 1.0),
                (_shimmerAnimation.value + 1).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
