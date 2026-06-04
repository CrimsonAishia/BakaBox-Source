import 'package:flutter/material.dart';

import '../../services/image_url_service.dart';
import '../disk_cached_image.dart';
import 'guide_tokens.dart';

/// 详情页 AuthorBar 下方地图横幅
///
/// 高度 88，包含：
/// - 左侧 mapBackground 80×64
/// - 中部 mapName · mapLabel + 攻略数 + 标签摘要
/// - 右侧「查看地图详情」+「更多该地图攻略」双按钮
///
/// 用法：
/// ```dart
/// GuideMapBanner(
///   mapName: guide.mapName!,
///   mapLabel: guide.mapLabel ?? '',
///   mapBackground: guide.mapBackground,
///   guideCount: 12,
///   tagsSummary: 'ZE · 困难 · 长图',
///   onViewMapDetail: () => DesktopNavigator.openMapDatabase(mapName: ...),
///   onMoreGuides: () => DesktopNavigator.openGuides(mapName: ...),
/// )
/// ```
class GuideMapBanner extends StatefulWidget {
  /// 地图技术名（主键）
  final String mapName;

  /// 地图展示名称
  final String mapLabel;

  /// 地图背景图 URL
  final String? mapBackground;

  /// 该地图攻略数
  final int guideCount;

  /// 标签摘要文本（如 'ZE · 困难 · 长图'）
  final String? tagsSummary;

  /// 查看地图详情回调
  final VoidCallback? onViewMapDetail;

  /// 更多该地图攻略回调
  final VoidCallback? onMoreGuides;

  const GuideMapBanner({
    super.key,
    required this.mapName,
    required this.mapLabel,
    this.mapBackground,
    this.guideCount = 0,
    this.tagsSummary,
    this.onViewMapDetail,
    this.onMoreGuides,
  });

  @override
  State<GuideMapBanner> createState() => _GuideMapBannerState();
}

class _GuideMapBannerState extends State<GuideMapBanner> {
  Future<String>? _signedUrlFuture;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  @override
  void didUpdateWidget(GuideMapBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapBackground != widget.mapBackground) {
      _loadSignedUrl();
    }
  }

  void _loadSignedUrl() {
    final bg = widget.mapBackground;
    if (bg != null && bg.isNotEmpty) {
      _signedUrlFuture = ImageUrlService.instance.getSignedUrl(bg);
    } else {
      _signedUrlFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(
        horizontal: GuideTokens.space16,
        vertical: GuideTokens.space12,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: GuideTokens.borderRadius12,
        border: Border.all(
          color: GuideTokens.divider(context),
        ),
      ),
      child: Row(
        children: [
          // 左侧地图背景图
          _buildMapImage(isDark),
          const SizedBox(width: GuideTokens.space12),

          // 中部信息
          Expanded(child: _buildInfo(context, theme)),

          const SizedBox(width: GuideTokens.space12),

          // 右侧双按钮
          _buildActions(context, theme),
        ],
      ),
    );
  }

  Widget _buildMapImage(bool isDark) {
    return ClipRRect(
      borderRadius: GuideTokens.borderRadius8,
      child: SizedBox(
        width: 80,
        height: 64,
        child: _signedUrlFuture != null
            ? FutureBuilder<String>(
                future: _signedUrlFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return DiskCachedImage(
                      imageUrl: snapshot.data!,
                      fit: BoxFit.cover,
                      cacheWidth: 160,
                      cacheHeight: 128,
                    );
                  }
                  return _buildFallbackImage(isDark);
                },
              )
            : _buildFallbackImage(isDark),
      ),
    );
  }

  Widget _buildFallbackImage(bool isDark) {
    return Container(
      color: isDark ? GuideTokens.fallbackBgDark : GuideTokens.fallbackBgLight,
      child: const Center(
        child: Icon(Icons.map_outlined, size: 28, color: GuideTokens.fallbackIcon),
      ),
    );
  }

  Widget _buildInfo(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // mapName · mapLabel
        Text(
          '${widget.mapName} · ${widget.mapLabel}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: GuideTokens.textPrimary(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: GuideTokens.space4),

        // 攻略数 + 标签摘要
        Text(
          _buildSubtitle(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: GuideTokens.textSecondary(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (widget.guideCount > 0) {
      parts.add('${widget.guideCount} 篇攻略');
    }
    if (widget.tagsSummary != null && widget.tagsSummary!.isNotEmpty) {
      parts.add(widget.tagsSummary!);
    }
    return parts.join(' · ');
  }

  Widget _buildActions(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _ActionTextButton(
          label: '查看地图详情',
          onTap: widget.onViewMapDetail,
        ),
        const SizedBox(height: GuideTokens.space4),
        _ActionTextButton(
          label: '更多该地图攻略',
          onTap: widget.onMoreGuides,
        ),
      ],
    );
  }
}

/// 横幅内文字按钮（紧凑型）
class _ActionTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _ActionTextButton({
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GuideTokens.space8,
          vertical: GuideTokens.space4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right,
              size: 14,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
