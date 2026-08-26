import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  bool _isPanelOpen = false;

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
    if (mounted) setState(() => _isPanelOpen = true);
  }

  void _hideNotificationPanel() {
    _panelOverlay?.remove();
    _panelOverlay = null;
    if (mounted) setState(() => _isPanelOpen = false);
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
          color: AppColors.primary.withValues(alpha: 0.2),
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
                    panelIsOpen: _isPanelOpen,
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
  final bool panelIsOpen;

  const _MessageCenterButton({
    super.key,
    required this.unreadCount,
    required this.onPressed,
    required this.isDark,
    this.panelIsOpen = false,
  });

  @override
  State<_MessageCenterButton> createState() => _MessageCenterButtonState();
}

class _MessageCenterButtonState extends State<_MessageCenterButton>
    with TickerProviderStateMixin, WindowListener {
  bool _isHovered = false;
  late AnimationController _pulseController;
  late AnimationController _bubbleIconController;
  late Animation<double> _pulseAnimation;
  int _lastUnreadCount = 0;
  int _dismissedUnreadCount = 0;

  bool get _hasUnread => widget.unreadCount > 0;
  bool get _shouldShowConstantly =>
      _hasUnread && widget.unreadCount > _dismissedUnreadCount;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _bubbleIconController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _lastUnreadCount = widget.unreadCount;
    if (widget.unreadCount > 0) {
      _checkFocusAndPlay();
    }
  }

  @override
  void didUpdateWidget(_MessageCenterButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.unreadCount > _lastUnreadCount) {
      _dismissedUnreadCount = 0;
      _checkFocusAndPlay();
    } else if (widget.unreadCount == 0) {
      _dismissedUnreadCount = 0;
      _pulseController.stop();
      _pulseController.reset();
      _bubbleIconController.stop();
      _bubbleIconController.reset();
    }

    _lastUnreadCount = widget.unreadCount;
  }

  Future<void> _checkFocusAndPlay() async {
    final isFocused = await windowManager.isFocused();
    if (mounted && isFocused && _hasUnread) {
      _pulseController.repeat(reverse: true);
      _bubbleIconController.repeat(reverse: true);
    } else if (mounted && !isFocused) {
      _pulseController.stop();
      _bubbleIconController.stop();
    }
  }

  @override
  void onWindowFocus() {
    if (mounted && _hasUnread) {
      _pulseController.repeat(reverse: true);
      _bubbleIconController.repeat(reverse: true);
    }
  }

  @override
  void onWindowBlur() {
    if (mounted) {
      _pulseController.stop();
      _bubbleIconController.stop();
    }
  }

  void _onCloseTooltip() {
    setState(() {
      _dismissedUnreadCount = widget.unreadCount;
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _pulseController.dispose();
    _bubbleIconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _hasUnread;
    // 面板打开时隐藏气泡，避免箭头从面板上方露出造成视觉冲突
    final showBubble =
        (_shouldShowConstantly || _isHovered) && !widget.panelIsOpen;

    return PortalTarget(
      visible: showBubble,
      anchor: const Aligned(
        follower: Alignment.topCenter,
        target: Alignment.bottomCenter,
      ),
      portalFollower: Material(
        color: Colors.transparent,
        child: _buildBubble(),
      ),
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
        },
        onExit: (_) {
          setState(() => _isHovered = false);
        },
        child: GestureDetector(
          onTap: () {
            if (_shouldShowConstantly) {
              setState(() {
                _dismissedUnreadCount = widget.unreadCount;
              });
            }
            widget.onPressed();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44,
            height: 36,
            decoration: BoxDecoration(
              color: _isHovered
                  ? (hasUnread
                        ? AppColors.primary.withValues(alpha: 0.15)
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
                      ? AppColors.primary
                      : (widget.isDark ? Colors.white70 : AppColors.gray500),
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

  Widget _buildBubble() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipPath(
          clipper: _UpArrowClipper(),
          child: Container(
            width: 10,
            height: 6,
            color: _hasUnread
                ? AppColors.primary
                : (widget.isDark ? const Color(0xFF2D2D2D) : Colors.white),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _hasUnread
                ? AppColors.primary
                : (widget.isDark ? const Color(0xFF2D2D2D) : Colors.white),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 12,
            right: _shouldShowConstantly ? 6 : 12,
            top: 8,
            bottom: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasUnread) ...[
                const Icon(
                      Icons.mark_email_unread_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                    .animate(controller: _bubbleIconController, autoPlay: false)
                    .moveY(
                      begin: -1.5,
                      end: 1.5,
                      duration: 1000.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(width: 6),
              ],
              Text(
                _hasUnread ? '您有 ${widget.unreadCount} 条未读消息' : '消息中心',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: _hasUnread ? FontWeight.w600 : FontWeight.w500,
                  color: _hasUnread
                      ? Colors.white
                      : (widget.isDark ? Colors.white : Colors.black87),
                  letterSpacing: 0.2,
                ),
              ),
              if (_shouldShowConstantly) ...[
                const SizedBox(width: 8),
                _TooltipCloseButton(onTap: _onCloseTooltip),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _UpArrowClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _TooltipCloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _TooltipCloseButton({required this.onTap});

  @override
  State<_TooltipCloseButton> createState() => _TooltipCloseButtonState();
}

class _TooltipCloseButtonState extends State<_TooltipCloseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
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
          : (widget.isDark ? Colors.white70 : AppColors.gray500);
    } else {
      buttonColor = _isHovered
          ? (widget.isDark
                ? Colors.white12
                : Colors.black.withValues(alpha: 0.05))
          : Colors.transparent;
      iconColor = widget.isDark ? Colors.white70 : AppColors.gray500;
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
