import 'package:flutter/material.dart';

class ServerCardCopyIconButton extends StatefulWidget {
  final VoidCallback onTap;

  const ServerCardCopyIconButton({super.key, required this.onTap});

  @override
  State<ServerCardCopyIconButton> createState() =>
      _ServerCardCopyIconButtonState();
}

class _ServerCardCopyIconButtonState extends State<ServerCardCopyIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Icon(
            Icons.copy,
            size: 14,
            color: _isHovered ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// 带 Hover 效果的图标按钮
class ServerCardHoverIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool isActive;
  final bool disabled;
  final VoidCallback? onPressed;

  const ServerCardHoverIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.disabled,
    this.onPressed,
  });

  @override
  State<ServerCardHoverIconButton> createState() =>
      _ServerCardHoverIconButtonState();
}

class _ServerCardHoverIconButtonState extends State<ServerCardHoverIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isHovered = _isHovered && !widget.disabled;

    return MouseRegion(
      cursor: widget.disabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isActive
                ? widget.color.withValues(alpha: 0.35)
                : isHovered
                ? widget.color.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: widget.disabled ? 0.05 : 0.15),
            borderRadius: BorderRadius.circular(4),
            border: widget.isActive
                ? Border.all(color: widget.color, width: 1.5)
                : isHovered
                ? Border.all(
                    color: widget.color.withValues(alpha: 0.6),
                    width: 1,
                  )
                : null,
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: widget.disabled
                ? Colors.white.withValues(alpha: 0.3)
                : widget.isActive || isHovered
                ? Colors.white
                : Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
