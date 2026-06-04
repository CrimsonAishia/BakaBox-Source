/// 可缩放图片的宽度/网格计算工具
///
/// 当前交互仅支持点击式操作（工具栏 +/- 调整宽度、三键对齐），
/// 不再包含拖拽吸附相关逻辑。
class ResizableImageSnap {
  const ResizableImageSnap._();

  /// 宽度主吸附点（+/- 按钮的步进档位）
  static const List<double> widthSnapPoints = [
    0.25,
    0.333,
    0.50,
    0.667,
    0.75,
    1.0,
  ];

  /// 网格总列数
  static const int gridColumns = 24;

  /// 宽度允许范围
  static const double minWidth = 0.2;
  static const double maxWidth = 1.0;

  /// 计算宽度对应的网格列数
  static int widthToCols(double width) {
    return (width * gridColumns).round().clamp(3, gridColumns);
  }

  /// 根据对齐方式计算 gridCol
  ///
  /// [align] 0=左, 1=居中, 2=右
  static int alignToGridCol(int align, int widthCols) {
    final maxCol = gridColumns - widthCols;
    if (maxCol <= 0) return 0;
    switch (align) {
      case 0:
        return 0;
      case 1:
        return (maxCol / 2).round();
      case 2:
        return maxCol;
      default:
        return 0;
    }
  }

  /// 判断当前 gridCol 属于哪种对齐（用于工具栏高亮）
  ///
  /// 返回 0=左, 1=居中, 2=右, -1=自定义
  static int gridColToAlign(int gridCol, int widthCols) {
    final maxCol = gridColumns - widthCols;
    if (maxCol <= 0) return 1; // 占满整行视为居中
    if (gridCol == 0) return 0;
    if (gridCol == maxCol) return 2;
    if (gridCol == (maxCol / 2).round()) return 1;
    return -1;
  }

  /// 找到最接近 current 宽度的主吸附点（用于 +/- 按钮的步进）
  static double nextSnapPoint(double current, {required bool increase}) {
    if (increase) {
      for (final snap in widthSnapPoints) {
        if (snap > current + 0.001) return snap;
      }
      return maxWidth;
    } else {
      for (final snap in widthSnapPoints.reversed) {
        if (snap < current - 0.001) return snap;
      }
      return minWidth;
    }
  }

  /// 将宽度格式化为百分比文字
  static String formatPercent(double width) {
    return '${(width * 100).round()}%';
  }
}
