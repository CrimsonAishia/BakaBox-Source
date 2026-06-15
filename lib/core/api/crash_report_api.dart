// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import '../models/crash_report_models.dart';

/// CS2 崩溃报告 API
class CrashReportApi {
  Future<CrashReportListResponse> getReports({
    int page = 1,
    int pageSize = 20,
    String severity = 'all',
    String category = 'all',
    String? module,
    String? keyword,
    String? signature,
    String sort = 'created_at DESC',
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<CrashReportDetail?> getReportDetail(int id) async {
    throw UnimplementedError('Stub');
  }

  /// 匿名上传一份崩溃报告
  Future<int?> uploadReport(Map<String, dynamic> body) async {
    throw UnimplementedError('Stub');
  }

  Future<CrashReportStats?> getStats() async {
    throw UnimplementedError('Stub');
  }
}
