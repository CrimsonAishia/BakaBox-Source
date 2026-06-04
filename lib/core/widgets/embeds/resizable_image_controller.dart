import 'package:flutter/foundation.dart';

/// 可缩放图片的全局选中协调器
///
/// 确保同一时间只有一张图片处于选中态。
///
/// 每个 RichTextEditor 实例持有一个独立的 controller，
/// 通过 InheritedWidget 向下传递给各个图片 embed。
class ResizableImageController extends ChangeNotifier {
  /// 当前选中的图片节点的 documentOffset（null 表示无选中）
  int? _selectedOffset;

  int? get selectedOffset => _selectedOffset;

  bool isSelected(int offset) => _selectedOffset == offset;

  /// 选中指定 offset 的图片
  void select(int offset) {
    _lastSelectAt = DateTime.now();
    if (_selectedOffset == offset) return;
    _selectedOffset = offset;
    notifyListeners();
  }

  /// 最近一次选中的时间（用于防止选中后立即被光标同步取消）
  DateTime? _lastSelectAt;

  /// 距离上次选中是否在保护期内（防抖）
  bool get isInSelectionGuard {
    final t = _lastSelectAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < const Duration(milliseconds: 350);
  }

  /// 取消所有选中
  void clearSelection() {
    if (_selectedOffset == null) return;
    _selectedOffset = null;
    notifyListeners();
  }
}
