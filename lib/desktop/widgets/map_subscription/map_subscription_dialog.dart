import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/map_subscription/map_subscription_bloc.dart';
import 'views/subscription_view.dart';
import 'views/add_subscription_view.dart';
import 'views/tts_settings_view.dart';
import 'components/nav_item.dart';

/// 导航项枚举
enum MapSubscriptionNavItem { subscription, add, tts }

/// 地图订阅管理弹窗 - 左右分栏布局
class MapSubscriptionDialog extends StatefulWidget {
  const MapSubscriptionDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<MapSubscriptionBloc>(),
        child: const MapSubscriptionDialog(),
      ),
    );
  }

  @override
  State<MapSubscriptionDialog> createState() => _MapSubscriptionDialogState();
}

class _MapSubscriptionDialogState extends State<MapSubscriptionDialog> {
  MapSubscriptionNavItem _selectedNav = MapSubscriptionNavItem.subscription;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<MapSubscriptionBloc>();
    bloc.add(const MapSubscriptionLoad());
    bloc.add(const MapSubscriptionLoadCategories());
    // 刷新过期的订阅地图信息
    bloc.add(const MapSubscriptionRefreshExpired());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 720,
        height: 560,
        child: BlocBuilder<MapSubscriptionBloc, MapSubscriptionState>(
          builder: (context, state) {
            return Row(
              children: [
                // 左侧导航栏
                _buildLeftNav(isDark, state),
                // 分隔线
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE5E7EB),
                ),
                // 右侧内容区
                Expanded(child: _buildContent(isDark, state)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 构建左侧导航栏
  Widget _buildLeftNav(bool isDark, MapSubscriptionState state) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : const Color(0xFFF9FAFB),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFF59E0B),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  '地图订阅',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 订阅管理
          _buildNavSection(
            isDark: isDark,
            title: '订阅管理',
            items: [
              NavItemData(
                icon: Icons.add_circle_outline_rounded,
                label: '添加',
                isSelected: _selectedNav == MapSubscriptionNavItem.add,
                onTap: () => setState(() {
                  _selectedNav = MapSubscriptionNavItem.add;
                }),
              ),
              NavItemData(
                icon: Icons.list_alt_rounded,
                label: '已订阅',
                badge: '${state.subscriptions.length}',
                isSelected: _selectedNav == MapSubscriptionNavItem.subscription,
                onTap: () => setState(() {
                  _selectedNav = MapSubscriptionNavItem.subscription;
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 语音播报
          _buildNavSection(
            isDark: isDark,
            title: '语音播报',
            items: [
              NavItemData(
                icon: Icons.record_voice_over_rounded,
                label: 'TTS 设置',
                statusIcon: !state.isTtsModelDownloaded
                    ? Icons.download_rounded
                    : (state.isTtsEnabled
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded),
                statusColor: !state.isTtsModelDownloaded
                    ? const Color(0xFFF59E0B)
                    : (state.isTtsEnabled
                          ? const Color(0xFF10B981)
                          : (isDark
                                ? Colors.white38
                                : const Color(0xFF9CA3AF))),
                isSelected: _selectedNav == MapSubscriptionNavItem.tts,
                onTap: () => setState(() {
                  _selectedNav = MapSubscriptionNavItem.tts;
                }),
              ),
            ],
          ),
          const Spacer(),
          // 全局开关区域
          _buildGlobalSwitches(isDark, state),
          const SizedBox(height: 12),
          // 关闭按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: isDark
                      ? Colors.white54
                      : const Color(0xFF6B7280),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('关闭'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建导航分组
  Widget _buildNavSection({
    required bool isDark,
    required String title,
    required List<NavItemData> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items.map((item) => NavItem(isDark: isDark, data: item)),
      ],
    );
  }

  /// 构建全局开关区域
  Widget _buildGlobalSwitches(bool isDark, MapSubscriptionState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          // 监控开关
          _buildSwitchRow(
            isDark: isDark,
            icon: Icons.visibility_rounded,
            label: '监控',
            tooltip: '开启后才会监控地图变化',
            value: state.isEnabled,
            activeColor: const Color(0xFF10B981),
            onChanged: (v) => context.read<MapSubscriptionBloc>().add(
              MapSubscriptionToggleGlobal(enabled: v),
            ),
          ),
          const SizedBox(height: 8),
          // 通知开关
          _buildSwitchRow(
            isDark: isDark,
            icon: state.isNotificationEnabled
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_rounded,
            label: '通知',
            tooltip: '开启后才会弹出通知窗口',
            value: state.isNotificationEnabled,
            activeColor: const Color(0xFF6366F1),
            onChanged: (v) => context.read<MapSubscriptionBloc>().add(
              MapSubscriptionToggleNotification(enabled: v),
            ),
          ),
          const SizedBox(height: 8),
          // TTS 语音播报开关
          _buildSwitchRow(
            isDark: isDark,
            icon: state.isTtsEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            label: '语音',
            tooltip: state.isTtsModelDownloaded
                ? '开启后地图变更时会语音播报'
                : '需要先下载 TTS 模型',
            value: state.isTtsEnabled,
            activeColor: const Color(0xFFF59E0B),
            enabled: state.isTtsModelDownloaded,
            onChanged: (v) => context.read<MapSubscriptionBloc>().add(
              MapSubscriptionToggleGlobalTts(enabled: v),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建开关行
  Widget _buildSwitchRow({
    required bool isDark,
    required IconData icon,
    required String label,
    required String tooltip,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final isDisabled = !enabled;
    final disabledColor = isDark ? Colors.white24 : const Color(0xFFD1D5DB);

    return Tooltip(
      message: tooltip,
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: isDisabled
                ? disabledColor
                : (value
                      ? activeColor
                      : (isDark ? Colors.white38 : const Color(0xFF9CA3AF))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDisabled
                    ? disabledColor
                    : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
              ),
            ),
          ),
          SizedBox(
            height: 20,
            width: 34,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch(
                value: value,
                onChanged: isDisabled ? null : onChanged,
                activeTrackColor: activeColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建右侧内容区
  Widget _buildContent(bool isDark, MapSubscriptionState state) {
    switch (_selectedNav) {
      case MapSubscriptionNavItem.subscription:
        return SubscriptionView(isDark: isDark, state: state);
      case MapSubscriptionNavItem.add:
        return AddSubscriptionView(isDark: isDark, state: state);
      case MapSubscriptionNavItem.tts:
        return TtsSettingsView(isDark: isDark, state: state);
    }
  }
}
