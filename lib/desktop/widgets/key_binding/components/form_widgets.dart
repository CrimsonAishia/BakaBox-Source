import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/models/key_config_models.dart';
import '../../../../core/utils/key_placeholder_parser.dart';
import 'common_widgets.dart';
import '../../../../core/constants/app_colors.dart';

/// 富文本脚本编辑器控制器，用于将占位符渲染为漂亮的标签
class RichScriptEditingController extends TextEditingController {
  final bool readOnly;

  RichScriptEditingController({this.readOnly = false, super.text});

  void _deletePlaceholder(int start, int end) {
    final currentText = text;
    final newText = currentText.replaceRange(start, end, '');

    int newCursor = selection.baseOffset;
    if (newCursor > end) {
      newCursor -= (end - start);
    } else if (newCursor > start) {
      newCursor = start;
    }
    if (newCursor < 0) newCursor = 0;

    value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  @override
  set value(TextEditingValue newValue) {
    TextEditingValue adjustedValue = newValue;
    final matches = KeyPlaceholderParser.placeholderPattern.allMatches(text);

    // 1. 防止在占位符内部修改文本，以及处理边界删除
    if (newValue.text != text) {
      final oldSelection = selection;

      if (oldSelection.isValid) {
        for (final match in matches) {
          if (oldSelection.isCollapsed) {
            final pos = oldSelection.baseOffset;
            
            // 防止在占位符内部输入
            if (pos > match.start && pos < match.end) {
              adjustedValue = value;
              break;
            }

            // 处理在占位符末尾按退格键
            if (pos == match.end && newValue.text.length < text.length && newValue.selection.baseOffset == match.end - 1) {
              final newText = text.replaceRange(match.start, match.end, '');
              adjustedValue = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: match.start),
              );
              break;
            }

            // 处理在占位符开头按 Delete 键
            if (pos == match.start && newValue.text.length < text.length && newValue.selection.baseOffset == match.start) {
              if (text.startsWith(match.group(0)!, match.start) && 
                  !newValue.text.startsWith(match.group(0)!, match.start)) {
                final newText = text.replaceRange(match.start, match.end, '');
                adjustedValue = TextEditingValue(
                  text: newText,
                  selection: TextSelection.collapsed(offset: match.start),
                );
                break;
              }
            }
          } else {
            // 防止跨占位符的部分修改
            if ((oldSelection.start > match.start && oldSelection.start < match.end) || 
                (oldSelection.end > match.start && oldSelection.end < match.end)) {
              adjustedValue = value;
              break;
            }
          }
        }
      }
    }

    // 2. 光标吸附逻辑：如果光标落入占位符内部，将其吸附到边缘
    if (adjustedValue.selection.isValid) {
      int? newBase;
      int? newExtent;
      final currentMatches = adjustedValue.text == text 
          ? matches 
          : KeyPlaceholderParser.placeholderPattern.allMatches(adjustedValue.text);
          
      final oldSelection = selection;

      for (final match in currentMatches) {
        if (adjustedValue.selection.isCollapsed) {
          final pos = adjustedValue.selection.baseOffset;
          if (pos > match.start && pos < match.end) {
             if (oldSelection.isValid && oldSelection.isCollapsed) {
               if (pos > oldSelection.baseOffset) {
                 newBase = match.end; // 向右移动
               } else if (pos < oldSelection.baseOffset) {
                 newBase = match.start; // 向左移动
               } else {
                 newBase = (pos - match.start < match.end - pos) ? match.start : match.end;
               }
             } else {
               newBase = (pos - match.start < match.end - pos) ? match.start : match.end;
             }
             newExtent = newBase;
             break;
          }
        } else {
          int b = newBase ?? adjustedValue.selection.baseOffset;
          int e = newExtent ?? adjustedValue.selection.extentOffset;
          bool changed = false;
          if (b > match.start && b < match.end) {
            b = (b > (oldSelection.isValid ? oldSelection.baseOffset : b)) ? match.end : match.start;
            changed = true;
          }
          if (e > match.start && e < match.end) {
            e = (e > (oldSelection.isValid ? oldSelection.extentOffset : e)) ? match.end : match.start;
            changed = true;
          }
          if (changed) {
            newBase = b;
            newExtent = e;
          }
        }
      }

      if (newBase != null || newExtent != null) {
        adjustedValue = adjustedValue.copyWith(
          selection: adjustedValue.selection.copyWith(
            baseOffset: newBase ?? adjustedValue.selection.baseOffset,
            extentOffset: newExtent ?? adjustedValue.selection.extentOffset,
          ),
        );
      }
    }

