import 'dart:async';
import 'package:flutter/material.dart';

/// 紧凑版刷新进度指示器
class CompactRefreshProgress extends StatefulWidget {
  final int refreshInterval;
  final bool isRefreshing;
  final int resetKey;
  final VoidCallback? onRefresh;

  const CompactRefreshProgress({
    super.key,
    this.refreshInterval = 15,
    this.isRefreshing = false,
    this.resetKey = 0,
    this.onRefresh,
  });

  @override
  State<CompactRefreshProgress> createState() => _CompactRefreshProgressState();
}

class _CompactRefreshProgressState extends State<CompactRefreshProgress> {
  Timer? _timer;
  int _remaining = 0;
  int _lastResetKey = 0;

  @override
  void initState() {
    super.initState();
    _remaining = widget.refreshInterval;
    _lastResetKey = widget.resetKey;
    _startTimer();
  }

  @override
  void didUpdateWidget(CompactRefreshProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    // resetKey 变化时重置倒计时
    if (widget.resetKey != _lastResetKey) {
      _lastResetKey = widget.resetKey;
      _reset();
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
      if (!mounted || widget.isRefreshing) return;
      if (_remaining <= 0) return; // 已经触发刷新，等待 resetKey 变化
      
      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          _remaining = 0;
          widget.onRefresh?.call();
        }
      });
    });
  }

  void _reset() {
    setState(() => _remaining = widget.refreshInterval);
  }

  void _manualRefresh() {
    if (widget.isRefreshing || _remaining <= 0) return;
    setState(() => _remaining = 0);
    widget.onRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    final showRefreshing = widget.isRefreshing || _remaining <= 0;
    final progress = showRefreshing ? 0.0 : _remaining / widget.refreshInterval;

    return MouseRegion(
      cursor: showRefreshing ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: showRefreshing ? null : _manualRefresh,
        child: Tooltip(
          message: showRefreshing ? '刷新中...' : '点击立即刷新',
          child: SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 背景圆环
                SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(Colors.grey.withValues(alpha: 0.2)),
                  ),
                ),
                // 进度圆环
                SizedBox(
                  width: 38,
                  height: 38,
                  child: showRefreshing
                      ? const CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(Color(0xFFF0A020)),
                        )
                      : CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3,
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF18A058)),
                        ),
                ),
                // 文字
                Text(
                  showRefreshing ? '...' : '$_remaining',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: showRefreshing ? const Color(0xFFF0A020) : const Color(0xFF18A058),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
