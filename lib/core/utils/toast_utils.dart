import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

/// 全局通用提示工具类 - Sonner 风格堆叠效果
class ToastUtils {
  static final List<_ToastEntry> _toastQueue = [];
  static const int _maxVisible = 5;
  static final _hoverNotifier = ValueNotifier<bool>(false);

  // 堆叠参数
  static const double _gapExpanded = 12.0; // 展开时的间距
  static const double _gapCollapsed = 8.0; // 收起时露出的高度
  static const double _scaleStep = 0.05; // 每层缩小比例
  static const double _opacityStep = 0.15; // 每层透明度降低

  // 动态时长参数
  static const int _minDurationSeconds = 5; // 最少显示5秒
  static const int _charsPerSecond = 6; // 每6个字符增加1秒（降速后需要更多时间阅读）

  /// 根据文字长度计算显示时长
  static Duration _calculateDuration(String message) {
    final charCount = message.length;
    final calculatedSeconds = (charCount / _charsPerSecond).ceil();
    // 长文本需要额外时间用于滚动展示
    final scrollBonus = charCount > 30 ? 3 : 0;
    final finalSeconds = (calculatedSeconds + scrollBonus) < _minDurationSeconds 
        ? _minDurationSeconds 
        : (calculatedSeconds + scrollBonus);
    return Duration(seconds: finalSeconds);
  }

  static void showSuccess(BuildContext context, String message,
      {Duration? duration}) {
    _showToast(
      context,
      message,
      const Color(0xFF10B981),
      Colors.white,
      Icons.check_circle_rounded,
      duration ?? _calculateDuration(message),
    );
  }

  static void showError(BuildContext context, String message,
      {Duration? duration}) {
    _showToast(
      context,
      message,
      const Color(0xFFEF4444),
      Colors.white,
      Icons.error_rounded,
      duration ?? _calculateDuration(message),
    );
  }

  static void showWarning(BuildContext context, String message,
      {Duration? duration}) {
    _showToast(
      context,
      message,
      const Color(0xFFF59E0B),
      Colors.white,
      Icons.warning_rounded,
      duration ?? _calculateDuration(message),
    );
  }

  static void showInfo(BuildContext context, String message,
      {Duration? duration}) {
    _showToast(
      context,
      message,
      const Color(0xFF3B82F6),
      Colors.white,
      Icons.info_rounded,
      duration ?? _calculateDuration(message),
    );
  }

  static void showCustom(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    IconData? icon,
    Duration? duration,
  }) {
    _showToast(
      context,
      message,
      backgroundColor ?? const Color(0xFF6B7280),
      Colors.white,
      icon ?? Icons.notifications_rounded,
      duration ?? _calculateDuration(message),
    );
  }

  static void _showToast(
    BuildContext context,
    String message,
    Color backgroundColor,
    Color textColor,
    IconData? icon,
    Duration duration,
  ) {
    // 检查 context 是否有效
    if (!context.mounted) return;
    
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    // 如果超过最大数量，移除最旧的
    if (_toastQueue.length >= _maxVisible) {
      _removeToast(_toastQueue.first);
    }

    late OverlayEntry overlayEntry;
    late _ToastEntry toastEntry;

    final indexNotifier = ValueNotifier<int>(_toastQueue.length);
    final totalNotifier = ValueNotifier<int>(_toastQueue.length + 1);
    final dismissNotifier = ValueNotifier<bool>(false);

    overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        backgroundColor: backgroundColor,
        textColor: textColor,
        icon: icon,
        indexNotifier: indexNotifier,
        totalNotifier: totalNotifier,
        hoverNotifier: _hoverNotifier,
        dismissNotifier: dismissNotifier,
        onRemove: () => _removeToast(toastEntry),
        onHover: (isHovered) => _hoverNotifier.value = isHovered,
      ),
    );

    toastEntry = _ToastEntry(
      overlayEntry: overlayEntry,
      timer: Timer(duration, () => _dismissWithAnimation(toastEntry)),
      indexNotifier: indexNotifier,
      totalNotifier: totalNotifier,
      dismissNotifier: dismissNotifier,
    );

    _toastQueue.add(toastEntry);
    overlay.insert(overlayEntry);
    _updateAllToasts();
  }

  /// 触发退出动画后移除
  static void _dismissWithAnimation(_ToastEntry entry) {
    entry.dismissNotifier.value = true;
    // 等待动画完成后移除
    Future.delayed(const Duration(milliseconds: 250), () {
      _removeToast(entry);
    });
  }

  static void _removeToast(_ToastEntry entry) {
    entry.timer.cancel();
    entry.overlayEntry.remove();
    _toastQueue.remove(entry);
    _updateAllToasts();
  }

  static void _updateAllToasts() {
    final total = _toastQueue.length;
    for (int i = 0; i < total; i++) {
      _toastQueue[i].indexNotifier.value = i;
      _toastQueue[i].totalNotifier.value = total;
    }
  }
}

class _ToastEntry {
  final OverlayEntry overlayEntry;
  final Timer timer;
  final ValueNotifier<int> indexNotifier;
  final ValueNotifier<int> totalNotifier;
  final ValueNotifier<bool> dismissNotifier; // 触发退出动画

