import 'package:flutter/material.dart';

import '../../../../core/bloc/guide_mine/guide_mine_event.dart';
import '../community_guide/community_guide_theme.dart';

/// 「我的中心」错误状态
class GuideMineErrorState extends StatelessWidget {
  /// 错误描述；null 时显示「加载失败」
  final String? error;
  final VoidCallback onRetry;

  const GuideMineErrorState({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: colors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            error ?? '加载失败',
            style: TextStyle(fontSize: 14, color: colors.textSecondary),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: colors.accentBlue,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

/// 「我的中心」空状态（按 Tab 显示对应图标与文案）
class GuideMineEmptyState extends StatelessWidget {
  /// 当前激活的 Tab，决定空态插画与提示文案
  final MineTab tab;

  const GuideMineEmptyState({super.key, required this.tab});

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);

    final (icon, title, subtitle) = switch (tab) {
      MineTab.published => (
        Icons.article_outlined,
        '还没有发布的攻略',
        '点击右上角「新建攻略」开始创作',
      ),
      MineTab.drafts => (
        Icons.edit_note_outlined,
        '没有草稿',
        '编辑器自动保存的草稿会出现在这里',
      ),
      MineTab.favorites => (
        Icons.bookmark_border,
        '还没有收藏攻略',
        '在攻略详情页点击收藏按钮即可加入这里',
      ),
      MineTab.liked => (
        Icons.thumb_up_outlined,
        '还没有赞过的攻略',
        '点赞过的攻略会显示在这里',
      ),
      MineTab.trash => (
        Icons.delete_outline,
        '回收站是空的',
        '删除的攻略会保留 30 天，可在此恢复',
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 72,
              color: colors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
