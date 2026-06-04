/// 攻略社区桌面端通用格式化与布局工具
library;

/// 攻略卡片网格在不同视口宽度下的列数
///
/// - ≥ 1280px → 4 列
/// - ≥ 1024px → 3 列
/// - ≥ 720px  → 2 列
/// - 否则     → 1 列
int guideCrossAxisCount(double width) {
  if (width >= 1280) return 4;
  if (width >= 1024) return 3;
  if (width >= 720) return 2;
  return 1;
}

/// 数字简化为 W/K 短格式
///
/// 例：12_345 → "1.2w"，1_500 → "1.5K"，500 → "500"
String formatGuideCount(int n) {
  if (n >= 10000) {
    final w = n / 10000;
    return '${w.toStringAsFixed(w.truncateToDouble() == w ? 0 : 1)}w';
  }
  if (n >= 1000) {
    final k = n / 1000;
    return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}K';
  }
  return n.toString();
}
