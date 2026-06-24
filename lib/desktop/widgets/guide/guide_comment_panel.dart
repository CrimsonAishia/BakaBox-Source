import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/auth/auth_bloc.dart';
import '../../../core/bloc/guide_comment/guide_comment_bloc.dart';
import '../../../core/bloc/guide_comment/guide_comment_event.dart';
import '../../../core/bloc/guide_comment/guide_comment_state.dart';
import '../../../core/models/guide_models.dart';
import '../../../core/services/token_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../core/widgets/clickable_image.dart';
import '../../../core/widgets/common_report_dialog.dart';
import '../../../core/api/guide_api.dart';
import '../../../core/widgets/guide/guide_tokens.dart';
import '../../../core/widgets/rich_text_viewer.dart';
import '../../../core/widgets/signed_network_image.dart';
import '../../../core/constants/app_colors.dart';

/// 桌面端攻略评论面板
///
/// 主输入框由 [GuideBottomCommentComposer] 以 fixed 方式固定在详情页底部（B 站风格）；
/// 本面板负责：标题栏 / 排序切换 / 评论列表 / 楼中楼展开 / 行内 fallback 回复输入条。
///
/// 使用方须在外层提供 [BlocProvider<GuideCommentBloc>]，由 detail view 统一管理。
class GuideCommentPanel extends StatefulWidget {
  /// 来自 Guide 模型的评论总数初值（接口未返回 total 时回退使用）
  final int totalCountFromGuide;

  /// 用户点击「回复」时的回调，由父组件将 replyTarget 传给底部 composer
  final void Function(GuideComment target)? onReplyRequested;

  const GuideCommentPanel({
    super.key,
    required this.totalCountFromGuide,
    this.onReplyRequested,
  });

  @override
  State<GuideCommentPanel> createState() => GuideCommentPanelState();
}

class GuideCommentPanelState extends State<GuideCommentPanel> {
  /// 当前正在就地回复的评论（底部 composer 接管时此字段不使用）
  GuideComment? _replyTarget;
  late final TextEditingController _replyController;
  late final FocusNode _replyFocusNode;

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController();
    _replyFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  // ─── Auth helpers ───────────────────────────────────────────────────────

  int? _currentUserId(BuildContext context) {
    // 使用后端用户 ID（与评论的 authorId 同体系）
    return TokenService.instance.userInfo?.id;
  }

  bool _isLoggedIn(BuildContext context) =>
      context.read<AuthBloc>().state.isAuthenticated;

  String? _currentAvatarUrl(BuildContext context) {
    final info = context.read<AuthBloc>().state.userInfo;
    if (info == null || info.avatar.isEmpty) return null;
    return info.avatar;
  }

  String _currentDisplayName(BuildContext context) {
    final info = context.read<AuthBloc>().state.userInfo;
    return info?.username ?? '游客';
  }

  void _requireLogin() => ToastUtils.showInfo(context, '登录后才能参与互动');

  // ─── Reply ──────────────────────────────────────────────────────────────

