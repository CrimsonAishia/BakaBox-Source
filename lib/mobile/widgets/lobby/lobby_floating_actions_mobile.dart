import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/bloc/lobby/lobby_bloc.dart';
import '../../../core/constants/app_colors.dart';

/// 移动端大厅浮动操作按钮组
///
/// 样式与桌面端 [LobbyFloatingActions] 保持一致：
/// 半透明黑底圆角按钮，竖向排列在右下角。
class LobbyFloatingActionsMobile extends StatelessWidget {
  final LobbyState state;
  final VoidCallback onChatTap;
  final VoidCallback onPlayersTap;
  final VoidCallback onSettingsTap;
  final VoidCallback? onBroadcastTap;
  final int unreadMessageCount;

  const LobbyFloatingActionsMobile({
    super.key,
    required this.state,
    required this.onChatTap,
    required this.onPlayersTap,
    required this.onSettingsTap,
    this.onBroadcastTap,
    this.unreadMessageCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bool canBroadcast =
        !state.isAnonymous && state.broadcastCooldownSeconds <= 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 广播按钮
        _MobileActionButton(
          icon: Icons.campaign,
          badge: state.broadcastCooldownSeconds > 0
              ? '${state.broadcastCooldownSeconds}'
              : null,
          badgeColor: AppColors.amber500,
          isDisabled: !canBroadcast,
          showDisabledStrike: true,
          onTap: canBroadcast ? onBroadcastTap : null,
        ),
        const SizedBox(height: 12),
        // 在线玩家按钮
        _MobileActionButton(
          icon: MdiIcons.accountGroup,
          badge: state.serverOnlineCount > 999
              ? '999+'
              : '${state.serverOnlineCount}',
          onTap: onPlayersTap,
        ),
        const SizedBox(height: 12),
        // 设置按钮
        _MobileActionButton(icon: MdiIcons.cogOutline, onTap: onSettingsTap),
        const SizedBox(height: 12),
        // 聊天按钮
        _MobileActionButton(
          icon: Icons.chat_bubble_outline,
          badge: unreadMessageCount > 0
              ? (unreadMessageCount > 99 ? '99+' : '$unreadMessageCount')
              : null,
          onTap: onChatTap,
        ),
      ],
    );
  }
}

/// 移动端浮动操作按钮（复用桌面端样式）
class _MobileActionButton extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final Color? badgeColor;
  final bool isDisabled;
  final bool showDisabledStrike;
  final VoidCallback? onTap;

  const _MobileActionButton({
    required this.icon,
    this.badge,
    this.badgeColor,
    this.isDisabled = false,
    this.showDisabledStrike = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final buttonWidget = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDisabled
                ? Colors.black.withValues(alpha: 0.24)
                : Colors.black.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDisabled
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Icon(
            icon,
            color: isDisabled
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.white,
            size: 24,
          ),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        buttonWidget,
        if (isDisabled && showDisabledStrike)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Transform.rotate(
                  angle: -0.5,
                  child: Container(
                    width: 34,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: AppColors.red500,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.red500.withValues(alpha: 0.6),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (badge != null)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor ?? AppColors.red500,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
