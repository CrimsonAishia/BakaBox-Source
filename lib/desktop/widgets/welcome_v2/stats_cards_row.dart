import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/core.dart';

/// 顶部数据卡片行
class StatsCardsRow extends StatelessWidget {
  final bool isDark;

  const StatsCardsRow({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, serverState) {
        return BlocBuilder<ServerStatsBloc, ServerStatsState>(
          builder: (context, statsState) {
            return BlocBuilder<LobbyBloc, LobbyState>(
              builder: (context, lobbyState) {
                return Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: MdiIcons.server,
                        iconColor: const Color(0xFF3B82F6),
                        label: '服务器',
                        value: _getServerCount(serverState),
                        suffix: '台',
                        isDark: isDark,
                        delay: 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: MdiIcons.accountGroup,
                        iconColor: const Color(0xFF10B981),
                        label: '今日峰值',
                        value: statsState.stats?.todayMax.toString(),
                        suffix: '人',
                        isDark: isDark,
                        delay: 100,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: MdiIcons.castle,
                        iconColor: const Color(0xFF8B5CF6),
                        label: '大厅',
                        value: lobbyState.serverOnlineCount.toString(),
                        suffix: '人',
                        isDark: isDark,
                        delay: 200,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: MdiIcons.accountMultiple,
                        iconColor: const Color(0xFFF59E0B),
                        label: '服务器总人数',
                        value: _getTotalOnlinePlayers(serverState),
                        suffix: '人',
                        isDark: isDark,
                        delay: 300,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: MdiIcons.clockOutline,
                        iconColor: const Color(0xFFEC4899),
                        label: '峰值时段',
                        value: _formatPeakHour(statsState.stats?.peakHour),
                        suffix: '',
                        isDark: isDark,
                        delay: 400,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  String _getServerCount(ServerState state) {
    final officialCategories = state.serverCategories.where(
      (cat) => !cat.isCustom,
    );
    final totalServers = officialCategories.fold<int>(
      0,
      (sum, cat) => sum + cat.serverList.length,
    );
    return totalServers.toString();
  }

  String _getTotalOnlinePlayers(ServerState state) {
    // 累加所有分类的在线人数
    final total = state.categoryOnlineCounts.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );
    return total.toString();
  }

  String _formatPeakHour(int? hour) {
    if (hour == null) return '--';
    return '${hour.toString().padLeft(2, '0')}:00';
  }
}

/// 单个数据卡片
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value;
  final String suffix;
  final bool isDark;
  final int delay;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.suffix,
    required this.isDark,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: iconColor),
              const SizedBox(height: 8),
              SizedBox(
                height: 28, // 固定高度，防止 loading 时高度变化
                child: value == null
                    ? Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: iconColor,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            value!,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          if (suffix.isNotEmpty)
                            Text(
                              suffix,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: delay.ms)
        .slideY(
          begin: 0.2,
          end: 0,
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
