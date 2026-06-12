import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../core/core.dart';
import '../../desktop/widgets/character_gallery/character_gallery_theme.dart';
import '../widgets/character_gallery/character_preview_mobile.dart';
import '../widgets/character_gallery/spell_card_mobile.dart';
import '../widgets/character_gallery/sub_model_selector_mobile.dart';
import '../widgets/character_gallery/zombie_skill_card_mobile.dart';

/// 移动端角色详情页面
class CharacterDetailMobile extends StatefulWidget {
  final int characterId;
  final int? initialSubModelId;

  const CharacterDetailMobile({
    super.key,
    required this.characterId,
    this.initialSubModelId,
  });

  @override
  State<CharacterDetailMobile> createState() => _CharacterDetailMobileState();
}

class _CharacterDetailMobileState extends State<CharacterDetailMobile> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 注意：initialSubModelId 的处理已经在路由配置中通过 LoadCharacterDetail 完成
    // 不需要在这里额外调用 SelectSubModel，因为此时角色数据可能还没加载完成
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CharacterGalleryBloc, CharacterGalleryState>(
      builder: (context, state) {
        return Scaffold(body: _buildBody(context, state));
      },
    );
  }

  Widget _buildBody(BuildContext context, CharacterGalleryState state) {
    // 加载中状态 - 显示骨架屏
    if (state.detailLoadState == LoadState.loading &&
        state.selectedCharacter == null) {
      return _buildSkeleton();
    }

    // 错误状态
    if (state.detailLoadState == LoadState.failure &&
        state.selectedCharacter == null) {
      return _buildErrorState(state.error);
    }

    // 成功加载 - 显示内容
    if (state.selectedCharacter != null) {
      return _buildContent(context, state);
    }

    // 初始状态 - 显示骨架屏
    return _buildSkeleton();
  }

  /// 构建内容区域
  Widget _buildContent(BuildContext context, CharacterGalleryState state) {
    return RefreshIndicator(
      onRefresh: () async {
        // 刷新时保持当前选中的子模型
        final currentSubModelId = state.selectedSubModelId;
        context.read<CharacterGalleryBloc>().add(
          LoadCharacterDetail(
            widget.characterId,
            initialSubModelId: currentSubModelId,
          ),
        );
      },
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
                  _buildPreviewSection(state),
                  const SizedBox(height: 16),
                  _buildCharacterInfo(state),
                  if (_hasSubModels(state)) ...[
                    const SizedBox(height: 16),
                    _buildSubModelSelector(state),
                  ],
                  const SizedBox(height: 16),
                  _buildDescription(state),
                  // 東方角色显示符卡
                  if (state.selectedCharacter?.category ==
                      CharacterCategory.touhou) ...[
                    const SizedBox(height: 24),
                    _buildSpellCardsSection(state),
                  ],
                  // 僵尸角色显示技能
                  if (state.selectedCharacter?.category ==
                      CharacterCategory.zombie) ...[
                    const SizedBox(height: 24),
                    _buildZombieSkillsSection(state),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建 AppBar
  Widget _buildAppBar(BuildContext context, CharacterGalleryState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final character = state.selectedCharacter;

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: theme.appBarTheme.backgroundColor,
      surfaceTintColor: theme.appBarTheme.backgroundColor,
      toolbarHeight: 56,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: Icon(MdiIcons.arrowLeft, color: colorScheme.onSurface),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            character?.name ?? '角色详情',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (character?.nameEn != null && character!.nameEn!.isNotEmpty)
            Text(
              character.nameEn!,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  bool _hasSubModels(CharacterGalleryState state) {
    return state.selectedCharacter?.subModels != null &&
        state.selectedCharacter!.subModels!.length > 1;
  }

  /// 构建预览图区域
  Widget _buildPreviewSection(CharacterGalleryState state) {
    final preview =
        state.currentSubModel?.preview ?? state.selectedCharacter?.preview;
    final characterName = state.selectedCharacter?.name;

    return CharacterPreviewMobile(
      preview: preview,
      currentPosition: state.previewPosition,
      onPositionChanged: (position) {
        context.read<CharacterGalleryBloc>().add(
          ChangePreviewPosition(position),
        );
      },
      onImageTap: () {
        final imageUrl = state.currentPreviewImage;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          FullscreenImageViewer.show(context, imageUrl, title: characterName);
        }
      },
    );
  }

  /// 构建角色信息区域（名称、获取渠道徽章）
  /// 与桌面端保持一致的显示逻辑
  Widget _buildCharacterInfo(CharacterGalleryState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final character = state.selectedCharacter;
    if (character == null) return const SizedBox.shrink();

    final currentSubModel = state.currentSubModel;
    // 如果是默认皮肤，显示角色名；否则显示子模型名（与桌面端一致）
    final displayName = (currentSubModel?.isDefault ?? true)
        ? character.name
        : (currentSubModel?.name ?? character.name);

    // 获取当前子模型的来源信息
    final acquisition = currentSubModel?.acquisition ?? character.acquisition;

    // 根据角色类型获取主题色
    final categoryColor = switch (character.category) {
      CharacterCategory.touhou => AppColors.red600,
      CharacterCategory.zombie => const Color(0xFF16A34A),
      _ => AppColors.violet500,
    };

    return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainer
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: categoryColor.withValues(alpha: isDark ? 0.2 : 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: categoryColor.withValues(alpha: isDark ? 0.1 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 角色名称带装饰
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 20,
                              decoration: BoxDecoration(
                                color: categoryColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (character.nameEn != null &&
                            character.nameEn!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 14),
                            child: Text(
                              character.nameEn!,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.8),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 获取渠道徽章（僵尸角色不显示，与桌面端一致）
                  if (character.category != CharacterCategory.zombie)
                    _buildAcquisitionBadge(acquisition),
                ],
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideY(begin: 0.05, end: 0);
  }

  /// 获取渠道徽章（与桌面端一致）
  Widget _buildAcquisitionBadge(AcquisitionInfo? acquisition) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (acquisition == null || acquisition.type == AcquisitionType.unknown) {
      return const SizedBox.shrink();
    }

    final (text, color, icon) = switch (acquisition.type) {
      AcquisitionType.gold => (
        '${acquisition.cost ?? 0} 金',
        CharacterGalleryTheme.getGold(context),
        Icons.monetization_on_outlined,
      ),
      AcquisitionType.points => (
        '${acquisition.cost ?? 0} 点',
        CharacterGalleryTheme.getVermillion(context),
        Icons.stars_rounded,
      ),
      AcquisitionType.custom => (
        acquisition.customSource ?? '特殊',
        CharacterGalleryTheme.getCustomSourceColor(context),
        Icons.auto_awesome_rounded,
      ),
      AcquisitionType.unknown => (
        '未知',
        theme.colorScheme.onSurfaceVariant,
        Icons.help_outline_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.4 : 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建子模型选择器
  Widget _buildSubModelSelector(CharacterGalleryState state) {
    final subModels = state.selectedCharacter?.subModels ?? [];
    final selectedId =
        state.selectedSubModelId ?? state.selectedCharacter?.defaultSubModelId;

    return SubModelSelectorMobile(
      subModels: subModels,
      selectedId: selectedId,
      onSelected: (id) {
        context.read<CharacterGalleryBloc>().add(SelectSubModel(id));
      },
    ).animate().fadeIn(duration: 300.ms, delay: 150.ms);
  }

  /// 构建角色介绍
  Widget _buildDescription(CharacterGalleryState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subModel = state.currentSubModel;
    // 优先使用子模型介绍（非空），兜底使用角色介绍（与桌面端一致）
    final description = (subModel?.description?.isNotEmpty ?? false)
        ? subModel!.description!
        : (state.selectedCharacter?.description ?? '暂无介绍');

    return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainer
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: isDark ? 0.3 : 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(
                        alpha: isDark ? 0.15 : 0.1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      MdiIcons.textBoxOutline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '角色介绍',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        )
                      : theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 0.05, end: 0);
  }

  /// 构建符卡区域（東方角色）
  Widget _buildSpellCardsSection(CharacterGalleryState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final vermillionColor = CharacterGalleryTheme.getVermillion(context);

    return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainer
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: vermillionColor.withValues(alpha: isDark ? 0.2 : 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: vermillionColor.withValues(alpha: isDark ? 0.1 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: vermillionColor.withValues(
                        alpha: isDark ? 0.15 : 0.1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      MdiIcons.cardsOutline,
                      size: 18,
                      color: vermillionColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '符卡',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  if (state.spellCards.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: vermillionColor.withValues(
                          alpha: isDark ? 0.15 : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${state.spellCards.length} 张',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: vermillionColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // 根据加载状态显示不同内容
              if (state.spellCardsLoadState == LoadState.loading)
                _buildSpellCardsSkeleton()
              else if (state.spellCards.isEmpty)
                _buildSpellCardsEmpty()
              else
                _buildSpellCardsGrouped(state.spellCards),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 250.ms)
        .slideY(begin: 0.05, end: 0);
  }

  /// 构建符卡加载骨架屏
  Widget _buildSpellCardsSkeleton() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shimmerBaseColor = isDark
        ? theme.colorScheme.surfaceContainer
        : Colors.grey[300]!;
    final shimmerHighlightColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.grey[100]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题骨架
        _buildSkeletonBox(
          width: 80,
          height: 20,
          borderRadius: 4,
          shimmerBaseColor: shimmerBaseColor,
          shimmerHighlightColor: shimmerHighlightColor,
        ),
        const SizedBox(height: 12),
        // 符卡卡片骨架
        _buildSkeletonBox(
          height: 140,
          borderRadius: 12,
          shimmerBaseColor: shimmerBaseColor,
          shimmerHighlightColor: shimmerHighlightColor,
        ),
        const SizedBox(height: 12),
        _buildSkeletonBox(
          height: 140,
          borderRadius: 12,
          shimmerBaseColor: shimmerBaseColor,
          shimmerHighlightColor: shimmerHighlightColor,
        ),
        const SizedBox(height: 20),
        // 第二组
        _buildSkeletonBox(
          width: 80,
          height: 20,
          borderRadius: 4,
          shimmerBaseColor: shimmerBaseColor,
          shimmerHighlightColor: shimmerHighlightColor,
        ),
        const SizedBox(height: 12),
        _buildSkeletonBox(
          height: 140,
          borderRadius: 12,
          shimmerBaseColor: shimmerBaseColor,
          shimmerHighlightColor: shimmerHighlightColor,
        ),
      ],
    );
  }

  /// 构建符卡空状态
  Widget _buildSpellCardsEmpty() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(
            MdiIcons.cardsOutline,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '暂无符卡数据',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// 构建分组显示的符卡列表
  Widget _buildSpellCardsGrouped(List<SpellCard> spellCards) {
    // 按类型分组
    final passiveCards = spellCards
        .where((card) => card.type == SpellCardType.passive)
        .toList();
    final ultimateCards = spellCards
        .where((card) => card.type == SpellCardType.ultimate)
        .toList();
    final normalCards = spellCards
        .where((card) => card.type == SpellCardType.normal)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 被动技能组
        if (passiveCards.isNotEmpty) ...[
          _buildSpellCardGroup(
            title: '被动技能',
            color: const Color(0xFF26A69A),
            cards: passiveCards,
          ),
          const SizedBox(height: 20),
        ],
        // 大符卡组
        if (ultimateCards.isNotEmpty) ...[
          _buildSpellCardGroup(
            title: '大符卡',
            color: const Color(0xFFFF8F00),
            cards: ultimateCards,
          ),
          const SizedBox(height: 20),
        ],
        // 小符卡组
        if (normalCards.isNotEmpty)
          _buildSpellCardGroup(
            title: '小符卡',
            color: AppColors.red600,
            cards: normalCards,
          ),
      ],
    );
  }

  /// 构建单个符卡分组
  Widget _buildSpellCardGroup({
    required String title,
    required Color color,
    required List<SpellCard> cards,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? color.withValues(alpha: 0.9) : color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${cards.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 符卡列表
        ...cards.asMap().entries.map((entry) {
          final index = entry.key;
          final card = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: index < cards.length - 1 ? 12 : 0),
            child: SpellCardMobile(spellCard: card),
          );
        }),
      ],
    );
  }

  /// 构建技能区域（僵尸角色）
  Widget _buildZombieSkillsSection(CharacterGalleryState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final skills = state.selectedCharacter?.zombieSkills ?? [];
    final zombieColor = const Color(0xFF16A34A);

    return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainer
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: zombieColor.withValues(alpha: isDark ? 0.2 : 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: zombieColor.withValues(alpha: isDark ? 0.1 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: zombieColor.withValues(alpha: isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      MdiIcons.flashOutline,
                      size: 18,
                      color: zombieColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '技能',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  if (skills.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: zombieColor.withValues(
                          alpha: isDark ? 0.15 : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${skills.length} 个',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: zombieColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (skills.isEmpty)
                _buildZombieSkillsEmpty()
              else
                _buildZombieSkillsGrouped(skills),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 250.ms)
        .slideY(begin: 0.05, end: 0);
  }

  /// 构建僵尸技能空状态
  Widget _buildZombieSkillsEmpty() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(
            MdiIcons.flashOffOutline,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '暂无技能数据',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// 构建分组显示的僵尸技能列表
  Widget _buildZombieSkillsGrouped(List<ZombieSkill> skills) {
    // 按类型分组
    final passiveSkills = skills
        .where((skill) => skill.type == ZombieSkillType.passive)
        .toList();
    final activeSkills = skills
        .where((skill) => skill.type == ZombieSkillType.active)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 被动技能组
        if (passiveSkills.isNotEmpty) ...[
          _buildZombieSkillGroup(
            title: '被动技能',
            color: const Color(0xFF388E3C), // 深绿色
            skills: passiveSkills,
          ),
          const SizedBox(height: 20),
        ],
        // 主动技能组
        if (activeSkills.isNotEmpty)
          _buildZombieSkillGroup(
            title: '主动技能',
            color: const Color(0xFF00897B), // 青绿色
            skills: activeSkills,
          ),
      ],
    );
  }

  /// 构建单个僵尸技能分组
  Widget _buildZombieSkillGroup({
    required String title,
    required Color color,
    required List<ZombieSkill> skills,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? color.withValues(alpha: 0.9) : color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${skills.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 技能列表
        ...skills.asMap().entries.map((entry) {
          final index = entry.key;
          final skill = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < skills.length - 1 ? 12 : 0,
            ),
            child: ZombieSkillCardMobile(skill: skill),
          );
        }),
      ],
    );
  }

  /// 构建骨架屏
  Widget _buildSkeleton() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shimmerBaseColor = isDark
        ? theme.colorScheme.surfaceContainer
        : Colors.grey[300]!;
    final shimmerHighlightColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.grey[100]!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(MdiIcons.arrowLeft, color: theme.colorScheme.onSurface),
        ),
        title: Container(
          width: 120,
          height: 24,
          decoration: BoxDecoration(
            color: shimmerBaseColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 预览图骨架
            _buildSkeletonBox(
              height: 300,
              borderRadius: 16,
              shimmerBaseColor: shimmerBaseColor,
              shimmerHighlightColor: shimmerHighlightColor,
            ),
            const SizedBox(height: 16),
            // 角色信息骨架
            _buildSkeletonBox(
              height: 80,
              borderRadius: 12,
              shimmerBaseColor: shimmerBaseColor,
              shimmerHighlightColor: shimmerHighlightColor,
            ),
            const SizedBox(height: 16),
            // 子模型选择器骨架
            Row(
              children: List.generate(
                3,
                (index) => Padding(
                  padding: EdgeInsets.only(right: index < 2 ? 8 : 0),
                  child: _buildSkeletonBox(
                    width: 80,
                    height: 80,
                    borderRadius: 12,
                    shimmerBaseColor: shimmerBaseColor,
                    shimmerHighlightColor: shimmerHighlightColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 描述骨架
            _buildSkeletonBox(
              height: 120,
              borderRadius: 12,
              shimmerBaseColor: shimmerBaseColor,
              shimmerHighlightColor: shimmerHighlightColor,
            ),
            const SizedBox(height: 24),
            // 符卡/技能区域骨架
            _buildSkeletonBox(
              height: 200,
              borderRadius: 12,
              shimmerBaseColor: shimmerBaseColor,
              shimmerHighlightColor: shimmerHighlightColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonBox({
    double? width,
    required double height,
    required double borderRadius,
    required Color shimmerBaseColor,
    required Color shimmerHighlightColor,
  }) {
    return Container(
          width: width ?? double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: shimmerBaseColor,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: 1500.ms,
          colors: [shimmerBaseColor, shimmerHighlightColor, shimmerBaseColor],
        );
  }

  /// 构建错误状态
  Widget _buildErrorState(String? error) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final errorColor = AppColors.red600;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(MdiIcons.arrowLeft, color: theme.colorScheme.onSurface),
        ),
        title: const Text('角色详情'),
      ),
      body: Center(
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
                  color: isDark
                      ? errorColor.withValues(alpha: 0.9)
                      : errorColor,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                        error ?? '角色不存在或加载失败',
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
                    onPressed: () {
                      context.read<CharacterGalleryBloc>().add(
                        LoadCharacterDetail(
                          widget.characterId,
                          initialSubModelId: widget.initialSubModelId,
                        ),
                      );
                    },
                    icon: Icon(MdiIcons.refresh, size: 18),
                    label: const Text('重新加载'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
      ),
    );
  }
}
