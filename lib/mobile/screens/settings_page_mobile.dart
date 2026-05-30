import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/core.dart';

/// 移动端设置页面
class SettingsPageMobile extends StatelessWidget {
  const SettingsPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSettingsCard(
                context,
                title: '通用',
                children: [
                  _buildSettingsItem(
                    context,
                    icon: MdiIcons.themeLightDark,
                    iconColor: const Color(0xFF8B5CF6),
                    title: '外观设置',
                    subtitle: settingsState.currentThemeModeText,
                    onTap: () => _showThemeDialog(context),
                  ),
                  _buildDivider(context),
                  _buildSettingsItem(
                    context,
                    icon: MdiIcons.folderOutline,
                    iconColor: const Color(0xFFEF4444),
                    title: '存储管理',
                    subtitle: settingsState.cacheSize,
                    onTap: () => _showStorageDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSettingsCard(
                context,
                title: '关于',
                children: [
                  _buildSettingsItem(
                    context,
                    icon: MdiIcons.update,
                    iconColor: const Color(0xFF10B981),
                    title: '检查更新',
                    subtitle: settingsState.appVersion.isNotEmpty
                        ? 'v${settingsState.appVersion}'
                        : '查看是否有新版本',
                    trailing: settingsState.isCheckingUpdate
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: settingsState.isCheckingUpdate
                        ? null
                        : () => _checkForUpdates(context),
                  ),
                  _buildDivider(context),
                  _buildSettingsItem(
                    context,
                    icon: MdiIcons.web,
                    iconColor: const Color(0xFFFF6B35),
                    title: '官方网站',
                    subtitle: 'baka.aishia.cc',
                    onTap: () => _openWebsite(context),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1);
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      indent: 62,
      endIndent: 16,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
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
    // 打开时立即加载移动端缓存详情
    settingsBloc.add(SettingsLoadMobileCacheDetails());

    showDialog(
      context: context,
      builder: (dialogContext) => BlocBuilder<SettingsBloc, SettingsState>(
        bloc: settingsBloc,
        buildWhen: (prev, curr) =>
            prev.mobileCacheDetails != curr.mobileCacheDetails ||
            prev.isLoadingMobileCacheDetails !=
                curr.isLoadingMobileCacheDetails,
        builder: (context, state) => AlertDialog(
          title: Row(
            children: [
              Icon(MdiIcons.folderOutline, color: const Color(0xFFEF4444)),
              const SizedBox(width: 8),
              const Text('存储管理'),
              const Spacer(),
              IconButton(
                onPressed: state.isLoadingMobileCacheDetails
                    ? null
                    : () => settingsBloc.add(SettingsLoadMobileCacheDetails()),
                icon: state.isLoadingMobileCacheDetails
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(MdiIcons.refresh, size: 20),
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          content: SizedBox(
            width: double.maxFinite,
            child:
                state.isLoadingMobileCacheDetails &&
                    state.mobileCacheDetails.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: state.mobileCacheDetails
                        .map(
                          (item) => _buildMobileCacheItem(
                            context,
                            item: item,
                            onClear: item.canClear
                                ? () {
                                    Navigator.pop(dialogContext);
                                    settingsBloc.add(
                                      SettingsClearMobileCacheByType(item.type),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${item.name}已清理'),
                                        backgroundColor: const Color(
                                          0xFF10B981,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCacheItem(
    BuildContext context, {
    required MobileCacheItemInfo item,
    VoidCallback? onClear,
  }) {
    final theme = Theme.of(context);
    final canClear = item.canClear;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          color: canClear
              ? null
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
        ),
        child: Row(
          children: [
            // 图标
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _mobileCacheIconColor(item.type).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _mobileCacheIcon(item.type),
                color: canClear
                    ? _mobileCacheIconColor(item.type)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // 文字
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: canClear
                              ? null
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                        ),
                      ),
                      if (!canClear) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '保留',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 大小 + 清理按钮
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.isClearing ? '清理中...' : item.formattedSize,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: canClear
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
                if (canClear) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: item.isClearing ? null : onClear,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: item.isClearing
                            ? theme.colorScheme.outline.withValues(alpha: 0.1)
                            : const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '清理',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: item.isClearing
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.3,
                                )
                              : const Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _mobileCacheIcon(MobileCacheType type) {
    switch (type) {
      case MobileCacheType.serverImages:
        return MdiIcons.imageMultipleOutline;
      case MobileCacheType.serverData:
        return MdiIcons.databaseOutline;
      case MobileCacheType.logs:
        return MdiIcons.textBoxOutline;
      case MobileCacheType.lobbyImages:
        return MdiIcons.mapOutline;
    }
  }

  Color _mobileCacheIconColor(MobileCacheType type) {
    switch (type) {
      case MobileCacheType.serverImages:
        return const Color(0xFF3B82F6);
      case MobileCacheType.serverData:
        return const Color(0xFFF59E0B);
      case MobileCacheType.logs:
        return const Color(0xFF6B7280);
      case MobileCacheType.lobbyImages:
        return const Color(0xFF10B981);
    }
  }

  void _checkForUpdates(BuildContext context) {
    context.read<SettingsBloc>().add(SettingsCheckForUpdates());
    context.read<UpdateBloc>().add(UpdateCheck());
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
}
