import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/api.dart';
import '../../api/guide_api.dart';
import '../../utils/error_utils.dart';
import '../../utils/log_service.dart';
import 'guide_mine_event.dart';
import 'guide_mine_state.dart';

/// 首屏 / Tab 切换 / 状态筛选的最小展示时长。
///
/// 防止接口过快返回时骨架屏一闪而过，也能压平连续切换 Tab 时的反馈节奏。
/// 仅对 page=1 的加载生效，分页加载更多不受影响。
const _minLoadingDuration = Duration(milliseconds: 600);

/// 我的中心 Bloc
///
/// 管理「已发布 / 草稿箱 / 我的收藏 / 我赞过的 / 回收站」五个 Tab 的分页数据。
class GuideMineBloc extends Bloc<GuideMineEvent, GuideMineState> {
  final GuideApi _guideApi = GuideApi();
  static const int _pageSize = 10;

  GuideMineBloc() : super(const GuideMineState()) {
    on<ChangeTab>(_onChangeTab);
    on<ChangeStatusFilter>(_onChangeStatusFilter);
    on<LoadMore>(_onLoadMore);
    on<LoadMineStats>(_onLoadMineStats);
    on<DeleteDraft>(_onDeleteDraft);
    on<ReloadCurrentList>(_onReloadCurrentList);
    on<DeleteGuide>(_onDeleteGuide);
    on<RestoreGuide>(_onRestoreGuide);
    on<PublishGuide>(_onPublishGuide);
  }

  /// 提取错误信息
  String _getErrorMessage(Object e) {
    if (e is ApiException) return e.message;
    return ErrorUtils.getErrorMessage(e);
  }

  // ─── 事件处理 ─────────────────────────────────────────────────────────────

  Future<void> _onChangeTab(
    ChangeTab event,
    Emitter<GuideMineState> emit,
  ) async {
    // 切换 Tab 时重置列表/分页状态，但保留 stats（属于用户全局概览）
    emit(
      GuideMineState(
        tab: event.tab,
        status: GuideMineStatus.loading,
        stats: state.stats,
      ),
    );
    await _loadPage(emit, page: 1);
  }

  Future<void> _onChangeStatusFilter(
    ChangeStatusFilter event,
    Emitter<GuideMineState> emit,
  ) async {
    // 仅 published Tab 使用状态筛选
    if (state.tab != MineTab.published) return;

    emit(
      state.copyWith(
        statusFilter: event.status,
        clearStatusFilter: event.status == null,
        status: GuideMineStatus.loading,
        items: const [],
        currentPage: 1,
        clearError: true,
      ),
    );
    await _loadPage(emit, page: 1);
  }

  Future<void> _onLoadMore(LoadMore event, Emitter<GuideMineState> emit) async {
    if (!state.canLoadMore) return;

    emit(state.copyWith(status: GuideMineStatus.loadingMore, clearError: true));
    await _loadPage(emit, page: state.currentPage + 1);
  }

  Future<void> _onLoadMineStats(
    LoadMineStats event,
    Emitter<GuideMineState> emit,
  ) async {
    try {
      final stats = await _guideApi.getMineStats();
      emit(state.copyWith(stats: stats));
    } catch (e) {
      // stats 加载失败不阻塞 UI，静默记录日志
      LogService.w('我的中心统计加载失败: ${_getErrorMessage(e)}');
    }
  }

  Future<void> _onDeleteDraft(
    DeleteDraft event,
    Emitter<GuideMineState> emit,
  ) async {
    try {
      await _guideApi.deleteDraft(event.draftId);
      // 从本地列表移除
      final updatedDrafts = state.drafts
          .where((d) => d.draftId != event.draftId)
          .toList();
      final newTotal = state.total - 1;
      final hasMore = updatedDrafts.length < newTotal;
      emit(
        state.copyWith(
          drafts: updatedDrafts,
          total: newTotal,
          hasMore: hasMore,
        ),
      );
      // 删除后如果还有更多数据，自动补加载下一页
      if (hasMore && updatedDrafts.length < _pageSize) {
        await _loadDrafts(emit, page: state.currentPage + 1);
      }
    } catch (e) {
      LogService.e('删除草稿失败', e);
      emit(state.copyWith(error: _getErrorMessage(e)));
    }
  }

