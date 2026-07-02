// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import '../models/map_tag_models.dart';
import '../models/report_models.dart';

/// 地图标签 API 服务
class MapTagApi {
  Future<List<MapTag>> getTagList() async { throw UnimplementedError('Stub'); }

  Future<MapTag?> submitTag(
    String name, {
    String? mapName,
    String? color,
    String? address,
  }) async { throw UnimplementedError('Stub'); }

  Future<MapTagServerListResponse?> getMapTagServers(String mapName) async {
    throw UnimplementedError('Stub');
  }

  Future<MapTagListSimpleResponse?> getMapTagList(
    String mapName, {
    String? address,
  }) async { throw UnimplementedError('Stub'); }

  Future<TagVoteResponse?> voteTag(
    String mapName,
    int tagId, {
    String? voteType,
    String? address,
  }) async { throw UnimplementedError('Stub'); }

  Future<bool> updateTag(
    int tagId,
    String name, {
    String? color,
    String? editReason,
  }) async { throw UnimplementedError('Stub'); }

  Future<bool> deleteTag(int tagId, {String? editReason}) async {
    throw UnimplementedError('Stub');
  }

  Future<bool> cancelTagChangeRequest(int tagId) async {
    throw UnimplementedError('Stub');
  }

  Future<List<MapTag>> getMyTags({String? auditStatus}) async {
    throw UnimplementedError('Stub');
  }

  Future<MapAllTagVotesResponse?> getMapAllTagUserVotes(
    String mapName, {
    int pageIndex = 1,
    int pageSize = 20,
    String? address,
  }) async { throw UnimplementedError('Stub'); }

  Future<TagUserVotesResponse?> getTagUserVotes(
    String mapName,
    int tagId, {
    int pageIndex = 1,
    int pageSize = 20,
    String? address,
  }) async { throw UnimplementedError('Stub'); }

  Future<List<MapTagChangeRequest>> getMyTagChangeRequests() async {
    throw UnimplementedError('Stub');
  }

  Future<bool> reportVote(MapTagVoteReport report) async {
    throw UnimplementedError('Stub');
  }
}
