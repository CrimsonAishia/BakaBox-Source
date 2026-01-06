import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/log_service.dart';

/// 公告已读状态服务
///
/// 负责管理公告的已读状态，使用 SharedPreferences 存储
class AnnouncementReadService {
  static const String _storageKey = 'announcement_read_ids';

  /// 标记公告为已读
  ///
  /// 参数:
  /// - [announcementId]: 公告ID
  Future<void> markAsRead(int announcementId) async {
    try {
      final readIds = await getReadIds();
      if (readIds.contains(announcementId)) {
        return; // 已经标记为已读
      }

      readIds.add(announcementId);
      await _saveReadIds(readIds);
      LogService.d('公告已标记为已读: $announcementId');
    } catch (e) {
      LogService.e('标记公告已读失败', e);
    }
  }

  /// 检查公告是否已读
  ///
  /// 参数:
  /// - [announcementId]: 公告ID
  ///
  /// 返回:
  /// - [bool]: 是否已读
  Future<bool> isRead(int announcementId) async {
    try {
      final readIds = await getReadIds();
      return readIds.contains(announcementId);
    } catch (e) {
      LogService.e('检查公告已读状态失败', e);
      return false;
    }
  }

  /// 获取所有已读公告ID
  ///
  /// 返回:
  /// - [Set<int>]: 已读公告ID集合
  Future<Set<int>> getReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);

      if (jsonStr == null || jsonStr.isEmpty) {
        return <int>{};
      }

      final List<dynamic> jsonList = json.decode(jsonStr);
      return jsonList.map((e) => e as int).toSet();
    } catch (e) {
      LogService.e('获取已读公告ID失败', e);
      return <int>{};
    }
  }

  /// 清除已读状态
  Future<void> clearReadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      LogService.i('已清除公告已读状态');
    } catch (e) {
      LogService.e('清除公告已读状态失败', e);
    }
  }

  /// 保存已读ID到本地存储
  Future<void> _saveReadIds(Set<int> readIds) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(readIds.toList());
    await prefs.setString(_storageKey, jsonStr);
  }
}
