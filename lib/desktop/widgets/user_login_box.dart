import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/bloc/auth/auth_bloc.dart';
import '../../core/bloc/auth/auth_event.dart';
import '../../core/bloc/auth/auth_state.dart';
import '../../core/bloc/daily_task/daily_task_bloc.dart';
import '../../core/bloc/daily_task/daily_task_event.dart';
import '../../core/bloc/daily_task/daily_task_state.dart';
import '../../core/models/user_info.dart';
import 'login_dialog.dart';
import 'shake_dialog.dart';

/// 用户登录框组件
///
/// 显示在侧边栏，展示登录状态和用户信息
/// 登录后可点击展开查看详细信息
class UserLoginBox extends StatefulWidget {
  const UserLoginBox({super.key});

  @override
  State<UserLoginBox> createState() => _UserLoginBoxState();
}

class _UserLoginBoxState extends State<UserLoginBox> {
  bool _isExpanded = false;
  bool _wasAuthenticated = false;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        // 首次构建时，如果已登录，触发状态检查
        if (!_initialized && state.isAuthenticated) {
          context.read<DailyTaskBloc>().add(
            const DailyTaskCheckStatusRequested(),
          );
          _wasAuthenticated = true;
          _initialized = true;
          return;
        }
        _initialized = true;

        // 登录成功时触发每日任务状态检查
        if (state.isAuthenticated && !_wasAuthenticated) {
          context.read<DailyTaskBloc>().add(
            const DailyTaskCheckStatusRequested(),
          );
        }
        // 登出时重置每日任务状态
        if (!state.isAuthenticated && _wasAuthenticated) {
          context.read<DailyTaskBloc>().add(const DailyTaskReset());
        }
        _wasAuthenticated = state.isAuthenticated;
      },
      builder: (context, state) {
        if (state.isAuthenticated && state.userInfo != null) {
          return _LoggedInView(
            userInfo: state.userInfo!,
            isExpanded: _isExpanded,
            onToggleExpand: () {
              setState(() => _isExpanded = !_isExpanded);
              // 展开时触发状态检查（懒加载，检测跨天）
              if (_isExpanded) {
                context.read<DailyTaskBloc>().add(
                  const DailyTaskCheckStatusRequested(),
                );
              }
            },
          );
        }
        return const _LoginPromptView();
      },
    );
  }
}

/// 获取卡片背景色 - 与侧边栏协调
Color _getCardColor(bool isDark) {
  return isDark
      ? const Color(0xFF334155).withValues(alpha: 0.6) // slate-700
      : const Color(0xFFF1F5F9); // slate-100
}

/// 获取卡片边框色
Color _getBorderColor(bool isDark) {
  return isDark
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);
}

/// 获取主文字颜色
Color _getPrimaryTextColor(bool isDark) {
  return isDark ? Colors.white : const Color(0xFF1F2937);
}

/// 获取次要文字颜色
Color _getSecondaryTextColor(bool isDark) {
  return isDark ? Colors.white60 : const Color(0xFF6B7280);
}

/// 获取头像背景色
Color _getAvatarBgColor(bool isDark) {
  return isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0);
}

