import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/bloc/settings/settings_bloc.dart';
import '../../../core/bloc/settings/settings_event.dart';
import '../../../core/bloc/settings/settings_state.dart';
import '../../../core/utils/formatters.dart';
import 'settings_group_title.dart';
import '../../../core/constants/app_colors.dart';

/// 隐私设置组件 — 黑名单管理
///
/// 位于 Settings → 隐私 → 黑名单，展示已拉黑用户列表，可移除拉黑。
/// 一期临时由 SettingsBloc 承载，独立 BlocklistBloc 留二期。
class PrivacySettings extends StatefulWidget {
  final SettingsState settingsState;

  const PrivacySettings({super.key, required this.settingsState});

  @override
  State<PrivacySettings> createState() => _PrivacySettingsState();
}

class _PrivacySettingsState extends State<PrivacySettings> {
  @override
  void initState() {
    super.initState();
    // 进入时加载黑名单
    context.read<SettingsBloc>().add(SettingsLoadBlocklist());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupTitle(
          title: '隐私',
          hasGlow: true,
          icon: MdiIcons.shieldAccountOutline,
        ),
        _buildBlocklistSection(context),
      ],
    );
  }

  Widget _buildBlocklistSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blockedUsers = widget.settingsState.blockedUsers;
    final isLoading = widget.settingsState.isLoadingBlocklist;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.slate700, AppColors.slate800]
              : [const Color(0xFFFAFBFC), AppColors.slate50],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.slate600 : AppColors.gray200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Icon(
                MdiIcons.accountCancelOutline,
                size: 20,
                color: isDark ? Colors.white70 : AppColors.gray700,
              ),
              const SizedBox(width: 10),
              Text(
                '黑名单',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.gray800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${blockedUsers.length})',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : AppColors.gray500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '被拉黑的用户无法在攻略社区中出现，其攻略和评论将被隐藏。',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : AppColors.gray500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // 列表内容
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (blockedUsers.isEmpty)
            _buildEmptyState(isDark)
          else
            _buildBlockedList(context, isDark, blockedUsers),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            MdiIcons.accountCheckOutline,
            size: 40,
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : AppColors.gray300,
          ),
          const SizedBox(height: 12),
          Text(
            '黑名单为空',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : AppColors.gray400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '在攻略详情或评论区通过「⋯」菜单拉黑用户',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white24 : AppColors.gray300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedList(
    BuildContext context,
    bool isDark,
    List<BlockedUserInfo> users,
  ) {
    return Column(
      children: users.map((user) {
        return _BlockedUserTile(
          user: user,
          isDark: isDark,
          onUnblock: () => _confirmUnblock(context, user),
        );
      }).toList(),
    );
  }

  void _confirmUnblock(BuildContext context, BlockedUserInfo user) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('取消拉黑'),
          content: Text('确定要取消拉黑「${user.userName}」吗？\n取消后该用户的内容将重新可见。'),
          backgroundColor: isDark ? AppColors.slate800 : Colors.white,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<SettingsBloc>().add(
                  SettingsUnblockUser(user.userId),
                );
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text('已取消拉黑「${user.userName}」'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  final BlockedUserInfo user;
  final bool isDark;
  final VoidCallback onUnblock;

  const _BlockedUserTile({
    required this.user,
    required this.isDark,
    required this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.gray200,
        ),
      ),
      child: Row(
        children: [
          // 头像占位
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.slate600 : AppColors.gray200,
            ),
            child: Center(
              child: Text(
                user.userName.isNotEmpty ? user.userName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppColors.gray500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 用户名 + 拉黑时间
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.userName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.gray800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '拉黑于 ${Formatters.formatDateTime(user.blockedAt.toIso8601String())}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : AppColors.gray400,
                  ),
                ),
              ],
            ),
          ),
          // 移除按钮
          TextButton.icon(
            onPressed: onUnblock,
            icon: Icon(
              MdiIcons.accountRemoveOutline,
              size: 16,
              color: isDark ? Colors.white60 : AppColors.gray500,
            ),
            label: Text(
              '移除',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : AppColors.gray500,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
