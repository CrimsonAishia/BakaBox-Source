import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

import '../../api/api.dart';
import '../../api/guide_api.dart';
import '../../models/guide_models.dart';
import '../../utils/error_utils.dart';
import '../../utils/log_service.dart';
import 'guide_list_event.dart';
import 'guide_list_state.dart';

/// ChangeKeyword 事件的 debounce 时长
const _keywordDebounceDuration = Duration(milliseconds: 400);

/// 首屏 / 重置加载的最小展示时长。
///
/// 防止接口过快返回时骨架屏一闪而过，也能压平 filter/search 高频切换的反馈节奏。
/// 仅对 reset 加载（首屏、筛选、搜索、排序变化）生效，分页加载不受影响。
const _minLoadingDuration = Duration(milliseconds: 600);

/// debounce transformer：仅对 ChangeKeyword 事件做 400ms 防抖
EventTransformer<E> _debounce<E>(Duration duration) {
  return (events, mapper) =>
      events.debounceTime(duration).switchMap(mapper);
}

/// 攻略列表 Bloc
///
/// 职责：分页加载、筛选 / 排序 / 搜索、乐观更新点赞/收藏、单项刷新。
class GuideListBloc extends Bloc<GuideListEvent, GuideListState> {
  final GuideApi _guideApi = GuideApi();
  static const int _pageSize = 20;

  GuideListBloc() : super(const GuideListState()) {
    on<LoadGuides>(_onLoadGuides);
    on<ChangeFilter>(_onChangeFilter);
    on<ChangeSort>(_onChangeSort);
    on<ChangeKeyword>(_onChangeKeyword, transformer: _debounce(_keywordDebounceDuration));
    on<RefreshGuide>(_onRefreshGuide);
    on<ToggleLikeOptimistic>(_onToggleLike);
    on<ToggleFavoriteOptimistic>(_onToggleFavorite);
  }

  /// 提取错误信息
  String _getErrorMessage(Object e) {
    if (e is ApiException) return e.message;
    return ErrorUtils.getErrorMessage(e);
  }

  /// 构建列表查询参数（含分类 / 排序 / 关键词 / 地图等当前筛选条件）
  GuideListQuery _buildQuery({int page = 1}) {
    return GuideListQuery(
      page: page,
      pageSize: _pageSize,
      category: state.filter.category,
      sortBy: state.sortBy,
      keyword: state.keyword.isNotEmpty ? state.keyword : null,
      tags: state.filter.tags,
      hasVideo: state.filter.hasVideo,
      authorId: state.filter.authorId,
      mapName: state.filter.mapName,
    );
  }

  // ─── 事件处理 ─────────────────────────────────────────────────────────────

  Future<void> _onLoadGuides(
    LoadGuides event,
    Emitter<GuideListState> emit,
  ) async {
    if (event.reset) {
      // 重置加载（首屏 / 切换分类 / 搜索 / 排序 / 重试）时清空旧列表，
      // 立即切到骨架屏，避免在加载新分类期间仍停留显示上一分类的卡片，
      // 造成「先显示旧内容、再跳到新内容」的突兀闪烁。
      emit(state.copyWith(
        status: GuideListStatus.loading,
        items: const [],
        pinned: const [],
        clearError: true,
        currentPage: 1,
      ));
    } else {
      if (!state.canLoadMore) return;
      emit(state.copyWith(
        status: GuideListStatus.loadingMore,
        clearError: true,
      ));
    }

    final stopwatch = event.reset ? (Stopwatch()..start()) : null;

    try {
      final page = event.reset ? 1 : state.currentPage + 1;
      final query = _buildQuery(page: page);
      final response = await _guideApi.getGuides(query: query);

      // 首屏 / 重置加载强制最小展示时长，避免骨架一闪而过
      if (stopwatch != null) {
        final remaining = _minLoadingDuration - stopwatch.elapsed;
        if (remaining > Duration.zero) {
          await Future.delayed(remaining);
        }
      }

      final newItems = event.reset
          ? response.items
          : [...state.items, ...response.items];

      emit(state.copyWith(
        status: GuideListStatus.success,
        items: newItems,
        pinned: event.reset ? response.pinned : state.pinned,
        total: response.total,
        hasMore: newItems.length < response.total,
        currentPage: page,
      ));
    } catch (e) {
      // 失败也补足最小时长，保持 UI 节奏一致
      if (stopwatch != null) {
        final remaining = _minLoadingDuration - stopwatch.elapsed;
        if (remaining > Duration.zero) {
          await Future.delayed(remaining);
        }
      }
      emit(state.copyWith(
        status: GuideListStatus.failure,
        error: _getErrorMessage(e),
      ));
      LogService.e('获取攻略列表失败', e);
    }
  }