    super.value = adjustedValue;
  }

  List<TextSpan> _buildSpacedText(String rawText, TextStyle? baseStyle) {
    if (rawText.isEmpty) return [];
    
    // 匹配连续的空格或制表符
    final matches = RegExp(r'[ \t]+').allMatches(rawText);
    if (matches.isEmpty) {
      return [TextSpan(text: rawText, style: baseStyle)];
    }

    // 成熟方案：将占位符颜色调淡，避免喧宾夺主
    final spaceStyle = baseStyle?.copyWith(
      color: baseStyle.color?.withValues(alpha: 0.35) ?? Colors.grey.withValues(alpha: 0.35),
    );

    final children = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        children.add(TextSpan(text: rawText.substring(lastEnd, match.start), style: baseStyle));
      }
      
      final spaceStr = match.group(0)!;
      // 使用半角片假名中点(･)代替普通中点(·)，它在等宽字体中占宽更标准
      final visuallyReplaced = spaceStr.replaceAll(' ', '･').replaceAll('\t', '→');
      
      children.add(TextSpan(text: visuallyReplaced, style: spaceStyle));
      lastEnd = match.end;
    }

    if (lastEnd < rawText.length) {
      children.add(TextSpan(text: rawText.substring(lastEnd), style: baseStyle));
    }

    return children;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final matches = KeyPlaceholderParser.placeholderPattern.allMatches(text);
    if (matches.isEmpty && !text.contains(' ') && !text.contains('\t')) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final children = <TextSpan>[];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        children.addAll(_buildSpacedText(text.substring(lastMatchEnd, match.start), style));
      }

      final label = match.group(1)!;
      final defaultKey = match.group(2);
      final start = match.start;
      final end = match.end;

      final originalText = match.group(0)!;
      // 保持长度一致以避免游标错位：原文本长度 N，我们放入 1 个 WidgetSpan (对应 \uFFFC)，加上 N-1 个字符的隐藏 TextSpan
      final hiddenText = originalText.substring(1);

      children.add(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _PlaceholderCard(
                label: label,
                defaultKey: defaultKey,
                readOnly: readOnly,
                onDelete: () => _deletePlaceholder(start, end),
              ),
            ),
            TextSpan(
              text: hiddenText,
              style: const TextStyle(
                color: Colors.transparent,
                fontSize: 0,
                height: 0,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      children.addAll(_buildSpacedText(text.substring(lastMatchEnd), style));
    }

    return TextSpan(style: style, children: children);
  }
}

