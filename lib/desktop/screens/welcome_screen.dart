import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/core.dart';
import '../../core/widgets/disk_cached_image.dart';

/// 欢迎界面回调类型
typedef OnNavigateToServers = void Function();

/// 首页欢迎界面
/// Hero 展示型设计，渐变背景 + 浮动图标 + 核心数据统计
class WelcomeScreen extends StatefulWidget {
  final OnNavigateToServers? onNavigateToServers;

  const WelcomeScreen({super.key, this.onNavigateToServers});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  /// 社区论坛URL
  static const String _forumUrl = 'https://bbs.zombieden.cn/';

  /// 官方网站URL
  static const String _websiteUrl = 'https://baka.aishia.cc';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  /// 加载首页所需数据
  void _loadData() {
    final serverBloc = context.read<ServerBloc>();
    final serverStatsBloc = context.read<ServerStatsBloc>();

    if (serverBloc.state.serverCategories.isEmpty &&
        !serverBloc.state.isLoading) {
      serverBloc.add(ServerFetchList());
    }
    if (serverBloc.state.serverCategories.isNotEmpty) {
      serverBloc.add(ServerUpdateCategoryOnlineCounts());
    }
    if (serverStatsBloc.state.stats == null &&
        !serverStatsBloc.state.isLoading) {
      serverStatsBloc.add(const ServerStatsFetch());
    }
  }

