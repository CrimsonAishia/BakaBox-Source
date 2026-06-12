import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/models/bilibili_content_models.dart';
import '../../../core/widgets/disk_cached_image.dart';
import '../../../core/constants/app_colors.dart';

const _bilibiliBlue = Color(0xFF00A1D6);

/// 移动端视频卡片
class VideoCardMobile extends StatelessWidget {
  final BilibiliVideo video;
  final VoidCallback? onTap;

  const VideoCardMobile({super.key, required this.video, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () async {
        onTap?.call();
        await _openBilibiliVideo(video.bvid);
      },
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        elevation: isDark ? 4 : 2,
        shadowColor: isDark ? Colors.black45 : Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面区域
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 封面图
                  DiskCachedImage(
                    imageUrl: video.displayCover ?? '',
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: Container(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      child: const Icon(
                        Icons.video_library,
                        size: 32,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  // 底部数据遮罩
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 14, 6, 4),
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
                          _buildCoverStat(Icons.play_arrow, video.playCount),
                          const Spacer(),
                          _buildCoverStat(
                            Icons.thumb_up_outlined,
                            video.likeCount,
                          ),
                          const SizedBox(width: 6),
                          _buildCoverStat(
                            Icons.monetization_on_outlined,
                            video.coinCount,
                          ),
                          const SizedBox(width: 6),
                          _buildCoverStat(
                            Icons.star_border,
                            video.favoriteCount,
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      video.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? Colors.white : AppColors.slate800,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    // 作者信息
                    Row(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: DiskCachedImage(
                              imageUrl: video.displayFace ?? '',
                              fit: BoxFit.cover,
                              placeholder: Container(
                                color: _bilibiliBlue.withValues(alpha: 0.2),
                                child: Icon(
                                  Icons.person,
                                  size: 12,
                                  color: _bilibiliBlue.withValues(alpha: 0.7),
                                ),
                              ),
                              errorWidget: Container(
                                color: _bilibiliBlue.withValues(alpha: 0.2),
                                child: Icon(
                                  Icons.person,
                                  size: 12,
                                  color: _bilibiliBlue.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            video.ownerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                        Text(
                          _formatDateTime(video.createdAt),
                          style: TextStyle(
                            fontSize: 10,
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
      ),
    );
  }

  Widget _buildCoverStat(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 2),
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

  /// 打开B站视频：优先尝试拉起B站App，失败则降级到网页
  Future<void> _openBilibiliVideo(String bvid) async {
    final appUrl = WebUri('bilibili://video/$bvid');
    final webUrl = WebUri('https://www.bilibili.com/video/$bvid');

    try {
      // 直接通过系统 Intent 打开 bilibili:// scheme
      await InAppBrowser.openWithSystemBrowser(url: appUrl);
    } catch (e) {
      debugPrint('Bilibili app scheme failed: $e');
      // App 未安装或 scheme 不可用，降级到系统浏览器打开网页
      try {
        await InAppBrowser.openWithSystemBrowser(url: webUrl);
      } catch (_) {}
    }
  }

  String _formatNumber(int number) {
    if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(1)}w';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours >= 1) {
        return '${difference.inHours}小时前';
      } else if (difference.inMinutes >= 1) {
        return '${difference.inMinutes}分钟前';
      } else {
        return '刚刚';
      }
    }

    if (dateTime.year == now.year) {
      return '${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }

    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
}