  _ToastEntry({
    required this.overlayEntry,
    required this.timer,
    required this.indexNotifier,
    required this.totalNotifier,
    required this.dismissNotifier,
  });
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;
  final ValueNotifier<int> indexNotifier;
  final ValueNotifier<int> totalNotifier;
  final ValueNotifier<bool> hoverNotifier;
  final ValueNotifier<bool> dismissNotifier;
  final VoidCallback onRemove;
  final ValueChanged<bool> onHover;

  const _ToastWidget({
    required this.message,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
    required this.indexNotifier,
    required this.totalNotifier,
    required this.hoverNotifier,
    required this.dismissNotifier,
    required this.onRemove,
    required this.onHover,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  static const double _toastHeight = 52.0;
  bool _isDismissing = false;
  bool _isHovering = false;
  bool _isCloseHovering = false;
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _needsScroll = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();

    // 监听自动消失
    widget.dismissNotifier.addListener(_onDismissTriggered);

    // 延迟检查是否需要滚动
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndStartScroll();
    });
  }

  void _checkAndStartScroll() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && 
          _scrollController.position.maxScrollExtent > 0) {
        _needsScroll = true;
        _startAutoScroll();
      }
    });
  }

  void _startAutoScroll() {
    if (!_needsScroll || !mounted) return;
    _scrollTimer?.cancel();
    _scrollTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;
      
      // 滚动到末尾 - 降低速度，每像素50ms
      _scrollController.animateTo(
        maxScroll,
        duration: Duration(milliseconds: (maxScroll * 50).toInt().clamp(1500, 8000)),
        curve: Curves.easeInOut,
      ).then((_) {
        if (!mounted) return;
        // 等待后滚动回开头
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted || !_scrollController.hasClients) return;
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          ).then((_) {
            // 循环滚动
            if (mounted) _startAutoScroll();
          });
        });
      });
    });
  }

  void _onDismissTriggered() {
    if (widget.dismissNotifier.value && !_isDismissing) {
      _isDismissing = true;
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    widget.dismissNotifier.removeListener(_onDismissTriggered);
    _scrollTimer?.cancel();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;
    if (mounted) {
      await _animationController.reverse();
      widget.onRemove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final screenWidth = MediaQuery.of(context).size.width;
    final double toastWidth = isDesktop ? 360 : screenWidth - 32;

    return ValueListenableBuilder<bool>(
      valueListenable: widget.hoverNotifier,
      builder: (context, isHovered, _) {
        return ValueListenableBuilder<int>(
          valueListenable: widget.indexNotifier,
          builder: (context, index, _) {
            return ValueListenableBuilder<int>(
              valueListenable: widget.totalNotifier,
              builder: (context, total, child) {
                // 反转索引：最新的 toast 在最上面（reverseIndex = 0）
                final reverseIndex = total - 1 - index;
                
                // 计算位置
                final double baseTop =
                    MediaQuery.of(context).padding.top + (isDesktop ? 60 : 20);
                
                double stackedTop;
                if (isHovered) {
                  // 展开：每个 toast 完整显示，有间距
                  stackedTop = baseTop + (reverseIndex * (_toastHeight + ToastUtils._gapExpanded));
                } else {
                  // 收起：只露出一小部分
                  stackedTop = baseTop + (reverseIndex * ToastUtils._gapCollapsed);
                }

                // 缩放和透明度
                final double scale = isHovered
                    ? 1.0
                    : (1.0 - reverseIndex * ToastUtils._scaleStep).clamp(0.9, 1.0);
                final double opacity = isHovered
                    ? 1.0
                    : (1.0 - reverseIndex * ToastUtils._opacityStep).clamp(0.4, 1.0);

                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  top: stackedTop,
                  right: isDesktop ? 20 : 16,
                  width: toastWidth,
                  child: MouseRegion(
                    onEnter: (_) => widget.onHover(true),
                    onExit: (_) => widget.onHover(false),
                    child: AnimatedScale(
                      scale: scale,
                      duration: const Duration(milliseconds: 200),
                      alignment: Alignment.topRight,
                      child: AnimatedOpacity(
                        opacity: opacity,
                        duration: const Duration(milliseconds: 200),
                        child: child,
                      ),
                    ),
                  ),
                );
              },
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildToastContent(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildToastContent() {
    return Material(
      color: Colors.transparent,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: _dismiss,
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 100) {
              _dismiss();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: _toastHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _isHovering
                  ? widget.backgroundColor.withValues(alpha: 0.95)
                  : widget.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _isHovering ? 0.18 : 0.12),
                  blurRadius: _isHovering ? 20 : 16,
                  offset: Offset(0, _isHovering ? 8 : 6),
                ),
                BoxShadow(
                  color: widget.backgroundColor.withValues(alpha: _isHovering ? 0.4 : 0.3),
                  blurRadius: _isHovering ? 12 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(widget.icon, color: widget.textColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: widget.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _isCloseHovering = true),
                  onExit: (_) => setState(() => _isCloseHovering = false),
                  child: GestureDetector(
                    onTap: _dismiss,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _isCloseHovering
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.close,
                        color: widget.textColor.withValues(
                            alpha: _isCloseHovering ? 1.0 : 0.6),
                        size: 16,
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
