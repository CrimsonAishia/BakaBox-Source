import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 通用滚动指示器
///
/// 用于显示列表可以向上或向下滚动的视觉提示
class CommonScrollIndicator extends StatelessWidget {
  final bool isTop;
  final Color? color;
  final Color? bgColor;

  const CommonScrollIndicator({
    super.key,
    required this.isTop,
    this.color,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final indicatorColor = color ?? (isDark ? Colors.white : AppColors.gray500);
    final bg = bgColor ?? (isDark ? const Color(0xFF1E1E2E) : Colors.white);

    return IgnorePointer(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              bg.withValues(alpha: 0.95),
              bg.withValues(alpha: 0.7),
              bg.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        padding: EdgeInsets.only(top: isTop ? 4 : 0, bottom: isTop ? 0 : 4),
        child: Icon(
          isTop ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: indicatorColor.withValues(alpha: 0.6),
          size: 20,
        ),
      ),
    );
  }
}
