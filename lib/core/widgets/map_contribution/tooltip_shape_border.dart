part of '../map_contribution_dialog.dart';

/// 自定义带有向下箭头的气泡边框
class TooltipShapeBorder extends ShapeBorder {
  final double radius;
  final double arrowWidth;
  final double arrowHeight;
  final Color borderColor;

  const TooltipShapeBorder({
    this.radius = 20.0,
    this.arrowWidth = 12.0,
    this.arrowHeight = 6.0,
    this.borderColor = Colors.transparent,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(bottom: arrowHeight);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect, textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    rect = Rect.fromPoints(
      rect.topLeft,
      rect.bottomRight - Offset(0, arrowHeight),
    );
    final path = Path();
    path.moveTo(rect.left + radius, rect.top);
    path.lineTo(rect.right - radius, rect.top);
    path.arcToPoint(
      Offset(rect.right, rect.top + radius),
      radius: Radius.circular(radius),
    );
    path.lineTo(rect.right, rect.bottom - radius);
    path.arcToPoint(
      Offset(rect.right - radius, rect.bottom),
      radius: Radius.circular(radius),
    );

    // Bottom edge with arrow
    path.lineTo(rect.width / 2 + rect.left + arrowWidth / 2, rect.bottom);
    path.lineTo(
      rect.width / 2 + rect.left,
      rect.bottom + arrowHeight,
    ); // Arrow tip
    path.lineTo(rect.width / 2 + rect.left - arrowWidth / 2, rect.bottom);

    path.lineTo(rect.left + radius, rect.bottom);
    path.arcToPoint(
      Offset(rect.left, rect.bottom - radius),
      radius: Radius.circular(radius),
    );
    path.lineTo(rect.left, rect.top + radius);
    path.arcToPoint(
      Offset(rect.left + radius, rect.top),
      radius: Radius.circular(radius),
    );
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (borderColor != Colors.transparent) {
      final paint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawPath(getOuterPath(rect, textDirection: textDirection), paint);
    }
  }

  @override
  ShapeBorder scale(double t) => this;
}
