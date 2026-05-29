import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/bilibili_content_models.dart';
import '../../../core/widgets/disk_cached_image.dart';

const _bilibiliBlue = Color(0xFF00A1D6);

/// 视频卡片组件
class VideoCard extends StatefulWidget {
  final BilibiliVideo video;
  final bool isRefreshing; // 刷新状态
  final VoidCallback? onTap; // 点击回调（用于增加点击数）

  const VideoCard({
    super.key,
    required this.video,
    this.isRefreshing = false,
    this.onTap,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  bool _isHovered = false;

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
        transform: Matrix4.translationValues(0.0, _isHovered ? -4.0 : 0.0, 0.0),
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
        final url = Uri.parse(
          'https://www.bilibili.com/video/${widget.video.bvid}',
        );
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
                  imageUrl: widget.video.displayCover ?? '',
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  placeholder: Container(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: Container(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    child: const Icon(
                      Icons.video_library,
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // 审核状态标签
                if (widget.video.auditStatus != null &&
                    widget.video.auditStatus != 'approved')
                  Positioned(top: 8, left: 8, child: _buildAuditStatusBadge()),
                // 底部数据遮罩（播放、点赞、投币、收藏）
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        // 播放量（居左）
                        _buildCoverStat(Icons.play_arrow, widget.video.playCount),
                        const Spacer(),
                        // 互动三连（居右）
                        _buildCoverStat(Icons.thumb_up_outlined, widget.video.likeCount),
                        const SizedBox(width: 8),
                        _buildCoverStat(Icons.monetization_on_outlined, widget.video.coinCount),
                        const SizedBox(width: 8),
                        _buildCoverStat(Icons.star_border, widget.video.favoriteCount),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 信息区域
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    widget.video.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  // 作者信息行：头像 + 名称 + 时间
                  Row(
                    children: [
                      // 作者头像
                      ClipOval(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: DiskCachedImage(
                            imageUrl: widget.video.displayFace ?? '',
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
                      // 作者名称
                      Expanded(
                        child: Text(
                          widget.video.ownerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      // 后端时间
                      Text(
                        _formatDateTime(widget.video.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38,
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

  /// 格式化日期时间为相对简洁的格式
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    // 1天内：X小时前 或 X分钟前
    if (difference.inDays == 0) {
      if (difference.inHours >= 1) {
        return '${difference.inHours}小时前';
      } else if (difference.inMinutes >= 1) {
        return '${difference.inMinutes}分钟前';
      } else {
        return '刚刚';
      }
    }

    // 1年内（1天以上，不超过1年）：xx-xx
    if (dateTime.year == now.year) {
      return '${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }

    // 1年以上：xx-xx-xx
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  Widget _buildAuditStatusBadge() {
    final status = widget.video.auditStatus ?? 'pending';
    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

    switch (status) {
      case 'pending':
        bgColor = Colors.orange.withValues(alpha: 0.9);
        textColor = Colors.white;
        text = '待审核';
        icon = Icons.hourglass_empty;
        break;
      case 'rejected':
        bgColor = Colors.red.withValues(alpha: 0.9);
        textColor = Colors.white;
        text = '已拒绝';
        icon = Icons.close;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建封面上的数据项
  Widget _buildCoverStat(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 3),
        Text(
          _formatNumber(count),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
