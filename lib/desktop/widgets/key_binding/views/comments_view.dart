import 'package:bakabox_app/core/widgets/baka_cached_image.dart';
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
import '../../../../core/constants/app_colors.dart';

/// 配置评论视图
class ConfigCommentsView extends StatefulWidget {
  final KeyConfig config;
  final Widget content;
  final ScrollController scrollController;
  final Widget? topIndicator;
  final Widget? bottomIndicator;

  const ConfigCommentsView({
    super.key,
    required this.config,
    required this.content,
    required this.scrollController,
    this.topIndicator,
    this.bottomIndicator,
  });

  @override
  State<ConfigCommentsView> createState() => _ConfigCommentsViewState();
}

class _ConfigCommentsViewState extends State<ConfigCommentsView> {
  final QuillController _commentController = RichTextEditor.createController();
  final GlobalKey<RichTextEditorState> _editorKey = GlobalKey();
  List<String> _commentImageUrls = [];

  // 回复相关
  KeyConfigComment? _replyToComment;
  // 评论元素对应的 Key 映射，用于滚动定位
  final Map<int, GlobalKey> _commentKeys = {};
  // 高亮的评论 ID，用于跳转时进行动画提示
  int? _highlightedCommentId;

  // 底栏展开状态
  bool _expanded = false;

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
      setState(() {
        _replyToComment = null;
        _expanded = false;
        _commentController.clear();
        _commentImageUrls = [];
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool _isLoggedIn() => context.read<AuthBloc>().state.isAuthenticated;

  String? _avatarUrl() {
    final info = context.read<AuthBloc>().state.userInfo;
    if (info == null || info.avatar.isEmpty) return null;
    return info.avatar;
  }

  String _displayName() {
    final info = context.read<AuthBloc>().state.userInfo;
    return info?.username ?? '游客';
  }

  void _expand() {
    if (!_isLoggedIn()) {
      ToastUtils.showInfo(context, '登录后才能参与评论');
      return;
    }
    if (_expanded) return;
    setState(() => _expanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _editorKey.currentState?.focus();

        if (widget.scrollController.hasClients) {
          if (_replyToComment == null) {
            // 如果是普通评论，展开时稍微向下滚动，确保能看到底部的内容
            widget.scrollController.animateTo(
              widget.scrollController.offset + 250,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          } else {
            // 如果是回复某人，确保被回复的评论在可视区域内
            final commentCtx =
                _commentKeys[_replyToComment!.id]?.currentContext;
            if (commentCtx != null) {
              Scrollable.ensureVisible(
                commentCtx,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: 0.3,
              );
            }
          }
        }
      }
    });
  }

  void _collapse() {
    if (!_expanded) return;
    setState(() => _expanded = false);
    _editorKey.currentState?.unfocus();
  }

  void _handleCancel() {
    _commentController.clear();
    _editorKey.currentState?.clearImages();
    _commentImageUrls = const [];
    setState(() {
      _replyToComment = null;
    });
    _collapse();
  }

  void _setReplyTo(KeyConfigComment comment) {
    setState(() {
      _replyToComment = comment;
    });
    _expand();
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
          _handleCancel(); // 提交成功后收起底栏
        }
      },
      builder: (context, state) {
        return Stack(
          children: [
            SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  widget.content,
                  const SizedBox(height: 32),
                  // 评论列表区域
                  _buildCommentList(state),
                  // 预留底部空间，避免展开时底栏遮挡最后一条评论
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    height: _expanded ? 500 : 120, // 展开时预留更多高度
                  ),
                ],
              ),
            ),
            if (widget.topIndicator != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: widget.topIndicator!,
              ),
            // 底部悬浮评论框（仅已通过的配置显示）
            if (widget.config.isApproved)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.bottomIndicator != null) widget.bottomIndicator!,
                    _buildBottomComposerContainer(state),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCommentList(KeyBindingState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.gray200,
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
            color: isDark ? Colors.white : AppColors.gray800,
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
          style: TextStyle(color: isDark ? Colors.white38 : AppColors.gray400),
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
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : const Color(0xFFEFF6FF))
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.slate700 : AppColors.gray100,
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
              backgroundColor: isDark ? AppColors.slate700 : AppColors.gray200,
              backgroundImage: comment.authorAvatar != null
                  ? bakaCachedImageProvider(comment.authorAvatar!)
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
                          color: isDark ? Colors.white70 : AppColors.gray700,
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
                            color: AppColors.primary,
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
                          color: isDark ? Colors.white38 : AppColors.gray400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          replyTarget.authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        Formatters.formatRelativeTime(comment.createdAt),
                        style: TextStyle(
                          color: isDark ? Colors.white38 : AppColors.gray400,
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
                  // 使用 RichTextViewer 显示评论内容
                  RichTextViewer(
                    content: comment.content,
                    textStyle: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: isDark ? Colors.white70 : AppColors.gray700,
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

  Widget _buildReplyButton(KeyConfigComment comment, bool isDark) {
    final isActive = _replyToComment?.id == comment.id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isActive) {
            _handleCancel();
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
                    ? AppColors.primary
                    : (isDark ? Colors.white38 : AppColors.gray400),
              ),
              const SizedBox(width: 4),
              Text(
                isActive ? '取消回复' : '回复',
                style: TextStyle(
                  fontSize: 12,
                  color: isActive
                      ? AppColors.primary
                      : (isDark ? Colors.white38 : AppColors.gray400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
              ? AppColors.slate700.withValues(alpha: 0.5)
              : AppColors.gray100,
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(
              width: 3,
              color: isDark ? AppColors.slate600 : AppColors.gray300,
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
                  color: isDark ? Colors.white38 : AppColors.gray400,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildBottomComposerContainer(KeyBindingState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.slate900.withValues(alpha: 0.96)
              : Colors.white.withValues(alpha: 0.97),
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppColors.gray200,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: _expanded
              ? _buildExpandedComposer(state)
              : _buildCollapsedComposer(),
        ),
      ),
    );
  }

  Widget _buildCollapsedComposer() {
    final isLoggedIn = _isLoggedIn();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hint = _replyToComment != null
        ? '回复 @${_replyToComment!.authorName}...'
        : (isLoggedIn ? '写下你的评论...' : '登录后参与评论');

    return Padding(
      key: const ValueKey('collapsed'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isDark ? AppColors.slate700 : AppColors.gray200,
            backgroundImage: isLoggedIn && _avatarUrl() != null
                ? bakaCachedImageProvider(_avatarUrl()!)
                : null,
            child: (!isLoggedIn || _avatarUrl() == null)
                ? Text(
                    _displayName()[0].toUpperCase(),
                    style: const TextStyle(fontSize: 14),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _expand,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800 : AppColors.gray100,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDark ? AppColors.slate700 : AppColors.gray200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: isDark ? Colors.white38 : AppColors.gray400,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hint,
                          style: TextStyle(
                            color: isDark ? Colors.white54 : AppColors.gray500,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_replyToComment != null)
                        IconButton(
                          tooltip: '取消回复',
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: _handleCancel,
                          icon: Icon(
                            Icons.close,
                            color: isDark ? Colors.white38 : AppColors.gray400,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _expand,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              minimumSize: const Size(0, 44),
            ),
            child: Text(
              _replyToComment != null ? '回复' : '发送',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedComposer(KeyBindingState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      key: const ValueKey('expanded'),
      padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _replyToComment != null ? '回复评论' : '发表评论',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : AppColors.gray700,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _handleCancel,
                icon: const Icon(Icons.close, size: 20),
                color: isDark ? Colors.white38 : AppColors.gray400,
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 回复提示条
          _buildReplyBar(isDark),
          // 使用 RichTextEditor
          SizedBox(
            height: 200,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.slate700 : AppColors.gray200,
                ),
              ),
              child: RichTextEditor(
                key: _editorKey,
                controller: _commentController,
                hintText: _replyToComment != null
                    ? '回复 @${_replyToComment!.authorName}...'
                    : '写下你的评论...',
                maxLength: 200,
                maxImages: 3,
                compactMode: true,
                draftId: null,
                enableDraftManualSave: false,
                onImagesChanged: (urls) =>
                    setState(() => _commentImageUrls = urls),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: state.isSubmittingComment ? null : _handleCancel,
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: state.isSubmittingComment ? null : _submitComment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
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

  Widget _buildReplyBar(bool isDark) {
    if (_replyToComment == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.1)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(MdiIcons.replyOutline, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '回复 ',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : AppColors.gray700,
            ),
          ),
          Text(
            _replyToComment!.authorName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () {
              setState(() => _replyToComment = null);
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 16,
                color: isDark ? Colors.white38 : AppColors.gray400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitComment() {
    if (!_isLoggedIn()) {
      ToastUtils.showInfo(context, '登录后才能参与评论');
      return;
    }
    final plainText = _commentController.document.toPlainText().trim();
    if (plainText.isEmpty) {
      ToastUtils.showWarning(context, '请输入评论内容');
      return;
    }

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