  /// 打开社区论坛
  Future<void> _openForum() async {
    final uri = Uri.parse(_forumUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// 打开官方网站
  Future<void> _openWebsite() async {
    final uri = Uri.parse(_websiteUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocListener<ServerBloc, ServerState>(
      listenWhen: (previous, current) {
        return previous.serverCategories.isEmpty &&
            current.serverCategories.isNotEmpty;
      },
      listener: (context, state) {
        context.read<ServerBloc>().add(ServerUpdateCategoryOnlineCounts());
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // 渐变背景
            _GradientBackground(isDark: isDark),
            // 浮动图标
            const _FloatingIcons(),
            // 主要内容
            _buildMainContent(context, theme, isDark),
          ],
        ),
      ),
    );
  }

  /// 构建主要内容
  Widget _buildMainContent(BuildContext context, ThemeData theme, bool isDark) {
    return Column(
      children: [
        Expanded(flex: 3, child: _buildHeroSection(context, theme, isDark)),
        Expanded(flex: 2, child: _buildStatsSection(context, theme, isDark)),
      ],
    );
  }

  /// 构建 Hero 区域
  Widget _buildHeroSection(BuildContext context, ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(isDark),
            const SizedBox(height: 32),
            _buildActionButtons(context, theme, isDark),
          ],
        ),
      ),
    );
  }

  /// 构建 Logo
  Widget _buildLogo(bool isDark) {
    return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo.png',
            width: 150,
            height: 150,
            fit: BoxFit.contain,
          ),
        )
        .animate()
        .fadeIn(duration: 600.ms)
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
          duration: 600.ms,
          curve: Curves.easeOutBack,
        );
  }

  /// 构建操作按钮
  Widget _buildActionButtons(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPrimaryButton(
              icon: MdiIcons.serverNetwork,
              label: '浏览服务器',
              onPressed: () => widget.onNavigateToServers?.call(),
            ),
            const SizedBox(width: 16),
            _buildSecondaryButton(
              icon: MdiIcons.forum,
              label: '社区论坛',
              onPressed: _openForum,
              isDark: isDark,
            ),
            const SizedBox(width: 16),
            _buildWebsiteButton(
              icon: MdiIcons.web,
              label: '官方网站',
              onPressed: _openWebsite,
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 600.ms, delay: 600.ms)
        .slideY(
          begin: 0.3,
          end: 0,
          duration: 500.ms,
          curve: Curves.easeOutCubic,
        );
  }

  /// 构建主按钮
  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return _HoverScaleButton(
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建次按钮
  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return _HoverScaleButton(
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建官网按钮
  Widget _buildWebsiteButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return _HoverScaleButton(
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建统计数据区域
  Widget _buildStatsSection(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 0, 48, 48),
      child: Column(
        children: [
          Container(
                width: 60,
                height: 3,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              )
              .animate()
              .fadeIn(duration: 600.ms, delay: 800.ms)
              .scaleX(
                begin: 0,
                end: 1,
                duration: 500.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 32),
          Expanded(
            child: BlocBuilder<ServerBloc, ServerState>(
              builder: (context, serverState) {
                return BlocBuilder<ServerStatsBloc, ServerStatsState>(
                  builder: (context, statsState) {
                    return _buildStatsCards(
                      context,
                      theme,
                      isDark,
                      serverState,
                      statsState,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建统计卡片
  Widget _buildStatsCards(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    ServerState serverState,
    ServerStatsState statsState,
  ) {
    final officialCategories = serverState.serverCategories.where(
      (cat) => !cat.isCustom,
    );
    final totalServers = officialCategories.fold<int>(
      0,
      (sum, cat) => sum + cat.serverList.length,
    );
    final totalOnlinePlayers = officialCategories.fold<int>(
      0,
      (sum, cat) =>
          sum + (serverState.categoryOnlineCounts[cat.modelName ?? ''] ?? 0),
    );

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: MdiIcons.server,
            iconColor: const Color(0xFF3B82F6),
            value: totalServers.toString(),
            subtitle: '台服务器',
            isDark: isDark,
            delay: 900,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            icon: MdiIcons.accountGroup,
            iconColor: const Color(0xFF10B981),
            value: totalOnlinePlayers.toString(),
            subtitle: '人正在游戏',
            isDark: isDark,
            delay: 1000,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: _PlayerTrendCard(
            isDark: isDark,
            delay: 1100,
            stats: statsState.stats,
          ),
        ),
      ],
    );
  }
}

/// 渐变背景组件
class _GradientBackground extends StatelessWidget {
  final bool isDark;
  const _GradientBackground({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF0F172A),
                  const Color(0xFF1E293B),
                  const Color(0xFF1A1A2E),
                ]
              : [
                  const Color(0xFFE3F2FD),
                  const Color(0xFFE0F7FA),
                  const Color(0xFFEDE7F6),
                  const Color(0xFFFFF3E0),
                ],
          stops: isDark ? [0.0, 0.5, 1.0] : [0.0, 0.35, 0.7, 1.0],
        ),
      ),
    );
  }
}

/// 浮动图标组件
class _FloatingIcons extends StatelessWidget {
  const _FloatingIcons();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _FloatingIcon(emoji: '❄️', size: 48, top: 0.15, left: 0.10, delay: 0),
        _FloatingIcon(
          emoji: '🌊',
          size: 40,
          top: 0.25,
          right: 0.15,
          delay: 1000,
        ),
        _FloatingIcon(
          emoji: '✨',
          size: 36,
          bottom: 0.35,
          left: 0.08,
          delay: 2000,
        ),
        _FloatingIcon(
          emoji: '🌟',
          size: 32,
          top: 0.45,
          right: 0.10,
          delay: 3000,
        ),
        _FloatingIcon(
          emoji: '💎',
          size: 28,
          top: 0.60,
          left: 0.15,
          delay: 1500,
        ),
        _FloatingIcon(
          emoji: '🎮',
          size: 36,
          bottom: 0.25,
          right: 0.12,
          delay: 2500,
        ),
      ],
    );
  }
}

/// 单个浮动图标
class _FloatingIcon extends StatefulWidget {
  final String emoji;
  final double size;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final int delay;

  const _FloatingIcon({
    required this.emoji,
    required this.size,
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.delay,
  });

  @override
  State<_FloatingIcon> createState() => _FloatingIconState();
}

