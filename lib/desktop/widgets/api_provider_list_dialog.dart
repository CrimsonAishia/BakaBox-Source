import 'package:flutter/material.dart';

class ApiProviderListDialog extends StatelessWidget {
  const ApiProviderListDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark
        ? Colors.white54
        : const Color(0xFF6B7280);

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
                      ? const Color(0xFF334155)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              tileColor: isDark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF9FAFB),
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
