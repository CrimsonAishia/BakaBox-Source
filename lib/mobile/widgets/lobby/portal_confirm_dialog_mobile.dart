import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../../core/models/lobby_models.dart';

/// 移动端传送门确认对话框
///
/// 复用桌面端 [PortalConfirmDialog] 的视觉风格，适配触摸交互。
class PortalConfirmDialogMobile extends StatefulWidget {
  final LobbyPortal portal;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const PortalConfirmDialogMobile({
    super.key,
    required this.portal,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<PortalConfirmDialogMobile> createState() =>
      _PortalConfirmDialogMobileState();
}

class _PortalConfirmDialogMobileState extends State<PortalConfirmDialogMobile>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _rotateController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    // 立即触发确认，不等关闭动画，让传送动画和对话框消失同时发生
    widget.onConfirm();
  }

  void _handleCancel() {
    _controller.reverse().then((_) => widget.onCancel());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _rotateController]),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: GestureDetector(
            onTap: _handleCancel,
            behavior: HitTestBehavior.opaque,
            child: Container(
              color:
                  Colors.black.withValues(alpha: 0.6 * _fadeAnimation.value),
              child: Center(
                child: GestureDetector(
                  onTap: () {}, // 阻止点击穿透
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 320,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1a1a2e).withValues(alpha: 0.95),
                            const Color(0xFF16213e).withValues(alpha: 0.95),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color:
                              Colors.purpleAccent.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purpleAccent
                                .withValues(alpha: 0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color:
                                Colors.cyanAccent.withValues(alpha: 0.1),
                            blurRadius: 50,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PortalIconMobile(
                              rotation: _rotateController.value),
                          const SizedBox(height: 16),
                          Text(
                            '传送门',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.7),
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.portal.label,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                    color: Colors.purpleAccent,
                                    blurRadius: 20),
                                Shadow(
                                    color: Colors.cyanAccent,
                                    blurRadius: 30),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '是否进入？',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _MobileDialogButton(
                                  label: '取消',
                                  onPressed: _handleCancel,
                                  isPrimary: false,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MobileDialogButton(
                                  label: '确认传送',
                                  onPressed: _handleConfirm,
                                  isPrimary: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 移动端对话框按钮（触摸友好）
class _MobileDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _MobileDialogButton({
    required this.label,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: isPrimary
                ? const LinearGradient(
                    colors: [Color(0xFF7B2CBF), Color(0xFF5A189A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isPrimary
                ? null
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary
                  ? Colors.purpleAccent.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isPrimary
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

/// 移动端传送门图标（与桌面端一致）
class _PortalIconMobile extends StatelessWidget {
  final double rotation;
  const _PortalIconMobile({required this.rotation});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: CustomPaint(painter: _PortalIconPainter(rotation: rotation)),
    );
  }
}

class _PortalIconPainter extends CustomPainter {
  final double rotation;
  _PortalIconPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 外发光
    final glowPaint = Paint()
      ..color = Colors.purpleAccent.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(center, radius * 0.8, glowPaint);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * math.pi * 2);

    // 外圈八芒星
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.purpleAccent.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..blendMode = BlendMode.plus;

    final outerPath = Path();
    for (int i = 0; i <= 16; i++) {
      final angle = (i * math.pi) / 8;
      final r = i.isEven ? radius * 0.7 : radius * 0.5;
      final x = math.cos(angle - math.pi / 2) * r;
      final y = math.sin(angle - math.pi / 2) * r;
      if (i == 0) {
        outerPath.moveTo(x, y);
      } else {
        outerPath.lineTo(x, y);
      }
    }
    canvas.drawPath(outerPath, outerPaint);

    // 内圈
    canvas.save();
    canvas.rotate(-rotation * math.pi * 4);
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.cyanAccent.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
      ..blendMode = BlendMode.plus;

    final innerPath = Path();
    for (int i = 0; i <= 12; i++) {
      final angle = (i * math.pi) / 6;
      final r = i.isEven ? radius * 0.45 : radius * 0.25;
      final x = math.cos(angle - math.pi / 2) * r;
      final y = math.sin(angle - math.pi / 2) * r;
      if (i == 0) {
        innerPath.moveTo(x, y);
      } else {
        innerPath.lineTo(x, y);
      }
    }
    canvas.drawPath(innerPath, innerPaint);
    canvas.restore();
    canvas.restore();

    // 中心核心
    final coreGradient = ui.Gradient.radial(
      center,
      radius * 0.2,
      [
        Colors.white,
        Colors.cyanAccent,
        Colors.purpleAccent.withValues(alpha: 0),
      ],
      [0.0, 0.5, 1.0],
    );
    final corePaint = Paint()
      ..shader = coreGradient
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, radius * 0.2, corePaint);

    // 中心白点
    final centerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(center, radius * 0.08, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _PortalIconPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}
