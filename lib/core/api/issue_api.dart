// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import '../models/issue_models.dart';

class IssueApi {
  Future<IssueListResponse> getIssues({
    int page = 1, int pageSize = 20, String? type,
    String status = 'open', String sort = 'created_at DESC', String? keyword,
  }) async { throw UnimplementedError('Stub'); }

  Future<Issue?> getIssueDetail(int id) async { throw UnimplementedError('Stub'); }
  Future<CreateIssueResponse?> createIssue(CreateIssueRequest request) async { throw UnimplementedError('Stub'); }
  Future<Issue?> updateIssue(int id, {String? title, String? content}) async { throw UnimplementedError('Stub'); }
  Future<bool> closeIssue(int id) async { throw UnimplementedError('Stub'); }
  Future<bool> reopenIssue(int id) async { throw UnimplementedError('Stub'); }
  Future<VoteResponse?> vote(int id) async { throw UnimplementedError('Stub'); }
  Future<VoteResponse?> unvote(int id) async { throw UnimplementedError('Stub'); }

  Future<CommentListResponse> getComments(int issueId, {int page = 1, int pageSize = 50}) async {
    throw UnimplementedError('Stub');
  }

  Future<CreateCommentResponse?> addComment(
    int issueId, String content, {List<String>? images, int? replyToId,}
  ) async { throw UnimplementedError('Stub'); }

  Future<IssueListResponse> getMyIssues({
    int page = 1, int pageSize = 20, String? type,
    String status = 'all', String sort = 'created_at DESC',
  }) async { throw UnimplementedError('Stub'); }
}
