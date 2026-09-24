import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../core/core.dart';
import '../../desktop/widgets/character_gallery/character_gallery_theme.dart';
import '../widgets/character_gallery/character_card_mobile.dart';
import '../widgets/character_gallery/weapon_model_card_mobile.dart';
import '../widgets/character_gallery/character_voice_card_mobile.dart';
import 'weapon_model_detail_mobile.dart';

/// 移动端角色图鉴列表页面
class CharacterGalleryMobile extends StatefulWidget {
  const CharacterGalleryMobile({super.key});

  @override
  State<CharacterGalleryMobile> createState() => _CharacterGalleryMobileState();
}

class _CharacterGalleryMobileState extends State<CharacterGalleryMobile> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _tierKeys = {};
  Timer? _searchDebounce;
  bool _hasSearchText = false;
  bool _isCategoryExpanded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchTextChanged);
  }

  void _onSearchTextChanged() {
    final hasText = _searchController.text.isNotEmpty;
    if (hasText != _hasSearchText) {
      setState(() {
        _hasSearchText = hasText;
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    // 滚动到底部时加载更多
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      final bloc = context.read<CharacterGalleryBloc>();
      final state = bloc.state;
      if (state.hasMore && state.listLoadState != LoadState.loading) {
        bloc.add(LoadMoreCharacters());
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      context.read<CharacterGalleryBloc>().add(SearchCharacters(value));
    });
  }

  void _onCategoryChanged(CharacterCategory? category) {
    context.read<CharacterGalleryBloc>().add(ChangeCategory(category));
  }

  void _navigateToDetail(int characterId) {
    context.push('/character-gallery/$characterId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<CharacterGalleryBloc, CharacterGalleryState>(
        buildWhen: (previous, current) =>
            previous.showSpellCardTierView != current.showSpellCardTierView ||
            previous.spellCardTierFilter != current.spellCardTierFilter ||
            previous.selectedCategory != current.selectedCategory ||
            previous.keyword != current.keyword,
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () async {
              final bloc = context.read<CharacterGalleryBloc>();
              if (state.showSpellCardTierView) {
                bloc.add(
                  LoadSpellCardTierList(type: state.spellCardTierFilter),
                );
              } else {
                bloc.add(
                  LoadCharacters(
                    category: state.selectedCategory,
                    keyword: state.keyword,
                  ),
                );
              }
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // AppBar 只在需要时重建（标题、副标题变化）
                BlocBuilder<CharacterGalleryBloc, CharacterGalleryState>(
                  buildWhen: (previous, current) =>
                      previous.totalCount != current.totalCount ||
                      previous.showSpellCardTierView !=
                          current.showSpellCardTierView ||
                      previous.spellCardTierTotalCount !=
                          current.spellCardTierTotalCount ||
                      (previous.listLoadState == LoadState.loading) !=
                          (current.listLoadState == LoadState.loading &&
                              current.characters.isEmpty),
                  builder: (context, state) => _buildAppBar(context, state),
                ),
                // 工具栏（分类按钮 + 搜索框）- 使用 SliverPersistentHeader 实现吸顶
                BlocBuilder<CharacterGalleryBloc, CharacterGalleryState>(
                  buildWhen: (previous, current) =>
                      previous.selectedCategory != current.selectedCategory ||
                      previous.showSpellCardTierView !=
                          current.showSpellCardTierView ||
                      previous.showWeaponModelView !=
                          current.showWeaponModelView ||
                      previous.showCheerSoundsView !=
                          current.showCheerSoundsView ||
                      previous.sortBy != current.sortBy,
                  builder: (context, state) {
                    final showSearch = !state.showCheerSoundsView;
                    double height = 20; // top 12 + bottom 8 padding
                    height += 10; // category container padding(8) + border(2)
                    height += _isCategoryExpanded ? 84 : 40; // chips height
                    if (showSearch) {
                      height += 12; // gap
                      height += 48; // search box
                    }
                    return SliverPersistentHeader(
                      pinned: true,
                      delegate: _ToolbarHeaderDelegate(
                        height: height,
                        child: _buildToolbar(state),
                      ),
                    );
                  },
                ),
                // 武器二级菜单（仅在装备视图显示）吸顶
                BlocBuilder<CharacterGalleryBloc, CharacterGalleryState>(
                  buildWhen: (previous, current) =>
                      previous.showWeaponModelView !=
                          current.showWeaponModelView ||
                      previous.weaponModelTab != current.weaponModelTab,
                  builder: (context, state) {
                    if (!state.showWeaponModelView) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    return SliverPersistentHeader(
                      pinned: true,
                      delegate: _ToolbarHeaderDelegate(
                        height:
                            54, // 10 top padding + 34 height + 10 bottom padding
                        child: Container(
                          color: Theme.of(context).appBarTheme.backgroundColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 5,
                          ),
                          child: _buildWeaponModelTabs(state),
                        ),
                      ),
                    );
                  },
                ),
                // 内容区域 - 只在内容相关状态变化时重建
                BlocBuilder<CharacterGalleryBloc, CharacterGalleryState>(
                  buildWhen: (previous, current) =>
                      previous.listLoadState != current.listLoadState ||
                      previous.characters != current.characters ||
                      previous.showSpellCardTierView !=
                          current.showSpellCardTierView ||
                      previous.showWeaponModelView !=
                          current.showWeaponModelView ||
                      previous.showCheerSoundsView !=
                          current.showCheerSoundsView ||
                      previous.allWeaponModelsLoadState !=
                          current.allWeaponModelsLoadState ||
                      previous.allKnifeModels != current.allKnifeModels ||
                      previous.allGunModels != current.allGunModels ||
                      previous.allMenuSkins != current.allMenuSkins ||
                      previous.weaponModelTab != current.weaponModelTab ||
                      previous.cheerSoundsLoadState !=
                          current.cheerSoundsLoadState ||
                      previous.cheerSounds != current.cheerSounds ||
                      previous.spellCardTierLoadState !=
                          current.spellCardTierLoadState ||
                      previous.spellCardTierGroups !=
                          current.spellCardTierGroups ||
                      previous.expandedTiers != current.expandedTiers ||
                      previous.hasMore != current.hasMore ||
                      previous.error != current.error,
                  builder: (context, state) =>
                      _buildContentSliver(context, state),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建 AppBar
  Widget _buildAppBar(BuildContext context, CharacterGalleryState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isDark ? AppColors.slate800 : Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        '人物图鉴',
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
    );
  }

  /// 构建内容区域（Sliver 版本）
  Widget _buildContentSliver(
    BuildContext context,
    CharacterGalleryState state,
  ) {
    // 加载中状态
    if (state.listLoadState == LoadState.loading && state.characters.isEmpty) {
      if (!state.showSpellCardTierView &&
          !state.showWeaponModelView &&
          !state.showCheerSoundsView) {
        return SliverFillRemaining(child: _buildLoadingState());
      }
    }

    if (state.showSpellCardTierView &&
        state.spellCardTierLoadState == LoadState.loading &&
        state.spellCardTierGroups.isEmpty) {
      return SliverFillRemaining(child: _buildLoadingState());
    }

    if (state.showWeaponModelView &&
        state.allWeaponModelsLoadState == LoadState.loading) {
      return SliverFillRemaining(child: _buildLoadingState());
    }

    if (state.showCheerSoundsView &&
        state.cheerSoundsLoadState == LoadState.loading &&
        state.cheerSounds.isEmpty) {
      return SliverFillRemaining(child: _buildLoadingState());
    }

    // 错误状态
    if (state.listLoadState == LoadState.failure && state.characters.isEmpty) {
      if (!state.showSpellCardTierView &&
          !state.showWeaponModelView &&
          !state.showCheerSoundsView) {
        return SliverFillRemaining(child: _buildErrorState(state.error));
      }
    }

    if (state.showSpellCardTierView &&
        state.spellCardTierLoadState == LoadState.failure &&
        state.spellCardTierGroups.isEmpty) {
      return SliverFillRemaining(child: _buildErrorState(state.error));
    }

    if (state.showWeaponModelView &&
        state.allWeaponModelsLoadState == LoadState.failure) {
      return SliverFillRemaining(child: _buildErrorState(state.error));
    }

    if (state.showCheerSoundsView &&
        state.cheerSoundsLoadState == LoadState.failure &&
        state.cheerSounds.isEmpty) {
      return SliverFillRemaining(child: _buildErrorState(state.error));
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        if (state.showSpellCardTierView)
          _buildSpellCardTierList(state)
        else if (state.showWeaponModelView)
          _buildWeaponModelList(state)
        else if (state.showCheerSoundsView)
          _buildCheerSoundsList(state)
        else if (state.characters.isEmpty)
          _buildEmptyState()
        else
          _buildCharacterGrid(state),
        if (!state.showSpellCardTierView &&
            !state.showWeaponModelView &&
            !state.showCheerSoundsView &&
            state.characters.isNotEmpty)
          _buildBottomIndicator(state),
        const SizedBox(height: 20),
      ]),
    );
  }

  /// 构建工具栏（分类按钮 + 搜索框）
  Widget _buildToolbar(CharacterGalleryState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isNormalView =
        !state.showSpellCardTierView &&
        !state.showWeaponModelView &&
        !state.showCheerSoundsView;

    // 所有分类定义
    final allCats = [
      (
        '東方',
        state.selectedCategory == CharacterCategory.touhou && isNormalView,
        () => _onCategoryChanged(CharacterCategory.touhou),
        AppColors.red600,
      ),
      (
        '僵尸',
        state.selectedCategory == CharacterCategory.zombie && isNormalView,
        () => _onCategoryChanged(CharacterCategory.zombie),
        const Color(0xFF16A34A),
      ),
      (
        '普通',
        state.selectedCategory == CharacterCategory.normal && isNormalView,
        () => _onCategoryChanged(CharacterCategory.normal),
        const Color(0xFF2563EB),
      ),
      (
        '符卡',
        state.showSpellCardTierView,
        () => context.read<CharacterGalleryBloc>().add(
          const LoadSpellCardTierList(),
        ),
        AppColors.amber500,
      ),
      (
        '装备',
        state.showWeaponModelView,
        () => context.read<CharacterGalleryBloc>().add(
          const LoadAllWeaponModels(),
        ),
        AppColors.slate500,
      ),
      (
        'Meme',
        state.showCheerSoundsView,
        () => context.read<CharacterGalleryBloc>().add(const LoadCheerSounds()),
        Colors.cyan,
      ),
    ];

    // 将选中的分类放到第一个（仅在折叠时改变顺序）
    if (!_isCategoryExpanded) {
      final selectedIndex = allCats.indexWhere((c) => c.$2);
      if (selectedIndex > 0) {
        final selected = allCats.removeAt(selectedIndex);
        allCats.insert(0, selected);
      }
    }

    return Container(
      color: theme.appBarTheme.backgroundColor, // 防止透明遮挡
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // 分类切换按钮容器
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainer
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildCategoryChip(
                              allCats[0].$1,
                              allCats[0].$2,
                              allCats[0].$3,
                              color: allCats[0].$4,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildCategoryChip(
                              allCats[1].$1,
                              allCats[1].$2,
                              allCats[1].$3,
                              color: allCats[1].$4,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildCategoryChip(
                              allCats[2].$1,
                              allCats[2].$2,
                              allCats[2].$3,
                              color: allCats[2].$4,
                            ),
                          ),
                        ],
                      ),
                      if (_isCategoryExpanded) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCategoryChip(
                                allCats[3].$1,
                                allCats[3].$2,
                                allCats[3].$3,
                                color: allCats[3].$4,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _buildCategoryChip(
                                allCats[4].$1,
                                allCats[4].$2,
                                allCats[4].$3,
                                color: allCats[4].$4,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _buildCategoryChip(
                                allCats[5].$1,
                                allCats[5].$2,
                                allCats[5].$3,
                                color: allCats[5].$4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // 展开/收起按钮
                GestureDetector(
                  onTap: () => setState(
                    () => _isCategoryExpanded = !_isCategoryExpanded,
                  ),
                  child: Container(
                    width: 36,
                    height: _isCategoryExpanded ? 84 : 40,
                    alignment: Alignment.center,
                    color: Colors.transparent, // 扩大点击区域
                    child: Icon(
                      _isCategoryExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 搜索框和排序 (Meme模式下不显示)
          if (!state.showCheerSoundsView) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (!state.showWeaponModelView) ...[
                  _buildSortButton(state.sortBy),
                  const SizedBox(width: 8),
                ],
                Expanded(child: _buildSearchBox()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSortButton(String currentSortBy) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUpdate = currentSortBy == 'update';

    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      color: isDark
          ? theme.colorScheme.surfaceContainer
          : theme.colorScheme.surface,
      onSelected: (value) {
        context.read<CharacterGalleryBloc>().add(ChangeSortBy(value));
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: '',
          height: 44,
          child: Row(
            children: [
              Icon(
                Icons.sort,
                size: 18,
                color: !isUpdate
                    ? AppColors.violet500
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '默认排序',
                style: TextStyle(
                  color: !isUpdate
                      ? AppColors.violet500
                      : theme.colorScheme.onSurface,
                  fontWeight: !isUpdate ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'update',
          height: 44,
          child: Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 18,
                color: isUpdate
                    ? AppColors.violet500
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '最近更新',
                style: TextStyle(
                  color: isUpdate
                      ? AppColors.violet500
                      : theme.colorScheme.onSurface,
                  fontWeight: isUpdate ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
      child: SizedBox(
        height: 48, // 固定高度
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            isUpdate ? Icons.access_time_rounded : Icons.sort,
            color: AppColors.violet500,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
    String label,
    bool isSelected,
    VoidCallback onTap, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chipColor = color ?? AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 40, // 固定高度
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? chipColor.withValues(alpha: isDark ? 0.2 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? chipColor
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = AppColors.violet500;

    return SizedBox(
      height: 48, // 固定高度
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: '搜索名称...',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.search_rounded,
                color: primaryColor.withValues(alpha: isDark ? 0.8 : 0.7),
                size: 22,
              ),
            ),
            suffixIcon: _hasSearchText
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 16,
                        ),
                      ),
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onChanged: _onSearchChanged,
        ),
      ),
    );
  }

  /// 构建角色网格列表
  Widget _buildCharacterGrid(CharacterGalleryState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        padding: const EdgeInsets.only(top: 14),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: state.characters.length,
        itemBuilder: (context, index) {
          final character = state.characters[index];
          return _buildCharacterCard(character, index);
        },
      ),
    );
  }

  /// 构建装备/武器网格列表
  Widget _buildWeaponModelList(CharacterGalleryState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [_buildWeaponModelListContent(state)]),
    );
  }

  Widget _buildWeaponModelTabs(CharacterGalleryState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildWeaponTabButton(
            '刀模',
            MdiIcons.knife,
            state.weaponModelTab == 0,
            () => context.read<CharacterGalleryBloc>().add(
              const ChangeWeaponModelTab(0),
            ),
          ),
          const SizedBox(width: 8),
          _buildWeaponTabButton(
            '枪模',
            MdiIcons.pistol,
            state.weaponModelTab == 1,
            () => context.read<CharacterGalleryBloc>().add(
              const ChangeWeaponModelTab(1),
            ),
          ),
          const SizedBox(width: 8),
          _buildWeaponTabButton(
            '菜单皮肤',
            Icons.view_sidebar_outlined,
            state.weaponModelTab == 2,
            () => context.read<CharacterGalleryBloc>().add(
              const ChangeWeaponModelTab(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeaponTabButton(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final vermillion = AppColors.red600;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? vermillion : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? vermillion
                : theme.dividerColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeaponModelListContent(CharacterGalleryState state) {
    if (state.allWeaponModelsLoadState == LoadState.loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppColors.red600),
        ),
      );
    }

    final items = state.weaponModelTab == 0
        ? state.allKnifeModels
        : state.weaponModelTab == 1
        ? state.allGunModels
        : state.allMenuSkins;

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.weaponModelTab == 0
                  ? MdiIcons.knife
                  : state.weaponModelTab == 1
                  ? MdiIcons.pistol
                  : Icons.view_sidebar_outlined,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无数据',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(top: 14),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        if (state.weaponModelTab == 0) {
          final knife = items[index] as KnifeModel;
          return WeaponModelCardMobile.fromKnifeModel(
            model: knife,
            onTap: () {
              final bloc = context.read<CharacterGalleryBloc>();
              context.read<CharacterGalleryBloc>().add(
                SelectWeaponModel(id: knife.id, type: WeaponModelType.knife),
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider.value(
                    value: bloc,
                    child: const WeaponModelDetailMobile(),
                  ),
                ),
              );
            },
          );
        } else if (state.weaponModelTab == 1) {
          final gun = items[index] as GunModel;
          return WeaponModelCardMobile.fromGunModel(
            model: gun,
            onTap: () {
              final bloc = context.read<CharacterGalleryBloc>();
              context.read<CharacterGalleryBloc>().add(
                SelectWeaponModel(id: gun.id, type: WeaponModelType.gun),
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider.value(
                    value: bloc,
                    child: const WeaponModelDetailMobile(),
                  ),
                ),
              );
            },
          );
        } else {
          final menuSkin = items[index] as MenuSkinModel;
          return WeaponModelCardMobile.fromMenuSkinModel(
            model: menuSkin,
            onTap: () {
              final bloc = context.read<CharacterGalleryBloc>();
              context.read<CharacterGalleryBloc>().add(
                SelectWeaponModel(
                  id: menuSkin.id,
                  type: WeaponModelType.menuSkin,
                ),
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider.value(
                    value: bloc,
                    child: const WeaponModelDetailMobile(),
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }

  /// 构建Meme语音列表
  Widget _buildCheerSoundsList(CharacterGalleryState state) {
    if (state.cheerSounds.isEmpty) {
      return _buildEmptyState();
    }

    final Map<String, List<VoiceItem>> groupedVoices = {};
    for (final voice in state.cheerSounds) {
      if (!groupedVoices.containsKey(voice.type)) {
        groupedVoices[voice.type] = [];
      }
      groupedVoices[voice.type]!.add(voice);
    }
    final voiceGroups = groupedVoices.values.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 12),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: voiceGroups.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return CharacterVoiceCardMobile(
            voices: voiceGroups[index],
            showType: false,
          );
        },
      ),
    );
  }

  Widget _buildCharacterCard(CharacterListItem character, int index) {
    return CharacterCardMobile(
      character: character,
      isSelected: false,
      onTap: () => _navigateToDetail(character.id),
    );
  }

  /// 构建符卡评级列表
  Widget _buildSpellCardTierList(CharacterGalleryState state) {
    if (state.spellCardTierGroups.isEmpty) {
      return _buildEmptySpellCardState();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final tierGroup in state.spellCardTierGroups)
            _buildTierGroup(
              tierGroup,
              state.expandedTiers.contains(tierGroup.tier),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 构建评级分组
  Widget _buildTierGroup(SpellCardTierGroup tierGroup, bool isExpanded) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tierColor = _getTierColor(tierGroup.tier);

    // 为每个评级创建 GlobalKey
    _tierKeys.putIfAbsent(tierGroup.tier, () => GlobalKey());
    final key = _tierKeys[tierGroup.tier];

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? tierColor.withValues(alpha: 0.5)
              : theme.dividerColor.withValues(alpha: 0.3),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isExpanded
                ? tierColor.withValues(alpha: isDark ? 0.15 : 0.1)
                : theme.colorScheme.shadow.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          // 评级标题（可点击展开/折叠）
          _buildTierHeader(tierGroup, isExpanded, tierColor),
          // 符卡列表（展开时显示）
          if (isExpanded) _buildTierSpellCards(tierGroup.spellCards),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  /// 构建评级标题
  Widget _buildTierHeader(
    SpellCardTierGroup tierGroup,
    bool isExpanded,
    Color tierColor,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final bloc = context.read<CharacterGalleryBloc>();
          final wasExpanded = bloc.state.expandedTiers.contains(tierGroup.tier);
          bloc.add(ToggleTierExpanded(tierGroup.tier));

          // 展开时滚动到该项
          if (!wasExpanded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final key = _tierKeys[tierGroup.tier];
              if (key?.currentContext != null) {
                Scrollable.ensureVisible(
                  key!.currentContext!,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: 0.0,
                );
              }
            });
          }
        },
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(15),
          bottom: isExpanded ? Radius.zero : const Radius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // 评级徽章
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: isDark ? 0.2 : 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: tierColor.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: Text(
                  tierGroup.tierLabel,
                  style: TextStyle(
                    color: tierColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 符卡数量
              Expanded(
                child: Text(
                  '${tierGroup.count} 张符卡',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
              // 展开/折叠图标
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isExpanded
                      ? tierColor
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建评级下的符卡列表
  Widget _buildTierSpellCards(List<SpellCardTierItem> spellCards) {
    return Column(
      children: [
        for (int i = 0; i < spellCards.length; i++)
          _buildSpellCardTierItem(
            spellCards[i],
            isLast: i == spellCards.length - 1,
          ),
      ],
    );
  }

  /// 构建符卡评级列表项
  Widget _buildSpellCardTierItem(
    SpellCardTierItem spellCard, {
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final gold = CharacterGalleryTheme.getGold(context);

    // 类型对应的颜色、符号和背景图
    final (
      Color borderColor,
      Color bgColor,
      String symbol,
      String bgAsset,
    ) = switch (spellCard.type) {
      SpellCardType.passive => (
        AppColors.skillGreen,
        AppColors.skillGreen.withValues(alpha: isDark ? 0.15 : 0.08),
        '✦',
        'assets/images/character_gallery/spell_card_bg_passive.png',
      ),
      SpellCardType.ultimate => (
        gold,
        gold.withValues(alpha: isDark ? 0.15 : 0.08),
        '◈',
        'assets/images/character_gallery/spell_card_bg_ultimate.png',
      ),
      SpellCardType.normal => (
        vermillion,
        vermillion.withValues(alpha: isDark ? 0.12 : 0.06),
        '✧',
        'assets/images/character_gallery/spell_card_bg_normal.png',
      ),
    };

    return GestureDetector(
      onTap: () => _navigateToDetailFromSpellCard(spellCard),
      child: Container(
        margin: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 8,
          bottom: isLast ? 12 : 0,
        ),
        constraints: const BoxConstraints(minHeight: 80),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Stack(
            children: [
              // 背景图层
              Positioned.fill(
                child: Image.asset(
                  bgAsset,
                  fit: BoxFit.cover,
                  opacity: AlwaysStoppedAnimation(isDark ? 0.3 : 0.5),
                ),
              ),
              // 渐变蒙版（顶部透明 → 底部加深，让属性行落在清晰区域）
              Positioned.fill(
                child: DecoratedBox(
                  decoration:
                      CharacterGalleryTheme.getCardBottomGradientDecoration(
                        context,
                      ),
                ),
              ),
              // 内容层
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题行：符号 + 名称 + 箭头
                    Row(
                      children: [
                        Text(
                          symbol,
                          style: TextStyle(
                            color: borderColor,
                            fontSize: 14,
                            shadows: isDark
                                ? null
                                : [
                                    const Shadow(
                                      color: Colors.white,
                                      blurRadius: 3,
                                    ),
                                    Shadow(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      blurRadius: 6,
                                    ),
                                  ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            spellCard.name,
                            style: TextStyle(
                              color: inkColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              shadows: isDark
                                  ? null
                                  : [
                                      const Shadow(
                                        color: Colors.white,
                                        blurRadius: 4,
                                      ),
                                      Shadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        blurRadius: 8,
                                      ),
                                      Shadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        blurRadius: 12,
                                      ),
                                    ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 箭头
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: scrollBrown.withValues(alpha: 0.6),
                          shadows: isDark
                              ? null
                              : [
                                  const Shadow(
                                    color: Colors.white,
                                    blurRadius: 3,
                                  ),
                                  Shadow(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    blurRadius: 6,
                                  ),
                                ],
                        ),
                      ],
                    ),
                    // 分隔线
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              borderColor.withValues(alpha: 0),
                              borderColor.withValues(alpha: 0.5),
                              borderColor.withValues(alpha: 0.5),
                              borderColor.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.2, 0.8, 1],
                          ),
                        ),
                      ),
                    ),
                    // 描述
                    if (spellCard.description != null &&
                        spellCard.description!.isNotEmpty)
                      RichTextViewer(
                        content: spellCard.description!,
                        textStyle: TextStyle(
                          color: inkColor,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          shadows: isDark
                              ? null
                              : [
                                  const Shadow(
                                    color: Colors.white,
                                    blurRadius: 4,
                                  ),
                                  Shadow(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    blurRadius: 8,
                                  ),
                                  Shadow(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    blurRadius: 12,
                                  ),
                                ],
                        ),
                      ),
                    // 属性行
                    if (spellCard.cooldown != null ||
                        spellCard.damage != null ||
                        spellCard.cost != null ||
                        spellCard.speed != null ||
                        spellCard.count != null ||
                        spellCard.angle != null ||
                        spellCard.puncture != null ||
                        spellCard.bounce != null ||
                        spellCard.explode != null ||
                        spellCard.holdTime != null ||
                        spellCard.trackSpeed != null ||
                        spellCard.customCd != null) ...[
                      const SizedBox(height: 8),
                      _buildTierItemStats(spellCard, borderColor, isDark),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 评级列表项属性行
  Widget _buildTierItemStats(
    SpellCardTierItem spellCard,
    Color accentColor,
    bool isDark,
  ) {
    final statItems = <Widget>[];

    if (spellCard.cooldown != null) {
      statItems.add(
        _buildStatItem(
          Icons.timer_outlined,
          '冷却',
          '${_formatNumber(spellCard.cooldown!)}s',
          CharacterGalleryTheme.getCooldownColor(context),
          isDark,
        ),
      );
    }

    if (spellCard.damage != null && spellCard.damage!.isNotEmpty) {
      statItems.add(
        _buildStatItem(
          Icons.flash_on,
          '伤害',
          spellCard.damage!,
          CharacterGalleryTheme.getDamageColor(context),
          isDark,
        ),
      );
    }

    if (spellCard.cost != null) {
      final isUltimate = spellCard.type == SpellCardType.ultimate;
      statItems.add(
        _buildStatItem(
          Icons.local_fire_department,
          isUltimate ? 'B点' : 'P点',
          _formatNumber(spellCard.cost!),
          isUltimate
              ? CharacterGalleryTheme.getBCostColor(context)
              : CharacterGalleryTheme.getPCostColor(context),
          isDark,
        ),
      );
    }

    if (spellCard.speed != null) {
      statItems.add(
        _buildStatItem(
          Icons.speed,
          '弹幕初速',
          _formatNumber(spellCard.speed!),
          CharacterGalleryTheme.getSpeedColor(context),
          isDark,
        ),
      );
    }
    if (spellCard.count != null) {
      statItems.add(
        _buildStatItem(
          Icons.scatter_plot,
          '弹幕数量',
          spellCard.count!.toString(),
          CharacterGalleryTheme.getCountColor(context),
          isDark,
        ),
      );
    }
    if (spellCard.angle != null) {
      statItems.add(
        _buildStatItem(
          Icons.architecture,
          '散射角度',
          '${_formatNumber(spellCard.angle!)}°',
          CharacterGalleryTheme.getAngleColor(context),
          isDark,
        ),
      );
    }
    if (spellCard.puncture != null) {
      statItems.add(
        _buildStatItem(
          Icons.swap_horiz,
          '穿刺次数',
          spellCard.puncture!.toString(),
          CharacterGalleryTheme.getPunctureColor(context),
          isDark,
        ),
      );
    }
    if (spellCard.bounce != null) {
      statItems.add(
        _buildStatItem(
          Icons.replay,
          '反弹次数',
          spellCard.bounce!.toString(),
          CharacterGalleryTheme.getBounceColor(context),
          isDark,
        ),
      );
    }
    if (spellCard.explode != null) {
      statItems.add(
        _buildStatItem(
          Icons.brightness_5,
          '影响范围',
          _formatNumber(spellCard.explode!),
          CharacterGalleryTheme.getExplodeColor(context),
          isDark,
        ),
      );
    }
    if (spellCard.holdTime != null) {
      statItems.add(
        _buildStatItem(
          Icons.hourglass_bottom,
          '持续时间',
          '${_formatNumber(spellCard.holdTime!)}s',
          CharacterGalleryTheme.getHoldTimeColor(context),
          isDark,
        ),
      );
    }
    if (spellCard.trackSpeed != null) {
      statItems.add(
        _buildStatItem(
          Icons.gps_fixed,
          '追踪转向',
          _formatNumber(spellCard.trackSpeed!),
          CharacterGalleryTheme.getTrackSpeedColor(context),
          isDark,
        ),
      );
    }
    if (spellCard.customCd != null) {
      statItems.add(
        _buildStatItem(
          Icons.settings,
          '内置CD',
          '${_formatNumber(spellCard.customCd!)}s',
          CharacterGalleryTheme.getCustomCdColor(context),
          isDark,
        ),
      );
    }

    return Wrap(spacing: 12, runSpacing: 6, children: statItems);
  }

  /// 单个属性项
  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
          shadows: isDark
              ? null
              : [
                  const Shadow(color: Colors.white, blurRadius: 3),
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.8),
                    blurRadius: 6,
                  ),
                ],
        ),
        const SizedBox(width: 4),
        Text(
          '$label:',
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            shadows: isDark
                ? null
                : [
                    const Shadow(color: Colors.white, blurRadius: 3),
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      blurRadius: 6,
                    ),
                  ],
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            shadows: isDark
                ? null
                : [
                    const Shadow(color: Colors.white, blurRadius: 3),
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      blurRadius: 6,
                    ),
                  ],
          ),
        ),
      ],
    );
  }

  /// 格式化数值：整数不显示小数点
  String _formatNumber(num value) {
    if (value is int) return value.toString();
    final d = value as double;
    if (d == d.truncateToDouble()) return d.toInt().toString();
    return d.toString();
  }

  /// 从符卡导航到角色详情
  void _navigateToDetailFromSpellCard(SpellCardTierItem spellCard) {
    final path = '/character-gallery/${spellCard.characterId}';
    if (spellCard.subModelId != null) {
      context.push('$path?subModelId=${spellCard.subModelId}');
    } else {
      context.push(path);
    }
  }

  /// 获取评级颜色
  Color _getTierColor(String tier) {
    return switch (tier) {
      'T0' => const Color(0xFFFF4444), // 红色 - 最强
      'T1' => const Color(0xFFFF8800), // 橙色 - 强力
      'T2' => const Color(0xFFFFCC00), // 金色 - 优秀
      'T3' => const Color(0xFF44BB44), // 绿色 - 中等
      'T4' => const Color(0xFF4488FF), // 蓝色 - 一般
      'T5' => const Color(0xFF8888AA), // 灰蓝 - 较弱
      'unranked' => const Color(0xFF8B7355), // 棕色 - 未评级
      _ => const Color(0xFF8B7355),
    };
  }

  /// 构建空符卡状态
  Widget _buildEmptySpellCardState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = AppColors.amber500;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark
                    ? primaryColor.withValues(alpha: 0.15)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Icon(
                MdiIcons.cards,
                size: 36,
                color: isDark
                    ? primaryColor.withValues(alpha: 0.9)
                    : const Color(0xFFD97706),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '暂无符卡数据',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请稍后再试',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = AppColors.violet500;
    final isSearching = _searchController.text.isNotEmpty;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark
                    ? primaryColor.withValues(alpha: 0.15)
                    : const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Icon(
                isSearching ? Icons.search_off : MdiIcons.cardsOutline,
                size: 36,
                color: isDark
                    ? primaryColor.withValues(alpha: 0.9)
                    : const Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSearching ? '没有找到相关角色' : '暂无角色数据',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching ? '试试其他关键词' : '请稍后再试',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  /// 构建错误状态
  Widget _buildErrorState(String? error) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            error ?? '加载失败',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final bloc = context.read<CharacterGalleryBloc>();
              final state = bloc.state;
              if (state.showSpellCardTierView) {
                bloc.add(
                  LoadSpellCardTierList(type: state.spellCardTierFilter),
                );
              } else {
                bloc.add(
                  LoadCharacters(
                    category: state.selectedCategory,
                    keyword: state.keyword,
                  ),
                );
              }
            },
            child: const Text('重试'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.3, end: 0);
  }

  /// 构建加载状态
  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = AppColors.violet500;

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
                '正在加载角色列表',
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

  /// 构建底部加载指示器
  Widget _buildBottomIndicator(CharacterGalleryState state) {
    if (!state.hasMore) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            '已加载全部角色',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    if (state.listLoadState == LoadState.loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _ToolbarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _ToolbarHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: maxExtent, child: child);
  }

  @override
  bool shouldRebuild(covariant _ToolbarHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}
