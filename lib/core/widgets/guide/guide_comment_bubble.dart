import 'package:flutter/material.dart';

import '../../models/guide_models.dart';
import '../../utils/formatters.dart';
import '../disk_cached_image.dart';
import 'guide_tokens.dart';

/// 评论气泡组件（含楼中楼）
///
/// 渲染：头像 24 圆 + 昵称 + 楼主 chip（isAuthor） + 内容气泡（surface 60% / borderRadius 12 / padding 12）
/// + 时间 + [回复] [赞] [更多] 操作。
///
/// 楼中楼回复：36px 缩进 + 1px 主色 20% 连接线。
///
/// 用法：
/// ```dart
/// GuideCommentBubble(
///   comment: comment,
///   currentUserId: authBloc.userId,
///   onReply: (comment) => expandReplyInput(comment),
///   onLike: (id) => bloc.add(ToggleCommentLike(id)),
///   onDelete: (id) => bloc.add(DeleteComment(id)),
///   onReport: (id) => ReportDialog.show(context, targetId: id, targetType: 'comment'),
///   onBlock: (userId) => bloc.add(UpdateBlockedUsers(...)),
///   onImageTap: (urls, index) => ImageViewerDialog.show(context, imageUrls: urls, initialIndex: index),
/// )
/// ```
class GuideCommentBubble extends StatelessWidget {
  /// 评论数据
  final GuideComment comment;

  /// 当前登录用户 ID（null 表示未登录）
  final int? currentUserId;

  /// 楼中楼回复列表
  final List<GuideComment> replies;

  /// 是否为嵌套回复（缩进）
  final bool isNested;

  /// 点击「回复」
  final ValueChanged<GuideComment>? onReply;

  /// 点击「赞」
  final ValueChanged<int>? onLike;

  /// 点击「删除」（作者本人）
  final ValueChanged<int>? onDelete;

  /// 点击「举报」
  final ValueChanged<int>? onReport;

  /// 点击「拉黑」
  final ValueChanged<int>? onBlock;

  /// 点击评论图片
  final void Function(List<String> urls, int index)? onImageTap;

  /// 「展开更多回复」按钮点击
  final ValueChanged<int>? onExpandReplies;

  /// 总回复数（用于显示「展开 N 条回复」）
  final int totalReplyCount;

  /// 是否已全部展开
  final bool repliesExpanded;

