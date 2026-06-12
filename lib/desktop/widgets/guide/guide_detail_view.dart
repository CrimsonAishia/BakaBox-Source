import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/guide_detail/guide_detail_bloc.dart';
import '../../../core/bloc/guide_detail/guide_detail_event.dart';
import '../../../core/bloc/guide_detail/guide_detail_state.dart';
import '../../../core/bloc/guide_list/guide_list_bloc.dart';
import '../../../core/bloc/guide_list/guide_list_event.dart';
import '../../../core/bloc/auth/auth_bloc.dart';
import '../../../core/api/server_api.dart';
import '../../../core/models/guide_models.dart';
import '../../../core/models/map_tag_models.dart' show MapTagSimple;
import '../../../core/models/server_models.dart' show MapData;
import '../../../core/services/analytics_service.dart';
import '../../../core/services/desktop_navigator.dart';
import '../../../core/services/token_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../core/widgets/embeds/bilibili_embed_builder.dart';
import '../../../core/widgets/marquee_text.dart';
import '../../../core/widgets/guide/guide_interaction_dock.dart';
import '../../../core/widgets/guide/guide_reading_progress.dart';
import '../../../core/widgets/guide/guide_report_dialog.dart';
import '../../../core/widgets/guide/guide_status_banner.dart';
import '../../../core/widgets/guide/guide_tokens.dart';
import '../../../core/widgets/rich_text_viewer.dart';
import '../../../core/widgets/signed_network_image.dart';
import '../../../core/bloc/guide_comment/guide_comment_bloc.dart';
import '../../../core/bloc/guide_comment/guide_comment_event.dart';
import 'community_guide/community_guide_format.dart';
import 'guide_bottom_comment_composer.dart';
import 'guide_comment_panel.dart';
import '../../../core/constants/app_colors.dart';

/// 攻略详情页
///
/// 由 [CommunityGuideScreen] 在 detail 视图时渲染。
/// 接入 [GuideDetailBloc] 处理加载、互动、上报。
/// 滚动联动 [GuideReadingProgress] 与 [GuideInteractionDock]。
class GuideDetailView extends StatefulWidget {
  final int id;

  const GuideDetailView({
    super.key,
    required this.id,
  });

  @override
  State<GuideDetailView> createState() => _GuideDetailViewState();
}

class _GuideDetailViewState extends State<GuideDetailView> {
  late final ScrollController _scrollController;
  late final GuideDetailBloc _detailBloc;
  late final GuideCommentBloc _commentBloc;
  Timer? _viewReportTimer;
  bool _viewReported = false;

  // 评论区 GlobalKey，用于滚动定位 / 可见性检测
  final GlobalKey _commentSectionKey = GlobalKey();

  /// 评论区是否进入视口（决定底部 composer 是否滑入）
  bool _commentBarVisible = false;

  /// 滚动指示器状态
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  /// 当前回复目标（B 站风格底部 composer 状态）
  GuideComment? _replyTarget;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
    _detailBloc = GuideDetailBloc()..add(LoadGuide(widget.id));
    _commentBloc = GuideCommentBloc(guideId: widget.id)
      ..add(const LoadComments(reset: true));

    // 进入立即上报埋点 guide_detail_view（fire-and-forget）
    _reportAnalytics();

