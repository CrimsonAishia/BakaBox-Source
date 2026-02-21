import 'package:flutter/material.dart';

/// 导航项数据
class NavItemData {
  final IconData icon;
  final String label;
  final String? badge;
  final IconData? statusIcon;
  final Color? statusColor;
  final bool isSelected;
  final VoidCallback onTap;

  const NavItemData({
    required this.icon,
    required this.label,
    this.badge,
    this.statusIcon,
    this.statusColor,
    this.isSelected = false,
    required this.onTap,
  });
}

/// 导航项组件
class NavItem extends StatefulWidget {
  final NavItemData data;
  final bool isDark;

  const NavItem({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  State<NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isDark = widget.isDark;
    final isSelected = data.isSelected;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                    : const Color(0xFF6366F1).withValues(alpha: 0.1))
                : (_isHovered
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03))
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: data.onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      data.icon,
                      size: 18,
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        data.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF6366F1)
                              : (isDark ? Colors.white70 : const Color(0xFF374151)),
                        ),
                      ),
                    ),
                    // 徽章或状态图标
                    if (data.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          data.badge!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : (isDark ? Colors.white54 : const Color(0xFF6B7280)),
                          ),
                        ),
                      )
                    else if (data.statusIcon != null)
                      Icon(
                        data.statusIcon,
                        size: 14,
                        color: data.statusColor ??
                            (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
