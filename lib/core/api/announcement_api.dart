// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import '../models/announcement_models.dart';

class AnnouncementApi {
  Future<AnnouncementListResponse?> getActiveAnnouncements({int limit = 10}) async {
    throw UnimplementedError('Stub');
  }

  Future<AnnouncementListResponse?> getStickyAnnouncements({int limit = 5}) async {
    throw UnimplementedError('Stub');
  }

  Future<AnnouncementItem?> getAnnouncementDetail(int id) async {
    throw UnimplementedError('Stub');
  }
}
