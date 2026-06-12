import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../core/bloc/settings/settings_bloc.dart';
import '../../../core/bloc/settings/settings_event.dart';
import '../../../core/bloc/settings/settings_state.dart';
import 'settings_group_title.dart';
import 'settings_item.dart';
import '../../../core/constants/app_colors.dart';

/// 外观设置组件
class AppearanceSettings extends StatelessWidget {
  final SettingsState settingsState;

  const AppearanceSettings({super.key, required this.settingsState});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupTitle(
          title: '外观设置',
          hasGlow: true,
          icon: MdiIcons.palette,
        ),
        AppSettingItem(
          title: '主题模式',
          description: '选择应用的外观主题，可跟随系统或手动设置',
          value: _buildThemeModeSelector(context, isDark),
          action: const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildThemeModeSelector(BuildContext context, bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ThemeModeOption(
          icon: MdiIcons.themeLightDark,
          label: '跟随系统',
          isSelected: settingsState.themeMode == ThemeMode.system,
          isDark: isDark,
          onTap: () => context.read<SettingsBloc>().add(
            const SettingsSetThemeMode(ThemeMode.system),
          ),
        ),
        _ThemeModeOption(
          icon: MdiIcons.weatherSunny,
          label: '浅色',
          isSelected: settingsState.themeMode == ThemeMode.light,
          isDark: isDark,
          onTap: () => context.read<SettingsBloc>().add(
            const SettingsSetThemeMode(ThemeMode.light),
          ),
        ),
        _ThemeModeOption(
          icon: MdiIcons.weatherNight,
          label: '深色',
          isSelected: settingsState.themeMode == ThemeMode.dark,
          isDark: isDark,
          onTap: () => context.read<SettingsBloc>().add(
            const SettingsSetThemeMode(ThemeMode.dark),
          ),
        ),
      ],
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeModeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    const Color(0xFF00D4FF).withValues(alpha: 0.08),
                  ],
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? AppColors.slate700 : AppColors.gray50),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.slate600 : AppColors.gray200),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.white70 : AppColors.gray500),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white : AppColors.gray700),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(
                MdiIcons.checkCircle,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
