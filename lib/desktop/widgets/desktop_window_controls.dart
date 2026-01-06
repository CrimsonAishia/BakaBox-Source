import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../core/core.dart';
import 'announcement/announcement_dialog.dart';

/// 桌面端自定义窗口控制按钮组件
/// 
/// 提供窗口最小化和关闭功能：
/// - 公告按钮：显示系统公告
/// - 最小化按钮：将窗口最小化到任务栏 (Requirements 8.1)
/// - 关闭按钮：显示退出确认对话框 (Requirements 8.2)
class DesktopWindowControls extends StatelessWidget {
  const DesktopWindowControls({super.key});

  /// 显示退出确认对话框，用户确认后关闭窗口
  Future<void> _handleClose(BuildContext context) async {
    final result = await ExitDialog.show(context);
    if (result == true) {
      // 先隐藏窗口，用户看到窗口立即消失
      // 然后异步销毁，避免卡顿感
      await windowManager.hide();
      FloatingWindowService().closeAllWindows();
      await windowManager.destroy();
    }
  }

  /// 显示公告对话框
  void _showAnnouncementDialog(BuildContext context) {
    AnnouncementDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF0080FF).withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 公告按钮
          BlocBuilder<AnnouncementBloc, AnnouncementState>(
            builder: (context, state) {
              return _AnnouncementButton(
                unreadCount: state.unreadCount,
                onPressed: () => _showAnnouncementDialog(context),
                isDark: isDark,
              );
            },
          ),
          // 分隔线
          Container(
            width: 1,
            height: 20,
            color: isDark 
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
          ),
          _WindowControlButton(
            icon: MdiIcons.windowMinimize,
            onPressed: () => windowManager.minimize(),
            tooltip: '最小化',
            isDark: isDark,
          ),
          _WindowControlButton(
            icon: MdiIcons.windowClose,
            onPressed: () => _handleClose(context),
            tooltip: '关闭',
            isDark: isDark,
            isCloseButton: true,
          ),
        ],
      ),
    );
  }
}

/// 公告按钮组件
class _AnnouncementButton extends StatefulWidget {
  final int unreadCount;
  final VoidCallback onPressed;
  final bool isDark;

  const _AnnouncementButton({
    required this.unreadCount,
    required this.onPressed,
    required this.isDark,
  });

  @override
  State<_AnnouncementButton> createState() => _AnnouncementButtonState();
}

class _AnnouncementButtonState extends State<_AnnouncementButton> 
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    if (widget.unreadCount > 0) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AnnouncementButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.unreadCount > 0 && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (widget.unreadCount == 0 && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = widget.unreadCount > 0;
    
    return Tooltip(
      message: hasUnread ? '${widget.unreadCount} 条未读公告' : '系统公告',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44,
            height: 36,
            decoration: BoxDecoration(
              color: _isHovered 
                  ? (hasUnread 
                      ? const Color(0xFFFF9800).withValues(alpha: 0.15)
                      : (widget.isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)))
                  : Colors.transparent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                bottomLeft: Radius.circular(11),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 铃铛图标
                Icon(
                  hasUnread ? Icons.notifications_active : Icons.notifications_outlined,
                  size: 16,
                  color: hasUnread 
                      ? const Color(0xFFFF9800)
                      : (widget.isDark ? Colors.white70 : const Color(0xFF6B7280)),
                ),
                // 未读数量角标
                if (hasUnread)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF44336),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF44336).withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                        child: Text(
                          widget.unreadCount > 9 ? '9+' : '${widget.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
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

class _WindowControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool isDark;
  final bool isCloseButton;

  const _WindowControlButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    required this.isDark,
    this.isCloseButton = false,
  });

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color buttonColor;
    Color iconColor;
    
    if (widget.isCloseButton) {
      buttonColor = _isHovered ? const Color(0xFFE81123) : Colors.transparent;
      iconColor = _isHovered 
          ? Colors.white 
          : (widget.isDark ? Colors.white70 : const Color(0xFF6B7280));
    } else {
      buttonColor = _isHovered 
          ? (widget.isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05))
          : Colors.transparent;
      iconColor = widget.isDark ? Colors.white70 : const Color(0xFF6B7280);
    }

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44,
            height: 36,
            decoration: BoxDecoration(
              color: buttonColor,
              borderRadius: widget.isCloseButton 
                  ? const BorderRadius.only(
                      topRight: Radius.circular(11),
                      bottomRight: Radius.circular(11),
                    )
                  : const BorderRadius.only(
                      topLeft: Radius.circular(11),
                      bottomLeft: Radius.circular(11),
                    ),
            ),
            child: Icon(widget.icon, size: 14, color: iconColor),
          ),
        ),
      ),
    );
  }
}

/// 可拖拽的标题栏区域
class DragToMoveArea extends StatelessWidget {
  final Widget child;

  const DragToMoveArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return child;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) => windowManager.startDragging(),
      child: child,
    );
  }
}
