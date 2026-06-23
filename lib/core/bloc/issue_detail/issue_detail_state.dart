import 'package:equatable/equatable.dart';
import '../../models/issue_models.dart';

class IssueDetailState extends Equatable {
  final Issue? issue;
  final List<IssueComment> comments;
  final bool isLoading;
  final bool isLoadingComments;
  final bool isLoadingMoreComments;
  final bool hasMoreComments;
  final bool hasLoadMoreError;
  final int commentsCurrentPage;
  final bool isSubmitting;
  final String? error;
  final String? successMessage;

  const IssueDetailState({
    this.issue,
    this.comments = const [],
    this.isLoading = false,
    this.isLoadingComments = false,
    this.isLoadingMoreComments = false,
    this.hasMoreComments = true,
    this.hasLoadMoreError = false,
    this.commentsCurrentPage = 1,
    this.isSubmitting = false,
    this.error,
    this.successMessage,
  });

  bool get hasIssue => issue != null;
  bool get canComment => hasIssue && !isSubmitting;
  bool get canVote => hasIssue && !isSubmitting;

  IssueDetailState copyWith({
    Issue? issue,
    List<IssueComment>? comments,
    bool? isLoading,
    bool? isLoadingComments,
    bool? isLoadingMoreComments,
    bool? hasMoreComments,
    bool? hasLoadMoreError,
    int? commentsCurrentPage,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return IssueDetailState(
      issue: issue ?? this.issue,
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      isLoadingComments: isLoadingComments ?? this.isLoadingComments,
      isLoadingMoreComments: isLoadingMoreComments ?? this.isLoadingMoreComments,
      hasMoreComments: hasMoreComments ?? this.hasMoreComments,
      hasLoadMoreError: hasLoadMoreError ?? this.hasLoadMoreError,
      commentsCurrentPage: commentsCurrentPage ?? this.commentsCurrentPage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
    issue,
    comments,
    isLoading,
    isLoadingComments,
    isLoadingMoreComments,
    hasMoreComments,
    hasLoadMoreError,
    commentsCurrentPage,
    isSubmitting,
    error,
    successMessage,
  ];
}
