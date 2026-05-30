import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../core/core.dart';
import '../../core/services/quill_delta_codec.dart';

/// Issue 详情移动端页面
class IssueDetailMobile extends StatefulWidget {
  final int issueId;
  const IssueDetailMobile({super.key, required this.issueId});

  @override
  State<IssueDetailMobile> createState() => _IssueDetailMobileState();
}

class _IssueDetailMobileState extends State<IssueDetailMobile> {
  final quill.QuillController _commentController =
      quill.QuillController.basic();
  final ScrollController _scrollController = ScrollController();
  final _commentEditorKey = GlobalKey<RichTextEditorState>();
  List<String> _commentImageUrls = [];

  // 回复相关
  IssueComment? _replyToComment;
  final Map<int, GlobalKey> _commentKeys = {};
  int? _highlightedCommentId;

  // 评论草稿相关
  bool _showCommentDraftPrompt = false;
  DraftData? _savedCommentDraft;

  @override
  void initState() {
    super.initState();
    // IssueDetailBloc 已在路由中初始化并触发 IssueDetailFetch
    _checkCommentDraftExists();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 检查评论草稿是否存在
  Future<void> _checkCommentDraftExists() async {
    try {
      final draftId = 'comment_${widget.issueId}';
      final hasDraft = await DraftService().hasDraft(draftId);
      if (hasDraft) {
        final draft = await DraftService().restoreDraft(draftId);
        if (draft != null && mounted) {
          setState(() {
            _savedCommentDraft = draft;
            _showCommentDraftPrompt = true;
          });
        }
      }
    } catch (e) {
      LogService.e('检查评论草稿失败', e);
    }
  }

  /// 恢复评论草稿
  void _restoreCommentDraft() {
    if (_savedCommentDraft == null) return;

    // 恢复内容
    if (_savedCommentDraft!.content.isNotEmpty) {
      try {
        final document = QuillDeltaCodec.decode(_savedCommentDraft!.content);
        _commentController.document = document;
      } catch (e) {
        LogService.e('解码评论草稿失败', e);
      }
    }

    // 恢复图片
    setState(() {
      _commentImageUrls = _savedCommentDraft!.imageUrls;
      _showCommentDraftPrompt = false;
      _savedCommentDraft = null;
    });

    ToastUtils.showSuccess(context, '草稿已恢复');
  }

  /// 忽略评论草稿
  void _ignoreCommentDraft() {
    DraftService().deleteDraft('comment_${widget.issueId}');
    setState(() {
      _showCommentDraftPrompt = false;
      _savedCommentDraft = null;
    });
  }

  void _submitComment() {
    if (_commentController.document.toPlainText().trim().isEmpty) {
      ToastUtils.showWarning(context, '请输入评论内容');
      return;
    }
    final content = QuillDeltaCodec.encode(_commentController.document);
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) {
      ToastUtils.showWarning(context, '请先登录');
      return;
    }
    context.read<IssueDetailBloc>().add(IssueDetailSetUser(authState.userInfo));
    context.read<IssueDetailBloc>().add(
      IssueDetailAddComment(
        content,
        images: _commentImageUrls,
        replyToId: _replyToComment?.id,
      ),
    );

    // 提交后删除草稿
    DraftService().deleteDraft('comment_${widget.issueId}');

    _commentController.clear();
    _commentEditorKey.currentState?.clearImages();
    setState(() {
      _commentImageUrls = [];
      _replyToComment = null;
    });
    FocusScope.of(context).unfocus();
  }

