import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 传送过渡动画组件
class TouhouPortalEffect extends StatefulWidget {
  final double progress;
  final String targetLabel;
  final bool isHovered;
  final VoidCallback? onComplete;

  const TouhouPortalEffect({
    super.key,
    required this.progress,
    required this.targetLabel,
    this.isHovered = false,
    this.onComplete,
  });

  @override
  State<TouhouPortalEffect> createState() => _TouhouPortalEffectState();
}

class _TouhouPortalEffectState extends State<TouhouPortalEffect>
    with TickerProviderStateMixin {
  late AnimationController _outerCircleController;
  late AnimationController _innerCircleController;
  late AnimationController _particleController;
  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();

    _outerCircleController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();

    _innerCircleController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 40),
      vsync: this,
    )..repeat();

    _ringController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _outerCircleController.dispose();
    _innerCircleController.dispose();
    _particleController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _outerCircleController,
        _innerCircleController,
        _particleController,
        _ringController,
      ]),
      builder: (context, child) {
        return Container(
          color: Colors.black,
          child: Stack(
            children: [
              // 背景星空
              const _StarField(),

              // 中心传送门特效
              Center(
                child: SizedBox(
                  width: 500,
                  height: 500,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 外层大魔法阵
                      Transform.rotate(
                        angle: _outerCircleController.value * math.pi * -2,
                        child: CustomPaint(
                          size: const Size(500, 500),
                          painter: _MagicCirclePainter(
                            color: const Color(
                              0xFF9B59B6,
                            ).withValues(alpha: 0.7),
                            points: 8,
                            innerRadius: 0.15,
                            outerRadius: 1.0,
                            strokeWidth: 1.5,
                            glowRadius: 6,
                          ),
                        ),
                      ),

                      // 外层光环动画
                      CustomPaint(
                        size: const Size(460, 460),
                        painter: _PulseRingPainter(
                          progress: _ringController.value,
                          color: const Color(0xFF8E44AD).withValues(alpha: 0.5),
                        ),
                      ),

                      // 中层魔法阵
                      Transform.rotate(
                        angle: _innerCircleController.value * math.pi * 2,
                        child: CustomPaint(
                          size: const Size(360, 360),
                          painter: _MagicCirclePainter(
                            color: const Color(
                              0xFFE91E63,
                            ).withValues(alpha: 0.75),
                            points: 6,
                            innerRadius: 0.2,
                            outerRadius: 0.95,
                            strokeWidth: 1.5,
                            glowRadius: 5,
                          ),
                        ),
                      ),

                      // 内层光环动画
                      CustomPaint(
                        size: const Size(320, 320),
                        painter: _PulseRingPainter(
                          progress: (_ringController.value + 0.5) % 1.0,
                          color: const Color(0xFFE91E63).withValues(alpha: 0.4),
                        ),
                      ),

                      // 内层小魔法阵
                      Transform.rotate(
                        angle: _outerCircleController.value * math.pi * 4,
                        child: CustomPaint(
                          size: const Size(220, 220),
                          painter: _MagicCirclePainter(
                            color: const Color(
                              0xFF00BCD4,
                            ).withValues(alpha: 0.6),
                            points: 12,
                            innerRadius: 0.25,
                            outerRadius: 0.9,
                            strokeWidth: 1.0,
                            glowRadius: 4,
                          ),
                        ),
                      ),

                      // 粒子光点
                      ...List.generate(16, (index) {
                        return _PortalParticle(
                          index: index,
                          totalParticles: 16,
                          animation: _particleController,
                          portalSize: 400,
                        );
                      }),

                      // 中心光球
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white,
                              const Color(0xFF00E5FF).withValues(alpha: 0.9),
                              const Color(0xFFE91E63).withValues(alpha: 0.6),
                              const Color(0xFF9C27B0).withValues(alpha: 0.3),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.2, 0.4, 0.7, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF00E5FF,
                              ).withValues(alpha: 0.8),
                              blurRadius: 40,
                              spreadRadius: 15,
                            ),
                            BoxShadow(
                              color: const Color(
                                0xFFE91E63,
                              ).withValues(alpha: 0.5),
                              blurRadius: 60,
                              spreadRadius: 25,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 边缘光晕
              ...List.generate(4, (index) {
                final angle =
                    _ringController.value * math.pi * 2 + (index * math.pi / 2);
                return Transform.translate(
                  offset: Offset(math.cos(angle) * 280, math.sin(angle) * 280),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF9B59B6).withValues(alpha: 0.6),
                          const Color(0xFF9B59B6).withValues(alpha: 0.0),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9B59B6).withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

/// 魔法阵绘制器
class _MagicCirclePainter extends CustomPainter {
  final Color color;
  final int points;
  final double innerRadius;
  final double outerRadius;
  final double strokeWidth;
  final double glowRadius;

  _MagicCirclePainter({
    required this.color,
    required this.points,
    required this.innerRadius,
    required this.outerRadius,
    required this.strokeWidth,
    required this.glowRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerCircleRadius = size.width / 2 * outerRadius;
    final innerCircleRadius = size.width / 2 * innerRadius;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + glowRadius
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius)
      ..blendMode = BlendMode.plus;

    final mainPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;

    // 外圈
    canvas.drawCircle(center, outerCircleRadius, glowPaint);
    canvas.drawCircle(center, outerCircleRadius, mainPaint);

    // 中圈
    canvas.drawCircle(center, outerCircleRadius * 0.75, glowPaint);
    canvas.drawCircle(center, outerCircleRadius * 0.75, mainPaint);

    // 内圈
    canvas.drawCircle(center, innerCircleRadius, glowPaint);
    canvas.drawCircle(center, innerCircleRadius, mainPaint);

    // 星型纹路
    final path = Path();
    for (int i = 0; i <= points * 2; i++) {
      final angle = (i * math.pi) / points;
      final radius = i.isEven ? outerCircleRadius * 0.75 : innerCircleRadius;

      final point = Offset(
        center.dx + radius * math.cos(angle - math.pi / 2),
        center.dy + radius * math.sin(angle - math.pi / 2),
      );

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, mainPaint);

    // 辐射线条
    final linePath = Path();
    for (int i = 0; i < points; i++) {
      final angle = (i * math.pi * 2) / points - math.pi / 2;
      final startPoint = Offset(
        center.dx + innerCircleRadius * math.cos(angle),
        center.dy + innerCircleRadius * math.sin(angle),
      );
      final endPoint = Offset(
        center.dx + outerCircleRadius * 0.75 * math.cos(angle),
        center.dy + outerCircleRadius * 0.75 * math.sin(angle),
      );

      linePath.moveTo(startPoint.dx, startPoint.dy);
      linePath.lineTo(endPoint.dx, endPoint.dy);
    }
    canvas.drawPath(linePath, glowPaint);
    canvas.drawPath(linePath, mainPaint);

    // 顶点装饰
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);

    for (int i = 0; i < points; i++) {
      final angle = (i * math.pi * 2) / points - math.pi / 2;
      final point = Offset(
        center.dx + outerCircleRadius * 0.75 * math.cos(angle),
        center.dy + outerCircleRadius * 0.75 * math.sin(angle),
      );
      canvas.drawCircle(point, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MagicCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.points != points ||
        oldDelegate.innerRadius != innerRadius ||
        oldDelegate.outerRadius != outerRadius;
  }
}

/// 脉冲光环绘制器
class _PulseRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _PulseRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + i * 0.33) % 1.0;
      final ringRadius = radius * (0.2 + ringProgress * 0.8);
      final alpha = (1.0 - ringProgress) * 0.4;

      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..blendMode = BlendMode.plus;

      canvas.drawCircle(center, ringRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulseRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// 传送门粒子
class _PortalParticle extends StatelessWidget {
  final int index;
  final int totalParticles;
  final AnimationController animation;
  final double portalSize;

  const _PortalParticle({
    required this.index,
    required this.totalParticles,
    required this.animation,
    required this.portalSize,
  });

  @override
  Widget build(BuildContext context) {
    final baseAngle = (index / totalParticles) * math.pi * 2;
    final randomOffset = (index * 0.7) % 1.0;
    final colors = [
      const Color(0xFF00E5FF),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
    ];
    final color = colors[index % colors.length];

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = (animation.value + randomOffset) % 1.0;
        final angle = baseAngle + progress * math.pi * 0.8;
        final distance = progress * (portalSize / 2 - 40);

        final x = math.cos(angle) * distance;
        final y = math.sin(angle) * distance;

        final particleSize = 3.0 + (1.0 - progress) * 2.5;
        final alpha = (1.0 - progress) * 0.9;

        return Transform.translate(
          offset: Offset(x, y),
          child: Container(
            width: particleSize,
            height: particleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: alpha),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: alpha * 0.8),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 背景星空
class _StarField extends StatelessWidget {
  const _StarField();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.infinite, painter: _StarFieldPainter());
  }
}

class _StarFieldPainter extends CustomPainter {
  final math.Random _random = math.Random(2024);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

    for (int i = 0; i < 120; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      final radius = _random.nextDouble() * 1.5 + 0.5;
      final alpha = _random.nextDouble() * 0.6 + 0.2;

      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // 添加一些彩色星星
    final colors = [
      const Color(0xFF00E5FF),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
    ];

    for (int i = 0; i < 15; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      final color = colors[i % colors.length];

      paint.color = color.withValues(alpha: 0.6);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(x, y), 2, paint);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
