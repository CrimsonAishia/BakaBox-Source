import 'dart:async';
import 'package:flutter/material.dart';

class CountdownProgressBar extends StatefulWidget {
  final int duration;
  final VoidCallback? onComplete;
  final bool isActive;
  final int resetKey;

  const CountdownProgressBar({
    super.key,
    this.duration = 30,
    this.onComplete,
    this.isActive = true,
    this.resetKey = 0,
  });

  @override
  State<CountdownProgressBar> createState() => _CountdownProgressBarState();
}

class _CountdownProgressBarState extends State<CountdownProgressBar> {
  Timer? _timer;
  int _remaining = 0;
  int _lastResetKey = 0;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
    _lastResetKey = widget.resetKey;
    if (widget.isActive) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(CountdownProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // resetKey 变化时重置倒计时
    if (widget.resetKey != _lastResetKey) {
      _lastResetKey = widget.resetKey;
      _reset();
      return; // resetKey 变化已处理，不需要再检查 isActive
    }
    
    // isActive 变化时启动或停止（不重置进度）
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        // 恢复时继续之前的进度，不重置
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
      if (!mounted || !widget.isActive) return;
      if (_remaining <= 0) return;
      
      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          _remaining = 0;
          widget.onComplete?.call();
        }
      });
    });
  }

  void _reset() {
    setState(() => _remaining = widget.duration);
    if (widget.isActive) {
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remaining / widget.duration;
    final isRefreshing = _remaining <= 0;

    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: isRefreshing
                ? const CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  )
                : CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: const Color(0xFF0080FF).withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _remaining <= 5 ? Colors.orange : const Color(0xFF0080FF),
                    ),
                  ),
          ),
          Text(
            isRefreshing ? '...' : '$_remaining',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _remaining <= 5 || isRefreshing ? Colors.orange : const Color(0xFF0080FF),
            ),
          ),
        ],
      ),
    );
  }
}
