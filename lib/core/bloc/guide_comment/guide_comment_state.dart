export 'guide_comment_event.dart' show CommentSortType;

import 'package:equatable/equatable.dart';

import '../../models/guide_models.dart';
import 'guide_comment_event.dart';

/// 评论区加载状态
enum CommentStatus { initial, loading, loadingMore, success, failure }

class GuideCommentState extends Equatable {
  /// 一级评论列表（已过滤拉黑用户）
  final List<GuideComment> comments;

  /// 楼中楼回复，key 为一级评论 id
  final Map<int, List<GuideComment>> replyMaps;

  /// 当前排序方式
  final CommentSortType sort;

  /// 总评论数
  final int total;

  /// 是否还有更多评论
  final bool hasMore;

  /// 是否正在发表评论
  final bool posting;

  /// 错误信息
  final String? error;

  /// 加载状态
  final CommentStatus status;

  /// 当前分页页码
  final int currentPage;

  /// 拉黑用户 ID 集合
  final Set<int> blockedUserIds;

  const GuideCommentState({
    this.comments = const [],
    this.replyMaps = const {},
    this.sort = CommentSortType.latest,
    this.total = 0,
    this.hasMore = true,
    this.posting = false,
    this.error,
    this.status = CommentStatus.initial,
    this.currentPage = 1,
    this.blockedUserIds = const {},
  });

  GuideCommentState copyWith({
    List<GuideComment>? comments,
    Map<int, List<GuideComment>>? replyMaps,
    CommentSortType? sort,
    int? total,
    bool? hasMore,
    bool? posting,
    String? error,
    bool clearError = false,
    CommentStatus? status,
    int? currentPage,
    Set<int>? blockedUserIds,
  }) {
    return GuideCommentState(
      comments: comments ?? this.comments,
      replyMaps: replyMaps ?? this.replyMaps,
      sort: sort ?? this.sort,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      posting: posting ?? this.posting,
      error: clearError ? null : (error ?? this.error),
      status: status ?? this.status,
      currentPage: currentPage ?? this.currentPage,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
    );
  }

  @override
  List<Object?> get props => [
    comments,
    replyMaps,
    sort,
    total,
    hasMore,
    posting,
    error,
    status,
    currentPage,
    blockedUserIds,
  ];
}