  Future<void> _onChangeFilter(
    ChangeFilter event,
    Emitter<GuideListState> emit,
  ) async {
    emit(state.copyWith(filter: event.filter));
    add(const LoadGuides(reset: true));
  }

  Future<void> _onChangeSort(
    ChangeSort event,
    Emitter<GuideListState> emit,
  ) async {
    if (state.sortBy == event.sortBy) return;
    emit(state.copyWith(sortBy: event.sortBy));
    add(const LoadGuides(reset: true));
  }

  Future<void> _onChangeKeyword(
    ChangeKeyword event,
    Emitter<GuideListState> emit,
  ) async {
    if (state.keyword == event.keyword) return;
    emit(state.copyWith(keyword: event.keyword));
    add(const LoadGuides(reset: true));
  }

  Future<void> _onRefreshGuide(
    RefreshGuide event,
    Emitter<GuideListState> emit,
  ) async {
    try {
      final detail = await _guideApi.getGuideDetail(event.id);
      if (detail == null) return;

      // 从详情构造 ListItem 并替换 items 中对应项
      final updatedItems = state.items.map((item) {
        if (item.id == event.id) {
          return GuideListItem(
            id: detail.id,
            title: detail.title,
            summary: detail.summary,
            coverUrl: detail.coverUrl,
            category: detail.category,
            categoryName: detail.categoryName,
            categoryColorHex: detail.categoryColorHex,
            tags: detail.tags,
            mapName: detail.mapName,
            mapLabel: detail.mapLabel,
            mapBackground: detail.mapBackground,
            hasVideo: detail.hasVideo,
            authorId: detail.authorId,
            authorName: detail.authorName,
            authorAvatar: detail.authorAvatar,
            viewCount: detail.viewCount,
            likeCount: detail.likeCount,
            favoriteCount: detail.favoriteCount,
            commentCount: detail.commentCount,
            isLiked: detail.isLiked,
            isFavorited: detail.isFavorited,
            isRecommended: detail.isRecommended,
            isPinned: detail.isPinned,
            status: detail.status,
            createdAt: detail.createdAt,
            publishedAt: detail.publishedAt,
            updatedAt: detail.updatedAt,
          );
        }
        return item;
      }).toList();

      // 同样替换 pinned 中对应项
      final updatedPinned = state.pinned.map((item) {
        if (item.id == event.id) {
          return GuideListItem(
            id: detail.id,
            title: detail.title,
            summary: detail.summary,
            coverUrl: detail.coverUrl,
            category: detail.category,
            categoryName: detail.categoryName,
            categoryColorHex: detail.categoryColorHex,
            tags: detail.tags,
            mapName: detail.mapName,
            mapLabel: detail.mapLabel,
            mapBackground: detail.mapBackground,
            hasVideo: detail.hasVideo,
            authorId: detail.authorId,
            authorName: detail.authorName,
            authorAvatar: detail.authorAvatar,
            viewCount: detail.viewCount,
            likeCount: detail.likeCount,
            favoriteCount: detail.favoriteCount,
            commentCount: detail.commentCount,
            isLiked: detail.isLiked,
            isFavorited: detail.isFavorited,
            isRecommended: detail.isRecommended,
            isPinned: detail.isPinned,
            status: detail.status,
            createdAt: detail.createdAt,
            publishedAt: detail.publishedAt,
            updatedAt: detail.updatedAt,
          );
        }
        return item;
      }).toList();

      emit(state.copyWith(items: updatedItems, pinned: updatedPinned));
    } catch (e) {
      // RefreshGuide 失败静默处理，不影响列表状态
      LogService.e('刷新攻略 ${event.id} 失败', e);
    }
  }

