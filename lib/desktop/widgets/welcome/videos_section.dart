import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/core.dart';
import '../bilibili_content/video_card.dart';

/// 视频展示区
class VideosSection extends StatelessWidget {
  final bool isDark;

  const VideosSection({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BilibiliContentBloc, BilibiliContentState>(
      builder: (context, state) {
        // 只展示审核通过的视频，按创建时间降序（新添加的优先）
        final videos = state.videos
            .where((v) => v.isApproved)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final displayVideos = videos.take(6).toList();

        return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行
                  Row(
                    children: [
                      Icon(
                        MdiIcons.playCircle,
                        size: 16,
                        color: const Color(0xFF00A1D6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '精选视频',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      if (state.status == BilibiliContentStatus.loading &&
                          !state.hasLoadedVideos)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 内容
                  if (displayVideos.isEmpty && !state.hasLoadedVideos)
                    _buildSkeleton(isDark)
                  else if (displayVideos.isEmpty)
                    _buildEmpty(isDark)
                  else
                    SizedBox(
                      height: 260,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: displayVideos.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final video = displayVideos[index];
                          return SizedBox(
                            width: 200,
                            child: VideoCard(
                              video: video,
                              isRefreshing: state.isRefreshing,
                              onTap: () {
                                context.read<BilibiliContentBloc>().add(
                                  BilibiliContentIncreaseVideoViewRequested(
                                    id: video.id,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 500.ms, delay: 1000.ms)
            .slideY(
              begin: 0.15,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }

  Widget _buildEmpty(bool isDark) {
    return SizedBox(
      height: 100,
      child: Center(
        child: Text(
          '暂无视频',
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    return SizedBox(
      height: 260,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 200,
            child: _SkeletonCard(isDark: isDark),
          );
        },
      ),
    );
  }
}

/// 骨架屏卡片
class _SkeletonCard extends StatefulWidget {
  final bool isDark;
  const _SkeletonCard({required this.isDark});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final color = widget.isDark
            ? Colors.white.withValues(alpha: _animation.value * 0.15)
            : Colors.black.withValues(alpha: _animation.value * 0.08);
        return Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }
}
