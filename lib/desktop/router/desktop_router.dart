import 'package:go_router/go_router.dart';
import '../screens/desktop_splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../app.dart';

/// 桌面端路由路径
class DesktopRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String servers = '/servers';
  static const String serverDetail = '/servers/:id';
  static const String updateLogs = '/update-logs';
  static const String settings = '/settings';
  static const String tools = '/tools';
  static const String welcome = '/welcome';
}

/// 桌面端路由配置
class DesktopRouter {
  static final GoRouter router = GoRouter(
    initialLocation: DesktopRoutes.splash,
    routes: [
      GoRoute(
        path: DesktopRoutes.splash,
        name: 'splash',
        builder: (context, state) => const DesktopSplashScreen(),
      ),
      GoRoute(
        path: DesktopRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => OnboardingScreen(
          onComplete: () => router.go(DesktopRoutes.home),
        ),
      ),
      GoRoute(
        path: DesktopRoutes.home,
        name: 'home',
        builder: (context, state) => const DesktopAppHome(),
      ),
    ],
  );
}
