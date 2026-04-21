import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../core/core.dart';
import '../../desktop/widgets/character_gallery/character_gallery_theme.dart';
import '../widgets/character_gallery/character_card_mobile.dart';

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

  void _onSpellCardTierTap() {
    context.read<CharacterGalleryBloc>().add(const LoadSpellCardTierList());
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
                bloc.add(LoadSpellCardTierList(
                  type: state.spellCardTierFilter,
                ));
              } else {
                bloc.add(LoadCharacters(
                  category: state.selectedCategory,
                  keyword: state.keyword,
                ));
              }
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // AppBar 只在需要时重建（标题、副标题变化）
                BlocBuilder<CharacterGalleryBloc, CharacterGalleryState>(
                  buildWhen: (previous, current) =>
                      previous.totalCount != current.totalCount ||
                      previous.showSpellCardTierView != current.showSpellCardTierView ||
                      previous.spellCardTierTotalCount != current.spellCardTierTotalCount ||
                      (previous.listLoadState == LoadState.loading) != (current.listLoadState == LoadState.loading && current.characters.isEmpty),
                  builder: (context, state) => _buildAppBar(context, state),
                ),
                // 工具栏（分类按钮 + 搜索框）- 只在分类或视图模式变化时重建
                BlocBuilder<CharacterGalleryBloc, CharacterGalleryState>(
                  buildWhen: (previous, current) =>
                      previous.selectedCategory != current.selectedCategory ||
                      previous.showSpellCardTierView != current.showSpellCardTierView,
                  builder: (context, state) => SliverToBoxAdapter(
                    child: _buildToolbar(state),
                  ),
                ),
                // 内容区域 - 只在内容相关状态变化时重建
                BlocBuilder<CharacterGalleryBloc, CharacterGalleryState>(
                  buildWhen: (previous, current) =>
                      previous.listLoadState != current.listLoadState ||
                      previous.characters != current.characters ||
                      previous.showSpellCardTierView != current.showSpellCardTierView ||
                      previous.spellCardTierLoadState != current.spellCardTierLoadState ||
                      previous.spellCardTierGroups != current.spellCardTierGroups ||
                      previous.expandedTiers != current.expandedTiers ||
                      previous.hasMore != current.hasMore ||
                      previous.error != current.error,
                  builder: (context, state) => _buildContentSliver(context, state),
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
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: theme.appBarTheme.backgroundColor,
      surfaceTintColor: theme.appBarTheme.backgroundColor,
      toolbarHeight: 80,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: Icon(
          MdiIcons.arrowLeft,
          color: colorScheme.onSurface,
        ),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: theme.appBarTheme.backgroundColor,
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: isDark ? 0.15 : 0.06),
              offset: const Offset(0, 1),
              blurRadius: 4,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(56, 12, 20, 12),
            child: Row(
              children: [
                _buildAppBarIcon(isDark),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '人物图鉴',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          letterSpacing: 0.3,
                        ),
                      ).animate().fadeIn(duration: 300.ms),
                      const SizedBox(height: 2),
                      Text(
                        _getSubtitle(state),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
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

  Widget _buildAppBarIcon(bool isDark) {
    final primaryColor = const Color(0xFF8B5CF6);
    
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [primaryColor.withValues(alpha: 0.9), const Color(0xFF6D28D9)]
              : [primaryColor, const Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: isDark ? 0.3 : 0.35),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Icon(MdiIcons.cardsOutline, color: Colors.white, size: 22),
    );
  }

  String _getSubtitle(CharacterGalleryState state) {
    if (state.listLoadState == LoadState.loading && state.characters.isEmpty) {
      return '加载中...';
    }
    if (state.showSpellCardTierView) {
      return '共 ${state.spellCardTierTotalCount} 张符卡';
    }
    return '共 ${state.totalCount} 个角色';
  }

  /// 构建内容区域（Sliver 版本）
  Widget _buildContentSliver(BuildContext context, CharacterGalleryState state) {
    // 加载中状态
    if (state.listLoadState == LoadState.loading && state.characters.isEmpty) {
      if (!state.showSpellCardTierView) {
        return SliverFillRemaining(child: _buildLoadingState());
      }
    }
    
    if (state.showSpellCardTierView && 
        state.spellCardTierLoadState == LoadState.loading &&
        state.spellCardTierGroups.isEmpty) {
      return SliverFillRemaining(child: _buildLoadingState());
    }

    // 错误状态
    if (state.listLoadState == LoadState.failure && state.characters.isEmpty) {
      return SliverFillRemaining(child: _buildErrorState(state.error));
    }
    
    if (state.showSpellCardTierView && 
        state.spellCardTierLoadState == LoadState.failure &&
        state.spellCardTierGroups.isEmpty) {
      return SliverFillRemaining(child: _buildErrorState(state.error));
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        if (state.showSpellCardTierView)
          _buildSpellCardTierList(state)
        else if (state.characters.isEmpty)
          _buildEmptyState()
        else
          _buildCharacterGrid(state),
        if (!state.showSpellCardTierView && state.characters.isNotEmpty)
          _buildBottomIndicator(state),
        const SizedBox(height: 20),
      ]),
    );
  }


  /// 构建工具栏（分类按钮 + 搜索框）
  Widget _buildToolbar(CharacterGalleryState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // 分类切换按钮 - 简洁文字设计
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
              children: [
                Expanded(
                  child: _buildCategoryChip(
                    '東方',
                    state.selectedCategory == CharacterCategory.touhou && 
                        !state.showSpellCardTierView,
                    () => _onCategoryChanged(CharacterCategory.touhou),
                    color: const Color(0xFFDC2626),
                  ),
                ),
                Expanded(
                  child: _buildCategoryChip(
                    '僵尸',
                    state.selectedCategory == CharacterCategory.zombie && 
                        !state.showSpellCardTierView,
                    () => _onCategoryChanged(CharacterCategory.zombie),
                    color: const Color(0xFF16A34A),
                  ),
                ),
                Expanded(
                  child: _buildCategoryChip(
                    '普通',
                    state.selectedCategory == CharacterCategory.normal && 
                        !state.showSpellCardTierView,
                    () => _onCategoryChanged(CharacterCategory.normal),
                    color: const Color(0xFF2563EB),
                  ),
                ),
                Expanded(
                  child: _buildCategoryChip(
                    '符卡',
                    state.showSpellCardTierView,
                    _onSpellCardTierTap,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 搜索框
          _buildSearchBox(),
        ],
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
    final chipColor = color ?? const Color(0xFF0080FF);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    );
  }

  Widget _buildSearchBox() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF8B5CF6);

    return Container(
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
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: '搜索角色名称...',
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
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
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
    );
  }

  /// 构建角色网格列表
  Widget _buildCharacterGrid(CharacterGalleryState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
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
            _buildTierGroup(tierGroup, state.expandedTiers.contains(tierGroup.tier)),
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
          if (isExpanded)
            _buildTierSpellCards(tierGroup.spellCards),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  /// 构建评级标题
  Widget _buildTierHeader(SpellCardTierGroup tierGroup, bool isExpanded, Color tierColor) {
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  color: isExpanded ? tierColor : theme.colorScheme.onSurfaceVariant,
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
          _buildSpellCardTierItem(spellCards[i], isLast: i == spellCards.length - 1),
      ],
    );
  }

  /// 构建符卡评级列表项（与桌面端完全一致）
  Widget _buildSpellCardTierItem(SpellCardTierItem spellCard, {bool isLast = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final gold = CharacterGalleryTheme.getGold(context);

    // 类型对应的颜色、符号和背景图（与桌面端完全一致）
    final (
      Color borderColor,
      Color bgColor,
      String symbol,
      String bgAsset,
    ) = switch (spellCard.type) {
      SpellCardType.passive => (
        const Color(0xFF4A7C59),
        const Color(0xFF4A7C59).withValues(alpha: isDark ? 0.15 : 0.08),
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
              // 背景图层（与桌面端一致）
              Positioned.fill(
                child: Image.asset(
                  bgAsset,
                  fit: BoxFit.cover,
                  opacity: AlwaysStoppedAnimation(isDark ? 0.3 : 0.5),
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
                                    const Shadow(color: Colors.white, blurRadius: 3),
                                    Shadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 6),
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
                                      const Shadow(color: Colors.white, blurRadius: 4),
                                      Shadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 8),
                                      Shadow(color: Colors.white.withValues(alpha: 0.7), blurRadius: 12),
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
                                  const Shadow(color: Colors.white, blurRadius: 3),
                                  Shadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 6),
                                ],
                        ),
                      ],
                    ),
                    // 分隔线（与桌面端一致）
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
                    if (spellCard.description != null && spellCard.description!.isNotEmpty)
                      Text(
                        spellCard.description!,
                        style: TextStyle(
                          color: inkColor,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          shadows: isDark
                              ? null
                              : [
                                  const Shadow(color: Colors.white, blurRadius: 4),
                                  Shadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 8),
                                  Shadow(color: Colors.white.withValues(alpha: 0.7), blurRadius: 12),
                                ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    // 属性行
                    if (spellCard.cooldown != null ||
                        spellCard.damage != null ||
                        spellCard.cost != null) ...[
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

  /// 评级列表项属性行（与桌面端完全一致）
  Widget _buildTierItemStats(SpellCardTierItem spellCard, Color accentColor, bool isDark) {
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

    return Wrap(spacing: 12, runSpacing: 6, children: statItems);
  }

  /// 单个属性项（与桌面端完全一致）
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
                  Shadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 6),
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
                    Shadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 6),
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
                    Shadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 6),
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
    final primaryColor = const Color(0xFFF59E0B);

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
    final primaryColor = const Color(0xFF8B5CF6);
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
                bloc.add(LoadSpellCardTierList(type: state.spellCardTierFilter));
              } else {
                bloc.add(LoadCharacters(
                  category: state.selectedCategory,
                  keyword: state.keyword,
                ));
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
    final primaryColor = const Color(0xFF8B5CF6);

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
                    color: primaryColor.withValues(alpha: isDark ? 0.25 : 0.2),
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
                      isDark ? primaryColor.withValues(alpha: 0.9) : primaryColor,
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
