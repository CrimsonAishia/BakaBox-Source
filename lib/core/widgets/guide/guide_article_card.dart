import 'package:flutter/material.dart';

import '../../services/image_url_service.dart';
import '../disk_cached_image.dart';
import 'guide_map_badge_chip.dart';
import 'guide_tokens.dart';

/// 攻略列表瀑布流卡片
///
/// 包含：封面 + 分类角标 + 标题 + 标签 + 作者元信息 + hover scale 1.02。
/// 当 `mapName != null` 时在右下渲染 `GuideMapBadgeChip`。
///
/// 遵循 cardTheme：95% 透明白 + 1.5px 描边 + 16 圆角。
///
/// 用法：
/// ```dart
/// GuideArticleCard(
///   title: '我的世界通关攻略',
///   coverUrl: item.coverUrl,
///   categoryName: item.categoryName,
///   categoryColorHex: item.categoryColorHex,
///   tags: item.tags,
///   authorName: item.authorName,
///   authorAvatar: item.authorAvatar,
///   viewCount: item.viewCount,
///   likeCount: item.likeCount,
///   commentCount: item.commentCount,
///   mapName: item.mapName,
///   mapLabel: item.mapLabel,
///   mapBackground: item.mapBackground,
///   hasVideo: item.hasVideo,
///   onTap: () => showDetail(item.id),
///   onMapBadgeTap: () => navigateToMap(item.mapName),
/// )
/// ```
class GuideArticleCard extends StatefulWidget {
  /// 攻略标题
  final String title;

  /// 攻略摘要
  final String? summary;

  /// 封面图 URL
  final String? coverUrl;

  /// 分类展示名称
  final String? categoryName;

  /// 分类色值（hex 字符串）
  final String? categoryColorHex;

  /// 标签列表
  final List<String> tags;

  /// 作者昵称
  final String authorName;

  /// 作者头像 URL
  final String? authorAvatar;

  /// 浏览数
  final int viewCount;

  /// 点赞数
  final int likeCount;

  /// 评论数
  final int commentCount;

  /// 关联地图名称
  final String? mapName;

  /// 关联地图展示名
  final String? mapLabel;

  /// 关联地图背景图 URL
  final String? mapBackground;

  /// 是否含有视频
  final bool hasVideo;

  /// 卡片点击回调
  final VoidCallback? onTap;

  /// 地图角标点击回调
  final VoidCallback? onMapBadgeTap;

  const GuideArticleCard({
    super.key,
    required this.title,
    this.summary,
    this.coverUrl,
    this.categoryName,
    this.categoryColorHex,
    this.tags = const [],
    required this.authorName,
    this.authorAvatar,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.mapName,
    this.mapLabel,
    this.mapBackground,
    this.hasVideo = false,
    this.onTap,
    this.onMapBadgeTap,
  });

  @override
  State<GuideArticleCard> createState() => _GuideArticleCardState();
}

class _GuideArticleCardState extends State<GuideArticleCard> {
  bool _isHovered = false;
  Future<String>? _signedCoverFuture;

  @override
  void initState() {
    super.initState();
    _loadCoverUrl();
  }