class PlaceholderDeletePopover extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const PlaceholderDeletePopover({
    super.key,
    required this.onCancel,
    required this.onDelete,
  });

  static OverlayEntry? _currentEntry;

  static void show({
    required BuildContext context,
    required BuildContext anchorContext,
    required VoidCallback onDelete,
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
              child: Container(color: Colors.black.withValues(alpha: 0.1)),
            ),
          ),
          // Popover positioned below the anchor
          Positioned(
            left: offset.dx + size.width / 2 - 80, // Center horizontally
            top: offset.dy + size.height,
            child: Material(
              color: Colors.transparent,
              child: PlaceholderDeletePopover(
                onCancel: hide,
                onDelete: () {
                  hide();
                  onDelete();
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
  State<PlaceholderDeletePopover> createState() =>
      _PlaceholderDeletePopoverState();
}

class _PlaceholderDeletePopoverState extends State<PlaceholderDeletePopover> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomPaint(
          size: const Size(16, 8),
          painter: TrianglePainter(
            color: AppColors.red500.withValues(alpha: 0.8),
          ),
        ),
        Container(
          width: 160,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.red500.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '删除此占位符？',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: widget.onCancel,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    child: const Text(
                      '取消',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  FilledButton(
                    onPressed: widget.onDelete,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.red500,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    child: const Text(
                      '删除',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaceholderCard extends StatefulWidget {
  final String label;
  final String? defaultKey;
  final VoidCallback onDelete;
  final bool readOnly;

  const _PlaceholderCard({
    required this.label,
    this.defaultKey,
    required this.onDelete,
    this.readOnly = false,
  });

  @override
  State<_PlaceholderCard> createState() => _PlaceholderCardState();
}

class _PlaceholderCardState extends State<_PlaceholderCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = AppColors.emerald500;
    final textColor = AppColors.emerald500;
    final bgColor = baseColor.withValues(alpha: _isHovered ? 0.25 : 0.15);
    final shadowColor = baseColor.withValues(alpha: _isHovered ? 0.6 : 0.3);

    final String displayText =
        widget.defaultKey != null && widget.defaultKey!.isNotEmpty
        ? '${widget.label} (${widget.defaultKey})'
        : widget.label;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(MdiIcons.keyboardOutline, size: 14, color: textColor),
        const SizedBox(width: 4),
        Text(
          displayText,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            color: textColor,
            height: 1.2,
            shadows: [
              Shadow(color: textColor.withValues(alpha: 0.5), blurRadius: 4),
            ],
          ),
        ),
      ],
    );

    final innerCard = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        // Removed border here, relying on the gradient border
      ),
      child: content,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardContent = MouseRegion(
      cursor: widget.readOnly
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7.5),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: _isHovered ? 12 : 6,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7.5),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: -50,
                bottom: -50,
                left: -50,
                right: -50,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) {
                    return Transform.rotate(
                      angle: _controller.value * 2 * 3.141592653589793,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: SweepGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.emerald500,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                margin: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate900 : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: innerCard,
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.readOnly) return cardContent;

    return Builder(
      builder: (anchorContext) {
        return GestureDetector(
          onTap: () {
            PlaceholderDeletePopover.show(
              context: context,
              anchorContext: anchorContext,
              onDelete: widget.onDelete,
            );
          },
          child: cardContent,
        );
      },
    );
  }
}

/// 通用表单输入框（配置名称、描述等）
class ConfigFormInput extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  const ConfigFormInput({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF1a1a2e),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
            filled: true,
            fillColor: isDark ? AppColors.slate700 : Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? AppColors.slate600 : Colors.grey[200]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? AppColors.slate600 : Colors.grey[200]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          onChanged: onChanged,
          validator:
              validator ?? (v) => v?.trim().isEmpty == true ? '必填' : null,
        ),
      ],
    );
  }
}

/// 分类选择 Chips
class CategoryChips extends StatelessWidget {
  final List<KeyConfigCategory> categories;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((c) {
        final sel = selectedId == c.id;
        return HoverChip(
          label: c.name,
          selected: sel,
          onTap: () => onSelected(c.id),
        );
      }).toList(),
    );
  }
}

/// 配置类型选择器（自动应用 / 按键绑定）
class ConfigTypeSelector extends StatelessWidget {
  final bool needsKey;
  final ValueChanged<bool> onChanged;

