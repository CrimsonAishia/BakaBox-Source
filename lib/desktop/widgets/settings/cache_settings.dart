import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../core/bloc/settings/settings_bloc.dart';
import '../../../core/bloc/settings/settings_event.dart';
import '../../../core/bloc/settings/settings_state.dart';
import '../selective_cache_dialog.dart';
import 'settings_group_title.dart';
import 'settings_buttons.dart';

/// 缓存管理设置组件
class CacheSettings extends StatelessWidget {
  final SettingsState settingsState;

  const CacheSettings({
    super.key,
    required this.settingsState,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupTitle(
          title: '缓存管理',
          icon: MdiIcons.database,
        ),
        _buildCacheInfoGrid(context),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: const Border(left: BorderSide(color: Color(0xFF3B82F6), width: 4)),
          ),
          child: const Text(
            '💡 统计包括缓存数据库、应用数据、临时文件和日志文件。定期清理可以释放磁盘空间。所有数据现在保存在用户目录下，不会因为应用更新而丢失。您可以选择性清理不同类型的内容。',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }

  Widget _buildCacheInfoGrid(BuildContext context) {
    final totalSize = settingsState.cacheDetails.isNotEmpty
        ? settingsState.formattedTotalCacheSize
        : settingsState.cacheSize;

    return Column(
      children: [
        _CacheInfoItem(
          icon: MdiIcons.harddisk,
          iconColor: const Color(0xFF0080FF),
          label: '缓存大小',
          value: settingsState.isLoadingCacheDetails
              ? const Text('计算中...', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)))
              : Text(
                  totalSize,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0080FF)),
                ),
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsOutlinedButton(
                onPressed: settingsState.isLoadingCacheDetails || settingsState.cacheDetails.isEmpty
                    ? null
                    : () => _openSelectiveCacheDialog(context),
                label: '选择性清理',
                icon: MdiIcons.filterVariant,
              ),
              const SizedBox(width: 8),
              SettingsDangerButton(
                onPressed: settingsState.isLoading ? null : () => _clearAllCache(context),
                label: '清理缓存',
                icon: MdiIcons.deleteOutline,
                isLoading: settingsState.isLoading,
              ),
            ],
          ),
        ),
        _CacheInfoItem(
          icon: MdiIcons.packageVariant,
          iconColor: const Color(0xFF10B981),
          label: '缓存项数量',
          value: settingsState.isLoadingCacheDetails
              ? const Text('统计中...', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)))
              : Text(
                  '${settingsState.cacheDetails.length} 个缓存类型',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                ),
          action: SettingsOutlinedButton(
            onPressed: settingsState.isLoadingCacheDetails
                ? null
                : () => context.read<SettingsBloc>().add(SettingsLoadCacheDetails()),
            label: '刷新',
            icon: MdiIcons.refresh,
            isLoading: settingsState.isLoadingCacheDetails,
          ),
        ),
      ],
    );
  }

  void _openSelectiveCacheDialog(BuildContext context) {
    SelectiveCacheDialog.show(
      context,
      cacheDetails: settingsState.cacheDetails,
      onConfirm: (selectedTypes) {
        context.read<SettingsBloc>().add(SettingsClearSelectedCache(selectedTypes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已清除 ${selectedTypes.length} 种缓存'),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }

  void _clearAllCache(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(MdiIcons.deleteAlertOutline, color: Colors.red),
            const SizedBox(width: 8),
            const Text('清除所有缓存'),
          ],
        ),
        content: const Text('确定要清除所有缓存吗？这将删除临时文件和服务器列表缓存，不会影响您的设置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<SettingsBloc>().add(SettingsClearAllCache());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('所有缓存已清除'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('确定清除'),
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
              ? [const Color(0xFF334155), const Color(0xFF1E293B)]
              : [const Color(0xFFFAFBFC), const Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB)),
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
                color: (iconColor ?? const Color(0xFF0080FF)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor ?? const Color(0xFF0080FF)),
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
                color: isDark ? Colors.white : const Color(0xFF374151),
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
