// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import 'package:dio/dio.dart';
import '../models/update_models.dart';

class UpdateApi {
  Future<AppUpdateInfo> checkForUpdate() async { throw UnimplementedError('Stub'); }

  Future<String> downloadUpdate(
    String downloadUrl, String savePath,
    void Function(DownloadProgress) onProgress, {
    CancelToken? cancelToken,
  }) async { throw UnimplementedError('Stub'); }

  Future<void> reportUpdateResult(UpdateReportRequest request) async {}
}
