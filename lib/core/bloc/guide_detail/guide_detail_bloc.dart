import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/api.dart';
import '../../api/guide_api.dart';
import '../../models/guide_models.dart';
import '../../services/analytics_service.dart';
import '../../utils/error_utils.dart';
import '../../utils/log_service.dart';
import 'guide_detail_event.dart';
import 'guide_detail_state.dart';

/// 攻略详情 Bloc
///
/// 职责：加载详情、乐观更新点赞/收藏（失败回滚）、上报浏览、分享。
/// 互动成功后递增 [lastInteractionId]，UI 层通过 BlocListener 监听变化
/// 以通知 GuideListBloc 执行 RefreshGuide(id)。
class GuideDetailBloc extends Bloc<GuideDetailEvent, GuideDetailState> {
  final GuideApi _guideApi = GuideApi();

  GuideDetailBloc() : super(const GuideDetailState()) {
    on<LoadGuide>(_onLoadGuide);
    on<ToggleLike>(_onToggleLike);
    on<ToggleFavorite>(_onToggleFavorite);
    on<ReportView>(_onReportView);
    on<Share>(_onShare);
  }

  /// 提取错误信息
  String _getErrorMessage(Object e) {
    if (e is ApiException) return e.message;
    return ErrorUtils.getErrorMessage(e);
  }

  // ─── 事件处理 ─────────────────────────────────────────────────────────────

  Future<void> _onLoadGuide(
    LoadGuide event,
    Emitter<GuideDetailState> emit,
  ) async {
    emit(state.copyWith(
      status: DetailStatus.loading,
      clearError: true,
    ));

    try {
      final guide = await _guideApi.getGuideDetail(event.id);
      if (guide == null) {
        emit(state.copyWith(status: DetailStatus.notFound));
        return;
      }
      emit(state.copyWith(
        status: DetailStatus.success,
        guide: guide,
      ));
    } on ApiException catch (e) {
      if (e.code == 404) {
        emit(state.copyWith(status: DetailStatus.notFound));
      } else if (e.code == 403) {
        emit(state.copyWith(status: DetailStatus.blocked));
      } else {
        emit(state.copyWith(
          status: DetailStatus.failure,
          error: e.message,
        ));
      }
      LogService.e('加载攻略详情失败', e);
    } catch (e) {
      emit(state.copyWith(
        status: DetailStatus.failure,
        error: _getErrorMessage(e),
      ));
      LogService.e('加载攻略详情失败', e);
    }
  }