  void _handleStartReply(GuideComment target) {
    if (!_isLoggedIn(context)) {
      _requireLogin();
      return;
    }

    // 优先委托给父组件（让底部 composer 接管）
    if (widget.onReplyRequested != null) {
      widget.onReplyRequested!(target);
      return;
    }

    // 兜底：本地行内回复
    setState(() {
      if (_replyTarget?.id == target.id) {
        _replyTarget = null;
        _replyController.clear();
      } else {
        _replyTarget = target;
        _replyController.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _replyFocusNode.requestFocus();
        });
      }
    });
  }

  void _handleSubmitReply(BuildContext context) {
    if (!_isLoggedIn(context) || _replyTarget == null) return;
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    final target = _replyTarget!;
    // 服务端 parentId=0 表示顶层，视为无父级
    final effectiveParentId = (target.parentId != null && target.parentId != 0)
        ? target.parentId
        : target.id;
    context.read<GuideCommentBloc>().add(
      PostComment(
        content: text,
        parentId: effectiveParentId,
        replyToId: target.id,
        replyToName: target.authorName,
      ),
    );
    setState(() {
      _replyTarget = null;
      _replyController.clear();
    });
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GuideCommentBloc, GuideCommentState>(
      listenWhen: (prev, curr) =>
          prev.error != curr.error && curr.error != null,
      listener: (context, state) {
        if (state.error != null) {
          ToastUtils.showError(context, state.error!);
        }
      },
      builder: (context, state) {
        return _buildPanel(context, state);
      },
    );
  }

  Widget _buildPanel(BuildContext context, GuideCommentState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final total = state.total > 0 ? state.total : widget.totalCountFromGuide;

    return Container(
      decoration: BoxDecoration(
        color: GuideTokens.cardSurface(context),
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : GuideTokens.borderLight,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(GuideTokens.space32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, state, total),
          const SizedBox(height: GuideTokens.space24),
          _buildList(context, state),
          if (state.hasMore && state.comments.isNotEmpty)
            _buildLoadMore(context, state),
        ],
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    GuideCommentState state,
    int total,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          '全部评论 ($total)',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: GuideTokens.textPrimary(context),
            fontSize: 20,
            letterSpacing: -0.3,
            height: 1.2,
          ),
        ),
        const Spacer(),
        _SortMenu(
          currentSort: state.sort,
          onChanged: (sort) =>
              context.read<GuideCommentBloc>().add(ChangeCommentSort(sort)),
        ),
      ],
    );
  }

  // ─── List ───────────────────────────────────────────────────────────────

  Widget _buildList(BuildContext context, GuideCommentState state) {
    if (state.status == CommentStatus.loading && state.comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: GuideTokens.space32),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (state.comments.isEmpty &&
        (state.status == CommentStatus.success ||
            state.status == CommentStatus.failure)) {
      return _buildEmpty(context);
    }

    return Column(
      children: [
        for (int i = 0; i < state.comments.length; i++) ...[
          _buildCommentItem(context, state, state.comments[i]),
          if (i < state.comments.length - 1)
            const SizedBox(height: GuideTokens.space24),
        ],
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GuideTokens.space32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 36,
              color: GuideTokens.textTertiary(context),
            ),
            const SizedBox(height: GuideTokens.space12),
            Text(
              '暂无评论，来发表第一条吧',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: GuideTokens.textTertiary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(
    BuildContext context,
    GuideCommentState state,
    GuideComment comment,
  ) {
    final replies = state.replyMaps[comment.id] ?? const [];
    final visibleReplies = replies.isNotEmpty
        ? replies
        : comment.replies.take(3).toList();
    final hasMoreReplies =
        replies.isEmpty && comment.replyCount > visibleReplies.length;

    final currentUid = _currentUserId(context);
    final isOwnComment = currentUid != null && currentUid == comment.authorId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentBubble(
          comment: comment,
          currentUserId: currentUid,
          showReplyToHint: false,
          onReply: () => _handleStartReply(comment),
          onLike: isOwnComment ? null : () => _handleLike(context, comment),
          onDislike: isOwnComment
              ? null
              : () => _handleDislike(context, comment),
          onDelete: () =>
              context.read<GuideCommentBloc>().add(DeleteComment(comment.id)),
          onReport: () => _handleReport(context, comment),
        ),
        if (visibleReplies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 56, top: GuideTokens.space16),
            child: _ReplyThread(
              parent: comment,
              replies: visibleReplies,
              currentUserId: _currentUserId(context),
              hasMoreReplies: hasMoreReplies,
              remainingCount: comment.replyCount - visibleReplies.length,
              onExpandMore: () =>
                  context.read<GuideCommentBloc>().add(LoadReplies(comment.id)),
              onReply: _handleStartReply,
              onLike: (c) => _handleLike(context, c),
              onDislike: (c) => _handleDislike(context, c),
              onDelete: (c) =>
                  context.read<GuideCommentBloc>().add(DeleteComment(c.id)),
              onReport: (c) => _handleReport(context, c),
            ),
          ),
        // 行内 fallback 回复输入条（仅在没有外部 onReplyRequested 时使用）
        if (widget.onReplyRequested == null &&
            _replyTarget != null &&
            (_replyTarget!.id == comment.id ||
                _replyTarget!.parentId == comment.id))
          Padding(
            padding: const EdgeInsets.only(left: 56, top: GuideTokens.space16),
            child: _buildInlineReplyInput(context),
          ),
      ],
    );
  }

  Widget _buildInlineReplyInput(BuildContext context) {
    final isLoggedIn = _isLoggedIn(context);
    final target = _replyTarget!;
    return AnimatedSize(
      duration: GuideTokens.durationNormal,
      curve: Curves.easeOutCubic,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CommentAvatar(
            avatarUrl: isLoggedIn ? _currentAvatarUrl(context) : null,
            displayName: isLoggedIn ? _currentDisplayName(context) : '游客',
            size: 36,
          ),
          const SizedBox(width: GuideTokens.space12),
          Expanded(
            child: _PillInput(
              controller: _replyController,
              focusNode: _replyFocusNode,
              hintText: '回复 @${target.authorName}',
              enabled: true,
              onSubmit: () => _handleSubmitReply(context),
            ),
          ),
          const SizedBox(width: GuideTokens.space12),
          TextButton(
            onPressed: () {
              setState(() {
                _replyTarget = null;
                _replyController.clear();
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: GuideTokens.textSecondary(context),
            ),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _handleLike(BuildContext context, GuideComment comment) {
    if (!_isLoggedIn(context)) {
      _requireLogin();
      return;
    }
    context.read<GuideCommentBloc>().add(ToggleCommentLike(comment.id));
  }

  void _handleDislike(BuildContext context, GuideComment comment) {
    if (!_isLoggedIn(context)) {
      _requireLogin();
      return;
    }
    context.read<GuideCommentBloc>().add(ToggleCommentDislike(comment.id));
  }

  void _handleReport(BuildContext context, GuideComment comment) {
    if (!_isLoggedIn(context)) {
      _requireLogin();
      return;
    }
    CommonReportDialog.show<ReportReason>(
      context,
      reasons: ReportReason.values
          .map((r) => ReportReasonItem(value: r, label: r.label))
          .toList(),
      onSubmit: (payload) async {
        final report = GuideReport(
          targetId: comment.id,
          targetType: 'comment',
          reason: payload.reason,
          description: payload.description,
          evidenceImages: payload.evidenceImages,
        );
        await GuideApi().report(report);
      },
    );
  }

  Widget _buildLoadMore(BuildContext context, GuideCommentState state) {
    final theme = Theme.of(context);
    final loading = state.status == CommentStatus.loadingMore;
    return Padding(
      padding: const EdgeInsets.only(top: GuideTokens.space24),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: () =>
                    context.read<GuideCommentBloc>().add(const LoadComments()),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GuideTokens.space20,
                    vertical: GuideTokens.space8,
                  ),
                ),
                child: Text(
                  '加载更多评论',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 评论气泡（含 hover 显示更多按钮）
// ═══════════════════════════════════════════════════════════════════════════

class _CommentBubble extends StatefulWidget {
  final GuideComment comment;
  final int? currentUserId;
  final bool showReplyToHint;
  final double avatarSize;
  final VoidCallback? onReply;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  const _CommentBubble({
    required this.comment,
    this.currentUserId,
    this.showReplyToHint = false,
    this.avatarSize = 44,
    this.onReply,
    this.onLike,
    this.onDislike,
    this.onDelete,
    this.onReport,
  });

  @override
  State<_CommentBubble> createState() => _CommentBubbleState();
}

class _CommentBubbleState extends State<_CommentBubble> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    if (widget.comment.isDeleted) {
      return _buildDeletedPlaceholder(context);
    }
    final theme = Theme.of(context);
    final comment = widget.comment;
    final isOwn =
        widget.currentUserId != null &&
        widget.currentUserId == comment.authorId;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentAvatar(
            avatarUrl: comment.authorAvatar,
            displayName: comment.authorName,
            size: widget.avatarSize,
          ),
          const SizedBox(width: GuideTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        comment.authorName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: GuideTokens.textPrimary(context),
                          fontSize: 15,
                          height: 1.2,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (comment.isAuthor) ...[
                      const SizedBox(width: GuideTokens.space8),
                      const _AuthorChip(),
                    ],
                  ],
                ),
                if (widget.showReplyToHint && comment.replyToName != null) ...[
                  const SizedBox(height: GuideTokens.space4),
                  Text(
                    '回复 @${comment.replyToName}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: GuideTokens.space8),
                // 评论内容（富文本 Delta JSON）
                RichTextViewer(
                  content: comment.content,
                  textStyle: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: GuideTokens.textPrimary(
                      context,
                    ).withValues(alpha: 0.92),
                  ),
                  compact: true,
                ),
                // 评论附图
                if (comment.images.isNotEmpty) ...[
                  const SizedBox(height: GuideTokens.space8),
                  ImageGrid(
                    imageUrls: comment.images,
                    imageWidth: 120,
                    imageHeight: 90,
                    spacing: 8,
                    borderRadius: 6,
                  ),
                ],
                const SizedBox(height: GuideTokens.space12),
                _CommentActions(
                  comment: comment,
                  isOwn: isOwn,
                  showActions: _hover,
                  onReply: widget.onReply,
                  onLike: widget.onLike,
                  onDislike: widget.onDislike,
                  onDelete: widget.onDelete,
                  onReport: widget.onReport,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletedPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: widget.avatarSize,
          height: widget.avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GuideTokens.textTertiary(context).withValues(alpha: 0.18),
          ),
        ),
        const SizedBox(width: GuideTokens.space12),
        Text(
          '该评论已删除',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: GuideTokens.textTertiary(context),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _AuthorChip extends StatelessWidget {
  const _AuthorChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fill = isDark
        ? const Color(0xFF60A5FA).withValues(alpha: 0.18)
        : theme.colorScheme.primary.withValues(alpha: 0.10);
    final color = isDark ? const Color(0xFF93C5FD) : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '作者',
        style: TextStyle(
          fontSize: 11,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _CommentActions extends StatelessWidget {
  final GuideComment comment;
  final bool isOwn;
  final bool showActions;
  final VoidCallback? onReply;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  const _CommentActions({
    required this.comment,
    required this.isOwn,
    required this.showActions,
    this.onReply,
    this.onLike,
    this.onDislike,
    this.onDelete,
    this.onReport,
  });

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除评论'),
        content: const Text('确定要删除这条评论吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete?.call();
            },
            style: FilledButton.styleFrom(
              backgroundColor: GuideTokens.statusRejected,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tertiary = GuideTokens.textTertiary(context);
    final theme = Theme.of(context);

    return Row(
      children: [
        // 时间
        Text(
          Formatters.formatRelativeTime(comment.createdAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: tertiary,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: GuideTokens.space20),
        // 赞（常显）
        _IconAction(
          icon: comment.isLiked
              ? Icons.thumb_up_rounded
              : Icons.thumb_up_outlined,
          label: comment.likeCount > 0 ? '${comment.likeCount}' : null,
          color: comment.isLiked ? GuideTokens.likeColor(context) : tertiary,
          onTap: onLike,
        ),
        const SizedBox(width: GuideTokens.space16),
        // 踩（常显）
        _IconAction(
          icon: comment.isDisliked
              ? Icons.thumb_down_rounded
              : Icons.thumb_down_outlined,
          label: comment.dislikeCount > 0 ? '${comment.dislikeCount}' : null,
          color: comment.isDisliked ? GuideTokens.likeColor(context) : tertiary,
          onTap: onDislike,
        ),
        // 回复（常显，自己的评论不显示）
        if (onReply != null) ...[
          const SizedBox(width: GuideTokens.space20),
          _IconAction(
            icon: Icons.reply_rounded,
            label: '回复',
            color: tertiary,
            onTap: onReply,
          ),
        ],
        // 删除 / 举报（hover 时显示）
        if ((isOwn && onDelete != null) || (!isOwn && onReport != null)) ...[
          const SizedBox(width: GuideTokens.space20),
          AnimatedOpacity(
            duration: GuideTokens.durationFast,
            opacity: showActions ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !showActions,
              child: isOwn
                  ? _IconAction(
                      icon: Icons.delete_outline,
                      label: '删除',
                      color: GuideTokens.statusRejected.withValues(alpha: 0.7),
                      onTap: () => _confirmDelete(context),
                    )
                  : _IconAction(
                      icon: Icons.flag_outlined,
                      label: '举报',
                      color: tertiary,
                      onTap: onReport,
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class _IconAction extends StatefulWidget {
  final IconData icon;
  final String? label;
  final Color color;
  final VoidCallback? onTap;

  const _IconAction({
    required this.icon,
    this.label,
    required this.color,
    this.onTap,
  });

  @override
  State<_IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<_IconAction> {
  bool _hover = false;

  bool get _enabled => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final effectiveColor = _enabled
        ? widget.color
        : widget.color.withValues(alpha: 0.45);

    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (_enabled) setState(() => _hover = true);
      },
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _enabled ? widget.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: GuideTokens.durationFast,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (_hover && _enabled) ? hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: effectiveColor),
              if (widget.label != null) ...[
                const SizedBox(width: 6),
                Text(
                  widget.label!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: effectiveColor,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyThread extends StatelessWidget {
  final GuideComment parent;
  final List<GuideComment> replies;
  final int? currentUserId;

  /// true 时底部显示「展开 N 条回复」按钮
  final bool hasMoreReplies;

  /// 未加载的回复数，用于按钮文案
  final int remainingCount;
  final VoidCallback? onExpandMore;
  final ValueChanged<GuideComment>? onReply;
  final ValueChanged<GuideComment>? onLike;
  final ValueChanged<GuideComment>? onDislike;
  final ValueChanged<GuideComment>? onDelete;
  final ValueChanged<GuideComment>? onReport;

  const _ReplyThread({
    required this.parent,
    required this.replies,
    this.currentUserId,
    this.hasMoreReplies = false,
    this.remainingCount = 0,
    this.onExpandMore,
    this.onReply,
    this.onLike,
    this.onDislike,
    this.onDelete,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lineColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.10);

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: lineColor, width: 1)),
      ),
      padding: const EdgeInsets.only(left: GuideTokens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < replies.length; i++) ...[
            _CommentBubble(
              comment: replies[i],
              currentUserId: currentUserId,
              avatarSize: 36,
              showReplyToHint:
                  replies[i].replyToId != null &&
                  replies[i].replyToId != parent.id,
              onReply: () => onReply?.call(replies[i]),
              onLike:
                  (currentUserId != null &&
                      currentUserId == replies[i].authorId)
                  ? null
                  : () => onLike?.call(replies[i]),
              onDislike:
                  (currentUserId != null &&
                      currentUserId == replies[i].authorId)
                  ? null
                  : () => onDislike?.call(replies[i]),
              onDelete: () => onDelete?.call(replies[i]),
              onReport: () => onReport?.call(replies[i]),
            ),
            if (i < replies.length - 1)
              const SizedBox(height: GuideTokens.space16),
          ],
          if (hasMoreReplies) ...[
            const SizedBox(height: GuideTokens.space12),
            TextButton.icon(
              onPressed: onExpandMore,
              icon: Icon(
                Icons.expand_more,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              label: Text(
                '展开 $remainingCount 条回复',
                style: theme.textTheme.labelMedium?.copyWith(
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
          ],
        ],
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  final CommentSortType currentSort;
  final ValueChanged<CommentSortType>? onChanged;

  const _SortMenu({required this.currentSort, this.onChanged});

  String _label(CommentSortType s) => s == CommentSortType.latest ? '最新' : '最热';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tertiary = GuideTokens.textTertiary(context);
    return PopupMenuButton<CommentSortType>(
      tooltip: '排序',
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: GuideTokens.borderRadius12),
      onSelected: (s) {
        if (s != currentSort) onChanged?.call(s);
      },
      itemBuilder: (context) => [
        for (final s in CommentSortType.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                if (s == currentSort)
                  Icon(Icons.check, size: 16, color: theme.colorScheme.primary)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(_label(s)),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label(currentSort),
              style: theme.textTheme.bodySmall?.copyWith(
                color: tertiary,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 16, color: tertiary),
          ],
        ),
      ),
    );
  }
}

// ─── 行内回复 fallback 用的简易药丸输入框 ────────────────────────────────────

class _PillInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final bool enabled;
  final VoidCallback? onSubmit;

  const _PillInput({
    required this.controller,
    this.focusNode,
    required this.hintText,
    this.enabled = true,
    this.onSubmit,
  });

  @override
  State<_PillInput> createState() => _PillInputState();
}

class _PillInputState extends State<_PillInput> {
  late FocusNode _focusNode;
  bool _focused = false;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!mounted) return;
    setState(() => _focused = _focusNode.hasFocus); // 聚焦状态变化时刷新边框色
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final fillColor = isDark
        ? Colors.white.withValues(alpha: _focused ? 0.08 : 0.05)
        : (_focused ? Colors.white : AppColors.slate100);
    final borderColor = _focused
        ? theme.colorScheme.primary.withValues(alpha: 0.65)
        : (isDark
              ? Colors.white.withValues(alpha: _hover ? 0.12 : 0.08)
              : GuideTokens.borderLight);

    if (!widget.enabled) {
      return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: GuideTokens.space20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          widget.hintText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: GuideTokens.textTertiary(context),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: GuideTokens.durationFast,
        height: 44,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: _focused ? 1.5 : 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: GuideTokens.space20),
        child: Center(
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => widget.onSubmit?.call(),
            maxLength: 500,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: GuideTokens.textPrimary(context),
              height: 1.3,
            ),
            decoration: InputDecoration(
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              counterText: '',
              hintText: widget.hintText,
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: GuideTokens.textTertiary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 评论头像（圆形 + 自动签名 URL + 首字母回退）
// ═══════════════════════════════════════════════════════════════════════════

class _CommentAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final double size;

  const _CommentAvatar({
    this.avatarUrl,
    required this.displayName,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: SignedNetworkImage(
          url: avatarUrl,
          fallback: _buildFallback(context),
          cacheWidth: (size * 2).toInt(),
          cacheHeight: (size * 2).toInt(),
        ),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.30),
            theme.colorScheme.primary.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Center(
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
