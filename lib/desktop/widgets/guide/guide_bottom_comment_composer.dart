import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../core/bloc/auth/auth_bloc.dart';
import '../../../core/bloc/guide_comment/guide_comment_bloc.dart';
import '../../../core/bloc/guide_comment/guide_comment_event.dart';
import '../../../core/bloc/guide_comment/guide_comment_state.dart';
import '../../../core/models/guide_models.dart';
import '../../../core/services/quill_delta_codec.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../core/widgets/guide/guide_tokens.dart';
import '../../../core/widgets/rich_text_editor.dart';
import '../../../core/widgets/signed_network_image.dart';
import 'community_guide/community_guide_theme.dart';

/// B 站风格的底部固定评论输入条
///
/// 两态：
/// 1. **收起态（pill）**：头像 + 一行药丸输入框 + 「发送」按钮 占位
/// 2. **展开态（panel）**：富文本编辑器 + 工具栏 + 取消/发送
///
/// 动效：从底部滑入（外层由 [GuideBottomCommentBar] 控制可见性）；
/// 展开时通过 [AnimatedSize] 平滑撑高。
///
/// 数据：
/// - 通过 `BlocProvider<GuideCommentBloc>` 自上而下注入
/// - 提交时使用 `QuillDeltaCodec.encode` 与现有 issues / key_binding 评论一致
class GuideBottomCommentComposer extends StatefulWidget {
  /// 当前正在回复的目标（null 表示主评论）。
  /// 由父组件传入，用于显示「回复 @xxx」徽标。
  final GuideComment? replyTarget;

  /// 取消回复（清空 replyTarget）
  final VoidCallback? onCancelReply;

  const GuideBottomCommentComposer({
    super.key,
    this.replyTarget,
    this.onCancelReply,
  });

  @override
  State<GuideBottomCommentComposer> createState() =>
      GuideBottomCommentComposerState();
}

