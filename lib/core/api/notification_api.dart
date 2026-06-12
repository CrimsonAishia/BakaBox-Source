// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import '../models/notification_models.dart';

class NotificationApi {
  Future<NotificationListResponse?> getNotifications({int page = 1, int pageSize = 20, String? type, bool? isRead}) async { throw UnimplementedError('Stub'); }
  Future<void> markAsRead(int id) async { throw UnimplementedError('Stub'); }
  Future<void> markAllAsRead() async { throw UnimplementedError('Stub'); }
  Future<void> deleteNotification(int id) async { throw UnimplementedError('Stub'); }
  Future<int> getUnreadCount() async { throw UnimplementedError('Stub'); }
}