  const ConfigTypeSelector({
    super.key,
    required this.needsKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: HoverTypeOption(
            icon: MdiIcons.autoFix,
            title: '自动应用',
            subtitle: '直接生效，无需选择按键',
            selected: !needsKey,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: HoverTypeOption(
            icon: MdiIcons.keyboardOutline,
            title: '按键绑定',
            subtitle: '需要用户选择绑定按键',
            selected: needsKey,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

/// 插入按键绑定按钮
class InsertPlaceholderButton extends StatelessWidget {
  final VoidCallback onPressed;

  const InsertPlaceholderButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(MdiIcons.keyboardOutline, size: 16),
      label: const Text(
        '插入自定义按键',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// 脚本编辑器
class ScriptEditor extends StatefulWidget {
  final TextEditingController controller;
  final bool needsKey;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  const ScriptEditor({
    super.key,
    required this.controller,
    required this.needsKey,
    this.onChanged,
    this.validator,
  });

  @override
  State<ScriptEditor> createState() => _ScriptEditorState();
}

class _ScriptEditorState extends State<ScriptEditor> {
  late ScrollController _textScrollController;
  late ScrollController _lineScrollController;

  @override
  void initState() {
    super.initState();
    _textScrollController = ScrollController();
    _lineScrollController = ScrollController();

    _textScrollController.addListener(() {
      if (_lineScrollController.hasClients) {
        _lineScrollController.jumpTo(_textScrollController.offset);
      }
    });
  }

  @override
  void dispose() {
    _textScrollController.dispose();
    _lineScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.slate700 : Colors.black87,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : const Color(0xFF252526),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  border: Border(
                    right: BorderSide(
                      color: isDark ? AppColors.slate700 : Colors.black54,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(top: 24),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (context, value, child) {
                    final lineCount = value.text.split('\n').length;
                    return ListView.builder(
                      controller: _lineScrollController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: lineCount > 1000 ? 1000 : lineCount,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            '${index + 1}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              height: 2.2,
                              letterSpacing: 1.0,
                              color: isDark ? Colors.white38 : Colors.grey[600],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  scrollController: _textScrollController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'monospace',
                    color: Color(0xFFF8F8F2),
                    height: 2.2,
                    letterSpacing: 1.0,
                  ),
                  decoration: const InputDecoration(
                    hintText: '输入脚本，例如：bind "v" "+jump"；点击右上角按钮将 v 替换为自定义按键',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                  ),
                  onChanged: widget.onChanged,
                  validator:
                      widget.validator ??
                      (v) {
                        if (v?.trim().isEmpty == true) return '必填';
                        if (widget.needsKey &&
                            !KeyPlaceholderParser.hasPlaceholders(v!)) {
                          return '需要至少一个自定义按键占位符，请点击上方按钮插入';
                        }
                        if (!widget.needsKey &&
                            KeyPlaceholderParser.hasPlaceholders(v!)) {
                          return '当前类型不允许使用自定义按键，请删除占位符或更改类型';
                        }
                        return null;
                      },
                ),
              ),
            ],
          ),
        ),
        if (widget.needsKey) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '点击右上角按钮在脚本中插入自定义按键，使用者应用时可以自行改键，如果不改则使用默认键',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 插入按键占位符对话框的工具方法
class PlaceholderInsertHelper {
  /// 显示插入占位符对话框
  static void showInsertDialog(
    BuildContext context, {
    required TextEditingController scriptController,
    required VoidCallback onInserted,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: isDark ? AppColors.slate800 : null,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    MdiIcons.keyboardOutline,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '插入自定义按键',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : null,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '请用简短的词语描述这个按键的作用。使用者在下载您的配置时，系统会提示他们根据这个描述来绑定自己的按键。',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelCtrl,
                  autofocus: true,
                  style: TextStyle(color: isDark ? Colors.white : null),
                  decoration: InputDecoration(
                    labelText: '按键用途说明 (必填)',
                    hintText: '例如：按键1、切换键等...',
                    filled: true,
                    fillColor: isDark ? AppColors.slate700 : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.slate600 : Colors.grey[300]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.slate600 : Colors.grey[300]!,
                      ),
                    ),
                    prefixIcon: Icon(MdiIcons.tagOutline, size: 18),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: () {
                  if (labelCtrl.text.trim().isNotEmpty) {
                    _doInsert(scriptController, labelCtrl.text.trim());
                    onInserted();
                    Navigator.pop(ctx);
                  } else {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(const SnackBar(content: Text('用途说明不能为空')));
                  }
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('插入'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 在脚本中插入带默认值的占位符
  static void _doInsert(TextEditingController scriptCtrl, String label) {
    final text = scriptCtrl.text;
    final sel = scriptCtrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;

    bool needsPrefixSpace = false;
    if (start > 0) {
      final charBefore = text[start - 1];
      if (charBefore != ' ' && charBefore != '\n' && charBefore != '\t') {
        needsPrefixSpace = true;
      }
    }

    bool needsSuffixSpace = false;
    if (end < text.length) {
      final charAfter = text[end];
      if (charAfter != ' ' && charAfter != '\n' && charAfter != '\t') {
        needsSuffixSpace = true;
      }
    } else {
      // 如果在文本末尾插入，保留后缀空格方便继续输入
      needsSuffixSpace = true;
    }

    final ph = '${needsPrefixSpace ? ' ' : ''}{{KEY:$label}}${needsSuffixSpace ? ' ' : ''}';
    
    final newText = text.replaceRange(start, end, ph);
    final newCursorPos = start + ph.length;

    scriptCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }
}
