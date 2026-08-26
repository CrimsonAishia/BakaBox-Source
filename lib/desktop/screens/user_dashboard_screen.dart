import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bakabox_app/core/widgets/baka_cached_image.dart';

import '../../core/bloc/auth/auth_bloc.dart';
import '../../core/bloc/auth/auth_event.dart';
import '../../core/bloc/auth/auth_state.dart';
import '../../core/bloc/daily_task/daily_task_bloc.dart';
import '../../core/bloc/daily_task/daily_task_event.dart';
import '../../core/bloc/daily_task/daily_task_state.dart';
import '../../core/bloc/lobby/lobby_bloc.dart';
import '../../core/models/user_info.dart';
import '../../core/models/proto/lobby.pb.dart' as pb;
import '../../core/services/lobby_nakama_service.dart';
import '../../core/utils/log_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/marquee_text.dart';
import '../widgets/page_layout.dart';
import '../widgets/common_scroll_indicator.dart';
import '../widgets/shake_tooltip.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import '../../core/api/daily_task_api.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  pb.SteamUserInfoResponse? _steamUserInfo;
  pb.InventoryStatsResponse? _inventoryStats;

  bool _isLoadingInfo = true;
  bool _isLoadingInventory = true;
  bool _isLoadingCalendar = true;

  String? _infoError;
  String? _inventoryError;

  List<DailyTaskRecordDto> _monthRecords = [];
  final JustTheController _shakeTooltipController = JustTheController();
  final ScrollController _scrollController = ScrollController();
  bool _hasVerifiedMissingShake = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _shakeTooltipController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final lobbyState = context.read<LobbyBloc>().state;
      final selfUser = lobbyState.selfUser;
      final nakamaUserId = selfUser?.serverUserId;

      _fetchMonthRecords();

      if (nakamaUserId == null || nakamaUserId.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoadingInfo = false;
            _isLoadingInventory = false;
            _infoError = '无法获取用户联机ID，可能尚未连接大厅';
            _inventoryError = '无法获取用户联机ID';
          });
        }
        return;
      }

      _loadSteamInfo(nakamaUserId);
      _loadInventory(nakamaUserId);
    });
  }

  Future<void> _fetchMonthRecords() async {
    try {
      final now = DateTime.now();
      final records = await DailyTaskApi.getMonthRecords(now.year, now.month);

      // 智能检查：如果今日后端无摇摇乐记录，且当前尚未强制校验过，则发起一次强制状态同步
      if (!_hasVerifiedMissingShake) {
        bool hasTodayShake = false;
        for (var r in records) {
          if (r.taskType == 'shake') {
            try {
              final date = DateTime.parse(r.createdAt).toLocal();
              if (date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day) {
                hasTodayShake = true;
                break;
              }
            } catch (_) {}
          }
        }

        if (!hasTodayShake) {
          _hasVerifiedMissingShake = true;
          // 发现没记录，触发一次强制获取结果（会检查网页状态，若已摇则自动补录后端）
          if (mounted) {
            context.read<DailyTaskBloc>().add(
              const DailyTaskCheckStatusRequested(force: true),
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _monthRecords = records;
          _isLoadingCalendar = false;
        });
      }
    } catch (e) {
      LogService.e('获取月度记录失败', e);
      if (mounted) {
        setState(() => _isLoadingCalendar = false);
      }
    }
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
      LogService.w('[UserDashboardScreen] 加载用户信息失败: $e');
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
      LogService.w('[UserDashboardScreen] 加载库存信息失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingInventory = false;
          _inventoryError = '加载失败，请稍后重试';
        });
      }
    }
  }

  BoxDecoration _getStandardCardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? AppColors.slate800 : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Color _getPrimaryTextColor(bool isDark) =>
      isDark ? Colors.white : AppColors.gray800;
  Color _getSecondaryTextColor(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.gray500;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (!authState.isAuthenticated || authState.userInfo == null) {
          return Center(
            child: Text(
              '请先登录',
              style: TextStyle(color: _getSecondaryTextColor(isDark)),
            ),
          );
        }
        final userInfo = authState.userInfo!;

        return PageLayout(
          title: '个人中心',
          background: _buildPageBackground(isDark),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Stack(
                children: [
                  ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      _buildCombinedHeaderAndCalendar(userInfo, isDark),
                      const SizedBox(height: 32),

                      // 双列数据布局
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(
                                  '综合数据总览',
                                  Icons.bar_chart_rounded,
                                  AppColors.primary,
                                  isDark,
                                ),
                                const SizedBox(height: 16),
                                _buildSteamInfoSection(isDark),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(
                                  'CS2 库存统计',
                                  Icons.inventory_2_outlined,
                                  const Color(0xFF4ADE80),
                                  isDark,
                                ),
                                const SizedBox(height: 16),
                                _buildInventorySection(isDark),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 48),
                      _buildFooter(isDark),
                      const SizedBox(height: 24),
                    ],
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _scrollController,
                        builder: (context, _) {
                          bool showTopIndicator = false;
                          bool showBottomIndicator = false;
                          if (_scrollController.hasClients &&
                              _scrollController.position.hasContentDimensions) {
                            showTopIndicator =
                                _scrollController.position.pixels > 0;
                            showBottomIndicator =
                                _scrollController.position.pixels <
                                _scrollController.position.maxScrollExtent;
                          }

                          return Stack(
                            children: [
                              if (showTopIndicator)
                                const Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: CommonScrollIndicator(isTop: true),
                                ),
                              if (showBottomIndicator)
                                const Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: CommonScrollIndicator(isTop: false),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageBackground(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.slate50,
      ),
      child: Stack(
        children: [
          // 右上角蓝色装饰
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                    AppColors.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          // 左下角绿色装饰
          Positioned(
            bottom: -100,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(
                      0xFF4ADE80,
                    ).withValues(alpha: isDark ? 0.12 : 0.06),
                    const Color(0xFF4ADE80).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: _getPrimaryTextColor(isDark),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCombinedHeaderAndCalendar(UserInfo userInfo, bool isDark) {
    return Container(
      decoration: _getStandardCardDecoration(isDark),
      child: Column(
        children: [
          _buildHeaderContent(userInfo, isDark),
          _buildDashedDivider(isDark),
          _buildCalendarContent(isDark),
        ],
      ),
    );
  }

  Widget _buildDashedDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boxWidth = constraints.constrainWidth();
          const dashWidth = 6.0;
          final dashCount = (boxWidth / (2 * dashWidth)).floor();
          return Flex(
            direction: Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildHeaderContent(UserInfo userInfo, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // 头像
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: userInfo.avatar.isNotEmpty
                  ? BakaCachedImage(
                      userInfo.avatar,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    )
                  : Icon(
                      Icons.person,
                      color: _getSecondaryTextColor(isDark),
                      size: 36,
                    ),
            ),
          ),
          const SizedBox(width: 20),
          // 用户信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userInfo.username,
                  style: TextStyle(
                    color: _getPrimaryTextColor(isDark),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (userInfo.userGroup != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          userInfo.userGroup!,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (userInfo.steamId != null) ...[
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: userInfo.steamUrl != null
                            ? () => launchUrl(Uri.parse(userInfo.steamUrl!))
                            : null,
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/icons/steam.png',
                              width: 14,
                              height: 14,
                              color: _getSecondaryTextColor(isDark),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              userInfo.steamId!,
                              style: TextStyle(
                                color: _getSecondaryTextColor(isDark),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // 资产数据
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAssetItem(
                  Icons.star,
                  '论坛积分',
                  userInfo.credits ?? '0',
                  const Color(0xFFFFD700),
                  isDark,
                ),
                Container(
                  width: 1,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1),
                ),
                _buildAssetItem(
                  Icons.monetization_on,
                  '僵尸币',
                  userInfo.zombieCoins ?? '0',
                  const Color(0xFF4ADE80),
                  isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetItem(
    IconData icon,
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color.withValues(alpha: 0.8)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: _getSecondaryTextColor(isDark),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarContent(bool isDark) {
    return BlocConsumer<DailyTaskBloc, DailyTaskState>(
      listener: (context, state) {
        if (state.hasCheckedIn || state.hasShaked) {
          _fetchMonthRecords();
        }
      },
      builder: (context, state) {
        final now = DateTime.now();
        final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
        final firstDayOfMonth = DateTime(now.year, now.month, 1);
        final firstWeekday = firstDayOfMonth.weekday;

        final Map<int, List<DailyTaskRecordDto>> recordsByDay = {};
        for (var record in _monthRecords) {
          try {
            final date = DateTime.parse(record.createdAt);
            final day = date.day;
            recordsByDay.putIfAbsent(day, () => []).add(record);
          } catch (e) {
            // ignore
          }
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_month,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${now.year}年${now.month}月 签到与任务',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getPrimaryTextColor(isDark),
                    ),
                  ),
                  const Spacer(),
                  if (_isLoadingCalendar)
                    const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),

                  _buildCompactActionButton(
                    icon: Icons.edit_calendar,
                    label: state.hasCheckedIn ? '今日已签到' : '立即签到',
                    color: const Color(0xFF60A5FA),
                    isCompleted: state.hasCheckedIn,
                    isLoading: state.isCheckingIn,
                    onTap:
                        state.hasCheckedIn ||
                            state.isCheckingIn ||
                            state.isCheckingStatus
                        ? null
                        : () => context.read<DailyTaskBloc>().add(
                            const DailyTaskCheckInRequested(),
                          ),
                  ),
                  const SizedBox(width: 8),

                  JustTheTooltip(
                    controller: _shakeTooltipController,
                    preferredDirection: AxisDirection.down,
                    backgroundColor: isDark
                        ? const Color(0xFF1E1E1E)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 8,
                    tailLength: 10,
                    tailBaseWidth: 16,
                    margin: const EdgeInsets.all(16),
                    triggerMode: TooltipTriggerMode.manual,
                    content: ShakeTooltipContent(
                      onClose: () => _shakeTooltipController.hideTooltip(),
                    ),
                    child: _buildCompactActionButton(
                      icon: Icons.casino_outlined,
                      label: state.hasShaked ? '摇摇乐已完成' : '去摇一摇',
                      color: const Color(0xFFF472B6),
                      isCompleted: state.hasShaked,
                      isLoading: false,
                      onTap: () {
                        if (!state.isCheckingStatus) {
                          _shakeTooltipController.showTooltip();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 星期表头
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              color: _getSecondaryTextColor(isDark),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              // 日历网格
              Column(
                children: List.generate(
                  ((daysInMonth + firstWeekday - 1) / 7).ceil(),
                  (rowIndex) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: List.generate(7, (colIndex) {
                          final index = rowIndex * 7 + colIndex;
                          if (index < firstWeekday - 1 ||
                              index >= daysInMonth + firstWeekday - 1) {
                            return const Expanded(child: SizedBox());
                          }

                          final day = index - (firstWeekday - 1) + 1;
                          final isToday = day == now.day;
                          final dayRecords = recordsByDay[day] ?? [];
                          final hasRecords = dayRecords.isNotEmpty;

                          return Expanded(
                            child: Container(
                              height: 60,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : (hasRecords
                                          ? (isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.03,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.02,
                                                  ))
                                          : Colors.transparent),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isToday
                                      ? AppColors.primary.withValues(alpha: 0.6)
                                      : (isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.05,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.05,
                                              )),
                                  width: isToday ? 1.5 : 1,
                                ),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Row(
                                children: [
                                  // 左侧日期
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Text(
                                        '$day',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isToday
                                              ? AppColors.primary
                                              : _getPrimaryTextColor(isDark),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 右侧签到与摇摇乐
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildTaskIndicator(
                                          dayRecords,
                                          'check_in',
                                          const Color(0xFF4ADE80),
                                          Icons.check_circle,
                                        ),
                                        _buildTaskIndicator(
                                          dayRecords,
                                          'shake',
                                          const Color(0xFFFFD700),
                                          Icons.monetization_on,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskIndicator(
    List<DailyTaskRecordDto> records,
    String taskType,
    Color color,
    IconData icon,
  ) {
    try {
      final record = records.firstWhere((r) => r.taskType == taskType);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            '+${record.rewardAmount}',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } catch (_) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.7), size: 14),
          const SizedBox(width: 6),
          Container(
            width: 10,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isCompleted,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isCompleted ? color.withValues(alpha: 0.1) : color,
        foregroundColor: isCompleted ? color : Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: isCompleted
              ? BorderSide(color: color.withValues(alpha: 0.3))
              : BorderSide.none,
        ),
      ),
      icon: isLoading
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isCompleted ? color : Colors.white,
              ),
            )
          : Icon(isCompleted ? Icons.check : icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSteamInfoSection(bool isDark) {
    if (_isLoadingInfo) return _buildLoading(AppColors.primary, isDark);
    if (_infoError != null) return _buildError(_infoError!, isDark);
    final info = _steamUserInfo!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (info.cs2Gold.toInt() > 0 || info.onlineTimeTotal.toInt() > 0) ...[
          _buildInfoCard('CS2 综合数据', [
            _InfoItem('金币', _formatNumber(info.cs2Gold.toInt())),
            _InfoItem('点数', _formatNumber(info.cs2Point.toInt())),
            _InfoItem('已消耗点', _formatNumber(info.cs2SpentPoint.toInt())),
            _InfoItem('今日在线', _formatDuration(info.onlineTimeDay.toInt())),
            _InfoItem('累计在线', _formatDuration(info.onlineTimeTotal.toInt())),
          ], isDark),
          const SizedBox(height: 16),
        ],

        if (info.csgoGold.toInt() > 0 || info.csgoOnlineTime.toInt() > 0) ...[
          _buildInfoCard('CS:GO 综合数据', [
            _InfoItem('金币', _formatNumber(info.csgoGold.toInt())),
            _InfoItem('累计在线', _formatDuration(info.csgoOnlineTime.toInt())),
          ], isDark),
        ],
      ],
    );
  }

  Widget _buildInfoCard(String title, List<_InfoItem> items, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _getStandardCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              title,
              style: TextStyle(
                color: _getPrimaryTextColor(isDark),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.2,
            children: items.map((item) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      color: _getSecondaryTextColor(isDark),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: MarqueeText(
                        text: item.value,
                        style: TextStyle(
                          color: _getPrimaryTextColor(isDark),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInventorySection(bool isDark) {
    if (_isLoadingInventory) {
      return _buildLoading(const Color(0xFF4ADE80), isDark);
    }
    if (_inventoryError != null) return _buildError(_inventoryError!, isDark);
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _getStandardCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 三列，适应右侧布局宽度
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final hasItem = item.count > 0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: hasItem
                      ? item.color.withValues(alpha: 0.05)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.02)
                            : Colors.black.withValues(alpha: 0.02)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: hasItem
                        ? item.color.withValues(alpha: 0.2)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      color: hasItem
                          ? item.color
                          : _getSecondaryTextColor(isDark),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: _getSecondaryTextColor(isDark),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${item.count}',
                      style: TextStyle(
                        color: hasItem
                            ? _getPrimaryTextColor(isDark)
                            : _getSecondaryTextColor(isDark),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '估算总价值',
                  style: TextStyle(
                    color: _getSecondaryTextColor(isDark),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.monetization_on,
                  color: AppColors.amber500,
                  size: 16,
                ),
                const SizedBox(width: 4),
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
    );
  }

  Widget _buildLoading(Color color, bool isDark) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(color),
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '正在加载数据...',
            style: TextStyle(
              color: _getSecondaryTextColor(isDark),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error, bool isDark) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: _getSecondaryTextColor(isDark),
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              color: _getSecondaryTextColor(isDark),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ElevatedButton.icon(
        onPressed: () => _showUnbindConfirm(context, isDark),
        icon: const Icon(Icons.logout, size: 18),
        label: const Text(
          '退出登录并解除论坛账户关联',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      ),
    );
  }

  void _showUnbindConfirm(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.slate800 : Colors.white,
        title: Text(
          '解除关联',
          style: TextStyle(color: _getPrimaryTextColor(isDark), fontSize: 16),
        ),
        content: Text(
          '确定要解除论坛账户关联吗？',
          style: TextStyle(color: _getSecondaryTextColor(isDark), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              '取消',
              style: TextStyle(color: _getSecondaryTextColor(isDark)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
            child: const Text('确认解除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int value) {
    if (value == 0) return '0';
    final str = value.toString();
    final buffer = StringBuffer();
    final len = str.length;
    for (var i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes分钟';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '$hours小时${mins > 0 ? ' $mins分' : ''}';
  }
}

class _InfoItem {
  final String label;
  final String value;
  const _InfoItem(this.label, this.value);
}

class _InventoryItem {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  const _InventoryItem(this.label, this.count, this.icon, this.color);
}
