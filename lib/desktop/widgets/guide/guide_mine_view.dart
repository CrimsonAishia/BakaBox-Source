import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/bloc/guide_mine/guide_mine_bloc.dart';
import '../../../core/bloc/guide_mine/guide_mine_event.dart';
import '../../../core/bloc/guide_mine/guide_mine_state.dart';
import '../../../core/models/guide_models.dart';
import 'community_guide/community_guide_format.dart';
import 'community_guide/community_guide_shimmer.dart';
import 'community_guide/community_guide_skeleton_grid.dart';
import 'community_guide/community_guide_theme.dart';
import 'guide_mine/guide_mine.dart';

/// 我的中心（攻略）— 桌面端
///
/// 风格与 [CommunityGuideScreen] 保持一致：自适应主题（亮/暗）+ 蓝色强调 + 卡片栅格。
///
/// 内部组件已拆分到 `lib/desktop/widgets/guide/guide_mine/` 目录下：
/// - [GuideMineHeader]：标题 / 返回 / 个人资料卡 / 工具栏
/// - [GuideMineToolbar]：Tab 胶囊 + 新建按钮
/// - [GuideMineCard]：攻略卡片（带状态角标 / 三点菜单）
/// - [GuideMineDraftCard]：草稿卡片
/// - [GuideMineCardSkeleton]：骨架
/// - [GuideMineEmptyState] / [GuideMineErrorState]：状态
class GuideMineView extends StatefulWidget {
  final int? initialTab;

  /// 「发布成功」信号（计数器）。
  ///
  /// 由宿主在「编辑器发布/修改成功 → 跳转我的中心」时自增。值变化时说明后端
  /// 数据已更新（草稿被删、已发布攻略内容或状态变化等），需刷新当前列表。
  final int publishSignal;

  /// 点击草稿项时的回调，传入 draftId
  final void Function(String draftId)? onEditDraft;

  /// 点击已发布攻略进入编辑器时的回调，传入 guideId
  final void Function(int guideId)? onEditGuide;

  /// 点击「新建攻略」回调
  final VoidCallback? onCreateGuide;

  /// 点击列表项查看详情的回调
  final void Function(int id)? onViewDetail;

  /// 点击返回（回到攻略列表主页）
  final VoidCallback? onBack;

  const GuideMineView({
    super.key,
    this.initialTab,
    this.publishSignal = 0,
    this.onEditDraft,
    this.onEditGuide,
    this.onCreateGuide,
    this.onViewDetail,
    this.onBack,
  });

  @override
  State<GuideMineView> createState() => GuideMineViewState();
}

class GuideMineViewState extends State<GuideMineView> {
  late final GuideMineBloc _bloc;
  final ScrollController _scrollController = ScrollController();

  static const _tabs = MineTab.values;

  /// Tab 数量缓存（保证切 tab 时其它 tab 的徽标不被清零）
  final Map<MineTab, int> _tabCounts = {};

  late int _selectedTabIndex;

