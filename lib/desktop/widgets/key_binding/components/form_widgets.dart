import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/models/key_config_models.dart';
import '../../../../core/utils/key_placeholder_parser.dart';
import 'common_widgets.dart';
import '../../../../core/constants/app_colors.dart';

/// 通用表单输入框（配置名称、描述等）
class ConfigFormInput extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  const ConfigFormInput({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
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
        '插入按键绑定',
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
class ScriptEditor extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate700 : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.slate600 : Colors.grey[200]!,
            ),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: isDark ? const Color(0xFFcdd6f4) : AppColors.gray700,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: needsKey ? '输入脚本，使用 {{KEY:名称}} 插入按键占位符' : '输入脚本...',
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey[400],
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: onChanged,
            validator:
                validator ??
                (v) {
                  if (v?.trim().isEmpty == true) return '必填';
                  if (needsKey && !KeyPlaceholderParser.hasPlaceholders(v!)) {
                    return '需包含按键占位符';
                  }
                  return null;
                },
          ),
        ),
        if (needsKey) ...[
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
                    '点击右上角按钮在脚本中插入按键绑定点，使用者可以自己选择按键',
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

/// 占位符标签列表
class PlaceholderTagList extends StatelessWidget {
  final List<KeyPlaceholder> placeholders;
  final TextEditingController scriptController;
  final VoidCallback? onChanged;

  const PlaceholderTagList({
    super.key,
    required this.placeholders,
    required this.scriptController,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(MdiIcons.keyboardOutline, size: 12, color: AppColors.amber500),
            const SizedBox(width: 6),
            Text(
              '已添加的按键占位符',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: placeholders
              .map(
                (p) => PlaceholderTag(
                  label: p.label,
                  onRemove: () {
                    scriptController.text = scriptController.text.replaceAll(
                      '{{KEY:${p.label}}}',
                      '',
                    );
                    onChanged?.call();
                  },
                ),
              )
              .toList(),
        ),
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
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              '插入按键绑定',
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
              '给这个按键位置起个说明，使用者会根据这个说明选择按键',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : null),
              decoration: InputDecoration(
                labelText: '按键说明',
                hintText: '例如：触发键1、触发键2',
                helperText: '将在脚本中插入 {{KEY:按键说明}}',
                helperStyle: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.grey[500],
                ),
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
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  _doInsert(scriptController, v.trim());
                  onInserted();
                  Navigator.pop(ctx);
                }
              },
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
              if (ctrl.text.trim().isNotEmpty) {
                _doInsert(scriptController, ctrl.text.trim());
                onInserted();
                Navigator.pop(ctx);
              }
            },
            icon: const Icon(Icons.check, size: 16),
            label: const Text('插入'),
          ),
        ],
      ),
    );
  }

  /// 在脚本中插入占位符
  static void _doInsert(TextEditingController scriptCtrl, String label) {
    final ph = ' {{KEY:$label}} ';
    final text = scriptCtrl.text;
    final sel = scriptCtrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;

    final newText = text.replaceRange(start, end, ph);
    final newCursorPos = start + ph.length;

    scriptCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }
}
