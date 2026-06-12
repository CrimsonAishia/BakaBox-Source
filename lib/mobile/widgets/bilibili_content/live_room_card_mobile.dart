import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/models/bilibili_content_models.dart';
import '../../../core/widgets/disk_cached_image.dart';
import '../../../core/constants/app_colors.dart';

const _bilibiliBlue = Color(0xFF00A1D6);

/// 移动端直播间卡片
class LiveRoomCardMobile extends StatelessWidget {
  final LiveRoom room;
  final VoidCallback? onTap;

  const LiveRoomCardMobile({super.key, required this.room, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () async {
        onTap?.call();
        await _openBilibiliLive(room.roomId);
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
                    imageUrl: room.displayCoverUrl,
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
                        Icons.live_tv,
                        size: 32,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  // 底部渐变遮罩
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 40,
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
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: room.isLive ? Colors.red : _bilibiliBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        room.isLive ? 'LIVE' : '休息中',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // 观众数（直播中显示）
                  if (room.isLive)
                    Positioned(
                      bottom: 4,
                      left: 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.visibility,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _formatNumber(room.popularity),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // 粉丝数
                  if (room.followerCount > 0)
                    Positioned(
                      bottom: 4,
                      right: 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _formatNumber(room.followerCount),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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
                      room.displayTitle,
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
                    // 主播信息
                    Row(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: DiskCachedImage(
                              imageUrl: room.displayFace ?? '',
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
                            room.ownerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
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
      ),
    );
  }

  /// 打开B站直播间：优先尝试拉起B站App，失败则降级到网页
  Future<void> _openBilibiliLive(String roomId) async {
    // B站直播间 deep link 格式：bilibili://live/{roomId}
    final appUrl = WebUri('bilibili://live/$roomId');
    final webUrl = WebUri('https://live.bilibili.com/$roomId');

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
}
