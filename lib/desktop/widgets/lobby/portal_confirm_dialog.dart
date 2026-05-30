import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../../core/models/lobby_models.dart';

/// 传送门确认对话框
class PortalConfirmDialog extends StatefulWidget {
  final LobbyPortal portal;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const PortalConfirmDialog({
    super.key,
    required this.portal,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<PortalConfirmDialog> createState() => _PortalConfirmDialogState();
}

class _PortalConfirmDialogState extends State<PortalConfirmDialog>
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

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

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
    _controller.reverse().then((_) {
      widget.onCancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _rotateController]),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            color: Colors.black.withValues(alpha: 0.6 * _fadeAnimation.value),
            child: Center(
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 380,
                  padding: const EdgeInsets.all(28),
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
                      color: Colors.purpleAccent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purpleAccent.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: Colors.cyanAccent.withValues(alpha: 0.1),
                        blurRadius: 50,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 传送门动画图标
                      _PortalIcon(rotation: _rotateController.value),
                      const SizedBox(height: 20),
                      // 标题
                      Text(
                        '传送门',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.7),
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 目标名称
                      Text(
                        widget.portal.label,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Colors.purpleAccent, blurRadius: 20),
                            Shadow(color: Colors.cyanAccent, blurRadius: 30),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 描述
                      Text(
                        '是否进入？',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // 按钮组
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 取消按钮
                          _DialogButton(
                            label: '取消',
                            onPressed: _handleCancel,
                            isPrimary: false,
                          ),
                          const SizedBox(width: 16),
                          // 确认按钮
                          _DialogButton(
                            label: '确认传送',
                            onPressed: _handleConfirm,
                            isPrimary: true,
                          ),
                        ],
                      ),
                    ],
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

/// 对话框按钮
class _DialogButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _DialogButton({
    required this.label,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            gradient: widget.isPrimary
                ? LinearGradient(
                    colors: _isHovered
                        ? [const Color(0xFF9D4EDD), const Color(0xFF7B2CBF)]
                        : [const Color(0xFF7B2CBF), const Color(0xFF5A189A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.isPrimary
                ? null
                : (_isHovered
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isPrimary
                  ? Colors.purpleAccent.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: _isHovered ? 0.2 : 0.1),
              width: 1,
            ),
            boxShadow: widget.isPrimary && _isHovered
                ? [
                    BoxShadow(
                      color: Colors.purpleAccent.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: widget.isPrimary
                  ? Colors.white
                  : Colors.white.withValues(alpha: _isHovered ? 0.9 : 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

/// 传送门图标动画
class _PortalIcon extends StatelessWidget {
  final double rotation;

  const _PortalIcon({required this.rotation});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
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

    // 保存画布状态
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * math.pi * 2);

    // 外圈魔法阵
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.purpleAccent.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..blendMode = BlendMode.plus;

    // 绘制八芒星外圈
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

    // 内圈魔法阵
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
