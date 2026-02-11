import 'package:flutter/material.dart';

/// 服务器卡片骨架屏
class ServerCardSkeleton extends StatefulWidget {
  const ServerCardSkeleton({super.key});

  @override
  State<ServerCardSkeleton> createState() => _ServerCardSkeletonState();
}

class _ServerCardSkeletonState extends State<ServerCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 与真实卡片完全一致的布局结构
    return Container(
      height: 140, // 固定高度与真实卡片一致
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.transparent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            // 深色背景
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E293B), Color(0xFF334155)],
                  ),
                ),
              ),
            ),
            // 半透明遮罩
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
            // 骨架内容 - 与真实卡片一致的 padding
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧内容
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 服务器名称 - 20px font
                          _buildShimmer(widthPercent: 0.7, height: 24),
                          const SizedBox(height: 11),
                          // 地图名称行 - 16px font
                          Row(
                            children: [
                              _buildShimmer(width: 44, height: 20), // "地图："
                              const SizedBox(width: 4),
                              Expanded(
                                child: _buildShimmer(widthPercent: 0.55, height: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 11),
                          // 地址和延迟行 - 15px font
                          Row(
                            children: [
                              _buildShimmer(width: 160, height: 18),
                              const SizedBox(width: 8),
                              _buildShimmer(width: 50, height: 18, radius: 4),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 右侧人数和运行时间
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 玩家数量框
                      _buildShimmer(width: 75, height: 44, radius: 6),
                      const SizedBox(height: 6),
                      // 运行时间框
                      _buildShimmer(width: 80, height: 38, radius: 6),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建闪烁骨架块
  Widget _buildShimmer({
    double? width,
    double? widthPercent,
    required double height,
    double radius = 4,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final actualWidth = width ?? (constraints.maxWidth * (widthPercent ?? 1.0));
            return Container(
              width: actualWidth,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                  stops: [
                    (_controller.value - 0.3).clamp(0.0, 1.0),
                    _controller.value,
                    (_controller.value + 0.3).clamp(0.0, 1.0),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
