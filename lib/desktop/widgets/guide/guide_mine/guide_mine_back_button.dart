import 'package:flutter/material.dart';

import '../community_guide/community_guide_theme.dart';

/// 「我的中心」页头左侧返回按钮
class GuideMineBackButton extends StatefulWidget {
  /// 点击时的回调，通常由 [GuideMineHeader] 传入
  final VoidCallback onTap;

  const GuideMineBackButton({super.key, required this.onTap});

  @override
  State<GuideMineBackButton> createState() => _GuideMineBackButtonState();
}

class _GuideMineBackButtonState extends State<GuideMineBackButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.onTap,
          child: Tooltip(
            message: '返回',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _hovering
                    ? (colors.isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.06))
                    : colors.chipInactiveBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: colors.iconPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
