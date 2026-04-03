import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/bloc/lobby/lobby_bloc.dart';

/// 大厅 Loading 界面
class LobbyLoadingScreen extends StatefulWidget {
  final LobbyState state;

  const LobbyLoadingScreen({super.key, required this.state});

  @override
  State<LobbyLoadingScreen> createState() => _LobbyLoadingScreenState();
}

class _LobbyLoadingScreenState extends State<LobbyLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rotateController;
  late final AnimationController _floatController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _rotateAnimation;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // 脉冲动画：光环呼吸效果
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 旋转动画：六边形轮廓缓慢旋转
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _rotateAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    // 浮动动画：城堡图标微弱上下浮动
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasAssets = widget.state.assets.isReady;
    final hasSnapshot = widget.state.selfUser != null;

    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF475569);
    final ringBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1);

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        color: isDark ? const Color(0xFF0B1120) : const Color(0xFFDDE7F7),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题（带闪烁效果）
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: 0.7 + 0.3 * _pulseAnimation.value,
                    child: child,
                  );
                },
                child: Text(
                  '正在进入大厅',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // 游戏风格进度环
              AnimatedBuilder(
                animation: Listenable.merge([_pulseAnimation, _rotateAnimation]),
                builder: (context, child) {
                  return SizedBox(
                    width: 100,
                    height: 100,
                    child: CustomPaint(
                      painter: _GameStyleRingPainter(
                        progress: _calculateProgress(hasAssets, hasSnapshot),
                        rotation: _rotateAnimation.value,
                        pulse: _pulseAnimation.value,
                        hasAssets: hasAssets,
                        hasSnapshot: hasSnapshot,
                        ringBgColor: ringBgColor,
                      ),
                      child: Center(
                        child: Transform.translate(
                          offset: Offset(0, _floatAnimation.value),
                          child: Icon(
                            hasSnapshot ? Icons.check_circle : Icons.castle,
                            color: textPrimary.withValues(alpha: 0.9),
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),

              // 步骤列表
              _LoadingStepItem(
                icon: Icons.cloud_done_outlined,
                label: '连接大厅',
                done: true,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _LoadingStepItem(
                icon: Icons.collections_outlined,
                label: '加载素材',
                done: hasAssets,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _LoadingStepItem(
                icon: Icons.people_outline,
                label: '获取大厅状态',
                done: hasSnapshot,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              const SizedBox(height: 20),

              // 状态文字
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  widget.state.transientNotice ?? '正在加载大厅数据...',
                  key: ValueKey(widget.state.transientNotice ?? 'loading'),
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateProgress(bool hasAssets, bool hasSnapshot) {
    // 使用更平滑的进度计算
    // 连接: 0-15% (已完成的固定值)
    // 素材: 15-55% (加载中逐渐增长)
    // 快照: 55-100% (加载中逐渐增长)
    if (hasSnapshot) return 1.0;
    if (hasAssets) {
      // 素材加载完成后，模拟快照加载过程
      return 0.6 + 0.4 * _simulateSnapshotProgress();
    }
    // 素材加载中，模拟素材加载过程
    return 0.15 + 0.4 * _simulateAssetsProgress();
  }

  double _simulateAssetsProgress() {
    // 基于时间模拟素材加载进度（0-1）
    // 假设素材加载需要约 2 秒
    return 0.7; // 默认返回 70%，让进度看起来更平滑
  }

  double _simulateSnapshotProgress() {
    // 基于时间模拟快照加载进度（0-1）
    // 假设快照加载需要约 1 秒
    return 0.85; // 默认返回 85%，让进度看起来更平滑
  }
}

/// 单个加载步骤项
class _LoadingStepItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  final Color textPrimary;
  final Color textSecondary;

  const _LoadingStepItem({
    required this.icon,
    required this.label,
    required this.done,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                  : textSecondary.withValues(alpha: 0.08),
            ),
            child: Icon(
              done ? Icons.check : icon,
              color: done ? const Color(0xFF22C55E) : textSecondary,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: done ? textPrimary : textSecondary,
              fontSize: 14,
              fontWeight: done ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// 游戏风格进度环画笔：六边形旋转轮廓 + 脉冲光环 + 渐变进度弧
class _GameStyleRingPainter extends CustomPainter {
  final double progress;
  final double rotation;
  final double pulse;
  final bool hasAssets;
  final bool hasSnapshot;
  final Color ringBgColor;

  _GameStyleRingPainter({
    required this.progress,
    required this.rotation,
    required this.pulse,
    required this.hasAssets,
    required this.hasSnapshot,
    required this.ringBgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // 绘制脉冲外环
    final glowPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.15 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius + 6 + pulse * 4, glowPaint);

    // 绘制六边形轮廓（旋转）
    _drawHexagonRing(canvas, center, radius);

    // 绘制背景圆环
    final bgPaint = Paint()
      ..color = ringBgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, bgPaint);

    // 绘制进度弧线
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -1.57,
          endAngle: 4.71,
          colors: [
            const Color(0xFF38BDF8),
            hasSnapshot ? const Color(0xFF22C55E) : const Color(0xFF38BDF8),
            const Color(0xFF38BDF8).withValues(alpha: 0.1),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.57,
        progress * 6.28,
        false,
        progressPaint,
      );
    }
  }

  void _drawHexagonRing(Canvas canvas, Offset center, double radius) {
    final hexPaint = Paint()
      ..color = ringBgColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = rotation + (i * math.pi / 3);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, hexPaint);

    // 绘制顶点装饰
    final dotPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.8 * pulse)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 6; i++) {
      final angle = rotation + (i * math.pi / 3);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 2 * pulse, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GameStyleRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rotation != rotation ||
        oldDelegate.pulse != pulse ||
        oldDelegate.hasSnapshot != hasSnapshot;
  }
}
