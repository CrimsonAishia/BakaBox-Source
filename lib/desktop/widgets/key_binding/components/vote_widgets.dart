import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/bloc/auth/auth_bloc.dart';
import '../../../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../../../core/bloc/key_binding/key_binding_event.dart';
import '../../../../core/models/key_config_models.dart';
import '../../login_dialog.dart';
import '../../../../core/constants/app_colors.dart';

/// 详情页投票按钮组
class DetailVoteButtons extends StatelessWidget {
  final KeyConfig config;
  final bool isOwner;

  const DetailVoteButtons({
    super.key,
    required this.config,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final upCount = config.upCount;
    final downCount = config.downCount;
    final voteType = config.voteTypeEnum;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate700 : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VoteButton(
            icon: voteType == KeyConfigVoteType.up
                ? MdiIcons.thumbUp
                : MdiIcons.thumbUpOutline,
            isActive: voteType == KeyConfigVoteType.up,
            onTap: () => _handleVote(context, KeyConfigVoteType.up),
          ),
          const SizedBox(width: 2),
          Text(
            '$upCount',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: voteType == KeyConfigVoteType.up
                  ? AppColors.emerald500
                  : (isDark ? Colors.white54 : Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 10),
          VoteButton(
            icon: voteType == KeyConfigVoteType.down
                ? MdiIcons.thumbDown
                : MdiIcons.thumbDownOutline,
            isActive: voteType == KeyConfigVoteType.down,
            isDownVote: true,
            disabled: isOwner,
            onTap: isOwner
                ? null
                : () => _handleVote(context, KeyConfigVoteType.down),
          ),
          const SizedBox(width: 2),
          Text(
            '$downCount',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: voteType == KeyConfigVoteType.down
                  ? AppColors.red500
                  : (isOwner
                        ? (isDark ? Colors.white24 : Colors.grey[400])
                        : (isDark ? Colors.white54 : Colors.grey[600])),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  void _handleVote(BuildContext context, KeyConfigVoteType voteType) {
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) {
      _showLoginPrompt(context);
      return;
    }

    context.read<KeyBindingBloc>().add(
      KeyBindingVote(configId: config.id, voteType: voteType),
    );
  }

  void _showLoginPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(
              MdiIcons.accountLockOutline,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 10),
            const Text('需要登录', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Text('登录后才能进行投票'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              LoginDialog.show(context);
            },
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }
}

/// 单个投票按钮
class VoteButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final bool isDownVote;
  final bool disabled;
  final VoidCallback? onTap;

  const VoteButton({
    super.key,
    required this.icon,
    required this.isActive,
    this.isDownVote = false,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDownVote ? AppColors.red500 : AppColors.emerald500;
    final bgColor = Colors.grey[200]!;
    final normalColor = Colors.grey[500]!;
    final disabledColor = Colors.grey[300]!;

    return Tooltip(
      message: disabled ? '不能对自己的配置投反对票' : (isDownVote ? '反对' : '赞成'),
      child: Material(
        color: isActive ? activeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          hoverColor: disabled ? Colors.transparent : bgColor,
          mouseCursor: disabled
              ? SystemMouseCursors.forbidden
              : SystemMouseCursors.click,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 14,
              color: disabled
                  ? disabledColor
                  : (isActive ? Colors.white : normalColor),
            ),
          ),
        ),
      ),
    );
  }
}
