import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/core.dart';
import '../bilibili_content/live_room_card.dart';

/// 直播间展示区
class LiveRoomsSection extends StatefulWidget {
  final bool isDark;

  const LiveRoomsSection({super.key, required this.isDark});

  @override
  State<LiveRoomsSection> createState() => _LiveRoomsSectionState();
}

class _LiveRoomsSectionState extends State<LiveRoomsSection> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollState);
    // 初始化后检查一次
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollState());
  }

  void _updateScrollState() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final canLeft = pos.pixels > 0;
    final canRight = pos.pixels < pos.maxScrollExtent;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scrollLeft() {
    _scrollController.animateTo(
      (_scrollController.offset - 200).clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      (_scrollController.offset + 200).clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollState);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return BlocBuilder<BilibiliContentBloc, BilibiliContentState>(
      builder: (context, state) {
        // 优先展示直播中的，再补充其他
        final rooms = [...state.liveRooms]
          ..sort((a, b) {
            if (a.isLive && !b.isLive) return -1;
            if (!a.isLive && b.isLive) return 1;
            return b.popularity.compareTo(a.popularity);
          });
        final displayRooms = rooms.take(6).toList();

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
                        MdiIcons.television,
                        size: 16,
                        color: const Color(0xFF00A1D6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '直播间',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 直播中数量徽章
                      if (state.liveRooms.any((r) => r.isLive))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${state.liveRooms.where((r) => r.isLive).length} 直播中',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      if (state.status == BilibiliContentStatus.loading &&
                          !state.hasLoadedLiveRooms)
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
                  if (displayRooms.isEmpty && !state.hasLoadedLiveRooms)
                    _buildSkeleton()
                  else if (displayRooms.isEmpty)
                    _buildEmpty()
                  else
                    MouseRegion(
                      onEnter: (_) => setState(() => _isHovering = true),
                      onExit: (_) => setState(() => _isHovering = false),
                      child: SizedBox(
                        height: 270, // 加 10 留给 Scrollbar 空间
                        child: Stack(
                          children: [
                            // 鼠标滚轮 → 横向滚动
                            Listener(
                              onPointerSignal: (event) {
                                if (event is PointerScrollEvent) {
                                  final delta = event.scrollDelta.dy != 0
                                      ? event.scrollDelta.dy
                                      : event.scrollDelta.dx;
                                  _scrollController.animateTo(
                                    (_scrollController.offset + delta).clamp(
                                      0.0,
                                      _scrollController.position.maxScrollExtent,
                                    ),
                                    duration: const Duration(milliseconds: 80),
                                    curve: Curves.linear,
                                  );
                                }
                              },
                              child: Scrollbar(
                                controller: _scrollController,
                                thumbVisibility: true,
                                trackVisibility: true,
                                child: Padding(
                                  // Scrollbar 占底部约 10px，卡片区保持 260
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: ListView.separated(
                                    controller: _scrollController,
                                    scrollDirection: Axis.horizontal,
                                    itemCount: displayRooms.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final room = displayRooms[index];
                                      return SizedBox(
                                        width: 180,
                                        child: LiveRoomCard(
                                          room: room,
                                          coverUrl: room.displayCover,
                                          title: room.displayTitle,
                                          isRefreshing: state.isRefreshing,
                                          onTap: () {
                                            context.read<BilibiliContentBloc>().add(
                                              BilibiliContentIncreaseLiveRoomViewRequested(
                                                id: room.id,
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            // 左侧翻页按钮
                            if (_canScrollLeft)
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 10,
                                child: AnimatedOpacity(
                                  opacity: _isHovering ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: _ScrollArrowButton(
                                    isDark: isDark,
                                    icon: Icons.chevron_left_rounded,
                                    onTap: _scrollLeft,
                                  ),
                                ),
                              ),
                            // 右侧翻页按钮
                            if (_canScrollRight)
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 10,
                                child: AnimatedOpacity(
                                  opacity: _isHovering ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: _ScrollArrowButton(
                                    isDark: isDark,
                                    icon: Icons.chevron_right_rounded,
                                    onTap: _scrollRight,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 500.ms, delay: 900.ms)
            .slideY(
              begin: 0.15,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }

  Widget _buildEmpty() {
    final isDark = widget.isDark;
    return SizedBox(
      height: 100,
      child: Center(
        child: Text(
          '暂无直播间',
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

  Widget _buildSkeleton() {
    final isDark = widget.isDark;
    return SizedBox(
      height: 260,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 180,
            child: _SkeletonCard(isDark: isDark),
          );
        },
      ),
    );
  }
}

/// 横向滚动箭头按钮
class _ScrollArrowButton extends StatefulWidget {
  final bool isDark;
  final IconData icon;
  final VoidCallback onTap;

  const _ScrollArrowButton({
    required this.isDark,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_ScrollArrowButton> createState() => _ScrollArrowButtonState();
}

class _ScrollArrowButtonState extends State<_ScrollArrowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          margin: const EdgeInsets.symmetric(vertical: 60),
          decoration: BoxDecoration(
            color: _hovering
                ? (widget.isDark
                    ? Colors.black.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.95))
                : (widget.isDark
                    ? Colors.black.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.75)),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            size: 22,
            color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
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
