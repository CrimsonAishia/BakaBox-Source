import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_io.dart'
    as platform_info;
import 'store_detection_utils.dart';

/// 平台工具类 - 提供全局的平台检测功能
class PlatformUtils {
  PlatformUtils._();

  static const double desktopBreakpoint = 800.0;
  static const double tabletBreakpoint = 600.0;

  static bool get isWeb => kIsWeb;
  static bool get isMobile =>
      !kIsWeb && (platform_info.isAndroid || platform_info.isIOS);
  static bool get isAndroid => !kIsWeb && platform_info.isAndroid;
  static bool get isIOS => !kIsWeb && platform_info.isIOS;
  static bool get isWindows => !kIsWeb && platform_info.isWindows;
  static bool get isDesktopPlatform => !kIsWeb && platform_info.isWindows;

  /// 检测是否从 Microsoft Store 安装（同步版本）
  ///
  /// 注意：首次使用前建议先调用 StoreDetectionUtils.isInstalledFromStore() 初始化
  /// 这个同步版本使用缓存结果，适合在 getter 中使用
  static bool get isInstalledFromStore {
    return StoreDetectionUtils.isInstalledFromStoreSync();
  }

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
    return platform_info.getOperatingSystem();
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
      'isInstalledFromStore': isInstalledFromStore,
      if (context != null) ...{
        'isDesktopLayout': isDesktop(context),
        'isTabletLayout': isTablet(context),
        'isMobileLayout': isMobileLayout(context),
        'deviceType': getDeviceType(context),
        'screenWidth': MediaQuery.of(context).size.width,
        'screenHeight': MediaQuery.of(context).size.height,
      },
    };
  }
}
