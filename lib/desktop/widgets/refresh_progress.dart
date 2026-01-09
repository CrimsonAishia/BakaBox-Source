import 'dart:async';
import 'package:flutter/material.dart';

/// 紧凑版刷新进度指示器
class CompactRefreshProgress extends StatefulWidget {
  final int refreshInterval;
  final VoidCallback? onRefresh;

  const CompactRefreshProgress({
    super.key,
    this.refreshInterval = 15,
    this.onRefresh,
  });

  @override
  State<CompactRefreshProgress> createState() => _CompactRefreshProgressState();
}

class _CompactRefreshProgressState extends State<CompactRefreshProgress> {
  Timer? _timer;
  int _remaining = 0;
  bool _isRefreshing = false;  // 内部管理的刷新状态

  @override
  void initState() {
    super.initState();
    _remaining = widget.refreshInterval;
    _startTimer();
  }

  @override
  void didUpdateWidget(CompactRefreshProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    // refreshInterval 变化时重新计算
    if (widget.refreshInterval != oldWidget.refreshInterval) {
      _remaining = widget.refreshInterval;
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
      if (!mounted || _isRefreshing) return;  // 刷新中时跳过
      
      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          // 触发刷新，显示短暂的刷新动画
          _triggerRefresh();
        }
      });
    });
  }

  void _triggerRefresh() {
    _isRefreshing = true;
    _remaining = widget.refreshInterval;  // 立即重置
    widget.onRefresh?.call();
    
    // 1秒后结束刷新动画
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _remaining = widget.refreshInterval - 1;  // 刷新动画占用1秒，所以从14开始
        });
      }
    });
  }

  void _manualRefresh() {
    if (_isRefreshing) return;
    _triggerRefresh();
    setState(() {});  // 触发 UI 更新
  }

  @override
  Widget build(BuildContext context) {
    final progress = _isRefreshing ? 0.0 : _remaining / widget.refreshInterval;

    return MouseRegion(
      cursor: _isRefreshing ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _isRefreshing ? null : _manualRefresh,
        child: Tooltip(
          message: _isRefreshing ? '刷新中...' : '点击立即刷新',
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
                  child: _isRefreshing
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
                  _isRefreshing ? '...' : '$_remaining',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isRefreshing ? const Color(0xFFF0A020) : const Color(0xFF18A058),
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
