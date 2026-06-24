import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_portal/flutter_portal.dart';

import '../core/core.dart';
import '../core/bootstrap/app_initializer.dart';
import '../core/services/game_launcher_service.dart';
import '../core/services/game_status_service.dart';
import '../core/services/gsi_service.dart';
import '../core/services/policy_service.dart';
import '../core/services/obs_server_service.dart';
import '../core/services/queue_guard_service.dart';
import '../core/services/score_upload_service.dart';
import '../core/services/server_address_mapping_service.dart';
import 'router/desktop_router.dart';
import '../core/services/console_log_service.dart';
import '../core/services/cs2_crash_monitor_service.dart';
import '../core/services/crash_report_uploader.dart';
import '../core/services/map_change_monitor_service.dart';

import '../core/services/update_log_monitor_service.dart';
import '../core/services/warmup_monitor_service.dart';
import 'theme/desktop_theme.dart';
import 'screens/desktop_home_screen.dart';
import 'widgets/exit_dialog.dart';
import 'widgets/policy_update_dialog.dart';

/// 桌面端应用入口
class DesktopApp extends StatefulWidget {
  const DesktopApp({super.key});

  @override
  State<DesktopApp> createState() => _DesktopAppState();
}

class _DesktopAppState extends State<DesktopApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // 设置关闭前的处理
    windowManager.setPreventClose(true);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    final behavior = context.read<SettingsBloc>().state.appExitBehavior;
    await ExitDialog.handleWindowClose(context, behavior: behavior);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // 全局 Bloc - 所有页面共享
        BlocProvider(
          create: (_) => AuthBloc()..add(const AuthCheckRequested()),
        ),
        BlocProvider(create: (_) => ServerBloc()),
        BlocProvider(
          create: (_) => ServerStatsBloc()..add(const ServerStatsFetch()),
        ),
        BlocProvider(create: (_) => UpdateLogBloc()),
        BlocProvider(create: (_) => UpdateBloc()),
        BlocProvider(create: (_) => SettingsBloc()..add(SettingsInit())),
        BlocProvider(create: (_) => AnnouncementBloc()),
        BlocProvider(create: (_) => DailyTaskBloc()),
        BlocProvider(create: (_) => CharacterGalleryBloc()),
        BlocProvider(create: (_) => BilibiliContentBloc()),
        BlocProvider(
          create: (_) => NotificationBloc()
            ..add(const NotificationFetchUnreadCount())
            ..add(const NotificationStartRealtime()),
        ),
        BlocProvider(
          create: (_) =>
              MapSubscriptionBloc()..add(const MapSubscriptionLoad()),
        ),
        BlocProvider(create: (_) => LobbyBloc()),
        BlocProvider(create: (_) => MapCdBloc()),
        BlocProvider(
          create: (context) {
            final bloc = GuideCategoriesBloc();
            AppInitializer.preheatGuideCategories(bloc);
            return bloc;
          },
        ),
      ],
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          return Portal(
            child: MaterialApp.router(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                FlutterQuillLocalizations.delegate,
              ],
              supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
              builder: (context, child) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Stack(
                  children: [
                    // 内容层：裁剪圆角
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        color: isDark
                            ? AppColors.slate900
                            : const Color(0xFFE9EEF8),
                        child: child,
                      ),
                    ),
                    // 边框层
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              theme: DesktopTheme.lightTheme,
              darkTheme: DesktopTheme.darkTheme,
              themeMode: settingsState.themeMode,
              routerConfig: DesktopRouter.router,
            ),
          );
        },
      ),
    );
  }
}

/// 桌面端主页，负责处理自动更新检查
class DesktopAppHome extends StatefulWidget {
  const DesktopAppHome({super.key});

  @override
  State<DesktopAppHome> createState() => _DesktopAppHomeState();
}

