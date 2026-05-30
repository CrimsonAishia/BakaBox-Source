import 'package:flutter/material.dart';
import 'package:flex_color_picker/flex_color_picker.dart';

/// 标签颜色选择器预设颜色列表
const List<String?> tagPresetColors = [
  null, // 无颜色
  '#EF4444', // 红色
  '#F97316', // 橙色
  '#F59E0B', // 琥珀色
  '#84CC16', // 酸绿色
  '#22C55E', // 绿色
  '#14B8A6', // 青色
  '#0EA5E9', // 天蓝色
  '#3B82F6', // 蓝色
  '#8B5CF6', // 紫色
  '#EC4899', // 粉色
  '#6B7280', // 灰色
];

/// 预设颜色的中文名称（用于无障碍提示）
const Map<String, String> tagPresetColorNames = {
  'null': '无颜色',
  '#EF4444': '红色',
  '#F97316': '橙色',
  '#F59E0B': '琥珀色',
  '#84CC16': '酸绿色',
  '#22C55E': '绿色',
  '#14B8A6': '青色',
  '#0EA5E9': '天蓝色',
  '#3B82F6': '蓝色',
  '#8B5CF6': '紫色',
  '#EC4899': '粉色',
  '#6B7280': '灰色',
};

/// 将十六进制颜色字符串转换为 Color
Color? hexToColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  try {
    final cleanHex = hex.replaceFirst('#', '');
    if (cleanHex.length == 6) {
      return Color(int.parse('FF$cleanHex', radix: 16));
    } else if (cleanHex.length == 8) {
      return Color(int.parse(cleanHex, radix: 16));
    }
  } catch (_) {}
  return null;
}

/// 将 Color 转换为十六进制字符串（带 # 前缀，无透明度）
String colorToHex(Color color) {
  return '#'
          '${(color.r * 255).toInt().toRadixString(16).padLeft(2, '0')}'
          '${(color.g * 255).toInt().toRadixString(16).padLeft(2, '0')}'
          '${(color.b * 255).toInt().toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

/// 标签颜色选择器组件
///
/// 支持预设颜色选择和自定义颜色（通过颜色面板选择）。
///
/// [selectedColor] 当前选中的颜色（null 表示无颜色）
/// [onColorChanged] 颜色变化回调（null 表示无颜色）
/// [enabled] 是否可用
class TagColorPicker extends StatelessWidget {
  /// 当前选中的颜色（null 表示无颜色）
  final String? selectedColor;

  /// 颜色变化回调（参数为新的颜色，无颜色时传入 null）
  final ValueChanged<String?> onColorChanged;

  /// 是否禁用
  final bool enabled;

  const TagColorPicker({
    super.key,
    required this.selectedColor,
    required this.onColorChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedValue = selectedColor;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...tagPresetColors.map((colorHex) {
          final isSelected = selectedValue == colorHex;
          final colorValue = hexToColor(colorHex);

          return _PresetColorButton(
            colorHex: colorHex,
            colorValue: colorValue,
            isSelected: isSelected,
            enabled: enabled,
            isDark: isDark,
            onTap: () => onColorChanged(colorHex),
          );
        }),
        _CustomColorButton(
          currentColor: hexToColor(selectedValue),
          enabled: enabled,
          isDark: isDark,
          onColorSelected: onColorChanged,
        ),
      ],
    );
  }
}

/// 预设颜色按钮
class _PresetColorButton extends StatefulWidget {
  final String? colorHex;
  final Color? colorValue;
  final bool isSelected;
  final bool enabled;
  final bool isDark;
  final VoidCallback onTap;

