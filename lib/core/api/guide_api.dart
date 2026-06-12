// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import '../models/guide_models.dart';
import '../models/map_contribution_models.dart';

/// 攻略列表查询参数
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

  const GuideListQuery({
    this.page = 1,
    this.pageSize = 20,
    this.mapName,
    this.category,
    this.sortBy,
    this.keyword,
    this.tags,
    this.hasVideo,
    this.authorId,
    this.status,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'pagination': {'pageIndex': page, 'pageSize': pageSize},
    };
    if (mapName != null) json['mapName'] = mapName;
    if (category != null) json['category'] = category;
    if (sortBy != null) json['sortBy'] = sortBy!.value;
    if (keyword != null && keyword!.isNotEmpty) json['keyword'] = keyword;
    if (tags != null && tags!.isNotEmpty) json['tags'] = tags;
    if (hasVideo != null) json['hasVideo'] = hasVideo;
    if (authorId != null) json['authorId'] = authorId;
    if (status != null) json['status'] = status!.value;
    return json;
  }
}

/// 攻略列表响应
class GuideListResponse {
  final int total;
  final List<GuideListItem> items;
  final List<GuideListItem> pinned;

  const GuideListResponse({
    required this.total,
    required this.items,
    this.pinned = const [],
  });

  factory GuideListResponse.fromJson(Map<String, dynamic> json) {
    return GuideListResponse(
      total: json['total'] as int? ?? 0,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => GuideListItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pinned: (json['pinned'] as List<dynamic>?)
              ?.map((e) => GuideListItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// 创建攻略请求
class CreateGuideRequest {
  final String title;
  final String? summary;
  final String? coverUrl;
  final String? category;
  final List<String> tags;
  final String? mapName;
  final String? content;
  final List<Map<String, dynamic>>? videoEmbeds;

  const CreateGuideRequest({
    required this.title,
    this.summary,
    this.coverUrl,
    this.category,
    this.tags = const [],
    this.mapName,
    this.content,
    this.videoEmbeds,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'title': title};
    if (summary != null) json['summary'] = summary;
    if (coverUrl != null) json['coverUrl'] = coverUrl;
    if (category != null) json['category'] = category;
    if (tags.isNotEmpty) json['tags'] = tags;
    if (mapName != null) json['mapName'] = mapName;
    if (content != null) json['content'] = content;
    if (videoEmbeds != null) json['videoEmbeds'] = videoEmbeds;
    return json;
  }
}

/// 更新攻略请求
class UpdateGuideRequest {
  final String? title;
  final String? summary;
  final String? coverUrl;
  final String? category;
  final List<String>? tags;
  final String? mapName;
  final String? content;
  final List<Map<String, dynamic>>? videoEmbeds;

  const UpdateGuideRequest({
    this.title,
    this.summary,
    this.coverUrl,
    this.category,
    this.tags,
    this.mapName,
    this.content,
    this.videoEmbeds,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (title != null) json['title'] = title;
    if (summary != null) json['summary'] = summary;
    if (coverUrl != null) json['coverUrl'] = coverUrl;
    if (category != null) json['category'] = category;
    if (tags != null) json['tags'] = tags;
    if (mapName != null) json['mapName'] = mapName;
    if (content != null) json['content'] = content;
    if (videoEmbeds != null) json['videoEmbeds'] = videoEmbeds;
    return json;
  }
}

/// 草稿列表响应
class GuideDraftListResponse {
  final int total;
  final List<GuideDraft> items;

  const GuideDraftListResponse({required this.total, required this.items});

  factory GuideDraftListResponse.fromJson(dynamic json) {
    if (json is List) {
      final items =
          json.whereType<Map<String, dynamic>>().map(GuideDraft.fromJson).toList();
      return GuideDraftListResponse(total: items.length, items: items);
    }
    if (json is Map<String, dynamic>) {
      final total = json['total'] as int? ?? 0;
      final list = json['items'] as List<dynamic>? ??
          json['list'] as List<dynamic>? ??
          json['data'] as List<dynamic>? ??
          [];
      final items =
          list.whereType<Map<String, dynamic>>().map(GuideDraft.fromJson).toList();
      return GuideDraftListResponse(total: total, items: items);
    }
    return const GuideDraftListResponse(total: 0, items: []);
  }
}

/// 草稿保存响应
sealed class DraftSaveResponse {
  const DraftSaveResponse();
}

/// 草稿保存成功
class DraftSaveSuccess extends DraftSaveResponse {
  final String draftId;
  final int version;
  final DateTime? updatedAt;

  const DraftSaveSuccess({
    required this.draftId,
    required this.version,
    this.updatedAt,
  });
}

/// 草稿保存冲突
class DraftSaveConflict extends DraftSaveResponse {
  final GuideDraft remote;

  const DraftSaveConflict({required this.remote});
}

/// 攻略评论列表响应
class GuideCommentListResponse {
  final int total;
  final List<GuideComment> items;

  const GuideCommentListResponse({required this.total, required this.items});

  factory GuideCommentListResponse.fromJson(Map<String, dynamic> json) {
    return GuideCommentListResponse(
      total: json['total'] as int? ?? 0,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => GuideComment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// 发表评论请求体
class AddCommentRequest {
  final String content;
  final List<String>? images;
  final int? parentId;
  final int? replyToId;
  final String? replyToName;

  const AddCommentRequest({
    required this.content,
    this.images,
    this.parentId,
    this.replyToId,
    this.replyToName,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'content': content};
    if (images != null && images!.isNotEmpty) json['images'] = images;
    if (parentId != null) json['parentId'] = parentId;
    if (replyToId != null) json['replyToId'] = replyToId;
    if (replyToName != null) json['replyToName'] = replyToName;
    return json;
  }
}

/// 我的攻略列表查询参数
class GuideMineQuery {
  final int page;
  final int pageSize;
  final GuideStatus? status;
  final bool onlyDeleted;

  const GuideMineQuery({
    this.page = 1,
    this.pageSize = 20,
    this.status,
    this.onlyDeleted = false,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'pagination': {'pageIndex': page, 'pageSize': pageSize},
    };
    if (status != null) json['status'] = status!.value;
    if (onlyDeleted) json['onlyDeleted'] = true;
    return json;
  }
}

/// 攻略社区 API 服务
class GuideApi {
  Future<GuideListResponse> getGuides({GuideListQuery query = const GuideListQuery()}) async {
    throw UnimplementedError('Stub');
  }

  Future<Guide?> getGuideDetail(int id) async {
    throw UnimplementedError('Stub');
  }

  Future<List<GuideListItem>> getRelated(int id) async {
    throw UnimplementedError('Stub');
  }

  Future<Guide?> createGuide(CreateGuideRequest request) async {
    throw UnimplementedError('Stub');
  }

  Future<Guide?> updateGuide(int id, UpdateGuideRequest request) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> publishGuide(int id) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> deleteGuide(int id) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> restoreGuide(int id) async {
    throw UnimplementedError('Stub');
  }

  Future<DraftSaveResponse> saveDraft(GuideDraft draft) async {
    throw UnimplementedError('Stub');
  }

  Future<GuideDraftListResponse> getDrafts({int page = 1, int pageSize = 10}) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> deleteDraft(String draftId) async {
    throw UnimplementedError('Stub');
  }

  Future<GuideDraft?> getDraftDetail(String draftId) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> like(int id) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> unlike(int id) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> favorite(int id) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> unfavorite(int id) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> view(int id) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> share(int id, {String? channel}) async {
    throw UnimplementedError('Stub');
  }

  Future<GuideCommentListResponse> getComments(
    int guideId, {
    int page = 1,
    int pageSize = 20,
    String sort = 'latest',
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<GuideComment?> addComment(int guideId, AddCommentRequest request) async {
    throw UnimplementedError('Stub');
  }

  Future<List<GuideComment>> getReplies(int commentId, {int page = 1, int pageSize = 20}) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> likeComment(int commentId) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> unlikeComment(int commentId) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> dislikeComment(int commentId) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> undislikeComment(int commentId) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> deleteComment(int guideId, int commentId) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> report(GuideReport report) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> block(int userId) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> unblock(int userId) async {
    throw UnimplementedError('Stub');
  }

  Future<GuideUserStats> getMineStats() async {
    throw UnimplementedError('Stub');
  }

  Future<GuideListResponse> getMine({GuideMineQuery query = const GuideMineQuery()}) async {
    throw UnimplementedError('Stub');
  }

  Future<GuideListResponse> getFavorites({int page = 1, int pageSize = 20}) async {
    throw UnimplementedError('Stub');
  }

  Future<GuideListResponse> getLiked({int page = 1, int pageSize = 20}) async {
    throw UnimplementedError('Stub');
  }

  Future<List<GuideCategoryDef>> getCategories() async {
    throw UnimplementedError('Stub');
  }

  Future<List<MapInfo>> getMaps({int page = 1, int pageSize = 50, String? keyword}) async {
    throw UnimplementedError('Stub');
  }

  Future<List<String>> suggestTags(String keyword) async {
    throw UnimplementedError('Stub');
  }
}
