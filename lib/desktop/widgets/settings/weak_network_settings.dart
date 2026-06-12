import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/bloc/settings/settings_bloc.dart';
import '../../../core/bloc/settings/settings_event.dart';
import '../../../core/bloc/settings/settings_state.dart';
import 'settings_group_title.dart';
import 'settings_item.dart';
import '../../../core/constants/app_colors.dart';

/// 弱网模式设置组件
///
/// 开启后将关闭所有自动刷新和后台推送，改为用户主动触发：
/// - 服务器列表 / 地图数据：仅在用户点"刷新"时更新
/// - 实时推送（消息 / 公告 / 比分 / 换图等）：暂停
/// - 大厅 / 挤服 / 暖服：不受影响
class WeakNetworkSettings extends StatelessWidget {
  final SettingsState settingsState;

  const WeakNetworkSettings({super.key, required this.settingsState});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOn = settingsState.weakNetworkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupTitle(
          title: '弱网模式',
          hasGlow: true,
          icon: MdiIcons.wifiStrength1Alert,
        ),
        AppSettingItem(
          title: '启用弱网模式',
          description:
              '关闭所有自动刷新和实时推送，改为手动触发。\n'
              '适合网络较差或流量有限的环境。\n'
              '大厅、挤服、暖服功能不受影响。',
          value: isOn ? _buildSummary(context, isDark) : null,
          action: Switch(
            value: isOn,
            onChanged: (value) {
              context.read<SettingsBloc>().add(
                SettingsSetWeakNetworkMode(value),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    value
                        ? '弱网模式已开启，所有自动刷新已暂停'
                        : '弱网模式已关闭，已恢复自动刷新',
                  ),
                  duration: const Duration(seconds: 2),
                  backgroundColor: value
                      ? Colors.orange
                      : AppColors.primary,
                ),
              );
            },
            activeThumbColor: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context, bool isDark) {
    final items = const [
      '• 服务器列表：仅在你点击"刷新"时更新',
      '• 实时推送：消息 / 公告 / 比分 / 换图 已暂停',
      '• 后台监控：换图监控、比分上报已暂停',
      '• 大厅 / 挤服 / 暖服：不受影响',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
