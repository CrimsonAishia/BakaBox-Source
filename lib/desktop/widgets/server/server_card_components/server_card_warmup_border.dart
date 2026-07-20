import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'server_card_painters.dart';

/// 独立的服务器热身动画边框组件
/// 该组件接管跑马灯动画的生命周期，通过 Ticker (AnimationController) 自动检查是否已经超过绝对结束时间 [endTime]。
/// 因为使用的是 Ticker，所以在程序失去焦点/最小化时会自动暂停检查，唤醒时自动恢复，完美规避休眠时间差导致的状态残留。
class ServerCardWarmupBorder extends StatefulWidget {
  final DateTime? endTime;

  const ServerCardWarmupBorder({super.key, this.endTime});

  @override
  State<ServerCardWarmupBorder> createState() => _ServerCardWarmupBorderState();
}

class _ServerCardWarmupBorderState extends State<ServerCardWarmupBorder>
    with SingleTickerProviderStateMixin, WindowListener {
  late final AnimationController _controller;
  bool _isVisible = false;
  bool _isWindowFocused = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _controller.addListener(_onTick);
    _initFocusState();
  }

  Future<void> _initFocusState() async {
    _isWindowFocused = await windowManager.isFocused();
    if (mounted) {
      _checkVisibility();
    }
  }

  @override
  void onWindowFocus() {
    _isWindowFocused = true;
    _checkVisibility();
  }

  @override
  void onWindowBlur() {
    _isWindowFocused = false;
    _hide();
  }

  @override
  void didUpdateWidget(ServerCardWarmupBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endTime != widget.endTime) {
      _checkVisibility();
    }
  }

  void _checkVisibility() {
    if (!_isWindowFocused) {
      _hide();
      return;
    }

    final endTime = widget.endTime;
    if (endTime == null) {
      _hide();
      return;
    }

    if (DateTime.now().isBefore(endTime)) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      if (!_isVisible) {
        setState(() => _isVisible = true);
      }
    } else {
      _hide();
    }
  }

  /// 每一帧刷新时触发，用于实时检查是否越过了结束边界
  void _onTick() {
    final endTime = widget.endTime;
    if (endTime != null && DateTime.now().isAfter(endTime)) {
      _hide();
    }
  }

  void _hide() {
    if (_controller.isAnimating) {
      _controller.stop();
    }
    if (_isVisible && mounted) {
      setState(() => _isVisible = false);
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: ServerCardWarmupMarchingAntsPainter(
              progress: _controller.value,
              borderRadius: 6,
            ),
          );
        },
      ),
    );
  }
}
