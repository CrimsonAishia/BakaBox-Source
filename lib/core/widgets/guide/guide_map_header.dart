import 'package:flutter/material.dart';

import '../../services/image_url_service.dart';
import '../disk_cached_image.dart';
import 'guide_tokens.dart';

/// 列表页 `?mapName=xxx` 模式下替代 `GuideHeroBanner` 的 Header
///
/// 高度 168 / 圆角 24，布局：
/// - 左侧 mapBackground 96×96
/// - 中部 headlineMedium 地图标题 + 副标题（攻略数等）
/// - 右侧「查看地图详情」「发布该地图攻略」双按钮
///
/// 用法：
/// ```dart
/// GuideMapHeader(
///   mapName: 'ze_minecraft',
///   mapLabel: '我的世界',
///   mapBackground: mapInfo.mapBackground,
///   guideCount: 42,
///   onViewMapDetail: () => DesktopNavigator.openMapDatabase(mapName: ...),
///   onPublishGuide: () => openEditor(prefillMapName: ...),
///   onBack: () => _showList(mapName: null),
/// )
/// ```
class GuideMapHeader extends StatefulWidget {
  /// 地图技术名
  final String mapName;

  /// 地图展示名称
  final String mapLabel;

  /// 地图背景图 URL
  final String? mapBackground;

  /// 该地图攻略总数
  final int guideCount;

  /// 查看地图详情回调
  final VoidCallback? onViewMapDetail;

  /// 发布该地图攻略回调
  final VoidCallback? onPublishGuide;

  /// 返回全部攻略回调
  final VoidCallback? onBack;

  const GuideMapHeader({
    super.key,
    required this.mapName,
    required this.mapLabel,
    this.mapBackground,
    this.guideCount = 0,
    this.onViewMapDetail,
    this.onPublishGuide,
    this.onBack,
  });

  @override
  State<GuideMapHeader> createState() => _GuideMapHeaderState();
}

class _GuideMapHeaderState extends State<GuideMapHeader> {
  Future<String>? _signedUrlFuture;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  @override
  void didUpdateWidget(GuideMapHeader oldWidget) {
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
      height: 168,
      decoration: BoxDecoration(
        borderRadius: GuideTokens.borderRadius24,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  GuideTokens.gradientDarkStart,
                  GuideTokens.gradientDarkEnd,
                ]
              : [
                  theme.colorScheme.primary.withValues(alpha: 0.06),
                  theme.colorScheme.primary.withValues(alpha: 0.02),
                ],
        ),
        border: Border.all(
          color: GuideTokens.divider(context),
        ),
      ),
      padding: const EdgeInsets.all(GuideTokens.space24),
      child: Row(
        children: [
          // 左侧地图背景
          _buildMapImage(isDark),
          const SizedBox(width: GuideTokens.space24),

          // 中部信息
          Expanded(child: _buildInfo(context, theme)),

          const SizedBox(width: GuideTokens.space16),

          // 右侧按钮组
          _buildActions(context, theme),
        ],
      ),
    );
  }

  Widget _buildMapImage(bool isDark) {
    return ClipRRect(
      borderRadius: GuideTokens.borderRadius16,
      child: SizedBox(
        width: 96,
        height: 96,
        child: _signedUrlFuture != null
            ? FutureBuilder<String>(
                future: _signedUrlFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return DiskCachedImage(
                      imageUrl: snapshot.data!,
                      fit: BoxFit.cover,
                      cacheWidth: 192,
                      cacheHeight: 192,
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
      child: Center(
        child: Icon(Icons.map_outlined, size: 40, color: GuideTokens.fallbackIcon),
      ),
    );
  }

  Widget _buildInfo(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 返回全部攻略
        if (widget.onBack != null)
          Padding(
            padding: const EdgeInsets.only(bottom: GuideTokens.space8),
            child: InkWell(
              onTap: widget.onBack,
              borderRadius: BorderRadius.circular(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_ios,
                    size: 12,
                    color: GuideTokens.textSecondary(context),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '返回全部攻略',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: GuideTokens.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 地图标题（headlineMedium）
        Text(
          widget.mapLabel,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: GuideTokens.textPrimary(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: GuideTokens.space4),

        // 副标题
        Text(
          '${widget.mapName} · ${widget.guideCount} 篇攻略',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: GuideTokens.textSecondary(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildOutlinedButton(
          context: context,
          theme: theme,
          label: '查看地图详情',
          icon: Icons.map_outlined,
          onTap: widget.onViewMapDetail,
        ),
        const SizedBox(height: GuideTokens.space8),
        _buildFilledButton(
          context: context,
          theme: theme,
          label: '发布该地图攻略',
          icon: Icons.edit_outlined,
          onTap: widget.onPublishGuide,
        ),
      ],
    );
  }

  Widget _buildOutlinedButton({
    required BuildContext context,
    required ThemeData theme,
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: GuideTokens.space12,
          vertical: GuideTokens.space8,
        ),
        textStyle: theme.textTheme.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: GuideTokens.borderRadius8,
        ),
      ),
    );
  }

  Widget _buildFilledButton({
    required BuildContext context,
    required ThemeData theme,
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: GuideTokens.space12,
          vertical: GuideTokens.space8,
        ),
        textStyle: theme.textTheme.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: GuideTokens.borderRadius8,
        ),
      ),
    );
  }
}
