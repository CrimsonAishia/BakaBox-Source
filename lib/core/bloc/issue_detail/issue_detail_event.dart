import 'package:equatable/equatable.dart';
import '../../models/issue_models.dart';
import '../../models/user_info.dart';

abstract class IssueDetailEvent extends Equatable {
  const IssueDetailEvent();
  @override
  List<Object?> get props => [];
}

/// 加载 Issue 详情
class IssueDetailFetch extends IssueDetailEvent {
  final int issueId;
  const IssueDetailFetch(this.issueId);
  @override
  List<Object?> get props => [issueId];
}

/// 加载评论
class IssueDetailLoadComments extends IssueDetailEvent {
  final int issueId;
  const IssueDetailLoadComments(this.issueId);
  @override
  List<Object?> get props => [issueId];
}

/// 投票/取消投票
class IssueDetailToggleVote extends IssueDetailEvent {
  const IssueDetailToggleVote();
}

/// 发表评论
class IssueDetailAddComment extends IssueDetailEvent {
  final String content;
  final List<String>? images;
  const IssueDetailAddComment(this.content, {this.images});
  @override
  List<Object?> get props => [content, images];
}

/// 关闭 Issue
class IssueDetailClose extends IssueDetailEvent {
  const IssueDetailClose();
}

/// 重开 Issue
class IssueDetailReopen extends IssueDetailEvent {
  const IssueDetailReopen();
}

/// 清除错误
class IssueDetailClearError extends IssueDetailEvent {
  const IssueDetailClearError();
}

/// 重置状态
class IssueDetailReset extends IssueDetailEvent {
  const IssueDetailReset();
}

/// 更新 Issue（本地状态更新）
class IssueDetailUpdate extends IssueDetailEvent {
  final Issue issue;
  const IssueDetailUpdate(this.issue);
  @override
  List<Object?> get props => [issue];
}

/// 设置当前用户信息（用于构建评论）
class IssueDetailSetUser extends IssueDetailEvent {
  final UserInfo? user;
  const IssueDetailSetUser(this.user);
  @override
  List<Object?> get props => [user];
}
