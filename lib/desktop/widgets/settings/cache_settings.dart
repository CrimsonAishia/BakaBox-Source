import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../core/bloc/settings/settings_bloc.dart';
import '../../../core/bloc/settings/settings_event.dart';
import '../../../core/bloc/settings/settings_state.dart';
import '../../../core/utils/platform_utils.dart';
import '../selective_cache_dialog.dart';
import 'settings_group_title.dart';
import 'settings_buttons.dart';
import '../../../core/constants/app_colors.dart';

/// 缓存管理设置组件
class CacheSettings extends StatelessWidget {
  final SettingsState settingsState;

  const CacheSettings({super.key, required this.settingsState});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 监听需要重启的状态
    if (settingsState.needsRestart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRestartDialog(context);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupTitle(title: '缓存管理', icon: MdiIcons.database),
        _buildCacheInfoGrid(context),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: isDark
                    ? const Color(0xFF60A5FA)
                    : AppColors.blue500,
                width: 4,
              ),
            ),
          ),
          child: Text(
            '💡 统计包括缓存数据库、应用数据、临时文件和日志文件。定期清理可以释放磁盘空间。所有数据现在保存在用户目录下，不会因为应用更新而丢失。您可以选择性清理不同类型的内容。',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : AppColors.gray500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCacheInfoGrid(BuildContext context) {
    final totalSize = settingsState.cacheDetails.isNotEmpty
        ? settingsState.formattedTotalCacheSize
        : settingsState.cacheSize;

    return _CacheInfoItem(
      icon: MdiIcons.harddisk,
      iconColor: AppColors.primary,
      label: '缓存大小',
      value: settingsState.isLoadingCacheDetails
          ? const Text(
              '计算中...',
              style: TextStyle(fontSize: 14, color: AppColors.gray500),
            )
          : Text(
              totalSize,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsOutlinedButton(
            onPressed: settingsState.isLoadingCacheDetails
                ? null
                : () => context.read<SettingsBloc>().add(
                    SettingsLoadCacheDetails(),
                  ),
            label: '刷新',
            icon: MdiIcons.refresh,
            isLoading: settingsState.isLoadingCacheDetails,
          ),
          const SizedBox(width: 8),
          SettingsDangerButton(
            onPressed:
                settingsState.isLoading || settingsState.isLoadingCacheDetails
                ? null
                : () => _openSelectiveCacheDialog(context),
            label: '清理缓存',
            icon: MdiIcons.deleteOutline,
            isLoading: settingsState.isLoading,
          ),
        ],
      ),
    );
  }

  void _openSelectiveCacheDialog(BuildContext context) {
    SelectiveCacheDialog.show(
      context,
      cacheDetails: settingsState.cacheDetails,
      onConfirm: (selectedTypes) {
        context.read<SettingsBloc>().add(
          SettingsClearSelectedCache(selectedTypes),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已清除 ${selectedTypes.length} 种缓存'),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }

  void _showRestartDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(MdiIcons.restart, color: AppColors.red500),
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
              if (PlatformUtils.isDesktopPlatform) {
                exit(0);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red500,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定并退出'),
          ),
        ],
      ),
    );
  }
}

class _CacheInfoItem extends StatelessWidget {
  final String label;
  final Widget value;
  final Widget action;
  final IconData? icon;
  final Color? iconColor;

  const _CacheInfoItem({
    required this.label,
    required this.value,
    required this.action,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.slate700, AppColors.slate800]
              : [const Color(0xFFFAFBFC), AppColors.slate50],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.slate600 : AppColors.gray200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
          ],
          SizedBox(
            width: icon != null ? 100 : 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.gray700,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: value,
            ),
          ),
          action,
        ],
      ),
    );
  }
}
