import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/core.dart';

/// QQ登录WebView页面（全屏）- 移动端
class QQLoginWebViewMobile extends StatefulWidget {
  const QQLoginWebViewMobile({super.key});

  @override
  State<QQLoginWebViewMobile> createState() => _QQLoginWebViewMobileState();
}

class _QQLoginWebViewMobileState extends State<QQLoginWebViewMobile> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  double _loadingProgress = 0;
  bool _hasLeftInitialPage = false;
  bool _loginDetected = false;
  bool _isExtracting = false;
  bool _isCheckingStatus = false;

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

  void _onUrlChange(String url) {
    if (_isExtracting) return;
    if (_loginDetected) return;

    LogService.d('[QQLogin] URL 变化: $url');

    // 1. 检测是否离开了初始登录页面（跳转到 QQ 登录）
    if (!_hasLeftInitialPage &&
        (url.contains('graph.qq.com') ||
            url.contains('ptlogin2.qq.com'))) {
      _hasLeftInitialPage = true;
      LogService.d('[QQLogin] 用户开始 QQ 登录流程');
    }

    // 2. 检测 QQ 登录后的回调页面
    if (_hasLeftInitialPage &&
        url.contains('bbs.zombieden.cn') &&
        !url.contains('op=init') &&
        !url.contains('graph.qq.com') &&
        !url.contains('ptlogin2.qq.com') &&
        (url.contains('connect.php') ||
            (url.contains('member.php') &&
                url.contains('mod=connect')))) {
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

  /// 检查登录状态
  Future<void> _checkLoginStatus() async {
    if (!mounted || _webViewController == null) return;

    try {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      const checkScript = '''
        (function() {
          const html = document.documentElement.innerHTML;
          const url = window.location.href;
          
          const hasBindSuccess = html.includes('您的账号与QQ账号绑定成功') ||
                                html.includes('绑定成功');
          const hasWelcomeBack = html.includes('欢迎回来');
          const hasBindAccount = html.includes('id="layer_reginfo_t"') &&
                                html.includes('绑定已有账号');
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

      final resultObj = await _webViewController!.evaluateJavascript(source: checkScript);
      final resultStr = resultObj?.toString() ?? '';
      LogService.d('[QQLogin] 页面检测结果: $resultStr');

      bool containsKey(String str, String key) {
        return str.contains('"$key":true') || str.contains('\\"$key\\":true');
      }

      final hasBindSuccess = containsKey(resultStr, 'hasBindSuccess');
      final hasWelcomeBack = containsKey(resultStr, 'hasWelcomeBack');
      final hasBindAccount = containsKey(resultStr, 'hasBindAccount');
      final isPageLoaded = containsKey(resultStr, 'isPageLoaded');

      if (hasBindSuccess || hasWelcomeBack) {
        LogService.d('[QQLogin] 检测到登录成功（${hasBindSuccess ? "绑定成功" : "欢迎回来"}），提取Cookie');
        await _extractCookiesAndLogin();
        return;
      }

      if (!isPageLoaded) {
        LogService.w('[QQLogin] 页面未完全加载，等待重试...');
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;

        final retryObj = await _webViewController!.evaluateJavascript(source: checkScript);
        final retryStr = retryObj?.toString() ?? '';
        LogService.d('[QQLogin] 重试检测结果: $retryStr');

        if (containsKey(retryStr, 'hasBindSuccess') ||
            containsKey(retryStr, 'hasWelcomeBack')) {
          LogService.d('[QQLogin] 重试时检测到登录成功，提取Cookie');
          await _extractCookiesAndLogin();
          return;
        }

        if (!containsKey(retryStr, 'isPageLoaded')) {
          _resetLoginState();
          if (mounted) {
            ToastUtils.showError(context, '页面加载异常，请重试');
          }
          return;
        }
      }

      if (hasBindAccount) {
        LogService.w('[QQLogin] 检测到 QQ 未绑定论坛账号');
        if (mounted) {
          ToastUtils.showInfo(context, 'QQ 未绑定论坛账号，请先在论坛绑定');
          Navigator.of(context).pop();
        }
      } else {
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

      if (!hasAuthCookie) {
        LogService.w('[QQLogin] 缺少 auth Cookie');
        _resetLoginState();
        if (mounted) {
          ToastUtils.showError(context, '登录信息不完整，请重试');
        }
        return;
      }

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
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(
                'https://bbs.zombieden.cn/connect.php?mod=login&op=init&referer=forum.php&statfrom=login_simple',
              ),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              userAgent:
                  'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 QQ/8.9.0',
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStart: (controller, url) {
              if (!_isExtracting) {
                setState(() => _isLoading = true);
              }
              if (url != null) {
                _onUrlChange(url.toString());
              }
            },
            onLoadStop: (controller, url) {
              if (!_isExtracting) {
                setState(() => _isLoading = false);
              }
              if (_loginDetected && _isExtracting && !_isCheckingStatus) {
                _isCheckingStatus = true;
                LogService.d('[QQLogin] 页面加载完成，开始检查登录状态');
                _checkLoginStatus();
              }
            },
            onProgressChanged: (controller, progress) {
              if (!_isExtracting) {
                setState(() => _loadingProgress = progress / 100);
              }
            },
          ),

          // 顶部加载进度条
          if (_isLoading && !_isExtracting)
            LinearProgressIndicator(
              value: _loadingProgress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),

          // 提取 Cookie 时的全屏遮罩层
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
