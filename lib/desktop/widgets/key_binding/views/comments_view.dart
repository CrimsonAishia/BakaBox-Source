import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/bloc/auth/auth_bloc.dart';
import '../../../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../../../core/bloc/key_binding/key_binding_event.dart';
import '../../../../core/bloc/key_binding/key_binding_state.dart';
import '../../../../core/models/key_config_models.dart';
import '../../../../core/services/quill_delta_codec.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../core/widgets/clickable_image.dart';
import '../../../../core/widgets/rich_text_editor.dart';
import '../../../../core/widgets/rich_text_viewer.dart';

/// 配置评论视图（复用 issue 评论模式）
class ConfigCommentsView extends StatefulWidget {
  final KeyConfig config;

  const ConfigCommentsView({super.key, required this.config});

  @override
  State<ConfigCommentsView> createState() => _ConfigCommentsViewState();
}

class _ConfigCommentsViewState extends State<ConfigCommentsView> {
  final QuillController _commentController = QuillController.basic();
  final GlobalKey<RichTextEditorState> _editorKey = GlobalKey();
  final GlobalKey _commentInputKey = GlobalKey();
  List<String> _commentImageUrls = [];

  // 回复相关
  KeyConfigComment? _replyToComment;
  // 评论元素对应的 Key 映射，用于滚动定位
  final Map<int, GlobalKey> _commentKeys = {};
  // 高亮的评论 ID，用于跳转时进行动画提示
  int? _highlightedCommentId;

  @override
  void initState() {
    super.initState();
    // 加载评论列表
    context.read<KeyBindingBloc>().add(
      KeyBindingLoadComments(configId: widget.config.id),
    );
  }

