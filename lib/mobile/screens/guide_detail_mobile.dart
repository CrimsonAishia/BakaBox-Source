import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/bloc/guide_detail/guide_detail_bloc.dart';
import '../../core/bloc/guide_detail/guide_detail_event.dart';
import '../../core/bloc/guide_detail/guide_detail_state.dart';
import '../../core/bloc/guide_list/guide_list_bloc.dart';
import '../../core/bloc/guide_list/guide_list_event.dart';
import '../../core/bloc/auth/auth_bloc.dart';
import '../../core/models/guide_models.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast_utils.dart';
import '../../core/widgets/embeds/bilibili_embed_builder.dart';
import '../../core/widgets/guide/guide_tokens.dart';
import '../../core/widgets/rich_text_viewer.dart';
import '../../core/widgets/signed_network_image.dart';
import '../../desktop/widgets/guide/community_guide/community_guide_format.dart';
import '../../desktop/widgets/guide/guide_comment_panel.dart';
import '../../desktop/widgets/guide/guide_bottom_comment_composer.dart';
import '../../core/bloc/guide_comment/guide_comment_bloc.dart';
import '../../core/bloc/guide_comment/guide_comment_event.dart';
import '../../core/constants/app_colors.dart';

class GuideDetailMobile extends StatefulWidget {
  final int id;

  const GuideDetailMobile({super.key, required this.id});

  @override
  State<GuideDetailMobile> createState() => _GuideDetailMobileState();
}

class _GuideDetailMobileState extends State<GuideDetailMobile> {
  late final GuideDetailBloc _detailBloc;
  late final GuideCommentBloc _commentBloc;
  Timer? _viewReportTimer;
  bool _viewReported = false;
  GuideComment? _replyTarget;

  @override
  void initState() {
    super.initState();
    _detailBloc = GuideDetailBloc()..add(LoadGuide(widget.id));
    _commentBloc = GuideCommentBloc(guideId: widget.id)
      ..add(const LoadComments(reset: true));
    _reportAnalytics();

    _viewReportTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_viewReported) {
        _viewReported = true;
        _detailBloc.add(const ReportView());
      }
    });
  }

  @override
  void dispose() {
    _viewReportTimer?.cancel();
    _detailBloc.close();
    _commentBloc.close();
    super.dispose();
  }

  void _reportAnalytics() {
    AnalyticsService.instance.trackEvent('guide_detail_view_mobile', {
      'id': widget.id,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _detailBloc),
        BlocProvider.value(value: _commentBloc),
      ],
      child: BlocListener<GuideDetailBloc, GuideDetailState>(
        listenWhen: (prev, curr) =>
            prev.lastInteractionId != curr.lastInteractionId,
        listener: (context, state) {
          try {
            context.read<GuideListBloc>().add(RefreshGuide(widget.id));
          } catch (_) {}
        },
        child: Scaffold(
          backgroundColor: isDark ? AppColors.slate800 : Colors.white,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: isDark ? AppColors.slate800 : Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: const Text(
              '攻略详情',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: GuideBottomCommentComposer(
              replyTarget: _replyTarget,
              onCancelReply: () => setState(() => _replyTarget = null),
            ),
          ),
          body: BlocBuilder<GuideDetailBloc, GuideDetailState>(
            builder: (context, state) {
              return switch (state.status) {
                DetailStatus.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                DetailStatus.success => _buildContent(context, state),
                DetailStatus.notFound => _buildMessage('攻略不存在或已被删除'),
                DetailStatus.blocked => _buildMessage('无权访问该攻略'),
                DetailStatus.failure => _buildError(context, state),
              };
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            size: 64,
            color: GuideTokens.textTertiary(context),
          ),
          const SizedBox(height: 16),
          Text(message),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, GuideDetailState state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: GuideTokens.textTertiary(context),
          ),
          const SizedBox(height: 16),
          Text(state.error ?? '加载失败'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _detailBloc.add(LoadGuide(widget.id)),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, GuideDetailState state) {
    final guide = state.guide!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (guide.coverUrl != null && guide.coverUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: SignedNetworkImage(
                  url: guide.coverUrl,
                  fallback: Container(
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            guide.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildAuthorRow(context, guide),
          const SizedBox(height: 16),
          if (guide.content != null && guide.content!.isNotEmpty)
            RichTextViewer(
              key: ValueKey('rich-${guide.id}'),
              content: guide.content!,
              embedBuilders: const [BilibiliEmbedBuilder()],
            ),
          const SizedBox(height: 24),
          _buildInteractionBar(context, guide),
          const SizedBox(height: 24),
          GuideCommentPanel(
            totalCountFromGuide: guide.commentCount,
            onReplyRequested: (comment) {
              setState(() => _replyTarget = comment);
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAuthorRow(BuildContext context, Guide guide) {
    final publishedAt =
        guide.publishedAt?.toIso8601String() ??
        guide.createdAt.toIso8601String();

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Theme.of(
            context,
          ).primaryColor.withValues(alpha: 0.1),
          child: guide.authorAvatar != null
              ? ClipOval(
                  child: SignedNetworkImage(
                    url: guide.authorAvatar,
                    fallback: Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : Text(
                  guide.authorName.isNotEmpty
                      ? guide.authorName[0].toUpperCase()
                      : '?',
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                guide.authorName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                '发布于 ${Formatters.formatDate(publishedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (guide.readingTimeMin > 0)
              Text(
                '${guide.readingTimeMin} 分钟阅读',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            Text(
              '${formatGuideCount(guide.viewCount)} 浏览',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInteractionBar(BuildContext context, Guide guide) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _InteractionButton(
          icon: guide.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
          label: guide.likeCount > 0 ? '${guide.likeCount}' : '点赞',
          color: guide.isLiked
              ? AppColors.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          onTap: () {
            if (!context.read<AuthBloc>().state.isAuthenticated) {
              ToastUtils.showInfo(context, '请先登录');
              return;
            }
            _detailBloc.add(const ToggleLike());
          },
        ),
        _InteractionButton(
          icon: guide.isFavorited ? Icons.favorite : Icons.favorite_border,
          label: guide.favoriteCount > 0 ? '${guide.favoriteCount}' : '收藏',
          color: guide.isFavorited
              ? AppColors.red500
              : Theme.of(context).colorScheme.onSurfaceVariant,
          onTap: () {
            if (!context.read<AuthBloc>().state.isAuthenticated) {
              ToastUtils.showInfo(context, '请先登录');
              return;
            }
            _detailBloc.add(const ToggleFavorite());
          },
        ),
        _InteractionButton(
          icon: Icons.chat_bubble_outline,
          label: guide.commentCount > 0 ? '${guide.commentCount}' : '评论',
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          onTap: () {
            // Scroll down or focus comment composer
            // Since it's a mobile page, we can just let user tap to focus if they want.
            // In a real implementation we'd scroll to the comment panel.
          },
        ),
      ],
    );
  }
}

class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _InteractionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
