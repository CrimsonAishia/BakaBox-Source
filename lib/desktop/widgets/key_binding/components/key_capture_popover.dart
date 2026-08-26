import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/key_name_mapper.dart';
import 'common_widgets.dart' show TrianglePainter;

class KeyCapturePopover extends StatefulWidget {
  final String label;
  final VoidCallback onCancel;
  final ValueChanged<String> onKeyCaptured;

  const KeyCapturePopover({
    super.key,
    required this.label,
    required this.onCancel,
    required this.onKeyCaptured,
  });

  static OverlayEntry? _currentEntry;

  static void show({
    required BuildContext context,
    required BuildContext anchorContext,
    required String label,
    required ValueChanged<String> onKeyCaptured,
  }) {
    hide(); // Ensure any existing popover is closed

    final renderBox = anchorContext.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _currentEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // Barrier
          Positioned.fill(
            child: GestureDetector(
              onTap: hide,
              child: Container(
                color: Colors.black.withValues(alpha: 0.2), // Light barrier
              ),
            ),
          ),
          // Popover positioned above or below the anchor
          Positioned(
            left:
                offset.dx +
                size.width / 2 -
                125, // Center popover horizontally relative to anchor
            top:
                offset.dy +
                size.height, // Position immediately below anchor so arrow touches exactly
            child: Material(
              color: Colors.transparent,
              child: KeyCapturePopover(
                label: label,
                onCancel: hide,
                onKeyCaptured: (key) {
                  hide();
                  onKeyCaptured(key);
                },
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_currentEntry!);
  }

  static void hide() {
    _currentEntry?.remove();
    _currentEntry = null;
  }

  @override
  State<KeyCapturePopover> createState() => _KeyCapturePopoverState();
}

class _KeyCapturePopoverState extends State<KeyCapturePopover>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _getReadableKeyName(LogicalKeyboardKey key) =>
      KeyNameMapper.getReadableKeyName(key);

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final keyName = _getReadableKeyName(event.logicalKey);
      if (keyName.isNotEmpty) {
        widget.onKeyCaptured(keyName);
      }
    }
  }

  void _handlePointerEvent(PointerDownEvent event) {
    final keyName = KeyNameMapper.mouseButtonToCS2Name(event.buttons);
    if (keyName != null) {
      widget.onKeyCaptured(keyName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerEvent,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          _handleKeyEvent(event);
          return KeyEventResult.handled;
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Triangle arrow pointing up
            CustomPaint(
              size: const Size(16, 8),
              painter: TrianglePainter(
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            Container(
              width: 250,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Container(
                                  width: 16 * _pulseAnimation.value,
                                  height: 16 * _pulseAnimation.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withValues(
                                      alpha: 1.0 - _pulseAnimation.value,
                                    ),
                                  ),
                                );
                              },
                            ),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '等待输入...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请按下你想绑定到【${widget.label}】的按键',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: widget.onCancel,
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      child: const Text(
                        '取消',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
