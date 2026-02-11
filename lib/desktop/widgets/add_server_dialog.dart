import 'package:flutter/material.dart';

/// 添加自定义服务器对话框返回结果
class AddServerResult {
  final String address;
  final String? nickname;
  
  AddServerResult({required this.address, this.nickname});
}

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
  final TextEditingController _nicknameController = TextEditingController();
  final FocusNode _addressFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _addressFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _addressFocusNode.removeListener(_onFocusChange);
    _addressFocusNode.dispose();
    _addressController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  /// 焦点变化时处理
  void _onFocusChange() {
    if (!_addressFocusNode.hasFocus) {
      _formatAddress();
    }
  }

  /// 智能格式化地址：提取服务器地址
  void _formatAddress() {
    final text = _addressController.text;
    if (text.isEmpty) return;
    
    String formatted = text.trim();
    
    // 移除常见的命令前缀
    final commandPrefixes = [
      RegExp(r'^connect\s+', caseSensitive: false),
      RegExp(r'^join\s+', caseSensitive: false),
      RegExp(r'^server\s+', caseSensitive: false),
    ];
    
    for (final pattern in commandPrefixes) {
      if (pattern.hasMatch(formatted)) {
        formatted = formatted.replaceFirst(pattern, '');
        break;
      }
    }
    
    // 2. 移除引号
    formatted = formatted.replaceAll('"', '').replaceAll("'", '');
    
    // 3. 移除多余的空格
    formatted = formatted.replaceAll(RegExp(r'\s+'), '');
    
    // 4. 提取地址:端口格式（支持 IP 和域名）
    // 匹配模式：域名或IP + : + 端口号
    final addressPattern = RegExp(
      r'([a-zA-Z0-9]([a-zA-Z0-9\-\.]*[a-zA-Z0-9])?):(\d+)',
    );
    final match = addressPattern.firstMatch(formatted);
    if (match != null) {
      formatted = match.group(0) ?? formatted;
    }
    
    // 如果格式化后的文本与原文本不同，更新输入框
    if (formatted != text && formatted.isNotEmpty) {
      _addressController.text = formatted;
      // 将光标移到末尾
      _addressController.selection = TextSelection.collapsed(
        offset: formatted.length,
      );
    }
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
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 服务器地址输入
              TextFormField(
                controller: _addressController,
                focusNode: _addressFocusNode,
                autofocus: true,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: '服务器地址 *',
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
                validator: _validateAddress,
              ),
              const SizedBox(height: 16),
              // 备注名输入
              TextFormField(
                controller: _nicknameController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: '备注名（可选）',
                  labelStyle: TextStyle(color: secondaryTextColor),
                  hintText: '给服务器起个名字，方便识别',
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
                  prefixIcon: Icon(Icons.label_outline, color: secondaryTextColor),
                ),
                maxLength: 30,
              ),
            ],
          ),
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

  String? _validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入服务器地址';
    }
    
    final address = value.trim();
                
    // 验证格式：地址:端口
    final parts = address.split(':');
    if (parts.length != 2) {
      return '格式错误，应为 地址:端口';
    }
    
    final host = parts[0];
                
    // 验证主机地址（IP 或域名）
    if (host.isEmpty) {
      return '主机地址不能为空';
    }
    
    // 检查是否为 IP 地址
    final ipParts = host.split('.');
    final isIpAddress = ipParts.length == 4 && 
        ipParts.every((part) {
          final num = int.tryParse(part);
          return num != null && num >= 0 && num <= 255;
        });
    
    // 如果不是 IP 地址，验证域名格式
    if (!isIpAddress) {
      // 域名基本验证：只允许字母、数字、点、连字符
      final domainPattern = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-\.]*[a-zA-Z0-9])?$');
      if (!domainPattern.hasMatch(host)) {
        return '主机地址格式错误（支持 IP 或域名）';
      }
                  
      // 域名不能以点或连字符开头/结尾
      if (host.startsWith('.') || host.startsWith('-') || 
          host.endsWith('.') || host.endsWith('-')) {
        return '域名格式错误';
      }
    }
    
    // 验证端口
    final port = int.tryParse(parts[1]);
    if (port == null || port < 1 || port > 65535) {
      return '端口号必须在 1-65535 之间';
    }
    
    return null;
  }

  void _handleSubmit() {
    // 提交前先格式化一次（防止用户直接点击添加按钮）
    _formatAddress();
    
    if (_formKey.currentState?.validate() ?? false) {
      final nickname = _nicknameController.text.trim();
      Navigator.of(context).pop(AddServerResult(
        address: _addressController.text.trim(),
        nickname: nickname.isEmpty ? null : nickname,
      ));
    }
  }
}
