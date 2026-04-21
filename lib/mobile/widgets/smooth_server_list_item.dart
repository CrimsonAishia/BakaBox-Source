import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/core.dart';
import 'server_list_item.dart';
import 'server_list_item_skeleton.dart';

class SmoothServerListItem extends StatefulWidget {
  final ExtendedServerItem server;
  final int index;
  final VoidCallback? onTap;

  const SmoothServerListItem({
    super.key,
    required this.server,
    required this.index,
    this.onTap,
  });

  @override
  State<SmoothServerListItem> createState() => _SmoothServerListItemState();
}

class _SmoothServerListItemState extends State<SmoothServerListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  bool _showRealCard = false;
  bool _hasData = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _checkDataAvailability();
    _startTimeoutTimer();
  }

  @override
  void didUpdateWidget(SmoothServerListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkDataAvailability();
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_showRealCard) {
        _transitionToReal();
      }
    });
  }

  void _transitionToReal() {
    if (!mounted || _showRealCard) return;
    setState(() => _showRealCard = true);
    _controller.forward();
  }

  void _checkDataAvailability() {
    final hasServerData = widget.server.serverData != null;
    final isLoading = widget.server.isLoading;

    // 如果正在加载，重置为骨架屏状态
    if (isLoading && _showRealCard) {
      setState(() {
        _showRealCard = false;
        _hasData = false;
      });
      _controller.reset();
      _startTimeoutTimer();
      return;
    }

    final shouldShowReal = hasServerData && !isLoading;

    if (shouldShowReal && !_hasData) {
      _hasData = true;
      _timeoutTimer?.cancel();

      // 缩短交错延迟，最多 cap 在 500ms
      final delay = (50 + (widget.index * 50)).clamp(50, 500);
      _timeoutTimer = Timer(Duration(milliseconds: delay), () {
        if (mounted) {
          _transitionToReal();
        }
      });
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 动画完成后，只渲染真实卡片，彻底移除骨架屏
    if (_showRealCard && _controller.isCompleted) {
      return ServerListItem(
        server: widget.server,
        onTap: widget.onTap,
      );
    }

    // 还没开始过渡，只渲染骨架屏
    if (!_showRealCard) {
      return ServerListItemSkeleton(
        index: widget.index,
        showShimmer: true,
      );
    }

    // 过渡中：用 AnimatedBuilder 做简单的交叉淡入
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // 骨架屏淡出
            if (_fadeAnimation.value < 1.0)
              Opacity(
                opacity: 1.0 - _fadeAnimation.value,
                child: ServerListItemSkeleton(
                  index: widget.index,
                  showShimmer: false, // 过渡中关闭 shimmer
                ),
              ),
            // 真实卡片淡入
            Opacity(
              opacity: _fadeAnimation.value,
              child: child,
            ),
          ],
        );
      },
      child: ServerListItem(
        server: widget.server,
        onTap: widget.onTap,
      ),
    );
  }
}
