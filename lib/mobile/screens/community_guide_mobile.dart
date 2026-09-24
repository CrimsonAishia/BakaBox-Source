import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/bloc/guide_list/guide_list_bloc.dart';
import '../../core/bloc/guide_list/guide_list_event.dart';
import '../../core/bloc/guide_list/guide_list_state.dart';
import '../../core/bloc/guide_categories/guide_categories_bloc.dart';
import '../../core/bloc/guide_categories/guide_categories_event.dart';
import '../../core/bloc/guide_categories/guide_categories_state.dart';
import '../../desktop/widgets/guide/community_guide/community_guide_card.dart';
import '../../desktop/widgets/guide/community_guide/community_guide_theme.dart';
import '../../desktop/widgets/guide/community_guide/community_guide_skeleton_grid.dart';
import '../router/mobile_router.dart';

class CommunityGuideMobile extends StatefulWidget {
  const CommunityGuideMobile({super.key});

  @override
  State<CommunityGuideMobile> createState() => _CommunityGuideMobileState();
}

class _CommunityGuideMobileState extends State<CommunityGuideMobile> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate800 : Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: isDark ? AppColors.slate800 : Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: const Text(
              '攻略社区',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: SizedBox(
                      height: 40,
                      child: Row(
                        children: [
                          _buildCategoryButton(context),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.shadow.withValues(
                                      alpha: 0.08,
                                    ),
                                    offset: const Offset(0, 2),
                                    blurRadius: 8,
                                  ),
                                ],
                                border: Border.all(
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: '搜索攻略...',
                                  hintStyle: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.search_rounded,
                                      color: theme.colorScheme.primary,
                                      size: 18,
                                    ),
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? Container(
                                          margin: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: IconButton(
                                            icon: Icon(
                                              Icons.clear_rounded,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              size: 16,
                                            ),
                                            onPressed: () {
                                              _searchController.clear();
                                              context.read<GuideListBloc>().add(
                                                const ChangeKeyword(''),
                                              );
                                            },
                                          ),
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                                onSubmitted: (val) {
                                  context.read<GuideListBloc>().add(
                                    ChangeKeyword(val),
                                  );
                                },
                                onChanged: (val) => setState(() {}),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ],
              ),
            ),
          ),

          BlocListener<GuideListBloc, GuideListState>(
            listenWhen: (prev, curr) =>
                _signatureOf(prev) != _signatureOf(curr),
            listener: (context, state) {
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

  List<Widget> _buildBodySlivers(
    BuildContext context,
    GuideListState listState,
  ) {
    if (listState.status == GuideListStatus.failure &&
        listState.items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: CommunityGuideColors.of(context).textTertiary,
                ),
                const SizedBox(height: 16),
                Text(listState.error ?? '加载失败'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.read<GuideListBloc>().add(
                    const LoadGuides(reset: true),
                  ),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final crossCount = MediaQuery.of(context).size.width > 600 ? 2 : 1;

    if ((listState.status == GuideListStatus.initial ||
            listState.status == GuideListStatus.loading) &&
        listState.items.isEmpty) {
      return [
        CommunityGuideSkeletonGrid(
          crossCount: crossCount,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          count: 4,
          skeletonBuilder: (_) => const CommunityGuideCardSkeleton(),
        ),
      ];
    }

    if (listState.status == GuideListStatus.success &&
        listState.items.isEmpty &&
        listState.pinned.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              '还没有攻略',
              style: TextStyle(
                color: CommunityGuideColors.of(context).textSecondary,
              ),
            ),
          ),
        ),
      ];
    }

    final pinnedIds = listState.pinned.map((e) => e.id).toSet();
    final nonPinnedItems = listState.items
        .where((item) => !pinnedIds.contains(item.id))
        .toList();
    final mergedItems = [...listState.pinned, ...nonPinnedItems];

    final result = <Widget>[];

    if (mergedItems.isNotEmpty) {
      result.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: crossCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childCount: mergedItems.length,
            itemBuilder: (context, index) {
              final item = mergedItems[index];
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: CommunityGuideCard(
                  key: ValueKey('guide_card_g${_generation}_${item.id}'),
                  item: item,
                  onTap: () {
                    context.push(
                      MobileRoutes.guideDetail.replaceFirst(
                        ':id',
                        item.id.toString(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      );
    }

    if (listState.status == GuideListStatus.loadingMore) {
      result.add(
        CommunityGuideSkeletonGrid(
          crossCount: crossCount,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          count: 2,
          skeletonBuilder: (_) => const CommunityGuideCardSkeleton(),
        ),
      );
    }

    if (!listState.hasMore && mergedItems.isNotEmpty) {
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

  Widget _buildCategoryButton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<GuideListBloc, GuideListState>(
      builder: (context, listState) {
        final selectedCategory = listState.filter.category;
        final hasCategory =
            selectedCategory != null && selectedCategory.isNotEmpty;

        return PopupMenuButton<String?>(
          offset: const Offset(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
          color: isDark
              ? theme.colorScheme.surfaceContainer
              : theme.colorScheme.surface,
          onSelected: (value) {
            if (value == null) {
              context.read<GuideListBloc>().add(
                ChangeFilter(listState.filter.copyWith(clearCategory: true)),
              );
            } else {
              context.read<GuideListBloc>().add(
                ChangeFilter(listState.filter.copyWith(category: value)),
              );
            }
          },
          itemBuilder: (context) {
            final catState = context.read<GuideCategoriesBloc>().state;
            final items = catState.items;
            return [
              PopupMenuItem<String?>(
                value: null,
                height: 40,
                child: Row(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 18,
                      color: !hasCategory
                          ? AppColors.violet500
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '全部分类',
                      style: TextStyle(
                        color: !hasCategory
                            ? AppColors.violet500
                            : theme.colorScheme.onSurface,
                        fontWeight: !hasCategory
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              ...items.map((cat) {
                final isSelected = cat.name == selectedCategory;
                return PopupMenuItem<String?>(
                  value: cat.name,
                  height: 40,
                  child: Row(
                    children: [
                      Icon(
                        Icons.label_outline,
                        size: 18,
                        color: isSelected
                            ? AppColors.violet500
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cat.name,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.violet500
                              : theme.colorScheme.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ];
          },
          child: SizedBox(
            height: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainer
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                hasCategory ? Icons.filter_alt : Icons.filter_alt_outlined,
                color: hasCategory
                    ? AppColors.violet500
                    : theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
          ),
        );
      },
    );
  }
}
