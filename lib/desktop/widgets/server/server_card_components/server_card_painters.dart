import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../../../core/constants/app_colors.dart';

class ServerCardMarchingAntsPainter extends CustomPainter {
  final double progress;
  final double borderRadius;

  ServerCardMarchingAntsPainter({
    required this.progress,
    required this.borderRadius,
  });

  // 挤服主题色：绿色
  static const _primaryColor = AppColors.green500;
  static const _glowColor = Color(0xFF4ADE80);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final path = Path()..addRRect(rrect);
    final pathMetrics = path.computeMetrics().first;
    final totalLength = pathMetrics.length;

    // 脉冲效果（呼吸感）
    final pulse = (0.5 + 0.5 * (progress * 2 * 3.14159).abs() % 1).clamp(
      0.3,
      1.0,
    );

    // 1. 绘制底层发光边框（整圈微弱发光）
    final baseGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..color = _primaryColor.withValues(alpha: 0.2 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, baseGlowPaint);

    // 2. 绘制底层实线边框
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = _primaryColor.withValues(alpha: 0.5);
    canvas.drawPath(path, basePaint);

    // 3. 绘制两道对向流光（更有动感）
    _drawFlowingLight(canvas, pathMetrics, totalLength, progress);
    _drawFlowingLight(canvas, pathMetrics, totalLength, (progress + 0.5) % 1.0);
  }

  void _drawFlowingLight(
    Canvas canvas,
    ui.PathMetric pathMetrics,
    double totalLength,
    double prog,
  ) {
    const glowLength = 100.0;
    const tailLength = 150.0;

    final headPosition = prog * totalLength;

    // 绘制拖尾
    for (var i = 0.0; i < tailLength; i += 3) {
      var pos = headPosition - i;
      if (pos < 0) pos += totalLength;

      final alpha = (1 - i / tailLength).clamp(0.0, 1.0) * 0.5;
      final width = 3.0 * (1 - i / tailLength).clamp(0.3, 1.0);

      final segmentEnd = (pos + 4).clamp(0.0, totalLength);
      if (segmentEnd > pos) {
        final tailPath = pathMetrics.extractPath(pos, segmentEnd);
        final tailPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = _glowColor.withValues(alpha: alpha);
        canvas.drawPath(tailPath, tailPaint);
      }
    }

    // 绘制流光头部
    final glowStart = headPosition;
    var glowEnd = headPosition + glowLength;

    // 处理循环
    if (glowEnd > totalLength) {
      // 绘制到末尾
      final path1 = pathMetrics.extractPath(glowStart, totalLength);
      _drawGlowSegment(canvas, path1);
      // 从头开始
      final path2 = pathMetrics.extractPath(0, glowEnd - totalLength);
      _drawGlowSegment(canvas, path2);
    } else {
      final glowPath = pathMetrics.extractPath(glowStart, glowEnd);
      _drawGlowSegment(canvas, glowPath);
    }
  }

  void _drawGlowSegment(Canvas canvas, Path glowPath) {
    // 外层大发光
    final outerGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..color = _primaryColor.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(glowPath, outerGlow);

    // 中层发光
    final midGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..color = _glowColor.withValues(alpha: 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(glowPath, midGlow);

    // 核心亮线
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withValues(alpha: 0.95);
    canvas.drawPath(glowPath, core);
  }

  @override
  bool shouldRepaint(ServerCardMarchingAntsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class ServerCardWarmupMarchingAntsPainter extends CustomPainter {
  final double progress;
  final double borderRadius;

  ServerCardWarmupMarchingAntsPainter({
    required this.progress,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final path = Path()..addRRect(rrect);

    // 绘制底层暗色实线边框，保证卡片轮廓始终清晰
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white.withValues(alpha: 0.1);
    canvas.drawPath(path, basePaint);

    // 定义彩虹彗星的 SweepGradient
    // SweepGradient 会以卡片中心为圆心进行角度扫描
    // 这里颜色的排布为：透明 -> 紫 -> 蓝 -> 绿 -> 黄 -> 橙红 (头部) -> 纯白 (高光点) -> 立刻变透明
    final gradient = SweepGradient(
      colors: const [
        Color(0x00000000), // 尾部完全透明
        Color(0xFF8A2BE2), // 尾部深紫
        Color(0xFF4488FF), // 蓝
        Color(0xFF44FF44), // 绿
        Color(0xFFFFDD44), // 黄
        Color(0xFFFF4444), // 头部红
        Color(0xFFFFFFFF), // 头部核心高光（纯白）
        Color(0x00000000), // 头部之后立刻截断透明
      ],
      stops: const [
        0.0,
        0.3,
        0.5,
        0.7,
        0.85,
        0.98,
        1.0,
        1.0,
      ],
      // 利用 progress (0.0 -> 1.0) 旋转整个渐变矩阵
      transform: GradientRotation(progress * 2 * 3.1415926535),
    );

    final shader = gradient.createShader(rect);

    // 1. 发光层：仅保留单层中等模糊，大幅降低 GPU MaskFilter 的渲染开销
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0)
      ..shader = shader;
    canvas.drawPath(path, glow);

    // 2. 核心亮线（彗星本体）
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = shader;
    canvas.drawPath(path, core);
  }

  @override
  bool shouldRepaint(ServerCardWarmupMarchingAntsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class ServerCardDashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Popover 箭头指针绘制器
///
/// [pointingRight] 为 true 表示箭头指向右侧（popover 显示在卡片左侧时使用），
/// 反之指向左侧（popover 显示在卡片右侧时使用）。
class ServerCardPopoverArrowPainter extends CustomPainter {
  final bool pointingRight;
  final Color fillColor;
  final Color borderColor;

  ServerCardPopoverArrowPainter({
    required this.pointingRight,
    required this.fillColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final midY = h / 2;

    final path = Path();
    if (pointingRight) {
      // 三角形顶点指向右侧（卡片在右）
      path.moveTo(0, 0);
      path.lineTo(w, midY);
      path.lineTo(0, h);
      path.close();
    } else {
      // 三角形顶点指向左侧（卡片在左）
      path.moveTo(w, 0);
      path.lineTo(0, midY);
      path.lineTo(w, h);
      path.close();
    }

    // 填充（与面板背景同色，营造融为一体的感觉）
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;
    canvas.drawPath(path, fillPaint);

    // 描边：仅画两条斜边，与面板侧边接缝处不画线，避免破坏融合感
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = borderColor;

    if (pointingRight) {
      canvas.drawLine(const Offset(0, 0), Offset(w, midY), borderPaint);
      canvas.drawLine(Offset(w, midY), Offset(0, h), borderPaint);
    } else {
      canvas.drawLine(Offset(w, 0), Offset(0, midY), borderPaint);
      canvas.drawLine(Offset(0, midY), Offset(w, h), borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ServerCardPopoverArrowPainter oldDelegate) {
    return oldDelegate.pointingRight != pointingRight ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor;
  }
}
