import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:window_manager/window_manager.dart';

import '../core/core.dart';
import '../core/services/game_status_service.dart';
import '../core/services/gsi_service.dart';
import '../core/services/policy_service.dart';
import 'router/desktop_router.dart';
import '../core/services/console_log_service.dart';
import '../core/services/map_change_monitor_service.dart';
import '../core/services/update_log_monitor_service.dart';
import '../core/services/warmup_monitor_service.dart';
import 'theme/desktop_theme.dart';
import 'screens/desktop_home_screen.dart';
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
    // 先隐藏窗口，用户看到窗口立即消失
    // 然后异步销毁，避免卡顿感
    await windowManager.hide();
    FloatingWindowService().closeAllWindows();
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // 全局 Bloc - 所有页面共享
        BlocProvider(create: (_) => AuthBloc()..add(const AuthCheckRequested())),
        BlocProvider(create: (_) => ServerBloc()),
        BlocProvider(create: (_) => ServerStatsBloc()..add(const ServerStatsFetch())),
        BlocProvider(create: (_) => UpdateLogBloc()),
        BlocProvider(create: (_) => UpdateBloc()),
        BlocProvider(create: (_) => SettingsBloc()..add(SettingsInit())),
        BlocProvider(create: (_) => AnnouncementBloc()),
        BlocProvider(create: (_) => DailyTaskBloc()),
        BlocProvider(
            create: (_) => FeatureStatusBloc()
              ..add(FeatureStatusLoad())
              ..add(FeatureStatusStartPeriodicRefresh())),
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
            supportedLocales: const [
              Locale('zh', 'CN'),
              Locale('en', 'US'),
            ],
            builder: (context, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Stack(
                children: [
                  // 内容层：裁剪圆角
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE9EEF8),
                      child: child,
                    ),
                  ),
                  // 边框层
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF0080FF), width: 2),
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
  bool _updateDialogShown = false;

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
      
      // 启动 GSI 服务（独立服务，不依赖其他服务）
      final gsiService = GsiService();
      await gsiService.initialize();
      await gsiService.start();
      
      // 启动游戏状态监控（桌面端专属，需要先完成初始检测）
      await GameStatusService().startMonitoring();
      
      // 启动控制台日志监控（依赖 GameStatusService 的状态流）
      await ConsoleLogService().startMonitoring();
      
      // 以下服务依赖 ConsoleLogService，需要在其启动完成后初始化
      MapChangeMonitorService().initialize();
      WarmupMonitorService().initialize();
      
      // 初始化更新日志监控服务
      UpdateLogMonitorService().initialize();
    } catch (e) {
      LogService.e('[DesktopAppHome] 初始化服务时出错', e);
    }
  }


  void _listenForUpdate() {
    final updateBloc = context.read<UpdateBloc>();
    
    // 检查启动屏幕是否已经检测到更新
    if (updateBloc.state.hasUpdate && updateBloc.state.updateInfo != null && !_updateDialogShown) {
      _updateDialogShown = true;
      UpdateDialog.show(context, updateBloc.state.updateInfo!);
    }
    
    // 监听后续更新状态变化（如手动检查更新）
    // 使用 BlocListener 替代 stream.listen 避免内存泄漏
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UpdateBloc, UpdateState>(
      listenWhen: (prev, curr) => !prev.hasUpdate && curr.hasUpdate && curr.updateInfo != null,
      listener: (context, state) {
        if (!_updateDialogShown) {
          _updateDialogShown = true;
          UpdateDialog.show(context, state.updateInfo!);
        }
      },
      child: const DesktopHomeScreen(),
    );
  }
}
