// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import '../models/activity_model.dart';

class ActivityApi {
  ActivityApi._();

  static final ActivityApi instance = ActivityApi._();

  Future<List<ActivityModel>> getActivities() async {
    throw UnimplementedError('Stub');
  }

  Future<ActivityModel?> getActivity(int id) async {
    throw UnimplementedError('Stub');
  }
}