    // 进入 3s 后上报 view
    _viewReportTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_viewReported) {
        _viewReported = true;
        _detailBloc.add(const ReportView());
      }
    });

    // 首帧渲染后初始化滚动指示器状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleScroll();
    });
  }

  @override
  void dispose() {
    _viewReportTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _detailBloc.close();
    _commentBloc.close();
    super.dispose();
  }

  void _handleScroll() {
    // 更新滚动指示器
    if (_scrollController.hasClients) {
      final pos = _scrollController.position;
      final newCanUp = pos.pixels > 20;
      final newCanDown = pos.pixels < pos.maxScrollExtent - 20;
      if (newCanUp != _canScrollUp || newCanDown != _canScrollDown) {
        setState(() {
          _canScrollUp = newCanUp;
          _canScrollDown = newCanDown;
        });
      }
    }

    // 检测评论区是否进入视口
    final ctx = _commentSectionKey.currentContext;
    if (ctx == null) return;
    final renderBox = ctx.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return;

    // 评论区顶部相对于 viewport 的位置
    final topOffset = renderBox.localToGlobal(Offset.zero).dy;
    final viewportHeight = MediaQuery.of(context).size.height;

    // 评论区顶部进入屏幕 85% 处时滑入底部 composer
    final shouldShow = topOffset < viewportHeight * 0.85;
    if (shouldShow != _commentBarVisible) {
      setState(() => _commentBarVisible = shouldShow);
    }
  }

  void _reportAnalytics() {
    // fire-and-forget
    AnalyticsService.instance.trackEvent('guide_detail_view', {
      'id': widget.id,
    });
  }

  void _scrollToComments() {
    final renderBox = _commentSectionKey.currentContext?.findRenderObject()
        as RenderBox?;
    if (renderBox != null && _scrollController.hasClients) {
      final offset = renderBox.localToGlobal(Offset.zero).dy +
          _scrollController.offset -
          100; // 留出 100px 顶部空间
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: GuideTokens.durationSlow,
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// 获取当前登录用户的数值 ID（与评论 authorId 同体系）
  /// 获取当前登录用户的数值 ID（与攻略 / 评论 authorId 同体系）
  ///
  /// 必须用后端用户 ID（[BackendUserInfo.id]，来自 TokenService），而不是论坛
  /// UID（AuthBloc.userInfo.uid，是另一套字符串体系）。authorId 是后端数值 ID，
  /// 用论坛 uid 比较永远不相等，会导致「自己的攻略」判断失效。
  int? _getCurrentUserId(BuildContext context) {
    return TokenService.instance.userInfo?.id;
  }

  /// 当前是否已登录（用于互动前的登录拦截）
  bool _isLoggedIn(BuildContext context) =>
      context.read<AuthBloc>().state.isAuthenticated;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _detailBloc),
        BlocProvider.value(value: _commentBloc),
      ],
      child: BlocListener<GuideDetailBloc, GuideDetailState>(
        listenWhen: (prev, curr) =>
            prev.lastInteractionId != curr.lastInteractionId,
        listener: (context, state) {
          // 互动（点赞/收藏）成功后通知列表 Bloc 刷新对应卡片
          try {
            context
                .read<GuideListBloc>()
                .add(RefreshGuide(widget.id));
          } catch (_) {
            // GuideListBloc 不在当前上下文时静默忽略
          }
        },
        child: BlocBuilder<GuideDetailBloc, GuideDetailState>(
          builder: (context, state) {
            return _buildBody(context, state);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, GuideDetailState state) {
    return switch (state.status) {
      DetailStatus.loading => _buildLoading(context),
      DetailStatus.success => _buildContent(context, state),
      DetailStatus.notFound => _buildNotFound(context),
      DetailStatus.blocked => _buildBlocked(context),
      DetailStatus.failure => _buildError(context, state),
    };
  }

  // ─── 加载态 ─────────────────────────────────────────────────────────────

  Widget _buildLoading(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  // ─── 404 ────────────────────────────────────────────────────────────────

  Widget _buildNotFound(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.article_outlined,
            size: 64,
            color: GuideTokens.textTertiary(context),
          ),
          const SizedBox(height: GuideTokens.space16),
          Text(
            '攻略不存在或已被删除',
            style: theme.textTheme.titleMedium?.copyWith(
              color: GuideTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: GuideTokens.space24),
          FilledButton.icon(
            onPressed: () => _navigateBack(),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('返回列表'),
          ),
        ],
      ),
    );
  }

  // ─── 403 ────────────────────────────────────────────────────────────────

  Widget _buildBlocked(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 64,
            color: GuideTokens.textTertiary(context),
          ),
          const SizedBox(height: GuideTokens.space16),
          Text(
            '无权访问该攻略',
            style: theme.textTheme.titleMedium?.copyWith(
              color: GuideTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: GuideTokens.space8),
          Text(
            '可能是作者限制了访问权限',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: GuideTokens.textTertiary(context),
            ),
          ),
          const SizedBox(height: GuideTokens.space24),
          FilledButton.icon(
            onPressed: () => _navigateBack(),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('返回列表'),
          ),
        ],
      ),
    );
  }

  // ─── 错误态 ─────────────────────────────────────────────────────────────

  Widget _buildError(BuildContext context, GuideDetailState state) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: GuideTokens.textTertiary(context),
          ),
          const SizedBox(height: GuideTokens.space16),
          Text(
            state.error ?? '加载失败',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: GuideTokens.textSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: GuideTokens.space24),
          FilledButton.icon(
            onPressed: () => _detailBloc.add(LoadGuide(widget.id)),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  // ─── 正文内容 ───────────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context, GuideDetailState state) {
    final guide = state.guide!;

    return Stack(
      children: [
        // 阅读进度条
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GuideReadingProgress(scrollController: _scrollController),
        ),

        // 主内容区域：撑满宽度，主内容包裹在一张大卡片里
        SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 主卡片（封面 + 分类标签 + 标题 + 作者条 + 地图横幅 + 正文 + 互动栏）
              Container(
                decoration: BoxDecoration(
                  color: GuideTokens.cardSurface(context),
                  borderRadius: BorderRadius.zero,
                  border: Border.all(
                    color: GuideTokens.border(context),
                  ),
                ),
                padding: const EdgeInsets.all(GuideTokens.space20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero 封面
                    if (guide.coverUrl != null &&
                        guide.coverUrl!.isNotEmpty)
                      _buildHeroCover(context, guide),

                    if (guide.coverUrl != null &&
                        guide.coverUrl!.isNotEmpty)
                      const SizedBox(height: GuideTokens.space16),

                    // 分类 chip + 标签（药丸形）
                    _buildCategoryAndTags(context, guide),

                    const SizedBox(height: GuideTokens.space16),

                    // 标题
                    _buildTitle(context, guide),

                    const SizedBox(height: GuideTokens.space12),

                    // 作者条（头像 + 名字/时间 在左，阅读时间/浏览数 在右）
                    _buildAuthorRow(context, guide),

                    // GuideMapBanner（mapInfo != null 时）
                    if (guide.mapInfo != null) ...[
                      const SizedBox(height: GuideTokens.space16),
                      _buildMapBannerHero(context, guide),
                    ],

                    // StatusBanner（非 published 时，仅作者本人或管理员可见）
                    if (guide.status != GuideStatus.published &&
                        _canSeeStatusBanner(context, guide)) ...[
                      const SizedBox(height: GuideTokens.space16),
                      GuideStatusBanner(
                        status: guide.status,
                        rejectReason: guide.rejectReason,
                        onEditTap:
                            guide.status == GuideStatus.rejected
                                ? () => _navigateToEditor(guide.id)
                                : null,
                      ),
                    ],

                    // 正文 RichTextViewer
                    if (guide.content != null &&
                        guide.content!.isNotEmpty) ...[
                      const SizedBox(height: GuideTokens.space20),
                      _buildRichContent(context, guide),
                    ],

                    const SizedBox(height: GuideTokens.space20),

                    // 顶部分隔线 + 互动栏
                    Container(
                      height: 1,
                      color: GuideTokens.divider(context),
                    ),
                    const SizedBox(height: GuideTokens.space8),

                    // 互动栏（文内）
                    _buildInlineInteractionBar(context, guide),
                  ],
                ),
              ),

              const SizedBox(height: GuideTokens.space24),

              // 评论区
              _buildCommentSection(context, guide),

              // 底部 composer 占位空间（避免最后一条评论被遮挡）
              SizedBox(height: _commentBarVisible ? 150 : 0),
            ],
          ),
        ),

        // 右下浮动「回到顶部」按钮
        Positioned(
          bottom: _commentBarVisible ? 90 : 32,
          right: 32,
          child: GuideInteractionDock(
            scrollController: _scrollController,
          ),
        ),

        // 顶部滚动指示器（向上渐变 + 箭头）
        if (_canScrollUp)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ScrollIndicator(
              direction: _ScrollDirection.up,
              onTap: () => _scrollController.animateTo(
                (_scrollController.offset - 300)
                    .clamp(0.0, _scrollController.position.maxScrollExtent),
                duration: GuideTokens.durationSlow,
                curve: Curves.easeOutCubic,
              ),
            ),
          ),

        // 底部滚动指示器（向下渐变 + 箭头）
        if (_canScrollDown && !_commentBarVisible)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _ScrollIndicator(
              direction: _ScrollDirection.down,
              onTap: () => _scrollController.animateTo(
                (_scrollController.offset + 300)
                    .clamp(0.0, _scrollController.position.maxScrollExtent),
                duration: GuideTokens.durationSlow,
                curve: Curves.easeOutCubic,
              ),
            ),
          ),

        // 底部 fixed 评论 composer（B 站风格，滚动到评论区时滑入）
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            offset: _commentBarVisible
                ? Offset.zero
                : const Offset(0, 1.2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _commentBarVisible ? 1.0 : 0.0,
              child: GuideBottomCommentComposer(
                replyTarget: _replyTarget,
                onCancelReply: () => setState(() => _replyTarget = null),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Hero 封面 ──────────────────────────────────────────────────────────

  Widget _buildHeroCover(BuildContext context, Guide guide) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(GuideTokens.radius16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: SignedNetworkImage(
          url: guide.coverUrl,
          fallback: Container(
            color: GuideTokens.fallbackBg(context),
            child: Center(
              child: Icon(
                Icons.image_outlined,
                size: 48,
                color: GuideTokens.textTertiary(context),
              ),
            ),
          ),
          cacheWidth: 1640,
          cacheHeight: 924,
        ),
      ),
    );
  }

  // ─── 分类 + 标签 ────────────────────────────────────────────────────────

  Widget _buildCategoryAndTags(BuildContext context, Guide guide) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: GuideTokens.space8,
      runSpacing: GuideTokens.space8,
      children: [
        // 分类 chip（药丸形 / 实心 / 主色）
        if (guide.categoryName != null && guide.categoryName!.isNotEmpty)
          _buildCategoryChip(context, guide),
        // 标签 chips（药丸形 / 半透明主色底）
        ...guide.tags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: GuideTokens.space12,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '#$tag',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildCategoryChip(BuildContext context, Guide guide) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GuideTokens.space12,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        guide.categoryName!,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ─── 标题 ───────────────────────────────────────────────────────────────

  Widget _buildTitle(BuildContext context, Guide guide) {
    final theme = Theme.of(context);
    return Text(
      guide.title,
      style: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: GuideTokens.textPrimary(context),
        height: 1.25,
        letterSpacing: -0.5,
      ),
    );
  }

  // ─── 作者条（新版样式：左侧头像 + 名字/时间，右侧阅读时间 + 浏览数）──────

  Widget _buildAuthorRow(BuildContext context, Guide guide) {
    final theme = Theme.of(context);
    final publishedAt = guide.publishedAt?.toIso8601String() ??
        guide.createdAt.toIso8601String();
    final tertiary = GuideTokens.textTertiary(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 头像
        _AuthorAvatar(
          avatarUrl: guide.authorAvatar,
          authorName: guide.authorName,
          size: 36,
        ),
        const SizedBox(width: GuideTokens.space12),

        // 名字 + 发布时间（纵向）
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                guide.authorName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: GuideTokens.textPrimary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '发布于 ${Formatters.formatDate(publishedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // 阅读时间
        if (guide.readingTimeMin > 0) ...[
          Icon(Icons.schedule_outlined, size: 14, color: tertiary),
          const SizedBox(width: GuideTokens.space4),
          Text(
            '${guide.readingTimeMin} 分钟阅读',
            style: theme.textTheme.bodySmall?.copyWith(
              color: tertiary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: GuideTokens.space16),
        ],

        // 浏览数
        Icon(Icons.visibility_outlined, size: 14, color: tertiary),
        const SizedBox(width: GuideTokens.space4),
        Text(
          '${formatGuideCount(guide.viewCount)} 浏览',
          style: theme.textTheme.bodySmall?.copyWith(
            color: tertiary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ─── 地图横幅（hero 样式：背景图 + 居中地图名 + 查看地图渐变按钮）──────

  Widget _buildMapBannerHero(BuildContext context, Guide guide) {
    final mapInfo = guide.mapInfo!;
    final effectiveMapName = guide.mapName ?? mapInfo.mapName;
    final effectiveMapLabel =
        mapInfo.mapLabel.isNotEmpty ? mapInfo.mapLabel : (guide.mapLabel ?? '');
    final effectiveMapBackground =
        guide.mapBackground ?? mapInfo.mapBackground;

    return _MapBannerHero(
      mapName: effectiveMapName,
      mapLabel: effectiveMapLabel,
      mapBackground: effectiveMapBackground,
      tags: mapInfo.tags,
      onViewMap: () {
        DesktopNavigatorProvider.of(context)
            ?.openMapDatabase(mapName: effectiveMapName);
      },
    );
  }

  // ─── 正文 ──────────────────────────────────────────────────────────────

  Widget _buildRichContent(BuildContext context, Guide guide) {
    return RichTextViewer(
      content: guide.content!,
      embedBuilders: const [BilibiliEmbedBuilder()],
    );
  }

  // ─── 文内互动栏（卡片底部 4 按钮：点赞 / 收藏 / 评论 / 举报）──────────

  Widget _buildInlineInteractionBar(BuildContext context, Guide guide) {
    final currentUserId = _getCurrentUserId(context);
    final isLoggedIn = _isLoggedIn(context);
    final isOwnGuide = currentUserId != null && currentUserId == guide.authorId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GuideTokens.space4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _InteractionButton(
            icon: guide.isLiked
                ? Icons.thumb_up_rounded
                : Icons.thumb_up_outlined,
            label: guide.likeCount > 0 ? '${guide.likeCount}' : '点赞',
            color: guide.isLiked
                ? GuideTokens.likeColor(context)
                : GuideTokens.textSecondary(context),
            onTap: !isLoggedIn
                ? () => ToastUtils.showInfo(context, '登录后才能点赞')
                : isOwnGuide
                    ? () => ToastUtils.showInfo(context, '不能给自己的攻略点赞')
                    : () => _detailBloc.add(const ToggleLike()),
          ),
          _InteractionButton(
            icon: guide.isFavorited
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: guide.favoriteCount > 0
                ? '${guide.favoriteCount}'
                : '收藏',
            color: guide.isFavorited
                ? GuideTokens.favoriteColor(context)
                : GuideTokens.textSecondary(context),
            onTap: !isLoggedIn
                ? () => ToastUtils.showInfo(context, '登录后才能收藏')
                : isOwnGuide
                    ? () => ToastUtils.showInfo(context, '不能收藏自己的攻略')
                    : () => _detailBloc.add(const ToggleFavorite()),
          ),
          _InteractionButton(
            icon: Icons.chat_bubble_outline,
            label: guide.commentCount > 0
                ? '评论 (${guide.commentCount})'
                : '评论',
            color: GuideTokens.textSecondary(context),
            onTap: _scrollToComments,
          ),
          // 举报/拉黑（仅登录用户且非自己的攻略显示）
          if (isLoggedIn && !isOwnGuide)
            _ReportBlockButton(
              guideId: guide.id,
              authorId: guide.authorId,
              authorName: guide.authorName,
              onReport: () => ReportDialog.show(
                context,
                targetId: guide.id,
                targetType: 'guide',
              ),
            ),
        ],
      ),
    );
  }

  // ─── 评论区 ─────────────────────────────────────────────────────────────

  Widget _buildCommentSection(BuildContext context, Guide guide) {
    return Container(
      key: _commentSectionKey,
      child: GuideCommentPanel(
        totalCountFromGuide: guide.commentCount,
        onReplyRequested: (target) {
          setState(() => _replyTarget = target);
        },
      ),
    );
  }

  // ─── 导航辅助 ──────────────────────────────────────────────────────────

  void _navigateBack() {
    // 通过 PopScope 机制返回列表
    Navigator.of(context).maybePop();
  }

  /// 导航到编辑器（用于驳回 banner 的「修改后重新提交」入口）
  void _navigateToEditor(int guideId) {
    DesktopNavigatorProvider.of(context)
        ?.openGuideEditor(guideId: guideId);
  }

  /// 判断当前用户是否可以看到状态 Banner（仅作者本人或管理员/版主）
  bool _canSeeStatusBanner(BuildContext context, Guide guide) {
    final currentUserId = _getCurrentUserId(context);
    if (currentUserId == null) return false;

    // 作者本人
    if (currentUserId == guide.authorId) return true;

    // 管理员判断（userGroup 为 admin）
    try {
      final authState = context.read<AuthBloc>().state;
      final userGroup = authState.userInfo?.userGroup;
      if (userGroup == 'admin' || userGroup == 'moderator') return true;
    } catch (_) {}

    return false;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 内部子组件
// ═══════════════════════════════════════════════════════════════════════════════

/// 互动栏按钮
class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _InteractionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: GuideTokens.borderRadius8,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GuideTokens.space12,
          vertical: GuideTokens.space8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: GuideTokens.space4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 举报按钮
class _ReportBlockButton extends StatelessWidget {
  final int guideId;
  final int authorId;
  final String authorName;
  final VoidCallback? onReport;

  const _ReportBlockButton({
    required this.guideId,
    required this.authorId,
    required this.authorName,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onReport,
      borderRadius: GuideTokens.borderRadius8,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GuideTokens.space12,
          vertical: GuideTokens.space8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: GuideTokens.textSecondary(context),
            ),
            const SizedBox(width: GuideTokens.space4),
            Text(
              '举报',
              style: TextStyle(
                fontSize: 13,
                color: GuideTokens.textSecondary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 作者头像组件
class _AuthorAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String authorName;
  final double size;

  const _AuthorAvatar({
    this.avatarUrl,
    required this.authorName,
    this.size = 48,
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
      color: theme.colorScheme.primary.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 地图横幅（仿 MapGroupCard 样式：背景图 + 底部渐变 + 地图名/译名 + 标签）
///
/// 整张卡片可点击，点击进入地图数据库对应地图详情。
class _MapBannerHero extends StatefulWidget {
  final String mapName;
  final String mapLabel;
  final String? mapBackground;
  final List<MapTagSimple> tags;
  final VoidCallback? onViewMap;

  const _MapBannerHero({
    required this.mapName,
    required this.mapLabel,
    this.mapBackground,
    this.tags = const [],
    this.onViewMap,
  });

  @override
  State<_MapBannerHero> createState() => _MapBannerHeroState();
}

class _MapBannerHeroState extends State<_MapBannerHero> {
  bool _isHovered = false;
  final ServerApi _serverApi = ServerApi();

  /// 从地图库补全的完整信息（包含标签/译名/背景），首帧后异步填充
  MapData? _fullMapInfo;

  @override
  void initState() {
    super.initState();
    _loadFullMapInfo();
  }

  @override
  void didUpdateWidget(_MapBannerHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapName != widget.mapName) {
      _fullMapInfo = null;
      _loadFullMapInfo();
    }
  }

  /// 攻略详情下发的 mapInfo 为精简版（通常缺少 tags/mapLabel），
  /// 这里复用地图库的数据源补全完整信息。
  Future<void> _loadFullMapInfo() async {
    if (widget.mapName.isEmpty) return;
    try {
      final data = await _serverApi.getMapInfo(widget.mapName);
      if (mounted && data != null) {
        setState(() => _fullMapInfo = data);
      }
    } catch (_) {
      // 静默失败：保留攻略自带的精简信息
    }
  }

  /// 译名：优先用补全数据，其次用攻略自带
  String get _effectiveMapLabel {
    final full = _fullMapInfo?.mapLabel;
    if (full != null && full.isNotEmpty && full != widget.mapName) {
      return full;
    }
    return widget.mapLabel;
  }

  /// 标签：优先用补全数据，其次用攻略自带
  List<MapTagSimple> get _effectiveTags {
    final full = _fullMapInfo?.tags;
    if (full != null && full.isNotEmpty) return full;
    return widget.tags;
  }

  /// 背景图：优先用攻略自带，其次用补全数据
  String? get _effectiveBackground {
    if (widget.mapBackground != null && widget.mapBackground!.isNotEmpty) {
      return widget.mapBackground;
    }
    return _fullMapInfo?.mapUrl;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mapLabel = _effectiveMapLabel;
    final tags = _effectiveTags;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onViewMap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GuideTokens.radius12),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08)),
              width: _isHovered ? 2 : 1,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GuideTokens.radius12),
            child: SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 背景图
                  SignedNetworkImage(
                    url: _effectiveBackground,
                    fallback: _buildFallback(),
                    cacheWidth: 1600,
                    cacheHeight: 480,
                  ),

                  // 底部渐变遮罩
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(
                              alpha: _isHovered ? 0.95 : 0.8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 右上角「查看地图」提示
                  Positioned(
                    top: 10,
                    right: 12,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _isHovered ? 1.0 : 0.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_new,
                                size: 13, color: Colors.white),
                            SizedBox(width: 5),
                            Text(
                              '查看地图',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 地图名 + 译名 + 标签
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 地图技术名
                        Row(
                          children: [
                            const Icon(
                              Icons.map_outlined,
                              size: 18,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: MarqueeText(
                                text: widget.mapName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.2,
                                  fontFamily: 'monospace',
                                  letterSpacing: 0.5,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 8),
                                    Shadow(
                                      color: Colors.black,
                                      offset: Offset(1, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // 地图译名
                        if (mapLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.translate,
                                size: 15,
                                color: Colors.white.withValues(alpha: 0.9),
                                shadows: const [
                                  Shadow(color: Colors.black, blurRadius: 4),
                                ],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: MarqueeText(
                                  text: mapLabel,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    shadows: const [
                                      Shadow(
                                          color: Colors.black, blurRadius: 4),
                                      Shadow(
                                        color: Colors.black,
                                        offset: Offset(1, 1),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // 标签
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.label_outline,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 6),
                              Expanded(child: _MapTagWrap(tags: tags)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GuideTokens.gradientDarkStart,
            GuideTokens.gradientDarkEnd,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.map_outlined,
          size: 48,
          color: Colors.white24,
        ),
      ),
    );
  }
}

/// 地图标签横向展示（仿 MapGroupCard 的 _MapTagRow：超出宽度时自动循环水平滚动）
class _MapTagWrap extends StatefulWidget {
  final List<MapTagSimple> tags;

  const _MapTagWrap({required this.tags});

  @override
  State<_MapTagWrap> createState() => _MapTagWrapState();
}

class _MapTagWrapState extends State<_MapTagWrap> {
  ScrollController? _scrollController;
  bool _needsScroll = false;
  bool _isScrolling = false;
  double _totalScrollWidth = 0;
  double _containerWidth = 0;

  static const double _tagSpacing = 6.0;

  TextStyle get _tagTextStyle => TextStyle(
        color: Colors.white.withValues(alpha: 0.9),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      );

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(_MapTagWrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tags != widget.tags) {
      _stopScrolling();
      if (_scrollController?.hasClients ?? false) {
        _scrollController?.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _containerWidth > 0) {
          _checkOverflowWithContainerWidth(_containerWidth);
        }
      });
    }
  }

  @override
  void dispose() {
    _stopScrolling();
    _scrollController?.dispose();
    super.dispose();
  }

  void _stopScrolling() {
    _isScrolling = false;
  }

  double _measureTagWidth(MapTagSimple tag) {
    final textPainter = TextPainter(
      text: TextSpan(text: tag.name, style: _tagTextStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    // padding(horizontal: 8 * 2) + textWidth
    return textPainter.width + 16;
  }

  void _checkOverflowWithContainerWidth(double maxWidth) {
    if (!mounted) return;

    _containerWidth = maxWidth;
    if (_containerWidth <= 0) return;

    double totalWidth = 0;
    for (int i = 0; i < widget.tags.length; i++) {
      totalWidth += _measureTagWidth(widget.tags[i]);
      if (i < widget.tags.length - 1) {
        totalWidth += _tagSpacing;
      }
    }

    final needsScroll = totalWidth > _containerWidth;

    if (needsScroll != _needsScroll ||
        (needsScroll && (totalWidth - _totalScrollWidth).abs() > 1)) {
      setState(() {
        _needsScroll = needsScroll;
        _totalScrollWidth = totalWidth;
      });
    }

    if (_needsScroll && !_isScrolling) {
      _startScrolling();
    }
  }

  void _startScrolling() async {
    if (!mounted || !_needsScroll || _scrollController == null) return;
    if (!_scrollController!.hasClients) return;

    _isScrolling = true;

    while (mounted && _needsScroll && _isScrolling) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_needsScroll || _scrollController == null) break;
      if (!_scrollController!.hasClients) break;

      final maxScroll = _scrollController!.position.maxScrollExtent;
      if (maxScroll <= 0) break;

      try {
        await _scrollController!.animateTo(
          maxScroll,
          duration: Duration(
            milliseconds: (maxScroll * 0.05).toInt().clamp(3000, 10000),
          ),
          curve: Curves.linear,
        );
      } catch (_) {
        break;
      }

      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) break;

      try {
        await _scrollController!.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } catch (_) {
        break;
      }

      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
    }

    _isScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    // 离屏渲染降级
    if (View.maybeOf(context) == null) {
      return Row(
        children: [
          ..._buildTagRow().take(5),
          if (widget.tags.length > 5)
            Text('...', style: _tagTextStyle.copyWith(color: Colors.white54)),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkOverflowWithContainerWidth(constraints.maxWidth);
        });
        return ClipRect(
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: _needsScroll
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(children: _buildTagRow()),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildTagRow() {
    final List<Widget> widgets = [];
    for (int i = 0; i < widget.tags.length; i++) {
      widgets.add(_buildTagChip(widget.tags[i]));
      if (i < widget.tags.length - 1) {
        widgets.add(const SizedBox(width: _tagSpacing));
      }
    }
    return widgets;
  }

  Widget _buildTagChip(MapTagSimple tag) {
    final tagColorValue = tag.colorValue;

    if (tagColorValue != null) {
      final darkColor = Color.lerp(tagColorValue, Colors.black, 0.2)!;
      final lightColor = Color.lerp(tagColorValue, Colors.white, 0.6)!;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              lightColor.withValues(alpha: 0.4),
              tagColorValue.withValues(alpha: 0.5),
              darkColor.withValues(alpha: 0.45),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: tagColorValue.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        child: Text(
          tag.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                color: Colors.black,
                blurRadius: 1,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          shadows: const [
            Shadow(
              color: Colors.black,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 滚动方向指示器 ────────────────────────────────────────────────────────

enum _ScrollDirection { up, down }

/// 页面边缘的滚动指示器（渐变蒙版 + 居中箭头）
///
/// 顶部指示可以向上滚动，底部指示可以向下滚动。
/// 点击时平滑滚动 300px。
class _ScrollIndicator extends StatelessWidget {
  final _ScrollDirection direction;
  final VoidCallback? onTap;

  const _ScrollIndicator({
    required this.direction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = direction == _ScrollDirection.up;

    final baseColor = Theme.of(context).scaffoldBackgroundColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isUp ? Alignment.topCenter : Alignment.bottomCenter,
            end: isUp ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              baseColor.withValues(alpha: 0.95),
              baseColor.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Center(
          child: AnimatedOpacity(
            duration: GuideTokens.durationFast,
            opacity: 0.6,
            child: Icon(
              isUp
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 24,
              color: GuideTokens.textTertiary(context),
            ),
          ),
        ),
      ),
    );
  }
}
