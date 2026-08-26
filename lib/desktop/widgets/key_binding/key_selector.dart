import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'components/key_capture_dialog.dart';

/// 按键选择器组件
///
/// 用于捕获用户按下的键盘按键或鼠标按键，并显示按键名称
class KeySelector extends StatefulWidget {
  /// 按键标签（占位符名称）
  final String label;

  /// 当前选中的按键
  final String? selectedKey;

  /// 默认按键（作者设定的）
  final String? defaultKey;

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
    this.defaultKey,
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

  Future<void> _startListening() async {
    if (widget.disabled) return;
    setState(() => _isListening = true);

    final keyName = await KeyCaptureDialog.show(
      context,
      title: '绑定按键',
      subtitle: '请按下您想要绑定到【${widget.label}】的物理按键...',
    );

    if (mounted) {
      setState(() => _isListening = false);
      if (keyName != null && keyName.isNotEmpty) {
        widget.onKeySelected?.call(keyName);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasSelectedKey =
        widget.selectedKey != null && widget.selectedKey!.isNotEmpty;
    final hasDefaultKey =
        widget.defaultKey != null && widget.defaultKey!.isNotEmpty;
    final hasKey = hasSelectedKey || hasDefaultKey;
    final displayKey = hasSelectedKey
        ? widget.selectedKey!
        : (hasDefaultKey ? widget.defaultKey! : '点击选择按键');
    final bindingPrefix = hasSelectedKey
        ? '当前绑定：'
        : (hasDefaultKey ? '默认：' : '');

    return GestureDetector(
      onTap: _startListening,

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
                          bindingPrefix,
                          style: TextStyle(
                            fontSize: 11,
                            color: hasSelectedKey
                                ? AppColors.primary
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          _isListening ? '正在唤起捕获...' : displayKey,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hasKey
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: _isListening
                                ? theme.colorScheme.primary
                                : (hasSelectedKey
                                      ? AppColors.primary
                                      : (hasDefaultKey
                                            ? theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.7)
                                            : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.5))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 按键图标或清除按钮（只有在用户自定义了按键时才显示清除按钮，恢复默认）
            if (hasSelectedKey && !_isListening)
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                onPressed: widget.disabled ? null : widget.onClear,
                tooltip: '清除',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
