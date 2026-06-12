// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import '../models/server_models.dart';
import '../models/map_contribution_models.dart';

class ServerApi {
  Future<List<ServerCategory>> getServerList() async { throw UnimplementedError('Stub'); }
  Future<MapData?> getMapInfo(String mapName) async { throw UnimplementedError('Stub'); }
  Future<MapRuntimeData?> getMapRuntime(String address, String mapName) async { throw UnimplementedError('Stub'); }
  Future<ServerHistoryData?> getServerHistory({required String address, int pageIndex = 1, int pageSize = 10, String? mapName}) async { throw UnimplementedError('Stub'); }
  Future<MapHistoryResponse?> getMapHistory(MapHistoryRequest request) async { throw UnimplementedError('Stub'); }
  void clearMapInfoCache() {}
  void clearMapInfoCacheForMap(String mapName) {}
  Future<MapData?> refreshMapInfo(String mapName) async { throw UnimplementedError('Stub'); }
  void clearServerListCache() {}
  bool isServerListCacheValid() => false;
  Future<List<ServerCategory>> refreshServerList() async { throw UnimplementedError('Stub'); }
  Future<Map<String, dynamic>> getCacheInfo() async => {};
}
