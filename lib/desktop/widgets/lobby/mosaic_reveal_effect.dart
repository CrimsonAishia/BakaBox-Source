import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 马赛克扫描清除效果
///
/// 显示目标地图（马赛克状态），根据 progress 从左到右逐渐清除马赛克显示清晰地图
class MosaicRevealEffect extends StatefulWidget {
  /// 目标地图内容（会显示为马赛克效果）
  final Widget targetContent;

  /// 目标地图名称
  final String targetName;

  /// 清除进度 0.0-1.0
  final double progress;

  /// 是否显示装饰
  final bool showTouhouDecoration;

  const MosaicRevealEffect({
    super.key,
    required this.targetContent,
    required this.targetName,
    required this.progress,
    this.showTouhouDecoration = false,
  });

  @override
  State<MosaicRevealEffect> createState() => _MosaicRevealEffectState();
}

class _MosaicRevealEffectState extends State<MosaicRevealEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0B1120) : const Color(0xFF0B1120),
      child: Stack(
        children: [
          // 底层：原始清晰地图
          Positioned.fill(child: widget.targetContent),

          // 中层：马赛克遮罩层（从左到右裁剪）
          if (widget.progress < 1.0)
            Positioned.fill(
              child: ClipRect(
                clipper: _LeftToRightRevealClipper(widget.progress),
                child: _MosaicOverlay(
                  glowProgress: _glowController.value,
                  isDark: isDark,
                ),
              ),
            ),

          // 扫描线效果
          if (widget.progress > 0 && widget.progress < 1.0)
            _ScanLineEffect(progress: widget.progress),

          // 顶部渐变遮罩
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 60,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (isDark ? Colors.black : Colors.black).withValues(
                      alpha: 0.6,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 底部信息区域
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomInfoBar(
              targetName: widget.targetName,
              progress: widget.progress,
              isDark: isDark,
            ),
          ),

          // 角落装饰
          if (widget.showTouhouDecoration) ..._buildCornerDecorations(),
        ],
      ),
    );
  }

  List<Widget> _buildCornerDecorations() {
    return [
      // 左上角
      Positioned(
        top: 20,
        left: 20,
        child: _CornerDecoration(angle: 0, glowProgress: _glowController.value),
      ),
      // 右上角
      Positioned(
        top: 20,
        right: 20,
        child: Transform.scale(
          scaleX: -1,
          child: _CornerDecoration(
            angle: 0,
            glowProgress: _glowController.value,
          ),
        ),
      ),
    ];
  }
}

/// 左到右 reveal 裁剪器
class _LeftToRightRevealClipper extends CustomClipper<Rect> {
  final double progress;

  _LeftToRightRevealClipper(this.progress);

  @override
  Rect getClip(Size size) {
    // 马赛克层显示在右边（从左往右逐渐清除马赛克，露出清晰地图）
    // progress=0: 全屏马赛克; progress=1: 无马赛克
    return Rect.fromLTWH(
      size.width * progress, // 左边起点随 progress 移动
      0,
      size.width * (1 - progress), // 宽度逐渐减小
      size.height,
    );
  }

  @override
  bool shouldReclip(_LeftToRightRevealClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}

/// 马赛克覆盖层
class _MosaicOverlay extends StatelessWidget {
  final double glowProgress;
  final bool isDark;

  const _MosaicOverlay({required this.glowProgress, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1F2E).withValues(alpha: 0.9)
            : const Color(0xFF1A1F2E).withValues(alpha: 0.95),
      ),
      child: CustomPaint(
        painter: _MosaicPatternPainter(glowProgress: glowProgress),
      ),
    );
  }
}

/// 马赛克纹理绘制器
class _MosaicPatternPainter extends CustomPainter {
  final double glowProgress;

  _MosaicPatternPainter({required this.glowProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    const blockSize = 12.0;

    // 绘制方块马赛克纹理
    for (double x = 0; x < size.width; x += blockSize) {
      for (double y = 0; y < size.height; y += blockSize) {
        final offset = ((x / blockSize).toInt() + (y / blockSize).toInt()) % 4;
        final alpha = 0.02 + offset * 0.015;
        paint.color = Colors.white.withValues(alpha: alpha);
        canvas.drawRect(
          Rect.fromLTWH(x, y, blockSize - 1, blockSize - 1),
          paint,
        );
      }
    }

    // 绘制扫描光效
    final scanLineY =
        (glowProgress * size.height * 2) % (size.height + 100) - 50;
    final scanPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, scanLineY - 30),
        Offset(0, scanLineY + 30),
        [
          Colors.transparent,
          Colors.cyan.withValues(alpha: 0.15),
          Colors.purple.withValues(alpha: 0.1),
          Colors.transparent,
        ],
        [0.0, 0.4, 0.6, 1.0],
      );
    canvas.drawRect(
      Rect.fromLTWH(0, scanLineY - 30, size.width, 60),
      scanPaint,
    );
  }

  @override
  bool shouldRepaint(_MosaicPatternPainter oldDelegate) {
    return oldDelegate.glowProgress != glowProgress;
  }
}

/// 扫描线效果
class _ScanLineEffect extends StatelessWidget {
  final double progress;

  const _ScanLineEffect({required this.progress});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 扫描线位置在马赛克左边缘
        final scanLineX = constraints.maxWidth * progress;
        return Stack(
          children: [
            // 扫描边界线（马赛克左边缘）
            Positioned(
              left: scanLineX - 2,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.cyan.withValues(alpha: 0.8),
                      Colors.purple.withValues(alpha: 0.6),
                      Colors.cyan.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withValues(alpha: 0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.3),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
            // 边缘光晕
            Positioned(
              left: scanLineX - 30,
              top: 0,
              bottom: 0,
              child: Container(
                width: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.cyan.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 底部信息条
class _BottomInfoBar extends StatelessWidget {
  final String targetName;
  final double progress;
  final bool isDark;

  const _BottomInfoBar({
    required this.targetName,
    required this.progress,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // 调试日志
    debugPrint('[MosaicRevealEffect] _BottomInfoBar: progress=$progress');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.black.withValues(alpha: 0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 目标名称
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.near_me,
                  color: Colors.cyan.withValues(alpha: 0.8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '正在前往 $targetName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    shadows: [Shadow(color: Colors.cyan, blurRadius: 10)],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 进度条
            SizedBox(
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.cyan.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // 百分比
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 角落装饰组件
class _CornerDecoration extends StatelessWidget {
  final double angle;
  final double glowProgress;

  const _CornerDecoration({required this.angle, required this.glowProgress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(60, 60),
      painter: _CornerPainter(glowProgress: glowProgress),
    );
  }
}

/// 角落绘制器
class _CornerPainter extends CustomPainter {
  final double glowProgress;

  _CornerPainter({required this.glowProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path()
      ..moveTo(0, size.height * 0.4)
      ..lineTo(0, 0)
      ..lineTo(size.width * 0.4, 0);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // 添加光点
    final dotPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.5 + glowProgress * 0.3)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawCircle(
      Offset(size.width * 0.4, 0),
      3 + glowProgress * 2,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) {
    return oldDelegate.glowProgress != glowProgress;
  }
}
