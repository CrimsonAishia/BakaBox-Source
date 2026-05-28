import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../core/core.dart';
import '../core/services/app_info_service.dart';
import 'router/mobile_router.dart';
import 'theme/mobile_theme.dart';
import 'screens/mobile_home_screen.dart';

/// 移动端应用入口
class MobileApp extends StatefulWidget {
  const MobileApp({super.key});

  @override
  State<MobileApp> createState() => _MobileAppState();
}

class _MobileAppState extends State<MobileApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    // 初始化应用目录服务（缓存和日志目录）
    await AppDirectoryService.init();
    // 初始化 Hive 存储
    await StorageUtils.init();
    // 初始化应用信息服务（版本号等）
    await AppInfoService.instance.init();
    // 初始化日志服务
    await LogService.init();
    // 初始化广播通知服务
    await BroadcastNotificationService.instance.init();
    // 初始化前台保活服务配置（Android 平台）
    AppPermissionService.initForegroundService();

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ServerBloc()),
        BlocProvider(create: (_) => ServerStatsBloc()),
        BlocProvider(create: (_) => UpdateLogBloc()),
        BlocProvider(create: (_) => UpdateBloc()),
        BlocProvider(create: (_) => SettingsBloc()..add(SettingsInit())),
        BlocProvider(
          create: (_) => AuthBloc()..add(const AuthCheckRequested()),
        ),
        BlocProvider(create: (_) => DailyTaskBloc()),
        BlocProvider(
          create: (_) => NotificationBloc()
            ..add(const NotificationFetchUnreadCount())
            ..add(const NotificationStartAutoRefresh()),
        ),
        BlocProvider(
          create: (_) => AnnouncementBloc()
            ..add(AnnouncementFetch())
            ..add(AnnouncementStartAutoRefresh()),
        ),
      ],
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          return MaterialApp.router(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
            theme: MobileTheme.lightTheme,
            darkTheme: MobileTheme.darkTheme,
            themeMode: settingsState.themeMode,
            routerConfig: MobileRouter.router,
          );
        },
      ),
    );
  }
}

/// 移动端主页，负责处理自动更新检查
class MobileAppHome extends StatefulWidget {
  const MobileAppHome({super.key});

  @override
  State<MobileAppHome> createState() => _MobileAppHomeState();
}

class _MobileAppHomeState extends State<MobileAppHome> {
  bool _hasShownAutoUpdateDialog = false; // 是否已显示自动检查的更新对话框

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBlocs();
      _checkForUpdate();
    });
  }

  void _initializeBlocs() {
    context.read<ServerBloc>().add(ServerStartPeriodicRefresh());

    // 首帧渲染完成，上报启动统计
    AnalyticsService.instance.reportStartupIfNeeded();
  }

  void _checkForUpdate() {
    final updateBloc = context.read<UpdateBloc>();

    // 检查启动屏幕是否已经检测到更新
    if (updateBloc.state.hasUpdate &&
        updateBloc.state.updateInfo != null &&
        !_hasShownAutoUpdateDialog) {
      _hasShownAutoUpdateDialog = true;
      UpdateDialog.show(context, updateBloc.state.updateInfo!);
    }
    // 后续更新状态变化通过 BlocListener 监听，避免内存泄漏
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UpdateBloc, UpdateState>(
      listenWhen: (prev, curr) {
        // 监听两种情况：
        // 1. 状态从非 available 变为 available（有更新）
        // 2. 状态从 checking 变为 idle（无更新）
        final hasNewUpdate =
            prev.status != UpdateStatus.available &&
            curr.status == UpdateStatus.available &&
            curr.updateInfo != null;

        final checkCompleteNoUpdate =
            prev.status == UpdateStatus.checking &&
            curr.status == UpdateStatus.idle &&
            curr.updateInfo != null &&
            !curr.updateInfo!.hasUpdate;

        return hasNewUpdate || checkCompleteNoUpdate;
      },
      listener: (context, state) {
        if (state.status == UpdateStatus.available &&
            state.updateInfo != null) {
          // 有更新：弹出更新对话框
          UpdateDialog.show(context, state.updateInfo!);
        } else if (state.status == UpdateStatus.idle &&
            state.updateInfo != null &&
            !state.updateInfo!.hasUpdate) {
          // 无更新：显示提示
          ToastUtils.showSuccess(context, '已是最新版本');
        }
      },
      child: const MobileHomeScreen(),
    );
  }
}
