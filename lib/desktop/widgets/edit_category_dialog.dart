import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 编辑自定义分类对话框
class EditCategoryDialog extends StatefulWidget {
  final String currentName;

  const EditCategoryDialog({super.key, required this.currentName});

  @override
  State<EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<EditCategoryDialog> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.slate800 : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.gray800;
    final secondaryTextColor = isDark ? Colors.white54 : AppColors.gray500;
    final inputBgColor = isDark ? AppColors.slate700 : AppColors.gray50;
    final borderColor = isDark ? AppColors.slate600 : AppColors.gray200;

    return AlertDialog(
      backgroundColor: bgColor,
      title: Text('编辑分类名称', style: TextStyle(color: textColor)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '修改分类的显示名称。',
              style: TextStyle(fontSize: 14, color: secondaryTextColor),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: '分类名称',
                labelStyle: TextStyle(color: secondaryTextColor),
                hintText: '例如：我的服务器',
                hintStyle: TextStyle(
                  color: secondaryTextColor.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: inputBgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                prefixIcon: Icon(
                  Icons.edit_outlined,
                  color: secondaryTextColor,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入分类名称';
                }
                if (value.trim().length < 2) {
                  return '分类名称至少需要 2 个字符';
                }
                if (value.trim().length > 20) {
                  return '分类名称不能超过 20 个字符';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      final newName = _nameController.text.trim();
      // 如果名称没有变化，直接关闭
      if (newName == widget.currentName) {
        Navigator.of(context).pop();
        return;
      }
      Navigator.of(context).pop(newName);
    }
  }
}
