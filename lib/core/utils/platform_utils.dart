import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 平台工具类 - 提供全局的平台检测功能
class PlatformUtils {
  PlatformUtils._();

  static const double desktopBreakpoint = 800.0;
  static const double tabletBreakpoint = 600.0;

  static bool get isWeb => kIsWeb;
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isDesktopPlatform => !kIsWeb && Platform.isWindows;

  /// 根据屏幕尺寸判断是否为桌面布局
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width > desktopBreakpoint;
  }

  /// 根据屏幕尺寸判断是否为平板布局
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width > tabletBreakpoint && width <= desktopBreakpoint;
  }

  /// 根据屏幕尺寸判断是否为手机布局
  static bool isMobileLayout(BuildContext context) {
    return MediaQuery.of(context).size.width <= tabletBreakpoint;
  }

  static String getDeviceType(BuildContext context) {
    if (isDesktop(context)) return 'desktop';
    if (isTablet(context)) return 'tablet';
    return 'mobile';
  }

  static String get platformName {
    if (kIsWeb) return 'web';
    return Platform.operatingSystem;
  }

  static Map<String, dynamic> getPlatformInfo(BuildContext? context) {
    return {
      'platform': platformName,
      'isWeb': isWeb,
      'isMobile': isMobile,
      'isAndroid': isAndroid,
      'isIOS': isIOS,
      'isWindows': isWindows,
      'isDesktopPlatform': isDesktopPlatform,
      if (context != null) ...{
        'isDesktopLayout': isDesktop(context),
        'isTabletLayout': isTablet(context),
        'isMobileLayout': isMobileLayout(context),
        'deviceType': getDeviceType(context),
        'screenWidth': MediaQuery.of(context).size.width,
        'screenHeight': MediaQuery.of(context).size.height,
      }
    };
  }
}
