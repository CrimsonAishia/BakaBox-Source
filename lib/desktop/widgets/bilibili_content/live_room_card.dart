import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/bilibili_content_models.dart';
import '../../../core/widgets/disk_cached_image.dart';

const _bilibiliBlue = Color(0xFF00A1D6);

/// 直播间卡片组件
class LiveRoomCard extends StatefulWidget {
  final LiveRoom room;
  final bool isOwner;
  final String? coverUrl;
  final String? title;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function(bool)? onToggle;
  final bool isRefreshing; // 刷新状态
  final bool isLoadingBilibiliData; // B站数据加载状态
  final VoidCallback? onTap; // 点击回调（用于增加点击数）

  const LiveRoomCard({
    super.key,
    required this.room,
    this.isOwner = false,
    this.coverUrl,
    this.title,
    this.onEdit,
    this.onDelete,
    this.onToggle,
    this.isRefreshing = false,
    this.isLoadingBilibiliData = false,
    this.onTap,
  });

  @override
  State<LiveRoomCard> createState() => _LiveRoomCardState();
}

class _LiveRoomCardState extends State<LiveRoomCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _bar1Animation;
  late Animation<double> _bar2Animation;
  late Animation<double> _bar3Animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // 三个柱子不同步的上下动画
    _bar1Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );
    _bar2Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeInOut),
      ),
    );
    _bar3Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeInOut),
      ),
    );

    if (widget.room.isLive) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LiveRoomCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.room.isLive && !_animationController.isAnimating) {
      _animationController.repeat(reverse: true);
    } else if (!widget.room.isLive && _animationController.isAnimating) {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..translate(0.0, _isHovered ? -4.0 : 0.0),
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: _isHovered ? (isDark ? 8 : 6) : (isDark ? 4 : 2),
          shadowColor: _isHovered
              ? _bilibiliBlue.withValues(alpha: 0.3)
              : (isDark ? Colors.black45 : Colors.black26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _isHovered
                  ? _bilibiliBlue.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: _isHovered ? 1.5 : 0,
            ),
          ),
          child: _buildCardContent(isDark),
        ),
      ),
    );
  }

  Widget _buildCardContent(bool isDark) {
    return InkWell(
      onTap: () {
        // 先调用点击回调（增加点击数），再打开链接
        widget.onTap?.call();
        final url = Uri.parse('https://live.bilibili.com/${widget.room.roomId}');
        launchUrl(url);
      },
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面区域 - 固定高度，宽度自适应
            SizedBox(
              height: 157,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 封面图
                  DiskCachedImage(
                    imageUrl: widget.coverUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: Container(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      child: const Icon(
                        Icons.live_tv,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  // 刷新状态动画
                  if (widget.isRefreshing)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.3),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // B站数据加载状态
                  if (widget.isLoadingBilibiliData && !widget.isRefreshing)
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.15),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // 底部渐变遮罩
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 直播状态标签
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.room.isLive ? Colors.red : _bilibiliBlue,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: (widget.room.isLive ? Colors.red : _bilibiliBlue)
                                .withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.room.isLive)
                            AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                return SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      _buildBar(_bar1Animation.value, 8),
                                      _buildBar(_bar2Animation.value, 6),
                                      _buildBar(_bar3Animation.value, 10),
                                    ],
                                  ),
                                );
                              },
                            ),
                          if (widget.room.isLive)
                            const SizedBox(width: 3),
                          Text(
                            widget.room.isLive ? 'LIVE' : '休息中~',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 直播中的观众数（左下角）
                  if (widget.room.isLive)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.visibility,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatNumber(widget.room.viewCount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // 粉丝数/关注数（右下角）
                  if (widget.room.followerCount > 0)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade400.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatNumber(widget.room.followerCount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 信息区域
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                        )
                      : const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Color(0xFFF8FAFC)],
                        ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      widget.isLoadingBilibiliData
                          ? '获取中...'
                          : (widget.title ?? widget.room.ownerName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    // 主播信息行：头像 + 名称
                    Row(
                      children: [
                        // 主播头像
                        ClipOval(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: DiskCachedImage(
                              imageUrl: widget.room.displayFace ?? '',
                              fit: BoxFit.cover,
                              placeholder: Container(
                                color: _bilibiliBlue.withValues(alpha: 0.2),
                                child: Icon(
                                  Icons.person,
                                  size: 16,
                                  color: _bilibiliBlue.withValues(alpha: 0.7),
                                ),
                              ),
                              errorWidget: Container(
                                color: _bilibiliBlue.withValues(alpha: 0.2),
                                child: Icon(
                                  Icons.person,
                                  size: 16,
                                  color: _bilibiliBlue.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 主播名称
                        Expanded(
                          child: Text(
                            widget.isLoadingBilibiliData ? '获取中...' : widget.room.ownerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }

  String _formatNumber(int number) {
    if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(1)}万';
    }
    return number.toString();
  }

  Widget _buildBar(double animationValue, double maxHeight) {
    // 计算柱子的高度：使用正弦曲线使动画更平滑
    final height = maxHeight * (0.3 + 0.7 * animationValue);
    return Container(
      width: 2,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