  const _PresetColorButton({
    required this.colorHex,
    required this.colorValue,
    required this.isSelected,
    required this.enabled,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_PresetColorButton> createState() => _PresetColorButtonState();
}

class _PresetColorButtonState extends State<_PresetColorButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.colorHex == null) {
      // 无颜色按钮
      return Tooltip(
        message: '无颜色',
        child: MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: widget.enabled ? widget.onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.isSelected
                      ? const Color(0xFF0080FF)
                      : _isHovered
                      ? (widget.isDark ? Colors.white54 : Colors.grey[400]!)
                      : (widget.isDark ? Colors.white24 : Colors.grey[300]!),
                  width: widget.isSelected ? 2 : 1,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0080FF).withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.close,
                size: 14,
                color: widget.isSelected
                    ? const Color(0xFF0080FF)
                    : (widget.isDark ? Colors.white38 : Colors.grey[500]),
              ),
            ),
          ),
        ),
      );
    }

    // 预设颜色按钮
    return Tooltip(
      message: tagPresetColorNames[widget.colorHex] ?? widget.colorHex!,
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: widget.colorValue,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: widget.isSelected
                    ? const Color(0xFF0080FF)
                    : _isHovered
                    ? (widget.isDark ? Colors.white70 : Colors.grey[500]!)
                    : Colors.transparent,
                width: widget.isSelected ? 2.5 : 1,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0080FF).withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ]
                  : _isHovered
                  ? [
                      BoxShadow(
                        color: (widget.colorValue ?? Colors.black).withValues(
                          alpha: 0.3,
                        ),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: widget.isSelected
                ? Icon(
                    Icons.check,
                    color: _contrastColor(widget.colorValue!),
                    size: 16,
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Color _contrastColor(Color background) {
    return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}

/// 自定义颜色按钮
class _CustomColorButton extends StatefulWidget {
  final Color? currentColor;
  final bool enabled;
  final bool isDark;
  final ValueChanged<String?> onColorSelected;

  const _CustomColorButton({
    required this.currentColor,
    required this.enabled,
    required this.isDark,
    required this.onColorSelected,
  });

  @override
  State<_CustomColorButton> createState() => _CustomColorButtonState();
}

class _CustomColorButtonState extends State<_CustomColorButton> {
  bool _isHovered = false;

  /// 当前颜色是否为自定义（不在预设颜色中）
  bool get _isCustomSelected {
    if (widget.currentColor == null) return false;
    final hex = colorToHex(widget.currentColor!);
    return !tagPresetColors.any((c) => c == hex);
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = _isCustomSelected;

    return Tooltip(
      message: '自定义颜色',
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.enabled ? () => _showCustomColorPicker(context) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Colors.red,
                  Colors.orange,
                  Colors.yellow,
                  Colors.green,
                  Colors.blue,
                  Colors.purple,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0080FF)
                    : _isHovered
                    ? Colors.white
                    : (widget.isDark ? Colors.white54 : Colors.grey[400]!),
                width: isSelected ? 2.5 : (_isHovered ? 2 : 1.5),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0080FF).withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ]
                  : _isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: widget.currentColor!.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    size: 16,
                  )
                : const Icon(Icons.colorize, size: 14, color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _showCustomColorPicker(BuildContext context) async {
    Color pickerColor = widget.currentColor ?? const Color(0xFF3B82F6);

    final Color result = await showColorPickerDialog(
      context,
      pickerColor,
      title: Text(
        '自定义颜色',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      width: 40,
      height: 40,
      spacing: 0,
      runSpacing: 0,
      borderRadius: 4,
      wheelDiameter: 200,
      wheelWidth: 16,
      showColorCode: true,
      colorCodeHasColor: true,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: false,
        ColorPickerType.accent: false,
        ColorPickerType.bw: false,
        ColorPickerType.custom: false,
        ColorPickerType.wheel: true,
      },
      actionButtons: const ColorPickerActionButtons(
        okButton: true,
        closeButton: true,
        dialogActionButtons: false,
      ),
      constraints: const BoxConstraints(
        minHeight: 360,
        minWidth: 300,
        maxWidth: 320,
      ),
    );

    widget.onColorSelected(colorToHex(result));
  }
}
