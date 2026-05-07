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
                  Expanded(child: _buildContent(state)),
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
                handleBuiltInTouches: true,
                touchSpotThreshold: 50,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) =>
                      isDark ? const Color(0xFF1E293B) : Colors.white,
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
      itemCount: math.min(maps.length, 10),
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final map = maps[index];
        final progress = maxPlay > 0 ? map.playCount / maxPlay : 0.0;

        return _TopMapItem(index: index, map: map, progress: progress);
      },
    );
  }
}

class _TopMapItem extends StatefulWidget {
  final int index;
  final TopMap map;
  final double progress;

  const _TopMapItem({
    required this.index,
    required this.map,
    required this.progress,
  });

  @override
  State<_TopMapItem> createState() => _TopMapItemState();
}

class _TopMapItemState extends State<_TopMapItem> {
  MapData? _mapData;

  @override
  void initState() {
    super.initState();
    _fetchMapInfo();
  }

  Future<void> _fetchMapInfo() async {
    try {
      final data = await ServerApi().getMapInfo(widget.map.mapName);
      if (mounted) {
        setState(() {
          _mapData = data;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final mapLabel = _mapData?.mapLabel;
    final mapUrl = _mapData?.mapUrl;

    final displayMapName =
        mapLabel != null &&
            mapLabel.isNotEmpty &&
            mapLabel != widget.map.mapName
        ? '$mapLabel (${widget.map.mapName})'
        : widget.map.mapName;

    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          // 地图背景
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: MapBackground(
                mapName: widget.map.mapName,
                imageUrl: mapUrl,
                cacheWidth: 400,
                cacheHeight: 112,
              ),
            ),
          ),
          // 渐变遮罩 (让左侧和下方有阴影，方便看字)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6), // 右侧稍微深一点方便看游玩次数
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),
          // 内容
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // 排名角标
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.index == 0
                          ? const Color(0xFFF59E0B)
                          : (widget.index == 1
                                ? const Color(0xFF94A3B8)
                                : (widget.index == 2
                                      ? const Color(0xFFB45309)
                                      : Colors.black.withValues(alpha: 0.4))),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      '${widget.index + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 地图名与进度条
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          displayMapName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 2),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: widget.progress,
                            minHeight: 4,
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.4,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.index == 0
                                  ? const Color(0xFFF59E0B)
                                  : const Color(
                                      0xFF8B5CF6,
                                    ).withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 游玩次数
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${widget.map.playCount}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '局',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
                : const Color(0xFF64748B),
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