  /// Published Tab 的状态下拉锚点 key
  final GlobalKey _publishedPillKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTab?.clamp(0, _tabs.length - 1) ?? 0;
    _bloc = GuideMineBloc();
    _bloc.add(ChangeTab(_tabs[_selectedTabIndex]));
    _bloc.add(const LoadMineStats());
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant GuideMineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 宿主在「发布/修改成功 → 我的中心」时自增 publishSignal，刷新当前列表，
    // 同步后端最新数据（草稿删除、已发布攻略内容 / 状态更新等）。
    if (widget.publishSignal != oldWidget.publishSignal) {
      _bloc.add(const ReloadCurrentList());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _bloc.add(const LoadMore());
    }
  }

  void _selectTab(int index) {
    if (index == _selectedTabIndex) return;
    setState(() => _selectedTabIndex = index);
    _bloc.add(ChangeTab(_tabs[index]));
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  /// 打开「已发布」Tab 的状态下拉筛选菜单
  Future<void> _openPublishedFilterMenu(GuideMineState state) async {
    final ctx = _publishedPillKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay = Overlay.of(ctx).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final colors = CommunityGuideColors.of(ctx);
    final topLeft = box.localToGlobal(
      box.size.bottomLeft(Offset.zero),
      ancestor: overlay,
    );
    final position = RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy + 6,
      overlay.size.width - topLeft.dx - 200,
      0,
    );

    final filters = <(String, GuideStatus?)>[
      ('全部', null),
      ('待审核', GuideStatus.pending),
      ('已发布', GuideStatus.published),
      ('已驳回', GuideStatus.rejected),
      ('已下架', GuideStatus.offShelf),
    ];

    // 用包装类型区分「用户取消（result == null）」和「选择全部（result.value == null）」。
    // showMenu 在点击遮罩取消时也返回 null，否则会把「取消」误当成「切到全部」。
    final result = await showMenu<_StatusFilterChoice>(
      context: ctx,
      position: position,
      color: colors.menuBg,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.toolbarBorder),
      ),
      constraints: const BoxConstraints(minWidth: 168),
      items: filters.map((f) {
        final isCurrent = state.statusFilter == f.$2;
        return PopupMenuItem<_StatusFilterChoice>(
          value: _StatusFilterChoice(f.$2),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  f.$1,
                  style: TextStyle(
                    color: isCurrent ? colors.accentBlue : colors.textPrimary,
                    fontSize: 13,
                    fontWeight:
                        isCurrent ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isCurrent)
                Icon(Icons.check, size: 16, color: colors.accentBlue),
            ],
          ),
        );
      }).toList(),
    );

    if (!mounted) return;
    if (result == null) return; // 用户取消，保持当前筛选
    if (result.value == _bloc.state.statusFilter) return; // 与现状一致，跳过
    _bloc.add(ChangeStatusFilter(result.value));
  }

  void _confirmDeleteDraft(BuildContext context, GuideDraft draft) {
    final colors = CommunityGuideColors.of(context);
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除草稿'),
        content: Text(
          '确定删除草稿「${(draft.title?.isNotEmpty ?? false) ? draft.title! : "无标题"}」吗？此操作不可撤销。',
        ),
        backgroundColor: colors.cardBg,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        _bloc.add(DeleteDraft(draft.draftId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: colors.scaffoldBg,
        body: BlocConsumer<GuideMineBloc, GuideMineState>(
          listenWhen: (a, b) => a.total != b.total || a.tab != b.tab,
          listener: (context, state) {
            // 缓存当前 tab 的总数，便于其它 tab 仍能显示历史徽标
            if (state.status == GuideMineStatus.success ||
                state.status == GuideMineStatus.loadingMore) {
              _tabCounts[state.tab] = state.total;
            }
          },
          builder: (context, state) {
            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: GuideMineHeader(
                    state: state,
                    onBack: widget.onBack,
                    onCreateGuide: widget.onCreateGuide,
                    selectedTabIndex: _selectedTabIndex,
                    onSelectTab: _selectTab,
                    publishedPillKey: _publishedPillKey,
                    onOpenPublishedFilter: () =>
                        _openPublishedFilterMenu(state),
                    tabCounts: _tabCounts,
                  ),
                ),
                ..._buildBodySlivers(state),
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── Body slivers ────────────────────────────────────────────────────────

  List<Widget> _buildBodySlivers(GuideMineState state) {
    if (state.status == GuideMineStatus.failure &&
        state.items.isEmpty &&
        state.drafts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: GuideMineErrorState(
            error: state.error,
            onRetry: () => _bloc.add(ChangeTab(state.tab)),
          ),
        ),
      ];
    }

    if (state.tab == MineTab.drafts) {
      return _buildDraftsSlivers(state);
    }

    return _buildGridSlivers(state);
  }

  // ─── 卡片瀑布流 ──────────────────────────────────────────────────────────

  List<Widget> _buildGridSlivers(GuideMineState state) {
    if ((state.status == GuideMineStatus.initial ||
            state.status == GuideMineStatus.loading) &&
        state.items.isEmpty) {
      return [
        _buildSkeletonGrid(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          count: 8,
        ),
      ];
    }

    if (state.items.isEmpty && state.status == GuideMineStatus.success) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: GuideMineEmptyState(tab: state.tab),
        ),
      ];
    }

    final result = <Widget>[];
    // showEdit 仅 published Tab 显示修改入口
    final showEdit = state.tab == MineTab.published;
    final isTrash = state.tab == MineTab.trash;
    final crossCount = guideCrossAxisCount(MediaQuery.of(context).size.width);

    result.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        sliver: SliverMasonryGrid.count(
          // 用 tab 名作为 key 的一部分，切 tab 时让 sliver 重置布局缓存，
          // 避免 estimatedMaxScrollOffset 与新 items 的实际尺寸错配触发断言。
          key: ValueKey('mine_grid_${state.tab.name}'),
          crossAxisCount: crossCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childCount: state.items.length,
          itemBuilder: (context, index) {
            final item = state.items[index];
            // 注意：不要在 SliverMasonryGrid 内部用 AnimateIfVisible，
            // 它会在子项进入视口时改变高度，导致 SliverMasonryGrid
            // 的 estimatedMaxScrollOffset 与已布局子项 endScrollOffset
            // 失配（line 624 断言）。瀑布流需要稳定的子项尺寸。
            return GuideMineCard(
              key: ValueKey('mine_card_${state.tab.name}_${item.id}'),
              item: item,
              showExpiryBadge: isTrash,
              onTap: () => widget.onViewDetail?.call(item.id),
              onEdit: showEdit &&
                      (item.status == GuideStatus.published ||
                          item.status == GuideStatus.rejected ||
                          item.status == GuideStatus.pending)
                  ? () => widget.onEditGuide?.call(item.id)
                  : null,
              onDelete: isTrash ? null : () => _bloc.add(DeleteGuide(item.id)),
              onRestore: isTrash ? () => _bloc.add(RestoreGuide(item.id)) : null,
            );
          },
        ),
      ),
    );

    if (state.status == GuideMineStatus.loadingMore) {
      result.add(_buildSkeletonGrid(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        count: 4,
      ));
    }

    if (!state.hasMore && state.items.isNotEmpty) {
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

  // ─── 草稿列表 ────────────────────────────────────────────────────────────

  List<Widget> _buildDraftsSlivers(GuideMineState state) {
    if ((state.status == GuideMineStatus.initial ||
            state.status == GuideMineStatus.loading) &&
        state.drafts.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: CommunityGuideShimmer(
                    child: GuideMineDraftCardSkeleton(),
                  ),
                );
              },
              childCount: 6,
            ),
          ),
        ),
      ];
    }

    if (state.drafts.isEmpty && state.status == GuideMineStatus.success) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: GuideMineEmptyState(tab: MineTab.drafts),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final draft = state.drafts[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GuideMineDraftCard(
                  draft: draft,
                  onTap: () => widget.onEditDraft?.call(draft.draftId),
                  onDelete: () => _confirmDeleteDraft(context, draft),
                ),
              );
            },
            childCount: state.drafts.length,
          ),
        ),
      ),
    ];
  }

  // ─── helpers ────────────────────────────────────────────────────────────

  Widget _buildSkeletonGrid({
    required EdgeInsets padding,
    required int count,
  }) {
    final crossCount = guideCrossAxisCount(MediaQuery.of(context).size.width);
    return CommunityGuideSkeletonGrid(
      crossCount: crossCount,
      padding: padding,
      count: count,
      skeletonBuilder: (_) => const GuideMineCardSkeleton(),
    );
  }
}

/// 已发布筛选菜单的选择结果包装。
///
/// 用包装类型把「用户取消（showMenu 返回 null）」与「选择了『全部』（value 为
/// null 的合法 GuideStatus?）」区分开。如果直接用 GuideStatus? 作菜单泛型，
/// 这两种情况都会得到 null，导致点遮罩取消会被当作切换到「全部」。
class _StatusFilterChoice {
  final GuideStatus? value;
  const _StatusFilterChoice(this.value);
}
