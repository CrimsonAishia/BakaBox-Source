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

    // 骨架屏直接渲染和真实卡片完全相同的 Text/Icon，
    // 只把颜色设为透明，让 widget 自然撑起行高，
    // 再用 Stack 把色块叠在上面覆盖文字。
    Widget skeletonRow({required Widget realWidget, required Widget overlay}) {
      return Stack(
        children: [
          Opacity(opacity: 0, child: realWidget),
          Positioned.fill(child: overlay),
        ],
      );
    }

    Widget skeleton = Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.grey.withValues(alpha: 0.3),
              width: 1.0,
            ),
          ),
          child: SizedBox(
            height: 165,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // 背景
                  Positioned.fill(child: Container(color: baseColor)),
                  // 内容：与真实卡片完全相同的 Padding + Column
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 名称行：用真实 Text 撑高，色块覆盖
                        skeletonRow(
                          realWidget: const Text(
                            'placeholder',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                          ),
                          overlay: Align(
                            alignment: Alignment.centerLeft,
                            child: block(
                              width: double.infinity,
                              height: 14,
                              radius: 4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),

                        // 地图行：Icon(18) + Text(15)
                        skeletonRow(
                          realWidget: Row(
                            children: [
                              const Icon(Icons.map, size: 18),
                              const SizedBox(width: 6),
                              const Text(
                                'placeholder map name',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          overlay: Row(
                            children: [
                              block(width: 18, height: 18, radius: 3),
                              const SizedBox(width: 6),
                              block(width: 160, height: 12, radius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),

                        // IP 行：Icon(18) + Text(14) + Padding(h:8,v:4)+Icon(16)
                        skeletonRow(
                          realWidget: Row(
                            children: [
                              const Icon(Icons.language, size: 18),
                              const SizedBox(width: 6),
                              const Text(
                                '000.000.000.000:00000',
                                style: TextStyle(fontSize: 14),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Icon(Icons.copy, size: 16),
                              ),
                            ],
                          ),
                          overlay: Row(
                            children: [
                              block(width: 18, height: 18, radius: 3),
                              const SizedBox(width: 6),
                              block(width: 130, height: 11, radius: 4),
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: SizedBox(width: 16, height: 16),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),

                        // 标签行：Icon(18) + Container(padding v:4) + Text(14)
                        skeletonRow(
                          realWidget: Row(
                            children: [
                              const Icon(Icons.label_outline, size: 18),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                child: const Text(
                                  'tag',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                child: const Text(
                                  'tag2',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          overlay: Row(
                            children: [
                              block(width: 18, height: 18, radius: 3),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: blockColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: block(width: 36, height: 14, radius: 2),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: blockColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: block(width: 28, height: 14, radius: 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),

                        // 底部 chips：Container(padding h:10,v:6) + child(fontSize:13)
                        skeletonRow(
                          realWidget: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: const Text(
                                  '00/00',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: const Text(
                                  '00分钟',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          overlay: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: blockColor.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: block(width: 48, height: 13, radius: 3),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: blockColor.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: block(width: 40, height: 13, radius: 3),
                              ),
                            ],
                          ),
                        ),
                      ],
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
