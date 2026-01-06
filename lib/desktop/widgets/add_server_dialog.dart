import 'package:flutter/material.dart';

/// 添加自定义服务器对话框
class AddServerDialog extends StatefulWidget {
  final String categoryName;
  
  const AddServerDialog({
    super.key,
    required this.categoryName,
  });

  @override
  State<AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<AddServerDialog> {
  final TextEditingController _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF6B7280);
    final inputBgColor = isDark ? const Color(0xFF334155) : const Color(0xFFF9FAFB);
    final borderColor = isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB);

    return AlertDialog(
      backgroundColor: bgColor,
      title: Text('添加服务器到 "${widget.categoryName}"', style: TextStyle(color: textColor)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '输入服务器地址（IP:端口），例如：192.168.1.100:27015',
              style: TextStyle(fontSize: 14, color: secondaryTextColor),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              autofocus: true,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: '服务器地址',
                labelStyle: TextStyle(color: secondaryTextColor),
                hintText: '例如：192.168.1.100:27015',
                hintStyle: TextStyle(color: secondaryTextColor.withValues(alpha: 0.6)),
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
                  borderSide: const BorderSide(color: Color(0xFF0080FF)),
                ),
                prefixIcon: Icon(Icons.dns_outlined, color: secondaryTextColor),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入服务器地址';
                }
                
                final address = value.trim();
                
                // 验证格式：IP:端口
                final parts = address.split(':');
                if (parts.length != 2) {
                  return '格式错误，应为 IP:端口';
                }
                
                // 验证 IP
                final ip = parts[0];
                final ipParts = ip.split('.');
                if (ipParts.length != 4) {
                  return 'IP 地址格式错误';
                }
                
                for (final part in ipParts) {
                  final num = int.tryParse(part);
                  if (num == null || num < 0 || num > 255) {
                    return 'IP 地址格式错误';
                  }
                }
                
                // 验证端口
                final port = int.tryParse(parts[1]);
                if (port == null || port < 1 || port > 65535) {
                  return '端口号必须在 1-65535 之间';
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
            backgroundColor: const Color(0xFF0080FF),
            foregroundColor: Colors.white,
          ),
          child: const Text('添加'),
        ),
      ],
    );
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_addressController.text.trim());
    }
  }
}
