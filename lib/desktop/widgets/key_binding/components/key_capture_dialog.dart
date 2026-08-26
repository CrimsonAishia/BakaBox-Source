import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/key_name_mapper.dart';

/// 键盘按键捕获弹窗 (重新美化版)
class KeyCaptureDialog extends StatefulWidget {
  final String title;
  final String subtitle;

  const KeyCaptureDialog({
    super.key,
    required this.title,
    required this.subtitle,
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: true,
      builder: (ctx) => KeyCaptureDialog(title: title, subtitle: subtitle),
    );
  }

  @override
  State<KeyCaptureDialog> createState() => _KeyCaptureDialogState();
}

class _KeyCaptureDialogState extends State<KeyCaptureDialog>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  String? _capturedKey;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
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

  /// 将鼠标按键转换为 CS2 按键名称
  String? _mouseButtonToCS2Name(int buttons) =>
      KeyNameMapper.mouseButtonToCS2Name(buttons);

  bool _hasCaptured = false;

  void _handleCapturedKey(String keyName) {
    if (keyName.isNotEmpty && !_hasCaptured) {
      _hasCaptured = true;
      setState(() {
        _capturedKey = keyName;
      });
      _pulseController.stop();
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          // ignore: use_build_context_synchronously
          Navigator.of(context).pop(_capturedKey);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final keyName = _getReadableKeyName(event.logicalKey);
          _handleCapturedKey(keyName);
        }
        return KeyEventResult.handled;
      },
      child: Listener(
        onPointerDown: (event) {
          if (event.buttons != kPrimaryButton &&
              event.buttons != kSecondaryButton) {
            final keyName = _mouseButtonToCS2Name(event.buttons);
            if (keyName != null) {
              _handleCapturedKey(keyName);
            }
          }
        },
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            if (event.scrollDelta.dy < 0) {
              _handleCapturedKey('MWHEELUP');
            } else if (event.scrollDelta.dy > 0) {
              _handleCapturedKey('MWHEELDOWN');
            }
          }
        },
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: 340,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            AppColors.slate900.withValues(alpha: 0.95),
                            AppColors.slate900.withValues(alpha: 0.8),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.95),
                            Colors.white.withValues(alpha: 0.85),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 50,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 顶部图标区
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.25),
                            AppColors.primary.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.keyboard_alt_outlined,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 标题与副标题
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // 按键显示区（加入脉冲呼吸动画）
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _capturedKey == null
                              ? _pulseAnimation.value
                              : 1.0,
                          child: child,
                        );
                      },
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 120,
                          minHeight: 120,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _capturedKey != null
                                ? [
                                    AppColors.primary.withValues(alpha: 0.15),
                                    AppColors.primary.withValues(alpha: 0.02),
                                  ]
                                : (isDark
                                      ? [AppColors.slate800, AppColors.slate900]
                                      : [Colors.grey[100]!, Colors.grey[50]!]),
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _capturedKey != null
                                ? AppColors.primary
                                : (isDark ? Colors.white24 : Colors.black12),
                            width: _capturedKey != null ? 2.5 : 1.5,
                          ),
                          boxShadow: _capturedKey != null
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 28,
                                    spreadRadius: 4,
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  );
                                },
                            child: _capturedKey == null
                                ? Text(
                                    '?',
                                    key: const ValueKey('prompt'),
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w300,
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.grey[400],
                                    ),
                                  )
                                : Text(
                                    _capturedKey!,
                                    key: ValueKey(_capturedKey),
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                      shadows: [
                                        Shadow(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // 底部操作
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.white54
                            : Colors.black54,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
