import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/bloc/bloc.dart';
import '../screens/mobile_splash_screen.dart';
import '../screens/issues_mobile.dart';
import '../screens/issue_detail_mobile.dart';
import '../screens/issue_create_mobile.dart';
import '../app.dart';

/// 移动端路由路径
class MobileRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String issues = '/issues';
  static const String issueDetail = '/issues/:id';
  static const String issueCreate = '/issues/create';
}

/// 移动端路由配置
class MobileRouter {
  static final GoRouter router = GoRouter(
    initialLocation: MobileRoutes.splash,
    routes: [
      GoRoute(
        path: MobileRoutes.splash,
        name: 'splash',
        builder: (context, state) => const MobileSplashScreen(),
      ),
      GoRoute(
        path: MobileRoutes.home,
        name: 'home',
        builder: (context, state) => const MobileAppHome(),
      ),
      GoRoute(
        path: MobileRoutes.issues,
        name: 'issues',
        builder: (context, state) => BlocProvider(
          create: (_) => IssueBloc()..add(const IssueFetch()),
          child: const IssuesMobile(),
        ),
      ),
      GoRoute(
        path: MobileRoutes.issueCreate,
        name: 'issueCreate',
        builder: (context, state) => BlocProvider(
          create: (_) => IssueBloc(),
          child: const IssueCreateMobile(),
        ),
      ),
      GoRoute(
        path: MobileRoutes.issueDetail,
        name: 'issueDetail',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return BlocProvider(
            create: (_) => IssueDetailBloc()..add(IssueDetailFetch(id)),
            child: IssueDetailMobile(issueId: id),
          );
        },
      ),
    ],
  );
}
