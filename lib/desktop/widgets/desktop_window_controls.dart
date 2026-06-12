import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../core/core.dart';
import 'exit_dialog.dart';
import 'notification/notification_panel.dart';

/// 桌面端自定义窗口控制按钮组件
///
/// 提供窗口最小化和关闭功能：
/// - 消息中心按钮：显示公告和通知
/// - 最小化按钮：将窗口最小化到任务栏
/// - 关闭按钮：显示退出确认对话框
class DesktopWindowControls extends StatefulWidget {
  const DesktopWindowControls({super.key});

  @override
  State<DesktopWindowControls> createState() => _DesktopWindowControlsState();
}

class _DesktopWindowControlsState extends State<DesktopWindowControls> {
  final GlobalKey _bellKey = GlobalKey();
  OverlayEntry? _panelOverlay;

  /// 按当前设置处理关闭主窗口行为
  Future<void> _handleClose(BuildContext context) async {
    await ExitDialog.handleWindowClose(
      context,
      behavior: context.read<SettingsBloc>().state.appExitBehavior,
    );
  }

  /// 显示消息中心面板
  void _showNotificationPanel() {
    if (_panelOverlay != null) {
      _hideNotificationPanel();
      return;
    }

    final renderBox = _bellKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _panelOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideNotificationPanel,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            top: position.dy + size.height + 8,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: NotificationPanel(onClose: _hideNotificationPanel),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_panelOverlay!);
  }

  void _hideNotificationPanel() {
    _panelOverlay?.remove();
    _panelOverlay = null;
  }

  @override
  void dispose() {
    _hideNotificationPanel();
    super.dispose();
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
          // 消息中心按钮（公告+通知）
          BlocBuilder<AnnouncementBloc, AnnouncementState>(
            builder: (context, announcementState) {
              return BlocBuilder<NotificationBloc, NotificationState>(
                builder: (context, notificationState) {
                  final totalUnread =
                      announcementState.unreadCount +
                      notificationState.unreadCount;
                  return _MessageCenterButton(
                    key: _bellKey,
                    unreadCount: totalUnread,
                    onPressed: _showNotificationPanel,
                    isDark: isDark,
                  );
                },
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

/// 消息中心按钮组件（公告+通知）
class _MessageCenterButton extends StatefulWidget {
  final int unreadCount;
  final VoidCallback onPressed;
  final bool isDark;

  const _MessageCenterButton({
    super.key,
    required this.unreadCount,
    required this.onPressed,
    required this.isDark,
  });

  @override
  State<_MessageCenterButton> createState() => _MessageCenterButtonState();
}

class _MessageCenterButtonState extends State<_MessageCenterButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _lastUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _lastUnreadCount = widget.unreadCount;
    if (widget.unreadCount > 0) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_MessageCenterButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 未读数增加时触发动画
    if (widget.unreadCount > _lastUnreadCount) {
      _pulseController.repeat(reverse: true);
    } else if (widget.unreadCount == 0 && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
    _lastUnreadCount = widget.unreadCount;
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
      message: hasUnread ? '${widget.unreadCount} 条未读消息' : '消息中心',
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
                        ? const Color(0xFF0080FF).withValues(alpha: 0.15)
                        : (widget.isDark
                              ? Colors.white12
                              : Colors.black.withValues(alpha: 0.05)))
                  : Colors.transparent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                bottomLeft: Radius.circular(11),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  hasUnread
                      ? Icons.notifications_active
                      : Icons.notifications_outlined,
                  size: 16,
                  color: hasUnread
                      ? const Color(0xFF0080FF)
                      : (widget.isDark
                            ? Colors.white70
                            : const Color(0xFF6B7280)),
                ),
                if (hasUnread)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        final opacity =
                            1.0 - (_pulseAnimation.value - 1.0) / 0.5;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Opacity(
                                opacity: opacity.clamp(0.0, 1.0),
                                child: Container(
                                  width: 18,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF44336),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                              ),
                            ),
                            child!,
                          ],
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF44336),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFF44336,
                              ).withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 14,
                        ),
                        child: Text(
                          widget.unreadCount > 9
                              ? '9+'
                              : '${widget.unreadCount}',
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
          ? (widget.isDark
                ? Colors.white12
                : Colors.black.withValues(alpha: 0.05))
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
                      topLeft: Radius.circular(0),
                      bottomLeft: Radius.circular(0),
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
