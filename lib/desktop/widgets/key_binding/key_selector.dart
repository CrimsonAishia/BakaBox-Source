import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 按键选择器组件
/// 
/// 用于捕获用户按下的键盘按键或鼠标按键，并显示按键名称
class KeySelector extends StatefulWidget {
  /// 按键标签（占位符名称）
  final String label;
  
  /// 当前选中的按键
  final String? selectedKey;
  
  /// 按键选择回调
  final ValueChanged<String>? onKeySelected;
  
  /// 清除按键回调
  final VoidCallback? onClear;
  
  /// 是否禁用
  final bool disabled;

  const KeySelector({
    super.key,
    required this.label,
    this.selectedKey,
    this.onKeySelected,
    this.onClear,
    this.disabled = false,
  });

  @override
  State<KeySelector> createState() => _KeySelectorState();
}

class _KeySelectorState extends State<KeySelector> {
  bool _isListening = false;
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  /// 将 LogicalKeyboardKey 转换为 CS2 按键名称
  String _keyToCS2Name(LogicalKeyboardKey key) {
    // 特殊按键映射
    final specialKeys = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.space: 'SPACE',
      LogicalKeyboardKey.enter: 'ENTER',
      LogicalKeyboardKey.escape: 'ESCAPE',
      LogicalKeyboardKey.tab: 'TAB',
      LogicalKeyboardKey.backspace: 'BACKSPACE',
      LogicalKeyboardKey.delete: 'DEL',
      LogicalKeyboardKey.insert: 'INS',
      LogicalKeyboardKey.home: 'HOME',
      LogicalKeyboardKey.end: 'END',
      LogicalKeyboardKey.pageUp: 'PGUP',
      LogicalKeyboardKey.pageDown: 'PGDN',
      LogicalKeyboardKey.arrowUp: 'UPARROW',
      LogicalKeyboardKey.arrowDown: 'DOWNARROW',
      LogicalKeyboardKey.arrowLeft: 'LEFTARROW',
      LogicalKeyboardKey.arrowRight: 'RIGHTARROW',
      LogicalKeyboardKey.shiftLeft: 'SHIFT',
      LogicalKeyboardKey.shiftRight: 'RSHIFT',
      LogicalKeyboardKey.controlLeft: 'CTRL',
      LogicalKeyboardKey.controlRight: 'RCTRL',
      LogicalKeyboardKey.altLeft: 'ALT',
      LogicalKeyboardKey.altRight: 'RALT',
      LogicalKeyboardKey.capsLock: 'CAPSLOCK',
      LogicalKeyboardKey.numLock: 'NUMLOCK',
      LogicalKeyboardKey.scrollLock: 'SCROLLLOCK',
      LogicalKeyboardKey.f1: 'F1',
      LogicalKeyboardKey.f2: 'F2',
      LogicalKeyboardKey.f3: 'F3',
      LogicalKeyboardKey.f4: 'F4',
      LogicalKeyboardKey.f5: 'F5',
      LogicalKeyboardKey.f6: 'F6',
      LogicalKeyboardKey.f7: 'F7',
      LogicalKeyboardKey.f8: 'F8',
      LogicalKeyboardKey.f9: 'F9',
      LogicalKeyboardKey.f10: 'F10',
      LogicalKeyboardKey.f11: 'F11',
      LogicalKeyboardKey.f12: 'F12',
      LogicalKeyboardKey.numpad0: 'KP_0',
      LogicalKeyboardKey.numpad1: 'KP_1',
      LogicalKeyboardKey.numpad2: 'KP_2',
      LogicalKeyboardKey.numpad3: 'KP_3',
      LogicalKeyboardKey.numpad4: 'KP_4',
      LogicalKeyboardKey.numpad5: 'KP_5',
      LogicalKeyboardKey.numpad6: 'KP_6',
      LogicalKeyboardKey.numpad7: 'KP_7',
      LogicalKeyboardKey.numpad8: 'KP_8',
      LogicalKeyboardKey.numpad9: 'KP_9',
      LogicalKeyboardKey.numpadDecimal: 'KP_DEL',
      LogicalKeyboardKey.numpadEnter: 'KP_ENTER',
      LogicalKeyboardKey.numpadAdd: 'KP_PLUS',
      LogicalKeyboardKey.numpadSubtract: 'KP_MINUS',
      LogicalKeyboardKey.numpadMultiply: 'KP_MULTIPLY',
      LogicalKeyboardKey.numpadDivide: 'KP_DIVIDE',
      LogicalKeyboardKey.semicolon: 'SEMICOLON',
      LogicalKeyboardKey.comma: ',',
      LogicalKeyboardKey.period: '.',
      LogicalKeyboardKey.slash: '/',
      LogicalKeyboardKey.backquote: '`',
      LogicalKeyboardKey.bracketLeft: '[',
      LogicalKeyboardKey.bracketRight: ']',
      LogicalKeyboardKey.backslash: '\\',
      LogicalKeyboardKey.quote: "'",
      LogicalKeyboardKey.minus: '-',
      LogicalKeyboardKey.equal: '=',
    };

