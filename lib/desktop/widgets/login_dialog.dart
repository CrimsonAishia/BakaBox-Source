import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/bloc/auth/auth_bloc.dart';
import '../../core/bloc/auth/auth_event.dart';
import '../../core/bloc/auth/auth_state.dart';
import '../../core/utils/toast_utils.dart';
import 'qq_login_dialog.dart';

/// 关联论坛账户对话框
class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const LoginDialog(),
    );
  }

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _usernameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    super.dispose();
  }

  void _handleBind() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ToastUtils.showWarning(context, '请输入用户名和密码');
      return;
    }

    context.read<AuthBloc>().add(
      AuthLoginRequested(username: username, password: password),
    );
  }

  void _openRegister() {
    launchUrl(Uri.parse('https://bbs.zombieden.cn/member.php?mod=zed-reg'));
  }

  void _openForgotPassword() {
    launchUrl(
      Uri.parse(
        'https://bbs.zombieden.cn/member.php?mod=logging&action=login&viewlostpw=1',
      ),
    );
  }

  void _openQQLogin(BuildContext context) {
    Navigator.of(context).pop();
    QQLoginDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Slate 配色
    final bgColor = isDark
        ? const Color(0xFF1E293B)
        : Colors.white; // slate-800
    final inputBgColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFF1F5F9); // slate-700 / slate-100
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark
        ? Colors.white54
        : const Color(0xFF6B7280);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          Navigator.of(context).pop();
          ToastUtils.showSuccess(context, '关联成功');
        } else if (state.status == AuthStatus.error &&
            state.errorMessage != null) {
          ToastUtils.showError(context, state.errorMessage!);
        }

        setState(() {
          _isLoading = state.status == AuthStatus.loading;
        });
      },
      builder: (context, state) {
        return Dialog(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 标题栏
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '关联论坛账户',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: secondaryTextColor),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 隐私提示
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: inputBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF0080FF).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.security,
                        color: Color(0xFF0080FF),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '您的密码仅用于验证身份，不会被保存',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 用户名输入
                TextField(
                  controller: _usernameController,
                  focusNode: _usernameFocus,
                  enabled: !_isLoading,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: '用户名',
                    labelStyle: TextStyle(color: secondaryTextColor),
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
                  ),
                  onSubmitted: (_) => _handleBind(),
                ),
                const SizedBox(height: 16),

                // 密码输入
                TextField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: true,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: '密码',
                    labelStyle: TextStyle(color: secondaryTextColor),
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
                  ),
                  onSubmitted: (_) => _handleBind(),
                ),
                const SizedBox(height: 12),

                // 注册和忘记密码链接
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _openRegister,
                      child: const Text(
                        '注册账号',
                        style: TextStyle(color: Color(0xFF0080FF)),
                      ),
                    ),
                    Text('|', style: TextStyle(color: borderColor)),
                    TextButton(
                      onPressed: _openForgotPassword,
                      child: const Text(
                        '忘记密码？',
                        style: TextStyle(color: Color(0xFF0080FF)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 关联按钮
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleBind,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0080FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: const Color(
                        0xFF0080FF,
                      ).withValues(alpha: 0.5),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('登录', style: TextStyle(fontSize: 16)),
                  ),
                ),

                // QQ 登录按钮（仅桌面端）
                if (Platform.isWindows) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: Divider(color: borderColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '或',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: borderColor)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _openQQLogin(context),
                      icon: Image.asset(
                        'assets/icons/qq.png',
                        width: 20,
                        height: 20,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.chat_bubble, size: 20),
                      ),
                      label: const Text(
                        'QQ 登录',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
