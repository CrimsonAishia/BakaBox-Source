import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/bloc/settings/settings_bloc.dart';
import '../../core/bloc/settings/settings_event.dart';
import '../../core/bloc/settings/settings_state.dart';
import '../widgets/page_layout.dart';
import '../widgets/settings/settings.dart';

/// 设置页面 - 桌面端
/// 使用 PageLayout 统一布局
class SettingsDesktop extends StatefulWidget {
  const SettingsDesktop({super.key});

  @override
  State<SettingsDesktop> createState() => _SettingsDesktopState();
}

class _SettingsDesktopState extends State<SettingsDesktop> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 刷新缓存大小
      context.read<SettingsBloc>().add(SettingsRefreshCacheSize());
      context.read<SettingsBloc>().add(SettingsLoadCacheDetails());
      // 重新初始化以加载最新的游戏路径（可能在 OOBE 中设置）
      context.read<SettingsBloc>().add(SettingsInit());
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          return PageLayout(
            title: '设置',
            subtitle: '自定义您的应用体验',
            child: _buildSettingsContent(settingsState),
          );
        },
      ),
    );
  }



  Widget _buildSettingsContent(SettingsState settingsState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppearanceSettings(settingsState: settingsState),
            const SizedBox(height: 30),
            GameSettings(settingsState: settingsState),
            const SizedBox(height: 30),
            AppSettings(settingsState: settingsState),
            const SizedBox(height: 30),
            NotificationSettings(settingsState: settingsState),
            const SizedBox(height: 30),
            CacheSettings(settingsState: settingsState),
            const SizedBox(height: 30),
            AboutSettings(settingsState: settingsState),
          ],
        ),
      ),
    );
  }
}
