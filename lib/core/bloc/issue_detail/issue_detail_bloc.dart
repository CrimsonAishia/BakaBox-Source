import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/api.dart';
import '../../api/issue_api.dart';
import '../../models/issue_models.dart';
import '../../models/user_info.dart';
import '../../utils/error_utils.dart';
import '../../utils/log_service.dart';
import 'issue_detail_event.dart';
import 'issue_detail_state.dart';

class IssueDetailBloc extends Bloc<IssueDetailEvent, IssueDetailState> {
  final IssueApi _issueApi = IssueApi();
  int? _currentIssueId;
  UserInfo? _currentUser;

  IssueDetailBloc() : super(const IssueDetailState()) {
    on<IssueDetailFetch>(_onFetch);
    on<IssueDetailLoadComments>(_onLoadComments);
    on<IssueDetailToggleVote>(_onToggleVote);
    on<IssueDetailAddComment>(_onAddComment);
    on<IssueDetailClose>(_onClose);
    on<IssueDetailReopen>(_onReopen);
    on<IssueDetailClearError>(_onClearError);
    on<IssueDetailReset>(_onReset);
    on<IssueDetailUpdate>(_onUpdate);
    on<IssueDetailSetUser>(_onSetUser);
  }

  /// 设置当前用户
  void _onSetUser(IssueDetailSetUser event, Emitter<IssueDetailState> emit) {
    _currentUser = event.user;
  }

  /// 提取错误信息
  String _getErrorMessage(Object e) {
    if (e is ApiException) return e.message;
    return ErrorUtils.getErrorMessage(e);
  }

  Future<void> _onFetch(IssueDetailFetch event, Emitter<IssueDetailState> emit) async {
    _currentIssueId = event.issueId;
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final issue = await _issueApi.getIssueDetail(event.issueId);
      if (issue != null) {
        emit(state.copyWith(issue: issue, isLoading: false));
        add(IssueDetailLoadComments(event.issueId));
      } else {
        emit(state.copyWith(error: 'Issue 不存在', isLoading: false));
      }
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isLoading: false));
      LogService.e('获取 Issue 详情失败', e);
    }
  }

  Future<void> _onLoadComments(IssueDetailLoadComments event, Emitter<IssueDetailState> emit) async {
    emit(state.copyWith(isLoadingComments: true));
    try {
      final response = await _issueApi.getComments(event.issueId);
      emit(state.copyWith(comments: response.items, isLoadingComments: false));
    } catch (e) {
      LogService.e('获取评论失败', e);
      emit(state.copyWith(isLoadingComments: false));
    }
  }

  Future<void> _onToggleVote(IssueDetailToggleVote event, Emitter<IssueDetailState> emit) async {
    if (state.issue == null) return;
    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      final issue = state.issue!;
      VoteResponse? response;
      if (issue.isVoted) {
        response = await _issueApi.unvote(issue.id);
      } else {
        response = await _issueApi.vote(issue.id);
      }
      if (response != null) {
        emit(state.copyWith(issue: issue.copyWith(voteCount: response.voteCount, isVoted: response.isVoted), isSubmitting: false));
      } else {
        emit(state.copyWith(isSubmitting: false));
      }
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isSubmitting: false));
      LogService.e('投票失败', e);
    }
  }

  Future<void> _onAddComment(IssueDetailAddComment event, Emitter<IssueDetailState> emit) async {
    if (state.issue == null || _currentIssueId == null) return;
    emit(state.copyWith(isSubmitting: true, clearError: true, clearSuccess: true));

    try {
      final response = await _issueApi.addComment(_currentIssueId!, event.content, images: event.images);
      if (response != null) {
        // 接口返回简化数据，需要构建完整的评论对象
        final comment = IssueComment(
          id: response.id,
          issueId: _currentIssueId!,
          authorId: int.tryParse(_currentUser?.uid ?? '0') ?? 0,
          authorName: _currentUser?.username ?? '我',
          authorAvatar: _currentUser?.avatar,
          isAdmin: false,
          content: response.content,
          images: event.images ?? [],
          createdAt: response.createdAt,
          updatedAt: null,
        );
        final updatedComments = [...state.comments, comment];
        final updatedIssue = state.issue!.copyWith(commentCount: state.issue!.commentCount + 1);
        emit(state.copyWith(comments: updatedComments, issue: updatedIssue, isSubmitting: false, successMessage: '评论发表成功'));
      } else {
        emit(state.copyWith(isSubmitting: false));
      }
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isSubmitting: false));
      LogService.e('发表评论失败', e);
    }
  }

  Future<void> _onClose(IssueDetailClose event, Emitter<IssueDetailState> emit) async {
    if (state.issue == null) return;
    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      final success = await _issueApi.closeIssue(state.issue!.id);
      if (success) {
        emit(state.copyWith(issue: state.issue!.copyWith(status: 'closed'), isSubmitting: false, successMessage: 'Issue 已关闭'));
      } else {
        emit(state.copyWith(isSubmitting: false));
      }
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isSubmitting: false));
      LogService.e('关闭 Issue 失败', e);
    }
  }

  Future<void> _onReopen(IssueDetailReopen event, Emitter<IssueDetailState> emit) async {
    if (state.issue == null) return;
    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      final success = await _issueApi.reopenIssue(state.issue!.id);
      if (success) {
        emit(state.copyWith(issue: state.issue!.copyWith(status: 'open'), isSubmitting: false, successMessage: 'Issue 已重新开放'));
      } else {
        emit(state.copyWith(isSubmitting: false));
      }
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isSubmitting: false));
      LogService.e('重开 Issue 失败', e);
    }
  }

  void _onClearError(IssueDetailClearError event, Emitter<IssueDetailState> emit) {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }

  void _onReset(IssueDetailReset event, Emitter<IssueDetailState> emit) {
    _currentIssueId = null;
    emit(const IssueDetailState());
  }

  void _onUpdate(IssueDetailUpdate event, Emitter<IssueDetailState> emit) {
    emit(state.copyWith(issue: event.issue));
  }
}
