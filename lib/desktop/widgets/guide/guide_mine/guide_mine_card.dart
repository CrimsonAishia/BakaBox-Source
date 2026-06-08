import 'package:flutter/material.dart';

import '../../../../core/models/guide_models.dart';
import '../../../../core/widgets/guide/guide_tokens.dart';
import '../community_guide/community_guide_card.dart';
import '../community_guide/community_guide_format.dart';
import '../community_guide/community_guide_theme.dart';

/// 「我的中心」攻略卡片（瀑布流）
///
/// 与社区列表卡片的差异：
/// - 右上角带状态角标（审核中 / 未通过）或回收站到期角标
/// - 底部右侧有「更多」三点菜单（修改 / 删除）
/// - 不显示作者信息（本人即作者）
class GuideMineCard extends StatefulWidget {
  final GuideListItem item;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  /// 回收站 Tab 时显示剩余天数角标
  final bool showExpiryBadge;

  const GuideMineCard({
    super.key,
    required this.item,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onRestore,
    this.showExpiryBadge = false,
  });

  @override
  State<GuideMineCard> createState() => _GuideMineCardState();
}

class _GuideMineCardState extends State<GuideMineCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final colors = CommunityGuideColors.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hovering ? -3.0 : 0.0, 0),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(
                alpha: (_hovering ? 1.6 : 1.0) * colors.shadow.a,
              ),
              blurRadius: _hovering ? 20 : 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CommunityGuideCoverImage(
                          coverUrl: item.coverUrl,
                          fallbackId: item.id,
                        ),
                        if (item.status == GuideStatus.pending ||
                            item.status == GuideStatus.rejected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GuideMineStatusBadge(
                              status: item.status,
                              rejectReason: item.rejectReason,
                            ),
                          ),
                        if (widget.showExpiryBadge)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GuideMineExpiryBadge(
                              expireDays: item.expireDays,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if ((item.summary ?? '').isNotEmpty)
                        Text(
                          item.summary!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.3,
                            color: colors.textTertiary,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Row(
                          children: [
                            _StatLabel(
                              icon: Icons.remove_red_eye_outlined,
                              text: formatGuideCount(item.viewCount),
                            ),
                            const SizedBox(width: 14),
                            _StatLabel(
                              icon: Icons.favorite,
                              iconColor: colors.likeRed,
                              text: formatGuideCount(item.likeCount),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 32,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: GuideMineTagsRow(
                                tags: item.tags,
                                categoryName: item.categoryName,
                                maxItems: 2,
                              ),
                            ),
                            GuideMineMoreMenu(
                              status: item.status,
                              onEdit: widget.onEdit,
                              onDelete: widget.onDelete,
                              onRestore: widget.onRestore,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 角标 ──────────────────────────────────────────────────────────────────

class _CardBadge extends StatelessWidget {
  final Color bgColor;
  final IconData icon;
  final String label;
  final String? tooltip;

  const _CardBadge({
    required this.bgColor,
    required this.icon,
    required this.label,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}

class GuideMineStatusBadge extends StatelessWidget {
  final GuideStatus status;
  final String? rejectReason;

  const GuideMineStatusBadge({
    super.key,
    required this.status,
    this.rejectReason,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bgColor, IconData icon, String label) = switch (status) {
      GuideStatus.pending => (
        GuideTokens.statusPending.withValues(alpha: 0.9),
        Icons.schedule,
        '审核中',
      ),
      GuideStatus.rejected => (
        GuideTokens.statusRejected.withValues(alpha: 0.9),
        Icons.error_outline,
        '未通过',
      ),
      _ => (Colors.transparent, Icons.circle, ''),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    final tooltip = status == GuideStatus.rejected &&
            rejectReason != null &&
            rejectReason!.isNotEmpty
        ? '驳回原因：$rejectReason'
        : null;

    return _CardBadge(
      bgColor: bgColor,
      icon: icon,
      label: label,
      tooltip: tooltip,
    );
  }
}

/// 回收站卡片右上角：显示剩余自动删除天数
class GuideMineExpiryBadge extends StatelessWidget {
  final int expireDays;

  const GuideMineExpiryBadge({super.key, required this.expireDays});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color bgColor;
    if (expireDays <= 0) {
      label = '即将清理';
      bgColor = GuideTokens.statusRejected.withValues(alpha: 0.9);
    } else if (expireDays <= 7) {
      label = '$expireDays 天后清理';
      bgColor = GuideTokens.statusRejected.withValues(alpha: 0.9);
    } else {
      label = '$expireDays 天后清理';
      bgColor = GuideTokens.statusOffShelf.withValues(alpha: 0.9);
    }

    return _CardBadge(
      bgColor: bgColor,
      icon: Icons.timer_outlined,
      label: label,
    );
  }
}

// ─── 统计文字 ─────────────────────────────────────────────────────────────

class _StatLabel extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String text;

  const _StatLabel({
    required this.icon,
    required this.text,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: iconColor ?? colors.textTertiary,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.textTertiary,
          ),
        ),
      ],
    );
  }
}

// ─── 标签行 ─────────────────────────────────────────────────────────────

class GuideMineTagsRow extends StatelessWidget {
  final List<String> tags;
  final String? categoryName;
  /// 最多显示的 chip 数量（超出截断）
  final int maxItems;

  const GuideMineTagsRow({
    super.key,
    required this.tags,
    required this.categoryName,
    this.maxItems = 2,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    final chips = <Widget>[];

    if (categoryName != null && categoryName!.isNotEmpty) {
      chips.add(_chip(label: categoryName!, primary: true, colors: colors));
    }
    for (final t in tags) {
      if (chips.length >= maxItems) break;
      if (t.trim().isEmpty) continue;
      chips.add(_chip(label: t, primary: chips.isEmpty, colors: colors));
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Flexible(child: chips[i]),
        ],
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool primary,
    required CommunityGuideColors colors,
  }) {
    final bgColor = primary
        ? colors.accentBlue.withValues(alpha: colors.isDark ? 0.22 : 0.16)
        : colors.tagSecondaryBg;
    final textColor = primary
        ? colors.tagPrimaryText
        : colors.tagSecondaryText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── 三点菜单 ──────────────────────────────────────────────────────────────

class GuideMineMoreMenu extends StatelessWidget {
  final GuideStatus? status;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;

  const GuideMineMoreMenu({
    super.key,
    this.status,
    this.onEdit,
    this.onDelete,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        tooltip: '更多',
        icon: Icon(
          Icons.more_vert,
          size: 18,
          color: colors.textTertiary,
        ),
        padding: EdgeInsets.zero,
        iconSize: 18,
        splashRadius: 16,
        color: colors.menuBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        itemBuilder: (context) {
          final menuTextColor = colors.textPrimary;
          return [
            if (onRestore != null)
              PopupMenuItem<String>(
                value: 'restore',
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.restore_outlined,
                        size: 14, color: colors.accentBlue),
                    const SizedBox(width: 8),
                    Text(
                      '还原',
                      style: TextStyle(color: colors.accentBlue, fontSize: 12),
                    ),
                  ],
                ),
              ),
            if (onEdit != null)
              PopupMenuItem<String>(
                value: 'edit',
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined,
                        size: 14, color: menuTextColor),
                    const SizedBox(width: 8),
                    Text(
                      '修改',
                      style: TextStyle(color: menuTextColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            if (onDelete != null)
              PopupMenuItem<String>(
                value: 'delete',
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline,
                        size: 14, color: Colors.redAccent.shade100),
                    const SizedBox(width: 8),
                    Text(
                      '删除',
                      style: TextStyle(
                        color: Colors.redAccent.shade100,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ];
        },
        onSelected: (value) {
          if (value == 'restore') {
            onRestore?.call();
          } else if (value == 'edit') {
            onEdit?.call();
          } else if (value == 'delete') {
            _confirmDelete(context, colors);
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, CommunityGuideColors colors) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          '确认删除',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '删除后将移入回收站，30 天内可恢复。确定要删除吗？',
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              '取消',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('删除'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        onDelete?.call();
      }
    });
  }
}
