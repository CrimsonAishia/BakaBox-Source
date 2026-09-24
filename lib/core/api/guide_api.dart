// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import '../models/guide_models.dart';
import '../models/map_contribution_models.dart';

class GuideListQuery {
  final int page;
  final int pageSize;
  final String? mapName;
  final String? category;
  final GuideSortBy? sortBy;
  final String? keyword;
  final List<String>? tags;
  final bool? hasVideo;
  final int? authorId;
  final GuideStatus? status;
  const GuideListQuery({this.page = 1, this.pageSize = 20, this.mapName, this.category, this.sortBy, this.keyword, this.tags, this.hasVideo, this.authorId, this.status});
}

class GuideListResponse {
  final int total;
  final List<GuideListItem> items;
  final List<GuideListItem> pinned;
  const GuideListResponse({required this.total, required this.items, this.pinned = const []});
}

class CreateGuideRequest {
  final String title;
  final String? summary;
  final String? coverUrl;
  final String? category;
  final List<String> tags;
  final String? mapName;
  final String? content;
  final List<Map<String, dynamic>>? videoEmbeds;
  const CreateGuideRequest({required this.title, this.summary, this.coverUrl, this.category, this.tags = const [], this.mapName, this.content, this.videoEmbeds});
}

class UpdateGuideRequest {
  final String? title;
  final String? summary;
  final String? coverUrl;
  final String? category;
  final List<String>? tags;
  final String? mapName;
  final String? content;
  final List<Map<String, dynamic>>? videoEmbeds;
  const UpdateGuideRequest({this.title, this.summary, this.coverUrl, this.category, this.tags, this.mapName, this.content, this.videoEmbeds});
}

class GuideDraftListResponse {
  final int total;
  final List<GuideDraft> items;
  const GuideDraftListResponse({required this.total, required this.items});
}

sealed class DraftSaveResponse { const DraftSaveResponse(); }

class DraftSaveSuccess extends DraftSaveResponse {
  final String draftId;
  final int version;
  final DateTime? updatedAt;
  const DraftSaveSuccess({required this.draftId, required this.version, this.updatedAt});
}

class DraftSaveConflict extends DraftSaveResponse {
  final GuideDraft remote;
  const DraftSaveConflict({required this.remote});
}

class GuideCommentListResponse {
  final int total;
  final List<GuideComment> items;
  const GuideCommentListResponse({required this.total, required this.items});
}

class AddCommentRequest {
  final String content;
  final List<String>? images;
  final int? parentId;
  final int? replyToId;
  final String? replyToName;
  const AddCommentRequest({required this.content, this.images, this.parentId, this.replyToId, this.replyToName});
}

class GuideMineQuery {
  final int page;
  final int pageSize;
  final GuideStatus? status;
  final bool onlyDeleted;
  const GuideMineQuery({this.page = 1, this.pageSize = 20, this.status, this.onlyDeleted = false});
}

class GuideApi {
  Future<GuideListResponse> getGuides({GuideListQuery query = const GuideListQuery()}) async { throw UnimplementedError('Stub'); }
  Future<Guide?> getGuideDetail(int id) async { throw UnimplementedError('Stub'); }
  Future<List<GuideListItem>> getRelated(int id) async { throw UnimplementedError('Stub'); }
  Future<Guide?> createGuide(CreateGuideRequest request) async { throw UnimplementedError('Stub'); }
  Future<Guide?> updateGuide(int id, UpdateGuideRequest request) async { throw UnimplementedError('Stub'); }
  Future<bool> publishGuide(int id) async { throw UnimplementedError('Stub'); }
  Future<bool> deleteGuide(int id) async { throw UnimplementedError('Stub'); }
  Future<bool> restoreGuide(int id) async { throw UnimplementedError('Stub'); }
  Future<DraftSaveResponse> saveDraft(GuideDraft draft) async { throw UnimplementedError('Stub'); }
  Future<GuideDraftListResponse> getDrafts({int page = 1, int pageSize = 10}) async { throw UnimplementedError('Stub'); }
  Future<bool> deleteDraft(String draftId) async { throw UnimplementedError('Stub'); }
  Future<GuideDraft?> getDraftDetail(String draftId) async { throw UnimplementedError('Stub'); }
  Future<bool> like(int id) async { throw UnimplementedError('Stub'); }
  Future<bool> unlike(int id) async { throw UnimplementedError('Stub'); }
  Future<bool> favorite(int id) async { throw UnimplementedError('Stub'); }
  Future<bool> unfavorite(int id) async { throw UnimplementedError('Stub'); }
  Future<bool> view(int id) async { throw UnimplementedError('Stub'); }
  Future<bool> share(int id, {String? channel}) async { throw UnimplementedError('Stub'); }
  Future<GuideCommentListResponse> getComments(int guideId, {int page = 1, int pageSize = 20, String sort = 'latest'}) async { throw UnimplementedError('Stub'); }
  Future<GuideComment?> addComment(int guideId, AddCommentRequest request) async { throw UnimplementedError('Stub'); }
  Future<List<GuideComment>> getReplies(int commentId, {int page = 1, int pageSize = 20}) async { throw UnimplementedError('Stub'); }
  Future<bool> likeComment(int commentId) async { throw UnimplementedError('Stub'); }
  Future<bool> unlikeComment(int commentId) async { throw UnimplementedError('Stub'); }
  Future<bool> dislikeComment(int commentId) async { throw UnimplementedError('Stub'); }
  Future<bool> undislikeComment(int commentId) async { throw UnimplementedError('Stub'); }
  Future<bool> deleteComment(int guideId, int commentId) async { throw UnimplementedError('Stub'); }
  Future<bool> report(GuideReport report) async { throw UnimplementedError('Stub'); }
  Future<bool> block(int userId) async { throw UnimplementedError('Stub'); }
  Future<bool> unblock(int userId) async { throw UnimplementedError('Stub'); }
  Future<GuideUserStats> getMineStats() async { throw UnimplementedError('Stub'); }
  Future<GuideListResponse> getMine({GuideMineQuery query = const GuideMineQuery()}) async { throw UnimplementedError('Stub'); }
  Future<GuideListResponse> getFavorites({int page = 1, int pageSize = 20}) async { throw UnimplementedError('Stub'); }
  Future<GuideListResponse> getLiked({int page = 1, int pageSize = 20}) async { throw UnimplementedError('Stub'); }
  Future<List<GuideCategoryDef>> getCategories() async { throw UnimplementedError('Stub'); }
  Future<List<MapInfo>> getMaps({int page = 1, int pageSize = 50, String? keyword}) async { throw UnimplementedError('Stub'); }
  Future<List<String>> suggestTags(String keyword) async { throw UnimplementedError('Stub'); }
}
