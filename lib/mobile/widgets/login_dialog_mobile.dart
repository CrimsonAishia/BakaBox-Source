import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/core.dart';
import 'captcha_dialog_mobile.dart';
import 'qq_login_webview_mobile.dart';

/// 移动端登录对话框
///
/// 支持：
/// - 账号密码登录（含验证码）
/// - QQ快捷登录（全屏WebView）
class LoginDialogMobile extends StatefulWidget {
  const LoginDialogMobile({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LoginDialogMobile(),
    );
  }

  @override
  State<LoginDialogMobile> createState() => _LoginDialogMobileState();
}

class _LoginDialogMobileState extends State<LoginDialogMobile> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _isLoading = false;
  String? _captchaToken;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ToastUtils.showError(context, '请输入用户名和密码');
      return;
    }

    if (_captchaToken == null || _captchaToken!.isEmpty) {
      ToastUtils.showError(context, '请先获取验证码');
      return;
    }

    context.read<AuthBloc>().add(
      AuthLoginRequested(
        username: username,
        password: password,
        captchaToken: _captchaToken,
      ),
    );
  }

  Future<void> _handleGetCaptcha() async {
    final captchaToken = await CaptchaDialogMobile.show(context);

    if (!mounted) return;

    if (captchaToken != null && captchaToken.isNotEmpty) {
      setState(() {
        _captchaToken = captchaToken;
      });
      ToastUtils.showSuccess(context, '验证成功');
    } else {
      ToastUtils.showWarning(context, '验证失败或已取消');
    }
  }

  void _openRegister() {
    launchUrl(
      Uri.parse('https://bbs.zombieden.cn/member.php?mod=zed-reg'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _openForgotPassword() {
    launchUrl(
      Uri.parse(
        'https://bbs.zombieden.cn/member.php?mod=logging&action=login&viewlostpw=1',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  void _openQQLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const QQLoginWebViewMobile(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          Navigator.of(context).pop();
          ToastUtils.showSuccess(context, '登录成功');
        } else if (state.status == AuthStatus.error &&
            state.errorMessage != null) {
          ToastUtils.showError(context, state.errorMessage!);
        }

        setState(() {
          _isLoading = state.status == AuthStatus.loading;
          if (state.status == AuthStatus.error) {
            _captchaToken = null;
          }
        });
      },
      builder: (context, state) {
        return AnimatedPadding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 顶部拖拽指示器
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // 标题
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '关联论坛账户',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 隐私提示
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0080FF).withValues(alpha: 0.1),
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
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
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
                      focusNode: _usernameFocusNode,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                      decoration: InputDecoration(
                        labelText: '用户名',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 密码输入
                    TextField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      enabled: !_isLoading,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleLogin(),
                      decoration: InputDecoration(
                        labelText: '密码',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 忘记密码链接
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _openForgotPassword,
                        child: Text(
                          '忘记密码？',
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 获取验证码按钮
                    SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _handleGetCaptcha,
                        icon: Icon(
                          _captchaToken != null
                              ? Icons.check_circle
                              : Icons.security,
                          size: 18,
                          color: _captchaToken != null ? Colors.green : null,
                        ),
                        label: Text(
                          _captchaToken != null ? '验证码已获取' : '获取验证码',
                          style: TextStyle(
                            fontSize: 14,
                            color: _captchaToken != null ? Colors.green : null,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _captchaToken != null
                                ? Colors.green
                                : theme.colorScheme.outline,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 登录按钮（验证码是必须的，没有验证码时禁用）
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (_isLoading ||
                                _captchaToken == null ||
                                _captchaToken!.isEmpty)
                            ? null
                            : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0080FF),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFF0080FF).withValues(alpha: 0.3),
                          disabledForegroundColor:
                              Colors.white.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                '登录',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 分隔线
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '或',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // QQ登录按钮
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _openQQLogin,
                        icon: Image.asset(
                          'assets/icons/qq.png',
                          width: 24,
                          height: 24,
                        ),
                        label: const Text(
                          'QQ 快捷登录',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 注册链接
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '还没有账号？',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _openRegister,
                          child: Text(
                            '立即注册',
                            style: TextStyle(color: theme.colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
