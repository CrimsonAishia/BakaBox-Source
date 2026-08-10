import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class LoginOptionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String iconPath;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const LoginOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconPath,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<LoginOptionCard> createState() => _LoginOptionCardState();
}

class _LoginOptionCardState extends State<LoginOptionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? AppColors.slate700 : AppColors.slate100;
    final hoverBgColor = widget.isDark ? AppColors.slate600 : AppColors.slate200;
    final borderColor = widget.isDark 
        ? Colors.white.withValues(alpha: 0.1) 
        : Colors.black.withValues(alpha: 0.05);
    final hoverBorderColor = widget.color.withValues(alpha: 0.5);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isHovered ? hoverBgColor : bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? hoverBorderColor : borderColor,
              width: 1.5,
            ),
            boxShadow: _isHovered ? [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ] : [],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.black26 : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Image.asset(
                  widget.iconPath,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.account_circle, 
                    color: widget.color,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? Colors.white : AppColors.gray800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark ? Colors.white54 : AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: _isHovered ? widget.color : (widget.isDark ? Colors.white38 : Colors.black26),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
