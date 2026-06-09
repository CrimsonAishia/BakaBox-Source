import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../core/core.dart';
import '../../core/widgets/disk_cached_image.dart';
import '../widgets/character_gallery/character_gallery_theme.dart';
import '../widgets/character_gallery/character_common_widgets.dart';
import '../widgets/character_gallery/character_painters.dart';
import '../widgets/character_gallery/character_hanafuda_card.dart';
import '../widgets/character_gallery/character_sub_model_card.dart';
import '../widgets/character_gallery/weapon_model_hanafuda_card.dart';
import '../widgets/character_gallery/character_preview_card.dart';
import '../widgets/character_gallery/character_skill_card.dart';
import '../widgets/character_gallery/character_skeleton.dart';
import '../widgets/character_gallery/character_image_viewer.dart';
import '../widgets/character_gallery/character_unified_edit_dialog.dart';
import '../widgets/character_gallery/character_unified_history_dialog.dart';
import '../widgets/character_gallery/skill_preview_indicator.dart';

/// 格式化数值：整数不显示小数点，小数保留原样
String _formatNumber(num value) {
  if (value is int) {
    return value.toString();
  }
  final d = value as double;
  if (d == d.truncateToDouble()) {
    return d.toInt().toString();
  }
  return d.toString();
}

/// 幻想乡卷轴风格 - 角色图鉴页面
class CharacterGalleryDesktop extends StatefulWidget {
  const CharacterGalleryDesktop({super.key});

  @override
  State<CharacterGalleryDesktop> createState() =>
      _CharacterGalleryDesktopState();
}

