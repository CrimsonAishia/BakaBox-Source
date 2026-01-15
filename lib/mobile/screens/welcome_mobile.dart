import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/core.dart';
import '../../core/widgets/disk_cached_image.dart';

/// 移动端首页
class WelcomeMobile extends StatefulWidget {
  final VoidCallback? onNavigateToServers;

  const WelcomeMobile({super.key, this.onNavigateToServers});

  @override
  State<WelcomeMobile> createState() => _WelcomeMobileState();
}

class _WelcomeMobileState extends State<WelcomeMobile> {
  static const String _forumUrl = 'https://bbs.zombieden.cn/';
  static const String _websiteUrl = 'https://baka.aishia.cc';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final serverBloc = context.read<ServerBloc>();
    final serverStatsBloc = context.read<ServerStatsBloc>();

    if (serverBloc.state.serverCategories.isEmpty && !serverBloc.state.isLoading) {
      serverBloc.add(ServerFetchList());
    }
    if (serverBloc.state.serverCategories.isNotEmpty) {
      serverBloc.add(ServerUpdateCategoryOnlineCounts());
    }
    if (serverStatsBloc.state.stats == null && !serverStatsBloc.state.isLoading) {
      serverStatsBloc.add(const ServerStatsFetch());
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocListener<ServerBloc, ServerState>(
      listenWhen: (prev, curr) => prev.serverCategories.isEmpty && curr.serverCategories.isNotEmpty,
      listener: (context, state) => context.read<ServerBloc>().add(ServerUpdateCategoryOnlineCounts()),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        body: RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            _loadData();
            await Future.delayed(const Duration(milliseconds: 800));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, isDark)),
              SliverToBoxAdapter(child: _buildQuickActions(context, isDark)),
              SliverToBoxAdapter(child: _buildLiveStats(context, isDark)),
              SliverToBoxAdapter(child: _buildTrendSection(context, isDark)),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset('assets/images/logo.png', width: 40, height: 40),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('BakaBox', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF97316)]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('CS2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('查看服务器状态和数据统计', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0, duration: 350.ms);
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionCard(
              icon: MdiIcons.forum,
              label: '社区论坛',
              color: const Color(0xFFF59E0B),
              onTap: () => _openUrl(_forumUrl),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionCard(
              icon: MdiIcons.web,
              label: '官方网站',
              color: const Color(0xFF8B5CF6),
              onTap: () => _openUrl(_websiteUrl),
              isDark: isDark,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0, duration: 350.ms);
  }

  Widget _buildLiveStats(BuildContext context, bool isDark) {
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, serverState) {
        final officialCategories = serverState.serverCategories.where((cat) => !cat.isCustom);
        final totalServers = officialCategories.fold<int>(0, (sum, cat) => sum + cat.serverList.length);
        final totalOnlinePlayers = officialCategories.fold<int>(0, (sum, cat) => sum + (serverState.categoryOnlineCounts[cat.modelName ?? ''] ?? 0));

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(child: _LiveStatCard(icon: MdiIcons.server, value: totalServers.toString(), label: '服务器', color: const Color(0xFF3B82F6), isDark: isDark)),
              const SizedBox(width: 12),
              Expanded(child: _LiveStatCard(icon: MdiIcons.accountGroup, value: totalOnlinePlayers.toString(), label: '在线玩家', color: const Color(0xFF10B981), isDark: isDark)),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1, end: 0, duration: 350.ms);
      },
    );
  }

  Widget _buildTrendSection(BuildContext context, bool isDark) {
    return BlocBuilder<ServerStatsBloc, ServerStatsState>(
      builder: (context, statsState) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(MdiIcons.chartLine, size: 18, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text('数据统计', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                ],
              ),
              const SizedBox(height: 12),
              _TrendCard(isDark: isDark, stats: statsState.stats),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.1, end: 0, duration: 350.ms);
      },
    );
  }
}


/// 快捷入口卡片 - 统一风格
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
            ],
          ),
        ),
      ),
    );
  }
}

/// 实时数据卡片
class _LiveStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _LiveStatCard({required this.icon, required this.value, required this.label, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 趋势卡片
class _TrendCard extends StatefulWidget {
  final bool isDark;
  final ServerStatsResponse? stats;

  const _TrendCard({required this.isDark, this.stats});

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _tabs = ['趋势', '时段', '服务器', '地图'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15), // 略小于外层圆角，避免边框被裁剪
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: widget.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF3B82F6),
                unselectedLabelColor: widget.isDark ? Colors.white54 : const Color(0xFF94A3B8),
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                indicatorColor: const Color(0xFF3B82F6),
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                tabs: _tabs.map((t) => Tab(text: t, height: 40)).toList(),
              ),
            ),
            SizedBox(
              height: 240,
              child: stats == null || stats.dailyStats.isEmpty
                  ? _buildLoading()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _DailyTrendChart(isDark: widget.isDark, stats: stats),
                        _HourlyChart(isDark: widget.isDark, hourlyStats: stats.hourlyStats, peakHour: stats.peakHour),
                        _TopServersList(isDark: widget.isDark, servers: stats.topServers),
                        _TopMapsList(isDark: widget.isDark, maps: stats.topMaps),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: widget.isDark ? Colors.white38 : const Color(0xFF94A3B8))),
          const SizedBox(height: 12),
          Text('加载中...', style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.white38 : const Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}


