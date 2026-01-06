import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 按键选择器组件
/// 
/// 用于捕获用户按下的键盘按键，并显示按键名称
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

  @override
  void dispose() {
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
      LogicalKeyboardKey.numpad0: 'KP_INS',
      LogicalKeyboardKey.numpad1: 'KP_END',
      LogicalKeyboardKey.numpad2: 'KP_DOWNARROW',
      LogicalKeyboardKey.numpad3: 'KP_PGDN',
      LogicalKeyboardKey.numpad4: 'KP_LEFTARROW',
      LogicalKeyboardKey.numpad5: 'KP_5',
      LogicalKeyboardKey.numpad6: 'KP_RIGHTARROW',
      LogicalKeyboardKey.numpad7: 'KP_HOME',
      LogicalKeyboardKey.numpad8: 'KP_UPARROW',
      LogicalKeyboardKey.numpad9: 'KP_PGUP',
      LogicalKeyboardKey.numpadDecimal: 'KP_DEL',
      LogicalKeyboardKey.numpadEnter: 'KP_ENTER',
      LogicalKeyboardKey.numpadAdd: 'KP_PLUS',
      LogicalKeyboardKey.numpadSubtract: 'KP_MINUS',
      LogicalKeyboardKey.numpadMultiply: 'KP_MULTIPLY',
      LogicalKeyboardKey.numpadDivide: 'KP_SLASH',
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

    // 字母和数字键
    final keyLabel = key.keyLabel;
    if (keyLabel.isNotEmpty) {
      return keyLabel.toLowerCase();
    }

    return key.debugName ?? 'UNKNOWN';
  }

  void _startListening() {
    if (widget.disabled) return;
    setState(() => _isListening = true);
    _focusNode.requestFocus();
  }

  void _stopListening() {
    setState(() => _isListening = false);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (!_isListening) return;
    if (event is! KeyDownEvent) return;

    final keyName = _keyToCS2Name(event.logicalKey);
    widget.onKeySelected?.call(keyName);
    _stopListening();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasKey = widget.selectedKey != null && widget.selectedKey!.isNotEmpty;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
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
      ),
    );
  }
}
