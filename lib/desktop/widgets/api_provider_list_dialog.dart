import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ApiProviderListDialog extends StatelessWidget {
  const ApiProviderListDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.slate800 : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.gray800;
    final secondaryTextColor = isDark
        ? Colors.white54
        : AppColors.gray500;

    return AlertDialog(
      backgroundColor: bgColor,
      title: Text('选择第三方接口', style: TextStyle(color: textColor)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请选择您要导入的第三方服务器数据源：',
              style: TextStyle(fontSize: 14, color: secondaryTextColor),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.api_rounded, color: Colors.blue),
              title: Text('CS2ZE 接口', style: TextStyle(color: textColor)),
              subtitle: Text(
                'public.cs2ze.org',
                style: TextStyle(color: secondaryTextColor, fontSize: 12),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isDark
                      ? AppColors.slate700
                      : AppColors.gray200,
                ),
              ),
              tileColor: isDark
                  ? AppColors.slate900
                  : AppColors.gray50,
              onTap: () {
                Navigator.of(context).pop('cs2ze');
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
      ],
    );
  }
}
