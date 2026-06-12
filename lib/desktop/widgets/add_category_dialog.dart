import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 添加自定义分类对话框
class AddCategoryDialog extends StatefulWidget {
  const AddCategoryDialog({super.key});

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

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
    final secondaryTextColor = isDark
        ? Colors.white54
        : AppColors.gray500;
    final inputBgColor = isDark
        ? AppColors.slate700
        : AppColors.gray50;
    final borderColor = isDark
        ? AppColors.slate600
        : AppColors.gray200;

    return AlertDialog(
      backgroundColor: bgColor,
      title: Text('添加自定义分类', style: TextStyle(color: textColor)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '创建一个新的服务器分类，用于管理您的自定义服务器。',
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
                  Icons.folder_outlined,
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
          onPressed: () => Navigator.of(context).pop('api_list'),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_download_outlined, size: 16),
              SizedBox(width: 4),
              Text('第三方接口导入'),
            ],
          ),
        ),
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
          child: const Text('添加'),
        ),
      ],
    );
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_nameController.text.trim());
    }
  }
}