  /// 发布成功后重新加载当前列表（第一页）并刷新统计。
  ///
  /// 仅当当前 Tab 会被发布影响时才刷新：草稿箱（草稿被删）与已发布（新攻略出现 /
  /// 内容或状态更新）。其它 Tab（收藏 / 点赞 / 回收站）与发布无关，跳过以免无谓
  /// 刷新。统计概览始终刷新，因为攻略数等会随发布变化。
  ///
  /// 复用现有的加载逻辑：草稿 Tab 走 _loadDrafts，其它 Tab 走 _loadItems。
  /// 先清空当前列表并置为 loading，使骨架屏（刷新特效）显示出来——否则列表已有
  /// 旧数据时不会进入骨架分支，用户感知不到刷新。拉到新数据后再 emit success。
  /// 正在加载中则跳过，避免与进行中的请求竞争。
  Future<void> _onReloadCurrentList(
    ReloadCurrentList event,
    Emitter<GuideMineState> emit,
  ) async {
    // 统计概览与具体 Tab 无关，始终刷新。
    add(const LoadMineStats());

    // 仅草稿箱 / 已发布会被发布影响，其它 Tab 不刷新列表。
    if (state.tab != MineTab.drafts && state.tab != MineTab.published) {
      return;
    }
    if (state.status == GuideMineStatus.loading ||
        state.status == GuideMineStatus.loadingMore) {
      return;
    }
    emit(
      state.copyWith(
        status: GuideMineStatus.loading,
        items: const [],
        drafts: const [],
        currentPage: 1,
        clearError: true,
      ),
    );
    await _loadPage(emit, page: 1);
  }

  Future<void> _onDeleteGuide(
    DeleteGuide event,
    Emitter<GuideMineState> emit,
  ) async {
    try {
      await _guideApi.deleteGuide(event.guideId);
      // 从本地列表移除
      final updatedItems = state.items
          .where((i) => i.id != event.guideId)
          .toList();
      final newTotal = state.total - 1;
      final hasMore = updatedItems.length < newTotal;
      emit(
        state.copyWith(items: updatedItems, total: newTotal, hasMore: hasMore),
      );
      // 删除会改变「攻略数 / 回收站」等概览，刷新统计
      add(const LoadMineStats());
    } catch (e) {
      LogService.e('删除攻略失败', e);
      emit(state.copyWith(error: _getErrorMessage(e)));
    }
  }

  Future<void> _onRestoreGuide(
    RestoreGuide event,
    Emitter<GuideMineState> emit,
  ) async {
    try {
      await _guideApi.restoreGuide(event.guideId);
      // 从回收站列表移除
      final updatedItems = state.items
          .where((i) => i.id != event.guideId)
          .toList();
      final newTotal = state.total - 1;
      final hasMore = updatedItems.length < newTotal;
      emit(
        state.copyWith(items: updatedItems, total: newTotal, hasMore: hasMore),
      );
      // 还原会改变「攻略数 / 回收站」等概览，刷新统计
      add(const LoadMineStats());
    } catch (e) {
      LogService.e('还原攻略失败', e);
      emit(state.copyWith(error: _getErrorMessage(e)));
    }
  }

  // ─── 加载逻辑 ─────────────────────────────────────────────────────────────

  /// 上架攻略：重新发布已下架的攻略。
  ///
  /// 发布后状态会进入「待审核」(pending)，与编辑器发布行为一致。直接重新拉取
  /// 当前列表第一页，让卡片状态角标 / 可用操作随新状态刷新，同时同步统计概览。
  Future<void> _onPublishGuide(
    PublishGuide event,
    Emitter<GuideMineState> emit,
  ) async {
    try {
      await _guideApi.publishGuide(event.guideId);
      add(const LoadMineStats());
      add(const ReloadCurrentList());
    } catch (e) {
      LogService.e('上架攻略失败', e);
      emit(state.copyWith(error: _getErrorMessage(e)));
    }
  }

