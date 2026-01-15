import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../core/core.dart';
import 'router/mobile_router.dart';
import 'theme/mobile_theme.dart';
import 'screens/mobile_home_screen.dart';

/// 移动端应用入口
class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ServerBloc()),
        BlocProvider(create: (_) => ServerStatsBloc()),
        BlocProvider(create: (_) => UpdateLogBloc()),
        BlocProvider(create: (_) => UpdateBloc()),
        BlocProvider(create: (_) => SettingsBloc()..add(SettingsInit())),
        BlocProvider(create: (_) => AuthBloc()..add(const AuthCheckRequested())),
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
  bool _updateDialogShown = false;

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
    if (updateBloc.state.hasUpdate && updateBloc.state.updateInfo != null && !_updateDialogShown) {
      _updateDialogShown = true;
      UpdateDialog.show(context, updateBloc.state.updateInfo!);
    }
    // 后续更新状态变化通过 BlocListener 监听，避免内存泄漏
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
      child: const MobileHomeScreen(),
    );
  }
}
