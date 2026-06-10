import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/services/status_window_service.dart';
import '../../../core/utils/player_count_utils.dart';
import 'warmup_arena_session.dart';
import 'warmup_window.dart';

/// 暖服悬浮卡片 - 显示在主界面右下角
class WarmupFloatingCard extends StatefulWidget {
  const WarmupFloatingCard({super.key});

  @override
  State<WarmupFloatingCard> createState() => _WarmupFloatingCardState();
}

class _WarmupFloatingCardState extends State<WarmupFloatingCard>
    with SingleTickerProviderStateMixin {
  final StatusWindowService _statusService = StatusWindowService();
  StreamSubscription<OperationState>? _subscription;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _isVisible = false;
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.elasticOut,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _subscription = _statusService.stateStream.listen(_onStateChanged);
    _checkInitialState();
  }

  void _checkInitialState() {
    final state = _statusService.state;
    final shouldShow = _shouldShowCard(state);
    if (shouldShow != _isVisible) {
      _isVisible = shouldShow;
      if (_isVisible) {
        _animationController.forward();
      }
    }
  }

  void _onStateChanged(OperationState state) {
    final shouldShow = _shouldShowCard(state);
    if (shouldShow != _isVisible) {
      setState(() {
        _isVisible = shouldShow;
        // 重新显示时恢复展开状态
        if (_isVisible) {
          _isMinimized = false;
        }
      });
      if (_isVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    } else if (_isVisible) {
      setState(() {});
    }
  }

  bool _shouldShowCard(OperationState state) {
    // 只在暖服中且暖服窗口未打开时显示
    return state.type == OperationType.warming &&
        state.status == OperationStatus.running &&
        !_statusService.isWarmupWindowOpen;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _showWarmupDialog() {
    final state = _statusService.state;
    if (state.serverAddress == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: WarmupWindow(
          serverAddress: state.serverAddress!,
          isCustomServer: false,
          serverName: state.serverName,
          initialServerInfo: state.serverInfo,
          initialMapInfo: state.mapInfo,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _stopWarmup() {
    // 停止暖服时清空会话（活动日志、竞技场用户、位置）
    WarmupArenaSession.instance.clear();
    _statusService.pauseWarmup();
  }

  void _toggleMinimize() {
    setState(() {
      _isMinimized = !_isMinimized;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        if (_animationController.value == 0) {
          return const SizedBox.shrink();
        }
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _isMinimized ? _buildMinimizedCard() : _buildCard(),
          ),
        );
      },
    );
  }

  /// 最小化状态的卡片
  Widget _buildMinimizedCard() {
    final state = _statusService.state;
    final players = state.serverInfo?.players ?? 0;
    // 使用统一的颜色（暖黄色）
    const themeColor = Color(0xFFF59E0B);

    return GestureDetector(
      onTap: _toggleMinimize,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: themeColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '暖服中 $players', // 简化的最小化状态显示
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(MdiIcons.chevronUp, size: 16, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    final state = _statusService.state;
    final serverName = state.serverName ?? state.serverAddress ?? '未知服务器';
    final players = state.serverInfo?.players ?? 0;
    final maxPlayers = state.serverInfo?.maxPlayers ?? 0;
    final playerColor = PlayerCountUtils.getPlayerCountColor(
      players,
      maxPlayers,
    );
    const themeColor = Color(0xFFF59E0B); // 暖服的暖黄色主题色

    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: themeColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '暖服中',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // 人数标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: playerColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: playerColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$players / $maxPlayers',
                  style: TextStyle(
                    color: playerColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 最小化按钮
              GestureDetector(
                onTap: _toggleMinimize,
                child: Icon(
                  MdiIcons.chevronDown,
                  size: 18,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 服务器名称
          Text(
            serverName,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          // 操作按钮
          Row(
            children: [
              Expanded(
                child: _buildButton(
                  icon: MdiIcons.eye,
                  label: '查看详情',
                  onTap: _showWarmupDialog,
                  isPrimary: true,
                  themeColor: themeColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildButton(
                  icon: MdiIcons.stop,
                  label: '停止',
                  onTap: _stopWarmup,
                  isPrimary: false,
                  themeColor: themeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
    required Color themeColor,
  }) {
    return Material(
      color: isPrimary ? themeColor : Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isPrimary ? Colors.white : Colors.white70,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
