import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'obs_utils.dart';

/// 辅助方法：将 Color 转换为十六进制字符串
/// 使用新的 API 避免 deprecated 警告
String _colorToHexString(Color color, {bool includeAlpha = false}) {
  final a = (color.a * 255.0).round() & 0xff;
  final r = (color.r * 255.0).round() & 0xff;
  final g = (color.g * 255.0).round() & 0xff;
  final b = (color.b * 255.0).round() & 0xff;

  if (includeAlpha) {
    return '#${a.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  } else {
    return '#${r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }
}

/// 颜色选项按钮（带 hover 效果）
class _ColorOptionButton extends StatefulWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorOptionButton({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ColorOptionButton> createState() => _ColorOptionButtonState();
}

class _ColorOptionButtonState extends State<_ColorOptionButton> {
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
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isSelected
                  ? Colors.blue
                  : _isHovered
                      ? Colors.blue.withValues(alpha: 0.7)
                      : Colors.grey,
              width: widget.isSelected ? 3 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : _isHovered
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
          ),
        ),
      ),
    );
  }
}

/// 构建文本颜色选项
Widget buildTextColorOption(
  Map<String, dynamic> el,
  String hexColor,
  Color color, {
  VoidCallback? onChanged,
}) {
  final isSelected = (el['textColor'] ?? '#FFFFFF') == hexColor;
  return _ColorOptionButton(
    color: color,
    isSelected: isSelected,
    onTap: () {
      el['textColor'] = hexColor;
      onChanged?.call();
    },
  );
}

/// 构建背景颜色选项
Widget buildBgColorOption(
  Map<String, dynamic> el,
  String hexColor,
  Color color, {
  VoidCallback? onChanged,
}) {
  final isSelected = (el['backgroundColor'] ?? '#80000000') == hexColor;
  return _ColorOptionButton(
    color: color,
    isSelected: isSelected,
    onTap: () {
      el['backgroundColor'] = hexColor;
      onChanged?.call();
    },
  );
}

/// 构建描边颜色选项
Widget buildStrokeColorOption(
  Map<String, dynamic> el,
  String hexColor,
  Color color, {
  VoidCallback? onChanged,
}) {
  final isSelected = (el['strokeColor'] ?? '#000000') == hexColor;
  return _ColorOptionButton(
    color: color,
    isSelected: isSelected,
    onTap: () {
      el['strokeColor'] = hexColor;
      onChanged?.call();
    },
  );
}

/// 构建自定义颜色选项（带预设面板）
Widget buildCustomColorOption(
  BuildContext context,
  Map<String, dynamic> el,
  String key,
  String currentColorHex, {
  bool enableAlpha = false,
  VoidCallback? onChanged,
}) {
  Color currentColor = parseColor(currentColorHex);
  return _CustomColorButton(
    onTap: () {
      showDialog(
        context: context,
        builder: (context) => _ColorPickerDialog(
          initialColor: currentColor,
          enableAlpha: enableAlpha,
          onColorSelected: (color) {
            if (enableAlpha) {
              el[key] = _colorToHexString(color, includeAlpha: true);
            } else {
              el[key] = _colorToHexString(color);
            }
            onChanged?.call();
          },
        ),
      );
    },
  );
}

/// 自定义颜色按钮（带 hover 效果）
class _CustomColorButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CustomColorButton({required this.onTap});

  @override
  State<_CustomColorButton> createState() => _CustomColorButtonState();
}

class _CustomColorButtonState extends State<_CustomColorButton> {
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
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.red, Colors.green, Colors.blue],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: _isHovered ? Colors.white : Colors.white.withValues(alpha: 0.8),
              width: _isHovered ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.4 : 0.3),
                blurRadius: _isHovered ? 6 : 3,
                offset: const Offset(1, 1),
              ),
              if (_isHovered)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.2),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.colorize,
              size: 14,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 2,
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 优化的颜色选择器对话框
class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final bool enableAlpha;
  final Function(Color) onColorSelected;

  const _ColorPickerDialog({
    required this.initialColor,
    required this.enableAlpha,
    required this.onColorSelected,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selectedColor;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _hexController = TextEditingController(text: _colorToHex(_selectedColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return _colorToHexString(color, includeAlpha: widget.enableAlpha);
  }

  void _onHexChanged(String value) {
    if (value.length == 7 || value.length == 9) {
      try {
        String hex = value.replaceAll('#', '');
        if (hex.length == 6) {
          final color = Color(int.parse('FF$hex', radix: 16));
          setState(() => _selectedColor = color);
        } else if (hex.length == 8) {
          final color = Color(int.parse(hex, radix: 16));
          setState(() => _selectedColor = color);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.colorize,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '选择颜色',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // HEX 输入框
            Row(
              children: [
                const Text(
                  'HEX',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    onChanged: _onHexChanged,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 颜色选择器
            SizedBox(
              height: 280,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: ColorPicker(
                  pickerColor: _selectedColor,
                  onColorChanged: (color) {
                    setState(() => _selectedColor = color);
                    _hexController.text = _colorToHex(color);
                  },
                  enableAlpha: widget.enableAlpha,
                  displayThumbColor: true,
                  portraitOnly: true,
                  pickerAreaHeightPercent: 0.65,
                  labelTypes: const [],
                  pickerAreaBorderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),
            // 按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    widget.onColorSelected(_selectedColor);
                    Navigator.pop(context);
                  },
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
