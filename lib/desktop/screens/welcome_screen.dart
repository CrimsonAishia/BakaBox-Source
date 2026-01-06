import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../core/core.dart';

/// 欢迎界面回调类型
typedef OnNavigateToServers = void Function();

/// 首页欢迎界面
/// Hero 展示型设计，渐变背景 + 浮动图标 + 核心数据统计
class WelcomeScreen extends StatefulWidget {
  final OnNavigateToServers? onNavigateToServers;

  const WelcomeScreen({
    super.key,
    this.onNavigateToServers,
  });

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
    final announcementBloc = context.read<AnnouncementBloc>();
    final updateLogBloc = context.read<UpdateLogBloc>();

    if (serverBloc.state.serverCategories.isEmpty && !serverBloc.state.isLoading) {
      serverBloc.add(ServerFetchList());
    }
    if (serverBloc.state.serverCategories.isNotEmpty) {
      serverBloc.add(ServerUpdateCategoryOnlineCounts());
    }
    if (!announcementBloc.state.isLoading) {
      announcementBloc.add(AnnouncementRefresh(silent: true));
    }
    if (!updateLogBloc.state.isLoading) {
      updateLogBloc.add(const UpdateLogFetch());
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
            const SizedBox(height: 24),
            _buildTitle(theme, isDark),
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
      child: Image.asset('assets/images/logo.png', width: 120, height: 120, fit: BoxFit.contain),
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0), duration: 600.ms, curve: Curves.easeOutBack);
  }


  /// 构建标题
  Widget _buildTitle(ThemeData theme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'ZombieDen',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 36,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3), offset: const Offset(0, 2), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFF97316)]),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: const Color(0xFFDC2626).withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: const Text('CS2', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white)),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 200.ms)
        .slideY(begin: 0.3, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  /// 构建操作按钮
  Widget _buildActionButtons(BuildContext context, ThemeData theme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPrimaryButton(icon: MdiIcons.serverNetwork, label: '立即浏览服务器', onPressed: () => widget.onNavigateToServers?.call()),
        const SizedBox(width: 16),
        _buildSecondaryButton(icon: MdiIcons.forum, label: '社区论坛', onPressed: _openForum, isDark: isDark),
        const SizedBox(width: 16),
        _buildWebsiteButton(icon: MdiIcons.web, label: '官方网站', onPressed: _openWebsite),
      ],
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 600.ms)
        .slideY(begin: 0.3, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);
  }


  /// 构建主按钮
  Widget _buildPrimaryButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return _HoverScaleButton(
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  /// 构建次按钮
  Widget _buildSecondaryButton({required IconData icon, required String label, required VoidCallback onPressed, required bool isDark}) {
    return _HoverScaleButton(
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  /// 构建官网按钮
  Widget _buildWebsiteButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return _HoverScaleButton(
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }


  /// 构建统计数据区域
  Widget _buildStatsSection(BuildContext context, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 0, 48, 48),
      child: Column(
        children: [
          Container(
            width: 60, height: 3,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)]),
              borderRadius: BorderRadius.circular(2),
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 800.ms).scaleX(begin: 0, end: 1, duration: 500.ms, curve: Curves.easeOutCubic),
          const SizedBox(height: 32),
          Expanded(
            child: BlocBuilder<ServerBloc, ServerState>(
              builder: (context, serverState) {
                return BlocBuilder<AnnouncementBloc, AnnouncementState>(
                  builder: (context, announcementState) {
                    return BlocBuilder<UpdateLogBloc, UpdateLogState>(
                      builder: (context, updateLogState) {
                        return _buildStatsCards(context, theme, isDark, serverState, announcementState, updateLogState);
                      },
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
  Widget _buildStatsCards(BuildContext context, ThemeData theme, bool isDark, ServerState serverState, AnnouncementState announcementState, UpdateLogState updateLogState) {
    final officialCategories = serverState.serverCategories.where((cat) => !cat.isCustom);
    final totalServers = officialCategories.fold<int>(0, (sum, cat) => sum + cat.serverList.length);
    final totalOnlinePlayers = officialCategories.fold<int>(0, (sum, cat) => sum + (serverState.categoryOnlineCounts[cat.modelName ?? ''] ?? 0));
    final announcementCount = announcementState.announcements.length;
    final updateLogCount = updateLogState.totalCount;

    return Row(
      children: [
        Expanded(child: _StatCard(icon: MdiIcons.server, iconColor: const Color(0xFF3B82F6), value: totalServers.toString(), subtitle: '台服务器', isDark: isDark, delay: 900)),
        const SizedBox(width: 16),
        Expanded(child: _StatCard(icon: MdiIcons.accountGroup, iconColor: const Color(0xFF10B981), value: totalOnlinePlayers.toString(), subtitle: '人正在游戏', isDark: isDark, delay: 1000)),
        const SizedBox(width: 16),
        Expanded(child: _StatCard(icon: MdiIcons.bullhorn, iconColor: const Color(0xFFF59E0B), value: announcementCount.toString(), subtitle: '条公告', isDark: isDark, delay: 1100)),
        const SizedBox(width: 16),
        Expanded(child: _StatCard(icon: MdiIcons.fileDocument, iconColor: const Color(0xFF8B5CF6), value: updateLogCount.toString(), subtitle: '条记录', isDark: isDark, delay: 1200)),
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
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B), const Color(0xFF1A1A2E)]
              : [const Color(0xFFE3F2FD), const Color(0xFFE0F7FA), const Color(0xFFEDE7F6), const Color(0xFFFFF3E0)],
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
        _FloatingIcon(emoji: '🌊', size: 40, top: 0.25, right: 0.15, delay: 1000),
        _FloatingIcon(emoji: '✨', size: 36, bottom: 0.35, left: 0.08, delay: 2000),
        _FloatingIcon(emoji: '🌟', size: 32, top: 0.45, right: 0.10, delay: 3000),
        _FloatingIcon(emoji: '💎', size: 28, top: 0.60, left: 0.15, delay: 1500),
        _FloatingIcon(emoji: '🎮', size: 36, bottom: 0.25, right: 0.12, delay: 2500),
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

class _FloatingIconState extends State<_FloatingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 6));
    _floatAnimation = Tween<double>(begin: 0, end: 20).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _rotateAnimation = Tween<double>(begin: 0, end: 0.1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
              child: Opacity(opacity: 0.7, child: Text(widget.emoji, style: TextStyle(fontSize: widget.size))),
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
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 28, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 13, color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8))),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: delay.ms).slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.identity()..translate(0.0, _isHovered ? -2.0 : 0.0),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
