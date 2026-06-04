import 'package:auto_animated/auto_animated.dart';
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

  // 卡片入场动画时长 / 间隔
  static const Duration _itemAnimDuration = Duration(milliseconds: 500);
  static const Duration _itemAnimInterval = Duration(milliseconds: 60);
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
      body: AnimateIfVisibleWrapper(
        showItemInterval: _itemAnimInterval,
        child: CustomScrollView(
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
            BlocBuilder<GuideListBloc, GuideListState>(
              builder: (context, listState) {
                return SliverMainAxisGroup(
                  slivers: _buildBodySlivers(context, listState),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
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
      return [_buildSkeletonGrid(crossCount, padding: const EdgeInsets.fromLTRB(24, 24, 24, 0))];
    }

    if (listState.status == GuideListStatus.success &&
        listState.items.isEmpty &&
        listState.pinned.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(),
        ),
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
              return AnimateIfVisible(
                key: ValueKey('guide_card_${item.id}'),
                duration: _itemAnimDuration,
                builder: (context, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(animation),
                      child: CommunityGuideCard(
                        item: item,
                        onTap: () => widget.onViewDetail(item.id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
    }

    if (loadingMore) {
      result.add(_buildSkeletonGrid(
        crossCount,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        count: 4,
      ));
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

// ===========================================================================
// 错误 / 空 状态
// ===========================================================================

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
          Icon(
            Icons.error_outline,
            size: 64,
            color: colors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            error ?? '加载失败',
            style: TextStyle(fontSize: 14, color: colors.textSecondary),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context
                .read<GuideListBloc>()
                .add(const LoadGuides(reset: true)),
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
          Icon(
            Icons.article_outlined,
            size: 72,
            color: colors.textTertiary,
          ),
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