  const GuideCommentBubble({
    super.key,
    required this.comment,
    this.currentUserId,
    this.replies = const [],
    this.isNested = false,
    this.onReply,
    this.onLike,
    this.onDelete,
    this.onReport,
    this.onBlock,
    this.onImageTap,
    this.onExpandReplies,
    this.totalReplyCount = 0,
    this.repliesExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (comment.isDeleted) {
      return _buildDeletedPlaceholder(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMainBubble(context),
        // 楼中楼回复
        if (!isNested && replies.isNotEmpty) _buildReplies(context),
        // 展开更多回复按钮
        if (!isNested && !repliesExpanded && totalReplyCount > replies.length)
          _buildExpandButton(context),
      ],
    );
  }

  Widget _buildDeletedPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GuideTokens.space8),
      child: Row(
        children: [
          // 头像占位
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: GuideTokens.textTertiary(context).withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: GuideTokens.space8),
          Text(
            '该评论已删除',
            style: theme.textTheme.bodySmall?.copyWith(
              color: GuideTokens.textTertiary(context),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainBubble(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GuideTokens.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像 24 circle
          _buildAvatar(context),
          const SizedBox(width: GuideTokens.space8),
          // 内容区
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 昵称行
                _buildNicknameRow(context, theme),
                const SizedBox(height: GuideTokens.space4),
                // 回复目标提示
                if (comment.replyToName != null) ...[
                  _buildReplyToHint(context, theme),
                  const SizedBox(height: GuideTokens.space4),
                ],
                // 内容气泡
                _buildContentBubble(context, theme, isDark),
                // 评论图片
                if (comment.images.isNotEmpty) ...[
                  const SizedBox(height: GuideTokens.space8),
                  _buildImages(context),
                ],
                const SizedBox(height: GuideTokens.space8),
                // 操作行：时间 + 回复 + 赞 + 更多
                _buildActions(context, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: 24,
        height: 24,
        child: comment.authorAvatar != null && comment.authorAvatar!.isNotEmpty
            ? DiskCachedImage(
                imageUrl: comment.authorAvatar!,
                fit: BoxFit.cover,
                cacheWidth: 48,
                cacheHeight: 48,
              )
            : Container(
                color: GuideTokens.commentBlue.withValues(alpha: 0.2),
                child: Center(
                  child: Text(
                    comment.authorName.isNotEmpty
                        ? comment.authorName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: GuideTokens.commentBlue,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildNicknameRow(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        // 昵称
        Flexible(
          child: Text(
            comment.authorName,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: GuideTokens.textPrimary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 楼主 chip
        if (comment.isAuthor) ...[
          const SizedBox(width: GuideTokens.space4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '楼主',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReplyToHint(BuildContext context, ThemeData theme) {
    return Text(
      '回复 @${comment.replyToName}',
      style: theme.textTheme.labelSmall?.copyWith(
        color: GuideTokens.textTertiary(context),
      ),
    );
  }

  Widget _buildContentBubble(
      BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GuideTokens.space12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: GuideTokens.borderRadius12,
      ),
      child: Text(
        comment.content,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: GuideTokens.textPrimary(context),
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildImages(BuildContext context) {
    final images = comment.images.take(3).toList();
    return Wrap(
      spacing: GuideTokens.space8,
      runSpacing: GuideTokens.space8,
      children: images.asMap().entries.map((entry) {
        final index = entry.key;
        final url = entry.value;
        return GestureDetector(
          onTap: () => onImageTap?.call(comment.images, index),
          child: ClipRRect(
            borderRadius: GuideTokens.borderRadius8,
            child: SizedBox(
              width: 120,
              height: 120,
              child: DiskCachedImage(
                imageUrl: url,
                fit: BoxFit.cover,
                cacheWidth: 240,
                cacheHeight: 240,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActions(BuildContext context, ThemeData theme) {
    final actionColor = GuideTokens.textTertiary(context);
    final actionStyle = theme.textTheme.labelSmall?.copyWith(
      color: actionColor,
      fontSize: 12,
    );

    return Row(
      children: [
        // 时间
        Text(
          Formatters.formatRelativeTime(comment.createdAt),
          style: actionStyle,
        ),
        const SizedBox(width: GuideTokens.space16),
        // 回复
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          label: '回复',
          color: actionColor,
          onTap: () => onReply?.call(comment),
        ),
        const SizedBox(width: GuideTokens.space12),
        // 赞
        _ActionButton(
          icon: comment.isLiked
              ? Icons.thumb_up
              : Icons.thumb_up_outlined,
          label: comment.likeCount > 0 ? '${comment.likeCount}' : '赞',
          color: comment.isLiked
              ? GuideTokens.likeColor(context)
              : actionColor,
          onTap: () => onLike?.call(comment.id),
        ),
        const SizedBox(width: GuideTokens.space12),
        // 更多菜单
        _MoreMenuButton(
          comment: comment,
          currentUserId: currentUserId,
          onDelete: onDelete,
          onReport: onReport,
          onBlock: onBlock,
        ),
      ],
    );
  }

  Widget _buildReplies(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 36),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: GuideTokens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: replies.map((reply) {
            return GuideCommentBubble(
              comment: reply,
              currentUserId: currentUserId,
              isNested: true,
              onReply: onReply,
              onLike: onLike,
              onDelete: onDelete,
              onReport: onReport,
              onBlock: onBlock,
              onImageTap: onImageTap,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildExpandButton(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = totalReplyCount - replies.length;
    return Padding(
      padding: const EdgeInsets.only(left: 36 + GuideTokens.space12),
      child: TextButton.icon(
        onPressed: () => onExpandReplies?.call(comment.id),
        icon: Icon(
          Icons.expand_more,
          size: 16,
          color: theme.colorScheme.primary,
        ),
        label: Text(
          '展开 $remaining 条回复',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: GuideTokens.space8,
            vertical: GuideTokens.space4,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

// ─── 私有子组件 ────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GuideTokens.space4,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreMenuButton extends StatelessWidget {
  final GuideComment comment;
  final int? currentUserId;
  final ValueChanged<int>? onDelete;
  final ValueChanged<int>? onReport;
  final ValueChanged<int>? onBlock;

  const _MoreMenuButton({
    required this.comment,
    this.currentUserId,
    this.onDelete,
    this.onReport,
    this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    final actionColor = GuideTokens.textTertiary(context);
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, size: 16, color: actionColor),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      style: IconButton.styleFrom(
        minimumSize: const Size(28, 28),
        padding: const EdgeInsets.all(4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      itemBuilder: (context) {
        final isOwnComment = currentUserId != null &&
            currentUserId == comment.authorId;
        return [
          if (isOwnComment)
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 16),
                  SizedBox(width: 8),
                  Text('删除'),
                ],
              ),
            )
          else ...[
            const PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('举报'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  Icon(Icons.block, size: 16),
                  SizedBox(width: 8),
                  Text('拉黑此用户'),
                ],
              ),
            ),
          ],
        ];
      },
      onSelected: (value) {
        switch (value) {
          case 'delete':
            onDelete?.call(comment.id);
          case 'report':
            onReport?.call(comment.id);
          case 'block':
            onBlock?.call(comment.authorId);
        }
      },
    );
  }
}
