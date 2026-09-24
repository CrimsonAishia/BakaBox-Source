import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../core/core.dart';
import '../../desktop/widgets/character_gallery/character_gallery_theme.dart';
import '../../desktop/widgets/character_gallery/model_author_tags.dart';
import '../widgets/character_gallery/mobile_acquisition_seal_badge.dart';
import '../widgets/character_gallery/character_preview_mobile.dart';
import '../../core/widgets/disk_cached_image.dart';

/// 移动端刀枪模/菜单皮肤详情页面
class WeaponModelDetailMobile extends StatefulWidget {
  const WeaponModelDetailMobile({super.key});

  @override
  State<WeaponModelDetailMobile> createState() =>
      _WeaponModelDetailMobileState();
}

class _WeaponModelDetailMobileState extends State<WeaponModelDetailMobile> {
  final ScrollController _scrollController = ScrollController();

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
    // 加载中 / 未选中 → 骨架屏
    if (state.selectedWeaponModelId == null ||
        state.weaponDetailLoadState == LoadState.loading) {
      return _buildSkeleton();
    }

    final knife = state.selectedKnifeModel;
    final gun = state.selectedGunModel;
    final menuSkin = state.selectedMenuSkin;

    if (knife == null && gun == null && menuSkin == null) {
      return _buildErrorState('未找到装备数据');
    }

