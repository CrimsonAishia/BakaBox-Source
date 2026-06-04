import 'package:flutter/material.dart';

import 'guide_tokens.dart';

/// 攻略列表页顶部 Hero Banner
///
/// 高度 168，渐变背景 + 标题 + 副标题 + 装饰元素。
/// 当列表处于 `mapName` 模式时由 `GuideMapHeader` 替代。
///
/// 用法：
/// ```dart
/// GuideHeroBanner(
///   title: '攻略社区',
///   subtitle: '发现精彩 CS2 攻略，分享你的游戏智慧',
/// )
/// ```
class GuideHeroBanner extends StatelessWidget {
  /// Banner 标题
  final String title;

  /// Banner 副标题
  final String subtitle;

  /// 右侧操作按钮点击回调（如"发布攻略"）
  final VoidCallback? onAction;

  /// 操作按钮文案
  final String? actionLabel;

  const GuideHeroBanner({
    super.key,
    this.title = '攻略社区',
    this.subtitle = '发现精彩 CS2 攻略，分享你的游戏智慧',
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : theme.colorScheme.primary.withValues(alpha: 0.1),
        border: Border.all(
          color: GuideTokens.divider(context),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: Center(
        child: _buildTextSection(context, theme),
      ),
    );
  }

  Widget _buildTextSection(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0), // Give space for the overlapping filter bar
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center, // Center text horizontally
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white, // Always white on dark overlay
              letterSpacing: 2.0,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: GuideTokens.space12),
          Text(
            subtitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

}
