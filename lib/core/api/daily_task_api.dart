// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

class DailyTaskRecordDto {
  final String taskType;
  final int rewardAmount;
  final String createdAt;
  DailyTaskRecordDto({required this.taskType, required this.rewardAmount, required this.createdAt});
}

class DailyTaskApi {
  static Future<void> recordTask(String taskType, int rewardAmount) async { throw UnimplementedError('Stub'); }
  static Future<List<DailyTaskRecordDto>> getTodayRecords() async { throw UnimplementedError('Stub'); }
  static Future<List<DailyTaskRecordDto>> getMonthRecords(int year, int month) async { throw UnimplementedError('Stub'); }
}
