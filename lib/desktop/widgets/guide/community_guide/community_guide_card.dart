import 'package:flutter/material.dart';

import '../../../../core/models/guide_models.dart';
import '../../../../core/widgets/signed_network_image.dart';
import 'community_guide_fallback.dart';
import 'community_guide_format.dart';
import 'community_guide_theme.dart';

/// 攻略列表卡片
///
/// 包含封面（带置顶徽标）、标题、摘要、标签、作者元信息。
/// 主题色由 [CommunityGuideColors] 统一提供，亮/暗自适配。
class CommunityGuideCard extends StatefulWidget {
  final GuideListItem item;
  final VoidCallback onTap;

  const CommunityGuideCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<CommunityGuideCard> createState() => _CommunityGuideCardState();
}

class _CommunityGuideCardState extends State<CommunityGuideCard> {
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
        transform: Matrix4.identity()
          ..translateByDouble(0.0, _hovering ? -3.0 : 0.0, 0.0, 1.0),
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
                        if (item.isPinned)
                          const Positioned(
                            top: 8,
                            right: 8,
                            child: CommunityGuidePinnedBadge(),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if ((item.summary ?? '').isNotEmpty) ...[
                        Text(
                          item.summary!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.3,
                            color: colors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      _CardTagRow(
                        tags: item.tags,
                        categoryName: item.categoryName,
                        maxItems: 2,
                      ),
                      const SizedBox(height: 10),
                      _CardMetaRow(item: item),
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

// ===========================================================================
// 置顶徽章
// ===========================================================================

class CommunityGuidePinnedBadge extends StatelessWidget {
  const CommunityGuidePinnedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.push_pin, size: 14, color: Colors.white),
          SizedBox(width: 4),
          Text(
            '置顶',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 标签行
// ===========================================================================

class _CardTagRow extends StatelessWidget {
  final List<String> tags;
  final String? categoryName;
  final int maxItems;

  const _CardTagRow({
    required this.tags,
    required this.categoryName,
    this.maxItems = 2,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    final chips = <Widget>[];

    if (categoryName != null && categoryName!.isNotEmpty) {
      chips.add(_chip(label: '#$categoryName', primary: true, colors: colors));
    }

    for (final t in tags) {
      if (chips.length >= maxItems) break;
      if (t.trim().isEmpty) continue;
      chips.add(
        _chip(label: '#$t', primary: chips.isEmpty, colors: colors),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips,
    );
  }

  Widget _chip({
    required String label,
    required bool primary,
    required CommunityGuideColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: primary ? colors.accentBlue : colors.tagSecondaryBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: primary ? Colors.white : colors.tagSecondaryText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ===========================================================================
// 元信息行（作者、浏览数、点赞数）
// ===========================================================================

class _CardMetaRow extends StatelessWidget {
  final GuideListItem item;

  const _CardMetaRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return Row(
      children: [
        CommunityGuideAuthorAvatar(
          avatarUrl: item.authorAvatar,
          fallbackId: item.authorId,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            item.authorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
        ),
        Icon(
          Icons.remove_red_eye_outlined,
          size: 18,
          color: colors.textTertiary,
        ),
        const SizedBox(width: 6),
        Text(
          formatGuideCount(item.viewCount),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.textTertiary,
          ),
        ),
        const SizedBox(width: 14),
        Icon(
          Icons.favorite,
          size: 18,
          color: colors.likeRed,
        ),
        const SizedBox(width: 6),
        Text(
          formatGuideCount(item.likeCount),
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

// ===========================================================================
// 作者头像
// ===========================================================================

class CommunityGuideAuthorAvatar extends StatelessWidget {
  final String? avatarUrl;
  final int fallbackId;

  const CommunityGuideAuthorAvatar({
    super.key,
    required this.avatarUrl,
    required this.fallbackId,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = CommunityGuideFallback.gradient(fallbackId);
    final placeholder = Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: fallback),
      ),
    );

    return ClipOval(
      child: SizedBox(
        width: 22,
        height: 22,
        child: SignedNetworkImage(
          url: avatarUrl,
          fallback: placeholder,
          cacheWidth: 64,
          cacheHeight: 64,
        ),
      ),
    );
  }
}

// ===========================================================================
// 封面图
// ===========================================================================

class CommunityGuideCoverImage extends StatelessWidget {
  final String? coverUrl;
  final int fallbackId;

  const CommunityGuideCoverImage({
    super.key,
    required this.coverUrl,
    required this.fallbackId,
  });

  @override
  Widget build(BuildContext context) {
    return SignedNetworkImage(
      url: coverUrl,
      fallback: _buildFallback(),
      cacheWidth: 600,
      cacheHeight: 360,
    );
  }

  Widget _buildFallback() {
    final colors = CommunityGuideFallback.gradient(fallbackId);
    final icon = CommunityGuideFallback.icon(fallbackId);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 64,
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}

// ===========================================================================
// 卡片骨架屏
// ===========================================================================

class CommunityGuideCardSkeleton extends StatelessWidget {
  const CommunityGuideCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
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
              child: Container(color: colors.skeletonBg),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _bar(colors, width: double.infinity, height: 10),
                const SizedBox(height: 6),
                _bar(colors, width: 160, height: 10),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _bar(colors, width: 80, height: 10),
                    const SizedBox(width: 6),
                    _bar(colors, width: 60, height: 10),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(
    CommunityGuideColors colors, {
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.skeletonBar,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
