import 'dart:async';
import 'package:flutter/material.dart';

class CountdownProgressBar extends StatefulWidget {
  final int duration;
  final VoidCallback? onComplete;
  final bool isActive;

  const CountdownProgressBar({
    super.key,
    this.duration = 30,
    this.onComplete,
    this.isActive = true,
  });

  @override
  State<CountdownProgressBar> createState() => _CountdownProgressBarState();
}

class _CountdownProgressBarState extends State<CountdownProgressBar> {
  Timer? _timer;
  int _remaining = 0;
  bool _isRefreshing = false; // 内部管理的刷新状态

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
          _triggerRefresh();
        }
      });
    });
  }

  void _triggerRefresh() {
    _isRefreshing = true;
    _remaining = widget.duration;
    widget.onComplete?.call();

    // 1秒后结束刷新动画
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _remaining = widget.duration - 1;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _isRefreshing ? 0.0 : _remaining / widget.duration;

    return SizedBox(
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
                      _remaining <= 5 ? Colors.orange : const Color(0xFF0080FF),
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
                  : const Color(0xFF0080FF),
            ),
          ),
        ],
      ),
    );
  }
}
