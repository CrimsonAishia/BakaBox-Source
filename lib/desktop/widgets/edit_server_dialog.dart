import 'package:flutter/material.dart';

/// 编辑服务器地址对话框
class EditServerDialog extends StatefulWidget {
  final String currentAddress;
  final String categoryName;
  final void Function(String newAddress) onConfirm;

  const EditServerDialog({
    super.key,
    required this.currentAddress,
    required this.categoryName,
    required this.onConfirm,
  });

  @override
  State<EditServerDialog> createState() => _EditServerDialogState();
}

class _EditServerDialogState extends State<EditServerDialog> {
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentAddress);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 验证服务器地址格式 (IP:端口)
  bool _validateAddress(String address) {
    // 基本格式检查：IP:端口
    final regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}:\d{1,5}$');
    if (!regex.hasMatch(address)) {
      return false;
    }
    
    // 检查 IP 各段是否合法
    final parts = address.split(':');
    final ip = parts[0];
    final port = int.tryParse(parts[1]);
    
    // 检查端口范围
    if (port == null || port < 1 || port > 65535) {
      return false;
    }
    
    // 检查 IP 各段范围
    final ipParts = ip.split('.');
    for (final part in ipParts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return false;
      }
    }
    
    return true;
  }

  void _onConfirm() {
    final newAddress = _controller.text.trim();
    
    if (newAddress.isEmpty) {
      setState(() => _errorText = '请输入服务器地址');
      return;
    }
    
    if (!_validateAddress(newAddress)) {
      setState(() => _errorText = '地址格式错误，请使用 IP:端口 格式');
      return;
    }
    
    if (newAddress == widget.currentAddress) {
      Navigator.of(context).pop();
      return;
    }
    
    widget.onConfirm(newAddress);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      title: const Text('编辑服务器地址'),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '分类: ${widget.categoryName}',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '服务器地址',
                hintText: '例如: 192.168.1.1:27015',
                errorText: _errorText,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.dns_outlined),
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              onSubmitted: (_) => _onConfirm(),
            ),
            const SizedBox(height: 8),
            Text(
              '格式: IP地址:端口号',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
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
          onPressed: _onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0080FF),
            foregroundColor: Colors.white,
          ),
          child: const Text('确认'),
        ),
      ],
    );
  }
}