class _FloatingIconState extends State<_FloatingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _floatAnimation = Tween<double>(
      begin: 0,
      end: 20,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 0.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned(
      top: widget.top != null ? size.height * widget.top! : null,
      bottom: widget.bottom != null ? size.height * widget.bottom! : null,
      left: widget.left != null ? size.width * widget.left! : null,
      right: widget.right != null ? size.width * widget.right! : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -_floatAnimation.value),
            child: Transform.rotate(
              angle: _rotateAnimation.value * math.pi,
              child: Opacity(
                opacity: 0.7,
                child: Text(
                  widget.emoji,
                  style: TextStyle(fontSize: widget.size),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 统计卡片组件
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String subtitle;
  final bool isDark;
  final int delay;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.subtitle,
    required this.isDark,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: delay.ms)
        .slideY(
          begin: 0.2,
          end: 0,
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

/// 悬停缩放按钮
class _HoverScaleButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  const _HoverScaleButton({required this.onPressed, required this.child});

  @override
  State<_HoverScaleButton> createState() => _HoverScaleButtonState();
}

class _HoverScaleButtonState extends State<_HoverScaleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 200),
            offset: Offset(0, _isHovered ? -0.05 : 0),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// 统计数据卡片（带 Tab 切换）
class _PlayerTrendCard extends StatefulWidget {
  final bool isDark;
  final int delay;
  final ServerStatsResponse? stats;

  const _PlayerTrendCard({
    required this.isDark,
    required this.delay,
    this.stats,
  });

  @override
  State<_PlayerTrendCard> createState() => _PlayerTrendCardState();
}

class _PlayerTrendCardState extends State<_PlayerTrendCard> {
  int _selectedTab = 0;
  static const _tabs = ['在线趋势', '热门时段', '热门服务器', '热门地图'];

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    if (stats == null || stats.dailyStats.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.8),
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
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTabBar(),
              const SizedBox(height: 16),
              Expanded(child: _buildTabContent(stats)),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: widget.delay.ms)
        .slideY(
          begin: 0.2,
          end: 0,
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildTabBar() {
    return Row(
      children: [
        for (int i = 0; i < _tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _buildTabItem(i, _tabs[i]),
        ],
      ],
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF8B5CF6)
                : (widget.isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : const Color(0xFF94A3B8)),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(ServerStatsResponse stats) {
    return switch (_selectedTab) {
      0 => _DailyTrendChart(isDark: widget.isDark, stats: stats),
      1 => _HourlyChart(
        isDark: widget.isDark,
        hourlyStats: stats.hourlyStats,
        peakHour: stats.peakHour,
      ),
      2 => _TopServersList(isDark: widget.isDark, servers: stats.topServers),
      3 => _TopMapsList(isDark: widget.isDark, maps: stats.topMaps),
      _ => const SizedBox(),
    };
  }

  Widget _buildEmptyState() {
    return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.8),
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
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '加载统计数据...',
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: widget.delay.ms)
        .slideY(
          begin: 0.2,
          end: 0,
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

/// 每日趋势折线图
class _DailyTrendChart extends StatelessWidget {
  final bool isDark;
  final ServerStatsResponse stats;

  const _DailyTrendChart({required this.isDark, required this.stats});

  @override
  Widget build(BuildContext context) {
    final dailyStats = stats.dailyStats;
    final maxY = dailyStats
        .map((d) => d.maxPlayers)
        .reduce(math.max)
        .toDouble();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _LegendItem(
              color: const Color(0xFF3B82F6),
              label: '最高 ${stats.weeklyMax}',
              isDark: isDark,
            ),
            const SizedBox(width: 16),
            _LegendItem(
              color: const Color(0xFF10B981),
              label: '平均 ${stats.weeklyAvg}',
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LineChart(
            key: ValueKey(isDark),
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
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
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= dailyStats.length) {
                        return const SizedBox();
                      }
                      final dateStr = dailyStats[index].date;
                      final parts = dateStr.split('-');
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${parts[1]}/${parts[2]}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
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
              maxX: (dailyStats.length - 1).toDouble(),
              minY: 0,
              maxY: maxY * 1.1,
              lineBarsData: [
                LineChartBarData(
                  spots: dailyStats
                      .asMap()
                      .entries
                      .map(
                        (e) => FlSpot(
                          e.key.toDouble(),
                          e.value.maxPlayers.toDouble(),
                        ),
                      )
                      .toList(),
                  isCurved: true,
                  color: const Color(0xFF3B82F6),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF3B82F6),
                          strokeWidth: 2,
                          strokeColor: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                        ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF3B82F6).withValues(alpha: 0.3),
                        const Color(0xFF3B82F6).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                LineChartBarData(
                  spots: dailyStats
                      .asMap()
                      .entries
                      .map(
                        (e) => FlSpot(
                          e.key.toDouble(),
                          e.value.avgPlayers.toDouble(),
                        ),
                      )
                      .toList(),
                  isCurved: true,
                  color: const Color(0xFF10B981),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF10B981),
                          strokeWidth: 2,
                          strokeColor: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                        ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF10B981).withValues(alpha: 0.2),
                        const Color(0xFF10B981).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) =>
                      isDark ? const Color(0xFF374151) : Colors.white,
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                    final isMax = spot.barIndex == 0;
                    return LineTooltipItem(
                      '${isMax ? "最高" : "平均"}: ${spot.y.toInt()}',
                      TextStyle(
                        color: isMax
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 24小时热门时段柱状图
class _HourlyChart extends StatelessWidget {
  final bool isDark;
  final List<HourlyStat> hourlyStats;
  final int peakHour;

  const _HourlyChart({
    required this.isDark,
    required this.hourlyStats,
    required this.peakHour,
  });

  @override
  Widget build(BuildContext context) {
    if (hourlyStats.isEmpty) {
      return Center(
        child: Text(
          '暂无数据',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black38),
        ),
      );
    }

    final maxY = hourlyStats
        .map((h) => h.avgPlayers)
        .reduce(math.max)
        .toDouble();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(MdiIcons.fire, size: 14, color: const Color(0xFFEF4444)),
            const SizedBox(width: 4),
            Text(
              '峰值时段 $peakHour:00',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY * 1.1,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) =>
                      isDark ? const Color(0xFF374151) : Colors.white,
                  tooltipRoundedRadius: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem(
                        '${hourlyStats[groupIndex].hour}:00\n${rod.toY.toInt()} 人',
                        TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
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
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final hour = value.toInt();
                      if (hour % 4 != 0) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '$hour',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: hourlyStats.asMap().entries.map((e) {
                final isPeak = e.value.hour == peakHour;
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.avgPlayers.toDouble(),
                      color: isPeak
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF8B5CF6),
                      width: 8,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// 热门服务器列表
class _TopServersList extends StatefulWidget {
  final bool isDark;
  final List<TopServer> servers;

  const _TopServersList({required this.isDark, required this.servers});

  @override
  State<_TopServersList> createState() => _TopServersListState();
}

class _TopServersListState extends State<_TopServersList> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, String> _serverNameCache = {};
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollIndicators();
      _loadServerNames();
    });
  }

  @override
  void didUpdateWidget(_TopServersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.servers != widget.servers) {
      _loadServerNames();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    super.dispose();
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

  /// 从 Steam 查询服务器名称
  Future<void> _loadServerNames() async {
    for (final server in widget.servers) {
      if (_serverNameCache.containsKey(server.address)) continue;

      final parts = server.address.split(':');
      if (parts.length != 2) continue;

      final ip = parts[0];
      final port = int.tryParse(parts[1]);
      if (port == null) continue;

      try {
        final info = await SourceServerService.getServerInfo(
          ip,
          port,
          timeout: 3000,
        );
        if (mounted && info != null && info.name.isNotEmpty) {
          setState(() => _serverNameCache[server.address] = info.name);
        }
      } catch (_) {
        // 查询失败则使用地址
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.servers.isEmpty) {
      return Center(
        child: Text(
          '暂无数据',
          style: TextStyle(
            color: widget.isDark ? Colors.white54 : Colors.black38,
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView.separated(
          controller: _scrollController,
          itemCount: widget.servers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final server = widget.servers[index];
            final maxWidth = widget.servers.first.avgPlayers.toDouble();
            final widthRatio = server.avgPlayers / maxWidth;
            final serverName =
                _serverNameCache[server.address] ?? server.address;

            return Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: index < 3
                          ? const Color(0xFFF59E0B)
                          : (widget.isDark
                                ? Colors.white54
                                : const Color(0xFF94A3B8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: widthRatio,
                        child: Container(
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: index < 3
                                  ? [
                                      const Color(
                                        0xFFF59E0B,
                                      ).withValues(alpha: 0.3),
                                      const Color(
                                        0xFFF59E0B,
                                      ).withValues(alpha: 0.1),
                                    ]
                                  : [
                                      const Color(
                                        0xFF8B5CF6,
                                      ).withValues(alpha: 0.3),
                                      const Color(
                                        0xFF8B5CF6,
                                      ).withValues(alpha: 0.1),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  serverName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: widget.isDark
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '峰值 ${server.maxPlayers} / 均值 ${server.avgPlayers}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: widget.isDark
                                      ? Colors.white54
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        if (_canScrollUp)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildScrollIndicator(isTop: true),
          ),
        if (_canScrollDown)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildScrollIndicator(isTop: false),
          ),
      ],
    );
  }

  Widget _buildScrollIndicator({required bool isTop}) {
    final bgColor = widget.isDark ? const Color(0xFF1E293B) : Colors.white;
    return IgnorePointer(
      child: Container(
        height: 24,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              bgColor,
              bgColor.withValues(alpha: 0.8),
              bgColor.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        child: Icon(
          isTop ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: const Color(0xFF6B7280),
          size: 16,
        ),
      ),
    );
  }
}

/// 热门地图列表
class _TopMapsList extends StatefulWidget {
  final bool isDark;
  final List<TopMap> maps;

  const _TopMapsList({required this.isDark, required this.maps});

  @override
  State<_TopMapsList> createState() => _TopMapsListState();
}

class _TopMapsListState extends State<_TopMapsList> {
  final ServerApi _serverApi = ServerApi();
  final Map<String, MapData?> _mapInfoCache = {};
  final ScrollController _scrollController = ScrollController();
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicators);
    _loadMapInfos();
  }

  @override
  void didUpdateWidget(_TopMapsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maps != widget.maps) {
      _loadMapInfos();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _loadMapInfos() async {
    for (final map in widget.maps) {
      if (!_mapInfoCache.containsKey(map.mapName)) {
        final mapInfo = await _serverApi.getMapInfo(map.mapName);
        if (mounted) {
          setState(() => _mapInfoCache[map.mapName] = mapInfo);
        }
      }
    }
    // 加载完成后更新滚动指示器
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateScrollIndicators(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.maps.isEmpty) {
      return Center(
        child: Text(
          '暂无数据',
          style: TextStyle(
            color: widget.isDark ? Colors.white54 : Colors.black38,
          ),
        ),
      );
    }
    
    return Stack(
      children: [
        ListView.separated(
          controller: _scrollController,
          itemCount: widget.maps.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final map = widget.maps[index];
            final maxWidth = widget.maps.first.playCount.toDouble();
            final widthRatio = map.playCount / maxWidth;
            final mapInfo = _mapInfoCache[map.mapName];
            final displayName = mapInfo?.mapLabel.isNotEmpty == true
                ? '${mapInfo!.mapLabel} (${map.mapName})'
                : map.mapName;

            return Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: index < 3
                          ? const Color(0xFF10B981)
                          : (widget.isDark
                                ? Colors.white54
                                : const Color(0xFF94A3B8)),
                    ),
                  ),
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
                            color: widget.isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.03),
                          ),
                          // 地图背景图
                          Positioned.fill(
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                Colors.black.withValues(alpha: 0.5),
                                BlendMode.darken,
                              ),
                              child: DiskCachedImage(
                                imageUrl: mapInfo?.mapUrl ?? '',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                fallbackAsset:
                                    'assets/images/default-map-bg.jpg',
                              ),
                            ),
                          ),
                          // 进度条
                          FractionallySizedBox(
                            widthFactor: widthRatio,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: index < 3
                                      ? [
                                          const Color(
                                            0xFF10B981,
                                          ).withValues(alpha: 0.5),
                                          const Color(
                                            0xFF10B981,
                                          ).withValues(alpha: 0.2),
                                        ]
                                      : [
                                          const Color(
                                            0xFF3B82F6,
                                          ).withValues(alpha: 0.5),
                                          const Color(
                                            0xFF3B82F6,
                                          ).withValues(alpha: 0.2),
                                        ],
                                ),
                              ),
                            ),
                          ),
                          // 文字
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black54,
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${map.playCount} 次',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white70,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 2,
                                        ),
                                      ],
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
            );
          },
        ),
        if (_canScrollUp)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildScrollIndicator(isTop: true),
          ),
        if (_canScrollDown)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildScrollIndicator(isTop: false),
          ),
      ],
    );
  }

  Widget _buildScrollIndicator({required bool isTop}) {
    final bgColor = widget.isDark ? const Color(0xFF1E293B) : Colors.white;
    return IgnorePointer(
      child: Container(
        height: 24,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              bgColor,
              bgColor.withValues(alpha: 0.8),
              bgColor.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        child: Icon(
          isTop ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: const Color(0xFF6B7280),
          size: 16,
        ),
      ),
    );
  }
}

/// 图例项
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDark;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? Colors.white.withValues(alpha: 0.7)
                : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
