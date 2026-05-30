import 'package:flutter/material.dart';

import '../../../core/bloc/lobby/lobby_bloc.dart';

/// 状态横幅组件
class LobbyStatusBanner extends StatefulWidget {
  final String message;
  final LobbyConnectionStatus connectionStatus;

  const LobbyStatusBanner({
    super.key,
    required this.message,
    required this.connectionStatus,
  });

  @override
  State<LobbyStatusBanner> createState() => _LobbyStatusBannerState();
}

class _LobbyStatusBannerState extends State<LobbyStatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 重连状态下启用脉冲动画
    if (widget.connectionStatus == LobbyConnectionStatus.reconnecting) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LobbyStatusBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 连接状态变化时更新动画
    if (widget.connectionStatus == LobbyConnectionStatus.reconnecting) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (widget.connectionStatus) {
      LobbyConnectionStatus.connected => const Color(0xFF22C55E),
      LobbyConnectionStatus.connecting => const Color(0xFF38BDF8),
      LobbyConnectionStatus.reconnecting => const Color(0xFFF59E0B),
      LobbyConnectionStatus.failed => const Color(0xFFEF4444),
      LobbyConnectionStatus.disconnected => const Color(0xFF94A3B8),
    };

    // 重连状态显示特殊图标和文字
    final bool isReconnecting =
        widget.connectionStatus == LobbyConnectionStatus.reconnecting;
    final IconData icon = isReconnecting ? Icons.sync : Icons.wifi_tethering;
    final String displayMessage = isReconnecting
        ? '正在重新连接大厅... ${widget.message}'
        : widget.message;

    Widget content = Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent.withValues(alpha: isReconnecting ? 0.9 : 0.75),
          ),
          boxShadow: isReconnecting
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                displayMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isReconnecting) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    accent.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // 重连状态添加脉冲效果
    if (isReconnecting) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: 0.85 + 0.15 * _pulseAnimation.value,
            child: child,
          );
        },
        child: content,
      );
    }

    return content;
  }
}
