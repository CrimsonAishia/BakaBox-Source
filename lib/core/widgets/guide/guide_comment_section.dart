import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../bloc/guide_comment/guide_comment_state.dart';
import '../../models/guide_models.dart';
import '../image_viewer_dialog.dart';
import '../rich_text_editor.dart';
import 'guide_comment_bubble.dart';
import 'guide_tokens.dart';

/// 评论区容器组件
///
/// 包含：标题「全部评论 (N)」+ 排序切换（最新 / 最热）+ 输入框 + 评论列表。
///
/// 不直接读 Bloc——由父页面接入数据与回调。
///
/// 用法：
/// ```dart
/// GuideCommentSection(
///   comments: state.comments,
///   replyMaps: state.replyMaps,
///   total: state.total,
///   sort: state.sort,
///   status: state.status,
///   posting: state.posting,
///   currentUserId: authState.userId,
///   isLoggedIn: authState.isLoggedIn,
///   onSortChanged: (sort) => bloc.add(ChangeCommentSort(sort)),
///   onSubmit: (content, images, parentId, replyToId, replyToName) =>
///       bloc.add(PostComment(...)),
///   onLoadMore: () => bloc.add(LoadComments()),
///   onExpandReplies: (id) => bloc.add(LoadReplies(id)),
///   onLike: (id) => bloc.add(ToggleCommentLike(id)),
///   onDelete: (id) => bloc.add(DeleteComment(id)),
///   onReport: (id) => ReportDialog.show(context, targetId: id, targetType: 'comment'),
///   onBlock: (userId) => ...,
///   onLoginRequired: () => LoginDialog.show(context),
/// )
/// ```
class GuideCommentSection extends StatefulWidget {
  /// 一级评论列表
  final List<GuideComment> comments;

  /// 楼中楼回复 map（key: 一级评论 id）
  final Map<int, List<GuideComment>> replyMaps;

  /// 总评论数
  final int total;

  /// 当前排序
  final CommentSortType sort;

  /// 加载状态
  final CommentStatus status;

  /// 是否正在发表评论
  final bool posting;

  /// 当前登录用户 ID（null 未登录）
  final int? currentUserId;

  /// 是否已登录
  final bool isLoggedIn;

  /// 是否还有更多评论
  final bool hasMore;

  /// 排序变更
  final ValueChanged<CommentSortType>? onSortChanged;

  /// 提交评论（content, images, parentId, replyToId, replyToName）
  final void Function(
    String content,
    List<String> images,
    int? parentId,
    int? replyToId,
    String? replyToName,
  )? onSubmit;

  /// 加载更多
  final VoidCallback? onLoadMore;

  /// 展开楼中楼回复
  final ValueChanged<int>? onExpandReplies;

  /// 点赞评论
  final ValueChanged<int>? onLike;

  /// 删除评论
  final ValueChanged<int>? onDelete;

  /// 举报评论
  final ValueChanged<int>? onReport;

  /// 拉黑用户
  final ValueChanged<int>? onBlock;

  /// 未登录时点击输入框
  final VoidCallback? onLoginRequired;

  const GuideCommentSection({
    super.key,
    this.comments = const [],
    this.replyMaps = const {},
    this.total = 0,
    this.sort = CommentSortType.latest,
    this.status = CommentStatus.initial,
    this.posting = false,
    this.currentUserId,
    this.isLoggedIn = false,
    this.hasMore = false,
    this.onSortChanged,
    this.onSubmit,
    this.onLoadMore,
    this.onExpandReplies,
    this.onLike,
    this.onDelete,
    this.onReport,
    this.onBlock,
    this.onLoginRequired,
  });

  @override
  State<GuideCommentSection> createState() => _GuideCommentSectionState();
}

class _GuideCommentSectionState extends State<GuideCommentSection> {
  late QuillController _mainEditorController;

  /// 当前正在回复的评论（就地展开输入框）
  GuideComment? _replyTarget;
  late QuillController _replyEditorController;

  @override
  void initState() {
    super.initState();
    _mainEditorController = QuillController.basic();
    _replyEditorController = QuillController.basic();
  }