/// 每日趋势图 - 点击显示数据
class _DailyTrendChart extends StatelessWidget {
  final bool isDark;
  final ServerStatsResponse stats;

  const _DailyTrendChart({required this.isDark, required this.stats});

  @override
  Widget build(BuildContext context) {
    final dailyStats = stats.dailyStats;
    final maxY = dailyStats.map((d) => d.maxPlayers).reduce(math.max).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: const Color(0xFF3B82F6), label: '最高 ${stats.weeklyMax}'),
              const SizedBox(width: 20),
              _LegendDot(color: const Color(0xFF10B981), label: '平均 ${stats.weeklyAvg}'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 3,
                  getDrawingHorizontalLine: (value) => FlLine(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= dailyStats.length) return const SizedBox();
                        final parts = dailyStats[index].date.split('-');
                        return Text('${parts[1]}/${parts[2]}', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (dailyStats.length - 1).toDouble(),
                minY: 0,
                maxY: maxY * 1.15,
                lineBarsData: [
                  _buildLine(dailyStats.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.maxPlayers.toDouble())).toList(), const Color(0xFF3B82F6)),
                  _buildLine(dailyStats.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.avgPlayers.toDouble())).toList(), const Color(0xFF10B981)),
                ],
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) => isDark ? const Color(0xFF374151) : Colors.white,
                    tooltipRoundedRadius: 6,
                    getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('${s.barIndex == 0 ? "最高" : "平均"}: ${s.y.toInt()}', TextStyle(color: s.barIndex == 0 ? const Color(0xFF3B82F6) : const Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 11))).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 3, color: color, strokeWidth: 0)),
      belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)])),
    );
  }
}

/// 24小时热门时段 - 点击显示数据
class _HourlyChart extends StatelessWidget {
  final bool isDark;
  final List<HourlyStat> hourlyStats;
  final int peakHour;

  const _HourlyChart({required this.isDark, required this.hourlyStats, required this.peakHour});

  @override
  Widget build(BuildContext context) {
    if (hourlyStats.isEmpty) return Center(child: Text('暂无数据', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)));

    final maxY = hourlyStats.map((h) => h.avgPlayers).reduce(math.max).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(MdiIcons.fire, size: 14, color: const Color(0xFFEF4444)),
              const SizedBox(width: 4),
              Text('峰值时段 $peakHour:00', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : const Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.15,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) => isDark ? const Color(0xFF374151) : Colors.white,
                    tooltipRoundedRadius: 6,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem('${hourlyStats[groupIndex].hour}:00\n${rod.toY.toInt()} 人', TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 11)),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (value, meta) {
                        final hour = value.toInt();
                        if (hour % 6 != 0) return const SizedBox();
                        return Text('$hour', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)));
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: hourlyStats.asMap().entries.map((e) {
                  final isPeak = e.value.hour == peakHour;
                  return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value.avgPlayers.toDouble(), color: isPeak ? const Color(0xFFEF4444) : const Color(0xFF8B5CF6).withValues(alpha: 0.7), width: 5, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// 热门服务器列表 - 带滚动指示器
class _TopServersList extends StatefulWidget {
  final bool isDark;
  final List<TopServer> servers;

  const _TopServersList({required this.isDark, required this.servers});

  @override
  State<_TopServersList> createState() => _TopServersListState();
}

class _TopServersListState extends State<_TopServersList> {
  final Map<String, String> _nameCache = {};
  final ScrollController _scrollController = ScrollController();
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicators);
    _loadNames();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TopServersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.servers != widget.servers) {
      _loadNames();
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
    }
  }

  void _updateScrollIndicators() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canUp = position.pixels > 0;
    final canDown = position.pixels < position.maxScrollExtent;
    if (canUp != _canScrollUp || canDown != _canScrollDown) {
      setState(() {
        _canScrollUp = canUp;
        _canScrollDown = canDown;
      });
    }
  }

  Future<void> _loadNames() async {
    for (final server in widget.servers) {
      if (_nameCache.containsKey(server.address)) continue;
      final parts = server.address.split(':');
      if (parts.length != 2) continue;
      try {
        final info = await SourceServerService.getServerInfo(parts[0], int.parse(parts[1]), timeout: 3000);
        if (mounted && info != null && info.name.isNotEmpty) {
          setState(() => _nameCache[server.address] = info.name);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.servers.isEmpty) return Center(child: Text('暂无数据', style: TextStyle(color: widget.isDark ? Colors.white38 : Colors.black38)));

    final maxVal = widget.servers.first.avgPlayers.toDouble();

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: widget.servers.length,
          itemBuilder: (context, index) {
            final server = widget.servers[index];
            final ratio = server.avgPlayers / maxVal;
            final name = _nameCache[server.address] ?? server.address;
            final isTop3 = index < 3;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isTop3 ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isTop3 ? const Color(0xFFF59E0B) : (widget.isDark ? Colors.white38 : const Color(0xFF94A3B8)))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: widget.isDark ? Colors.white : const Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Stack(
                          children: [
                            Container(height: 4, decoration: BoxDecoration(color: widget.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(2))),
                            FractionallySizedBox(widthFactor: ratio, child: Container(height: 4, decoration: BoxDecoration(color: isTop3 ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6), borderRadius: BorderRadius.circular(2)))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${server.avgPlayers}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white54 : const Color(0xFF64748B))),
                ],
              ),
            );
          },
        ),
        // 上滚动指示器
        if (_canScrollUp)
          Positioned(top: 0, left: 0, right: 0, child: _ScrollIndicator(isTop: true, isDark: widget.isDark)),
        // 下滚动指示器
        if (_canScrollDown)
          Positioned(bottom: 0, left: 0, right: 0, child: _ScrollIndicator(isTop: false, isDark: widget.isDark)),
      ],
    );
  }
}