  Future<void> _onToggleLike(
    ToggleLike event,
    Emitter<GuideDetailState> emit,
  ) async {
    final guide = state.guide;
    if (guide == null) return;

    final nowLiked = !guide.isLiked;
    final newLikeCount = guide.likeCount + (nowLiked ? 1 : -1);

    // 乐观更新
    final optimisticGuide = Guide(
      id: guide.id,
      title: guide.title,
      summary: guide.summary,
      coverUrl: guide.coverUrl,
      category: guide.category,
      categoryName: guide.categoryName,
      categoryColorHex: guide.categoryColorHex,
      tags: guide.tags,
      mapName: guide.mapName,
      mapLabel: guide.mapLabel,
      mapBackground: guide.mapBackground,
      hasVideo: guide.hasVideo,
      authorId: guide.authorId,
      authorName: guide.authorName,
      authorAvatar: guide.authorAvatar,
      viewCount: guide.viewCount,
      likeCount: newLikeCount < 0 ? 0 : newLikeCount,
      favoriteCount: guide.favoriteCount,
      commentCount: guide.commentCount,
      isLiked: nowLiked,
      isFavorited: guide.isFavorited,
      isRecommended: guide.isRecommended,
      isPinned: guide.isPinned,
      status: guide.status,
      createdAt: guide.createdAt,
      publishedAt: guide.publishedAt,
      updatedAt: guide.updatedAt,
      content: guide.content,
      attachments: guide.attachments,
      videoEmbeds: guide.videoEmbeds,
      tocItems: guide.tocItems,
      mapInfo: guide.mapInfo,
      readingTimeMin: guide.readingTimeMin,
      version: guide.version,
      rejectReason: guide.rejectReason,
      relatedGuideIds: guide.relatedGuideIds,
    );

    emit(state.copyWith(guide: optimisticGuide, clearError: true));

    try {
      if (nowLiked) {
        await _guideApi.like(guide.id);
      } else {
        await _guideApi.unlike(guide.id);
      }
      // 上报埋点 guide_like（fire-and-forget）
      AnalyticsService.instance.trackEvent('guide_like', {
        'id': guide.id,
        'action': nowLiked ? 'like' : 'unlike',
      });
      // 互动成功，递增 lastInteractionId 通知列表刷新
      emit(state.copyWith(
        lastInteractionId: state.lastInteractionId + 1,
      ));
    } catch (e) {
      // 失败回滚
      emit(state.copyWith(
        guide: guide,
        error: _getErrorMessage(e),
      ));
      LogService.e('点赞操作失败', e);
    }
  }

  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<GuideDetailState> emit,
  ) async {
    final guide = state.guide;
    if (guide == null) return;

    final nowFavorited = !guide.isFavorited;
    final newFavoriteCount =
        guide.favoriteCount + (nowFavorited ? 1 : -1);

    // 乐观更新
    final optimisticGuide = Guide(
      id: guide.id,
      title: guide.title,
      summary: guide.summary,
      coverUrl: guide.coverUrl,
      category: guide.category,
      categoryName: guide.categoryName,
      categoryColorHex: guide.categoryColorHex,
      tags: guide.tags,
      mapName: guide.mapName,
      mapLabel: guide.mapLabel,
      mapBackground: guide.mapBackground,
      hasVideo: guide.hasVideo,
      authorId: guide.authorId,
      authorName: guide.authorName,
      authorAvatar: guide.authorAvatar,
      viewCount: guide.viewCount,
      likeCount: guide.likeCount,
      favoriteCount: newFavoriteCount < 0 ? 0 : newFavoriteCount,
      commentCount: guide.commentCount,
      isLiked: guide.isLiked,
      isFavorited: nowFavorited,
      isRecommended: guide.isRecommended,
      isPinned: guide.isPinned,
      status: guide.status,
      createdAt: guide.createdAt,
      publishedAt: guide.publishedAt,
      updatedAt: guide.updatedAt,
      content: guide.content,
      attachments: guide.attachments,
      videoEmbeds: guide.videoEmbeds,
      tocItems: guide.tocItems,
      mapInfo: guide.mapInfo,
      readingTimeMin: guide.readingTimeMin,
      version: guide.version,
      rejectReason: guide.rejectReason,
      relatedGuideIds: guide.relatedGuideIds,
    );

    emit(state.copyWith(guide: optimisticGuide, clearError: true));

    try {
      if (nowFavorited) {
        await _guideApi.favorite(guide.id);
      } else {
        await _guideApi.unfavorite(guide.id);
      }
      // 上报埋点 guide_favorite（fire-and-forget）
      AnalyticsService.instance.trackEvent('guide_favorite', {
        'id': guide.id,
        'action': nowFavorited ? 'favorite' : 'unfavorite',
      });
      // 互动成功，递增 lastInteractionId 通知列表刷新
      emit(state.copyWith(
        lastInteractionId: state.lastInteractionId + 1,
      ));
    } catch (e) {
      // 失败回滚
      emit(state.copyWith(
        guide: guide,
        error: _getErrorMessage(e),
      ));
      LogService.e('收藏操作失败', e);
    }
  }

  Future<void> _onReportView(
    ReportView event,
    Emitter<GuideDetailState> emit,
  ) async {
    final guide = state.guide;
    if (guide == null) return;

    // fire-and-forget：不改变状态
    try {
      await _guideApi.view(guide.id);
    } catch (e) {
      // 浏览上报失败静默处理
      LogService.e('上报浏览失败', e);
    }
  }

  Future<void> _onShare(
    Share event,
    Emitter<GuideDetailState> emit,
  ) async {
    final guide = state.guide;
    if (guide == null) return;

    // 上报埋点 guide_share（fire-and-forget）
    AnalyticsService.instance.trackEvent('guide_share', {
      'id': guide.id,
      'channel': event.channel,
    });

    try {
      await _guideApi.share(guide.id, channel: event.channel);
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e)));
      LogService.e('分享失败', e);
    }
  }
}
