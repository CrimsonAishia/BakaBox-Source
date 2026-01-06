import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    final baseColor = isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF4A5568) : const Color(0xFFF7FAFC);

    Widget skeleton = Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.3), width: 1.0),
          ),
          child: SizedBox(
            height: 170,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: baseColor,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 服务器名称骨架
                    Container(
                      width: double.infinity,
                      height: 20,
                      decoration: BoxDecoration(
                        color: highlightColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 地图信息骨架
                    Container(
                      width: 180,
                      height: 14,
                      decoration: BoxDecoration(
                        color: highlightColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 地址信息骨架
                    Container(
                      width: 150,
                      height: 14,
                      decoration: BoxDecoration(
                        color: highlightColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    // 底部信息标签骨架
                    Row(
                      children: [
                        Container(
                          width: 70,
                          height: 28,
                          decoration: BoxDecoration(
                            color: highlightColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 60,
                          height: 28,
                          decoration: BoxDecoration(
                            color: highlightColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 90,
                          height: 28,
                          decoration: BoxDecoration(
                            color: highlightColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (showShimmer) {
      return skeleton
          .animate(onPlay: (controller) => controller.repeat())
          .shimmer(
            duration: 1500.ms,
            color: highlightColor.withValues(alpha: 0.5),
          );
    }

    return skeleton;
  }
}
