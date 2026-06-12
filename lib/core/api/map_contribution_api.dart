// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import '../models/map_contribution_models.dart';

class MapContributionApi {
  Future<List<MapContribution>> getNameContributions(String mapName) async { throw UnimplementedError('Stub'); }
  Future<List<MapContribution>> getBackgroundContributions(String mapName) async { throw UnimplementedError('Stub'); }
  Future<MapContribution?> submitNameContribution(String mapName, String name) async { throw UnimplementedError('Stub'); }
  Future<MapContribution?> submitBackgroundContribution(String mapName, int fileId) async { throw UnimplementedError('Stub'); }
  Future<ContributionVoteResponse?> toggleVote(int contributionId, VoteType voteType) async { throw UnimplementedError('Stub'); }
  Future<MapContribution?> updateNameContribution(int id, String name) async { throw UnimplementedError('Stub'); }
  Future<MapContribution?> updateBackgroundContribution(int id, int fileId) async { throw UnimplementedError('Stub'); }
  Future<bool> deleteNameContribution(int id) async { throw UnimplementedError('Stub'); }
  Future<bool> deleteBackgroundContribution(int id) async { throw UnimplementedError('Stub'); }
  Future<MapListResponse?> getAllMaps(MapListRequest request) async { throw UnimplementedError('Stub'); }
  Future<MapContributionListResponse?> getMyContributions(MapContributionListRequest request) async { throw UnimplementedError('Stub'); }
}
