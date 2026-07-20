import 'package:flutter/material.dart';

class ServerCardMonitoringBadge extends StatelessWidget {
  const ServerCardMonitoringBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: CustomPaint(
        painter: _BadgePainter(),
        child: const Stack(
          children: [
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                Icons.notifications_active_rounded, // 监控铃铛图标
                size: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();

    // 绘制阴影发光效果
    canvas.drawShadow(
      path,
      const Color(0xFFFFB300).withValues(alpha: 0.6),
      4,
      false,
    );

    // 绘制渐变填充
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0xFFFFEA00), // 明亮的黄色
          Color(0xFFFFB300), // 稍微偏橙的黄色
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);

    // 绘制内边距高光边框增加立体感
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.5);

    // 为了不超出边界被截断，将高光往内缩 0.5
    final borderPath = Path()
      ..moveTo(1, 0.5)
      ..lineTo(size.width - 0.5, 0.5)
      ..lineTo(size.width - 0.5, size.height - 1)
      ..close();

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
