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
  static Color getOverlayColor(BuildContext context, {double alpha = 0.5}) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: alpha)
        : Colors.white.withValues(alpha: alpha);
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
    return Theme.of(context).brightness == Brightness.dark
        ? goldBright
        : gold;
  }
}