  /// 根据当前 tab 调用对应 API 加载数据
  Future<void> _loadPage(
    Emitter<GuideMineState> emit, {
    required int page,
  }) async {
    final stopwatch = page == 1 ? (Stopwatch()..start()) : null;
    try {
      if (state.tab == MineTab.drafts) {
        await _loadDrafts(emit, page: page, stopwatch: stopwatch);
      } else {
        await _loadItems(emit, page: page, stopwatch: stopwatch);
      }
    } catch (e) {
      // 首屏失败也补足最小时长，保持 UI 节奏一致
      if (stopwatch != null) {
        final remaining = _minLoadingDuration - stopwatch.elapsed;
        if (remaining > Duration.zero) {
          await Future.delayed(remaining);
        }
      }
      emit(
        state.copyWith(
          status: GuideMineStatus.failure,
          error: _getErrorMessage(e),
        ),
      );
      LogService.e('我的中心加载失败 [${state.tab.name}]', e);
    }
  }

  /// 等待最小加载时长结束（[stopwatch] 为 null 时立即返回）
  Future<void> _waitMinDuration(Stopwatch? stopwatch) async {
    if (stopwatch == null) return;
    final remaining = _minLoadingDuration - stopwatch.elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  /// 加载草稿（分页）
  Future<void> _loadDrafts(
    Emitter<GuideMineState> emit, {
    required int page,
    Stopwatch? stopwatch,
  }) async {
    final response = await _guideApi.getDrafts(page: page, pageSize: _pageSize);
    await _waitMinDuration(stopwatch);
    final isReset = page == 1;
    final newDrafts = isReset
        ? response.items
        : [...state.drafts, ...response.items];

    emit(
      state.copyWith(
        status: GuideMineStatus.success,
        drafts: newDrafts,
        items: const [],
        total: response.total,
        hasMore: newDrafts.length < response.total,
        currentPage: page,
      ),
    );
  }

  /// 加载分页列表（published / favorites / liked / trash）
  Future<void> _loadItems(
    Emitter<GuideMineState> emit, {
    required int page,
    Stopwatch? stopwatch,
  }) async {
    final response = await _fetchResponse(page: page);
    await _waitMinDuration(stopwatch);
    final isReset = page == 1;
    final newItems = isReset
        ? response.items
        : [...state.items, ...response.items];

    emit(
      state.copyWith(
        status: GuideMineStatus.success,
        items: newItems,
        drafts: const [],
        total: response.total,
        hasMore: newItems.length < response.total,
        currentPage: page,
      ),
    );
  }

  /// 根据当前 Tab 分发到对应的 API 调用
  Future<GuideListResponse> _fetchResponse({required int page}) async {
    switch (state.tab) {
      case MineTab.published:
        return await _guideApi.getMine(
          query: GuideMineQuery(
            page: page,
            pageSize: _pageSize,
            status: state.statusFilter,
          ),
        );

      case MineTab.favorites:
        return await _guideApi.getFavorites(page: page, pageSize: _pageSize);

      case MineTab.liked:
        return await _guideApi.getLiked(page: page, pageSize: _pageSize);

      case MineTab.trash:
        // 回收站：后端新逻辑用 onlyDeleted 过滤（deletedAt 非空），
        // 不再用 status=deleted。返回项的 status 是删除前的原始状态。
        return await _guideApi.getMine(
          query: GuideMineQuery(
            page: page,
            pageSize: _pageSize,
            onlyDeleted: true,
          ),
        );

      case MineTab.drafts:
        // 不会走到这里，草稿由 _loadDrafts 单独处理
        return const GuideListResponse(total: 0, items: []);
    }
  }
}