class GuideBottomCommentComposerState
    extends State<GuideBottomCommentComposer> {
  late QuillController _editorController;
  final GlobalKey<RichTextEditorState> _editorKey =
      GlobalKey<RichTextEditorState>();
  final FocusNode _focusNode = FocusNode();

  bool _expanded = false;
  List<String> _imageUrls = const [];

  @override
  void initState() {
    super.initState();
    _editorController = QuillController.basic();
  }

  @override
  void didUpdateWidget(GuideBottomCommentComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换回复目标时自动展开
    if (widget.replyTarget != null && widget.replyTarget != oldWidget.replyTarget) {
      _expand();
    }
  }

  @override
  void dispose() {
    _editorController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─── Auth helpers ───────────────────────────────────────────────────────

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

  // ─── Expand / collapse ──────────────────────────────────────────────────

  void _expand() {
    if (!_isLoggedIn()) {
      ToastUtils.showInfo(context, '登录后才能参与评论');
      return;
    }
    if (_expanded) return;
    setState(() => _expanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _collapse() {
    if (!_expanded) return;
    setState(() => _expanded = false);
    _focusNode.unfocus();
  }

  void _handleCancel() {
    _editorController.clear();
    _editorKey.currentState?.clearImages();
    _imageUrls = const [];
    widget.onCancelReply?.call();
    _collapse();
  }

  // ─── Submit ─────────────────────────────────────────────────────────────

  void _handleSubmit() {
    if (!_isLoggedIn()) {
      ToastUtils.showInfo(context, '登录后才能参与评论');
      return;
    }

    final plainText = _editorController.document.toPlainText().trim();
    if (plainText.isEmpty) {
      ToastUtils.showWarning(context, '请输入评论内容');
      return;
    }

    final content = QuillDeltaCodec.encode(_editorController.document);
    final target = widget.replyTarget;
    // 服务端 parentId=0 表示顶层，视为无父级
    final effectiveParentId = (target?.parentId != null && target!.parentId != 0)
        ? target.parentId
        : target?.id;
    context.read<GuideCommentBloc>().add(PostComment(
          content: content,
          images: _imageUrls,
          parentId: effectiveParentId,
          replyToId: target?.id,
          replyToName: target?.authorName,
        ));
  }

  void _onPostingDone() {
    // 清理 + 收起
    _editorController.clear();
    _editorKey.currentState?.clearImages();
    _imageUrls = const [];
    widget.onCancelReply?.call();
    _collapse();
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<GuideCommentBloc, GuideCommentState>(
      listenWhen: (prev, curr) =>
          prev.posting && !curr.posting && curr.error == null,
      listener: (context, state) => _onPostingDone(),
      child: _buildContainer(context),
    );
  }

  Widget _buildContainer(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final guideColors = CommunityGuideColors.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? guideColors.scaffoldBg.withValues(alpha: 0.96)
              : Colors.white.withValues(alpha: 0.97),
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : GuideTokens.borderLight,
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
          child: _expanded ? _buildExpanded(context) : _buildCollapsed(context),
        ),
      ),
    );
  }

  // ─── Collapsed pill ─────────────────────────────────────────────────────

  Widget _buildCollapsed(BuildContext context) {
    final isLoggedIn = _isLoggedIn();
    final hint = widget.replyTarget != null
        ? '回复 @${widget.replyTarget!.authorName}...'
        : (isLoggedIn ? '写下你的评论...' : '登录后参与评论');

    return Padding(
      key: const ValueKey('collapsed'),
      padding: const EdgeInsets.symmetric(
        horizontal: GuideTokens.space24,
        vertical: GuideTokens.space12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Avatar(
            avatarUrl: isLoggedIn ? _avatarUrl() : null,
            displayName: isLoggedIn ? _displayName() : '游客',
            size: 36,
          ),
          const SizedBox(width: GuideTokens.space12),
          Expanded(
            child: _CollapsedPill(
              hintText: hint,
              showReplyChip: widget.replyTarget != null,
              onTap: _expand,
              onCancelReply: widget.onCancelReply,
            ),
          ),
          const SizedBox(width: GuideTokens.space12),
          _GlowPostButton(
            label: widget.replyTarget != null ? '回复' : '发送',
            onTap: _expand,
          ),
        ],
      ),
    );
  }

  // ─── Expanded panel ─────────────────────────────────────────────────────

  Widget _buildExpanded(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('expanded'),
      padding: const EdgeInsets.fromLTRB(
        GuideTokens.space24,
        GuideTokens.space16,
        GuideTokens.space24,
        GuideTokens.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部：头像 + 回复目标 / 关闭
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(
                avatarUrl: _avatarUrl(),
                displayName: _displayName(),
                size: 36,
              ),
              const SizedBox(width: GuideTokens.space12),
              Expanded(
                child: widget.replyTarget != null
                    ? _ReplyTargetChip(
                        name: widget.replyTarget!.authorName,
                        onClear: widget.onCancelReply,
                      )
                    : Text(
                        _displayName(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: GuideTokens.textPrimary(context),
                        ),
                      ),
              ),
              IconButton(
                tooltip: '收起',
                onPressed: _handleCancel,
                icon: Icon(
                  Icons.expand_more,
                  color: GuideTokens.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: GuideTokens.space12),

          // 富文本编辑器（评论场景用精简工具栏：粗体/斜体/标题/列表 + 图片，
          // 去掉下划线/删除线/引用/代码块/链接/撤销重做等重排版功能）
          SizedBox(
            height: 280,
            child: RichTextEditor(
              key: _editorKey,
              controller: _editorController,
              hintText: widget.replyTarget != null
                  ? '回复 @${widget.replyTarget!.authorName}...'
                  : '写下你的评论...',
              compactMode: true,
              maxLength: 500,
              maxImages: 5,
              imageMode: ImageMode.attachment,
              toolbarIconSize: 20,
              toolbarButtonSize: 36,
              onImagesChanged: (urls) {
                _imageUrls = urls;
              },
            ),
          ),

          const SizedBox(height: GuideTokens.space12),

          // 底部操作栏
          Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: _handleCancel,
                style: TextButton.styleFrom(
                  foregroundColor: GuideTokens.textSecondary(context),
                ),
                child: const Text('取消'),
              ),
              const SizedBox(width: GuideTokens.space8),
              BlocBuilder<GuideCommentBloc, GuideCommentState>(
                buildWhen: (prev, curr) => prev.posting != curr.posting,
                builder: (context, state) {
                  return _GlowPostButton(
                    label: widget.replyTarget != null ? '回复' : '发送',
                    loading: state.posting,
                    onTap: _handleSubmit,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 收起态药丸
// ═══════════════════════════════════════════════════════════════════════════

class _CollapsedPill extends StatefulWidget {
  final String hintText;
  final bool showReplyChip;
  final VoidCallback? onTap;
  final VoidCallback? onCancelReply;

  const _CollapsedPill({
    required this.hintText,
    this.showReplyChip = false,
    this.onTap,
    this.onCancelReply,
  });

  @override
  State<_CollapsedPill> createState() => _CollapsedPillState();
}

class _CollapsedPillState extends State<_CollapsedPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark
        ? Colors.white.withValues(alpha: _hover ? 0.08 : 0.05)
        : (_hover ? Colors.white : const Color(0xFFF1F5F9));
    final borderColor = isDark
        ? Colors.white.withValues(alpha: _hover ? 0.14 : 0.08)
        : GuideTokens.borderLight;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: GuideTokens.durationFast,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: GuideTokens.space20),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: GuideTokens.textTertiary(context),
              ),
              const SizedBox(width: GuideTokens.space8),
              Expanded(
                child: Text(
                  widget.hintText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: GuideTokens.textTertiary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.showReplyChip && widget.onCancelReply != null)
                IconButton(
                  tooltip: '取消回复',
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  splashRadius: 14,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: widget.onCancelReply,
                  icon: Icon(
                    Icons.close,
                    color: GuideTokens.textTertiary(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 回复目标徽标 ──────────────────────────────────────────────────────────

class _ReplyTargetChip extends StatelessWidget {
  final String name;
  final VoidCallback? onClear;
  const _ReplyTargetChip({required this.name, this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GuideTokens.space12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.reply_rounded, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '回复 @$name',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onClear,
              child: Icon(
                Icons.close,
                size: 14,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 头像 ─────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final double size;

  const _Avatar({
    this.avatarUrl,
    required this.displayName,
    this.size = 36,
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

// ─── 蓝色发光发送按钮 ──────────────────────────────────────────────────────

class _GlowPostButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _GlowPostButton({
    required this.label,
    this.loading = false,
    this.onTap,
  });

  @override
  State<_GlowPostButton> createState() => _GlowPostButtonState();
}

class _GlowPostButtonState extends State<_GlowPostButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.loading || widget.onTap == null;

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) {
        if (!disabled) setState(() => _hover = true);
      },
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: disabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: GuideTokens.durationFast,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: GuideTokens.space24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF7DD3FC),
                Color(0xFF3B82F6),
                Color(0xFF1D4ED8),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(
                        alpha: _hover ? 0.65 : 0.50,
                      ),
                      blurRadius: _hover ? 28 : 20,
                      spreadRadius: _hover ? 2 : 0,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: const Color(0xFF60A5FA).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      shadows: [
                        Shadow(
                          color: Color(0x33000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
