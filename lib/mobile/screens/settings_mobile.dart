import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/core.dart';

class SettingsMobile extends StatefulWidget {
  const SettingsMobile({super.key});

  @override
  State<SettingsMobile> createState() => _SettingsMobileState();
}

class _SettingsMobileState extends State<SettingsMobile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsBloc>().add(SettingsRefreshCacheSize());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<SettingsBloc, SettingsState>(
        listener: (context, state) {
          // 监听需要重启的状态
          if (state.needsRestart) {
            _showRestartDialog(context);
          }
        },
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            return CustomScrollView(
              slivers: [
                _buildFixedAppBar(context),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMenuCard(
                          context,
                          title: '外观设置',
                          subtitle:
                              '主题模式：${settingsState.currentThemeModeText}',
                          icon: MdiIcons.themeLightDark,
                          iconColor: const Color(0xFF8B5CF6),
                          onTap: () => _showThemeDialog(context),
                        ),
                        const SizedBox(height: AppConstants.defaultPadding),
                        _buildMenuCard(
                          context,
                          title: '存储管理',
                          subtitle: '缓存大小：${settingsState.cacheSize}',
                          icon: MdiIcons.folderOutline,
                          iconColor: const Color(0xFFEF4444),
                          onTap: () => _showStorageDialog(context),
                        ),
                        const SizedBox(height: AppConstants.defaultPadding),
                        // 问题反馈入口已隐藏
                        // _buildMenuCard(
                        //   context,
                        //   title: '问题反馈',
                        //   subtitle: '提交Bug、功能建议或问题咨询',
                        //   icon: MdiIcons.commentQuestionOutline,
                        //   iconColor: const Color(0xFFF59E0B),
                        //   onTap: () => context.push(MobileRoutes.issues),
                        // ),
                        // const SizedBox(height: AppConstants.defaultPadding),
                        _buildMenuCard(
                          context,
                          title: '检查更新',
                          subtitle: '查看是否有新版本可用',
                          icon: MdiIcons.update,
                          iconColor: const Color(0xFF10B981),
                          onTap: settingsState.isCheckingUpdate
                              ? null
                              : () => _checkForUpdates(context),
                          trailing: settingsState.isCheckingUpdate
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: AppConstants.defaultPadding),
                        _buildMenuCard(
                          context,
                          title: '官方网站',
                          subtitle: '访问官网获取更多信息',
                          icon: MdiIcons.web,
                          iconColor: const Color(0xFFFF6B35),
                          onTap: () => _openWebsite(context),
                        ),
                        const SizedBox(height: AppConstants.defaultPadding),
                        _buildMenuCard(
                          context,
                          title: '关于',
                          subtitle: '应用信息',
                          icon: MdiIcons.informationOutline,
                          iconColor: const Color(0xFF0080FF),
                          onTap: () => _showAboutDialog(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFixedAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: theme.appBarTheme.backgroundColor,
      surfaceTintColor: theme.appBarTheme.backgroundColor,
      toolbarHeight: 80,
      automaticallyImplyLeading: false,
      expandedHeight: 80,
      collapsedHeight: 80,
      forceElevated: false,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: theme.appBarTheme.backgroundColor,
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.05),
              offset: const Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                            width: 56,
                            height: 56,
                            padding: const EdgeInsets.all(4),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0080FF),
                                    Color(0xFF00B4FF),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF0080FF,
                                    ).withValues(alpha: 0.3),
                                    offset: const Offset(0, 4),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.settings_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          )
                          .animate()
                          .scale(
                            begin: const Offset(0.5, 0.5),
                            end: const Offset(1.0, 1.0),
                            duration: 600.ms,
                            curve: Curves.elasticOut,
                          )
                          .fadeIn(duration: 200.ms)
                          .then()
                          .scale(
                            begin: const Offset(1.0, 1.0),
                            end: const Offset(1.05, 1.05),
                            duration: 200.ms,
                            curve: Curves.easeOut,
                          )
                          .then()
                          .scale(
                            begin: const Offset(1.05, 1.05),
                            end: const Offset(1.0, 1.0),
                            duration: 200.ms,
                            curve: Curves.easeIn,
                          )
                          .then()
                          .shimmer(
                            duration: 1000.ms,
                            delay: 100.ms,
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.1),
                              Colors.white.withValues(alpha: 0.3),
                              Colors.white.withValues(alpha: 0.1),
                              Colors.transparent,
                            ],
                          ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '设置',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: theme.appBarTheme.foregroundColor,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ).animate().fadeIn(duration: 300.ms),
                            const SizedBox(height: 2),
                            Text(
                              '个性化设置和系统配置',
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    theme.appBarTheme.foregroundColor
                                        ?.withValues(alpha: 0.7) ??
                                    colorScheme.onSurface.withValues(
                                      alpha: 0.7,
                                    ),
                                height: 1.2,
                              ),
                            ).animate().fadeIn(duration: 300.ms, delay: 80.ms),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    MdiIcons.chevronRight,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2);
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final settingsBloc = context.read<SettingsBloc>();
    final currentThemeMode = settingsBloc.state.themeMode;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(MdiIcons.themeLightDark, color: const Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            const Text('外观设置'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(
              dialogContext,
              title: '跟随系统',
              subtitle: '跟随系统设置自动切换',
              icon: MdiIcons.cellphone,
              isSelected: currentThemeMode == ThemeMode.system,
              onTap: () {
                settingsBloc.add(const SettingsSetThemeMode(ThemeMode.system));
                Navigator.pop(dialogContext);
              },
            ),
            _buildThemeOption(
              dialogContext,
              title: '浅色模式',
              subtitle: '始终使用浅色主题',
              icon: MdiIcons.weatherSunny,
              isSelected: currentThemeMode == ThemeMode.light,
              onTap: () {
                settingsBloc.add(const SettingsSetThemeMode(ThemeMode.light));
                Navigator.pop(dialogContext);
              },
            ),
            _buildThemeOption(
              dialogContext,
              title: '深色模式',
              subtitle: '始终使用深色主题',
              icon: MdiIcons.weatherNight,
              isSelected: currentThemeMode == ThemeMode.dark,
              onTap: () {
                settingsBloc.add(const SettingsSetThemeMode(ThemeMode.dark));
                Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF8B5CF6)
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF8B5CF6)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected ? const Color(0xFF8B5CF6) : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                MdiIcons.checkCircle,
                color: const Color(0xFF8B5CF6),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showStorageDialog(BuildContext context) {
    final settingsBloc = context.read<SettingsBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) => BlocBuilder<SettingsBloc, SettingsState>(
        bloc: settingsBloc,
        builder: (context, state) => AlertDialog(
          title: Row(
            children: [
              Icon(MdiIcons.folderOutline, color: const Color(0xFFEF4444)),
              const SizedBox(width: 8),
              const Text('存储管理'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      MdiIcons.cached,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '应用缓存',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            state.cacheSize,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          settingsBloc.add(SettingsRefreshCacheSize()),
                      icon: Icon(MdiIcons.refresh),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: state.isLoading
                      ? null
                      : () => _showClearCacheDialog(context, dialogContext),
                  icon: state.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(MdiIcons.trashCanOutline),
                  label: Text(state.isLoading ? '清理中...' : '清理缓存'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearCacheDialog(
    BuildContext context,
    BuildContext storageDialogContext,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(MdiIcons.alertCircleOutline, color: const Color(0xFFEF4444)),
            const SizedBox(width: 8),
            const Text('清理缓存'),
          ],
        ),
        content: const Text('确定要清理应用缓存吗？这将删除所有临时文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(storageDialogContext);
              context.read<SettingsBloc>().add(SettingsClearCache());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('缓存清理成功'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _checkForUpdates(BuildContext context) {
    context.read<SettingsBloc>().add(SettingsCheckForUpdates());
    context.read<UpdateBloc>().add(UpdateCheck());
  }

  void _showAboutDialog(BuildContext context) {
    final settingsState = context.read<SettingsBloc>().state;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(MdiIcons.informationOutline, color: const Color(0xFF0080FF)),
            const SizedBox(width: 8),
            const Text('关于'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '应用介绍',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('一个专为移动设备设计的CS2服务器浏览器，让你随时随地查看服务器状态和更新日志。'),
              const SizedBox(height: 16),
              _buildInfoRow(
                dialogContext,
                icon: MdiIcons.application,
                title: '应用名称',
                value: AppConstants.appName,
              ),
              _buildInfoRow(
                dialogContext,
                icon: MdiIcons.tagOutline,
                title: '版本号',
                value: settingsState.appVersion.isNotEmpty
                    ? 'v${settingsState.appVersion}'
                    : '获取中...',
              ),
              const SizedBox(height: 16),
              const Text(
                '项目地址',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  MdiIcons.sourceRepository,
                  color: const Color(0xFFE74C3C),
                ),
                title: const Text('Gitee'),
                subtitle: const Text('查看项目'),
                onTap: () async {
                  Navigator.pop(dialogContext);
                  HapticFeedback.lightImpact();
                  const giteeUrl =
                      'https://gitee.com/CrimsonAishia/zed-box-app/releases/latest';
                  try {
                    final uri = Uri.parse(giteeUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('无法打开浏览器'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    LogService.e('打开Gitee链接失败', e);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('打开链接失败，请稍后重试'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _openWebsite(BuildContext context) async {
    HapticFeedback.lightImpact();
    const websiteUrl = 'https://baka.aishia.cc';
    try {
      final uri = Uri.parse(websiteUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法打开浏览器'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      LogService.e('打开网站链接失败', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('打开链接失败，请稍后重试'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showRestartDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(MdiIcons.restart, color: const Color(0xFFEF4444)),
            const SizedBox(width: 8),
            const Text('需要重启应用'),
          ],
        ),
        content: const Text('应用数据已清除，需要重启应用才能生效。点击确定后应用将自动关闭，请手动重新启动。'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // 退出应用
              SystemNavigator.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('确定并退出'),
          ),
        ],
      ),
    );
  }
}
