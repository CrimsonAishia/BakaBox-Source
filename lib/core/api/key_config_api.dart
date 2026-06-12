// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import '../models/key_config_models.dart';
import '../models/user_info.dart';

class KeyConfigApi {
  Future<KeyConfigListResponse?> getConfigList({int page = 1, int pageSize = 100, int? categoryId, String? keyword, bool? isActive}) async { throw UnimplementedError('Stub'); }
  Future<KeyConfigListResponse?> getMyConfigList({int page = 1, int pageSize = 100, int? categoryId, String? keyword}) async { throw UnimplementedError('Stub'); }
  Future<List<KeyConfigCategory>> getCategories() async { throw UnimplementedError('Stub'); }
  Future<KeyConfig?> createConfig(KeyConfigCreateRequest request) async { throw UnimplementedError('Stub'); }
  Future<bool> deleteConfig(int id, {String? editReason}) async { throw UnimplementedError('Stub'); }
  Future<KeyConfig?> updateConfig(int id, KeyConfigCreateRequest request, {String? editReason}) async { throw UnimplementedError('Stub'); }
  Future<BackendUserInfo?> getUserByUid(String uid) async { throw UnimplementedError('Stub'); }
  Future<KeyConfigVoteResponse?> vote(int id, KeyConfigVoteType voteType) async { throw UnimplementedError('Stub'); }
  Future<void> useConfig(int id) async { throw UnimplementedError('Stub'); }
  Future<KeyConfigCommentListResponse> getComments(int configId, {int page = 1, int pageSize = 20}) async { throw UnimplementedError('Stub'); }
  Future<KeyConfigComment?> addComment(int configId, String content, {List<String>? images, int? replyToId}) async { throw UnimplementedError('Stub'); }
  Future<void> cancelChangeRequest(int configId) async { throw UnimplementedError('Stub'); }
  Future<KeyConfigChangeRequestListResponse?> getMyChangeRequests({int page = 1, int pageSize = 20}) async { throw UnimplementedError('Stub'); }
}