  @override
  void dispose() {
    _mainEditorController.dispose();
    _replyEditorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题 + 排序
        _buildHeader(context),
        const SizedBox(height: GuideTokens.space16),
        // 主输入框
        _buildMainInput(context),
        const SizedBox(height: GuideTokens.space16),
        // 评论列表
        _buildCommentList(context),
        // 加载更多
        if (widget.hasMore) _buildLoadMore(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          '全部评论 (${widget.total})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: GuideTokens.textPrimary(context),
          ),
        ),
        const Spacer(),
        // 排序切换
        _SortToggle(
          currentSort: widget.sort,
          onChanged: widget.onSortChanged,
        ),
      ],
    );
  }

  Widget _buildMainInput(BuildContext context) {
    if (!widget.isLoggedIn) {
      return _buildLoginPlaceholderInput(context);
    }

    return _CommentInputBox(
      controller: _mainEditorController,
      hintText: '说点什么...',
      posting: widget.posting && _replyTarget == null,
      onSubmit: (content, images) {
        widget.onSubmit?.call(content, images, null, null, null);
        _mainEditorController.clear();
      },
    );
  }

  Widget _buildLoginPlaceholderInput(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onLoginRequired,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: GuideTokens.space12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : theme.colorScheme.surface.withValues(alpha: 0.6),
          borderRadius: GuideTokens.borderRadius12,
          border: Border.all(
            color: GuideTokens.divider(context),
          ),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          '登录后参与评论',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: GuideTokens.textTertiary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentList(BuildContext context) {
    if (widget.status == CommentStatus.loading && widget.comments.isEmpty) {
      return _buildLoadingState(context);
    }

    if (widget.comments.isEmpty && widget.status == CommentStatus.success) {
      return _buildEmptyState(context);
    }

    return Column(
      children: widget.comments.map((comment) {
        final replies = widget.replyMaps[comment.id] ?? [];
        final defaultReplies =
            replies.isNotEmpty ? replies : comment.replies.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GuideCommentBubble(
              comment: comment,
              currentUserId: widget.currentUserId,
              replies: defaultReplies,
              totalReplyCount: comment.replyCount,
              repliesExpanded: replies.isNotEmpty,
              onReply: _handleReply,
              onLike: widget.onLike,
              onDelete: widget.onDelete,
              onReport: widget.onReport,
              onBlock: widget.onBlock,
              onImageTap: (urls, index) {
                ImageViewerDialog.show(
                  context,
                  imageUrls: urls,
                  initialIndex: index,
                );
              },
              onExpandReplies: widget.onExpandReplies,
            ),
            // 就地展开的回复输入框
            if (_replyTarget != null && _isReplyingTo(comment))
              _buildInlineReplyInput(context, comment),
            Divider(
              height: 1,
              color: GuideTokens.divider(context),
            ),
          ],
        );
      }).toList(),
    );
  }

  /// 判断是否正在回复该评论（或其子回复）
  bool _isReplyingTo(GuideComment comment) {
    if (_replyTarget == null) return false;
    // 回复一级评论
    if (_replyTarget!.id == comment.id) return true;
    // 回复楼中楼里的某条子评论
    if (_replyTarget!.parentId == comment.id) return true;
    return false;
  }

  void _handleReply(GuideComment target) {
    if (!widget.isLoggedIn) {
      widget.onLoginRequired?.call();
      return;
    }

    setState(() {
      if (_replyTarget?.id == target.id) {
        // 再次点击同一评论的回复，关闭
        _replyTarget = null;
        _replyEditorController.clear();
      } else {
        _replyTarget = target;
        _replyEditorController.clear();
        // 自动填入 @对方昵称
        _replyEditorController.document.insert(
          0,
          '@${target.authorName} ',
        );
        // 移动光标到末尾
        _replyEditorController.updateSelection(
          TextSelection.collapsed(
            offset: _replyEditorController.document.length - 1,
          ),
          ChangeSource.local,
        );
      }
    });
  }

  Widget _buildInlineReplyInput(BuildContext context, GuideComment parent) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 36 + GuideTokens.space12,
        bottom: GuideTokens.space8,
      ),
      child: AnimatedSize(
        duration: GuideTokens.durationNormal,
        curve: Curves.easeOutCubic,
        child: _CommentInputBox(
          controller: _replyEditorController,
          hintText: '回复 @${_replyTarget!.authorName}',
          posting: widget.posting && _replyTarget != null,
          compact: true,
          onSubmit: (content, images) {
            final parentId = _replyTarget!.parentId ?? _replyTarget!.id;
            final replyToId = _replyTarget!.id;
            final replyToName = _replyTarget!.authorName;
            widget.onSubmit?.call(
              content,
              images,
              parentId,
              replyToId,
              replyToName,
            );
            setState(() {
              _replyTarget = null;
              _replyEditorController.clear();
            });
          },
          onCancel: () {
            setState(() {
              _replyTarget = null;
              _replyEditorController.clear();
            });
          },
        ),
      ),
    );
  }

  Widget _buildLoadMore(BuildContext context) {
    final theme = Theme.of(context);
    final isLoadingMore = widget.status == CommentStatus.loadingMore;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GuideTokens.space16),
      child: Center(
        child: isLoadingMore
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: widget.onLoadMore,
                child: Text(
                  '加载更多评论',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
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

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GuideTokens.space32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: GuideTokens.textTertiary(context),
            ),
            const SizedBox(height: GuideTokens.space8),
            Text(
              '暂无评论，来发表第一条吧',
              style: theme.textTheme.bodySmall?.copyWith(
                color: GuideTokens.textTertiary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 排序切换 ──────────────────────────────────────────────────────────────────

class _SortToggle extends StatelessWidget {
  final CommentSortType currentSort;
  final ValueChanged<CommentSortType>? onChanged;

  const _SortToggle({
    required this.currentSort,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSortChip(context, theme, CommentSortType.latest, '最新'),
        const SizedBox(width: GuideTokens.space4),
        _buildSortChip(context, theme, CommentSortType.hot, '最热'),
      ],
    );
  }

  Widget _buildSortChip(
    BuildContext context,
    ThemeData theme,
    CommentSortType sort,
    String label,
  ) {
    final isActive = currentSort == sort;
    return GestureDetector(
      onTap: () {
        if (!isActive) onChanged?.call(sort);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: GuideTokens.space8,
          vertical: GuideTokens.space4,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(GuideTokens.radius8),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isActive
                ? theme.colorScheme.primary
                : GuideTokens.textSecondary(context),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─── 评论输入框 ────────────────────────────────────────────────────────────────

class _CommentInputBox extends StatefulWidget {
  final QuillController controller;
  final String hintText;
  final bool posting;
  final bool compact;
  final void Function(String content, List<String> images)? onSubmit;
  final VoidCallback? onCancel;

  const _CommentInputBox({
    required this.controller,
    required this.hintText,
    this.posting = false,
    this.compact = false,
    this.onSubmit,
    this.onCancel,
  });

  @override
  State<_CommentInputBox> createState() => _CommentInputBoxState();
}

class _CommentInputBoxState extends State<_CommentInputBox> {
  final GlobalKey<RichTextEditorState> _editorKey =
      GlobalKey<RichTextEditorState>();
  List<String> _imageUrls = const [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: GuideTokens.borderRadius12,
        border: Border.all(
          color: GuideTokens.divider(context),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 编辑器
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: widget.compact ? 60 : 80,
              maxHeight: 160,
            ),
            child: RichTextEditor(
              key: _editorKey,
              controller: widget.controller,
              hintText: widget.hintText,
              compactMode: true,
              maxLength: 500,
              maxImages: 3,
              imageMode: ImageMode.attachment,
              onImagesChanged: (urls) {
                _imageUrls = urls;
              },
            ),
          ),
          // 操作栏
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: GuideTokens.space8,
              vertical: GuideTokens.space4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.onCancel != null) ...[
                  TextButton(
                    onPressed: widget.onCancel,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: GuideTokens.space8,
                      ),
                    ),
                    child: Text(
                      '取消',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: GuideTokens.textSecondary(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: GuideTokens.space8),
                ],
                FilledButton(
                  onPressed: widget.posting ? null : () => _handleSubmit(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(56, 30),
                    padding: const EdgeInsets.symmetric(
                      horizontal: GuideTokens.space12,
                    ),
                  ),
                  child: widget.posting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          '发送',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubmit() {
    final plainText = widget.controller.document.toPlainText().trim();
    if (plainText.isEmpty) return;

    widget.onSubmit?.call(plainText, _imageUrls);
    _editorKey.currentState?.clearImages();
    _imageUrls = const [];
  }
}
