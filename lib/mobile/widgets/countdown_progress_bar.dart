import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class CountdownProgressBar extends StatefulWidget {
  final int duration;
  final VoidCallback? onComplete;

  /// 手动点击刷新时的回调（用于强制刷新）
  final VoidCallback? onForceRefresh;
  final bool isActive;

  /// 外部传入的刷新状态，用于同步 Bloc 的实际刷新状态
  final bool isRefreshing;

  const CountdownProgressBar({
    super.key,
    this.duration = 30,
    this.onComplete,
    this.onForceRefresh,
    this.isActive = true,
    this.isRefreshing = false,
  });

  @override
  State<CountdownProgressBar> createState() => _CountdownProgressBarState();
}

class _CountdownProgressBarState extends State<CountdownProgressBar> {
  Timer? _timer;
  int _remaining = 0;
  bool _internalRefreshing = false; // 内部刷新动画状态

  /// 实际的刷新状态：内部动画状态 或 外部传入的刷新状态
  bool get _isRefreshing => _internalRefreshing || widget.isRefreshing;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
    if (widget.isActive) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(CountdownProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // duration 变化时重新计算
    if (widget.duration != oldWidget.duration) {
      _remaining = widget.duration;
    }

    // isActive 变化时启动或停止
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startTimer();
      } else {
        _timer?.cancel();
      }
    }

    // 外部刷新状态从 true 变为 false 时，重置倒计时
    if (oldWidget.isRefreshing && !widget.isRefreshing) {
      setState(() {
        _internalRefreshing = false;
        _remaining = widget.duration;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !widget.isActive || _isRefreshing) return;

      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          _triggerRefresh(isManual: false);
        }
      });
    });
  }

  void _triggerRefresh({required bool isManual}) {
    _internalRefreshing = true;
    _remaining = widget.duration;

    // 手动刷新使用强制刷新，自动刷新使用普通刷新
    if (isManual && widget.onForceRefresh != null) {
      widget.onForceRefresh!();
    } else {
      widget.onComplete?.call();
    }

    // 1秒后结束刷新动画
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _internalRefreshing = false;
        });
      }
    });
  }

  void _manualRefresh() {
    if (_isRefreshing) return;
    _triggerRefresh(isManual: true);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final progress = _isRefreshing ? 0.0 : _remaining / widget.duration;

    return GestureDetector(
      onTap: _isRefreshing ? null : _manualRefresh,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: _isRefreshing
                  ? const CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    )
                  : CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      backgroundColor: const Color(
                        0xFF0080FF,
                      ).withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _remaining <= 5
                            ? Colors.orange
                            : AppColors.primary,
                      ),
                    ),
            ),
            Text(
              _isRefreshing ? '...' : '$_remaining',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _remaining <= 5 || _isRefreshing
                    ? Colors.orange
                    : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
