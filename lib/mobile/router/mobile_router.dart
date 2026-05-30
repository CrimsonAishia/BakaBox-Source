import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/bloc/bloc.dart';
import '../../core/models/character_models.dart';
import '../screens/mobile_splash_screen.dart';
import '../screens/issues_mobile.dart';
import '../screens/issue_detail_mobile.dart';
import '../screens/issue_create_mobile.dart';
import '../screens/notifications_mobile.dart';
import '../screens/settings_page_mobile.dart';
import '../screens/character_gallery_mobile.dart';
import '../screens/character_detail_mobile.dart';
import '../screens/update_logs_mobile.dart';
import '../screens/map_database_mobile.dart';
import '../screens/bilibili_content_mobile.dart';
import '../app.dart';

/// 移动端路由路径
class MobileRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String issues = '/issues';
  static const String issueDetail = '/issues/:id';
  static const String issueCreate = '/issues/create';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String characterGallery = '/character-gallery';
  static const String characterDetail = '/character-gallery/:id';
  static const String updateLogs = '/update-logs';
  static const String mapDatabase = '/map-database';
  static const String bilibiliContent = '/bilibili-content';
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
      GoRoute(
        path: MobileRoutes.notifications,
        name: 'notifications',
        builder: (context, state) => const NotificationsMobile(),
      ),
      GoRoute(
        path: MobileRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsPageMobile(),
      ),
      GoRoute(
        path: MobileRoutes.characterGallery,
        name: 'characterGallery',
        builder: (context, state) => BlocProvider(
          create: (_) =>
              CharacterGalleryBloc()
                ..add(const ChangeCategory(CharacterCategory.touhou)),
          child: const CharacterGalleryMobile(),
        ),
      ),
      GoRoute(
        path: MobileRoutes.characterDetail,
        name: 'characterDetail',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final subModelId = int.tryParse(
            state.uri.queryParameters['subModelId'] ?? '',
          );
          return BlocProvider(
            create: (_) =>
                CharacterGalleryBloc()
                  ..add(LoadCharacterDetail(id, initialSubModelId: subModelId)),
            child: CharacterDetailMobile(
              characterId: id,
              initialSubModelId: subModelId,
            ),
          );
        },
      ),
      GoRoute(
        path: MobileRoutes.updateLogs,
        name: 'updateLogs',
        builder: (context, state) => const UpdateLogsMobile(),
      ),
      GoRoute(
        path: MobileRoutes.mapDatabase,
        name: 'mapDatabase',
        builder: (context, state) => const MapDatabaseMobile(),
      ),
      GoRoute(
        path: MobileRoutes.bilibiliContent,
        name: 'bilibiliContent',
        builder: (context, state) => BlocProvider(
          create: (_) => BilibiliContentBloc(),
          child: const BilibiliContentMobile(),
        ),
      ),
    ],
  );
}
