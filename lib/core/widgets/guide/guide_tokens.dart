import 'package:flutter/material.dart';
import '../../models/guide_models.dart';

/// 攻略社区设计 Tokens
///
/// 集中定义所有颜色、间距、圆角、阴影、动效常量。
/// 禁止内联 `Color(0xFF...)`，统一从 `Theme.of(context)` 或本文件取色。
///
/// 参考: docs/implementation_plan.md §13.2 / §13.6 / §13.7
class GuideTokens {
  GuideTokens._();

  // ─── 底色 (Backgrounds & Surfaces) ─────────────────────────────────────────

  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);

  static Color cardSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? surfaceDark
          : Colors.white;

  // ─── 互动色 ─────────────────────────────────────────────────────────────────
  // 亮色
  static const Color likeRed = Color(0xFFFF4D6D);
  static const Color favoriteAmber = Color(0xFFF5A623);
  static const Color commentBlue = Color(0xFF0080FF);
  static const Color shareGreen = Color(0xFF22C55E);

  // 暗色（饱和度 −10）
  static const Color likeRedDark = Color(0xFFFF6B85);
  static const Color favoriteAmberDark = Color(0xFFFFB84D);
  static const Color commentBlueDark = Color(0xFF1A8DFF);
  static const Color shareGreenDark = Color(0xFF34D06B);

  /// 根据亮暗模式返回对应的互动色
  static Color likeColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? likeRedDark : likeRed;

  static Color favoriteColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? favoriteAmberDark
          : favoriteAmber;

  static Color commentColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? commentBlueDark
          : commentBlue;

  static Color shareColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? shareGreenDark
          : shareGreen;

  // ─── 状态色 ─────────────────────────────────────────────────────────────────

  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusRejected = Color(0xFFEF4444);
  static const Color statusOffShelf = Color(0xFF64748B);

  // ─── 分类色 fallback 表 ────────────────────────────────────────────────────
  // 仅在分类接口下发的 colorHex 为空时使用，key 与 GuideCategoryDef.code 一致。
  // 未知 code 时回退到主色。
  static const Map<String, Color> categoryColorsFallback = {
    'ze': Color(0xFF8B5CF6), // 紫
    'zi': Color(0xFFEF4444), // 红
    'movement': Color(0xFF10B981), // 绿
    'lineup': Color(0xFFF59E0B), // 橙
    'general': Color(0xFF64748B), // 灰蓝
    'announcement': Color(0xFF0080FF), // 主色
  };

  /// 解析分类色：接口下发优先（colorHex），fallback 表次之（按 code 精确匹配），主色兜底。
  ///
  /// 注意：此函数仅服务于颜色字段缺失的容忍，不为分类接口整体失败兜底。
  /// 分类接口失败时 UI 应显式降级（隐藏分类 Tab + 错误提示 + 重试按钮）。
  static Color categoryColor(GuideCategoryDef def, BuildContext context) {
    if (def.colorHex != null && def.colorHex!.isNotEmpty) {
      return hexToColor(def.colorHex!);
    }
    return categoryColorsFallback[def.code] ??
        Theme.of(context).colorScheme.primary;
  }

  // ─── 已发布状态色 ──────────────────────────────────────────────────────────

  static const Color statusPublished = Color(0xFF10B981);

  // ─── 占位 / 降级色（用于封面 fallback、边框、图标占位等）──────────────────────

  /// 暗色封面 fallback 背景
  static const Color fallbackBgDark = Color(0xFF334155);

  /// 亮色封面 fallback 背景
  static const Color fallbackBgLight = Color(0xFFF1F5F9);

  /// Shimmer 高光色（暗色模式）
  static const Color shimmerHighlightDark = Color(0xFF475569);

  /// Shimmer 高光色（亮色模式）= borderLight
  static const Color shimmerHighlightLight = Color(0xFFE2E8F0);

  /// 占位图标色
  static const Color fallbackIcon = Color(0xFF94A3B8);

  /// 亮色边框/分隔线
  static const Color borderLight = Color(0xFFE2E8F0);

  /// 亮色容器背景（轻微灰）
  static const Color surfaceLight = Color(0xFFF8FAFC);

  /// 对话框 / Dropdown 暗色背景
  static const Color dialogBgDark = Color(0xFF1E293B);

  /// 输入框聚焦边框色（同 commentBlue / 主色）
  static const Color focusBorderColor = Color(0xFF0080FF);

  /// 暗色渐变起始
  static const Color gradientDarkStart = Color(0xFF1E293B);

  /// 暗色渐变结束
  static const Color gradientDarkEnd = Color(0xFF0F172A);

  /// 错误相关浅底色
  static const Color errorSurfaceLight = Color(0xFFFEF2F2);

  /// 错误相关浅边框色
  static const Color errorBorderLight = Color(0xFFFECACA);

  /// 信息底色（用于选中状态等）
  static const Color infoSurfaceLight = Color(0xFFEFF6FF);

  /// 必填星号色（同 statusRejected）
  static const Color requiredMark = Color(0xFFEF4444);

  /// 封面 fallback 背景（根据亮暗自动选择）
  static Color fallbackBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? fallbackBgDark
          : fallbackBgLight;

  /// 边框色（根据亮暗自动选择）
  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.1)
          : borderLight;

  /// 对话框背景色（根据亮暗自动选择）
  static Color dialogBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? dialogBgDark
          : Colors.white;

  // ─── 文本语义色（补充 textTheme 之外的场景）──────────────────────────────────

  static const Color textPrimaryLight = Color(0xFF1F2937);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textTertiaryLight = Color(0xFF9CA3AF);

  static const Color textPrimaryDark = Color(0xFFE2E8F0);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textTertiaryDark = Color(0xFF94A3B8);

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? textPrimaryDark
          : textPrimaryLight;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? textSecondaryDark
          : textSecondaryLight;

  static Color textTertiary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? textTertiaryDark
          : textTertiaryLight;

  // ─── 分隔 / 描边 ───────────────────────────────────────────────────────────

  static Color divider(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06);

  // ─── 玻璃面 ─────────────────────────────────────────────────────────────────

  static Color glassSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F172A).withValues(alpha: 0.80)
          : Colors.white.withValues(alpha: 0.65);

  /// 玻璃面模糊半径
  static const double glassBlurSigma = 24.0;

  /// 玻璃面描边色
  static Color glassBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.30);

  // ─── 间距（4 的倍数，米游社风格紧凑型）─────────────────────────────────────

  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;

  /// 卡片内填充
  static const EdgeInsets cardPadding = EdgeInsets.all(space12);

  /// 区块间距
  static const double sectionGap = space24;

  /// 卡片间距（纵 / 横）
  static const double cardGap = space16;

  // ─── 圆角 ──────────────────────────────────────────────────────────────────

  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius24 = 24.0;

  static const BorderRadius borderRadius8 = BorderRadius.all(Radius.circular(radius8));
  static const BorderRadius borderRadius12 = BorderRadius.all(Radius.circular(radius12));
  static const BorderRadius borderRadius16 = BorderRadius.all(Radius.circular(radius16));
  static const BorderRadius borderRadius20 = BorderRadius.all(Radius.circular(radius20));
  static const BorderRadius borderRadius24 = BorderRadius.all(Radius.circular(radius24));

  // ─── 阴影（3 档）──────────────────────────────────────────────────────────

  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          blurRadius: 4,
          offset: const Offset(0, 2),
          color: Colors.black.withValues(alpha: 0.04),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          blurRadius: 16,
          offset: const Offset(0, 8),
          color: Colors.black.withValues(alpha: 0.12),
        ),
      ];

  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          blurRadius: 32,
          offset: const Offset(0, 16),
          color: Colors.black.withValues(alpha: 0.20),
        ),
      ];

  // ─── 动效时长（§13.6 统一节奏）────────────────────────────────────────────

  /// 卡片 hover / Tab 切换 / 阅读进度条
  static const Duration durationFast = Duration(milliseconds: 200);

  /// 评论展开楼中楼
  static const Duration durationNormal = Duration(milliseconds: 280);

  /// 列表 item 进入
  static const Duration durationMedium = Duration(milliseconds: 320);

  /// 详情页 Hero 封面切换
  static const Duration durationSlow = Duration(milliseconds: 360);

  /// FAB 点赞 +1 浮起（最长允许值）
  static const Duration durationMax = Duration(milliseconds: 600);

  // ─── B 站品牌色 ──────────────────────────────────────────────────────────────

  /// B 站粉（品牌主色）
  static const Color bilibiliPink = Color(0xFFFB7299);

  /// B 站视频卡片 placeholder 暗色背景
  static const Color bilibiliPlaceholderDark = Color(0xFF1A1A1A);

  /// B 站视频卡片 fallback 亮色背景
  static const Color bilibiliFallbackLight = Color(0xFFF9FAFB);

  /// B 站对话框 / 输入框边框亮色
  static const Color bilibiliInputBorderLight = Color(0xFFE5E7EB);

  // ─── 工具方法 ───────────────────────────────────────────────────────────────

  /// 将 hex 字符串转为 Color。支持 `#RRGGBB` / `RRGGBB` / `#AARRGGBB` / `AARRGGBB`。
  ///
  /// 所有需要解析 hex 颜色的场景统一使用此方法，禁止内联 `Color(int.parse(...))`。
  static Color hexToColor(String hex) {
    String cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    }
    return Color(int.parse(cleaned, radix: 16));
  }
}