  Future<void> _onToggleLike(
    ToggleLikeOptimistic event,
    Emitter<GuideListState> emit,
  ) async {
    final index = state.items.indexWhere((item) => item.id == event.id);
    if (index == -1) return;

    final original = state.items[index];
    final nowLiked = !original.isLiked;
    final newLikeCount =
        original.likeCount + (nowLiked ? 1 : -1);

    // 乐观更新
    final optimisticItem = GuideListItem(
      id: original.id,
      title: original.title,
      summary: original.summary,
      coverUrl: original.coverUrl,
      category: original.category,
      categoryName: original.categoryName,
      categoryColorHex: original.categoryColorHex,
      tags: original.tags,
      mapName: original.mapName,
      mapLabel: original.mapLabel,
      mapBackground: original.mapBackground,
      hasVideo: original.hasVideo,
      authorId: original.authorId,
      authorName: original.authorName,
      authorAvatar: original.authorAvatar,
      viewCount: original.viewCount,
      likeCount: newLikeCount < 0 ? 0 : newLikeCount,
      favoriteCount: original.favoriteCount,
      commentCount: original.commentCount,
      isLiked: nowLiked,
      isFavorited: original.isFavorited,
      isRecommended: original.isRecommended,
      isPinned: original.isPinned,
      status: original.status,
      createdAt: original.createdAt,
      publishedAt: original.publishedAt,
      updatedAt: original.updatedAt,
    );

    final updatedItems = List<GuideListItem>.from(state.items);
    updatedItems[index] = optimisticItem;
    emit(state.copyWith(items: updatedItems));

    try {
      if (nowLiked) {
        await _guideApi.like(event.id);
      } else {
        await _guideApi.unlike(event.id);
      }
    } catch (e) {
      // 失败回滚
      final rollbackItems = List<GuideListItem>.from(state.items);
      final currentIndex =
          rollbackItems.indexWhere((item) => item.id == event.id);
      if (currentIndex != -1) {
        rollbackItems[currentIndex] = original;
        emit(state.copyWith(
          items: rollbackItems,
          error: _getErrorMessage(e),
        ));
      }
      LogService.e('点赞操作失败', e);
    }
  }

  Future<void> _onToggleFavorite(
    ToggleFavoriteOptimistic event,
    Emitter<GuideListState> emit,
  ) async {
    final index = state.items.indexWhere((item) => item.id == event.id);
    if (index == -1) return;

    final original = state.items[index];
    final nowFavorited = !original.isFavorited;
    final newFavoriteCount =
        original.favoriteCount + (nowFavorited ? 1 : -1);

    // 乐观更新
    final optimisticItem = GuideListItem(
      id: original.id,
      title: original.title,
      summary: original.summary,
      coverUrl: original.coverUrl,
      category: original.category,
      categoryName: original.categoryName,
      categoryColorHex: original.categoryColorHex,
      tags: original.tags,
      mapName: original.mapName,
      mapLabel: original.mapLabel,
      mapBackground: original.mapBackground,
      hasVideo: original.hasVideo,
      authorId: original.authorId,
      authorName: original.authorName,
      authorAvatar: original.authorAvatar,
      viewCount: original.viewCount,
      likeCount: original.likeCount,
      favoriteCount: newFavoriteCount < 0 ? 0 : newFavoriteCount,
      commentCount: original.commentCount,
      isLiked: original.isLiked,
      isFavorited: nowFavorited,
      isRecommended: original.isRecommended,
      isPinned: original.isPinned,
      status: original.status,
      createdAt: original.createdAt,
      publishedAt: original.publishedAt,
      updatedAt: original.updatedAt,
    );

    final updatedItems = List<GuideListItem>.from(state.items);
    updatedItems[index] = optimisticItem;
    emit(state.copyWith(items: updatedItems));

    try {
      if (nowFavorited) {
        await _guideApi.favorite(event.id);
      } else {
        await _guideApi.unfavorite(event.id);
      }
    } catch (e) {
      // 失败回滚
      final rollbackItems = List<GuideListItem>.from(state.items);
      final currentIndex =
          rollbackItems.indexWhere((item) => item.id == event.id);
      if (currentIndex != -1) {
        rollbackItems[currentIndex] = original;
        emit(state.copyWith(
          items: rollbackItems,
          error: _getErrorMessage(e),
        ));
      }
      LogService.e('收藏操作失败', e);
    }
  }
}
