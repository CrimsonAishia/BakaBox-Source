import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/core.dart';
import '../widgets/welcome_v2/stats_cards_row.dart';
import '../widgets/welcome_v2/server_categories_panel.dart';
import '../widgets/welcome_v2/announcements_panel.dart';
import '../widgets/welcome_v2/update_logs_panel.dart';
import '../widgets/welcome_v2/online_trend_chart.dart';
import '../widgets/welcome_v2/live_rooms_section.dart';
import '../widgets/welcome_v2/videos_section.dart';

/// 欢迎界面回调类型
typedef OnNavigateToServers = void Function();

/// 首页欢迎界面
class WelcomeScreen extends StatefulWidget {
  final OnNavigateToServers? onNavigateToServers;

  const WelcomeScreen({super.key, this.onNavigateToServers});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  /// 各数据源的缓存时长
  static const _serverOnlineCountsTtl = Duration(minutes: 2);
  static const _statsTtl = Duration(minutes: 5);
  static const _announcementsTtl = Duration(minutes: 30);
  static const _updateLogsTtl = Duration(hours: 1);
  static const _bilibiliTtl = Duration(minutes: 10);

  bool _isStale(DateTime? lastFetched, Duration ttl) {
    if (lastFetched == null) return true;
    return DateTime.now().difference(lastFetched) > ttl;
  }

  /// 加载首页所需数据（基于时间戳缓存，避免频繁请求）
  void _loadData() {
    final serverBloc = context.read<ServerBloc>();
    final serverStatsBloc = context.read<ServerStatsBloc>();
    final announcementBloc = context.read<AnnouncementBloc>();
    final updateLogBloc = context.read<UpdateLogBloc>();
    final bilibiliBloc = context.read<BilibiliContentBloc>();

    // 服务器列表：没有就加载
    if (serverBloc.state.serverCategories.isEmpty &&
        !serverBloc.state.isLoading) {
      serverBloc.add(ServerFetchList());
    }
    // 服务器在线人数：每 2 分钟刷新一次
    if (serverBloc.state.serverCategories.isNotEmpty &&
        _isStale(serverBloc.state.onlineCountsLastFetched, _serverOnlineCountsTtl)) {
      serverBloc.add(ServerUpdateCategoryOnlineCounts());
    }

    // 统计数据：每 5 分钟刷新一次
    if (!serverStatsBloc.state.isLoading &&
        _isStale(serverStatsBloc.state.lastFetched, _statsTtl)) {
      serverStatsBloc.add(const ServerStatsFetch());
    }

    // 公告：每 30 分钟刷新一次
    if (!announcementBloc.state.isLoading &&
        _isStale(announcementBloc.state.lastFetched, _announcementsTtl)) {
      announcementBloc.add(AnnouncementFetch());
    }

    // 更新日志：每 1 小时刷新一次
    if (!updateLogBloc.state.isLoading &&
        _isStale(updateLogBloc.state.lastFetched, _updateLogsTtl)) {
      updateLogBloc.add(const UpdateLogFetch());
    }

    // B 站内容：每 10 分钟刷新一次
    if (_isStale(bilibiliBloc.state.liveRoomsLastFetched, _bilibiliTtl) &&
        bilibiliBloc.state.status != BilibiliContentStatus.loading) {
      bilibiliBloc.add(const BilibiliContentFetchRequested(tabIndex: 0));
    }
    if (_isStale(bilibiliBloc.state.videosLastFetched, _bilibiliTtl) &&
        bilibiliBloc.state.status != BilibiliContentStatus.loading) {
      bilibiliBloc.add(const BilibiliContentFetchRequested(tabIndex: 1));
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
        body: Container(
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部欢迎语 + 数据卡片行
                _WelcomeHeader(isDark: isDark),
                const SizedBox(height: 16),
                StatsCardsRow(isDark: isDark),
                const SizedBox(height: 24),

                // 上半区：服务器分类（左）+ 公告/更新日志（右）
                SizedBox(
                  height: 420, // 固定高度，左右等高
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 左侧：服务器分类
                      Expanded(
                        flex: 4,
                        child: ServerCategoriesPanel(
                          isDark: isDark,
                          onNavigateToServers: widget.onNavigateToServers,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 右侧：公告 + 更新日志
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            Expanded(
                              child: AnnouncementsPanel(isDark: isDark),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: UpdateLogsPanel(isDark: isDark),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OnlineTrendChart(isDark: isDark),
                const SizedBox(height: 24),

                // 下半区：直播 + 视频
                LiveRoomsSection(isDark: isDark),
                const SizedBox(height: 16),
                VideosSection(isDark: isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶部欢迎语组件
class _WelcomeHeader extends StatelessWidget {
  final bool isDark;

  const _WelcomeHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final username = authState.userInfo?.username;
        final greeting = _getGreeting();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              username != null ? '$greeting，$username 👋' : '$greeting 👋',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ).animate().fadeIn(duration: 400.ms).slideX(
              begin: -0.1,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            ),
            const SizedBox(height: 4),
            Text(
              _getSubtitle(),
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : const Color(0xFF64748B),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
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
    if (hour < 6) return '还在熬夜？注意休息哦';
    if (hour < 12) return '今天也是充满活力的一天！';
    if (hour < 14) return '午饭吃了吗？';
    if (hour < 18) return '下午好，来一局？';
    if (hour < 22) return '晚上好，服务器正在等你';
    return '这么晚还在玩？注意休息哦';
  }
}