  @override
  void didUpdateWidget(GuideArticleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) {
      _loadCoverUrl();
    }
  }

  void _loadCoverUrl() {
    final url = widget.coverUrl;
    if (url != null && url.isNotEmpty) {
      _signedCoverFuture = ImageUrlService.instance.getSignedUrl(url);
    } else {
      _signedCoverFuture = null;
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
          transform: Matrix4.identity()
            ..scaleByDouble(_isHovered ? 1.02 : 1.0, _isHovered ? 1.02 : 1.0, 1.0, 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: GuideTokens.cardSurface(context),
            borderRadius: GuideTokens.borderRadius16,
            border: Border.all(
              color: GuideTokens.border(context),
              width: 1.0,
            ),
            boxShadow: _isHovered
                ? GuideTokens.shadowLg
                : GuideTokens.shadowSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面区域
              _buildCoverSection(isDark),

              // 内容区域
              Padding(
                padding: GuideTokens.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    _buildTitle(context, theme),
                    const SizedBox(height: GuideTokens.space8),

                    // 标签
                    if (widget.tags.isNotEmpty) ...[
                      _buildTags(context, theme),
                      const SizedBox(height: GuideTokens.space8),
                    ],

                    // 作者 + 元信息
                    _buildMeta(context, theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverSection(bool isDark) {
    return Stack(
      children: [
        // 封面图
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(GuideTokens.radius16),
          ),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _signedCoverFuture != null
                ? FutureBuilder<String>(
                    future: _signedCoverFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return DiskCachedImage(
                          imageUrl: snapshot.data!,
                          fit: BoxFit.cover,
                          cacheWidth: 480,
                          cacheHeight: 270,
                        );
                      }
                      return _buildFallbackCover(isDark);
                    },
                  )
                : _buildFallbackCover(isDark),
          ),
        ),

        // 视频角标（左下）
        if (widget.hasVideo)
          Positioned(
            bottom: GuideTokens.space8,
            left: GuideTokens.space8,
            child: _buildVideoBadge(),
          ),

        // 地图角标（右下）
        if (widget.mapName != null && widget.mapLabel != null)
          Positioned(
            bottom: GuideTokens.space8,
            right: GuideTokens.space8,
            child: GuideMapBadgeChip(
              mapBackground: widget.mapBackground,
              mapLabel: widget.mapLabel!,
              onTap: widget.onMapBadgeTap,
            ),
          ),
      ],
    );
  }

  Widget _buildFallbackCover(bool isDark) {
    return Container(
      color: isDark ? GuideTokens.fallbackBgDark : GuideTokens.fallbackBgLight,
      child: Center(
        child: Icon(
          Icons.article_outlined,
          size: 40,
          color: GuideTokens.fallbackIcon,
        ),
      ),
    );
  }

  Widget _buildVideoBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GuideTokens.space8,
        vertical: GuideTokens.space4,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: GuideTokens.borderRadius8,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_outline, size: 12, color: Colors.white),
          SizedBox(width: 2),
          Text(
            '视频',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.categoryName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: GuideTokens.space4),
            child: Text(
              widget.categoryName!.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: GuideTokens.textTertiary(context),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        Text(
          widget.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : GuideTokens.textPrimary(context),
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.summary != null && widget.summary!.isNotEmpty) ...[
          const SizedBox(height: GuideTokens.space4),
          Text(
            widget.summary!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: GuideTokens.textTertiary(context),
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildTags(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Wrap(
      spacing: GuideTokens.space4,
      runSpacing: GuideTokens.space4,
      children: widget.tags.take(3).map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GuideTokens.space8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
            borderRadius: GuideTokens.borderRadius8,
          ),
          child: Text(
            '#$tag',
            style: theme.textTheme.labelSmall?.copyWith(
              color: GuideTokens.textSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMeta(BuildContext context, ThemeData theme) {
    final statColor = GuideTokens.textTertiary(context);
    final statStyle = theme.textTheme.labelSmall?.copyWith(
      color: statColor,
      fontSize: 11,
    );

    return Row(
      children: [
        // 作者头像
        if (widget.authorAvatar != null) ...[
          CircleAvatar(
            radius: 8,
            backgroundImage: NetworkImage(widget.authorAvatar!),
          ),
          const SizedBox(width: GuideTokens.space4),
        ] else ...[
          const CircleAvatar(
            radius: 8,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, size: 10, color: Colors.white),
          ),
          const SizedBox(width: GuideTokens.space4),
        ],
        // 作者名
        Expanded(
          child: Text(
            widget.authorName,
            style: theme.textTheme.bodySmall?.copyWith(
              color: GuideTokens.textSecondary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // 互动数据
        Icon(Icons.visibility_outlined, size: 12, color: statColor),
        const SizedBox(width: 2),
        Text(_formatCount(widget.viewCount), style: statStyle),
        const SizedBox(width: GuideTokens.space8),
        Icon(Icons.favorite_border, size: 12, color: statColor),
        const SizedBox(width: 2),
        Text(_formatCount(widget.likeCount), style: statStyle),
      ],
    );
  }



  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}w';
    }
    return count.toString();
  }
}
