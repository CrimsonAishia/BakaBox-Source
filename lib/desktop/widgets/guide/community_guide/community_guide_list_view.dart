import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../../core/bloc/auth/auth_bloc.dart';
import '../../../../core/bloc/guide_categories/guide_categories_bloc.dart';
import '../../../../core/bloc/guide_categories/guide_categories_event.dart';
import '../../../../core/bloc/guide_categories/guide_categories_state.dart';
import '../../../../core/bloc/guide_list/guide_list_bloc.dart';
import '../../../../core/bloc/guide_list/guide_list_event.dart';
import '../../../../core/bloc/guide_list/guide_list_state.dart';
import '../../login_dialog.dart';
import 'community_guide_card.dart';
import 'community_guide_format.dart';
import 'community_guide_skeleton_grid.dart';
import 'community_guide_theme.dart';
import 'community_guide_toolbar.dart';

/// 攻略社区列表视图
///
/// 顶部：Hero Banner + 浮动毛玻璃工具栏（搜索 / 分类 / 我的）
/// 主体：瀑布流卡片（置顶项合并到列表头部，卡片右上角显示置顶徽标）
class CommunityGuideListView extends StatefulWidget {
  /// 按地图名预筛选；null 表示不筛选
  final String? mapName;
  final void Function(int id) onViewDetail;
  final VoidCallback onOpenMine;

  const CommunityGuideListView({
    super.key,
    required this.mapName,
    required this.onViewDetail,
    required this.onOpenMine,
  });

  @override
  State<CommunityGuideListView> createState() => _CommunityGuideListViewState();
}