    return _buildContent(context, state, knife, gun, menuSkin);
  }

  // ─── 内容区域 ──────────────────────────────────────────────

  Widget _buildContent(
    BuildContext context,
    CharacterGalleryState state,
    KnifeModel? knife,
    GunModel? gun,
    MenuSkinModel? menuSkin,
  ) {
    final name = knife?.name ?? gun?.name ?? menuSkin?.name ?? '';
    final characterId =
        knife?.characterId ?? gun?.characterId ?? menuSkin?.characterId;
    final characterName =
        knife?.characterName ?? gun?.characterName ?? menuSkin?.characterName;
    final description =
        knife?.description ?? gun?.description ?? menuSkin?.description;
    final acquisition =
        knife?.acquisition ?? gun?.acquisition ?? menuSkin?.acquisition;
    final tags = knife?.tags ?? gun?.tags ?? menuSkin?.tags;
    final authorMetadata = (knife ?? gun ?? menuSkin) as ModelAuthorMetadata?;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        _buildAppBar(context, name),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 预览图
                _buildPreviewSection(state, knife, gun, menuSkin, name),
                const SizedBox(height: 16),
                // 名称 + 获取途径信息卡
                _buildInfoCard(name, tags, acquisition, authorMetadata, state),
                // 专属角色
                if (characterId != null &&
                    characterName != null &&
                    characterName.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildExclusiveCharacterCard(
                    characterId,
                    characterName,
                    state.weaponCharacterThumbnailUrl,
                    state.weaponCharacterLoadState,
                  ),
                ],
                // 描述
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildDescription(description),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── AppBar ─────────────────────────────

  Widget _buildAppBar(BuildContext context, String name) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: theme.appBarTheme.backgroundColor,
      surfaceTintColor: theme.appBarTheme.backgroundColor,
      toolbarHeight: 56,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(MdiIcons.arrowLeft, color: colorScheme.onSurface),
      ),
      title: Text(
        name.isEmpty ? '装备详情' : name,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ─── 预览图（复用 CharacterPreviewMobile 的风格）─────────────

  Widget _buildPreviewSection(
    CharacterGalleryState state,
    KnifeModel? knife,
    GunModel? gun,
    MenuSkinModel? menuSkin,
    String name,
  ) {
    // 如果是刀枪模（有多角度预览），构造 CharacterPreviewImages 来复用组件
    final weaponPreview = knife?.preview ?? gun?.preview;
    final isMenuSkin = state.selectedWeaponType == WeaponModelType.menuSkin;

    if (!isMenuSkin && weaponPreview != null) {
      // 将 WeaponModelPreview 映射为 CharacterPreviewImages
      final previewImages = CharacterPreviewImages(
        front: weaponPreview.front ?? '',
        left: weaponPreview.left ?? '',
        right: weaponPreview.right ?? '',
        back: weaponPreview.back ?? '',
        hand: weaponPreview.hand ?? '',
        leg: '', // 刀枪模没有腿部
      );

      return CharacterPreviewMobile(
        preview: previewImages,
        currentPosition: state.weaponPreviewPosition,
        onPositionChanged: (position) {
          context.read<CharacterGalleryBloc>().add(
            ChangeWeaponPreviewPosition(position),
          );
        },
        onImageTap: () {
          final imageUrl = state.currentWeaponPreviewImage;
          if (imageUrl != null && imageUrl.isNotEmpty) {
            FullscreenImageViewer.show(context, imageUrl, title: name);
          }
        },
      );
    }

    // 菜单皮肤：只有一张图，不需要角度切换
    final menuPreviewUrl = menuSkin?.previewUrl;
    final hasImage = menuPreviewUrl != null && menuPreviewUrl.isNotEmpty;

    return GestureDetector(
          onTap: hasImage
              ? () => FullscreenImageViewer.show(
                  context,
                  menuPreviewUrl,
                  title: name,
                )
              : null,
          child: Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: CharacterGalleryTheme.getWashiColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: CharacterGalleryTheme.getGold(context).withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.4
                      : 0.5,
                ),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: CharacterGalleryTheme.getGold(context).withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.15
                        : 0.2,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: hasImage
                  ? DiskCachedImage(
                      imageUrl: menuPreviewUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : Center(
                      child: Icon(
                        MdiIcons.imageOffOutline,
                        size: 48,
                        color: CharacterGalleryTheme.getScrollBrown(
                          context,
                        ).withValues(alpha: 0.35),
                      ),
                    ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 350.ms)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1.0, 1.0),
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }

  // ─── 信息卡片 ─────────

  Widget _buildInfoCard(
    String name,
    List<ItemTagData>? tags,
    AcquisitionInfo? acquisition,
    ModelAuthorMetadata? authorMetadata,
    CharacterGalleryState state,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // 装备统一用紫色主题
    final categoryColor = AppColors.violet500;

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
              // 名称
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                name,
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
                        // 标签
                        if (tags != null && tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 14),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: tags.map((t) => _buildTag(t)).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 获取渠道徽章
              Align(
                alignment: Alignment.centerRight,
                child: _buildAcquisitionBadge(authorMetadata, acquisition),
              ),
              // 来源、作者、投稿人
              if (authorMetadata != null)
                ModelAuthorTagsSection(
                  model: authorMetadata,
                  alignment: WrapAlignment.end,
                ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
        .slideX(begin: 0.05, end: 0);
  }

  // ─── 获取渠道徽章 ──────────────────────

  Widget _buildAcquisitionBadge(
    ModelAuthorMetadata? authorMetadata,
    AcquisitionInfo? acquisition,
  ) {
    List<Widget> badges = [];

    // 1. 额外检查
    if (authorMetadata?.othercheckKeyName != null &&
        authorMetadata!.othercheckKeyName!.isNotEmpty) {
      badges.add(ModelOtherCheckBadge(model: authorMetadata));
    }

    // 2. 特殊用户组
    if (authorMetadata?.groupName != null &&
        authorMetadata!.groupName!.isNotEmpty) {
      badges.add(ModelGroupBadge(model: authorMetadata));
    }

    // 3. 捐助者
    if (authorMetadata?.viplevel != null && authorMetadata!.viplevel! > 0) {
      badges.add(ModelViplevelBadge(model: authorMetadata));
    }

    // 4. 基础获取方式
    if (acquisition != null && acquisition.type != AcquisitionType.unknown) {
      badges.add(MobileAcquisitionSealBadge(acquisition: acquisition));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    // 插入加号
    List<Widget> childrenWithPlus = [];
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    for (int i = 0; i < badges.length; i++) {
      childrenWithPlus.add(badges[i]);
      if (i < badges.length - 1) {
        childrenWithPlus.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '+',
              style: TextStyle(
                color: inkColor.withValues(alpha: 0.5),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    }

    return Wrap(
      spacing: 4,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: childrenWithPlus,
    );
  }

  // ─── 标签组件 ─────────────────────────────────────────────

  Widget _buildTag(ItemTagData tag) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.slate500.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.slate500.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
      ),
      child: Text(
        tag.name,
        style: const TextStyle(
          color: AppColors.slate500,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ─── 专属角色卡片（新设计，与信息卡同风格）─────────────────

  Widget _buildExclusiveCharacterCard(
    int characterId,
    String characterName,
    String? thumbnailUrl,
    LoadState loadState,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = const Color(0xFF16A34A); // 绿色强调

    return GestureDetector(
      onTap: () => context.push('/character-gallery/$characterId'),
      child:
          Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainer
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accentColor.withValues(alpha: isDark ? 0.2 : 0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: isDark ? 0.1 : 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 缩略图
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(
                          alpha: isDark ? 0.1 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: loadState == LoadState.loading
                            ? Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: accentColor,
                                  ),
                                ),
                              )
                            : thumbnailUrl != null && thumbnailUrl.isNotEmpty
                            ? DiskCachedImage(
                                imageUrl: thumbnailUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : Icon(
                                Icons.person_rounded,
                                color: accentColor.withValues(alpha: 0.4),
                                size: 28,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // 标签 + 名称
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(
                                    alpha: isDark ? 0.15 : 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '专属角色',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            characterName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // 箭头
                    Icon(
                      MdiIcons.chevronRight,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 300.ms, delay: 200.ms)
              .slideX(begin: 0.05, end: 0),
    );
  }

  // ─── 描述卡片 ──────────

  Widget _buildDescription(String description) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                    '装备描述',
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
                child: RichTextViewer(
                  content: description,
                  textStyle: TextStyle(
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

  // ─── 骨架屏 ───────────────

  Widget _buildSkeleton() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shimmerBaseColor = isDark
        ? theme.colorScheme.surfaceContainer
        : Colors.grey[300]!;
    final shimmerHighlightColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.grey[100]!;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          elevation: 0,
          backgroundColor: theme.appBarTheme.backgroundColor,
          surfaceTintColor: theme.appBarTheme.backgroundColor,
          toolbarHeight: 56,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(MdiIcons.arrowLeft, color: theme.colorScheme.onSurface),
          ),
          title:
              Container(
                    width: 120,
                    height: 24,
                    decoration: BoxDecoration(
                      color: shimmerBaseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(
                    duration: 1500.ms,
                    colors: [
                      shimmerBaseColor,
                      shimmerHighlightColor,
                      shimmerBaseColor,
                    ],
                  ),
        ),
        SliverToBoxAdapter(
          child: Padding(
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
                // 信息卡骨架
                _buildSkeletonBox(
                  height: 140,
                  borderRadius: 16,
                  shimmerBaseColor: shimmerBaseColor,
                  shimmerHighlightColor: shimmerHighlightColor,
                ),
                const SizedBox(height: 16),
                // 专属角色卡片骨架
                _buildSkeletonBox(
                  height: 80,
                  borderRadius: 16,
                  shimmerBaseColor: shimmerBaseColor,
                  shimmerHighlightColor: shimmerHighlightColor,
                ),
                const SizedBox(height: 16),
                // 描述骨架
                _buildSkeletonBox(
                  height: 160,
                  borderRadius: 16,
                  shimmerBaseColor: shimmerBaseColor,
                  shimmerHighlightColor: shimmerHighlightColor,
                ),
              ],
            ),
          ),
        ),
      ],
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

  // ─── 错误状态 ───────────

  Widget _buildErrorState(String? error) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final errorColor = AppColors.red600;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(MdiIcons.arrowLeft, color: theme.colorScheme.onSurface),
        ),
        title: const Text('装备详情'),
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
                        error ?? '装备不存在或加载失败',
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
            ],
          ),
        ),
      ),
    );
  }
}
