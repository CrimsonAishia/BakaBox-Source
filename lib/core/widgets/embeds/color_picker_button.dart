import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'toolbar_icon_button.dart';
import '../../constants/app_colors.dart';

/// 工具栏颜色按钮：弹出色板，支持文字颜色（A）或背景色（高亮）。
///
/// 使用方式：
/// ```dart
/// ColorPickerButton(controller: ctrl, isBackground: false) // 文字色
/// ColorPickerButton(controller: ctrl, isBackground: true)  // 背景色
/// ```
class ColorPickerButton extends StatefulWidget {
  /// Quill Controller
  final QuillController controller;

  /// true=背景色（高亮），false=文字颜色
  final bool isBackground;

  const ColorPickerButton({
    super.key,
    required this.controller,
    this.isBackground = false,
  });

  @override
  State<ColorPickerButton> createState() => _ColorPickerButtonState();
}

class _ColorPickerButtonState extends State<ColorPickerButton> {
  /// 调色板（17 色 + 默认）。覆盖常见标注色：黑/白/灰系 + 红橙黄绿青蓝紫粉。
  static const List<Color> _palette = [
    Color(0xFFFFFFFF),
    AppColors.gray200,
    AppColors.slate400,
    AppColors.gray800,
    Color(0xFF000000),
    AppColors.red500,
    Color(0xFFF97316),
    AppColors.amber500,
    Color(0xFFEAB308),
    Color(0xFF84CC16),
    AppColors.green500,
    Color(0xFF14B8A6),
    Color(0xFF06B6D4),
    AppColors.blue500,
    AppColors.indigo500,
    AppColors.violet500,
    Color(0xFFD946EF),
    Color(0xFFEC4899),
  ];

  String _hex(Color c) {
    final argb = c.toARGB32();
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  /// 应用颜色：null 表示清除该属性
  void _apply(Color? color) {
    if (color == null) {
      widget.controller.formatSelection(
        widget.isBackground
            ? const BackgroundAttribute(null)
            : const ColorAttribute(null),
      );
    } else {
      final attribute = widget.isBackground
          ? BackgroundAttribute(_hex(color))
          : ColorAttribute(_hex(color));
      widget.controller.formatSelection(attribute);
    }
    // 关闭浮层
    Navigator.of(context).maybePop();
  }

  Future<void> _showPalette() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    if (button == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(
          button.size.bottomLeft(Offset.zero),
          ancestor: overlay,
        ),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    await showMenu<void>(
      context: context,
      position: position,
      color: isDark ? const Color(0xFF1F2A3D) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.gray200,
        ),
      ),
      elevation: 8,
      items: [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _PaletteContent(
            palette: _palette,
            isDark: isDark,
            isBackground: widget.isBackground,
            onPick: _apply,
            onClear: () => _apply(null),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ToolbarIconButton(
      icon: widget.isBackground
          ? Icons.format_color_fill_rounded
          : Icons.format_color_text_rounded,
      tooltip: widget.isBackground ? '背景色（高亮）' : '文字颜色',
      onTap: _showPalette,
    );
  }
}

class _PaletteContent extends StatelessWidget {
  final List<Color> palette;
  final bool isDark;
  final bool isBackground;
  final ValueChanged<Color> onPick;
  final VoidCallback onClear;

  const _PaletteContent({
    required this.palette,
    required this.isDark,
    required this.isBackground,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? AppColors.slate400 : AppColors.slate500;

    return SizedBox(
      width: 210,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isBackground
                      ? Icons.format_color_fill_rounded
                      : Icons.format_color_text_rounded,
                  size: 14,
                  color: muted,
                ),
                const SizedBox(width: 6),
                Text(
                  isBackground ? '背景色' : '文字颜色',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
                const Spacer(),
                _ClearButton(isDark: isDark, onTap: onClear),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in palette)
                  _Swatch(color: c, isDark: isDark, onTap: () => onPick(c)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatefulWidget {
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _Swatch({
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_Swatch> createState() => _SwatchState();
}

class _SwatchState extends State<_Swatch> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: _hover
                  ? AppColors.primary
                  : (widget.isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppColors.gray300),
              width: _hover ? 1.6 : 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.45),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

class _ClearButton extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _ClearButton({required this.isDark, required this.onTap});

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = _hover
        ? AppColors.primary
        : (widget.isDark ? AppColors.slate400 : AppColors.slate500);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: '清除',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.format_color_reset_rounded, size: 12, color: color),
                const SizedBox(width: 4),
                Text(
                  '清除',
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500,
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