class _DesktopAppHomeState extends State<DesktopAppHome> {
  bool _hasShownAutoUpdateDialog = false; // 是否已显示自动检查的更新对话框

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPolicyUpdate();
      _initializeServices();
      _listenForUpdate();
    });
  }

  /// 检查协议更新
  Future<void> _checkPolicyUpdate() async {
    try {
      final policyService = PolicyService();
      final needsReAgreement = await policyService.needsReAgreement();

      if (needsReAgreement && mounted) {
        // 显示协议更新对话框（不可关闭，必须同意）
        await PolicyUpdateDialog.show(context);
      }
    } catch (e) {
      LogService.e('[DesktopAppHome] 检查协议更新失败', e);
    }
  }

  Future<void> _initializeServices() async {
    try {
      // 首帧渲染完成，上报启动统计
      AnalyticsService.instance.reportStartupIfNeeded();

      // 启动实时推送服务（弱网模式下跳过）
      if (!NetworkModeService.instance.weakNetwork) {
        await RealtimeService().start();
        // 启动地图信息缓存失效器（监听 map.info 频道）
        RealtimeMapInfoInvalidator().start();
      } else {
        LogService.i('[DesktopAppHome] 弱网模式开启，跳过 Realtime 主推送启动');
      }

      // 启动 GSI 服务（独立服务，不依赖其他服务）
      final gsiService = GsiService();
      await gsiService.initialize();
      await gsiService.start();

      // 配置 Steam 启动选项（添加 -condebug，在 GSI 启动后执行）
      final launcher = GameLauncherService();
      await launcher.ensureCondebugConfigured();

      // 启动游戏状态监控（桌面端专属，需要先完成初始检测）
      await GameStatusService().startMonitoring();

      // 启动控制台日志监控（依赖 GameStatusService 的状态流）
      await ConsoleLogService().startMonitoring();

      // 刷新 OBS 服务的 ConsoleLog 状态（确保获取到用户当前所在的服务器）
      ObsServerService().refreshConsoleLogStatus();

      // 以下服务依赖 ConsoleLogService，需要在其启动完成后初始化
      MapChangeMonitorService().initialize();
      WarmupMonitorService().initialize();
      MapSubscriptionService().initialize();

      // 启动 CS2 崩溃 (mdmp) 监控（依赖 GameStatusService 状态流）
      Cs2CrashMonitorService().initialize();
      CrashReportUploader().initialize();

      // 初始化大厅素材 URL 缓存（需要在 LobbyNakamaService 之前初始化）
      await LobbyAssetCacheService.instance.init();

      // 初始化大厅占位服务
      await LobbyNakamaService.instance.initialize();

      // 初始化更新日志监控服务
      UpdateLogMonitorService().initialize();

      // 初始化比分上传服务（依赖 GsiService 和 ConsoleLogService）
      await ScoreUploadService().initialize();

      // 加载地址映射（挤服守护进程依赖；ObsServerService.start 也会加载，
      // 但 OBS 未启用时不会被调用，因此这里独立兜底）
      ServerAddressMappingService().load();

      // 启动挤服守护进程（依赖 ConsoleLogService、GsiService 和 ServerAddressMappingService）
      QueueGuardService().start();
    } catch (e) {
      LogService.e('[DesktopAppHome] 初始化服务时出错', e);
    }
  }

  void _listenForUpdate() {
    final updateBloc = context.read<UpdateBloc>();

    // 检查启动屏幕是否已经检测到更新
    if (updateBloc.state.hasUpdate &&
        updateBloc.state.updateInfo != null &&
        !_hasShownAutoUpdateDialog) {
      _hasShownAutoUpdateDialog = true;
      UpdateDialog.show(context, updateBloc.state.updateInfo!);
    }

    // 监听后续更新状态变化（如手动检查更新）
    // 使用 BlocListener 替代 stream.listen 避免内存泄漏
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('当前已是最新版本'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: const DesktopHomeScreen(),
    );
  }
}
