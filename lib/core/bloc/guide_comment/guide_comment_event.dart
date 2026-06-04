import 'package:equatable/equatable.dart';

abstract class GuideCommentEvent extends Equatable {
  const GuideCommentEvent();
  @override
  List<Object?> get props => [];
}

/// 加载评论列表（reset=true 时重置到第一页）
class LoadComments extends GuideCommentEvent {
  final bool reset;
  const LoadComments({this.reset = false});
  @override
  List<Object?> get props => [reset];
}

/// 加载某一级评论的楼中楼回复
class LoadReplies extends GuideCommentEvent {
  final int parentCommentId;
  const LoadReplies(this.parentCommentId);
  @override
  List<Object?> get props => [parentCommentId];
}

/// 发表评论
class PostComment extends GuideCommentEvent {
  final String content;
  final List<String> images;
  final int? parentId;
  final int? replyToId;
  final String? replyToName;

  const PostComment({
    required this.content,
    this.images = const [],
    this.parentId,
    this.replyToId,
    this.replyToName,
  });

  @override
  List<Object?> get props => [content, images, parentId, replyToId, replyToName];
}

/// 删除评论（软删除：标记 isDeleted=true，保留楼层）
class DeleteComment extends GuideCommentEvent {
  final int id;
  const DeleteComment(this.id);
  @override
  List<Object?> get props => [id];
}

/// 切换评论点赞（乐观更新 + 失败回滚）
class ToggleCommentLike extends GuideCommentEvent {
  final int id;
  const ToggleCommentLike(this.id);
  @override
  List<Object?> get props => [id];
}

/// 切换排序方式（最新 / 最热）
class ChangeCommentSort extends GuideCommentEvent {
  final CommentSortType sort;
  const ChangeCommentSort(this.sort);
  @override
  List<Object?> get props => [sort];
}

/// 更新拉黑用户集合
class UpdateBlockedUsers extends GuideCommentEvent {
  final Set<int> blockedUserIds;
  const UpdateBlockedUsers(this.blockedUserIds);
  @override
  List<Object?> get props => [blockedUserIds];
}

/// 评论排序类型
enum CommentSortType {
  latest,
  hot;

  String get value => switch (this) {
        CommentSortType.latest => 'latest',
        CommentSortType.hot => 'hot',
      };
}
