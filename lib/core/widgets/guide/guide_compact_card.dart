import 'package:flutter/material.dart';

import '../../services/image_url_service.dart';
import '../disk_cached_image.dart';
import 'guide_tokens.dart';

/// 地图详情「攻略」Tab 用紧凑列表项
///
/// 高度 96，布局：封面 96×96 在左，标题 + 作者 + 互动数据在右。
/// 用于 `MapDatabaseDesktop`「攻略」Tab 中展示该地图的攻略列表。
///
/// 用法：
/// ```dart
/// GuideCompactCard(
///   title: '我的世界通关攻略',
///   coverUrl: guide.coverUrl,
///   authorName: guide.authorName,
///   viewCount: guide.viewCount,
///   likeCount: guide.likeCount,
///   commentCount: guide.commentCount,
///   onTap: () => DesktopNavigator.openGuideDetail(guide.id),
/// )
/// ```
class GuideCompactCard extends StatefulWidget {
  /// 攻略标题
  final String title;

  /// 封面图 URL
  final String? coverUrl;

  /// 作者昵称
  final String authorName;

  /// 浏览数
  final int viewCount;

  /// 点赞数
  final int likeCount;

  /// 评论数
  final int commentCount;

  /// 点击回调
  final VoidCallback? onTap;

  const GuideCompactCard({
    super.key,
    required this.title,
    this.coverUrl,
    required this.authorName,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.onTap,
  });

  @override
  State<GuideCompactCard> createState() => _GuideCompactCardState();
}

class _GuideCompactCardState extends State<GuideCompactCard> {
  Future<String>? _signedUrlFuture;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  @override
  void didUpdateWidget(GuideCompactCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) {
      _loadSignedUrl();
    }
  }

  void _loadSignedUrl() {
    final url = widget.coverUrl;
    if (url != null && url.isNotEmpty) {
      _signedUrlFuture = ImageUrlService.instance.getSignedUrl(url);
    } else {
      _signedUrlFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: GuideTokens.durationFast,
          curve: Curves.easeOutCubic,
          height: 96,
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.02))
                : Colors.transparent,
            borderRadius: GuideTokens.borderRadius12,
          ),
          padding: const EdgeInsets.all(GuideTokens.space8),
          child: Row(
            children: [
              // 左侧封面 96×96（减去 padding 后实际内容区域 80×80）
              _buildCover(isDark),
              const SizedBox(width: GuideTokens.space12),

              // 右侧信息
              Expanded(child: _buildInfo(context, theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(bool isDark) {
    return ClipRRect(
      borderRadius: GuideTokens.borderRadius8,
      child: SizedBox(
        width: 80,
        height: 80,
        child: _signedUrlFuture != null
            ? FutureBuilder<String>(
                future: _signedUrlFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return DiskCachedImage(
                      imageUrl: snapshot.data!,
                      fit: BoxFit.cover,
                      cacheWidth: 160,
                      cacheHeight: 160,
                    );
                  }
                  return _buildFallbackCover(isDark);
                },
              )
            : _buildFallbackCover(isDark),
      ),
    );
  }

  Widget _buildFallbackCover(bool isDark) {
    return Container(
      color: isDark ? GuideTokens.fallbackBgDark : GuideTokens.fallbackBgLight,
      child: Center(
        child: Icon(
          Icons.article_outlined,
          size: 28,
          color: GuideTokens.fallbackIcon,
        ),
      ),
    );
  }

  Widget _buildInfo(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 标题
        Text(
          widget.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: GuideTokens.textPrimary(context),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: GuideTokens.space4),

        // 作者
        Text(
          widget.authorName,
          style: theme.textTheme.bodySmall?.copyWith(
            color: GuideTokens.textSecondary(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: GuideTokens.space4),

        // 互动数据
        _buildStats(context, theme),
      ],
    );
  }

  Widget _buildStats(BuildContext context, ThemeData theme) {
    final statColor = GuideTokens.textTertiary(context);
    final statStyle = theme.textTheme.labelSmall?.copyWith(
      color: statColor,
      fontSize: 11,
    );

    return Row(
      children: [
        Icon(Icons.visibility_outlined, size: 12, color: statColor),
        const SizedBox(width: 2),
        Text(_formatCount(widget.viewCount), style: statStyle),
        const SizedBox(width: GuideTokens.space8),
        Icon(Icons.thumb_up_outlined, size: 12, color: statColor),
        const SizedBox(width: 2),
        Text(_formatCount(widget.likeCount), style: statStyle),
        const SizedBox(width: GuideTokens.space8),
        Icon(Icons.chat_bubble_outline, size: 12, color: statColor),
        const SizedBox(width: 2),
        Text(_formatCount(widget.commentCount), style: statStyle),
      ],
    );
  }

  /// 格式化数量（≥10000 显示为 x.xw）
  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}w';
    }
    return count.toString();
  }
}
