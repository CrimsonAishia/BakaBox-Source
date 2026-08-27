import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/bloc/activity/activity_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/activity_model.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/widgets/signed_network_image.dart';
import '../activity/activity_detail_dialog.dart';

class ActivityBannerCarousel extends StatefulWidget {
  const ActivityBannerCarousel({super.key});

  @override
  State<ActivityBannerCarousel> createState() => _ActivityBannerCarouselState();
}

class _ActivityBannerCarouselState extends State<ActivityBannerCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || _isHovered) return;
      final bloc = context.read<ActivityBloc>();
      final activities = bloc.state.activities;
      if (activities.length > 1 && _pageController.hasClients) {
        int currentPage = _pageController.page?.round() ?? 0;
        int nextPage = currentPage + 1;
        if (nextPage >= activities.length) {
          nextPage = 0;
        }
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _goToPrevious() {
    final bloc = context.read<ActivityBloc>();
    final activities = bloc.state.activities;
    if (activities.length <= 1 || !_pageController.hasClients) return;

    int currentPage = _pageController.page?.round() ?? 0;
    int prevPage = currentPage - 1;
    if (prevPage < 0) {
      prevPage = activities.length - 1;
    }
    _pageController.animateToPage(
      prevPage,
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
    );
  }

  void _goToNext() {
    final bloc = context.read<ActivityBloc>();
    final activities = bloc.state.activities;
    if (activities.length <= 1 || !_pageController.hasClients) return;

    int currentPage = _pageController.page?.round() ?? 0;
    int nextPage = currentPage + 1;
    if (nextPage >= activities.length) {
      nextPage = 0;
    }
    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ActivityBloc, ActivityState>(
      listenWhen: (previous, current) =>
          previous.activities.length != current.activities.length,
      listener: (context, state) {
        // 数量变化时，强制重置页面索引，防止 Flutter PageView 的滚动边界卡死 Bug
        if (mounted) {
          setState(() {
            _currentPage = 0;
          });
          if (_pageController.hasClients) {
            _pageController.jumpToPage(0);
          }
        }
      },
      builder: (context, state) {
        final activities = state.activities;

        if (activities.isEmpty) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          height: 230,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: Stack(
              children: [
                PageView.builder(
                  key: ValueKey(activities.length), // 强制重建 PageView，彻底解决无法滚动的问题
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    return _BannerItemWidget(activity: activity);
                  },
                ),

                if (activities.length > 1)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: AnimatedOpacity(
                        opacity: _isHovered ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: _NavButton(
                          icon: Icons.chevron_left_rounded,
                          onTap: _goToPrevious,
                        ),
                      ),
                    ),
                  ),

                if (activities.length > 1)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: AnimatedOpacity(
                        opacity: _isHovered ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: _NavButton(
                          icon: Icons.chevron_right_rounded,
                          onTap: _goToNext,
                        ),
                      ),
                    ),
                  ),

                if (activities.length > 1)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16, right: 24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            activities.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentPage == index ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _currentPage == index
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.black.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: _isHovered ? 0.3 : 0.1),
            ),
          ),
          child: Icon(widget.icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _BannerItemWidget extends StatefulWidget {
  final ActivityModel activity;

  const _BannerItemWidget({required this.activity});

  @override
  State<_BannerItemWidget> createState() => _BannerItemWidgetState();
}

class _BannerItemWidgetState extends State<_BannerItemWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          ActivityDetailDialog.show(context, widget.activity);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.activity.bannerUrl.isNotEmpty)
              AnimatedScale(
                scale: _isHovered ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                child: SignedNetworkImage(
                  url: widget.activity.bannerUrl,
                  fit: BoxFit.cover,
                  fallback: _buildPlaceholder(),
                ),
              )
            else
              _buildPlaceholder(),

            // 顶部优雅角标 (左上角)
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 16, left: 16),
                child: Row(
                  children: [
                    if (widget.activity.isPinned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFF43F5E),
                              Color(0xFFE11D48),
                            ], // Rose 500 to 600
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFE11D48,
                              ).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.push_pin_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '置顶',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 底部平滑渐变遮罩
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 0.8],
                ),
              ),
            ),

            // 左下角信息
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 24,
                  bottom: 24,
                  right: 120,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: AnimatedSlide(
                    offset: _isHovered ? const Offset(0, -0.05) : Offset.zero,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTimeAndStatusRow(context),
                        const SizedBox(height: 8),
                        Text(
                          widget.activity.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.activity.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.activity.description,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.slate800 : AppColors.slate100,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 64,
          color: isDark ? AppColors.slate600 : AppColors.slate300,
        ),
      ),
    );
  }

  // 构建底部元数据栏 (包含状态指示器和精简后的时间)
  Widget _buildTimeAndStatusRow(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final isUpcoming = now < widget.activity.startTime;
    final isEnded =
        widget.activity.endTime != null && now > widget.activity.endTime!;
    final isOngoing = !isUpcoming && !isEnded;

    final String statusText = isOngoing ? '进行中' : (isUpcoming ? '即将开始' : '已结束');
    final Color statusColor = isOngoing
        ? const Color(0xFF10B981) // Emerald (进行中)
        : (isUpcoming
              ? const Color(0xFFF59E0B)
              : const Color(0xFF9CA3AF)); // Amber (未开始) / Gray (已结束)

    final String timeStr = TimeUtils.formatActivityTime(
      widget.activity.startTime,
      widget.activity.endTime,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 状态指示标签
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.6),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 时间字符串
        Icon(
          Icons.schedule_rounded,
          color: const Color(0xFFFBBF24),
          size: 13,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 3),
            Shadow(
              color: Colors.black.withValues(alpha: 0.6),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
        const SizedBox(width: 4),
        Text(
          timeStr,
          style: TextStyle(
            color: const Color(0xFFFBBF24),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 3),
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
