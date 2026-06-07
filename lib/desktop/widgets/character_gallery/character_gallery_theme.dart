import 'package:flutter/material.dart';

/// 角色图鉴主题颜色常量
class CharacterGalleryTheme {
  CharacterGalleryTheme._();

  // ===== 亮色模式颜色 =====
  /// 和纸米黄
  static const washiColorLight = Color(0xFFF5F0E6);

  /// 卷轴木纹棕
  static const scrollBrownLight = Color(0xFF8B4513);

  /// 墨色
  static const inkColorLight = Color(0xFF2C1810);

  // ===== 暗色模式颜色 =====
  /// 暗色和纸（深灰带暖调）
  static const washiColorDark = Color(0xFF2A2520);

  /// 暗色卷轴棕（柔和的棕色）
  static const scrollBrownDark = Color(0xFFB8956A);

  /// 暗色墨色（浅色文字）
  static const inkColorDark = Color(0xFFE8E0D8);

  // ===== 通用颜色（两种模式共用） =====
  /// 朱红
  static const vermillion = Color(0xFFC41E3A);

  /// 亮红色（暗色模式用）
  static const vermillionBright = Color(0xFFFF5A6E);

  /// 金色
  static const gold = Color(0xFFD4AF37);

  /// 亮金色（暗色模式用）
  static const goldBright = Color(0xFFFFD966);

  /// 樱花粉
  static const sakuraPink = Color(0xFFFFB7C5);

  // ===== 静态颜色（兼容旧代码） =====
  static const washiColor = washiColorLight;
  static const scrollBrown = scrollBrownLight;
  static const inkColor = inkColorLight;

  /// 根据当前主题获取和纸颜色
  static Color getWashiColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? washiColorDark
        : washiColorLight;
  }

  /// 根据当前主题获取卷轴棕色
  static Color getScrollBrown(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? scrollBrownDark
        : scrollBrownLight;
  }

  /// 根据当前主题获取墨色
  static Color getInkColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? inkColorDark
        : inkColorLight;
  }

  /// 根据当前主题获取卡片背景色
  static Color getCardBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF352F2A)
        : Colors.white;
  }

  /// 根据当前主题获取输入框背景色
  static Color getInputBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3D3632)
        : Colors.white;
  }

  /// 根据当前主题获取半透明白色/黑色
  /// 浅色模式下透明度会自动提高到 0.7
  static Color getOverlayColor(BuildContext context, {double alpha = 0.5}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return Colors.black.withValues(alpha: alpha);
    } else {
      // 浅色模式下提高透明度
      final lightAlpha = (alpha + 0.2).clamp(0.0, 1.0);
      return Colors.white.withValues(alpha: lightAlpha);
    }
  }

  /// 根据当前主题获取分隔线颜色
  static Color getDividerColor(BuildContext context) {
    final scrollBrown = getScrollBrown(context);
    return scrollBrown.withValues(alpha: 0.3);
  }

  /// 根据当前主题获取阴影颜色
  static Color getShadowColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.15);
  }

  /// 根据当前主题获取朱红色（暗色模式下更亮）
  static Color getVermillion(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? vermillionBright
        : vermillion;
  }

  /// 根据当前主题获取金色（暗色模式下更亮）
  static Color getGold(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? goldBright : gold;
  }

  // ===== 属性数值颜色（冷却、伤害、消耗等） =====

  /// 冷却时间颜色（青色系）
  static Color getCooldownColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF26A69A) // 暗色模式：亮青色
        : const Color(0xFF00796B); // 浅色模式：深青色
  }

  /// 伤害颜色（红色系）
  static Color getDamageColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE57373) // 暗色模式：浅红色
        : const Color(0xFFD32F2F); // 浅色模式：深红色
  }

  /// P点消耗颜色（蓝色系）
  static Color getPCostColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF64B5F6) // 暗色模式：浅蓝色
        : const Color(0xFF1976D2); // 浅色模式：深蓝色
  }

  /// 范围颜色（棕色系，使用 scrollBrown）
  static Color getRangeColor(BuildContext context) {
    return getScrollBrown(context);
  }

  /// 特殊效果颜色（紫色系）
  static Color getSpecialColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFBA68C8) // 暗色模式：浅紫色
        : const Color(0xFF7B1FA2); // 浅色模式：深紫色
  }

  /// B点消耗颜色（橙色系）
  static Color getBCostColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? goldBright // 暗色模式：亮金色
        : const Color(0xFFFF8000); // 浅色模式：橙色 rgb(255,128,0)
  }

  /// 自定义来源颜色（紫色系）
  static Color getCustomSourceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFCE93D8) // 暗色模式：浅紫色
        : const Color(0xFF9C27B0); // 浅色模式：深紫色
  }

  // 颜色按字段语义选取，避免与上面已有的 cooldown/damage/P点/B点/range/special 撞色。

  /// 弹幕初速颜色（青色系，流动/速度感）
  static Color getSpeedColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF4DD0E1) // 暗色模式：浅 cyan
        : const Color(0xFF0097A7); // 浅色模式：深 cyan
  }

  /// 弹幕数量颜色（蓝紫色系，群体感）
  static Color getCountColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9575CD) // 暗色模式：浅蓝紫
        : const Color(0xFF5E35B1); // 浅色模式：深蓝紫
  }

  /// 散射角度颜色（黄绿色系，扇形/光线感）
  static Color getAngleColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFC0CA33) // 暗色模式：亮黄绿
        : const Color(0xFF827717); // 浅色模式：深橄榄
  }

  /// 穿刺次数颜色（玫红系，锐利穿透感）
  static Color getPunctureColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF06292) // 暗色模式：粉玫红
        : const Color(0xFFAD1457); // 浅色模式：深玫红
  }

  /// 反弹次数颜色（金黄系，弹性活力感）
  static Color getBounceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFF176) // 暗色模式：浅柠檬黄
        : const Color(0xFFFBC02D); // 浅色模式：金黄
  }

  /// 影响范围颜色（火橙红系，爆炸扩散感）
  static Color getExplodeColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFF8A65) // 暗色模式：浅橙红
        : const Color(0xFFD84315); // 浅色模式：深橙红
  }

  /// 持续时间颜色（茶褐系，沙漏/时间感）
  static Color getHoldTimeColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFA1887F) // 暗色模式：浅茶褐
        : const Color(0xFF6D4C41); // 浅色模式：深茶褐
  }

  /// 追踪转向颜色（翠绿系，瞄准锁定感）
  static Color getTrackSpeedColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF81C784) // 暗色模式：浅翠绿
        : const Color(0xFF2E7D32); // 浅色模式：深翠绿
  }

  /// 内置CD逻辑颜色（蓝灰系，配置/中性标志）
  static Color getCustomCdColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB0BEC5) // 暗色模式：浅蓝灰
        : const Color(0xFF546E7A); // 浅色模式：深蓝灰
  }

  /// 符卡/技能整卡蒙版装饰
  static BoxDecoration getCardBottomGradientDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                Colors.black.withValues(alpha: 0.0),
                Colors.black.withValues(alpha: 0.1),
                Colors.black.withValues(alpha: 0.8),
              ]
            : [
                Colors.white.withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.96),
              ],
        // 加深拐点上移到 0.3，给两排 stats 留出足够蒙版高度
        stops: const [0.0, 0.3, 1.0],
      ),
    );
  }
}