  @override
  void didUpdateWidget(covariant ConfigCommentsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当配置 ID 变化时，重新加载评论并清除回复状态
    if (oldWidget.config.id != widget.config.id) {
      context.read<KeyBindingBloc>().add(
        KeyBindingLoadComments(configId: widget.config.id),
      );
      setState(() => _replyToComment = null);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _setReplyTo(KeyConfigComment comment) {
    setState(() {
      _replyToComment = comment;
    });
    // 滚动到评论输入区域
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _commentInputKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToComment = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KeyBindingBloc, KeyBindingState>(
      listenWhen: (prev, curr) =>
          prev.isSubmittingComment &&
          !curr.isSubmittingComment &&
          curr.successMessage != null,
      listener: (context, state) {
        // 评论提交成功后清空编辑器和回复状态
        if (state.successMessage?.contains('评论') == true) {
          _commentController.clear();
          _editorKey.currentState?.clearImages();
          setState(() {
            _commentImageUrls = [];
            _replyToComment = null;
          });
        }
      },
      builder: (context, state) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 评论列表区域
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(state),
                  const SizedBox(height: 16),
                  if (state.isLoadingComments)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (state.comments.isEmpty)
                    _buildEmptyState()
                  else
                    ...state.comments.map(
                      (comment) => _buildCommentItem(comment, state.comments),
                    ),
                ],
              ),
            ),
            // 评论输入区域（仅已通过的配置显示）
            if (widget.config.isApproved) ...[
              const SizedBox(height: 16),
              Container(
                key: _commentInputKey,
                child: _buildCommentInput(state),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeader(KeyBindingState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          '评论 (${state.commentTotal})',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        const Spacer(),
        if (!state.isLoadingComments)
          IconButton(
            onPressed: () => context.read<KeyBindingBloc>().add(
              KeyBindingLoadComments(configId: widget.config.id),
            ),
            icon: Icon(
              Icons.refresh,
              size: 18,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
            tooltip: '刷新评论',
            splashRadius: 18,
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          '暂无评论',
          style: TextStyle(
            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentItem(
    KeyConfigComment comment,
    List<KeyConfigComment> allComments,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReplyTarget = _replyToComment?.id == comment.id;
    // 查找被回复的评论
    final replyTarget = comment.replyToId != null && comment.replyToId! > 0
        ? allComments.where((c) => c.id == comment.replyToId).firstOrNull
        : null;

    final commentKey = _commentKeys.putIfAbsent(comment.id, () => GlobalKey());

    final isHighlighted = _highlightedCommentId == comment.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      key: commentKey,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? (isDark
                  ? const Color(0xFFEAB308).withValues(alpha: 0.15)
                  : const Color(0xFFFEF08A).withValues(alpha: 0.5))
            : isReplyTarget
            ? (isDark
                  ? const Color(0xFF0080FF).withValues(alpha: 0.08)
                  : const Color(0xFFEFF6FF))
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
          ),
        ),
        borderRadius: isReplyTarget ? BorderRadius.circular(8) : null,
      ),
      child: Padding(
        padding: isReplyTarget
            ? const EdgeInsets.symmetric(horizontal: 8)
            : EdgeInsets.zero,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE5E7EB),
              backgroundImage: comment.authorAvatar != null
                  ? NetworkImage(comment.authorAvatar!)
                  : null,
              child: comment.authorAvatar == null
                  ? Text(
                      comment.authorName.isNotEmpty
                          ? comment.authorName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 14),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comment.authorName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF374151),
                        ),
                      ),
                      if (comment.isAdmin) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0080FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '管理员',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ],
                      if (replyTarget != null) ...[
                        const SizedBox(width: 6),
                        Icon(
                          MdiIcons.arrowRightThin,
                          size: 14,
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          replyTarget.authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0080FF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        Formatters.formatRelativeTime(comment.createdAt),
                        style: TextStyle(
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      if (widget.config.isApproved)
                        _buildReplyButton(comment, isDark),
                    ],
                  ),
                  if (replyTarget != null) ...[
                    const SizedBox(height: 6),
                    _buildReplyQuote(replyTarget, isDark),
                  ],
                  const SizedBox(height: 8),
                  // 使用 RichTextViewer 显示评论内容（与 issue 一致）
                  RichTextViewer(
                    content: comment.content,
                    textStyle: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: isDark ? Colors.white70 : const Color(0xFF374151),
                    ),
                    compact: true,
                  ),
                  if (comment.images.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ImageGrid(
                      imageUrls: comment.images,
                      imageWidth: 120,
                      imageHeight: 90,
                      spacing: 8,
                      borderRadius: 6,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 回复按钮
  Widget _buildReplyButton(KeyConfigComment comment, bool isDark) {
    final isActive = _replyToComment?.id == comment.id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isActive) {
            _cancelReply();
          } else {
            _setReplyTo(comment);
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                MdiIcons.replyOutline,
                size: 14,
                color: isActive
                    ? const Color(0xFF0080FF)
                    : (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
              ),
              const SizedBox(width: 4),
              Text(
                isActive ? '取消回复' : '回复',
                style: TextStyle(
                  fontSize: 12,
                  color: isActive
                      ? const Color(0xFF0080FF)
                      : (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 被回复评论的引用块
  Widget _buildReplyQuote(KeyConfigComment replyTarget, bool isDark) {
    return InkWell(
      onTap: () async {
        final context = _commentKeys[replyTarget.id]?.currentContext;
        if (context != null) {
          await Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
          if (mounted) {
            setState(() {
              _highlightedCommentId = replyTarget.id;
            });
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted && _highlightedCommentId == replyTarget.id) {
                setState(() {
                  _highlightedCommentId = null;
                });
              }
            });
          }
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF334155).withValues(alpha: 0.5)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(
              width: 3,
              color: isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB),
            ),
          ),
        ),
        child: IgnorePointer(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 80),
            child: ClipRect(
              child: RichTextViewer(
                content: replyTarget.content,
                compact: true,
                textStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 评论输入区域上方的回复提示条
  Widget _buildReplyBar(bool isDark) {
    if (_replyToComment == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0080FF).withValues(alpha: 0.1)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF0080FF).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(MdiIcons.replyOutline, size: 16, color: const Color(0xFF0080FF)),
          const SizedBox(width: 8),
          Text(
            '回复 ',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : const Color(0xFF374151),
            ),
          ),
          Text(
            _replyToComment!.authorName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0080FF),
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: _cancelReply,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 16,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(KeyBindingState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthBloc>().state;

    if (!authState.isAuthenticated) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              MdiIcons.loginVariant,
              size: 16,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              '登录后可以发表评论',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _replyToComment != null ? '回复评论' : '发表评论',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),
          // 回复提示条
          _buildReplyBar(isDark),
          // 使用 RichTextEditor（紧凑模式，适合侧边栏宽度）
          SizedBox(
            height: 300,
            child: RichTextEditor(
              key: _editorKey,
              controller: _commentController,
              hintText: _replyToComment != null
                  ? '回复 ${_replyToComment!.authorName}...'
                  : '写下你的评论...',
              maxLength: 200,
              maxImages: 3,
              compactMode: true, // 紧凑模式，简化工具栏
              draftId: null,
              enableDraftManualSave: false,
              onImagesChanged: (urls) =>
                  setState(() => _commentImageUrls = urls),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: state.isSubmittingComment ? null : _submitComment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0080FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: state.isSubmittingComment
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_replyToComment != null ? '回复' : '发表评论'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submitComment() {
    final plainText = _commentController.document.toPlainText().trim();
    if (plainText.isEmpty) {
      ToastUtils.showWarning(context, '请输入评论内容');
      return;
    }

    // 使用 QuillDeltaCodec 编码富文本内容（与 issue 一致）
    final content = QuillDeltaCodec.encode(_commentController.document);

    context.read<KeyBindingBloc>().add(
      KeyBindingAddComment(
        configId: widget.config.id,
        content: content,
        images: _commentImageUrls.isNotEmpty ? _commentImageUrls : null,
        replyToId: _replyToComment?.id,
      ),
    );
  }
}
