import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';

class ServerListItemSkeleton extends StatelessWidget {
  final int index;
  final double opacity;
  final double scale;
  final bool showShimmer;

  const ServerListItemSkeleton({
    super.key,
    required this.index,
    this.opacity = 1.0,
    this.scale = 1.0,
    this.showShimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2D3748) : AppColors.slate200;
    final blockColor = isDark
        ? const Color(0xFF4A5568)
        : const Color(0xFFCBD5E0);

    Widget block({double? width, required double height, double radius = 4}) =>
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: blockColor,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    Widget skeleton = Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.transparent,
          elevation: 0,
          child: SizedBox(
            height: 145,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // 背景
                  Positioned.fill(child: Container(color: baseColor)),

                  // 顶部区域：服务器名称 + 人数
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 服务器名称骨架（左侧）
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                block(width: 180, height: 16, radius: 4),
                                const SizedBox(height: 6),
                                block(width: 120, height: 14, radius: 4),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 人数骨架（右侧）
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              block(width: 28, height: 22, radius: 4),
                              const SizedBox(width: 4),
                              block(width: 8, height: 14, radius: 2),
                              const SizedBox(width: 4),
                              block(width: 20, height: 12, radius: 3),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 底部渐变区域
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.only(
                        left: 14,
                        right: 14,
                        bottom: 10,
                        top: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            baseColor.withValues(alpha: 0.7),
                            baseColor,
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Row 1: 地图名 + info chips
                          Row(
                            children: [
                              block(width: 15, height: 15, radius: 3),
                              const SizedBox(width: 6),
                              Expanded(child: block(height: 12, radius: 4)),
                              const SizedBox(width: 8),
                              block(width: 50, height: 18, radius: 4),
                              const SizedBox(width: 6),
                              block(width: 40, height: 18, radius: 4),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Row 2: 标签 + 复制IP
                          Row(
                            children: [
                              block(width: 42, height: 18, radius: 4),
                              const SizedBox(width: 6),
                              block(width: 36, height: 18, radius: 4),
                              const Spacer(),
                              block(width: 60, height: 18, radius: 4),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (showShimmer) {
      return skeleton
          .animate(onPlay: (controller) => controller.repeat())
          .shimmer(duration: 1500.ms, color: blockColor.withValues(alpha: 0.6));
    }

    return skeleton;
  }
}
