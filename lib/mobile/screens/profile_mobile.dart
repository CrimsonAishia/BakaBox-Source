import 'package:bakabox_app/core/widgets/baka_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../core/core.dart';
import '../../core/api/daily_task_api.dart';
import '../router/mobile_router.dart';
import '../widgets/login_dialog_mobile.dart';
import '../widgets/shake_dialog_mobile.dart';
import '../../core/models/proto/lobby.pb.dart' as pb;

class ProfileMobile extends StatefulWidget {
  const ProfileMobile({super.key});

  @override
  State<ProfileMobile> createState() => _ProfileMobileState();
}

class _ProfileMobileState extends State<ProfileMobile>
    with WidgetsBindingObserver {
  bool _wasAuthenticated = false;
  bool _initialized = false;
  bool _hasVerifiedMissingShake = false;

  pb.SteamUserInfoResponse? _steamUserInfo;
  pb.InventoryStatsResponse? _inventoryStats;
  bool _isLoadingInfo = true;
  bool _isLoadingInventory = true;
  String? _infoError;
  String? _inventoryError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsBloc>().add(SettingsRefreshCacheSize());
      final authState = context.read<AuthBloc>().state;
      if (authState.isAuthenticated) {
        _verifyDailyTasks();
        _loadData();
        _wasAuthenticated = true;
      }
      _initialized = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _initialized) {
      final authState = context.read<AuthBloc>().state;
      if (authState.isAuthenticated) {
        // App 从后台恢复时重新验证状态，以处理跨天重置的情况
        _verifyDailyTasks();
      }
    }
  }

  Future<void> _connectAndLoadData() async {
    setState(() {
      _isLoadingInfo = true;
      _isLoadingInventory = true;
      _infoError = null;
      _inventoryError = null;
    });

    try {
      await LobbyNakamaService.instance.initialize();
    } catch (e) {
      LogService.w('[ProfileMobile] 手动连接大厅服务失败: $e');
    }

    await _loadData();
  }

  Future<void> _loadData() async {
    final nakamaUserId = LobbyNakamaService.instance.currentUserId;

    if (nakamaUserId == null || nakamaUserId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingInfo = false;
          _isLoadingInventory = false;
          _infoError = '获取游戏数据依赖大厅服务，点击下方按钮即可获取';
          _inventoryError = '获取游戏数据依赖大厅服务，点击下方按钮即可获取';
        });
      }
      return;
    }

    _loadSteamInfo(nakamaUserId);
    _loadInventory(nakamaUserId);
  }

  Future<void> _loadSteamInfo(String nakamaUserId) async {
    try {
      final result = await LobbyNakamaService.instance.rpcSteamUserInfo(
        nakamaUserId,
      );
      if (!mounted) return;
      if (result != null && result.code == 0) {
        setState(() {
          _steamUserInfo = result;
          _isLoadingInfo = false;
        });
      } else {
        setState(() {
          _isLoadingInfo = false;
          _infoError = result?.message.isNotEmpty == true
              ? result!.message
              : '暂未绑定 Steam 或获取数据失败';
        });
      }
    } catch (e) {
      LogService.w('[ProfileMobile] 加载用户信息失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingInfo = false;
          _infoError = '加载失败，请稍后重试';
        });
      }
    }
  }

  Future<void> _loadInventory(String nakamaUserId) async {
    try {
      final result = await LobbyNakamaService.instance.rpcInventoryStats(
        nakamaUserId,
      );
      if (!mounted) return;
      if (result != null && result.code == 0) {
        setState(() {
          _inventoryStats = result;
          _isLoadingInventory = false;
        });
      } else {
        setState(() {
          _isLoadingInventory = false;
          _inventoryError = result?.message.isNotEmpty == true
              ? result!.message
              : '暂未绑定 Steam 或获取数据失败';
        });
      }
    } catch (e) {
      LogService.w('[ProfileMobile] 加载库存信息失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingInventory = false;
          _inventoryError = '加载失败，请稍后重试';
        });
      }
    }
  }

  Future<void> _verifyDailyTasks() async {
    if (_hasVerifiedMissingShake) {
      if (mounted) {
        context.read<DailyTaskBloc>().add(
          const DailyTaskCheckStatusRequested(),
        );
      }
      return;
    }

    try {
      final now = DateTime.now();
      final records = await DailyTaskApi.getMonthRecords(now.year, now.month);

      bool hasTodayCheckIn = false;
      bool hasTodayShake = false;
      for (var r in records) {
        try {
          final date = DateTime.parse(r.createdAt).toLocal();
          if (date.year == now.year &&
              date.month == now.month &&
              date.day == now.day) {
            if (r.taskType == 'check_in') hasTodayCheckIn = true;
            if (r.taskType == 'shake') hasTodayShake = true;
            if (hasTodayCheckIn && hasTodayShake) break;
          }
        } catch (_) {}
      }

      if (mounted) {
        if (!hasTodayCheckIn || !hasTodayShake) {
          _hasVerifiedMissingShake = true;
          context.read<DailyTaskBloc>().add(
            const DailyTaskCheckStatusRequested(force: true),
          );
        } else {
          context.read<DailyTaskBloc>().add(
            const DailyTaskCheckStatusRequested(),
          );
        }
      }
    } catch (e) {
      LogService.e('[ProfileMobile] 获取每日任务记录失败', e);
      if (mounted) {
        context.read<DailyTaskBloc>().add(
          const DailyTaskCheckStatusRequested(),
        );
      }
    }
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
                _verifyDailyTasks();
                _loadData();
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
            return RefreshIndicator(
              onRefresh: () async {
                if (authState.isAuthenticated) {
                  _verifyDailyTasks();
                  await _loadData();
                }
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 顶部渐变背景 + 用户信息
                  _buildProfileHeader(context, authState),
                  // 内容区域
                  SliverToBoxAdapter(child: _buildContent(context, authState)),
                ],
              ),
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
                ? [const Color(0xFF1E3A5F), AppColors.slate900]
                : [AppColors.primary, const Color(0xFF00B4FF)],
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
                final totalUnread =
                    notificationState.unreadCount +
                    announcementState.unreadCount;
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.red500,
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
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 2,
            ),
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
                ? bakaCachedImageProvider(userInfo.avatar)
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
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: const Icon(
              Icons.person_outline,
              size: 40,
              color: Colors.white,
            ),
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
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text(
            '关联论坛账户',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
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

            // CP模块
            if (_steamUserInfo != null && _steamUserInfo!.hasCp()) ...[
              _buildSectionTitle(context, '我的 CP'),
              const SizedBox(height: 12),
              _buildCpCard(context, _steamUserInfo!.cp),
              const SizedBox(height: 20),
            ],

            // Steam Info
            _buildSteamInfoSection(context),
            const SizedBox(height: 20),
            // Inventory
            _buildInventorySection(context),
          ],

          // 退出登录按钮（仅登录用户显示）
          if (authState.isAuthenticated) ...[
            const SizedBox(height: 24),
            _buildLogoutButton(context),
          ] else ...[
            // 未登录时显示功能特权介绍，避免下方空白
            _buildGuestBenefits(context),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 未登录状态下的特权展示卡片
  Widget _buildGuestBenefits(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            '登录后解锁更多专属功能',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildBenefitCard(
          context,
          icon: Icons.bar_chart_rounded,
          title: '全方位数据追踪',
          subtitle: '查看您的金、点、时长等游戏数据，以及资产统计',
          color: AppColors.blue500,
          delay: 100,
        ),
        const SizedBox(height: 12),
        _buildBenefitCard(
          context,
          icon: MdiIcons.calendarCheck,
          title: '每日任务与摇摇乐',
          subtitle: '完成每日签到领取奖励，参与摇摇乐试试手气',
          color: AppColors.primary,
          delay: 150,
        ),
        const SizedBox(height: 12),
        _buildBenefitCard(
          context,
          icon: Icons.chat_bubble_outline_rounded,
          title: '大厅互动',
          subtitle: '与其他玩家交流',
          color: AppColors.violet500,
          delay: 200,
        ),
      ],
    );
  }

  Widget _buildBenefitCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required int delay,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms, delay: delay.ms).slideY(begin: 0.1),
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
          // 论坛积分
          Expanded(
            child: _buildStatItem(
              context,
              icon: Icons.star,
              iconColor: const Color(0xFFFFD700),
              value: userInfo.credits ?? '0',
              label: '论坛积分',
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
              iconColor: const Color(0xFF4ADE80),
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
                    color: AppColors.primary,
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
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isCompleted
                  ? AppColors.emerald500
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.emerald500.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reward,
                  style: const TextStyle(
                    color: AppColors.emerald500,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  actionText ?? (isCompleted ? '已完成' : '去完成'),
                  style: TextStyle(
                    color: isCompleted
                        ? AppColors.emerald500
                        : AppColors.primary,
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

  String _formatNumber(int number) {
    if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(1)}万';
    }
    return number.toString();
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return '0小时';
    final hours = seconds / 3600;
    if (hours < 1) return '< 1小时';
    return '${hours.toStringAsFixed(1)}小时';
  }

  Widget _buildSteamInfoSection(BuildContext context) {
    if (_isLoadingInfo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionTitle(context, 'CS2 综合数据'),
          const SizedBox(height: 12),
          _buildLoadingCard(context),
        ],
      );
    }
    if (_infoError != null || _steamUserInfo == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionTitle(context, 'CS2 综合数据'),
          const SizedBox(height: 12),
          _buildErrorCard(context, _infoError ?? '暂无数据'),
        ],
      );
    }
    final info = _steamUserInfo!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(context, 'CS2 综合数据'),
        const SizedBox(height: 12),
        _buildInfoCard(context, [
          _InfoItem('金', _formatNumber(info.cs2Gold.toInt())),
          _InfoItem('点', _formatNumber(info.cs2Point.toInt())),
          _InfoItem('已消耗点', _formatNumber(info.cs2SpentPoint.toInt())),
          _InfoItem('活动积分', _formatNumber(info.cs2EventPoint.toInt())),
          _InfoItem('今日在线', _formatDuration(info.onlineTimeDay.toInt())),
          _InfoItem('本月在线', _formatDuration(info.onlineTimeMonth.toInt())),
          _InfoItem('上月在线', _formatDuration(info.onlineTimeLastMonth.toInt())),
          _InfoItem('累计在线', _formatDuration(info.onlineTimeTotal.toInt())),
        ]),
        const SizedBox(height: 16),

        if (info.csgoGold.toInt() > 0 || info.csgoOnlineTime.toInt() > 0) ...[
          _buildSectionTitle(context, 'CS:GO 综合数据'),
          const SizedBox(height: 12),
          _buildInfoCard(context, [
            _InfoItem('金币', _formatNumber(info.csgoGold.toInt())),
            _InfoItem('累计在线', _formatDuration(info.csgoOnlineTime.toInt())),
          ]),
        ],
      ],
    );
  }

  Widget _buildInventorySection(BuildContext context) {
    if (_isLoadingInventory) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionTitle(context, 'CS2 库存统计'),
          const SizedBox(height: 12),
          _buildLoadingCard(context),
        ],
      );
    }
    if (_inventoryError != null || _inventoryStats == null) {
      return const SizedBox.shrink();
    }
    final stats = _inventoryStats!;
    final items = [
      _InventoryItem(
        '皮肤',
        stats.skinCount,
        MdiIcons.tshirtCrew,
        AppColors.violet500,
      ),
      _InventoryItem(
        '符卡',
        stats.spellCount,
        MdiIcons.cards,
        AppColors.amber500,
      ),
      _InventoryItem(
        '弹幕',
        stats.danmakuCount,
        MdiIcons.shuriken,
        const Color(0xFFF97316),
      ),
      _InventoryItem(
        '技能',
        stats.skillCount,
        MdiIcons.lightningBolt,
        const Color(0xFFEAB308),
      ),
      _InventoryItem(
        '刀模',
        stats.knifeCount,
        MdiIcons.knifeMilitary,
        AppColors.slate400,
      ),
      _InventoryItem(
        '枪模',
        stats.weaponCount,
        MdiIcons.pistol,
        const Color(0xFF60A5FA),
      ),
      _InventoryItem(
        'Cheer',
        stats.cheerCount,
        Icons.campaign_outlined,
        const Color(0xFFF472B6),
      ),
      _InventoryItem(
        '菜单皮肤',
        stats.skinmenuCount,
        Icons.view_sidebar_outlined,
        const Color(0xFF2DD4BF),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'CS2 库存统计'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  return Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : AppColors.slate50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : AppColors.slate100,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon, color: item.color, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          '${item.count}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // 估算总价值
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.02)
                      : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '估算总价值',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.monetization_on,
                      color: AppColors.amber500,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '金 ',
                      style: TextStyle(
                        color: AppColors.amber500.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _formatNumber(stats.totalGoldValue.toInt()),
                      style: const TextStyle(
                        color: AppColors.amber500,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Icon(Icons.bolt, color: Color(0xFF60A5FA), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '点 ',
                      style: TextStyle(
                        color: const Color(0xFF60A5FA).withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _formatNumber(stats.totalPointValue.toInt()),
                      style: const TextStyle(
                        color: Color(0xFF60A5FA),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 140,
      alignment: Alignment.center,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '正在获取数据...',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<_InfoItem> items) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
      child: GridView.count(
        padding: EdgeInsets.zero,
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.2,
        children: items.map((item) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : AppColors.slate50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.slate100,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily:
                        'Roboto', // Use a slightly more rigid font for numbers if preferred
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }).toList(),
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
            Icon(MdiIcons.restart, color: AppColors.red500),
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
              backgroundColor: AppColors.red500,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定并退出'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            MdiIcons.serverNetworkOff,
            size: 48,
            color: isDark ? AppColors.slate500 : AppColors.slate400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _connectAndLoadData,
            icon: const Icon(Icons.link, size: 18),
            label: const Text('连接大厅并获取'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.slate700 : AppColors.slate100,
              foregroundColor: isDark ? Colors.white : AppColors.slate700,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCpCard(BuildContext context, pb.CPData cp) {
    final theme = Theme.of(context);

    final taUser = cp.owner;
    final partnerUser = cp.partner;

    int days = 0;
    if (cp.bindDate.isNotEmpty) {
      try {
        final bindDateTime = DateTime.parse(cp.bindDate);
        days = DateTime.now().difference(bindDateTime).inDays;
      } catch (e) {
        // ignore
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 上半部分：头像和红心
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCpAvatar(context, taUser, isTa: true),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite,
                    color: Colors.pinkAccent,
                    size: 30,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$days 天',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              _buildCpAvatar(context, partnerUser, isTa: false),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: theme.dividerColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          // 下半部分：数据卡片
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildCpDataBox(context, 'Lv.${cp.level}', 'CP 等级'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCpDataBox(
                  context,
                  '${_formatNumber(cp.point)} pt',
                  '亲密度',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCpAvatar(
    BuildContext context,
    pb.CPUserData user, {
    required bool isTa,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.pinkAccent.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.pinkAccent.withValues(alpha: 0.2),
                blurRadius: 8,
              ),
            ],
          ),
          child: ClipOval(
            child: BakaCachedImage(
              user.avatarUrl.isNotEmpty ? user.avatarUrl : '',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.person,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 96,
          child: Text(
            user.playerName,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 22,
          child: isTa
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '我',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    user.steamId.isNotEmpty ? user.steamId : 'Unbound',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCpDataBox(BuildContext context, String value, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.pink.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.pink.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  _InfoItem(this.label, this.value);
}

class _InventoryItem {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  _InventoryItem(this.label, this.count, this.icon, this.color);
}
