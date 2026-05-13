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

    // 如果初始化时已经有数据，直接显示真实卡片，跳过骨架屏
    final hasServerData = widget.server.serverData != null;
    if (hasServerData) {
      _showRealCard = true;
      _hasData = true;
      _controller.value = 1.0; // 直接完成动画
    } else {
      _checkDataAvailability();
      _startTimeoutTimer();
    }
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

    // 如果正在加载且之前从未有过数据，保持骨架屏状态
    // 但如果已经有数据（无感刷新），不回退到骨架屏，避免闪烁
    if (isLoading && !hasServerData && _showRealCard) {
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
    // 还没开始过渡，只渲染骨架屏
    if (!_showRealCard) {
      return ServerListItemSkeleton(
        index: widget.index,
        showShimmer: true,
      );
    }

    // 过渡中或已完成：始终保持完全相同的 widget 树结构
    // 不使用条件渲染（if），确保 ServerListItem 在树中的位置永远不变
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        final animValue = _fadeAnimation.value;
        final isComplete = animValue >= 1.0;
        return Stack(
          children: [
            // 骨架屏淡出（完成后 opacity=0，仍保留在树中维持结构稳定）
            Opacity(
              opacity: isComplete ? 0.0 : 1.0 - animValue,
              child: isComplete
                  ? const SizedBox.shrink() // 动画完成后用轻量占位，释放骨架屏资源
                  : ServerListItemSkeleton(
                      index: widget.index,
                      showShimmer: false,
                    ),
            ),
            // 真实卡片淡入（完成后 opacity=1.0）
            Opacity(
              opacity: animValue,
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
