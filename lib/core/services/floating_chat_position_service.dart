import 'package:hive/hive.dart';

import '../utils/log_service.dart';

/// 悬浮聊天按钮位置持久化服务
///
/// 将按钮在父容器中的位置 (left, top) 持久化到本地，
/// 以便重启应用后恢复用户上次拖动的位置。
class FloatingChatPositionService {
  static const String _hiveBoxName = 'floating_chat';
  static const String _keyLeft = 'button_left';
  static const String _keyTop = 'button_top';

  /// 读取已保存的按钮位置。
  ///
  /// 返回 `(left, top)`，若未保存过则返回 `null`。
  static Future<({double left, double top})?> loadPosition() async {
    try {
      final box = await Hive.openBox(_hiveBoxName);
      final left = box.get(_keyLeft);
      final top = box.get(_keyTop);
      if (left is num && top is num) {
        return (left: left.toDouble(), top: top.toDouble());
      }
    } catch (e) {
      LogService.w('读取悬浮聊天按钮位置失败: $e');
    }
    return null;
  }

  /// 保存按钮位置。
  static Future<void> savePosition(double left, double top) async {
    try {
      final box = await Hive.openBox(_hiveBoxName);
      await box.put(_keyLeft, left);
      await box.put(_keyTop, top);
    } catch (e) {
      LogService.w('保存悬浮聊天按钮位置失败: $e');
    }
  }
}
