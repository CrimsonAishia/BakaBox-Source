import 'package:flutter/material.dart';
import 'character_gallery_theme.dart';

/// 带 hover 效果的分类按钮
class CategoryButton extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<CategoryButton> createState() => _CategoryButtonState();
}

class _CategoryButtonState extends State<CategoryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final cardBg = CharacterGalleryTheme.getCardBackground(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? CharacterGalleryTheme.getVermillion(context)
                : _isHovered
                ? CharacterGalleryTheme.getVermillion(
                    context,
                  ).withValues(alpha: isDark ? 0.2 : 0.1)
                : cardBg.withValues(alpha: 0.8),
            border: Border.all(
              color: widget.isSelected || _isHovered
                  ? CharacterGalleryTheme.getVermillion(context)
                  : scrollBrown.withValues(alpha: 0.4),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isSelected ? Colors.white : inkColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

/// 带 hover 效果的操作按钮
class HoverButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool small;

  const HoverButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.small = false,
  });

  @override
  State<HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<HoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    final iconSize = widget.small ? 12.0 : 14.0;
    final fontSize = widget.small ? 11.0 : 12.0;
    final hPadding = widget.small ? 8.0 : 10.0;
    final vPadding = widget.small ? 4.0 : 5.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: hPadding,
            vertical: vPadding,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? CharacterGalleryTheme.getVermillion(
                    context,
                  ).withValues(alpha: isDark ? 0.2 : 0.1)
                : Colors.transparent,
            border: Border.all(
              color: _isHovered
                  ? CharacterGalleryTheme.getVermillion(context)
                  : scrollBrown.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: iconSize,
                color: _isHovered
                    ? CharacterGalleryTheme.getVermillion(context)
                    : scrollBrown,
              ),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: _isHovered
                      ? CharacterGalleryTheme.getVermillion(context)
                      : scrollBrown,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 滚动指示器
class ScrollIndicator extends StatelessWidget {
  final bool isTop;

  const ScrollIndicator({super.key, required this.isTop});

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return IgnorePointer(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              scrollBrown.withValues(alpha: 0.25),
              scrollBrown.withValues(alpha: 0.12),
              scrollBrown.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        padding: EdgeInsets.only(top: isTop ? 2 : 0, bottom: isTop ? 0 : 2),
        child: Icon(
          isTop ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: scrollBrown,
          size: 24,
        ),
      ),
    );
  }
}

/// 分隔线（带标题）
class SectionDivider extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionDivider({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Container(width: 30, height: 2, color: scrollBrown),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: scrollBrown,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 2,
              color: scrollBrown.withValues(alpha: 0.3),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// 虚线边框绘制器
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashWidth = 4.0,
    this.dashSpace = 4.0,
    this.radius = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    final dashedPath = Path();

    for (final metric in metrics) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final length = draw ? dashWidth : dashSpace;
        if (draw) {
          dashedPath.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.radius != radius;
  }
}

/// 角色图鉴通用标签组件
class CharacterTagWidget extends StatelessWidget {
  final String text;
  final String colorHex;

  const CharacterTagWidget({
    super.key,
    required this.text,
    required this.colorHex,
  });

  @override
  Widget build(BuildContext context) {
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final color = Color(int.parse(colorHex.replaceAll('#', '0xFF')));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      // 外层描边 (Solid stroke)
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          // 极淡的描边阴影
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 2,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CustomPaint(
        // 内层虚线 (Dashed border)
        painter: DashedBorderPainter(
          color: color.withValues(alpha: 0.6),
          strokeWidth: 1,
          dashWidth: 4,
          dashSpace: 3,
          radius: 3,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.black12,
                    width: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: inkColor.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  // 文字描边
                  shadows: [
                    Shadow(
                      color: isDark ? Colors.black87 : Colors.white,
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
