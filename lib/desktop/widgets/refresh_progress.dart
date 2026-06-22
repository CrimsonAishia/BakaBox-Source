import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/services/network_mode_service.dart';

/// 紧凑版刷新进度指示器
class CompactRefreshProgress extends StatefulWidget {
  final int refreshInterval;
  final VoidCallback? onRefresh;

  /// 手动点击刷新时的回调（用于强制刷新，重置所有状态）
  final VoidCallback? onForceRefresh;

  /// 外部传入的刷新状态，用于同步 Bloc 的实际刷新状态
  final bool isRefreshing;

  const CompactRefreshProgress({
    super.key,
    this.refreshInterval = 15,
    this.onRefresh,
    this.onForceRefresh,
    this.isRefreshing = false,
  });

  @override
  State<CompactRefreshProgress> createState() => _CompactRefreshProgressState();
}

class _CompactRefreshProgressState extends State<CompactRefreshProgress> {
  Timer? _timer;
  int _remaining = 0;
  bool _internalRefreshing = false; // 内部刷新动画状态（用于显示短暂的刷新动画）

  /// 监听弱网模式切换，运行时即时启停倒计时
  StreamSubscription<bool>? _networkModeSubscription;

  /// 实际的刷新状态：内部动画状态 或 外部传入的刷新状态
  bool get _isRefreshing => _internalRefreshing || widget.isRefreshing;

  @override
  void initState() {
    super.initState();
    _remaining = widget.refreshInterval;
    _startTimer();

    // 弱网开关切换时即时响应：开启 → 立即停 timer；关闭 → 重启 timer
    _networkModeSubscription = NetworkModeService.instance.changes.listen((
      weakNetwork,
    ) {
      if (!mounted) return;
      if (weakNetwork) {
        _timer?.cancel();
        _timer = null;
        // 触发 UI 重建以切换到「弱网手动刷新」样式
        setState(() {});
      } else {
        // 关闭弱网时：重置倒计时并启动 timer
        _remaining = widget.refreshInterval;
        _startTimer();
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(CompactRefreshProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    // refreshInterval 变化时重新计算
    if (widget.refreshInterval != oldWidget.refreshInterval) {
      _remaining = widget.refreshInterval;
    }

    // 外部刷新状态从 true 变为 false 时，重置倒计时
    // 这确保了当 Bloc 刷新完成后，倒计时从头开始
    // 注意：不重置 _internalRefreshing，由 _triggerRefresh 的 2 秒定时器控制
    if (oldWidget.isRefreshing && !widget.isRefreshing) {
      setState(() {
        _remaining = widget.refreshInterval;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _networkModeSubscription?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    // 弱网模式下不启动倒计时；UI 上仅保留刷新按钮，由用户主动触发
    if (NetworkModeService.instance.weakNetwork) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isRefreshing) return; // 刷新中时跳过

      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          // 自动刷新：使用普通刷新
          _triggerRefresh(isManual: false);
        }
      });
    });
  }

  void _triggerRefresh({required bool isManual}) {
    _internalRefreshing = true;
    _remaining = widget.refreshInterval; // 立即重置

    // 手动刷新使用强制刷新（重置所有状态），自动刷新使用普通刷新
    if (isManual && widget.onForceRefresh != null) {
      widget.onForceRefresh!();
    } else {
      widget.onRefresh?.call();
    }

    // 最短显示 1 秒刷新动画（防止频繁点击），之后由外部 isRefreshing 状态控制
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _internalRefreshing = false;
          // 注意：不在这里重置 _remaining，因为已经在上面重置过了
          // 倒计时会在 Timer 中继续递减
        });
      }
    });
  }

  void _manualRefresh() {
    if (_isRefreshing) return;
    _triggerRefresh(isManual: true);
    setState(() {}); // 触发 UI 更新
  }

  @override
  Widget build(BuildContext context) {
    final isWeakNetwork = NetworkModeService.instance.weakNetwork;
    final progress = _isRefreshing ? 0.0 : _remaining / widget.refreshInterval;

    return MouseRegion(
      cursor: _isRefreshing
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _isRefreshing ? null : _manualRefresh,
        child: Tooltip(
          message: _isRefreshing
              ? '刷新中...'
              : (isWeakNetwork ? '弱网模式：点击手动刷新' : '点击立即刷新'),
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
                    valueColor: AlwaysStoppedAnimation(
                      Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                // 进度圆环（弱网模式下不显示倒计时进度，仅在刷新中时显示动画）
                SizedBox(
                  width: 38,
                  height: 38,
                  child: _isRefreshing
                      ? const CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(Color(0xFFF0A020)),
                        )
                      : (isWeakNetwork
                            ? const SizedBox.shrink()
                            : CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 3,
                                valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFF18A058),
                                ),
                              )),
                ),
                // 文字（弱网模式下显示刷新图标，不再显示倒数秒数）
                _isRefreshing
                    ? const Text(
                        '...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF0A020),
                        ),
                      )
                    : isWeakNetwork
                    ? const Icon(
                        Icons.refresh,
                        size: 18,
                        color: Color(0xFFF0A020),
                      )
                    : Text(
                        '$_remaining',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF18A058),
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
