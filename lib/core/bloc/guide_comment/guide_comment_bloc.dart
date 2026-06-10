import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/api.dart';
import '../../api/guide_api.dart';
import '../../models/guide_models.dart';
import '../../services/analytics_service.dart';
import '../../utils/error_utils.dart';
import '../../utils/log_service.dart';
import 'guide_comment_event.dart';
import 'guide_comment_state.dart';

/// 攻略评论 Bloc
///
/// 职责：评论列表分页加载、楼中楼回复、发表评论（含 5 秒限速）、
/// 软删除、评论点赞（乐观更新 + 回滚）、排序切换、拉黑过滤。
class GuideCommentBloc extends Bloc<GuideCommentEvent, GuideCommentState> {
  final int guideId;
  final GuideApi _guideApi = GuideApi();

  static const int _pageSize = 20;

  /// 客户端 5 秒限速：记录上次发表评论的时间
  DateTime? _lastPostTime;

  /// 限速间隔
  static const Duration _rateLimitInterval = Duration(seconds: 5);

  GuideCommentBloc({required this.guideId})
      : super(const GuideCommentState()) {
    on<LoadComments>(_onLoadComments);
    on<LoadReplies>(_onLoadReplies);
    on<PostComment>(_onPostComment);
    on<DeleteComment>(_onDeleteComment);
    on<ToggleCommentLike>(_onToggleCommentLike);
    on<ToggleCommentDislike>(_onToggleCommentDislike);
    on<ChangeCommentSort>(_onChangeSort);
    on<UpdateBlockedUsers>(_onUpdateBlockedUsers);
  }

  /// 提取错误信息
  String _getErrorMessage(Object e) {
    if (e is ApiException) return e.message;
    return ErrorUtils.getErrorMessage(e);
  }

  /// 过滤拉黑用户的评论（blockedIds 为空时直接返回原列表）
  List<GuideComment> _filterBlocked(
    List<GuideComment> comments,
    Set<int> blockedIds,
  ) {
    if (blockedIds.isEmpty) return comments;
    return comments
        .where((c) => !blockedIds.contains(c.authorId))
        .toList();
  }

  // ─── 事件处理 ─────────────────────────────────────────────────────────────

  Future<void> _onLoadComments(
    LoadComments event,
    Emitter<GuideCommentState> emit,
  ) async {
    final isReset = event.reset;
    final page = isReset ? 1 : state.currentPage;

    emit(state.copyWith(
      status: isReset ? CommentStatus.loading : CommentStatus.loadingMore,
      clearError: true,
    ));

    try {
      final response = await _guideApi.getComments(
        guideId,
        page: page,
        pageSize: _pageSize,
        sort: state.sort.value,
      );

      final filtered = _filterBlocked(response.items, state.blockedUserIds);
      final newComments =
          isReset ? filtered : [...state.comments, ...filtered];
      final hasMore = response.items.length >= _pageSize;

      emit(state.copyWith(
        status: CommentStatus.success,
        comments: newComments,
        total: response.total,
        hasMore: hasMore,
        currentPage: page + 1,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CommentStatus.failure,
        error: _getErrorMessage(e),
      ));
      LogService.e('加载评论列表失败', e);
    }
  }

