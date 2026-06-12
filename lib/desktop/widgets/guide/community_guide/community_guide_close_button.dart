import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// 详情弹窗右上角的"切角三角形"关闭按钮
///
/// 点击区域为右上角直角三角形：
/// - 默认填充 `#EF4444`，hover 时加深至 `#DC2626`
/// - 始终描边 `#B91C1C`
class CommunityGuideCloseButton extends StatefulWidget {
  final VoidCallback onTap;

  const CommunityGuideCloseButton({super.key, required this.onTap});

  @override
  State<CommunityGuideCloseButton> createState() =>
      _CommunityGuideCloseButtonState();
}

class _CommunityGuideCloseButtonState extends State<CommunityGuideCloseButton> {
  bool _isHovered = false;

  static const _fill = AppColors.red500;
  static const _fillHover = AppColors.red600;
  static const _border = Color(0xFFB91C1C);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          child: CustomPaint(
            painter: _CornerTrianglePainter(
              fillColor: _isHovered ? _fillHover : _fill,
              borderColor: _border,
            ),
            child: const Align(
              alignment: Alignment(0.55, -0.55),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 右上角倒三角绘制器
class _CornerTrianglePainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;

  _CornerTrianglePainter({required this.fillColor, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_CornerTrianglePainter oldDelegate) =>
      fillColor != oldDelegate.fillColor ||
      borderColor != oldDelegate.borderColor;
}
