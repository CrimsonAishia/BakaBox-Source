import 'dart:math';
import 'package:flutter/material.dart';
import 'character_gallery_theme.dart';

/// 樱花纹样分隔线绘制器
class TraditionalDividerPainter extends CustomPainter {
  final Color color;
  TraditionalDividerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    // 中心竖线
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );

    // 樱花装饰点
    const spacing = 40.0;
    final count = (size.height / spacing).ceil();

    for (int i = 0; i < count; i++) {
      final y = i * spacing + spacing / 2;
      _drawSakura(canvas, Offset(size.width / 2, y), 6, paint, fillPaint);
    }
  }

  void _drawSakura(
      Canvas canvas, Offset center, double size, Paint strokePaint, Paint fillPaint) {
    // 绘制5瓣樱花
    for (int i = 0; i < 5; i++) {
      final angle = (i * 72 - 90) * pi / 180;
      final petalPath = Path();

      final tipX = center.dx + cos(angle) * size;
      final tipY = center.dy + sin(angle) * size;

      final leftAngle = angle - 0.4;
      final rightAngle = angle + 0.4;
      final ctrlDist = size * 0.6;

      petalPath.moveTo(center.dx, center.dy);
      petalPath.quadraticBezierTo(
        center.dx + cos(leftAngle) * ctrlDist,
        center.dy + sin(leftAngle) * ctrlDist,
        tipX,
        tipY,
      );
      petalPath.quadraticBezierTo(
        center.dx + cos(rightAngle) * ctrlDist,
        center.dy + sin(rightAngle) * ctrlDist,
        center.dx,
        center.dy,
      );

      canvas.drawPath(petalPath, fillPaint);
      canvas.drawPath(petalPath, strokePaint);
    }

    // 花心
    canvas.drawCircle(center, 1.5, Paint()..color = CharacterGalleryTheme.goldBright);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 樱花飘落动画
class SakuraPetals extends StatelessWidget {
  final AnimationController controller;
  const SakuraPetals({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _SakuraPetalsPainter(progress: controller.value, isDark: isDark),
          size: Size.infinite,
        );
      },
    );
  }
}

class _SakuraPetalsPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final List<_Petal> petals;

  _SakuraPetalsPainter({required this.progress, required this.isDark})
      : petals = List.generate(15, (i) => _Petal(i));

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final petal in petals) {
      final x =
          (petal.startX * size.width + progress * petal.speedX * 100) % size.width;
      final y = (petal.startY * size.height + progress * petal.speedY * size.height * 1.5) %
          size.height;
      final rotation = progress * petal.rotationSpeed * 2 * pi;

      // 夜间模式下降低樱花透明度
      final baseOpacity = isDark ? petal.opacity * 0.6 : petal.opacity;
      paint.color = CharacterGalleryTheme.sakuraPink.withValues(alpha: baseOpacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      // 绘制花瓣形状
      final path = Path()
        ..moveTo(0, -petal.size)
        ..quadraticBezierTo(petal.size * 0.8, -petal.size * 0.5, petal.size * 0.5, 0)
        ..quadraticBezierTo(petal.size * 0.8, petal.size * 0.5, 0, petal.size)
        ..quadraticBezierTo(-petal.size * 0.8, petal.size * 0.5, -petal.size * 0.5, 0)
        ..quadraticBezierTo(-petal.size * 0.8, -petal.size * 0.5, 0, -petal.size);

      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SakuraPetalsPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}

class _Petal {
  final double startX;
  final double startY;
  final double speedX;
  final double speedY;
  final double rotationSpeed;
  final double size;
  final double opacity;

  _Petal(int seed)
      : startX = Random(seed).nextDouble(),
        startY = Random(seed + 1).nextDouble(),
        speedX = Random(seed + 2).nextDouble() * 2 - 1,
        speedY = Random(seed + 3).nextDouble() * 0.5 + 0.5,
        rotationSpeed = Random(seed + 4).nextDouble() * 2 - 1,
        size = Random(seed + 5).nextDouble() * 6 + 4,
        opacity = Random(seed + 6).nextDouble() * 0.3 + 0.15;
}
