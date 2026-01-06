import 'package:flutter/material.dart';

import 'floating_window_colors.dart';
import 'floating_window_state.dart';

/// 底部进度条 - 全宽显示
class FloatingProgressBar extends StatefulWidget {
  final FloatingWindowState state;
  final bool isCountdownActive;
  final int countdownSeconds;
  final int totalCountdownSeconds;

  const FloatingProgressBar({
    super.key,
    required this.state,
    this.isCountdownActive = false,
    this.countdownSeconds = 0,
    this.totalCountdownSeconds = 5,
  });

  @override
  State<FloatingProgressBar> createState() => _FloatingProgressBarState();
}

class _FloatingProgressBarState extends State<FloatingProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _indeterminateController;

  @override
  void initState() {
    super.initState();
    _indeterminateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(FloatingProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当状态变化时更新动画
    if (oldWidget.state.isTerminal != widget.state.isTerminal ||
        oldWidget.state.isPaused != widget.state.isPaused) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    // 终态或暂停状态时停止动画
    if (widget.state.isTerminal || widget.state.isPaused) {
      _indeterminateController.stop();
    } else {
      _indeterminateController.repeat();
    }
  }

  @override
  void dispose() {
    _indeterminateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = FloatingWindowColors.fromState(widget.state);
    
    // 判断是否应该显示倒计时进度条
    final showCountdown = (widget.state.isTerminal || widget.state.isPaused) && widget.isCountdownActive;
    
    return Container(
      height: 3,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        child: showCountdown
            ? _buildCountdownProgress(color)
            : _buildIndeterminateProgress(color),
      ),
    );
  }

  Widget _buildIndeterminateProgress(Color color) {
    return AnimatedBuilder(
      animation: _indeterminateController,
      builder: (context, child) {
        return CustomPaint(
          painter: _IndeterminateProgressPainter(
            color: color,
            progress: _indeterminateController.value,
          ),
          size: const Size(double.infinity, 3),
        );
      },
    );
  }

  Widget _buildCountdownProgress(Color color) {
    // 计算当前进度：剩余秒数 / 总秒数
    final progress = widget.totalCountdownSeconds > 0
        ? widget.countdownSeconds / widget.totalCountdownSeconds
        : 0.0;
    
    return TweenAnimationBuilder<double>(
      // 每次 countdownSeconds 变化时，key 变化，重新开始动画
      key: ValueKey(widget.countdownSeconds),
      tween: Tween(
        begin: (widget.countdownSeconds + 1) / widget.totalCountdownSeconds,
        end: progress,
      ),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.linear,
      builder: (context, value, child) {
        return FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
          ),
        );
      },
    );
  }
}

/// 不确定进度条绘制器
class _IndeterminateProgressPainter extends CustomPainter {
  final Color color;
  final double progress;

  _IndeterminateProgressPainter({
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 绘制移动的光条
    final barWidth = size.width * 0.3;
    final startX = (size.width + barWidth) * progress - barWidth;
    
    // 创建渐变效果
    final gradient = LinearGradient(
      colors: [
        color.withValues(alpha: 0),
        color,
        color,
        color.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );
    
    final rect = Rect.fromLTWH(startX, 0, barWidth, size.height);
    paint.shader = gradient.createShader(rect);
    
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_IndeterminateProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