class _CommunityGuideListViewState extends State<CommunityGuideListView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  /// 列表「代」标识。每当筛选条件（分类/标签/地图）、关键词或排序变化时自增，
  /// 用作卡片入场动画的 key，让切换分类时整屏卡片重新淡入，避免硬切换的突兀感。
  int _generation = 0;

  /// 计算当前列表的筛选签名。
  String _signatureOf(GuideListState s) {
    final f = s.filter;
    return [
      f.category ?? '',
      (f.tags ?? const []).join(','),
      f.mapName ?? '',
      f.hasVideo?.toString() ?? '',
      f.authorId?.toString() ?? '',
      s.keyword,
      s.sortBy.name,
    ].join('|');
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    final keyword = context.read<GuideListBloc>().state.keyword;
    if (keyword.isNotEmpty) {
      _searchController.text = keyword;
    }

    final cs = context.read<GuideCategoriesBloc>();
    if (cs.state.status == CategoriesStatus.initial ||
        cs.state.status == CategoriesStatus.failure) {
      cs.add(const LoadCategories());
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      try {
        context.read<GuideListBloc>().add(const LoadGuides());
      } catch (_) {}
    }
  }

  void _handleOpenMine() {
    final auth = context.read<AuthBloc>().state;
    if (!auth.isAuthenticated) {
      LoginDialog.show(context);
      return;
    }
    widget.onOpenMine();
  }

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: CommunityGuideToolbar(
              searchController: _searchController,
              onOpenMine: _handleOpenMine,
            ),
          ),
          // 列表主体单独订阅 GuideListBloc，仅在列表数据变化时重建
          // （工具栏内部各自订阅自己关心的 Bloc，互不干扰）
          BlocListener<GuideListBloc, GuideListState>(
            listenWhen: (prev, curr) =>
                _signatureOf(prev) != _signatureOf(curr),
            listener: (context, state) {
              // 筛选条件变化（切换分类/搜索/排序）时自增代号，触发整屏卡片重新淡入。
              setState(() => _generation++);
            },
            child: BlocBuilder<GuideListBloc, GuideListState>(
              builder: (context, listState) {
                return SliverMainAxisGroup(
                  slivers: _buildBodySlivers(context, listState),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  /// 构建列表主体 sliver 组
  ///
  /// 根据 [listState] 返回以下三种之一：
  /// - 错误态（列表为空且 status=failure）
  /// - 骨架屏（首次加载）
  /// - 空态 / 正常卡片瀑布流 + 加载更多骨架 + 到底提示
  List<Widget> _buildBodySlivers(
    BuildContext context,
    GuideListState listState,
  ) {
    if (listState.status == GuideListStatus.failure &&
        listState.items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorState(error: listState.error),
        ),
      ];
    }

    final crossCount = guideCrossAxisCount(MediaQuery.of(context).size.width);

    // initial / loading 都展示骨架屏，避免首屏空白
    if ((listState.status == GuideListStatus.initial ||
            listState.status == GuideListStatus.loading) &&
        listState.items.isEmpty) {
      return [
        _buildSkeletonGrid(
          crossCount,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        ),
      ];
    }

    if (listState.status == GuideListStatus.success &&
        listState.items.isEmpty &&
        listState.pinned.isEmpty) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: _EmptyState()),
      ];
    }

    // 置顶项合并到普通列表头部，置顶状态由卡片右上角徽标体现
    final pinnedIds = listState.pinned.map((e) => e.id).toSet();
    final nonPinnedItems = listState.items
        .where((item) => !pinnedIds.contains(item.id))
        .toList(growable: false);
    final mergedItems = [...listState.pinned, ...nonPinnedItems];

    final result = <Widget>[];
    final loadingMore = listState.status == GuideListStatus.loadingMore;
    final showEnd = !listState.hasMore && mergedItems.isNotEmpty;

    if (mergedItems.isNotEmpty) {
      result.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: crossCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childCount: mergedItems.length,
            itemBuilder: (context, index) {
              final item = mergedItems[index];
              // 不在 SliverMasonryGrid 内部使用 AnimateIfVisible：
              // 它的 Fade/Slide 过渡会让子项在进入视口时改变可见尺寸，
              // 触发 SliverMasonryGrid 在 line 624 的
              // estimatedMaxScrollOffset >= endScrollOffset - leadingScrollOffset 断言。
              //
              // 这里的入场动画用 _CardEntrance：它只对绘制做透明度 + 位移变换，
              // 不改变子项布局尺寸，因此不会触发上述断言。切换分类时 _generation
              // 自增 → key 变化 → 动画从头播放，实现整屏淡入。
              return _CardEntrance(
                key: ValueKey('guide_card_g${_generation}_${item.id}'),
                index: index,
                child: CommunityGuideCard(
                  item: item,
                  onTap: () => widget.onViewDetail(item.id),
                ),
              );
            },
          ),
        ),
      );
    }

    if (loadingMore) {
      result.add(
        _buildSkeletonGrid(
          crossCount,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          count: 4,
        ),
      );
    }

    if (showEnd) {
      result.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                '— 到底啦 —',
                style: TextStyle(
                  fontSize: 12,
                  color: CommunityGuideColors.of(context).textTertiary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return result;
  }

  /// 构建骨架屏 sliver；[count] 为骨架卡片数量
  Widget _buildSkeletonGrid(
    int crossCount, {
    required EdgeInsets padding,
    int count = 8,
  }) {
    return CommunityGuideSkeletonGrid(
      crossCount: crossCount,
      padding: padding,
      count: count,
      skeletonBuilder: (_) => const CommunityGuideCardSkeleton(),
    );
  }
}

// 错误 / 空 状态

class _ErrorState extends StatelessWidget {
  final String? error;

  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 64, color: colors.textTertiary),
          const SizedBox(height: 16),
          Text(
            error ?? '加载失败',
            style: TextStyle(fontSize: 14, color: colors.textSecondary),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.read<GuideListBloc>().add(
              const LoadGuides(reset: true),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: colors.accentBlue,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.article_outlined, size: 72, color: colors.textTertiary),
          const SizedBox(height: 16),
          Text(
            '还没有攻略',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '稍后再来看看吧',
            style: TextStyle(fontSize: 13, color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// 卡片入场动画

/// 卡片入场动画包装器。
///
/// 仅对绘制做透明度 + 轻微上移变换（不改变布局尺寸），因此可以安全地用在
/// [SliverMasonryGrid] 内部，不会触发其布局断言。
///
/// 按 [index] 错开起始时间，形成自上而下的瀑布式淡入；切换分类时外层通过
/// 改变 key 让本组件重建，从而重新播放动画。
class _CardEntrance extends StatefulWidget {
  final int index;
  final Widget child;

  const _CardEntrance({super.key, required this.index, required this.child});

  @override
  State<_CardEntrance> createState() => _CardEntranceState();
}

class _CardEntranceState extends State<_CardEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    // 按卡片序号错开起播，最多累计 300ms，避免列表很长时延迟过久。
    final delayMs = (widget.index * 45).clamp(0, 300);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Transform.translate(
            offset: Offset(0, (1 - _animation.value) * 16),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