    if (specialKeys.containsKey(key)) {
      return specialKeys[key]!;
    }

    // 字母和数字键 - 统一转为大写
    final keyLabel = key.keyLabel;
    if (keyLabel.isNotEmpty) {
      return keyLabel.toUpperCase();
    }

    return key.debugName ?? 'UNKNOWN';
  }

  /// 将鼠标按键转换为 CS2 按键名称
  String? _mouseButtonToCS2Name(int buttons) {
    // buttons 是位掩码:
    // kPrimaryButton = 1 (左键)
    // kSecondaryButton = 2 (右键)
    // kMiddleMouseButton = 4 (中键)
    // kBackMouseButton = 8 (侧键1/后退)
    // kForwardMouseButton = 16 (侧键2/前进)
    if (buttons & kMiddleMouseButton != 0) {
      return 'MOUSE3';
    } else if (buttons & kBackMouseButton != 0) {
      return 'MOUSE4';
    } else if (buttons & kForwardMouseButton != 0) {
      return 'MOUSE5';
    }
    return null; // 左键和右键忽略
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => _KeyBindingOverlay(
        onCancel: () => _stopListening(clearBinding: true),
        onKeyEvent: _handleKeyEvent,
        onMouseEvent: _handleMouseEvent,
        onScrollEvent: _handleScrollEvent,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _startListening() {
    if (widget.disabled) return;
    setState(() => _isListening = true);
    _showOverlay();
  }

  void _stopListening({bool clearBinding = false}) {
    _removeOverlay();
    setState(() => _isListening = false);
    if (clearBinding) {
      widget.onClear?.call();
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (!_isListening) return;
    if (event is! KeyDownEvent) return;

    // ESC 键取消绑定并清空
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _stopListening(clearBinding: true);
      return;
    }

    final keyName = _keyToCS2Name(event.logicalKey);
    widget.onKeySelected?.call(keyName);
    _stopListening();
  }

  void _handleMouseEvent(PointerDownEvent event) {
    if (!_isListening) return;

    final keyName = _mouseButtonToCS2Name(event.buttons);
    if (keyName != null) {
      widget.onKeySelected?.call(keyName);
      _stopListening();
    }
    // 左键和右键不处理，让用户可以点击取消
  }

  void _handleScrollEvent(PointerScrollEvent event) {
    if (!_isListening) return;

    // 判断滚动方向
    if (event.scrollDelta.dy < 0) {
      // 向上滚动
      widget.onKeySelected?.call('MWHEELUP');
      _stopListening();
    } else if (event.scrollDelta.dy > 0) {
      // 向下滚动
      widget.onKeySelected?.call('MWHEELDOWN');
      _stopListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasKey = widget.selectedKey != null && widget.selectedKey!.isNotEmpty;

    return GestureDetector(
      onTap: _isListening ? _stopListening : _startListening,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _isListening
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isListening
                ? theme.colorScheme.primary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1)),
            width: _isListening ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // 标签
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (hasKey) ...[
                        Text(
                          '绑定至：',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          _isListening
                              ? '按下任意键...'
                              : (hasKey ? widget.selectedKey! : '点击选择按键'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hasKey ? FontWeight.w600 : FontWeight.normal,
                            color: _isListening
                                ? theme.colorScheme.primary
                                : (hasKey
                                    ? const Color(0xFF0080FF)
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 按键图标或清除按钮
            if (hasKey && !_isListening)
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                onPressed: widget.disabled ? null : widget.onClear,
                tooltip: '清除',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              )
            else
              Icon(
                _isListening ? Icons.keyboard : Icons.keyboard_outlined,
                size: 20,
                color: _isListening
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }
}

/// 按键绑定全局遮罩
class _KeyBindingOverlay extends StatelessWidget {
  final VoidCallback onCancel;
  final void Function(KeyEvent) onKeyEvent;
  final void Function(PointerDownEvent) onMouseEvent;
  final void Function(PointerScrollEvent) onScrollEvent;

  const _KeyBindingOverlay({
    required this.onCancel,
    required this.onKeyEvent,
    required this.onMouseEvent,
    required this.onScrollEvent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Material(
      color: Colors.transparent,
      child: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: onKeyEvent,
        autofocus: true,
        child: Listener(
          onPointerDown: (event) {
            // 左键点击取消
            if (event.buttons == 1) {
              onCancel();
            } else {
              onMouseEvent(event);
            }
          },
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              onScrollEvent(event);
            }
          },
          child: Container(
            color: Colors.black.withValues(alpha: 0.6),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.keyboard_alt_outlined,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '请按下要绑定的按键',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '按 ESC 或点击任意位置取消',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
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
