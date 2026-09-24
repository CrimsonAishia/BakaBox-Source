import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../core/core.dart';
import '../../core/bloc/activity/activity_bloc.dart';
import '../../desktop/widgets/welcome/activity_banner_carousel.dart';
import '../../desktop/widgets/welcome/online_trend_chart.dart';
import '../../desktop/widgets/welcome/update_logs_panel.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final serverBloc = context.read<ServerBloc>();
    final serverStatsBloc = context.read<ServerStatsBloc>();
    final updateLogBloc = context.read<UpdateLogBloc>();
    final activityBloc = context.read<ActivityBloc>();

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

    if (activityBloc.state.activities.isEmpty &&
        activityBloc.state.status != ActivityStatus.loading) {
      activityBloc.add(const ActivityFetch());
    }
    if (updateLogBloc.state.logs.isEmpty && !updateLogBloc.state.isLoading) {
      updateLogBloc.add(const UpdateLogFetch());
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
      listenWhen: (prev, curr) =>
          prev.serverCategories.isEmpty && curr.serverCategories.isNotEmpty,
      listener: (context, state) =>
          context.read<ServerBloc>().add(ServerUpdateCategoryOnlineCounts()),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.slate900 : AppColors.slate100,
        body: RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            _loadData();
            await Future.delayed(const Duration(milliseconds: 800));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeaderAndStats(context, isDark)),
              SliverToBoxAdapter(child: _buildQuickActions(context, isDark)),
              BlocBuilder<ActivityBloc, ActivityState>(
                builder: (context, state) {
                  if (state.activities.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: const ActivityBannerCarousel(isMobile: true),
                    ),
                  );
                },
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SizedBox(
                    height: 280,
                    child: UpdateLogsPanel(isDark: isDark),
                  ),
                ),
              ),
              BlocBuilder<ServerStatsBloc, ServerStatsState>(
                builder: (context, statsState) {
                  final stats = statsState.stats;
                  if (stats == null) {
                    return const SliverToBoxAdapter(child: SizedBox());
                  }
                  return SliverList(
                    delegate: SliverChildListDelegate([
                      _buildChartCard(
                        context,
                        isDark,
                        '在线趋势',
                        SizedBox(
                          height: 160,
                          child: DailyTrendChartWidget(
                            isDark: isDark,
                            stats: stats,
                          ),
                        ),
                        0,
                      ),
                      _buildChartCard(
                        context,
                        isDark,
                        '热门时段',
                        SizedBox(
                          height: 160,
                          child: HourlyBarChartWidget(
                            isDark: isDark,
                            stats: stats,
                          ),
                        ),
                        1,
                      ),
                      _buildChartCard(
                        context,
                        isDark,
                        '热门地图',
                        TopMapsListWidget(
                          isDark: isDark,
                          maps: stats.topMaps,
                          isMobile: true,
                        ),
                        2,
                      ),
                    ]),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAndStats(BuildContext context, bool isDark) {
    final paddingTop = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        // 顶部背景渐变 (类似于桌面端的背景)
        Container(
          height: paddingTop + 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      AppColors.slate900,
                      AppColors.slate800,
                      const Color(0xFF1A1A2E),
                    ]
                  : [
                      const Color(0xFFE3F2FD),
                      const Color(0xFFE0F7FA),
                      const Color(0xFFEDE7F6),
                    ],
            ),
          ),
        ),
        Column(
          children: [
            SizedBox(height: paddingTop + 16),
            // 问候语头部
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _WelcomeHeaderMobile(isDark: isDark),
            ),
            const SizedBox(height: 24),
            // 悬浮数据统计卡片
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _StatsBoardMobile(isDark: isDark),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _QuickActionItem(
                icon: MdiIcons.forum,
                label: '社区论坛',
                color: AppColors.amber500,
                onTap: () => _openUrl(_forumUrl),
                isDark: isDark,
              ),
            ),
            SizedBox(
              height: 40,
              width: 1,
              child: CustomPaint(
                painter: _DashedLinePainter(
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
              ),
            ),
            Expanded(
              child: _QuickActionItem(
                icon: MdiIcons.web,
                label: '官方网站',
                color: AppColors.violet500,
                onTap: () => _openUrl(_websiteUrl),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(
    BuildContext context,
    bool isDark,
    String title,
    Widget child,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.blue500,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.slate800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// 移动端专属问候语头部
class _WelcomeHeaderMobile extends StatelessWidget {
  final bool isDark;

  const _WelcomeHeaderMobile({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final username = authState.userInfo?.username;
        final greeting = _getGreeting();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username != null
                        ? '$greeting，\n$username 👋'
                        : '$greeting 👋',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.slate800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getSubtitle(),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.6)
                          : AppColors.slate600,
                    ),
                  ),
                ],
              ),
            ),
            // 右侧 Logo 或 头像
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: isDark ? AppColors.slate800 : Colors.white,
                backgroundImage: const AssetImage('assets/images/logo.png'),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    if (hour < 22) return '晚上好';
    return '夜深了';
  }

  String _getSubtitle() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '还在熬夜？注意休息哦 🌙';
    if (hour < 12) return '今天也是充满活力的一天！☀️';
    if (hour < 14) return '午饭吃了吗？🍱';
    if (hour < 18) return '下午好，来一局？🎮';
    if (hour < 22) return '晚上好，服务器正在等你 🚀';
    return '这么晚还在玩？注意休息哦 ☕';
  }
}

/// 移动端数据概览卡片 (悬浮在顶部渐变之上)
class _StatsBoardMobile extends StatelessWidget {
  final bool isDark;

  const _StatsBoardMobile({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.slate800.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: BlocBuilder<ServerStatsBloc, ServerStatsState>(
        builder: (context, statsState) {
          final totalServers = statsState.stats?.totalServerCount ?? 0;
          final currentPlayers = statsState.stats?.currentPlayers ?? 0;
          final todayMax = statsState.stats?.todayMax ?? 0;

          return Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: MdiIcons.accountGroup,
                  color: AppColors.emerald500,
                  value: currentPlayers.toString(),
                  label: '在线玩家',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: MdiIcons.server,
                  color: AppColors.blue500,
                  value: totalServers.toString(),
                  label: '服务器',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: MdiIcons.trendingUp,
                  color: AppColors.amber500,
                  value: todayMax.toString(),
                  label: '今日峰值',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.slate800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : AppColors.slate500,
          ),
        ),
      ],
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _QuickActionItem({
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.slate800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashHeight = 4.0;
    const dashSpace = 4.0;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