  Future<void> _onLoadReplies(
    LoadReplies event,
    Emitter<GuideCommentState> emit,
  ) async {
    try {
      final replies = await _guideApi.getReplies(event.parentCommentId);
      final filtered = _filterBlocked(replies, state.blockedUserIds);

      final newReplyMaps = Map<int, List<GuideComment>>.from(state.replyMaps);
      newReplyMaps[event.parentCommentId] = filtered;

      emit(state.copyWith(replyMaps: newReplyMaps));
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e)));
      LogService.e('加载楼中楼回复失败', e);
    }
  }

  Future<void> _onPostComment(
    PostComment event,
    Emitter<GuideCommentState> emit,
  ) async {
    // 客户端 5 秒限速检查
    if (_lastPostTime != null) {
      final elapsed = DateTime.now().difference(_lastPostTime!);
      if (elapsed < _rateLimitInterval) {
        emit(state.copyWith(error: '评论太快了，稍后再试'));
        return;
      }
    }

    emit(state.copyWith(posting: true, clearError: true));

    try {
      final request = AddCommentRequest(
        content: event.content,
        images: event.images.isNotEmpty ? event.images : null,
        parentId: event.parentId,
        replyToId: event.replyToId,
        replyToName: event.replyToName,
      );

      LogService.d('[GuideCommentBloc] PostComment: '
          'parentId=${event.parentId}, '
          'replyToId=${event.replyToId}, '
          'replyToName=${event.replyToName}');

      final newComment = await _guideApi.addComment(guideId, request);
      _lastPostTime = DateTime.now();

      // 上报埋点 guide_comment_post（fire-and-forget）
      AnalyticsService.instance.trackEvent('guide_comment_post', {
        'guideId': guideId,
        'isReply': event.parentId != null,
      });

      if (newComment != null) {
        LogService.d('[GuideCommentBloc] newComment received: '
            'id=${newComment.id}, '
            'parentId=${newComment.parentId}, '
            'replyToId=${newComment.replyToId}');
        if (event.parentId != null && event.parentId != 0) {
          // 楼中楼回复：追加到对应 replyMaps
          LogService.d('[GuideCommentBloc] placing in replyMaps[${event.parentId}]');

          // 找到父级一级评论，用于在 replyMaps 尚未加载时回填已有的内嵌 replies 预览
          GuideComment? parentComment;
          for (final c in state.comments) {
            if (c.id == event.parentId) {
              parentComment = c;
              break;
            }
          }

          final newReplyMaps =
              Map<int, List<GuideComment>>.from(state.replyMaps);

          // 关键修复：replyMaps[parentId] 未加载时，用父评论自带的 replies 预览作为基础，
          // 否则会把面板从「展示预览 replies」切换成「只展示这一条新回复」，
          // 导致刚被回复的那条二级评论看起来「被替换」。
          final List<GuideComment> baseReplies;
          if (newReplyMaps.containsKey(event.parentId)) {
            baseReplies = List<GuideComment>.from(newReplyMaps[event.parentId]!);
            LogService.d('[GuideCommentBloc] replyMaps[${event.parentId}] '
                '已加载，基础回复数=${baseReplies.length}');
          } else {
            baseReplies =
                List<GuideComment>.from(parentComment?.replies ?? const []);
            LogService.d('[GuideCommentBloc] replyMaps[${event.parentId}] '
                '未加载，用父评论内嵌预览作为基础，基础回复数=${baseReplies.length}');
          }

          // 避免重复追加（防御：若新回复 id 已存在则跳过）
          if (!baseReplies.any((r) => r.id == newComment.id)) {
            baseReplies.add(newComment);
          }
          newReplyMaps[event.parentId!] = baseReplies;
          LogService.d('[GuideCommentBloc] replyMaps[${event.parentId}] '
              '追加后回复数=${baseReplies.length}');

          // 更新对应一级评论的 replyCount
          final updatedComments = state.comments.map((c) {
            if (c.id == event.parentId) {
              return GuideComment(
                id: c.id,
                guideId: c.guideId,
                parentId: c.parentId,
                replyToId: c.replyToId,
                replyToName: c.replyToName,
                content: c.content,
                images: c.images,
                authorId: c.authorId,
                authorName: c.authorName,
                authorAvatar: c.authorAvatar,
                likeCount: c.likeCount,
                isLiked: c.isLiked,
                replyCount: c.replyCount + 1,
                replies: c.replies,
                isAuthor: c.isAuthor,
                isDeleted: c.isDeleted,
                createdAt: c.createdAt,
              );
            }
            return c;
          }).toList();

          emit(state.copyWith(
            posting: false,
            replyMaps: newReplyMaps,
            comments: updatedComments,
            total: state.total + 1,
          ));
        } else {
          // 一级评论：插入到列表头部
          LogService.d('[GuideCommentBloc] placing as top-level comment (parentId is null)');
          final updatedComments = [newComment, ...state.comments];
          emit(state.copyWith(
            posting: false,
            comments: updatedComments,
            total: state.total + 1,
          ));
        }
      } else {
        emit(state.copyWith(posting: false));
      }
    } on ApiException catch (e) {
      _lastPostTime = DateTime.now();
      if (e.code == 429) {
        // 服务端 429 限速
        emit(state.copyWith(
          posting: false,
          error: '评论太快了，稍后再试',
        ));
      } else {
        emit(state.copyWith(
          posting: false,
          error: e.message,
        ));
      }
      LogService.e('发表评论失败', e);
    } catch (e) {
      _lastPostTime = DateTime.now();
      emit(state.copyWith(
        posting: false,
        error: _getErrorMessage(e),
      ));
      LogService.e('发表评论失败', e);
    }
  }

  Future<void> _onDeleteComment(
    DeleteComment event,
    Emitter<GuideCommentState> emit,
  ) async {
    try {
      await _guideApi.deleteComment(guideId, event.id);

      // 软删除：保留楼层，标记 isDeleted=true
      final updatedComments = state.comments.map((c) {
        if (c.id == event.id) {
          return GuideComment(
            id: c.id,
            guideId: c.guideId,
            parentId: c.parentId,
            replyToId: c.replyToId,
            replyToName: c.replyToName,
            content: c.content,
            images: c.images,
            authorId: c.authorId,
            authorName: c.authorName,
            authorAvatar: c.authorAvatar,
            likeCount: c.likeCount,
            isLiked: c.isLiked,
            replyCount: c.replyCount,
            replies: c.replies,
            isAuthor: c.isAuthor,
            isDeleted: true,
            createdAt: c.createdAt,
          );
        }
        return c;
      }).toList();

      // 也检查 replyMaps 中的评论
      final updatedReplyMaps =
          Map<int, List<GuideComment>>.from(state.replyMaps);
      for (final entry in updatedReplyMaps.entries) {
        updatedReplyMaps[entry.key] = entry.value.map((c) {
          if (c.id == event.id) {
            return GuideComment(
              id: c.id,
              guideId: c.guideId,
              parentId: c.parentId,
              replyToId: c.replyToId,
              replyToName: c.replyToName,
              content: c.content,
              images: c.images,
              authorId: c.authorId,
              authorName: c.authorName,
              authorAvatar: c.authorAvatar,
              likeCount: c.likeCount,
              isLiked: c.isLiked,
              replyCount: c.replyCount,
              replies: c.replies,
              isAuthor: c.isAuthor,
              isDeleted: true,
              createdAt: c.createdAt,
            );
          }
          return c;
        }).toList();
      }

      emit(state.copyWith(
        comments: updatedComments,
        replyMaps: updatedReplyMaps,
      ));
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e)));
      LogService.e('删除评论失败', e);
    }
  }

  Future<void> _onToggleCommentLike(
    ToggleCommentLike event,
    Emitter<GuideCommentState> emit,
  ) async {
    // 查找评论（一级或楼中楼）
    GuideComment? targetComment;
    bool isReply = false;
    int? parentId;

    for (final c in state.comments) {
      if (c.id == event.id) {
        targetComment = c;
        break;
      }
    }

    if (targetComment == null) {
      // 在 replyMaps 中查找
      for (final entry in state.replyMaps.entries) {
        for (final reply in entry.value) {
          if (reply.id == event.id) {
            targetComment = reply;
            isReply = true;
            parentId = entry.key;
            break;
          }
        }
        if (targetComment != null) break;
      }
    }

    if (targetComment == null) return;

    final nowLiked = !targetComment.isLiked;
    final newLikeCount =
        targetComment.likeCount + (nowLiked ? 1 : -1);

    final optimistic = GuideComment(
      id: targetComment.id,
      guideId: targetComment.guideId,
      parentId: targetComment.parentId,
      replyToId: targetComment.replyToId,
      replyToName: targetComment.replyToName,
      content: targetComment.content,
      images: targetComment.images,
      authorId: targetComment.authorId,
      authorName: targetComment.authorName,
      authorAvatar: targetComment.authorAvatar,
      likeCount: newLikeCount < 0 ? 0 : newLikeCount,
      isLiked: nowLiked,
      replyCount: targetComment.replyCount,
      replies: targetComment.replies,
      isAuthor: targetComment.isAuthor,
      isDeleted: targetComment.isDeleted,
      createdAt: targetComment.createdAt,
    );

    // 乐观更新
    if (isReply && parentId != null) {
      final newReplyMaps =
          Map<int, List<GuideComment>>.from(state.replyMaps);
      newReplyMaps[parentId] = newReplyMaps[parentId]!.map((c) {
        return c.id == event.id ? optimistic : c;
      }).toList();
      emit(state.copyWith(replyMaps: newReplyMaps, clearError: true));
    } else {
      final updatedComments = state.comments.map((c) {
        return c.id == event.id ? optimistic : c;
      }).toList();
      emit(state.copyWith(comments: updatedComments, clearError: true));
    }

    // 调接口
    try {
      if (nowLiked) {
        await _guideApi.likeComment(event.id);
      } else {
        await _guideApi.unlikeComment(event.id);
      }
    } catch (e) {
      // 失败回滚
      if (isReply && parentId != null) {
        final rollbackReplyMaps =
            Map<int, List<GuideComment>>.from(state.replyMaps);
        rollbackReplyMaps[parentId] =
            rollbackReplyMaps[parentId]!.map((c) {
          return c.id == event.id ? targetComment! : c;
        }).toList();
        emit(state.copyWith(
          replyMaps: rollbackReplyMaps,
          error: _getErrorMessage(e),
        ));
      } else {
        final rollbackComments = state.comments.map((c) {
          return c.id == event.id ? targetComment! : c;
        }).toList();
        emit(state.copyWith(
          comments: rollbackComments,
          error: _getErrorMessage(e),
        ));
      }
      LogService.e('评论点赞失败', e);
    }
  }

  /// 切换评论点踩（乐观更新 + 失败回滚）
  ///
  /// 与点赞互斥：点踩时若已点赞，则同时取消点赞（仅本地状态，点赞数 -1）。
  Future<void> _onToggleCommentDislike(
    ToggleCommentDislike event,
    Emitter<GuideCommentState> emit,
  ) async {
    // 查找评论（一级或楼中楼）
    GuideComment? targetComment;
    bool isReply = false;
    int? parentId;

    for (final c in state.comments) {
      if (c.id == event.id) {
        targetComment = c;
        break;
      }
    }

    if (targetComment == null) {
      for (final entry in state.replyMaps.entries) {
        for (final reply in entry.value) {
          if (reply.id == event.id) {
            targetComment = reply;
            isReply = true;
            parentId = entry.key;
            break;
          }
        }
        if (targetComment != null) break;
      }
    }

    if (targetComment == null) {
      LogService.w('[GuideCommentBloc] dislike: 未找到评论 id=${event.id}');
      return;
    }

    final nowDisliked = !targetComment.isDisliked;
    // 点踩与点赞互斥：点踩时取消已有点赞
    final wasLiked = targetComment.isLiked;
    final newLikeCount = (nowDisliked && wasLiked)
        ? (targetComment.likeCount - 1).clamp(0, 1 << 31)
        : targetComment.likeCount;
    final newDislikeCount =
        (targetComment.dislikeCount + (nowDisliked ? 1 : -1)).clamp(0, 1 << 31);

    LogService.d('[GuideCommentBloc] ToggleCommentDislike: '
        'id=${event.id}, nowDisliked=$nowDisliked, wasLiked=$wasLiked, '
        'dislikeCount=${targetComment.dislikeCount}->$newDislikeCount');

    final optimistic = targetComment.copyWith(
      isDisliked: nowDisliked,
      isLiked: nowDisliked ? false : targetComment.isLiked,
      likeCount: newLikeCount,
      dislikeCount: newDislikeCount,
    );

    // 乐观更新
    if (isReply && parentId != null) {
      final newReplyMaps =
          Map<int, List<GuideComment>>.from(state.replyMaps);
      newReplyMaps[parentId] = newReplyMaps[parentId]!
          .map((c) => c.id == event.id ? optimistic : c)
          .toList();
      emit(state.copyWith(replyMaps: newReplyMaps, clearError: true));
    } else {
      final updatedComments = state.comments
          .map((c) => c.id == event.id ? optimistic : c)
          .toList();
      emit(state.copyWith(comments: updatedComments, clearError: true));
    }

    // 调接口
    try {
      if (nowDisliked) {
        await _guideApi.dislikeComment(event.id);
      } else {
        await _guideApi.undislikeComment(event.id);
      }
    } catch (e) {
      // 失败回滚
      if (isReply && parentId != null) {
        final rollbackReplyMaps =
            Map<int, List<GuideComment>>.from(state.replyMaps);
        rollbackReplyMaps[parentId] = rollbackReplyMaps[parentId]!
            .map((c) => c.id == event.id ? targetComment! : c)
            .toList();
        emit(state.copyWith(
          replyMaps: rollbackReplyMaps,
          error: _getErrorMessage(e),
        ));
      } else {
        final rollbackComments = state.comments
            .map((c) => c.id == event.id ? targetComment! : c)
            .toList();
        emit(state.copyWith(
          comments: rollbackComments,
          error: _getErrorMessage(e),
        ));
      }
      LogService.e('评论点踩失败', e);
    }
  }

  Future<void> _onChangeSort(
    ChangeCommentSort event,
    Emitter<GuideCommentState> emit,
  ) async {
    if (event.sort == state.sort) return;

    emit(state.copyWith(
      sort: event.sort,
      comments: [],
      replyMaps: {},
      currentPage: 1,
      hasMore: true,
      status: CommentStatus.loading,
      clearError: true,
    ));

    // 重新加载第一页
    add(const LoadComments(reset: true));
  }

  void _onUpdateBlockedUsers(
    UpdateBlockedUsers event,
    Emitter<GuideCommentState> emit,
  ) {
    final newBlockedIds = event.blockedUserIds;

    // 重新过滤现有评论
    final filteredComments = _filterBlocked(state.comments, newBlockedIds);

    // 重新过滤楼中楼
    final filteredReplyMaps =
        Map<int, List<GuideComment>>.from(state.replyMaps);
    for (final entry in filteredReplyMaps.entries) {
      filteredReplyMaps[entry.key] =
          _filterBlocked(entry.value, newBlockedIds);
    }

    emit(state.copyWith(
      blockedUserIds: newBlockedIds,
      comments: filteredComments,
      replyMaps: filteredReplyMaps,
    ));
  }
}