/// 热门地图列表 - 带滚动指示器
class _TopMapsList extends StatefulWidget {
  final bool isDark;
  final List<TopMap> maps;

  const _TopMapsList({required this.isDark, required this.maps});

  @override
  State<_TopMapsList> createState() => _TopMapsListState();
}

class _TopMapsListState extends State<_TopMapsList> {
  final ServerApi _api = ServerApi();
  final Map<String, MapData?> _mapCache = {};
  final ScrollController _scrollController = ScrollController();
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicators);
    _loadMaps();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TopMapsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maps != widget.maps) {
      _loadMaps();
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
    }
  }

  void _updateScrollIndicators() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canUp = position.pixels > 0;
    final canDown = position.pixels < position.maxScrollExtent;
    if (canUp != _canScrollUp || canDown != _canScrollDown) {
      setState(() {
        _canScrollUp = canUp;
        _canScrollDown = canDown;
      });
    }
  }

  Future<void> _loadMaps() async {
    for (final map in widget.maps) {
      if (!_mapCache.containsKey(map.mapName)) {
        final info = await _api.getMapInfo(map.mapName);
        if (mounted) setState(() => _mapCache[map.mapName] = info);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.maps.isEmpty) return Center(child: Text('暂无数据', style: TextStyle(color: widget.isDark ? Colors.white38 : Colors.black38)));

    final maxVal = widget.maps.first.playCount.toDouble();

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: widget.maps.length,
          itemBuilder: (context, index) {
            final map = widget.maps[index];
            final ratio = map.playCount / maxVal;
            final mapInfo = _mapCache[map.mapName];
            final displayName = mapInfo?.mapLabel.isNotEmpty == true ? '${mapInfo!.mapLabel} (${map.mapName})' : map.mapName;
            final isTop3 = index < 3;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isTop3 ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isTop3 ? const Color(0xFF10B981) : (widget.isDark ? Colors.white38 : const Color(0xFF94A3B8)))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 32,
                        child: Stack(
                          children: [
                            // 背景色
                            Container(
                              color: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                            ),
                            // 地图背景图
                            if (mapInfo?.mapUrl != null)
                              Positioned.fill(
                                child: ColorFiltered(
                                  colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.darken),
                                  child: DiskCachedImage(
                                    imageUrl: mapInfo!.mapUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                              ),
                            // 进度条
                            FractionallySizedBox(
                              widthFactor: ratio,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isTop3
                                        ? [const Color(0xFF10B981).withValues(alpha: 0.5), const Color(0xFF10B981).withValues(alpha: 0.2)]
                                        : [const Color(0xFF3B82F6).withValues(alpha: 0.5), const Color(0xFF3B82F6).withValues(alpha: 0.2)],
                                  ),
                                ),
                              ),
                            ),
                            // 文字
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: mapInfo?.mapUrl != null ? Colors.white : (widget.isDark ? Colors.white : const Color(0xFF1E293B)),
                                          shadows: mapInfo?.mapUrl != null ? [const Shadow(color: Colors.black54, blurRadius: 2)] : null,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${map.playCount} 次',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: mapInfo?.mapUrl != null ? Colors.white70 : (widget.isDark ? Colors.white54 : const Color(0xFF94A3B8)),
                                        shadows: mapInfo?.mapUrl != null ? [const Shadow(color: Colors.black54, blurRadius: 2)] : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // 上滚动指示器
        if (_canScrollUp)
          Positioned(top: 0, left: 0, right: 0, child: _ScrollIndicator(isTop: true, isDark: widget.isDark)),
        // 下滚动指示器
        if (_canScrollDown)
          Positioned(bottom: 0, left: 0, right: 0, child: _ScrollIndicator(isTop: false, isDark: widget.isDark)),
      ],
    );
  }
}

/// 滚动指示器
class _ScrollIndicator extends StatelessWidget {
  final bool isTop;
  final bool isDark;

  const _ScrollIndicator({required this.isTop, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return IgnorePointer(
      child: Container(
        height: 20,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [bgColor, bgColor.withValues(alpha: 0.8), bgColor.withValues(alpha: 0)],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        child: Icon(isTop ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFF6B7280), size: 14),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }
}
