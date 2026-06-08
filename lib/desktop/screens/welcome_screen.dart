import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/core.dart';
import '../widgets/welcome/stats_cards_row.dart';
import '../widgets/welcome/announcements_panel.dart';
import '../widgets/welcome/update_logs_panel.dart';
import '../widgets/welcome/online_trend_chart.dart';
import '../widgets/welcome/live_rooms_section.dart';
import '../widgets/welcome/videos_section.dart';

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
  static const _statsTtl = Duration(minutes: 5);
  static const _announcementsTtl = Duration(minutes: 30);
  static const _updateLogsTtl = Duration(hours: 1);
  static const _bilibiliTtl = Duration(minutes: 10);

  bool _isStale(DateTime? lastFetched, Duration ttl) {
    if (lastFetched == null) return true;
    return DateTime.now().difference(lastFetched) > ttl;
  }

  /// 弱网模式下：只有数据为空才拉取，不再按 TTL 自动重拉
  bool _shouldFetch(DateTime? lastFetched, Duration ttl) {
    if (NetworkModeService.instance.weakNetwork) {
      return lastFetched == null;
    }
    return _isStale(lastFetched, ttl);
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

    // 统计数据：每 5 分钟刷新一次（弱网模式下仅首次拉取）
    if (!serverStatsBloc.state.isLoading &&
        _shouldFetch(serverStatsBloc.state.lastFetched, _statsTtl)) {
      serverStatsBloc.add(const ServerStatsFetch());
    }

    // 公告：每 30 分钟刷新一次（弱网模式下仅首次拉取）
    if (!announcementBloc.state.isLoading &&
        _shouldFetch(announcementBloc.state.lastFetched, _announcementsTtl)) {
      announcementBloc.add(AnnouncementFetch());
    }

    // 更新日志：每 1 小时刷新一次（弱网模式下仅首次拉取）
    if (!updateLogBloc.state.isLoading &&
        _shouldFetch(updateLogBloc.state.lastFetched, _updateLogsTtl)) {
      updateLogBloc.add(const UpdateLogFetch());
    }

    // B 站内容：每 10 分钟刷新一次（弱网模式下仅首次拉取）
    if (_shouldFetch(bilibiliBloc.state.liveRoomsLastFetched, _bilibiliTtl) &&
        bilibiliBloc.state.status != BilibiliContentStatus.loading) {
      bilibiliBloc.add(const BilibiliContentFetchRequested(tabIndex: 0));
    }
    if (_shouldFetch(bilibiliBloc.state.videosLastFetched, _bilibiliTtl) &&
        bilibiliBloc.state.status != BilibiliContentStatus.loading) {
      bilibiliBloc.add(const BilibiliContentFetchRequested(tabIndex: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
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
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部欢迎语 + 数据卡片行
              _WelcomeHeader(isDark: isDark),
              const SizedBox(height: 12),
              StatsCardsRow(isDark: isDark),
              const SizedBox(height: 12),

              // 上半区：在线趋势（左）+ 公告/更新日志（右）
              SizedBox(
                height: 420, // 固定高度，左右等高
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 左侧：在线趋势
                    Expanded(flex: 4, child: OnlineTrendChart(isDark: isDark)),
                    const SizedBox(width: 16),

                    // 右侧：公告 + 更新日志
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          Expanded(child: AnnouncementsPanel(isDark: isDark)),
                          const SizedBox(height: 6),
                          Expanded(child: UpdateLogsPanel(isDark: isDark)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 下半区：直播 + 视频
              LiveRoomsSection(isDark: isDark),
              const SizedBox(height: 12),
              VideosSection(isDark: isDark),
            ],
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

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 项目 Logo
            ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: 400.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(width: 16),
            // 欢迎语
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                        username != null
                            ? '$greeting，$username 👋'
                            : '$greeting 👋',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideX(
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
    if (hour < 6) return '还在熬夜？注意休息哦';
    if (hour < 12) return '今天也是充满活力的一天！';
    if (hour < 14) return '午饭吃了吗？';
    if (hour < 18) return '下午好，来一局？';
    if (hour < 22) return '晚上好，服务器正在等你';
    return '这么晚还在玩？注意休息哦';
  }
}
