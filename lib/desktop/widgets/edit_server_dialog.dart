import 'package:flutter/material.dart';

/// 编辑服务器对话框返回结果
class EditServerResult {
  final String address;
  final String? nickname;

  EditServerResult({required this.address, this.nickname});
}

/// 编辑服务器对话框
class EditServerDialog extends StatefulWidget {
  final String currentAddress;
  final String? currentNickname;
  final String categoryName;
  final void Function(String newAddress, String? nickname) onConfirm;

  const EditServerDialog({
    super.key,
    required this.currentAddress,
    this.currentNickname,
    required this.categoryName,
    required this.onConfirm,
  });

  @override
  State<EditServerDialog> createState() => _EditServerDialogState();
}

class _EditServerDialogState extends State<EditServerDialog> {
  late TextEditingController _addressController;
  late TextEditingController _nicknameController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.currentAddress);
    _nicknameController = TextEditingController(
      text: widget.currentNickname ?? '',
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  /// 验证服务器地址格式
  bool _validateAddress(String address) {
    final parts = address.split(':');
    if (parts.length != 2) return false;

    final host = parts[0];
    final port = int.tryParse(parts[1]);

    if (port == null || port < 1 || port > 65535) return false;

    // 检查是否为 IP 地址
    final ipParts = host.split('.');
    final isIpAddress =
        ipParts.length == 4 &&
        ipParts.every((part) {
          final num = int.tryParse(part);
          return num != null && num >= 0 && num <= 255;
        });

    if (isIpAddress) return true;

    // 验证域名格式
    final domainPattern = RegExp(
      r'^[a-zA-Z0-9]([a-zA-Z0-9\-\.]*[a-zA-Z0-9])?$',
    );
    return domainPattern.hasMatch(host) &&
        !host.startsWith('.') &&
        !host.startsWith('-') &&
        !host.endsWith('.') &&
        !host.endsWith('-');
  }

  void _onConfirm() {
    final newAddress = _addressController.text.trim();
    final nickname = _nicknameController.text.trim();

    if (newAddress.isEmpty) {
      setState(() => _errorText = '请输入服务器地址');
      return;
    }

    if (!_validateAddress(newAddress)) {
      setState(() => _errorText = '地址格式错误，请使用 地址:端口 格式');
      return;
    }

    // 检查是否有任何变化
    final addressChanged = newAddress != widget.currentAddress;
    final nicknameChanged = nickname != (widget.currentNickname ?? '');

    if (!addressChanged && !nicknameChanged) {
      Navigator.of(context).pop();
      return;
    }

    widget.onConfirm(newAddress, nickname.isEmpty ? null : nickname);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark
        ? Colors.white54
        : const Color(0xFF6B7280);
    final inputBgColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFF9FAFB);
    final borderColor = isDark
        ? const Color(0xFF475569)
        : const Color(0xFFE5E7EB);

    return AlertDialog(
      title: const Text('编辑服务器'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '分类: ${widget.categoryName}',
              style: TextStyle(fontSize: 14, color: secondaryTextColor),
            ),
            const SizedBox(height: 16),
            // 服务器地址
            TextField(
              controller: _addressController,
              autofocus: true,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: '服务器地址',
                labelStyle: TextStyle(color: secondaryTextColor),
                hintText: '例如: 192.168.1.1:27015',
                hintStyle: TextStyle(
                  color: secondaryTextColor.withValues(alpha: 0.6),
                ),
                errorText: _errorText,
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
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              onSubmitted: (_) => _onConfirm(),
            ),
            const SizedBox(height: 16),
            // 备注名
            TextField(
              controller: _nicknameController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: '备注名（可选）',
                labelStyle: TextStyle(color: secondaryTextColor),
                hintText: '给服务器起个名字，方便识别',
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
                  borderSide: const BorderSide(color: Color(0xFF0080FF)),
                ),
                prefixIcon: Icon(
                  Icons.label_outline,
                  color: secondaryTextColor,
                ),
              ),
              maxLength: 30,
              onSubmitted: (_) => _onConfirm(),
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
