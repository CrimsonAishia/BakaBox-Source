// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import '../models/server_score.dart';

class ScoreApi {
  Future<String?> uploadScore({
    required String serverAddress, required String steamId,
    required int ctScore, required int tScore,
    required int round, required String mapName, bool isFinal = false,
  }) async { throw UnimplementedError('Stub'); }

  Future<Map<String, ServerScore>> fetchScoresBatch(List<String> serverAddresses) async {
    throw UnimplementedError('Stub');
  }
}
