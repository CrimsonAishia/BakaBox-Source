import 'package:flutter/material.dart';

import '../../services/image_url_service.dart';
import '../disk_cached_image.dart';
import 'guide_map_badge_chip.dart';
import 'guide_tokens.dart';
import '../../constants/app_colors.dart';

/// 攻略列表置顶/推荐大卡
///
/// 用于 Pinned 行（最多 3 条置顶）展示，比普通卡片更大更醒目。
/// 水平布局：左侧封面（宽 240）+ 右侧信息（标题 + 摘要 + 标签 + 元信息）。
///
/// 遵循 cardTheme：95% 透明白 + 1.5px 描边 + 16 圆角。
/// hover 效果：scale 1.02 + 200ms easeOutCubic + shadow 升级。
///
/// 用法：
/// ```dart
/// GuidePinnedHeroCard(
///   title: '置顶攻略标题',
///   summary: '攻略摘要描述...',
///   coverUrl: item.coverUrl,
///   categoryName: item.categoryName,
///   categoryColorHex: item.categoryColorHex,
///   tags: item.tags,
///   authorName: item.authorName,
///   viewCount: item.viewCount,
///   likeCount: item.likeCount,
///   mapName: item.mapName,
///   mapLabel: item.mapLabel,
///   mapBackground: item.mapBackground,
///   onTap: () => showDetail(item.id),
///   onMapBadgeTap: () => navigateToMap(item.mapName),
/// )
/// ```
class GuidePinnedHeroCard extends StatefulWidget {
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

  /// 是否为推荐
  final bool isRecommended;

  /// 是否为置顶
  final bool isPinned;

  /// 卡片点击回调
  final VoidCallback? onTap;

  /// 地图角标点击回调
  final VoidCallback? onMapBadgeTap;

  const GuidePinnedHeroCard({
    super.key,
    required this.title,
    this.summary,
    this.coverUrl,
    this.categoryName,
    this.categoryColorHex,
    this.tags = const [],
    required this.authorName,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.mapName,
    this.mapLabel,
    this.mapBackground,
    this.isRecommended = false,
    this.isPinned = false,
    this.onTap,
    this.onMapBadgeTap,
  });

  @override
  State<GuidePinnedHeroCard> createState() => _GuidePinnedHeroCardState();
}

class _GuidePinnedHeroCardState extends State<GuidePinnedHeroCard> {
  bool _isHovered = false;
  Future<String>? _signedCoverFuture;

  @override
  void initState() {
    super.initState();
    _loadCoverUrl();
  }

  @override
  void didUpdateWidget(GuidePinnedHeroCard oldWidget) {
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
          transform: Matrix4.diagonal3Values(
            _isHovered ? 1.02 : 1.0,
            _isHovered ? 1.02 : 1.0,
            1.0,
          ),
          transformAlignment: Alignment.center,
          height: 240,
          decoration: BoxDecoration(
            color: GuideTokens.cardSurface(context),
            borderRadius: GuideTokens.borderRadius16,
          ),
          clipBehavior:
              Clip.antiAlias, // ensure children don't overflow borderRadius
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 底部图片铺满
              _buildCoverImage(isDark),

              // 悬浮文字渐变层
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 140, // Height for the gradient
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.9),
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // 底部文本
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(GuideTokens.space16),
                  child: _buildContent(context, theme),
                ),
              ),

              // 置顶/推荐标签（左上）
              if (widget.isPinned || widget.isRecommended)
                Positioned(
                  top: GuideTokens.space8,
                  left: GuideTokens.space8,
                  child: _buildPinnedBadge(),
                ),

              // 地图角标（右下）
              if (widget.mapName != null && widget.mapLabel != null)
                Positioned(
                  top: GuideTokens.space8,
                  right: GuideTokens.space8,
                  child: GuideMapBadgeChip(
                    mapBackground: widget.mapBackground,
                    mapLabel: widget.mapLabel!,
                    onTap: widget.onMapBadgeTap,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(bool isDark) {
    if (_signedCoverFuture != null) {
      return FutureBuilder<String>(
        future: _signedCoverFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return DiskCachedImage(imageUrl: snapshot.data!, fit: BoxFit.cover);
          }
          return _buildFallbackCover(isDark);
        },
      );
    }
    return _buildFallbackCover(isDark);
  }

  Widget _buildFallbackCover(bool isDark) {
    return Container(
      color: isDark ? GuideTokens.fallbackBgDark : GuideTokens.fallbackBgLight,
      child: Center(
        child: Icon(
          Icons.article_outlined,
          size: 48,
          color: GuideTokens.fallbackIcon,
        ),
      ),
    );
  }

  Widget _buildPinnedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GuideTokens.space8,
        vertical: GuideTokens.space4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
        borderRadius: GuideTokens.borderRadius8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.push_pin, size: 12, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            widget.isPinned ? '置顶' : '推荐',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Text(
          widget.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white, // 始终为白色
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: GuideTokens.space8),

        // 标签（胶囊样式，原型中是蓝底/灰底的 #标签）
        if (widget.tags.isNotEmpty)
          Wrap(
            spacing: GuideTokens.space8,
            runSpacing: GuideTokens.space4,
            children: widget.tags.take(2).toList().asMap().entries.map((entry) {
              final isFirst = entry.key == 0;
              final tag = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: GuideTokens.space8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isFirst
                      ? AppColors.primary
                      : (theme.brightness == Brightness.dark
                            ? Colors.white24
                            : Colors.white60),
                  borderRadius: GuideTokens.borderRadius8,
                ),
                child: Text(
                  '#$tag',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: isFirst ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