/// 未登录视图 - 固定高度
class _LoginPromptView extends StatelessWidget {
  const _LoginPromptView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getCardColor(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getBorderColor(isDark)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '欢迎使用 BakaBox',
            style: TextStyle(
              color: _getPrimaryTextColor(isDark),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '关联您的论坛账户',
            style: TextStyle(
              color: _getSecondaryTextColor(isDark),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 28,
            child: ElevatedButton(
              onPressed: () {
                // 使用 addPostFrameCallback 确保 overlay 已准备好
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    LoginDialog.show(context);
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0080FF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('关联账户', style: TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('https://bbs.zombieden.cn/forum.php'),
                    ),
                    icon: Icon(Icons.forum_outlined, size: 14,
                        color: _getSecondaryTextColor(isDark)),
                    label: Text('论坛入口',
                        style: TextStyle(
                          fontSize: 11,
                          color: _getSecondaryTextColor(isDark),
                        )),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: _getBorderColor(isDark)),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('https://baka.aishia.cc'),
                    ),
                    icon: Icon(Icons.language, size: 14,
                        color: _getSecondaryTextColor(isDark)),
                    label: Text('官方网站',
                        style: TextStyle(
                          fontSize: 11,
                          color: _getSecondaryTextColor(isDark),
                        )),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: _getBorderColor(isDark)),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 已登录视图 - 可展开
class _LoggedInView extends StatelessWidget {
  final UserInfo userInfo;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const _LoggedInView({
    required this.userInfo,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: _getCardColor(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getBorderColor(isDark)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 折叠状态的主卡片
          InkWell(
            onTap: onToggleExpand,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 头像
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _getAvatarBgColor(isDark),
                    backgroundImage: userInfo.avatar.isNotEmpty
                        ? NetworkImage(userInfo.avatar)
                        : null,
                    child: userInfo.avatar.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 24,
                            color: _getSecondaryTextColor(isDark),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // 用户信息
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userInfo.username,
                          style: TextStyle(
                            color: _getPrimaryTextColor(isDark),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (userInfo.userGroup != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            "用户组:${userInfo.userGroup!}",
                            style: TextStyle(
                              color: _getSecondaryTextColor(isDark),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 展开/收起图标
                  AnimatedRotation(
                    turns: isExpanded ? 0 : 0.5,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: _getSecondaryTextColor(isDark),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 论坛入口 & 官方网站 - 始终可见
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse('https://bbs.zombieden.cn/forum.php'),
                      ),
                      icon: Icon(Icons.forum_outlined, size: 14,
                          color: _getSecondaryTextColor(isDark)),
                      label: Text('论坛入口',
                          style: TextStyle(
                            fontSize: 11,
                            color: _getSecondaryTextColor(isDark),
                          )),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _getBorderColor(isDark)),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse('https://baka.aishia.cc'),
                      ),
                      icon: Icon(Icons.language, size: 14,
                          color: _getSecondaryTextColor(isDark)),
                      label: Text('官方网站',
                          style: TextStyle(
                            fontSize: 11,
                            color: _getSecondaryTextColor(isDark),
                          )),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _getBorderColor(isDark)),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _ExpandedContent(userInfo: userInfo),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

/// 展开后的详细内容
class _ExpandedContent extends StatelessWidget {
  final UserInfo userInfo;

  const _ExpandedContent({required this.userInfo});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Divider(color: _getBorderColor(isDark), height: 1),
          const SizedBox(height: 12),

          // Steam ID
          if (userInfo.steamId != null)
            _SteamRow(steamId: userInfo.steamId!, steamUrl: userInfo.steamUrl),

          // 积分
          if (userInfo.credits != null)
            _InfoRow(
              icon: Icons.star_outline,
              label: '积分',
              value: userInfo.credits!,
            ),

          // 僵尸币
          if (userInfo.zombieCoins != null)
            _InfoRow(
              icon: Icons.monetization_on_outlined,
              label: '僵尸币',
              value: userInfo.zombieCoins!,
            ),
          const SizedBox(height: 12),
          // 每日任务按钮
          BlocBuilder<DailyTaskBloc, DailyTaskState>(
            builder: (context, state) {
              return Row(
                children: [
                  Expanded(child: _CheckInButton(state: state)),
                  const SizedBox(width: 8),
                  Expanded(child: _ShakeButton(state: state)),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.link_off,
                  label: '解除关联',
                  isDestructive: true,
                  onPressed: () => _showUnbindConfirm(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUnbindConfirm(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          '解除关联',
          style: TextStyle(color: _getPrimaryTextColor(isDark)),
        ),
        content: Text(
          '确定要解除论坛账户关联吗？',
          style: TextStyle(color: _getSecondaryTextColor(isDark)),
        ),
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
            child: const Text('确认解除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Steam 信息行 - 使用图标
class _SteamRow extends StatelessWidget {
  final String steamId;
  final String? steamUrl;

  const _SteamRow({required this.steamId, this.steamUrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: steamUrl != null ? () => launchUrl(Uri.parse(steamUrl!)) : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Image.asset(
              'assets/icons/steam.png',
              width: 14,
              height: 14,
              errorBuilder: (_, __, ___) => Icon(
                Icons.games,
                size: 14,
                color: _getSecondaryTextColor(isDark),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                steamId,
                style: TextStyle(
                  color: steamUrl != null
                      ? const Color(0xFF0080FF)
                      : _getSecondaryTextColor(isDark),
                  fontSize: 12,
                ),
              ),
            ),
            if (steamUrl != null)
              const Icon(Icons.open_in_new, size: 12, color: Color(0xFF0080FF)),
          ],
        ),
      ),
    );
  }
}

/// 信息行
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _getSecondaryTextColor(isDark)),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              color: _getSecondaryTextColor(isDark),
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(color: _getPrimaryTextColor(isDark), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.isDestructive = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDestructive
        ? Colors.red.shade400
        : (isDark ? Colors.white70 : const Color(0xFF6B7280));

    return SizedBox(
      height: 32,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}

/// 签到按钮 - 根据状态显示不同样式
class _CheckInButton extends StatelessWidget {
  final DailyTaskState state;

  const _CheckInButton({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white70 : const Color(0xFF6B7280);

    // 已签到 - 显示绿色完成状态和奖励金额
    if (state.hasCheckedIn) {
      final rewardText = state.checkInRewardAmount != null
          ? '+${state.checkInRewardAmount}'
          : '已签到';
      return SizedBox(
        height: 32,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.check, size: 14),
          label: Text(rewardText, style: const TextStyle(fontSize: 11)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green,
            disabledForegroundColor: Colors.green,
            side: BorderSide(color: Colors.green.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      );
    }

    // 签到中或检测状态中 - 显示 loading
    if (state.isCheckingIn || state.isCheckingStatus) {
      return SizedBox(
        height: 32,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
          label: Text(
            state.isCheckingIn ? '签到中' : '检测中',
            style: const TextStyle(fontSize: 11),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            disabledForegroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.3)),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      );
    }

    // 默认：可点击签到
    return SizedBox(
      height: 32,
      child: OutlinedButton.icon(
        onPressed: () => context.read<DailyTaskBloc>().add(
          const DailyTaskCheckInRequested(),
        ),
        icon: const Icon(Icons.check_circle_outline, size: 14),
        label: const Text('签到', style: TextStyle(fontSize: 11)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}

/// 摇一摇按钮 - 根据状态显示不同样式
class _ShakeButton extends StatelessWidget {
  final DailyTaskState state;

  const _ShakeButton({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white70 : const Color(0xFF6B7280);

    // 已摇过 - 显示绿色完成状态和奖励金额，仍可点击查看
    if (state.hasShaked) {
      final rewardText = state.shakeRewardAmount != null
          ? '+${state.shakeRewardAmount}'
          : '已摇过';
      return SizedBox(
        height: 32,
        child: OutlinedButton.icon(
          onPressed: () => ShakeDialog.show(context), // 允许点击查看
          icon: const Icon(Icons.check, size: 14),
          label: Text(rewardText, style: const TextStyle(fontSize: 11)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green,
            disabledForegroundColor: Colors.green,
            side: BorderSide(color: Colors.green.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      );
    }

    // 检测状态中 - 显示 loading
    if (state.isCheckingStatus) {
      return SizedBox(
        height: 32,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
          label: const Text('检测中', style: TextStyle(fontSize: 11)),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            disabledForegroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.3)),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      );
    }

    // 默认：可点击摇一摇
    // 无论 canShake 是 true/false/null，都允许用户点击尝试
    // ShakeDialog 内部会再次检测状态
    return SizedBox(
      height: 32,
      child: OutlinedButton.icon(
        onPressed: () => ShakeDialog.show(context),
        icon: const Icon(Icons.casino, size: 14),
        label: const Text('摇一摇', style: TextStyle(fontSize: 11)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}
