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
  late Animation<double> _scaleAnimation;
  
  bool _showRealCard = false;
  bool _hasData = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
      ),
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
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_showRealCard) {
        setState(() => _showRealCard = true);
        _controller.forward();
      }
    });
  }

  void _checkDataAvailability() {
    final hasServerData = widget.server.serverData != null;
    final shouldShowReal = hasServerData;
    
    if (shouldShowReal && !_hasData) {
      _hasData = true;
      _timeoutTimer?.cancel();
      
      _timeoutTimer = Timer(Duration(milliseconds: 200 + (widget.index * 100)), () {
        if (mounted) {
          setState(() => _showRealCard = true);
          _controller.forward();
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
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return ServerListItemSkeleton(
              index: widget.index,
              opacity: _showRealCard ? 1.0 - _fadeAnimation.value : 1.0,
              scale: _showRealCard ? 1.0 - (_fadeAnimation.value * 0.05) : 1.0,
              showShimmer: !_showRealCard,
            );
          },
        ),
        if (_showRealCard)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: ServerListItem(
                    server: widget.server,
                    onTap: widget.onTap,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
