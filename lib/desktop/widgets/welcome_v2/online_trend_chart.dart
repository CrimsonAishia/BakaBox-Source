import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/core.dart';

/// 在线趋势图（7日每日峰值 + 平均值折线图）
class OnlineTrendChart extends StatefulWidget {
  final bool isDark;

  const OnlineTrendChart({super.key, required this.isDark});

  @override
  State<OnlineTrendChart> createState() => _OnlineTrendChartState();
}

class _OnlineTrendChartState extends State<OnlineTrendChart> {
  int _selectedTab = 0; // 0: 在线趋势, 1: 热门时段, 2: 热门地图

  static const _tabs = ['在线趋势', '热门时段', '热门地图'];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServerStatsBloc, ServerStatsState>(
      builder: (context, state) {
        return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: widget.isDark ? 0.2 : 0.05,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题 + Tab 切换
                  Row(
                    children: [
                      for (int i = 0; i < _tabs.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        _TabChip(
                          label: _tabs[i],
                          selected: _selectedTab == i,
                          isDark: widget.isDark,
                          onTap: () => setState(() => _selectedTab = i),
                        ),
                      ],
                      const Spacer(),
                      if (state.isLoading)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: widget.isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 图表内容
                  SizedBox(
                    height: 160,
                    child: _buildContent(state),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 500.ms, delay: 800.ms)
            .slideY(
              begin: 0.2,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }

  Widget _buildContent(ServerStatsState state) {
    final stats = state.stats;
    if (stats == null) {
      return Center(
        child: Text(
          '加载统计数据...',
          style: TextStyle(
            fontSize: 13,
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.4)
                : const Color(0xFF94A3B8),
          ),
        ),
      );
    }

    return switch (_selectedTab) {
      0 => _DailyTrendChart(isDark: widget.isDark, stats: stats),
      1 => _HourlyBarChart(isDark: widget.isDark, stats: stats),
      2 => _TopMapsList(isDark: widget.isDark, maps: stats.topMaps),
      _ => const SizedBox(),
    };
  }
}

/// Tab 切换芯片
class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? const Color(0xFF8B5CF6)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : const Color(0xFF94A3B8)),
          ),
        ),
      ),
    );
  }
}

/// 7日每日趋势折线图
class _DailyTrendChart extends StatelessWidget {
  final bool isDark;
  final ServerStatsResponse stats;

  const _DailyTrendChart({required this.isDark, required this.stats});

  @override
  Widget build(BuildContext context) {
    final daily = stats.dailyStats;
    if (daily.isEmpty) {
      return _emptyHint(isDark, '暂无趋势数据');
    }

    final maxY = daily.map((d) => d.maxPlayers).reduce(math.max).toDouble();
    final safeMax = maxY == 0 ? 10.0 : maxY;

    return Column(
      children: [
        // 图例
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _LegendDot(color: const Color(0xFF3B82F6), label: '峰值'),
            const SizedBox(width: 12),
            _LegendDot(color: const Color(0xFF10B981), label: '均值'),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: LineChart(
            key: ValueKey(isDark),
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: safeMax / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= daily.length) {
                        return const SizedBox();
                      }
                      final parts = daily[idx].date.split('-');
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${parts[1]}/${parts[2]}',
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.4)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (daily.length - 1).toDouble(),
              minY: 0,
              maxY: safeMax * 1.15,
              lineBarsData: [
                // 峰值线
                LineChartBarData(
                  spots: daily.asMap().entries.map((e) {
                    return FlSpot(
                      e.key.toDouble(),
                      e.value.maxPlayers.toDouble(),
                    );
                  }).toList(),
                  isCurved: true,
                  color: const Color(0xFF3B82F6),
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                  ),
                ),
                // 均值线
                LineChartBarData(
                  spots: daily.asMap().entries.map((e) {
                    return FlSpot(
                      e.key.toDouble(),
                      e.value.avgPlayers.toDouble(),
                    );
                  }).toList(),
                  isCurved: true,
                  color: const Color(0xFF10B981),
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  dashArray: [4, 4],
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      final label = spot.barIndex == 0 ? '峰值' : '均值';
                      return LineTooltipItem(
                        '$label: ${spot.y.toInt()}人',
                        TextStyle(
                          color: spot.bar.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 热门时段柱状图
class _HourlyBarChart extends StatelessWidget {
  final bool isDark;
  final ServerStatsResponse stats;

  const _HourlyBarChart({required this.isDark, required this.stats});

  @override
  Widget build(BuildContext context) {
    final hourly = stats.hourlyStats;
    if (hourly.isEmpty) {
      return _emptyHint(isDark, '暂无时段数据');
    }

    final maxY = hourly.map((h) => h.avgPlayers).reduce(math.max).toDouble();
    final safeMax = maxY == 0 ? 10.0 : maxY;
    final peakHour = stats.peakHour;

    return BarChart(
      key: ValueKey(isDark),
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: safeMax / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 4,
              getTitlesWidget: (value, meta) {
                final hour = value.toInt();
                if (hour % 4 != 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: hourly.map((h) {
          final isPeak = h.hour == peakHour;
          return BarChartGroupData(
            x: h.hour,
            barRods: [
              BarChartRodData(
                toY: h.avgPlayers.toDouble(),
                color: isPeak
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF8B5CF6).withValues(alpha: 0.7),
                width: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
            ],
          );
        }).toList(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) =>
                isDark ? const Color(0xFF1E293B) : Colors.white,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${group.x.toString().padLeft(2, '0')}:00\n${rod.toY.toInt()}人',
                TextStyle(
                  color: rod.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 热门地图列表
class _TopMapsList extends StatelessWidget {
  final bool isDark;
  final List<TopMap> maps;

  const _TopMapsList({required this.isDark, required this.maps});

  @override
  Widget build(BuildContext context) {
    if (maps.isEmpty) {
      return _emptyHint(isDark, '暂无地图数据');
    }

    final maxPlay = maps.map((m) => m.playCount).reduce(math.max);

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: math.min(maps.length, 5),
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final map = maps[index];
        final progress = maxPlay > 0 ? map.playCount / maxPlay : 0.0;
        return Row(
          children: [
            // 排名
            SizedBox(
              width: 20,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: index == 0
                      ? const Color(0xFFF59E0B)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.4)
                            : const Color(0xFF94A3B8)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 地图名 + 进度条
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          map.mapName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.85)
                                : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      Text(
                        '${map.playCount}局',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.4)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        index == 0
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF8B5CF6).withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 图例点
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

Widget _emptyHint(bool isDark, String text) {
  return Center(
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: isDark
            ? Colors.white.withValues(alpha: 0.4)
            : const Color(0xFF94A3B8),
      ),
    ),
  );
}
