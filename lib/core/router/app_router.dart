import 'package:go_router/go_router.dart';
import '../utils/platform_utils.dart';
import '../../desktop/router/desktop_router.dart';
import '../../mobile/router/mobile_router.dart';

/// 获取当前平台的路由
GoRouter getAppRouter() {
  return PlatformUtils.isDesktopPlatform
      ? DesktopRouter.router
      : MobileRouter.router;
}