  void _toggleVote() {
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) {
      ToastUtils.showWarning(context, '请先登录');
      return;
    }
    context.read<IssueDetailBloc>().add(const IssueDetailToggleVote());
  }

  void _setReplyTo(IssueComment comment) {
    setState(() {
      _replyToComment = comment;
    });
    // 打开评论面板
    final state = context.read<IssueDetailBloc>().state;
    _showCommentDialog(state);
  }

  void _cancelReply() {
    setState(() {
      _replyToComment = null;
    });
  }

  Future<void> _saveCommentDraft() async {
    final plainText = _commentController.document.toPlainText().trim();
    if (plainText.isEmpty) {
      ToastUtils.showWarning(context, '内容为空，无需保存草稿');
      return;
    }

    try {
      final content = QuillDeltaCodec.encode(_commentController.document);

      await DraftService().saveDraft(
        draftId: 'comment_${widget.issueId}',
        content: content,
        imageUrls: _commentImageUrls,
      );

      if (mounted) {
        ToastUtils.showSuccess(context, '草稿已保存');
      }
    } catch (e) {
      LogService.e('保存草稿失败', e);
      if (mounted) {
        ToastUtils.showError(context, '保存草稿失败');
      }
    }
  }

  /// 评论草稿提示条
  Widget _buildCommentDraftPrompt() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0080FF);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: isDark ? 0.15 : 0.1),
            primaryColor.withValues(alpha: isDark ? 0.08 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.restore_rounded, size: 18, color: primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '发现未保存的评论草稿',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: _ignoreCommentDraft,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(50, 28),
            ),
            child: Text(
              '忽略',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: _restoreCommentDraft,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(50, 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              '恢复',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<IssueDetailBloc, IssueDetailState>(
      listener: (context, state) {
        if (state.error != null) {
          ToastUtils.showError(context, state.error!);
          context.read<IssueDetailBloc>().add(const IssueDetailClearError());
        }
        if (state.successMessage != null) {
          ToastUtils.showSuccess(context, state.successMessage!);
          context.read<IssueDetailBloc>().add(const IssueDetailClearError());
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: state.isLoading
              ? _buildLoadingState()
              : state.issue == null
              ? _buildErrorState()
              : _buildContent(state),
          bottomNavigationBar: state.issue != null
              ? _buildBottomBar(state)
              : null,
        );
      },
    );
  }

  /// 构建优化后的 AppBar
  Widget _buildAppBar(BuildContext context, IssueDetailState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: theme.appBarTheme.backgroundColor,
      surfaceTintColor: theme.appBarTheme.backgroundColor,
      toolbarHeight: 80,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: theme.appBarTheme.backgroundColor,
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.05),
              offset: const Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
            child: Row(
              children: [
                // 返回按钮
                IconButton(
                  onPressed: () => context.pop(),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: theme.appBarTheme.foregroundColor,
                    size: 22,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ).animate().fadeIn(duration: 200.ms),
                const SizedBox(width: 8),
                // 图标容器
                Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0080FF), Color(0xFF0066CC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0080FF,
                            ).withValues(alpha: 0.3),
                            offset: const Offset(0, 4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Icon(
                        MdiIcons.fileDocumentOutline,
                        color: Colors.white,
                        size: 24,
                      ),
                    )
                    .animate()
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1.0, 1.0),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 200.ms)
                    .then()
                    .shimmer(
                      duration: 1000.ms,
                      delay: 100.ms,
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.3),
                        Colors.white.withValues(alpha: 0.8),
                        Colors.white.withValues(alpha: 0.3),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                const SizedBox(width: 16),
                // 标题区域
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        state.issue != null ? '#${state.issue!.id}' : '加载中...',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.appBarTheme.foregroundColor,
                        ),
                      ).animate().fadeIn(duration: 300.ms),
                      const SizedBox(height: 2),
                      Text(
                        '问题详情',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.appBarTheme.foregroundColor?.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ).animate().fadeIn(duration: 300.ms, delay: 80.ms),
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

  /// 构建加载状态
  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0080FF);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: primaryColor.withValues(
                          alpha: isDark ? 0.25 : 0.2,
                        ),
                      ),
                    )
                    .animate(onPlay: (controller) => controller.repeat())
                    .scale(duration: 1000.ms)
                    .fadeIn(duration: 500.ms),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark
                          ? primaryColor.withValues(alpha: 0.9)
                          : primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
                '正在加载反馈详情',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isDark
                      ? primaryColor.withValues(alpha: 0.9)
                      : primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .fadeIn(duration: 800.ms)
              .then(delay: 200.ms)
              .fadeOut(duration: 800.ms),
          const SizedBox(height: 8),
          Text(
            '请稍候...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  /// 构建错误状态
  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = context.read<IssueDetailBloc>().state;
    final errorMessage = state.error ?? 'Issue 不存在或加载失败';
    final errorColor = const Color(0xFFDC2626);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark
                    ? errorColor.withValues(alpha: 0.15)
                    : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Icon(
                MdiIcons.alertCircleOutline,
                size: 36,
                color: isDark ? errorColor.withValues(alpha: 0.9) : errorColor,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text(
              '加载失败',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? errorColor.withValues(alpha: 0.1)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? errorColor.withValues(alpha: 0.3)
                      : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    MdiIcons.informationOutline,
                    size: 16,
                    color: isDark
                        ? errorColor.withValues(alpha: 0.9)
                        : errorColor,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      errorMessage,
                      style: TextStyle(
                        color: isDark
                            ? errorColor.withValues(alpha: 0.9)
                            : errorColor,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
            const SizedBox(height: 20),
            ElevatedButton.icon(
                  onPressed: () => context.read<IssueDetailBloc>().add(
                    IssueDetailFetch(widget.issueId),
                  ),
                  icon: Icon(MdiIcons.refresh, size: 18),
                  label: const Text('重新加载'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0080FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: 300.ms, duration: 300.ms)
                .slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }

  /// 构建内容区域
  Widget _buildContent(IssueDetailState state) {
    final issue = state.issue!;
    return RefreshIndicator(
      onRefresh: () async =>
          context.read<IssueDetailBloc>().add(IssueDetailFetch(widget.issueId)),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(context, state),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIssueCard(issue)
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 16),
                  _buildCommentsSection(state)
                      .animate()
                      .fadeIn(duration: 300.ms, delay: 100.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建问题详情卡片
  Widget _buildIssueCard(Issue issue) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 类型和状态标签行
          Row(
            children: [
              _buildTypeTag(issue.issueType),
              const SizedBox(width: 8),
              _buildStatusTag(issue.issueStatus),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${issue.id}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 标题
          Text(
            issue.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // 作者信息行
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: issue.authorAvatar != null
                      ? NetworkImage(issue.authorAvatar!)
                      : null,
                  child: issue.authorAvatar == null
                      ? Text(
                          issue.authorName[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.authorName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            MdiIcons.clockOutline,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            Formatters.formatRelativeTime(issue.createdAt),
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 投票和评论统计
                _buildStatBadge(MdiIcons.thumbUpOutline, issue.voteCount),
                const SizedBox(width: 8),
                _buildStatBadge(MdiIcons.commentOutline, issue.commentCount),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 分割线
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.dividerColor.withValues(alpha: 0),
                  theme.dividerColor,
                  theme.dividerColor.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 内容区域
          RichTextViewer(
            content: issue.content,
            textStyle: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: theme.colorScheme.onSurface,
            ),
          ),
          // 图片网格
          if (issue.images.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildImageGrid(issue.images),
          ],
          // 设备信息
          if (issue.deviceInfo != null) ...[
            const SizedBox(height: 16),
            _buildDeviceInfoCard(issue.deviceInfo!),
          ],
        ],
      ),
    );
  }

  /// 构建统计徽章
  Widget _buildStatBadge(IconData icon, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建图片网格
  Widget _buildImageGrid(List<String> images) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                MdiIcons.imageMultipleOutline,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '附件图片 (${images.length})',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ImageGrid(
            imageUrls: images,
            imageWidth: 100,
            imageHeight: 100,
            spacing: 8,
            borderRadius: 8,
          ),
        ],
      ),
    );
  }

  /// 构建设备信息卡片
  Widget _buildDeviceInfoCard(DeviceInfo deviceInfo) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF0080FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              MdiIcons.cellphoneInformation,
              size: 18,
              color: const Color(0xFF0080FF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '设备信息',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${deviceInfo.appVersion} · ${deviceInfo.platform} · ${deviceInfo.osVersion}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建类型标签
  Widget _buildTypeTag(IssueType type) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (color, bgColor, icon) = switch (type) {
      IssueType.bug => (
        const Color(0xFFDC2626),
        isDark
            ? const Color(0xFFDC2626).withValues(alpha: 0.15)
            : const Color(0xFFFEE2E2),
        MdiIcons.bug,
      ),
      IssueType.feature => (
        const Color(0xFF2563EB),
        isDark
            ? const Color(0xFF2563EB).withValues(alpha: 0.15)
            : const Color(0xFFDBEAFE),
        MdiIcons.lightbulbOnOutline,
      ),
      IssueType.question => (
        const Color(0xFF059669),
        isDark
            ? const Color(0xFF059669).withValues(alpha: 0.15)
            : const Color(0xFFD1FAE5),
        MdiIcons.helpCircleOutline,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            type.label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建状态标签
  Widget _buildStatusTag(IssueStatus status) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOpen = status.isOpen;
    final color = isOpen ? const Color(0xFF16A34A) : const Color(0xFF6B7280);
    final bgColor = isOpen
        ? (isDark
              ? const Color(0xFF16A34A).withValues(alpha: 0.15)
              : const Color(0xFFDCFCE7))
        : (isDark
              ? const Color(0xFF6B7280).withValues(alpha: 0.15)
              : const Color(0xFFF3F4F6));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建评论区域
  Widget _buildCommentsSection(IssueDetailState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0080FF);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 评论标题行
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  MdiIcons.commentMultipleOutline,
                  size: 18,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '评论',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${state.comments.length}',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 评论列表
          if (state.isLoadingComments)
            _buildCommentsLoading()
          else if (state.comments.isEmpty)
            _buildCommentsEmpty()
          else
            ...state.comments.asMap().entries.map((entry) {
              return _buildCommentItem(entry.value, entry.key)
                  .animate()
                  .fadeIn(
                    duration: 300.ms,
                    delay: Duration(milliseconds: 50 * entry.key),
                  )
                  .slideX(begin: 0.05, end: 0);
            }),
        ],
      ),
    );
  }

  /// 构建评论加载状态
  Widget _buildCommentsLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0080FF)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '加载评论中...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建评论空状态
  Widget _buildCommentsEmpty() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF3B82F6);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark
                    ? primaryColor.withValues(alpha: 0.15)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                MdiIcons.commentOutline,
                size: 28,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无评论',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '成为第一个评论的人吧',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建评论项
  Widget _buildCommentItem(IssueComment comment, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLast =
        index == context.read<IssueDetailBloc>().state.comments.length - 1;
    final allComments = context.read<IssueDetailBloc>().state.comments;
    final issue = context.read<IssueDetailBloc>().state.issue;
    final isOpen = issue?.issueStatus.isOpen ?? false;

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
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isHighlighted
            ? (isDark
                  ? const Color(0xFFEAB308).withValues(alpha: 0.15)
                  : const Color(0xFFFEF08A).withValues(alpha: 0.5))
            : Colors.transparent,
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
              ),
        borderRadius: isHighlighted ? BorderRadius.circular(8) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像
          Stack(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: comment.authorAvatar != null
                    ? NetworkImage(comment.authorAvatar!)
                    : null,
                child: comment.authorAvatar == null
                    ? Text(
                        comment.authorName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : null,
              ),
              // 管理员标识
              if (comment.isAdmin)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0080FF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // 评论内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 作者信息行
                Row(
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              comment.authorName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (comment.isAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0080FF),
                                    Color(0xFF0066CC),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '管理员',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          if (replyTarget != null) ...[
                            const SizedBox(width: 6),
                            Icon(
                              MdiIcons.arrowRightThin,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                replyTarget.authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF0080FF),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      MdiIcons.clockOutline,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      Formatters.formatRelativeTime(comment.createdAt),
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                // 回复引用
                if (replyTarget != null) ...[
                  const SizedBox(height: 6),
                  _buildReplyQuote(replyTarget),
                ],
                const SizedBox(height: 8),
                // 评论内容
                RichTextViewer(
                  content: comment.content,
                  textStyle: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: theme.colorScheme.onSurface,
                  ),
                  compact: true,
                ),
                // 评论图片
                if (comment.images.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ImageGrid(
                    imageUrls: comment.images,
                    imageWidth: 80,
                    imageHeight: 80,
                    spacing: 6,
                    borderRadius: 6,
                  ),
                ],
                // 回复按钮 - 右下角
                if (isOpen) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildReplyButton(comment),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建回复按钮
  Widget _buildReplyButton(IssueComment comment) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _setReplyTo(comment),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                MdiIcons.replyOutline,
                size: 16,
                color: const Color(0xFF0080FF),
              ),
              const SizedBox(width: 6),
              Text(
                '回复',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0080FF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建回复引用
  Widget _buildReplyQuote(IssueComment replyTarget) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        final context = _commentKeys[replyTarget.id]?.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.3,
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(
              width: 3,
              color: isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB),
            ),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 60),
          child: ClipRect(
            child: RichTextViewer(
              content: replyTarget.content,
              compact: true,
              textStyle: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建底部操作栏
  Widget _buildBottomBar(IssueDetailState state) {
    final issue = state.issue!;
    final authState = context.read<AuthBloc>().state;
    final backendUserInfo = TokenService.instance.userInfo;
    final isAuthor =
        authState.isAuthenticated &&
        backendUserInfo != null &&
        backendUserInfo.id == issue.authorId;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // 投票按钮
          _buildVoteButton(issue, state.isSubmitting),
          const SizedBox(width: 12),
          // 关闭/重开按钮（仅作者可见）
          if (isAuthor) ...[
            _buildCloseReopenButton(issue, state.isSubmitting),
            const SizedBox(width: 12),
          ],
          // 评论输入按钮
          Expanded(
            child: issue.issueStatus.isOpen
                ? _buildCommentInput(state)
                : _buildClosedCommentHint(),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0);
  }

  /// 构建投票按钮
  Widget _buildVoteButton(Issue issue, bool isSubmitting) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSubmitting ? null : _toggleVote,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: issue.isVoted
                ? const Color(0xFF0080FF).withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: issue.isVoted
                  ? const Color(0xFF0080FF)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                issue.isVoted ? MdiIcons.thumbUp : MdiIcons.thumbUpOutline,
                size: 20,
                color: issue.isVoted
                    ? const Color(0xFF0080FF)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '${issue.voteCount}',
                style: TextStyle(
                  color: issue.isVoted
                      ? const Color(0xFF0080FF)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建关闭/重开按钮
  Widget _buildCloseReopenButton(Issue issue, bool isSubmitting) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOpen = issue.issueStatus.isOpen;
    final color = isOpen ? const Color(0xFFDC2626) : const Color(0xFF059669);
    final bgColor = isOpen
        ? (isDark
              ? const Color(0xFFDC2626).withValues(alpha: 0.15)
              : const Color(0xFFFEE2E2))
        : (isDark
              ? const Color(0xFF059669).withValues(alpha: 0.15)
              : const Color(0xFFD1FAE5));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSubmitting
            ? null
            : () {
                if (isOpen) {
                  context.read<IssueDetailBloc>().add(const IssueDetailClose());
                } else {
                  context.read<IssueDetailBloc>().add(
                    const IssueDetailReopen(),
                  );
                }
              },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                isOpen ? MdiIcons.closeCircleOutline : MdiIcons.refreshCircle,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                isOpen ? '关闭' : '重开',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建评论输入按钮
  Widget _buildCommentInput(IssueDetailState state) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showCommentDialog(state),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                MdiIcons.pencilOutline,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Text(
                '写评论...',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建已关闭评论提示
  Widget _buildClosedCommentHint() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            MdiIcons.lockOutline,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '该问题已关闭，无法评论',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示评论编辑底部面板
  void _showCommentDialog(IssueDetailState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final viewInsets = MediaQuery.of(sheetContext).viewInsets.bottom;
            final screenHeight = MediaQuery.of(sheetContext).size.height;
            final topPadding = MediaQuery.of(sheetContext).padding.top;
            // 面板最大高度：屏幕高度减去键盘高度和顶部安全区，留一点间距
            final maxSheetHeight = screenHeight - viewInsets - topPadding - 20;

            return Padding(
              padding: EdgeInsets.only(bottom: viewInsets),
              child: Container(
                height: maxSheetHeight.clamp(300.0, screenHeight * 0.85),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    // 顶部拖动条
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // 标题栏
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF0080FF,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              MdiIcons.commentEditOutline,
                              size: 18,
                              color: const Color(0xFF0080FF),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _replyToComment != null ? '回复评论' : '写评论',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                _cancelReply();
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 编辑器
                    Expanded(
                      child: Column(
                        children: [
                          // 回复提示条
                          if (_replyToComment != null)
                            _buildReplyBar(isDark, setSheetState),
                          // 评论草稿提示条
                          if (_showCommentDraftPrompt) ...[
                            _buildCommentDraftPrompt(),
                            const SizedBox(height: 12),
                          ],
                          // 编辑器
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: RichTextEditor(
                                key: _commentEditorKey,
                                controller: _commentController,
                                hintText: _replyToComment != null
                                    ? '回复 ${_replyToComment!.authorName}...'
                                    : '写下你的评论...',
                                maxLength: 500,
                                maxImages: 5,
                                compactMode: true,
                                draftId: 'comment_${widget.issueId}',
                                enableDraftManualSave: true,
                                onImagesChanged: (urls) {
                                  setState(() {
                                    _commentImageUrls = urls;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 提交按钮
                    Container(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 12,
                        bottom: MediaQuery.of(sheetContext).padding.bottom + 12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border(
                          top: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.5),
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.shadow.withValues(
                              alpha: 0.05,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // 保存草稿按钮
                          OutlinedButton.icon(
                            onPressed: state.isSubmitting
                                ? null
                                : _saveCommentDraft,
                            icon: const Icon(Icons.save_outlined, size: 16),
                            label: const Text('草稿'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0080FF),
                              side: const BorderSide(color: Color(0xFF0080FF)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 发表评论按钮
                          Expanded(
                            child: ElevatedButton(
                              onPressed: state.isSubmitting
                                  ? null
                                  : () {
                                      _submitComment();
                                      Navigator.of(sheetContext).pop();
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0080FF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: state.isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(MdiIcons.send, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          _replyToComment != null
                                              ? '回复'
                                              : '发表评论',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // 面板关闭时清除回复状态
      if (_replyToComment != null) {
        _cancelReply();
      }
    });
  }

  /// 构建回复提示条
  Widget _buildReplyBar(bool isDark, StateSetter setSheetState) {
    if (_replyToComment == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
          ),
          Flexible(
            child: Text(
              _replyToComment!.authorName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0080FF),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _replyToComment = null;
              });
              setSheetState(() {});
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
