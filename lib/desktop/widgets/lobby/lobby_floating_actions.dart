import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/bloc/lobby/lobby_bloc.dart';
import '../../../core/constants/app_colors.dart';

/// 大厅浮动操作按钮组
class LobbyFloatingActions extends StatelessWidget {
  final LobbyState state;

  const LobbyFloatingActions({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 广播按钮
        LobbyActionButton(
          icon: Icons.campaign,
          badge: state.broadcastCooldownSeconds > 0
              ? '${state.broadcastCooldownSeconds}'
              : null,
          badgeColor: AppColors.amber500,
          isDisabled: state.isAnonymous || state.broadcastCooldownSeconds > 0,
          showDisabledStrike: true,
          onTap: !state.isAnonymous && state.broadcastCooldownSeconds <= 0
              ? () => context.read<LobbyBloc>().add(
                  const LobbyBroadcastDialogToggled(),
                )
              : null,
        ),
        const SizedBox(height: 12),
        LobbyActionButton(
          icon: MdiIcons.accountGroup,
          badge: state.serverOnlineCount > 999
              ? '999+'
              : '${state.serverOnlineCount}',
          isActive: state.isPlayersPanelOpen,
          onTap: () =>
              context.read<LobbyBloc>().add(const LobbyPlayersPanelToggled()),
        ),
        const SizedBox(height: 12),
        LobbyActionButton(
          icon: MdiIcons.cogOutline,
          isActive: state.isSettingsPanelOpen,
          onTap: () =>
              context.read<LobbyBloc>().add(const LobbySettingsPanelToggled()),
        ),
      ],
    );
  }
}

/// 浮动操作按钮
class LobbyActionButton extends StatefulWidget {
  final IconData icon;
  final String? badge;
  final Color? badgeColor;
  final bool isActive;
  final bool isDisabled;
  final bool showDisabledStrike;
  final VoidCallback? onTap;

  const LobbyActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badge,
    this.badgeColor,
    this.isActive = false,
    this.isDisabled = false,
    this.showDisabledStrike = false,
  });

  @override
  State<LobbyActionButton> createState() => _LobbyActionButtonState();
}

class _LobbyActionButtonState extends State<LobbyActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isHovered = _isHovered && !widget.isDisabled;

    final buttonWidget = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.isDisabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isDisabled ? null : widget.onTap,
          borderRadius: BorderRadius.circular(14),
          canRequestFocus: false,
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isDisabled
                  ? Colors.black.withValues(alpha: 0.24)
                  : (widget.isActive
                        ? Colors.white.withValues(alpha: 0.18)
                        : (isHovered
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.48))),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isDisabled
                    ? Colors.white.withValues(alpha: 0.04)
                    : (widget.isActive
                          ? AppColors.sky400.withValues(alpha: 0.6)
                          : (isHovered
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.08))),
              ),
              boxShadow: isHovered && !widget.isDisabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.icon,
              color: widget.isDisabled
                  ? Colors.white.withValues(alpha: 0.3)
                  : (widget.isActive ? AppColors.sky400 : Colors.white),
              size: 18,
            ),
          ),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        buttonWidget,
        if (widget.isDisabled && widget.showDisabledStrike)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Transform.rotate(
                  angle: -0.5,
                  child: Container(
                    width: 28,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.red500,
                      borderRadius: BorderRadius.circular(1),
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
        if (widget.badge != null)
          Positioned(
            top: -6,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: widget.badgeColor ?? AppColors.red500,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                widget.badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