class _CharacterGalleryDesktopState extends State<CharacterGalleryDesktop> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listScrollController = ScrollController();
  final ScrollController _detailScrollController = ScrollController();
  Timer? _searchDebounce;

  // 滚动指示器状态
  bool _listCanScrollUp = false;
  bool _listCanScrollDown = false;
  bool _detailCanScrollUp = false;
  bool _detailCanScrollDown = false;

  @override
  void initState() {
    super.initState();
    _listScrollController.addListener(_onScroll);
    _listScrollController.addListener(_updateListScrollIndicators);
    _detailScrollController.addListener(_updateDetailScrollIndicators);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<CharacterGalleryBloc>();
      if (bloc.state.listLoadState == LoadState.initial) {
        // 默认选中東方分类
        bloc.add(ChangeCategory(CharacterCategory.touhou));
      }
    });
  }

  void _onScroll() {
    if (_listScrollController.position.pixels >=
        _listScrollController.position.maxScrollExtent - 200) {
      context.read<CharacterGalleryBloc>().add(LoadMoreCharacters());
    }
  }

  void _updateListScrollIndicators() {
    if (!_listScrollController.hasClients) return;
    final position = _listScrollController.position;
    final canUp = position.pixels > 0;
    final canDown = position.pixels < position.maxScrollExtent;
    if (canUp != _listCanScrollUp || canDown != _listCanScrollDown) {
      setState(() {
        _listCanScrollUp = canUp;
        _listCanScrollDown = canDown;
      });
    }
  }

  void _updateDetailScrollIndicators() {
    if (!_detailScrollController.hasClients) return;
    final position = _detailScrollController.position;
    final canUp = position.pixels > 0;
    final canDown = position.pixels < position.maxScrollExtent;
    if (canUp != _detailCanScrollUp || canDown != _detailCanScrollDown) {
      setState(() {
        _detailCanScrollUp = canUp;
        _detailCanScrollDown = canDown;
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _listScrollController.removeListener(_onScroll);
    _listScrollController.removeListener(_updateListScrollIndicators);
    _listScrollController.dispose();
    _detailScrollController.removeListener(_updateDetailScrollIndicators);
    _detailScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final washiColor = CharacterGalleryTheme.getWashiColor(context);

    return BlocListener<CharacterGalleryBloc, CharacterGalleryState>(
      listenWhen: (prev, curr) =>
          prev.deleteRequestState != curr.deleteRequestState,
      listener: (context, state) {
        if (state.deleteRequestState == LoadState.success) {
          ToastUtils.showSuccess(context, '编辑申请已撤销');
        } else if (state.deleteRequestState == LoadState.failure) {
          ToastUtils.showError(
            context,
            state.deleteRequestError ?? '撤销失败，请稍后重试',
          );
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // 和纸纹理背景（夜间模式使用纯色背景）
            Positioned.fill(
              child: isDark
                  ? Container(color: washiColor)
                  : Image.asset(
                      'assets/images/character_gallery/washi_paper.png',
                      repeat: ImageRepeat.repeat,
                      fit: BoxFit.none,
                    ),
            ),
            // 左侧过渡渐变
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 32,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      navBgColor,
                      navBgColor.withValues(alpha: 0.5),
                      washiColor.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            // 主内容
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 55, 16, 16),
              child: _buildScrollContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollContent() {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Container(
      decoration: BoxDecoration(
        color: washiColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scrollBrown.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        children: [
          _buildToolbar(),
          Container(height: 1, color: scrollBrown.withValues(alpha: 0.3)),
          Expanded(
            child: Row(
              children: [
                Expanded(flex: 3, child: _buildCharacterGrid()),
                _buildVerticalDivider(),
                Expanded(flex: 4, child: _buildDetailPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return BlocBuilder<CharacterGalleryBloc, CharacterGalleryState>(
      buildWhen: (prev, curr) =>
          prev.selectedCategory != curr.selectedCategory ||
          prev.showSpellCardTierView != curr.showSpellCardTierView ||
          prev.showWeaponModelView != curr.showWeaponModelView ||
          prev.sortBy != curr.sortBy,
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              CategoryButton(
                label: '東方',
                isSelected:
                    state.selectedCategory == CharacterCategory.touhou &&
                    !state.showSpellCardTierView &&
                    !state.showWeaponModelView,
                onTap: () {
                  PaintingBinding.instance.imageCache.clear();
                  context.read<CharacterGalleryBloc>().add(
                    ChangeCategory(CharacterCategory.touhou),
                  );
                },
              ),
              const SizedBox(width: 8),
              CategoryButton(
                label: '僵尸',
                isSelected:
                    state.selectedCategory == CharacterCategory.zombie &&
                    !state.showSpellCardTierView &&
                    !state.showWeaponModelView,
                onTap: () {
                  PaintingBinding.instance.imageCache.clear();
                  context.read<CharacterGalleryBloc>().add(
                    ChangeCategory(CharacterCategory.zombie),
                  );
                },
              ),
              const SizedBox(width: 8),
              CategoryButton(
                label: '普通',
                isSelected:
                    state.selectedCategory == CharacterCategory.normal &&
                    !state.showSpellCardTierView &&
                    !state.showWeaponModelView,
                onTap: () {
                  PaintingBinding.instance.imageCache.clear();
                  context.read<CharacterGalleryBloc>().add(
                    ChangeCategory(CharacterCategory.normal),
                  );
                },
              ),
              const SizedBox(width: 8),
              // 分隔线
              Builder(
                builder: (context) {
                  final scrollBrown = CharacterGalleryTheme.getScrollBrown(
                    context,
                  );
                  return Container(
                    width: 1,
                    height: 20,
                    color: scrollBrown.withValues(alpha: 0.3),
                  );
                },
              ),
              const SizedBox(width: 8),
              // 符卡评级按钮
              CategoryButton(
                label: '符卡',
                isSelected: state.showSpellCardTierView,
                onTap: () {
                  PaintingBinding.instance.imageCache.clear();
                  context.read<CharacterGalleryBloc>().add(
                    const LoadSpellCardTierList(),
                  );
                },
              ),
              const SizedBox(width: 8),
              // 刀枪图鉴按钮
              CategoryButton(
                label: '刀枪',
                isSelected: state.showWeaponModelView,
                onTap: () {
                  PaintingBinding.instance.imageCache.clear();
                  context.read<CharacterGalleryBloc>().add(
                    const LoadAllWeaponModels(),
                  );
                },
              ),
              const Spacer(),
              // 排序按钮（仅在人物和符卡视图显示）
              if (!state.showWeaponModelView) ...[
                _buildSortButton(state.sortBy),
                const SizedBox(width: 8),
              ],
              _buildSearchBox(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortButton(String currentSortBy) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final cardBg = CharacterGalleryTheme.getCardBackground(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUpdate = currentSortBy == 'update';
    final label = isUpdate ? '最近更新' : '默认';

    return PopupMenuButton<String>(
      tooltip: '排序方式',
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: scrollBrown.withValues(alpha: 0.3)),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      onSelected: (value) {
        context.read<CharacterGalleryBloc>().add(ChangeSortBy(value));
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: '',
          height: 36,
          child: Row(
            children: [
              Icon(
                Icons.sort,
                size: 16,
                color: !isUpdate
                    ? CharacterGalleryTheme.getVermillion(context)
                    : inkColor.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                '默认',
                style: TextStyle(
                  color: inkColor,
                  fontSize: 13,
                  fontWeight: !isUpdate ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'update',
          height: 36,
          child: Row(
            children: [
              Icon(
                Icons.update,
                size: 16,
                color: isUpdate
                    ? CharacterGalleryTheme.getVermillion(context)
                    : inkColor.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                '最近更新',
                style: TextStyle(
                  color: inkColor,
                  fontSize: 13,
                  fontWeight: isUpdate ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isUpdate
              ? CharacterGalleryTheme.getVermillion(
                  context,
                ).withValues(alpha: isDark ? 0.2 : 0.1)
              : cardBg.withValues(alpha: 0.8),
          border: Border.all(
            color: isUpdate
                ? CharacterGalleryTheme.getVermillion(context)
                : scrollBrown.withValues(alpha: 0.4),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_vert,
              size: 14,
              color: isUpdate
                  ? CharacterGalleryTheme.getVermillion(context)
                  : inkColor.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: inkColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: inkColor.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);

    return Container(
      width: 180,
      height: 32,
      decoration: BoxDecoration(
        color: inputBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: inkColor, fontSize: 13),
        decoration: InputDecoration(
          hintText: '搜索...',
          hintStyle: TextStyle(
            color: inkColor.withValues(alpha: 0.4),
            fontSize: 13,
          ),
          prefixIcon: Icon(Icons.search, color: scrollBrown, size: 18),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: scrollBrown, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: scrollBrown.withValues(alpha: 0.4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: scrollBrown.withValues(alpha: 0.4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(
              color: CharacterGalleryTheme.getVermillion(context),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
        onChanged: _onSearchChanged,
        onSubmitted: (value) {
          _searchDebounce?.cancel();
          context.read<CharacterGalleryBloc>().add(SearchCharacters(value));
        },
      ),
    );
  }

  void _onSearchChanged(String value) {
    // 取消之前的定时器
    _searchDebounce?.cancel();

    // 设置新的定时器，500ms 后触发搜索
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      context.read<CharacterGalleryBloc>().add(SearchCharacters(value));
    });

    // 更新清除按钮显示状态
    setState(() {});
  }

  Widget _buildVerticalDivider() {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    return SizedBox(
      width: 20,
      child: CustomPaint(
        painter: TraditionalDividerPainter(color: scrollBrown),
        size: const Size(20, double.infinity),
      ),
    );
  }

  Widget _buildCharacterGrid() {
    return BlocBuilder<CharacterGalleryBloc, CharacterGalleryState>(
      builder: (context, state) {
        // 如果是符卡评级视图，显示符卡列表
        if (state.showSpellCardTierView) {
          return _buildSpellCardTierList(state);
        }

        // 如果是刀枪图鉴视图，显示刀枪列表
        if (state.showWeaponModelView) {
          return _buildWeaponModelList(state);
        }

        if (state.listLoadState == LoadState.loading &&
            state.characters.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              color: CharacterGalleryTheme.getVermillion(context),
            ),
          );
        }
        if (state.listLoadState == LoadState.failure &&
            state.characters.isEmpty) {
          return _buildErrorState(state.error ?? '加载失败');
        }
        if (state.characters.isEmpty) {
          return _buildEmptyState();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateListScrollIndicators();
        });

        return Stack(
          children: [
            GridView.builder(
              controller: _listScrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount:
                  state.characters.length +
                  (state.listLoadState == LoadState.loading &&
                          state.characters.isNotEmpty
                      ? 1
                      : 0),
              itemBuilder: (context, index) {
                // 如果是最后一项且正在加载，显示加载指示器
                if (index == state.characters.length) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(
                        color: CharacterGalleryTheme.getVermillion(context),
                      ),
                    ),
                  );
                }

                final character = state.characters[index];
                // 卡片选中状态：已加载完成的角色 或 正在加载中的角色
                final isSelected =
                    state.selectedCharacter?.id == character.id ||
                    state.loadingCharacterId == character.id;
                return HanafudaCard(
                  character: character,
                  isSelected: isSelected,
                  onTap: () => context.read<CharacterGalleryBloc>().add(
                    LoadCharacterDetail(character.id),
                  ),
                );
              },
            ),
            if (_listCanScrollUp)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ScrollIndicator(isTop: true),
              ),
            if (_listCanScrollDown)
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ScrollIndicator(isTop: false),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDetailPanel() {
    return BlocBuilder<CharacterGalleryBloc, CharacterGalleryState>(
      builder: (context, state) {
        // 如果是刀枪图鉴视图
        if (state.showWeaponModelView) {
          // 优先判断 loading 状态
          if (state.detailLoadState == LoadState.loading) {
            return const DetailPanelSkeleton();
          }
          // 如果有选中的角色（从刀枪模跳转过来），显示角色详情
          if (state.selectedCharacter != null) {
            return Stack(
              children: [
                KeyedSubtree(
                  key: ValueKey(
                    '${state.selectedCharacter!.id}_${state.selectedSubModelId}',
                  ),
                  child: _buildCharacterDetail(state),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, authState) =>
                        _buildEditFab(state, authState.isAuthenticated),
                  ),
                ),
              ],
            );
          }
          // 否则显示刀枪模详情
          return _buildWeaponModelDetailPanel(state);
        }

        // 角色图鉴视图：优先判断 loading 状态
        if (state.detailLoadState == LoadState.loading) {
          return const DetailPanelSkeleton();
        }

        // 如果有选中的刀枪模（从角色详情的专属装备点击过来），显示刀枪模详情
        if (state.selectedWeaponModelId != null &&
            state.selectedCharacter == null) {
          // 刀枪模详情加载中显示骨架屏
          if (state.weaponDetailLoadState == LoadState.loading) {
            return const WeaponModelDetailSkeleton();
          }
          return _buildWeaponModelDetailPanel(state);
        }

        // 没有选中角色时显示提示
        if (state.selectedCharacter == null) {
          return _buildSelectHint();
        }
        // 正常显示角色详情
        return Stack(
          children: [
            KeyedSubtree(
              key: ValueKey(
                '${state.selectedCharacter!.id}_${state.selectedSubModelId}',
              ),
              child: _buildCharacterDetail(state),
            ),
            // 编辑浮动按钮（包含待审核状态）- 监听登录状态变化
            Positioned(
              right: 16,
              bottom: 16,
              child: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, authState) =>
                    _buildEditFab(state, authState.isAuthenticated),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 刀枪模详情面板（和角色详情一样的布局）
  Widget _buildWeaponModelDetailPanel(CharacterGalleryState state) {
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    // 没有选中刀枪模时显示提示
    if (state.selectedWeaponModelId == null) {
      return _buildWeaponModelSelectHint(state);
    }

    // 加载中显示骨架屏
    if (state.weaponDetailLoadState == LoadState.loading) {
      return const WeaponModelDetailSkeleton();
    }

    // 获取选中的刀枪模
    final knife = state.selectedKnifeModel;
    final gun = state.selectedGunModel;

    if (knife == null && gun == null) {
      return _buildWeaponModelSelectHint(state);
    }

    final name = knife?.name ?? gun?.name ?? '';
    final characterId = knife?.characterId ?? gun?.characterId;
    final characterName = knife?.characterName ?? gun?.characterName;
    final description = knife?.description ?? gun?.description;
    final acquisition = knife?.acquisition ?? gun?.acquisition;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateDetailScrollIndicators();
    });

    return Stack(
      children: [
        SingleChildScrollView(
          controller: _detailScrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 预览图区域（和角色详情一样）
              _buildWeaponPreviewSection(state),
              const SizedBox(height: 20),
              // 名称区域
              _buildWeaponNameSection(name, acquisition),
              const SizedBox(height: 16),
              // 专属角色区域（参照人物详情中专属刀模/枪模的布局）
              if (characterId != null &&
                  characterName != null &&
                  characterName.isNotEmpty)
                _buildExclusiveCharacterSection(
                  characterId,
                  characterName,
                  state.weaponCharacterThumbnailUrl,
                  state.weaponCharacterAcquisition,
                  state.weaponCharacterLoadState,
                ),
              // 描述
              if (description != null && description.isNotEmpty) ...[
                SectionDivider(title: '描述'),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    color: inkColor.withValues(alpha: 0.8),
                    fontSize: 14,
                    height: 1.8,
                  ),
                ),
              ],
              // 底部留白
              const SizedBox(height: 60),
            ],
          ),
        ),
        if (_detailCanScrollUp)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ScrollIndicator(isTop: true),
          ),
        if (_detailCanScrollDown)
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ScrollIndicator(isTop: false),
          ),
      ],
    );
  }

  /// 刀枪模预览区域（和角色详情一样的布局）
  Widget _buildWeaponPreviewSection(CharacterGalleryState state) {
    final previewUrl = state.currentWeaponPreviewImage;
    final knife = state.selectedKnifeModel;
    final gun = state.selectedGunModel;
    final preview = knife?.preview ?? gun?.preview;
    final name = knife?.name ?? gun?.name ?? '';

    return Column(
      children: [
        PreviewImageCard(
          key: ValueKey(
            'weapon_preview_${state.selectedWeaponModelId}_${state.weaponPreviewPosition}',
          ),
          imageUrl: previewUrl,
          onTap: (previewUrl != null && previewUrl.isNotEmpty)
              ? () => _showWeaponImageViewer(previewUrl, preview, name)
              : null,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PreviewPositionButton(
              position: 0,
              label: '正',
              isSelected: state.weaponPreviewPosition == 0,
              onTap: () => context.read<CharacterGalleryBloc>().add(
                const ChangeWeaponPreviewPosition(0),
              ),
            ),
            PreviewPositionButton(
              position: 1,
              label: '左',
              isSelected: state.weaponPreviewPosition == 1,
              onTap: () => context.read<CharacterGalleryBloc>().add(
                const ChangeWeaponPreviewPosition(1),
              ),
            ),
            PreviewPositionButton(
              position: 2,
              label: '右',
              isSelected: state.weaponPreviewPosition == 2,
              onTap: () => context.read<CharacterGalleryBloc>().add(
                const ChangeWeaponPreviewPosition(2),
              ),
            ),
            PreviewPositionButton(
              position: 3,
              label: '背',
              isSelected: state.weaponPreviewPosition == 3,
              onTap: () => context.read<CharacterGalleryBloc>().add(
                const ChangeWeaponPreviewPosition(3),
              ),
            ),
            PreviewPositionButton(
              position: 4,
              label: '手',
              isSelected: state.weaponPreviewPosition == 4,
              onTap: () => context.read<CharacterGalleryBloc>().add(
                const ChangeWeaponPreviewPosition(4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 刀枪模图片查看器
  void _showWeaponImageViewer(
    String imageUrl,
    WeaponModelPreview? preview,
    String name,
  ) {
    if (imageUrl.isEmpty) return;

    final allImages = <String>[];
    if (preview != null) {
      allImages.addAll(preview.validUrls);
    }

    if (allImages.isEmpty) return;

    final initialIndex = allImages.indexOf(imageUrl);
    final safeIndex = initialIndex >= 0 ? initialIndex : 0;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => CharacterImageViewerDialog(
        images: allImages,
        initialIndex: safeIndex,
        characterName: name,
      ),
    );
  }

  /// 刀枪模名称区域
  Widget _buildWeaponNameSection(String name, AcquisitionInfo? acquisition) {
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '◆',
          style: TextStyle(
            color: CharacterGalleryTheme.getVermillion(context),
            fontSize: 18,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: inkColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
        // 来源途径徽章
        if (acquisition != null && acquisition.type != AcquisitionType.unknown)
          _AcquisitionSealBadge(acquisition: acquisition),
      ],
    );
  }

  /// 专属角色区域（参照人物详情中专属刀模/枪模的布局）
  Widget _buildExclusiveCharacterSection(
    int characterId,
    String characterName,
    String? characterThumbnailUrl,
    AcquisitionInfo? characterAcquisition,
    LoadState loadState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionDivider(title: '专属角色'),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: _ExclusiveCharacterCard(
            characterId: characterId,
            characterName: characterName,
            characterThumbnailUrl: characterThumbnailUrl,
            characterAcquisition: characterAcquisition,
            isLoading: loadState == LoadState.loading,
            onTap: () => _navigateToCharacterFromWeapon(characterId),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// 从刀枪模详情跳转到角色详情（保持刀枪图鉴视图，只切换详情面板）
  void _navigateToCharacterFromWeapon(int characterId) {
    // 加载角色详情，但保持刀枪图鉴视图
    context.read<CharacterGalleryBloc>().add(
      LoadCharacterDetailInWeaponView(characterId),
    );
  }

  /// 刀枪模选择提示
  Widget _buildWeaponModelSelectHint(CharacterGalleryState state) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final isKnife = state.weaponModelTab == 0;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isKnife ? MdiIcons.knife : MdiIcons.pistol,
            size: 64,
            color: scrollBrown.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '请从左侧选择${isKnife ? '刀模' : '枪模'}',
            style: TextStyle(
              color: inkColor.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditFab(CharacterGalleryState state, bool isLoggedIn) {
    final character = state.selectedCharacter;
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final cardBg = CharacterGalleryTheme.getCardBackground(context);

    // 没有选中角色时不显示按钮
    if (character == null) {
      return const SizedBox.shrink();
    }

    // 获取当前子模型，如果没有子模型则创建一个虚拟的默认子模型
    final currentSubModel =
        state.currentSubModel ?? _createDefaultSubModel(character);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 历史按钮
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _openUnifiedHistoryDialog(character, currentSubModel),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scrollBrown.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: inkColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, color: scrollBrown, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '历史',
                    style: TextStyle(
                      color: scrollBrown,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 未登录时不显示编辑按钮
        if (isLoggedIn) ...[
          const SizedBox(width: 10),
          // 有待审核申请时显示待审核按钮组，否则显示编辑按钮
          if (state.hasPendingRequest)
            _buildPendingRequestButtons(character, currentSubModel, state)
          else
            _buildEditButton(character, currentSubModel, state.spellCards),
        ],
      ],
    );
  }

  /// 编辑按钮
  Widget _buildEditButton(
    CharacterModel character,
    CharacterSubModel subModel,
    List<SpellCard> spellCards,
  ) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openUnifiedEditDialog(character, subModel, spellCards),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: scrollBrown,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: scrollBrown.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                '编辑',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 待审核状态按钮组（修改 + 撤销）
  Widget _buildPendingRequestButtons(
    CharacterModel character,
    CharacterSubModel subModel,
    CharacterGalleryState state,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            color: Colors.orange.shade700,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            '审核中',
            style: TextStyle(
              color: Colors.orange.shade800,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          // 修改
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _openEditDialogForPendingRequest(
                character,
                subModel,
                state.spellCards,
                state.pendingRequestId!,
              ),
              child: Text(
                '修改',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '|',
              style: TextStyle(color: Colors.orange.shade300, fontSize: 13),
            ),
          ),
          // 撤销
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _showDeleteConfirmDialog(state.pendingRequestId!),
              child: Text(
                '撤销',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openUnifiedHistoryDialog(
    CharacterModel character,
    CharacterSubModel subModel,
  ) {
    // 如果子模型 ID 为 0（虚拟子模型），则不打开历史对话框
    if (subModel.id == 0) {
      ToastUtils.showInfo(context, '该角色暂无编辑历史');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => UnifiedHistoryDialog(
        subModelId: subModel.id,
        characterName: character.name,
        subModelName: subModel.name,
        category: character.category,
      ),
    );
  }

  void _openUnifiedEditDialog(
    CharacterModel character,
    CharacterSubModel subModel,
    List<SpellCard> spellCards,
  ) async {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    // 显示加载中
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: washiColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: CharacterGalleryTheme.getVermillion(context),
              ),
              const SizedBox(height: 16),
              Text('加载数据...', style: TextStyle(color: inkColor, fontSize: 14)),
            ],
          ),
        ),
      ),
    );

    try {
      final api = CharacterApi();

      // 确定有效的 subModelId
      final effectiveSubModelId = subModel.id > 0
          ? subModel.id
          : character.subModels?.firstOrNull?.id;

      // 并行获取最新的角色详情、子模型详情和符卡数据
      final futures = await Future.wait([
        api.getCharacterDetail(character.id),
        effectiveSubModelId != null
            ? api.getSubModelDetail(character.id, effectiveSubModelId)
            : Future.value(null),
        character.category == CharacterCategory.touhou &&
                effectiveSubModelId != null
            ? api.getSpellCards(character.id, subModelId: effectiveSubModelId)
            : Future.value(null),
      ]);

      if (!mounted) return;
      Navigator.pop(context); // 关闭加载对话框

      final latestCharacter = futures[0] as CharacterModel?;
      final latestSubModel = futures[1] as CharacterSubModel?;
      final latestSpellCards =
          futures[2] as Map<SpellCardType, List<SpellCard>>?;

      if (latestCharacter == null) {
        ToastUtils.showError(context, '获取角色数据失败');
        return;
      }

      // 使用最新数据，如果子模型获取失败则使用传入的数据
      final finalSubModel = latestSubModel ?? subModel;
      final List<SpellCard> finalSpellCards = latestSpellCards != null
          ? <SpellCard>[
              ...latestSpellCards[SpellCardType.normal] ?? [],
              ...latestSpellCards[SpellCardType.ultimate] ?? [],
              ...latestSpellCards[SpellCardType.passive] ?? [],
            ]
          : spellCards;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => UnifiedEditDialog(
          character: latestCharacter,
          subModel: finalSubModel,
          spellCards: finalSpellCards,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 关闭加载对话框
      ToastUtils.showError(context, '获取数据失败: $e');
    }
  }

  /// 为没有子模型的角色创建一个虚拟的默认子模型
  CharacterSubModel _createDefaultSubModel(CharacterModel character) {
    return CharacterSubModel(
      id: 0, // 虚拟ID
      characterId: character.id,
      name: character.name,
      type: SubModelType.default_,
      thumbnailUrl: character.thumbnailUrl,
      preview: character.preview,
      acquisition: character.acquisition,
      isDefault: true,
      sortOrder: 0,
    );
  }

  void _openEditDialogForPendingRequest(
    CharacterModel character,
    CharacterSubModel subModel,
    List<SpellCard> spellCards,
    int pendingRequestId,
  ) async {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    // 显示加载中
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: washiColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: CharacterGalleryTheme.getVermillion(context),
              ),
              const SizedBox(height: 16),
              Text(
                '加载申请详情...',
                style: TextStyle(color: inkColor, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // 获取申请详情
      final api = CharacterApi();
      final detail = await api.getEditRequestDetail(pendingRequestId);

      if (!mounted) return;
      Navigator.pop(context); // 关闭加载对话框

      if (detail == null) {
        ToastUtils.showError(context, '获取申请详情失败');
        return;
      }

      // 打开编辑对话框，传入申请详情
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => UnifiedEditDialog(
          character: character,
          subModel: subModel,
          spellCards: spellCards,
          pendingRequestId: pendingRequestId,
          pendingRequestDetail: detail,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 关闭加载对话框
      ToastUtils.showError(context, '获取申请详情失败: $e');
    }
  }

  void _showDeleteConfirmDialog(int requestId) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: washiColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scrollBrown.withValues(alpha: 0.4)),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            Text(
              '撤销编辑申请',
              style: TextStyle(
                color: inkColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          '确定要撤销这条编辑申请吗？撤销后无法恢复。',
          style: TextStyle(
            color: inkColor.withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: scrollBrown)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteEditRequest(requestId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定撤销'),
          ),
        ],
      ),
    );
  }

  void _deleteEditRequest(int requestId) {
    context.read<CharacterGalleryBloc>().add(DeleteEditRequest(requestId));
  }

  Widget _buildSelectHint() {
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎴', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            '选择一张卡片查看详情',
            style: TextStyle(
              color: inkColor.withValues(alpha: 0.6),
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterDetail(CharacterGalleryState state) {
    final character = state.selectedCharacter!;
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateDetailScrollIndicators();
    });

    return Stack(
      children: [
        SingleChildScrollView(
          controller: _detailScrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPreviewSection(state),
              const SizedBox(height: 20),
              _buildNameSection(character, state),
              const SizedBox(height: 16),
              if (character.subModels != null &&
                  character.subModels!.length > 1)
                _buildSubModelSelector(state),
              // 角色介绍（优先使用子模型介绍，兜底使用角色介绍）
              SectionDivider(title: '角色介绍'),
              const SizedBox(height: 12),
              Text(
                (state.currentSubModel?.description?.isNotEmpty ?? false)
                    ? state.currentSubModel!.description!
                    : character.description,
                style: TextStyle(
                  color: inkColor.withValues(alpha: 0.8),
                  fontSize: 14,
                  height: 1.8,
                ),
              ),
              // 符卡/技能区域
              if (character.category == CharacterCategory.touhou)
                _buildSpellCardsSection(state),
              if (character.category == CharacterCategory.zombie)
                _buildZombieSkillsSection(character),
              // 刀模/枪模区域
              _buildWeaponModelsSection(state),
              // 底部留白，避免被浮动按钮遮挡
              const SizedBox(height: 60),
            ],
          ),
        ),
        if (_detailCanScrollUp)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ScrollIndicator(isTop: true),
          ),
        if (_detailCanScrollDown)
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ScrollIndicator(isTop: false),
          ),
      ],
    );
  }

  /// 符卡区域
  Widget _buildSpellCardsSection(CharacterGalleryState state) {
    final spellCards = state.spellCards;

    // 分组：被动、大符卡、小符卡
    final passive = spellCards
        .where((c) => c.type == SpellCardType.passive)
        .toList();
    final ultimate = spellCards
        .where((c) => c.type == SpellCardType.ultimate)
        .toList();
    final normal = spellCards
        .where((c) => c.type == SpellCardType.normal)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionDivider(title: '符卡系统'),
        const SizedBox(height: 12),
        if (state.spellCardsLoadState == LoadState.loading)
          const SpellCardsLoadingSkeleton()
        else if (spellCards.isEmpty)
          const EmptySkillHint(text: '暂无符卡数据')
        else ...[
          // 被动技能
          if (passive.isNotEmpty) ...[
            _buildSpellCardGroupHeader('被动技能', const Color(0xFF4A7C59)),
            const SizedBox(height: 8),
            ...passive.map((card) => _buildTouhouSpellCard(card)),
            const SizedBox(height: 16),
          ],
          // 大符卡
          if (ultimate.isNotEmpty) ...[
            _buildSpellCardGroupHeader(
              '大符卡',
              CharacterGalleryTheme.getGold(context),
            ),
            const SizedBox(height: 8),
            ...ultimate.map((card) => _buildTouhouSpellCard(card)),
            const SizedBox(height: 16),
          ],
          // 小符卡
          if (normal.isNotEmpty) ...[
            _buildSpellCardGroupHeader(
              '小符卡',
              CharacterGalleryTheme.getVermillion(context),
            ),
            const SizedBox(height: 8),
            ...normal.map((card) => _buildTouhouSpellCard(card)),
          ],
        ],
      ],
    );
  }

  /// 符卡分组标题
  Widget _buildSpellCardGroupHeader(String title, Color color) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: scrollBrown,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.3)),
        ),
      ],
    );
  }

  /// 东方风格符卡卡片
  Widget _buildTouhouSpellCard(SpellCard card) {
    final type = card.type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final gold = CharacterGalleryTheme.getGold(context);

    // 类型对应的颜色、符号和背景图
    final (
      Color borderColor,
      Color bgColor,
      String symbol,
      String bgAsset,
    ) = switch (type) {
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

    // 卡片高度：背景图比例 4:1，宽度约 320px，所以最小高度约 80px
    // 但需要容纳内容，所以用 constraints 而非固定高度
    return SkillPreviewIndicator(
      previewType: card.previewType,
      previewImageUrl: card.previewImageUrl,
      previewVideoUrl: card.previewVideoUrl,
      previewVideoOrigin: card.previewVideoOrigin,
      videoUrlSource: card.videoUrlSource,
      skillName: card.name,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
              // 背景图层（夜间模式降低透明度）
              Positioned.fill(
                child: Image.asset(
                  bgAsset,
                  fit: BoxFit.cover,
                  opacity: AlwaysStoppedAnimation(isDark ? 0.3 : 0.6),
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
                    // 标题行：符号 + 名称 + 评级
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
                                    Shadow(color: Colors.white, blurRadius: 3),
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
                            card.name,
                            style: TextStyle(
                              color: inkColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              shadows: isDark
                                  ? null
                                  : [
                                      Shadow(
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
                          ),
                        ),
                        // 评级标签
                        if (card.tier != null &&
                            card.tier != SpellCardTier.unranked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.black : Colors.white)
                                  .withValues(alpha: 0.85),
                              border: Border.all(
                                color: _getSpellCardTierColor(card.tier!),
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              card.tier!.shortLabel,
                              style: TextStyle(
                                color: _getSpellCardTierColor(card.tier!),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                    Text(
                      card.description,
                      style: TextStyle(
                        color: inkColor,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        shadows: isDark
                            ? null
                            : [
                                Shadow(color: Colors.white, blurRadius: 4),
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

                    // 属性行（如果有任意字段）
                    if (card.cooldown != null ||
                        card.damage != null ||
                        card.cost != null ||
                        card.speed != null ||
                        card.count != null ||
                        card.angle != null ||
                        card.puncture != null ||
                        card.bounce != null ||
                        card.explode != null ||
                        card.holdTime != null ||
                        card.trackSpeed != null ||
                        card.customCd != null) ...[
                      const SizedBox(height: 10),
                      _buildSpellCardStats(card, borderColor),
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

  /// 符卡属性行
  Widget _buildSpellCardStats(SpellCard card, Color accentColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statItems = <Widget>[];

    if (card.cooldown != null) {
      statItems.add(
        _buildStatItem(
          Icons.timer_outlined,
          '冷却',
          '${_formatNumber(card.cooldown!)}s',
          CharacterGalleryTheme.getCooldownColor(context),
          isDark,
        ),
      );
    }

    if (card.damage != null) {
      statItems.add(
        _buildStatItem(
          Icons.flash_on,
          '伤害',
          card.damage!,
          CharacterGalleryTheme.getDamageColor(context),
          isDark,
        ),
      );
    }

    if (card.cost != null) {
      final isUltimate = card.type == SpellCardType.ultimate;
      statItems.add(
        _buildStatItem(
          Icons.local_fire_department,
          isUltimate ? 'B点' : 'P点',
          _formatNumber(card.cost!),
          isUltimate
              ? CharacterGalleryTheme.getBCostColor(context)
              : CharacterGalleryTheme.getPCostColor(context),
          isDark,
        ),
      );
    }

    if (card.speed != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.speedometer,
          '弹幕初速',
          _formatNumber(card.speed!),
          CharacterGalleryTheme.getSpeedColor(context),
          isDark,
        ),
      );
    }

    if (card.count != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.counter,
          '弹幕数量',
          _formatNumber(card.count!),
          CharacterGalleryTheme.getCountColor(context),
          isDark,
        ),
      );
    }

    if (card.angle != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.angleAcute,
          '散射角度',
          '${_formatNumber(card.angle!)}°',
          CharacterGalleryTheme.getAngleColor(context),
          isDark,
        ),
      );
    }

    if (card.puncture != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.arrowExpandHorizontal,
          '穿刺次数',
          _formatNumber(card.puncture!),
          CharacterGalleryTheme.getPunctureColor(context),
          isDark,
        ),
      );
    }

    if (card.bounce != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.arrowUDownLeft,
          '反弹次数',
          _formatNumber(card.bounce!),
          CharacterGalleryTheme.getBounceColor(context),
          isDark,
        ),
      );
    }

    if (card.explode != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.weatherSunny,
          '影响范围',
          _formatNumber(card.explode!),
          CharacterGalleryTheme.getExplodeColor(context),
          isDark,
        ),
      );
    }

    if (card.holdTime != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.timerSand,
          '持续时间',
          '${_formatNumber(card.holdTime!)}s',
          CharacterGalleryTheme.getHoldTimeColor(context),
          isDark,
        ),
      );
    }

    if (card.trackSpeed != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.crosshairs,
          '追踪转向',
          _formatNumber(card.trackSpeed!),
          CharacterGalleryTheme.getTrackSpeedColor(context),
          isDark,
        ),
      );
    }

    if (card.customCd != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.cog,
          '内置CD',
          '${_formatNumber(card.customCd!)}s',
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
                  Shadow(color: Colors.white, blurRadius: 3),
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
                    Shadow(color: Colors.white, blurRadius: 3),
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
                    Shadow(color: Colors.white, blurRadius: 3),
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

  /// 僵尸技能区域
  Widget _buildZombieSkillsSection(CharacterModel character) {
    final skills = character.zombieSkills ?? [];

    // 分组：被动、主动
    final passive = skills
        .where((s) => s.type == ZombieSkillType.passive)
        .toList();
    final active = skills
        .where((s) => s.type == ZombieSkillType.active)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionDivider(title: '技能系统'),
        const SizedBox(height: 12),
        if (skills.isEmpty)
          const EmptySkillHint(text: '暂无技能数据')
        else ...[
          // 被动技能
          if (passive.isNotEmpty) ...[
            _buildSpellCardGroupHeader('被动技能', const Color(0xFF4A7C59)),
            const SizedBox(height: 8),
            ...passive.map((skill) => _buildZombieSkillCard(skill)),
            const SizedBox(height: 16),
          ],
          // 主动技能
          if (active.isNotEmpty) ...[
            _buildSpellCardGroupHeader(
              '主动技能',
              CharacterGalleryTheme.getVermillion(context),
            ),
            const SizedBox(height: 8),
            ...active.map((skill) => _buildZombieSkillCard(skill)),
          ],
        ],
      ],
    );
  }

  /// 僵尸技能卡片
  Widget _buildZombieSkillCard(ZombieSkill skill) {
    final isPassive = skill.type == ZombieSkillType.passive;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);

    // 被动用绿色和被动背景，主动用朱红和大符卡背景
    final (
      Color borderColor,
      Color bgColor,
      String symbol,
      String bgAsset,
    ) = isPassive
        ? (
            const Color(0xFF4A7C59),
            const Color(0xFF4A7C59).withValues(alpha: isDark ? 0.15 : 0.08),
            '✦',
            'assets/images/character_gallery/spell_card_bg_passive.png',
          )
        : (
            vermillion,
            vermillion.withValues(alpha: isDark ? 0.12 : 0.06),
            '✧',
            'assets/images/character_gallery/spell_card_bg_ultimate.png',
          );

    return SkillPreviewIndicator(
      previewType: skill.previewType,
      previewImageUrl: skill.previewImageUrl,
      previewVideoUrl: skill.previewVideoUrl,
      previewVideoOrigin: skill.previewVideoOrigin,
      videoUrlSource: skill.videoUrlSource,
      skillName: skill.name,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
                  opacity: AlwaysStoppedAnimation(isDark ? 0.3 : 0.6),
                ),
              ),
              // 内容层
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题行
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
                                    Shadow(color: Colors.white, blurRadius: 3),
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
                            skill.name,
                            style: TextStyle(
                              color: inkColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              shadows: isDark
                                  ? null
                                  : [
                                      Shadow(
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
                          ),
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
                              borderColor.withValues(alpha: 0.4),
                              borderColor.withValues(alpha: 0.4),
                              borderColor.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.2, 0.8, 1],
                          ),
                        ),
                      ),
                    ),

                    // 描述
                    Text(
                      skill.description,
                      style: TextStyle(
                        color: inkColor,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        shadows: isDark
                            ? null
                            : [
                                Shadow(color: Colors.white, blurRadius: 4),
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
                    if (skill.cooldown != null ||
                        skill.damage != null ||
                        skill.range != null ||
                        skill.special != null) ...[
                      const SizedBox(height: 10),
                      _buildZombieSkillStats(skill, borderColor),
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

  /// 僵尸技能属性行
  Widget _buildZombieSkillStats(ZombieSkill skill, Color accentColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final statItems = <Widget>[];

    if (skill.cooldown != null) {
      statItems.add(
        _buildStatItem(
          Icons.timer_outlined,
          '冷却',
          '${_formatNumber(skill.cooldown!)}s',
          CharacterGalleryTheme.getCooldownColor(context),
          isDark,
        ),
      );
    }

    if (skill.damage != null) {
      statItems.add(
        _buildStatItem(
          Icons.flash_on,
          '伤害',
          skill.damage!,
          CharacterGalleryTheme.getDamageColor(context),
          isDark,
        ),
      );
    }

    if (skill.range != null) {
      statItems.add(
        _buildStatItem(Icons.radar, '范围', skill.range!, scrollBrown, isDark),
      );
    }

    if (skill.special != null) {
      statItems.add(
        _buildStatItem(
          Icons.auto_awesome,
          '特殊',
          skill.special!,
          CharacterGalleryTheme.getSpecialColor(context),
          isDark,
        ),
      );
    }

    return Wrap(spacing: 12, runSpacing: 6, children: statItems);
  }

  /// 刀枪图鉴列表视图（左侧列表区域）
  Widget _buildWeaponModelList(CharacterGalleryState state) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return Column(
      children: [
        // 标签页切换
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildWeaponTabButton(
                label: '刀模',
                icon: MdiIcons.knife,
                isSelected: state.weaponModelTab == 0,
                onTap: () => context.read<CharacterGalleryBloc>().add(
                  const ChangeWeaponModelTab(0),
                ),
              ),
              const SizedBox(width: 8),
              _buildWeaponTabButton(
                label: '枪模',
                icon: MdiIcons.pistol,
                isSelected: state.weaponModelTab == 1,
                onTap: () => context.read<CharacterGalleryBloc>().add(
                  const ChangeWeaponModelTab(1),
                ),
              ),
              const Spacer(),
              // 统计信息
              Text(
                '共 ${state.weaponModelTab == 0 ? state.allKnifeTotalCount : state.allGunTotalCount} 个',
                style: TextStyle(
                  color: inkColor.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: scrollBrown.withValues(alpha: 0.2)),
        // 列表内容
        Expanded(child: _buildWeaponModelListContent(state)),
      ],
    );
  }

  Widget _buildWeaponTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? vermillion : scrollBrown.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? Colors.white
                    : inkColor.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : inkColor.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeaponModelListContent(CharacterGalleryState state) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);

    if (state.allWeaponModelsLoadState == LoadState.loading) {
      return Center(child: CircularProgressIndicator(color: vermillion));
    }

    if (state.allWeaponModelsLoadState == LoadState.failure) {
      return _buildErrorState(state.error ?? '加载失败');
    }

    final items = state.weaponModelTab == 0
        ? state.allKnifeModels
        : state.allGunModels;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.weaponModelTab == 0 ? MdiIcons.knife : MdiIcons.pistol,
              size: 48,
              color: scrollBrown.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无${state.weaponModelTab == 0 ? '刀模' : '枪模'}数据',
              style: TextStyle(
                color: inkColor.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // 使用和角色列表一样的 GridView 布局
    return GridView.builder(
      controller: _listScrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        if (state.weaponModelTab == 0) {
          final knife = items[index] as KnifeModel;
          final isSelected =
              state.selectedWeaponModelId == knife.id &&
              state.selectedWeaponIsKnife;
          return WeaponModelHanafudaCard.fromKnifeModel(
            model: knife,
            isSelected: isSelected,
            onTap: () => context.read<CharacterGalleryBloc>().add(
              SelectWeaponModel(id: knife.id, isKnife: true),
            ),
          );
        } else {
          final gun = items[index] as GunModel;
          final isSelected =
              state.selectedWeaponModelId == gun.id &&
              !state.selectedWeaponIsKnife;
          return WeaponModelHanafudaCard.fromGunModel(
            model: gun,
            isSelected: isSelected,
            onTap: () => context.read<CharacterGalleryBloc>().add(
              SelectWeaponModel(id: gun.id, isKnife: false),
            ),
          );
        }
      },
    );
  }

  /// 刀模/枪模区域
  Widget _buildWeaponModelsSection(CharacterGalleryState state) {
    final knifeModels = state.knifeModels;
    final gunModels = state.gunModels;
    final isLoading = state.weaponModelsLoadState == LoadState.loading;

    // 如果没有刀模和枪模，不显示此区域
    if (!isLoading && knifeModels.isEmpty && gunModels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionDivider(title: '专属装备'),
        const SizedBox(height: 12),
        if (isLoading)
          _buildWeaponModelsLoading()
        else ...[
          // 刀模区域
          if (knifeModels.isNotEmpty) ...[
            _WeaponSectionTitle(
              title: '专属刀模',
              icon: MdiIcons.knife,
              count: knifeModels.length,
            ),
            const SizedBox(height: 10),
            _buildWeaponModelsWrap(knifeModels, true),
            const SizedBox(height: 16),
          ],
          // 枪模区域
          if (gunModels.isNotEmpty) ...[
            _WeaponSectionTitle(
              title: '专属枪模',
              icon: MdiIcons.pistol,
              count: gunModels.length,
            ),
            const SizedBox(height: 10),
            _buildWeaponModelsWrap(gunModels, false),
          ],
        ],
      ],
    );
  }

  /// 刀模/枪模加载中骨架屏
  Widget _buildWeaponModelsLoading() {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    return Container(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: CircularProgressIndicator(color: scrollBrown, strokeWidth: 2),
      ),
    );
  }

  /// 刀模/枪模 Wrap 布局
  Widget _buildWeaponModelsWrap(List<dynamic> models, bool isKnife) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: models.map((model) {
        if (isKnife) {
          final knife = model as KnifeModel;
          return SizedBox(
            height: 120,
            child: SubModelCard.fromKnifeModel(
              model: knife,
              onTap: () => context.read<CharacterGalleryBloc>().add(
                LoadWeaponModelDetailInCharacterView(
                  id: knife.id,
                  isKnife: true,
                ),
              ),
            ),
          );
        } else {
          final gun = model as GunModel;
          return SizedBox(
            height: 120,
            child: SubModelCard.fromGunModel(
              model: gun,
              onTap: () => context.read<CharacterGalleryBloc>().add(
                LoadWeaponModelDetailInCharacterView(
                  id: gun.id,
                  isKnife: false,
                ),
              ),
            ),
          );
        }
      }).toList(),
    );
  }

  Widget _buildPreviewSection(CharacterGalleryState state) {
    final previewUrl = state.currentPreviewImage;

    return Column(
      children: [
        PreviewImageCard(
          key: ValueKey(
            'preview_${state.selectedSubModelId}_${state.previewPosition}',
          ),
          imageUrl: previewUrl,
          onTap: (previewUrl != null && previewUrl.isNotEmpty)
              ? () => _showImageViewer(previewUrl, state)
              : null,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PreviewPositionButton(
              position: 0,
              label: '正',
              isSelected: state.previewPosition == 0,
              onTap: () => context.read<CharacterGalleryBloc>().add(
                ChangePreviewPosition(0),
              ),
            ),
            PreviewPositionButton(
              position: 1,
              label: '左',
              isSelected: state.previewPosition == 1,
              onTap: () => context.read<CharacterGalleryBloc>().add(
                ChangePreviewPosition(1),
              ),
            ),
            PreviewPositionButton(
              position: 2,
              label: '右',
              isSelected: state.previewPosition == 2,
              onTap: () => context.read<CharacterGalleryBloc>().add(
                ChangePreviewPosition(2),
              ),
            ),
            PreviewPositionButton(
              position: 3,
              label: '背',
              isSelected: state.previewPosition == 3,
              onTap: () => context.read<CharacterGalleryBloc>().add(
                ChangePreviewPosition(3),
              ),
            ),
            PreviewPositionButton(
              position: 4,
              label: '手',
              isSelected: state.previewPosition == 4,
              onTap: () => context.read<CharacterGalleryBloc>().add(
                ChangePreviewPosition(4),
              ),
            ),
            PreviewPositionButton(
              position: 5,
              label: '腿',
              isSelected: state.previewPosition == 5,
              onTap: () => context.read<CharacterGalleryBloc>().add(
                ChangePreviewPosition(5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showImageViewer(String imageUrl, CharacterGalleryState state) {
    // 如果传入的 imageUrl 为空，直接返回
    if (imageUrl.isEmpty) return;

    final character = state.selectedCharacter;
    final preview = state.currentSubModel?.preview ?? character?.preview;
    final allImages = <String>[];

    if (preview != null) {
      if (preview.front.isNotEmpty) allImages.add(preview.front);
      if (preview.left.isNotEmpty) allImages.add(preview.left);
      if (preview.right.isNotEmpty) allImages.add(preview.right);
      if (preview.back.isNotEmpty) allImages.add(preview.back);
      if (preview.hand.isNotEmpty) allImages.add(preview.hand);
      if (preview.leg.isNotEmpty) allImages.add(preview.leg);
    }

    // 如果没有任何有效图片，直接返回
    if (allImages.isEmpty) return;

    final initialIndex = allImages.indexOf(imageUrl);
    // 如果当前图片不在列表中，默认显示第一张
    final safeIndex = initialIndex >= 0 ? initialIndex : 0;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => CharacterImageViewerDialog(
        images: allImages,
        initialIndex: safeIndex,
        characterName: character?.name ?? '',
      ),
    );
  }

  Widget _buildNameSection(
    CharacterModel character,
    CharacterGalleryState state,
  ) {
    final currentSubModel = state.currentSubModel;
    // 如果是默认皮肤，显示角色名；否则显示子模型名
    final displayName = (currentSubModel?.isDefault ?? true)
        ? character.name
        : (currentSubModel?.name ?? character.name);

    // 获取当前子模型的来源信息
    final acquisition = currentSubModel?.acquisition ?? character.acquisition;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '◆',
          style: TextStyle(
            color: CharacterGalleryTheme.getVermillion(context),
            fontSize: 18,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Builder(
            builder: (context) {
              final inkColor = CharacterGalleryTheme.getInkColor(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: inkColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  if (character.nameEn != null)
                    Text(
                      character.nameEn!,
                      style: TextStyle(
                        color: inkColor.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        // 来源途径显示在角色名右侧
        _buildAcquisitionBadge(acquisition, character, currentSubModel),
      ],
    );
  }

  /// 来源途径徽章（显示在角色名右侧）- 日式印章风格
  /// 僵尸角色不显示获取来源
  Widget _buildAcquisitionBadge(
    AcquisitionInfo? acquisition,
    CharacterModel character,
    CharacterSubModel? currentSubModel,
  ) {
    // 僵尸角色不显示获取来源
    if (character.category == CharacterCategory.zombie) {
      return const SizedBox.shrink();
    }

    if (acquisition == null || acquisition.type == AcquisitionType.unknown) {
      return const SizedBox.shrink();
    }

    return _AcquisitionSealBadge(acquisition: acquisition);
  }

  Widget _buildSubModelSelector(CharacterGalleryState state) {
    final subModels = state.selectedCharacter!.subModels!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionDivider(title: '子模型'),
        const SizedBox(height: 12),
        _SubModelScrollableList(
          subModels: subModels,
          selectedSubModelId: state.selectedSubModelId,
          onSelect: (id) =>
              context.read<CharacterGalleryBloc>().add(SelectSubModel(id)),
        ),
      ],
    );
  }

  /// 符卡评级列表视图
  Widget _buildSpellCardTierList(CharacterGalleryState state) {
    if (state.spellCardTierLoadState == LoadState.loading) {
      return Center(
        child: CircularProgressIndicator(
          color: CharacterGalleryTheme.getVermillion(context),
        ),
      );
    }
    if (state.spellCardTierLoadState == LoadState.failure) {
      return _buildErrorState(state.error ?? '加载失败');
    }
    if (state.spellCardTierGroups.isEmpty) {
      return _buildEmptySpellCardState();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateListScrollIndicators();
    });

    final washiColor = CharacterGalleryTheme.getWashiColor(context);

    // 计算固定标题的高度（最多只有一个展开的评级）
    final pinnedHeaderHeight = state.expandedTiers.isNotEmpty ? 40.0 : 0.0;

    return Stack(
      children: [
        CustomScrollView(
          controller: _listScrollController,
          slivers: [
            const SliverPadding(padding: EdgeInsets.only(top: 8)),
            for (final tierGroup in state.spellCardTierGroups) ...[
              // 评级标题（粘性头部）
              SliverPersistentHeader(
                pinned: state.expandedTiers.contains(tierGroup.tier),
                delegate: _TierHeaderDelegate(
                  tierGroup: tierGroup,
                  isExpanded: state.expandedTiers.contains(tierGroup.tier),
                  tierColor: _getTierColor(tierGroup.tier),
                  washiColor: washiColor,
                  onTap: () {
                    context.read<CharacterGalleryBloc>().add(
                      ToggleTierExpanded(tierGroup.tier),
                    );
                  },
                ),
              ),
              // 符卡列表（仅在展开时显示）
              if (state.expandedTiers.contains(tierGroup.tier))
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildSpellCardTierItem(
                        tierGroup.spellCards[index],
                        isSelected:
                            state.selectedSpellCardId ==
                            tierGroup.spellCards[index].id,
                      ),
                      childCount: tierGroup.spellCards.length,
                    ),
                  ),
                ),
            ],
            const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
          ],
        ),
        // 上方滚动指示条（显示在固定标题下方）
        if (_listCanScrollUp)
          Positioned(
            top: pinnedHeaderHeight,
            left: 0,
            right: 0,
            child: const ScrollIndicator(isTop: true),
          ),
        if (_listCanScrollDown)
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ScrollIndicator(isTop: false),
          ),
      ],
    );
  }

  /// 符卡评级列表项
  Widget _buildSpellCardTierItem(
    SpellCardTierItem spellCard, {
    bool isSelected = false,
  }) {
    final type = spellCard.type;
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
    ) = switch (type) {
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          context.read<CharacterGalleryBloc>().add(
            NavigateToCharacterFromSpellCard(
              spellCardId: spellCard.id,
              characterId: spellCard.characterId,
              subModelId: spellCard.subModelId,
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          constraints: const BoxConstraints(minHeight: 80),
          decoration: BoxDecoration(
            color: isSelected ? borderColor.withValues(alpha: 0.12) : bgColor,
            border: Border.all(
              color: isSelected
                  ? borderColor
                  : borderColor.withValues(alpha: 0.8),
              width: isSelected ? 2 : 1.5,
            ),
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
                    opacity: AlwaysStoppedAnimation(
                      isDark
                          ? (isSelected ? 0.4 : 0.3)
                          : (isSelected ? 0.7 : 0.5),
                    ),
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
                      // 标题行：符号 + 名称 + 评级 + 箭头
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
                                      Shadow(
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
                                        Shadow(
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
                            color: isSelected
                                ? borderColor
                                : scrollBrown.withValues(alpha: 0.6),
                            shadows: isDark
                                ? null
                                : [
                                    Shadow(color: Colors.white, blurRadius: 3),
                                    Shadow(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
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
                        Builder(
                          builder: (context) {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final inkColor = CharacterGalleryTheme.getInkColor(
                              context,
                            );
                            return Text(
                              spellCard.description!,
                              style: TextStyle(
                                color: inkColor,
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                shadows: isDark
                                    ? null
                                    : [
                                        Shadow(
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
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
                        _buildTierItemStats(spellCard, borderColor),
                      ],
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

  /// 评级列表项属性行
  Widget _buildTierItemStats(SpellCardTierItem spellCard, Color accentColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

    if (spellCard.damage != null) {
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
          MdiIcons.speedometer,
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
          MdiIcons.counter,
          '弹幕数量',
          _formatNumber(spellCard.count!),
          CharacterGalleryTheme.getCountColor(context),
          isDark,
        ),
      );
    }

    if (spellCard.angle != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.angleAcute,
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
          MdiIcons.arrowExpandHorizontal,
          '穿刺次数',
          _formatNumber(spellCard.puncture!),
          CharacterGalleryTheme.getPunctureColor(context),
          isDark,
        ),
      );
    }

    if (spellCard.bounce != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.arrowUDownLeft,
          '反弹次数',
          _formatNumber(spellCard.bounce!),
          CharacterGalleryTheme.getBounceColor(context),
          isDark,
        ),
      );
    }

    if (spellCard.explode != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.weatherSunny,
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
          MdiIcons.timerSand,
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
          MdiIcons.crosshairs,
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
          MdiIcons.cog,
          '内置CD',
          '${_formatNumber(spellCard.customCd!)}s',
          CharacterGalleryTheme.getCustomCdColor(context),
          isDark,
        ),
      );
    }

    return Wrap(spacing: 12, runSpacing: 6, children: statItems);
  }

  /// 获取评级颜色
  Color _getTierColor(String tier) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    return switch (tier) {
      'T0' => const Color(0xFFFF4444), // 红色 - 最强
      'T1' => const Color(0xFFFF8800), // 橙色 - 强力
      'T2' => const Color(0xFFFFCC00), // 金色 - 优秀
      'T3' => const Color(0xFF44BB44), // 绿色 - 中等
      'T4' => const Color(0xFF4488FF), // 蓝色 - 一般
      'T5' => const Color(0xFF8888AA), // 灰蓝 - 较弱
      'unranked' => scrollBrown, // 棕色 - 未评级
      _ => scrollBrown,
    };
  }

  /// 获取符卡评级颜色（枚举版本）
  Color _getSpellCardTierColor(SpellCardTier tier) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    return switch (tier) {
      SpellCardTier.t0 => const Color(0xFFFF4444),
      SpellCardTier.t1 => const Color(0xFFFF8800),
      SpellCardTier.t2 => const Color(0xFFFFCC00),
      SpellCardTier.t3 => const Color(0xFF44BB44),
      SpellCardTier.t4 => const Color(0xFF4488FF),
      SpellCardTier.t5 => const Color(0xFF8888AA),
      SpellCardTier.unranked => scrollBrown,
    };
  }

  /// 空符卡状态
  Widget _buildEmptySpellCardState() {
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎴', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            '暂无符卡数据',
            style: TextStyle(
              color: inkColor.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📜', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            '暂无角色数据',
            style: TextStyle(
              color: inkColor.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            error,
            style: TextStyle(
              color: inkColor.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.read<CharacterGalleryBloc>().add(
              const LoadCharacters(),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: CharacterGalleryTheme.getVermillion(context),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '重试',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 日式印章风格的获取途径徽章
class _AcquisitionSealBadge extends StatelessWidget {
  final AcquisitionInfo acquisition;

  const _AcquisitionSealBadge({required this.acquisition});

  @override
  Widget build(BuildContext context) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final gold = CharacterGalleryTheme.getGold(context);

    final (label, subLabel, color) = switch (acquisition.type) {
      AcquisitionType.gold => ('金', '${acquisition.cost ?? 0}', gold),
      AcquisitionType.points => ('点', '${acquisition.cost ?? 0}', vermillion),
      AcquisitionType.custom => (
        '特',
        acquisition.customSource ?? '活动',
        const Color(0xFF4A7C59),
      ),
      _ => ('？', '未知', scrollBrown),
    };

    // 自定义来源使用横向布局
    if (acquisition.type == AcquisitionType.custom) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 80),
              child: Text(
                subLabel,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // 金/点使用印章风格
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: washiColor,
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subLabel,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 子模型可滚动列表（hover 时浮动显示滚动按钮）
class _SubModelScrollableList extends StatefulWidget {
  final List<CharacterSubModel> subModels;
  final int? selectedSubModelId;
  final ValueChanged<int> onSelect;

  const _SubModelScrollableList({
    required this.subModels,
    required this.selectedSubModelId,
    required this.onSelect,
  });

  @override
  State<_SubModelScrollableList> createState() =>
      _SubModelScrollableListState();
}

class _SubModelScrollableListState extends State<_SubModelScrollableList> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  bool _isHovered = false;

  // 每个子模型卡片的宽度（包含间距）
  static const double _itemWidth = 100.0; // 卡片宽度
  static const double _itemSpacing = 12.0; // 间距

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollState();
      _scrollToSelectedItem();
    });
  }

  @override
  void didUpdateWidget(covariant _SubModelScrollableList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当选中的子模型变化时，不滚动（保持当前位置）
    // 只在初始化时滚动到选中项
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollState);
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动到选中的子模型位置
  void _scrollToSelectedItem() {
    if (!_scrollController.hasClients) return;

    final selectedIndex = widget.subModels.indexWhere(
      (s) =>
          s.id == widget.selectedSubModelId ||
          (widget.selectedSubModelId == null && s.isDefault),
    );

    if (selectedIndex <= 0) return; // 第一个不需要滚动

    // 计算目标偏移量，让选中项尽量居中显示
    final itemOffset = selectedIndex * (_itemWidth + _itemSpacing);
    final viewportWidth = _scrollController.position.viewportDimension;
    final targetOffset = (itemOffset - (viewportWidth - _itemWidth) / 2).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _updateScrollState() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canLeft = position.pixels > 0;
    final canRight = position.pixels < position.maxScrollExtent;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scrollLeft() {
    final newOffset = (_scrollController.offset - 200).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollRight() {
    final newOffset = (_scrollController.offset + 200).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: SizedBox(
        height: 140,
        child: Stack(
          children: [
            // 列表
            ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: widget.subModels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final subModel = widget.subModels[index];
                final isSelected =
                    widget.selectedSubModelId == subModel.id ||
                    (widget.selectedSubModelId == null && subModel.isDefault);
                return SubModelCard.fromSubModel(
                  subModel: subModel,
                  isSelected: isSelected,
                  onTap: () => widget.onSelect(subModel.id),
                );
              },
            ),
            // 左滚动按钮（浮动）
            if (_canScrollLeft)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _buildFloatingScrollButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: _scrollLeft,
                  isLeft: true,
                ),
              ),
            // 右滚动按钮（浮动）
            if (_canScrollRight)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: _buildFloatingScrollButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: _scrollRight,
                  isLeft: false,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingScrollButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isLeft,
  }) {
    return Builder(
      builder: (context) {
        final washiColor = CharacterGalleryTheme.getWashiColor(context);
        final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
        final inkColor = CharacterGalleryTheme.getInkColor(context);

        return AnimatedOpacity(
          opacity: _isHovered ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_isHovered,
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
                  end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
                  colors: [
                    washiColor,
                    washiColor.withValues(alpha: 0.9),
                    washiColor.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
              child: Align(
                alignment: isLeft
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: isLeft ? 4 : 0,
                    right: isLeft ? 0 : 4,
                  ),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: onTap,
                      child: Container(
                        width: 28,
                        height: 48,
                        decoration: BoxDecoration(
                          color: washiColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: scrollBrown.withValues(alpha: 0.4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: inkColor.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(icon, size: 20, color: scrollBrown),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 评级标题粘性头部代理
class _TierHeaderDelegate extends SliverPersistentHeaderDelegate {
  final SpellCardTierGroup tierGroup;
  final bool isExpanded;
  final Color tierColor;
  final Color washiColor;
  final VoidCallback onTap;

  _TierHeaderDelegate({
    required this.tierGroup,
    required this.isExpanded,
    required this.tierColor,
    required this.washiColor,
    required this.onTap,
  });

  @override
  double get minExtent => 40;

  @override
  double get maxExtent => 40;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // 当头部被固定时（shrinkOffset > 0 或 overlapsContent），显示阴影
    final isPinned = shrinkOffset > 0 || overlapsContent;

    return SizedBox(
      height: maxExtent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isPinned ? washiColor : tierColor.withValues(alpha: 0.1),
                border: Border(left: BorderSide(color: tierColor, width: 3)),
                boxShadow: isPinned
                    ? [
                        BoxShadow(
                          color: tierColor.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  // 展开/折叠图标
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: tierColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tierGroup.tierLabel,
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${tierGroup.count}',
                      style: TextStyle(
                        color: tierColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 折叠提示或固定提示
                  if (!isExpanded)
                    Text(
                      '点击展开',
                      style: TextStyle(
                        color: tierColor.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    )
                  else if (isPinned)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.push_pin,
                          size: 12,
                          color: tierColor.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '点击收起',
                          style: TextStyle(
                            color: tierColor.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TierHeaderDelegate oldDelegate) {
    return tierGroup != oldDelegate.tierGroup ||
        isExpanded != oldDelegate.isExpanded ||
        tierColor != oldDelegate.tierColor ||
        washiColor != oldDelegate.washiColor;
  }
}

/// 刀模/枪模区域标题
class _WeaponSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;

  const _WeaponSectionTitle({
    required this.title,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: scrollBrown),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: inkColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: scrollBrown.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: scrollBrown,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// 专属角色卡片（用于刀枪模详情页面，参照 SubModelCard 的样式）
class _ExclusiveCharacterCard extends StatefulWidget {
  final int characterId;
  final String characterName;
  final String? characterThumbnailUrl;
  final AcquisitionInfo? characterAcquisition;
  final bool isLoading;
  final VoidCallback onTap;

  const _ExclusiveCharacterCard({
    required this.characterId,
    required this.characterName,
    this.characterThumbnailUrl,
    this.characterAcquisition,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  State<_ExclusiveCharacterCard> createState() =>
      _ExclusiveCharacterCardState();
}

class _ExclusiveCharacterCardState extends State<_ExclusiveCharacterCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final cardBg = CharacterGalleryTheme.getOverlayColor(context, alpha: 0.5);

    final borderColor = _isHovered
        ? scrollBrown
        : scrollBrown.withValues(alpha: 0.4);
    final borderWidth = _isHovered ? 1.5 : 1.0;
    final elevation = _isHovered ? 2.0 : 0.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 90,
          decoration: BoxDecoration(
            color: _isHovered ? washiColor : cardBg,
            border: Border.all(color: borderColor, width: borderWidth),
            borderRadius: BorderRadius.circular(8),
            boxShadow: elevation > 0
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: elevation * 2,
                      offset: Offset(0, elevation / 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              // 缩略图
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                  child: widget.isLoading
                      ? Container(
                          color: scrollBrown.withValues(alpha: 0.1),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: CharacterGalleryTheme.getVermillion(
                                  context,
                                ),
                              ),
                            ),
                          ),
                        )
                      : widget.characterThumbnailUrl != null &&
                            widget.characterThumbnailUrl!.isNotEmpty
                      ? DiskCachedImage(
                          imageUrl: widget.characterThumbnailUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : Container(
                          color: scrollBrown.withValues(alpha: 0.1),
                          child: Center(
                            child: Icon(
                              Icons.person_rounded,
                              color: _isHovered
                                  ? CharacterGalleryTheme.getVermillion(context)
                                  : scrollBrown.withValues(alpha: 0.4),
                              size: 32,
                            ),
                          ),
                        ),
                ),
              ),
              // 名称和获取途径
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(7),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.characterName,
                      style: TextStyle(
                        color: inkColor,
                        fontSize: 11,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    widget.isLoading
                        ? Text(
                            '加载中...',
                            style: TextStyle(
                              color: inkColor.withValues(alpha: 0.5),
                              fontSize: 9,
                            ),
                          )
                        : _CharacterAcquisitionTag(
                            acquisition: widget.characterAcquisition,
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 角色获取途径标签（紧凑版，和 SubModelCard 一样）
class _CharacterAcquisitionTag extends StatelessWidget {
  final AcquisitionInfo? acquisition;

  const _CharacterAcquisitionTag({this.acquisition});

  @override
  Widget build(BuildContext context) {
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    final (
      text,
      color,
    ) = acquisition == null || acquisition!.type == AcquisitionType.unknown
        ? ('未知', inkColor.withValues(alpha: 0.5))
        : switch (acquisition!.type) {
            AcquisitionType.gold => (
              '${acquisition!.cost ?? 0} 金',
              CharacterGalleryTheme.getGold(context),
            ),
            AcquisitionType.points => (
              '${acquisition!.cost ?? 0} 点',
              CharacterGalleryTheme.getVermillion(context),
            ),
            AcquisitionType.custom => (
              acquisition!.customSource ?? '特殊',
              CharacterGalleryTheme.getCustomSourceColor(context),
            ),
            AcquisitionType.unknown => ('未知', inkColor.withValues(alpha: 0.5)),
          };
    return Text(
      text,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w500),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }
}
