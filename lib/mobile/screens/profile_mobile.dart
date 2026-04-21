import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../core/core.dart';
import '../router/mobile_router.dart';
import '../widgets/login_dialog_mobile.dart';
import '../widgets/shake_dialog_mobile.dart';

class ProfileMobile extends StatefulWidget {
  const ProfileMobile({super.key});

  @override
  State<ProfileMobile> createState() => _ProfileMobileState();
}

class _ProfileMobileState extends State<ProfileMobile> {
  bool _wasAuthenticated = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsBloc>().add(SettingsRefreshCacheSize());
      final authState = context.read<AuthBloc>().state;
      if (authState.isAuthenticated) {
        context.read<DailyTaskBloc>().add(
          const DailyTaskCheckStatusRequested(),
        );
        _wasAuthenticated = true;
      }
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<SettingsBloc, SettingsState>(
            listener: (context, state) {
              if (state.needsRestart) {
                _showRestartDialog(context);
              }
            },
          ),
          BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (!_initialized) return;
              if (state.isAuthenticated && !_wasAuthenticated) {
                context.read<DailyTaskBloc>().add(
                  const DailyTaskCheckStatusRequested(),
                );
              }
              if (!state.isAuthenticated && _wasAuthenticated) {
                context.read<DailyTaskBloc>().add(const DailyTaskReset());
                // 退出登录时清除消息数据
                context.read<NotificationBloc>().add(const NotificationClear());
              }
              _wasAuthenticated = state.isAuthenticated;
            },
          ),
        ],
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            return CustomScrollView(
              slivers: [
                // 顶部渐变背景 + 用户信息
                _buildProfileHeader(context, authState),
                // 内容区域
                SliverToBoxAdapter(
                  child: _buildContent(context, authState),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 构建顶部渐变背景和用户信息区域
  Widget _buildProfileHeader(BuildContext context, AuthState authState) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1E3A5F), const Color(0xFF0F172A)]
                : [const Color(0xFF0080FF), const Color(0xFF00B4FF)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 顶部操作栏（保持右侧 padding）
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                child: _buildTopActions(context),
              ),
              const SizedBox(height: 8),
              // 头像和用户信息（水平居中）
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: authState.isAuthenticated && authState.userInfo != null
                    ? _buildLoggedInHeader(context, authState.userInfo!)
                    : _buildGuestHeader(context),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  /// 顶部操作栏（铃铛和设置）
  Widget _buildTopActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 消息通知铃铛
        BlocBuilder<NotificationBloc, NotificationState>(
          builder: (context, notificationState) {
            return BlocBuilder<AnnouncementBloc, AnnouncementState>(
              builder: (context, announcementState) {
                final totalUnread = notificationState.unreadCount + announcementState.unreadCount;
                return Stack(
                  children: [
                    IconButton(
                      onPressed: () => context.push(MobileRoutes.notifications),
                      icon: Icon(MdiIcons.bellOutline),
                      color: Colors.white,
                      iconSize: 24,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                    if (totalUnread > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          child: Text(
                            totalUnread > 99 ? '99+' : '$totalUnread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(width: 4),
        // 设置图标
        IconButton(
          onPressed: () => context.push(MobileRoutes.settings),
          icon: Icon(MdiIcons.cogOutline),
          color: Colors.white,
          iconSize: 24,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  /// 已登录用户头部
  Widget _buildLoggedInHeader(BuildContext context, UserInfo userInfo) {
    return Column(
      children: [
        // 头像（带边框装饰）
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage: userInfo.avatar.isNotEmpty
                ? NetworkImage(userInfo.avatar)
                : null,
            child: userInfo.avatar.isEmpty
                ? const Icon(Icons.person, size: 40, color: Colors.white)
                : null,
          ),
        ).animate().scale(
          begin: const Offset(0.8, 0.8),
          duration: 400.ms,
          curve: Curves.easeOutBack,
        ),
        const SizedBox(height: 12),
        // 用户名
        Text(
          userInfo.username,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 4),
        // 用户组标签
        if (userInfo.userGroup != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              userInfo.userGroup!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ).animate().fadeIn(delay: 150.ms),
      ],
    );
  }

  /// 未登录用户头部
  Widget _buildGuestHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
          ),
          child: CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: const Icon(Icons.person_outline, size: 40, color: Colors.white),
          ),
        ).animate().scale(
          begin: const Offset(0.8, 0.8),
          duration: 400.ms,
          curve: Curves.easeOutBack,
        ),
        const SizedBox(height: 12),
        const Text(
          '未登录',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => LoginDialogMobile.show(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0080FF),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text('关联论坛账户', style: TextStyle(fontWeight: FontWeight.w600)),
        ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2),
      ],
    );
  }

  /// 构建内容区域
  Widget _buildContent(BuildContext context, AuthState authState) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 数据统计栏（仅登录用户显示）
          if (authState.isAuthenticated && authState.userInfo != null) ...[
            _buildStatsBar(context, authState.userInfo!),
            const SizedBox(height: 20),
            // 每日任务卡片
            _buildDailyTaskCard(context),
            const SizedBox(height: 20),
          ],

          // 功能列表
          _buildSectionTitle(context, '功能'),
          const SizedBox(height: 12),
          _buildFunctionList(context),

          // 退出登录按钮（仅登录用户显示）
          if (authState.isAuthenticated) ...[
            const SizedBox(height: 24),
            _buildLogoutButton(context),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 数据统计栏
  Widget _buildStatsBar(BuildContext context, UserInfo userInfo) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 积分
          Expanded(
            child: _buildStatItem(
              context,
              icon: Icons.star,
              iconColor: const Color(0xFFF59E0B),
              value: userInfo.credits ?? '0',
              label: '积分',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.dividerColor.withValues(alpha: 0.3),
          ),
          // 僵尸币
          Expanded(
            child: _buildStatItem(
              context,
              icon: Icons.monetization_on,
              iconColor: const Color(0xFF10B981),
              value: userInfo.zombieCoins ?? '0',
              label: '僵尸币',
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  /// 每日任务卡片
  Widget _buildDailyTaskCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BlocBuilder<DailyTaskBloc, DailyTaskState>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    MdiIcons.calendarCheck,
                    color: const Color(0xFF0080FF),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '每日任务',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 签到任务
              _buildTaskItem(
                context,
                icon: Icons.check_circle_outline,
                title: '每日签到',
                isCompleted: state.hasCheckedIn,
                reward: state.checkInRewardAmount != null
                    ? '+${state.checkInRewardAmount}'
                    : null,
                isLoading: state.isCheckingIn || state.isCheckingStatus,
                onTap: state.hasCheckedIn || state.isCheckingIn
                    ? null
                    : () => context.read<DailyTaskBloc>().add(
                          const DailyTaskCheckInRequested(),
                        ),
              ),
              const SizedBox(height: 12),
              // 摇摇乐任务
              _buildTaskItem(
                context,
                icon: MdiIcons.dice5,
                title: '摇摇乐',
                isCompleted: state.hasShaked,
                reward: state.shakeRewardAmount != null
                    ? '+${state.shakeRewardAmount}'
                    : null,
                isLoading: state.isCheckingStatus,
                onTap: () => ShakeDialogMobile.show(context),
                actionText: state.hasShaked ? '查看' : '去摇奖',
              ),
            ],
          );
        },
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1);
  }

  Widget _buildTaskItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isCompleted,
    String? reward,
    bool isLoading = false,
    VoidCallback? onTap,
    String? actionText,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isCompleted
                  ? const Color(0xFF10B981)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (isCompleted && reward != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reward,
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0080FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  actionText ?? (isCompleted ? '已完成' : '去完成'),
                  style: TextStyle(
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : const Color(0xFF0080FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  /// 功能列表
  Widget _buildFunctionList(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildListItem(
            context,
            icon: MdiIcons.cardsOutline,
            iconColor: const Color(0xFFEC4899),
            title: '人物图鉴',
            subtitle: '浏览游戏角色信息',
            onTap: () => context.push(MobileRoutes.characterGallery),
          ),
          Divider(
            height: 1,
            indent: 62,
            endIndent: 16,
            color: theme.dividerColor.withValues(alpha: 0.3),
          ),
          _buildListItem(
            context,
            icon: MdiIcons.messageTextOutline,
            iconColor: const Color(0xFF8B5CF6),
            title: '问题反馈',
            subtitle: '查看和提交反馈',
            onTap: () => context.push(MobileRoutes.issues),
          ),
          Divider(
            height: 1,
            indent: 62,
            endIndent: 16,
            color: theme.dividerColor.withValues(alpha: 0.3),
          ),
          _buildListItem(
            context,
            icon: MdiIcons.fileDocumentOutline,
            iconColor: const Color(0xFFEF4444),
            title: '更新日志',
            subtitle: '查看ZE/ZM更新历史',
            onTap: () => context.push(MobileRoutes.updateLogs),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideY(begin: 0.1);
  }

  Widget _buildListItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  MdiIcons.chevronRight,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
          ],
        ),
      ),
    );
  }

  /// 退出登录按钮
  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () => _showUnbindConfirm(context),
        icon: const Icon(Icons.link_off, size: 18),
        label: const Text('退出登录', style: TextStyle(fontSize: 15)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 250.ms);
  }

  void _showUnbindConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要解除论坛账户关联吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
            child: const Text('确认退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRestartDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(MdiIcons.restart, color: const Color(0xFFEF4444)),
            const SizedBox(width: 8),
            const Text('需要重启应用'),
          ],
        ),
        content: const Text('应用数据已清除，需要重启应用才能生效。点击确定后应用将自动关闭，请手动重新启动。'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              SystemNavigator.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('确定并退出'),
          ),
        ],
      ),
    );
  }
}
