import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/core.dart';

/// 移动端登录对话框
///
/// 支持：
/// - 账号密码登录
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

    context.read<AuthBloc>().add(
      AuthLoginRequested(username: username, password: password),
    );
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
        builder: (context) => const _QQLoginWebViewPage(),
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

                    // 登录按钮
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0080FF),
                          foregroundColor: Colors.white,
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

/// QQ登录WebView页面（全屏）
class _QQLoginWebViewPage extends StatefulWidget {
  const _QQLoginWebViewPage();

  @override
  State<_QQLoginWebViewPage> createState() => _QQLoginWebViewPageState();
}

class _QQLoginWebViewPageState extends State<_QQLoginWebViewPage> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  double _loadingProgress = 0;
  bool _hasLeftInitialPage = false; // 标记是否已离开初始登录页面（去过QQ授权页）
  bool _loginDetected = false; // 标记是否检测到登录回调
  bool _isExtracting = false; // 标记是否正在提取Cookie
  bool _isCheckingStatus = false; // 防止重复检查登录状态

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        // QQ登录阶段使用iPhone QQ客户端UA
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 QQ/8.9.0',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!_isExtracting) {
              setState(() => _isLoading = true);
            }

            if (!_loginDetected) {
              LogService.d('[QQLogin] URL 变化: $url');

              // 1. 检测是否离开了初始登录页面（跳转到 QQ 登录）
              if (!_hasLeftInitialPage &&
                  (url.contains('graph.qq.com') ||
                      url.contains('ptlogin2.qq.com'))) {
                _hasLeftInitialPage = true;
                LogService.d('[QQLogin] 用户开始 QQ 登录流程');
              }

              // 2. 检测 QQ 登录后的回调页面
              // 必须先离开初始页面，然后再回到论坛，才算登录成功
              if (_hasLeftInitialPage &&
                  url.contains('bbs.zombieden.cn') &&
                  !url.contains('op=init') &&
                  !url.contains('graph.qq.com') &&
                  !url.contains('ptlogin2.qq.com') &&
                  (url.contains('connect.php') ||
                      (url.contains('member.php') &&
                          url.contains('mod=connect')))) {
                // 第一时间进入 loading 状态
                if (!_isExtracting) {
                  LogService.d('[QQLogin] 检测到登录回调，立即显示 loading');
                  setState(() {
                    _isExtracting = true;
                    _loginDetected = true;
                    _isLoading = true;
                  });
                }
              }
            }
          },
          onPageFinished: (url) {
            // 只有在非提取状态才关闭loading，否则保持loading直到处理完成
            if (!_isExtracting) {
              setState(() => _isLoading = false);
            }

            // 如果检测到登录回调，在页面加载完成后执行登录检查（防止重复调用）
            if (_loginDetected && _isExtracting && !_isCheckingStatus) {
              _isCheckingStatus = true;
              LogService.d('[QQLogin] 页面加载完成，开始检查登录状态');
              _checkLoginStatus();
            }
          },
          onProgress: (progress) {
            if (!_isExtracting) {
              setState(() => _loadingProgress = progress / 100);
            }
          },
        ),
      )
      ..loadRequest(
        // 使用论坛QQ互联的登录入口
        Uri.parse(
          'https://bbs.zombieden.cn/connect.php?mod=login&op=init&referer=forum.php&statfrom=login_simple',
        ),
      );
  }

  /// 重置登录检测状态
  void _resetLoginState() {
    if (mounted) {
      setState(() {
        _isExtracting = false;
        _loginDetected = false;
        _hasLeftInitialPage = false;
        _isCheckingStatus = false;
      });
    }
  }

  /// 检查登录状态
  Future<void> _checkLoginStatus() async {
    if (!mounted) return;

    try {
      // 等待页面加载完成
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      // 检查页面内容
      final checkScript = '''
        (function() {
          const html = document.documentElement.innerHTML;
          const url = window.location.href;
          
          // 检查绑定成功提示
          const hasBindSuccess = html.includes('您的账号与QQ账号绑定成功') ||
                                html.includes('绑定成功');
          
          // 检查欢迎回来（已有账号登录成功）
          const hasWelcomeBack = html.includes('欢迎回来');
          
          // 检查绑定账号元素（未绑定的情况）
          const hasBindAccount = html.includes('id="layer_reginfo_t"') &&
                                html.includes('绑定已有账号');
          
          // 检查页面是否加载完整（放宽条件）
          const htmlLower = html.toLowerCase();
          const isPageLoaded = html.length > 200 &&
                              (htmlLower.includes('</html>') ||
                               htmlLower.includes('</body>') ||
                               html.includes('action=logout'));
          
          return JSON.stringify({
            hasBindSuccess: hasBindSuccess,
            hasWelcomeBack: hasWelcomeBack,
            hasBindAccount: hasBindAccount,
            isPageLoaded: isPageLoaded,
            url: url,
            htmlLength: html.length
          });
        })();
      ''';

      final resultStr =
          await _webViewController.runJavaScriptReturningResult(checkScript)
              as String;
      LogService.d('[QQLogin] 页面检测结果: $resultStr');

      // 解析结果（注意：runJavaScriptReturningResult 返回的字符串可能包含转义引号）
      // 使用辅助函数简化判断
      bool containsKey(String str, String key) {
        return str.contains('"$key":true') || str.contains('\\"$key\\":true');
      }

      final hasBindSuccess = containsKey(resultStr, 'hasBindSuccess');
      final hasWelcomeBack = containsKey(resultStr, 'hasWelcomeBack');
      final hasBindAccount = containsKey(resultStr, 'hasBindAccount');
      final isPageLoaded = containsKey(resultStr, 'isPageLoaded');

      // 检查是否显示"绑定成功"或"欢迎回来"提示
      // 这些页面本身就是登录成功的状态，直接提取Cookie
      if (hasBindSuccess || hasWelcomeBack) {
        LogService.d('[QQLogin] 检测到登录成功（${hasBindSuccess ? "绑定成功" : "欢迎回来"}），提取Cookie');
        await _extractCookiesAndLogin();
        return;
      }

      // 检查页面是否加载完整（如果未加载完整，再等待一次）
      if (!isPageLoaded) {
        LogService.w('[QQLogin] 页面未完全加载，等待重试...');
        await Future.delayed(const Duration(milliseconds: 1500));

        if (!mounted) return;

        // 重新检测
        final retryStr =
            await _webViewController.runJavaScriptReturningResult(checkScript)
                as String;
        LogService.d('[QQLogin] 重试检测结果: $retryStr');

        // 重试时也检查绑定成功和欢迎回来
        if (containsKey(retryStr, 'hasBindSuccess') ||
            containsKey(retryStr, 'hasWelcomeBack')) {
          LogService.d('[QQLogin] 重试时检测到登录成功，提取Cookie');
          await _extractCookiesAndLogin();
          return;
        }

        if (!containsKey(retryStr, 'isPageLoaded')) {
          // 仍然未加载完整，显示错误
          _resetLoginState();
          if (mounted) {
            ToastUtils.showError(context, '页面加载异常，请重试');
          }
          return;
        }
      }

      // 优先检查是否是绑定页面（最明确的特征）
      if (hasBindAccount) {
        // QQ 未绑定论坛账号
        LogService.w('[QQLogin] 检测到 QQ 未绑定论坛账号');
        if (mounted) {
          ToastUtils.showInfo(context, 'QQ 未绑定论坛账号，请先在论坛绑定');
          Navigator.of(context).pop();
        }
      } else {
        // 已登录成功，提取 Cookie
        LogService.d('[QQLogin] 检测到已登录状态，提取 Cookie');
        await _extractCookiesAndLogin();
      }
    } catch (e) {
      LogService.e('检查登录状态失败: $e');
      _resetLoginState();
      if (mounted) {
        ToastUtils.showError(context, '检查登录状态失败：$e');
      }
    }
  }

  /// 提取 Cookie 并完成登录
  Future<void> _extractCookiesAndLogin() async {
    if (!mounted) return;

    try {
      LogService.d('[QQLogin] 开始提取 Cookie...');
      
      // 使用原生 MethodChannel 获取所有 Cookie（包括 HttpOnly）
      const channel = MethodChannel('cc.aishia.bakabox/cookie');
      final result = await channel.invokeMethod<List<dynamic>>(
        'getCookies',
        {'url': 'https://bbs.zombieden.cn/'},
      );

      if (result == null || result.isEmpty) {
        LogService.w('[QQLogin] 未获取到任何 Cookie');
        _resetLoginState();
        if (mounted) {
          ToastUtils.showError(context, '未获取到登录信息，请重试');
        }
        return;
      }

      // 转换为 List<Map<String, String>> 格式
      final cookieList = <Map<String, String>>[];
      bool hasAuthCookie = false;

      for (final cookie in result) {
        final cookieMap = cookie as Map<dynamic, dynamic>;
        final name = cookieMap['name'] as String? ?? '';
        final value = cookieMap['value'] as String? ?? '';
        
        if (name.isNotEmpty && value.isNotEmpty) {
          cookieList.add({
            'name': name,
            'value': value,
          });
          
          if (name == 'auth' || name.endsWith('_auth')) {
            hasAuthCookie = true;
          }
        }
      }

      LogService.d('[QQLogin] 提取到的Cookie: ${cookieList.map((c) => c['name']).join(", ")}');
      LogService.d('[QQLogin] 是否包含 auth Cookie: $hasAuthCookie');

      // 检查是否有必需的 auth Cookie
      if (!hasAuthCookie) {
        LogService.w('[QQLogin] 缺少 auth Cookie');
        _resetLoginState();
        if (mounted) {
          ToastUtils.showError(context, '登录信息不完整，请重试');
        }
        return;
      }

      // 触发QQ登录事件
      if (mounted) {
        LogService.i('[QQLogin] 触发 AuthQQLoginRequested 事件');
        context.read<AuthBloc>().add(
          AuthQQLoginRequested(cookies: cookieList),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      LogService.e('[QQLogin] Cookie获取失败: $e');
      _resetLoginState();
      if (mounted) {
        ToastUtils.showError(context, '登录失败：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QQ 登录'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          
          // 顶部加载进度条
          if (_isLoading && !_isExtracting)
            LinearProgressIndicator(
              value: _loadingProgress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          
          // 提取 Cookie 时的全屏遮罩层（完全遮住 WebView）
          if (_isExtracting)
            Container(
              color: bgColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFF0080FF),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '登录成功，正在获取信息...',
                      style: TextStyle(color: textColor),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
