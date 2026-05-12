import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/lobby/lobby_bloc.dart';

/// 移动端大厅 Loading 界面
///
/// 复用桌面端 [LobbyLoadingScreen] 的步骤逻辑，适配移动端布局。
class LobbyLoadingScreenMobile extends StatefulWidget {
  final LobbyState state;

  const LobbyLoadingScreenMobile({super.key, required this.state});

  @override
  State<LobbyLoadingScreenMobile> createState() =>
      _LobbyLoadingScreenMobileState();
}

class _LobbyLoadingScreenMobileState extends State<LobbyLoadingScreenMobile>
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

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _rotateAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

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

  List<_LoadingStep> _buildSteps() {
    final phase = widget.state.loadingPhase;
    final connectionStatus = widget.state.connectionStatus;
    final isQueueing = widget.state.isQueueing;
    final steps = <_LoadingStep>[];

    final isConnected = connectionStatus == LobbyConnectionStatus.connected;
    final isReconnecting =
        connectionStatus == LobbyConnectionStatus.reconnecting;
    final isDisconnected =
        connectionStatus == LobbyConnectionStatus.disconnected ||
        connectionStatus == LobbyConnectionStatus.failed;

    // 步骤1：连接大厅
    steps.add(_LoadingStep(
      icon: Icons.cloud_done_outlined,
      label: '连接大厅',
      status: isConnected
          ? _StepStatus.done
          : isDisconnected
              ? _StepStatus.failed
              : (isReconnecting || phase == LobbyLoadingPhase.connecting)
                  ? _StepStatus.loading
                  : _StepStatus.pending,
    ));

    // 步骤1.5：排队（仅在排队时显示）
    if (isQueueing) {
      steps.add(_LoadingStep(
        icon: Icons.hourglass_top,
        label: '排队等待',
        status: _StepStatus.loading,
      ));
    }

    // 步骤2：加载素材
    final hasAssets = _checkAssetsReady();
    _StepStatus assetsStatus;
    if (isQueueing) {
      assetsStatus = _StepStatus.pending;
    } else if (isDisconnected) {
      assetsStatus = hasAssets ? _StepStatus.done : _StepStatus.failed;
    } else if (hasAssets) {
      assetsStatus = _StepStatus.done;
    } else if (phase == LobbyLoadingPhase.loadingAssets ||
        phase == LobbyLoadingPhase.waiting) {
      assetsStatus = _StepStatus.loading;
    } else if (isReconnecting || phase == LobbyLoadingPhase.connecting) {
      assetsStatus = _StepStatus.pending;
    } else {
      assetsStatus = _StepStatus.done;
    }
    steps.add(_LoadingStep(
      icon: Icons.collections_outlined,
      label: '加载素材',
      status: assetsStatus,
    ));

    // 步骤3：获取大厅状态
    final hasSnapshot = widget.state.selfUser != null;
    _StepStatus snapshotStatus;
    if (isQueueing) {
      snapshotStatus = _StepStatus.pending;
    } else if (isDisconnected) {
      snapshotStatus = hasSnapshot ? _StepStatus.done : _StepStatus.failed;
    } else if (hasSnapshot) {
      snapshotStatus = _StepStatus.done;
    } else if (phase == LobbyLoadingPhase.loadingSnapshot) {
      snapshotStatus = _StepStatus.loading;
    } else if (isReconnecting || phase == LobbyLoadingPhase.connecting) {
      snapshotStatus = _StepStatus.pending;
    } else {
      snapshotStatus = _StepStatus.pending;
    }
    steps.add(_LoadingStep(
      icon: Icons.people_outline,
      label: '获取大厅状态',
      status: snapshotStatus,
    ));

    return steps;
  }

  bool _checkAssetsReady() {
    final assets = widget.state.assets;
    return assets.mapConfig != null || assets.sprites.isNotEmpty;
  }

  double _calculateProgress() {
    final steps = _buildSteps();
    final doneCount = steps.where((s) => s.status == _StepStatus.done).length;
    final totalCount = steps.length;
    if (doneCount == 0) return 0.0;
    if (doneCount == totalCount) return 1.0;
    return (doneCount - 1) / totalCount + (0.5 / totalCount);
  }

  String _buildStatusText() {
    final status = widget.state.connectionStatus;
    if (status == LobbyConnectionStatus.disconnected ||
        status == LobbyConnectionStatus.failed) {
      return '连接已断开';
    }
    return widget.state.transientNotice ?? '正在加载大厅数据...';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final steps = _buildSteps();
    final hasSnapshot = steps.last.status == _StepStatus.done;

    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF475569);
    final ringBgColor =
        isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1);

    return Container(
      color: isDark ? const Color(0xFF0B1120) : const Color(0xFFDDE7F7),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                AnimatedBuilder(
                  animation: Listenable.merge(
                      [_pulseAnimation, _rotateAnimation]),
                  builder: (context, child) {
                    return SizedBox(
                      width: 90,
                      height: 90,
                      child: CustomPaint(
                        painter: _MobileRingPainter(
                          progress: _calculateProgress(),
                          rotation: _rotateAnimation.value,
                          pulse: _pulseAnimation.value,
                          hasSnapshot: hasSnapshot,
                          ringBgColor: ringBgColor,
                        ),
                        child: Center(
                          child: Transform.translate(
                            offset: Offset(0, _floatAnimation.value),
                            child: Icon(
                              hasSnapshot ? Icons.check_circle : Icons.castle,
                              color: textPrimary.withValues(alpha: 0.9),
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                for (final step in steps)
                  _LoadingStepItem(
                    step: step,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _buildStatusText(),
                    key: ValueKey(_buildStatusText()),
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ),
                // 连接断开时显示重新连接按钮
                if (widget.state.connectionStatus ==
                        LobbyConnectionStatus.disconnected ||
                    widget.state.connectionStatus ==
                        LobbyConnectionStatus.failed) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 160,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.read<LobbyBloc>().add(const LobbyStarted());
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('重新连接'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 内部模型 & 组件 ────────────────────────────────────────

class _LoadingStep {
  final IconData icon;
  final String label;
  final _StepStatus status;
  const _LoadingStep({
    required this.icon,
    required this.label,
    required this.status,
  });
}

enum _StepStatus { pending, loading, done, failed }

class _LoadingStepItem extends StatelessWidget {
  final _LoadingStep step;
  final Color textPrimary;
  final Color textSecondary;
  const _LoadingStepItem({
    required this.step,
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
          _StepIndicator(status: step.status, textSecondary: textSecondary),
          const SizedBox(width: 12),
          Text(
            step.label,
            style: TextStyle(
              color: step.status == _StepStatus.done
                  ? textPrimary
                  : step.status == _StepStatus.failed
                      ? const Color(0xFFEF4444)
                      : textSecondary,
              fontSize: 14,
              fontWeight: step.status == _StepStatus.done
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final _StepStatus status;
  final Color textSecondary;
  const _StepIndicator({required this.status, required this.textSecondary});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _bgColor,
      ),
      child: _buildIcon(),
    );
  }

  Color get _bgColor {
    switch (status) {
      case _StepStatus.done:
        return const Color(0xFF22C55E).withValues(alpha: 0.2);
      case _StepStatus.loading:
        return const Color(0xFF38BDF8).withValues(alpha: 0.2);
      case _StepStatus.failed:
        return const Color(0xFFEF4444).withValues(alpha: 0.15);
      case _StepStatus.pending:
        return textSecondary.withValues(alpha: 0.08);
    }
  }

  Widget _buildIcon() {
    switch (status) {
      case _StepStatus.done:
        return const Icon(Icons.check, color: Color(0xFF22C55E), size: 16);
      case _StepStatus.loading:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
          ),
        );
      case _StepStatus.failed:
        return const Icon(Icons.close, color: Color(0xFFEF4444), size: 16);
      case _StepStatus.pending:
        return Icon(
          Icons.circle_outlined,
          color: textSecondary.withValues(alpha: 0.5),
          size: 14,
        );
    }
  }
}

/// 移动端进度环画笔（简化版桌面端 _GameStyleRingPainter）
class _MobileRingPainter extends CustomPainter {
  final double progress;
  final double rotation;
  final double pulse;
  final bool hasSnapshot;
  final Color ringBgColor;

  _MobileRingPainter({
    required this.progress,
    required this.rotation,
    required this.pulse,
    required this.hasSnapshot,
    required this.ringBgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // 脉冲外环
    final glowPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.15 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius + 6 + pulse * 4, glowPaint);

    // 背景圆环
    final bgPaint = Paint()
      ..color = ringBgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, bgPaint);

    // 进度弧线
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -1.57,
          endAngle: 4.71,
          colors: [
            const Color(0xFF38BDF8),
            hasSnapshot
                ? const Color(0xFF22C55E)
                : const Color(0xFF38BDF8),
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

    // 六边形顶点装饰
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
  bool shouldRepaint(covariant _MobileRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rotation != rotation ||
        oldDelegate.pulse != pulse ||
        oldDelegate.hasSnapshot != hasSnapshot;
  }
}
