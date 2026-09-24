import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/bloc/auth/auth_bloc.dart';
import '../../core/bloc/auth/auth_event.dart';
import '../../core/bloc/auth/auth_state.dart';
import '../../core/utils/toast_utils.dart';
import '../../core/utils/log_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/webview_environment_service.dart';
import '../../core/widgets/app_web_view.dart';

/// 移动端论坛 Web 登录页面
class ForumLoginWebviewMobile extends StatefulWidget {
  const ForumLoginWebviewMobile({super.key});

  @override
  State<ForumLoginWebviewMobile> createState() =>
      _ForumLoginWebviewMobileState();
}

class _ForumLoginWebviewMobileState extends State<ForumLoginWebviewMobile> {
  InAppWebViewController? _webViewController;
  Timer? _loadingTimer;
  bool _isLoading = true;
  bool _isInitialized = false;
  bool _isExtracting = false;
  bool _loginDetected = false;
  bool _isDisposed = false;
  bool _isCssInjected = false;
  Timer? _statusCheckTimer;

  static const String _forumLoginUrl =
      'https://bbs.zombieden.cn/member.php?mod=logging&action=login';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _loadingTimer?.cancel();
    _statusCheckTimer?.cancel();
    _webViewController = null;
    super.dispose();
  }

  void _handleUrlChange(String url) {
    if (!mounted || _loginDetected || _isDisposed) return;
    LogService.d('[ForumLoginMobile] URL 变化: $url');
    _checkLoginStatus();
  }

  Future<void> _initializeWebView() async {
    if (!mounted) return;
    setState(() {
      _isInitialized = true;
      _isLoading = true;
    });

    // 作为一个后备方案，如果一直没有检测到加载完成，4秒后强制取消 Loading 遮罩
    _loadingTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isDisposed && _isLoading) {
        setState(() {
          _isLoading = false;
          _isCssInjected = true; // 强制显示页面
        });
      }
    });

    // 定期检查登录状态，以便能够尽早捕获登录成功事件
    // 同时也会尽早注入 CSS 隐藏无用元素
    _statusCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && !_isDisposed && !_loginDetected) {
        _checkLoginStatus();
      }
    });
  }

  Future<void> _checkLoginStatus() async {
    if (!mounted || _webViewController == null || _isDisposed) return;

    try {
      // 注入 viewport meta 标签，让页面在手机上正常缩放显示
      await _webViewController!.evaluateJavascript(
        source: '''
          (function() {
            var meta = document.querySelector('meta[name="viewport"]');
            if (!meta) {
              meta = document.createElement('meta');
              meta.name = 'viewport';
              document.head.appendChild(meta);
            }
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes';
          })();
        ''',
      );

      final checkScript = '''
        (function() {
          if (typeof document === 'undefined' || !document || !document.documentElement) {
            return JSON.stringify({ hasLogout: false, isPageLoaded: false, url: '' });
          }

          if (!document.getElementById('baka-injected-style')) {
            var style = document.createElement('style');
            style.id = 'baka-injected-style';
            style.innerHTML = `
              /* 隐藏返回按钮、QQ登录按钮、注册与找回密码链接，以及底部可能干扰的导航栏 */
              .mz, .btn_qqlogin, .reg_link, .foot, .foot_height { display: none !important; }
              body { background: transparent !important; min-width: auto !important; overflow-x: hidden !important; }
            `;
            if (document.head) {
              document.head.appendChild(style);
            } else if (document.documentElement) {
              document.documentElement.appendChild(style);
            }
          }

          document.querySelectorAll('.rfm').forEach(rfm => {
            if (rfm.innerHTML.includes('cookietime') || rfm.innerHTML.includes('快捷登录')) {
              rfm.style.setProperty('display', 'none', 'important');
            }
          });

          document.querySelectorAll('a[href*="yinxingfei_zzza"]').forEach(a => {
            let el = a.parentElement;
            if (el && el.parentElement) {
              el.parentElement.style.setProperty('display', 'none', 'important');
            }
          });

          const html = document.documentElement.innerHTML;
          const url = window.location.href || '';
          
          const succeedElement = document.getElementById('main_succeed');
          const isSucceedVisible = succeedElement && succeedElement.style.display !== 'none';
          
          const hasLogout = (html || '').includes('action=logout') || 
                            (html || '').includes('logging&action=logout') ||
                            (html || '').includes('欢迎您回来') ||
                            (html || '').includes('现在将转入登录前页面') ||
                            isSucceedVisible;
          const isPageLoaded = (html || '').length > 200 && 
                               ((html || '').toLowerCase().includes('</html>') || 
                                (html || '').toLowerCase().includes('</body>'));
          return JSON.stringify({
            hasLogout: hasLogout,
            isPageLoaded: isPageLoaded,
            url: url,
            cssInjected: !!document.getElementById('baka-injected-style')
          });
        })();
      ''';

      final result = await _webViewController!.evaluateJavascript(
        source: checkScript,
      );
      if (result != null) {
        final resultStr = result.toString();
        LogService.d('[ForumLoginMobile] 页面检测结果: $resultStr');

        final hasLogout = resultStr.contains('"hasLogout":true');
        final isCssInjected = resultStr.contains('"cssInjected":true');
        final isPageLoaded = resultStr.contains('"isPageLoaded":true');

        if (isCssInjected && isPageLoaded && _isLoading) {
          setState(() {
            _isCssInjected = true;
            _isLoading = false;
          });
        }

        if (hasLogout) {
          LogService.d('[ForumLoginMobile] 检测到已登录状态，开始提取 Cookie');
          if (!_isExtracting) {
            setState(() {
              _isExtracting = true;
              _loginDetected = true;
            });
            await _extractCookiesAndLogin();
          }
        }
      }
    } catch (e) {
      LogService.e('[ForumLoginMobile] 检查登录状态失败', e);
    }
  }

  Future<void> _extractCookiesAndLogin() async {
    if (!mounted || _webViewController == null || _isDisposed) return;

    // 提前获取 AuthBloc 实例，避免 await 之后跨异步访问 context 导致 lint 警告或潜在的上下文丢失
    final authBloc = context.read<AuthBloc>();

    try {
      final cookies = await WebViewEnvironmentService.cookieManager.getCookies(
        url: WebUri('https://bbs.zombieden.cn/'),
      );

      final forumCookies = <Map<String, String>>[];
      bool hasAuthCookie = false;

      for (final cookie in cookies) {
        final name = cookie.name;
        final value = cookie.value;

        if (name.isNotEmpty && value.isNotEmpty) {
          forumCookies.add({'name': name, 'value': value});
          if (name == 'auth' || name.endsWith('_auth')) {
            hasAuthCookie = true;
          }
        }
      }

      if (forumCookies.isEmpty || !hasAuthCookie) {
        throw Exception('Cookie 无效，缺少 auth Cookie');
      }

      if (mounted && !_isDisposed) {
        final completer = Completer<bool>();
        late final StreamSubscription subscription;

        subscription = authBloc.stream.listen((state) {
          if (state.isAuthenticated) {
            if (!completer.isCompleted) {
              completer.complete(true);
              subscription.cancel();
            }
          } else if (state.status == AuthStatus.error) {
            if (!completer.isCompleted) {
              completer.complete(false);
              subscription.cancel();
            }
          }
        });

        authBloc.add(AuthCookieLoginRequested(cookies: forumCookies));

        final success = await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            subscription.cancel();
            return false;
          },
        );

        if (!mounted || _isDisposed) {
          subscription.cancel();
          return;
        }

        if (success) {
          ToastUtils.showSuccess(context, '论坛登录成功');
          Navigator.of(context).pop();
        } else {
          ToastUtils.showError(context, '论坛登录失败，请重试');
          setState(() => _isExtracting = false);
          _loginDetected = false;
        }
      }
    } catch (e) {
      LogService.e('[ForumLoginMobile] 提取 Cookie 失败', e);
      if (mounted && !_isDisposed) {
        ToastUtils.showError(context, '获取登录信息失败，请重试');
        setState(() => _isExtracting = false);
        _loginDetected = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.colorScheme.onSurface;
    final secondaryTextColor = theme.colorScheme.onSurface.withValues(
      alpha: 0.7,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('论坛登录')),
      body: Stack(
        children: [
          if (_isInitialized)
            AppWebView(
              initialSettings: InAppWebViewSettings(
                transparentBackground: true,
              ),
              initialUserScripts: UnmodifiableListView([
                UserScript(
                  source: '''
                    var style = document.createElement('style');
                    style.id = 'baka-injected-style';
                    style.innerHTML = `
                      /* 隐藏返回按钮、QQ登录按钮、注册与找回密码链接，以及底部可能干扰的导航栏 */
                      .mz, .btn_qqlogin, .reg_link, .foot, .foot_height { display: none !important; }
                      body { background: transparent !important; min-width: auto !important; overflow-x: hidden !important; }
                    `;
                    document.documentElement.appendChild(style);
                    
                    document.addEventListener('DOMContentLoaded', function() {
                      document.querySelectorAll('.rfm').forEach(rfm => {
                        if (rfm.innerHTML.includes('cookietime') || rfm.innerHTML.includes('快捷登录')) {
                          rfm.style.setProperty('display', 'none', 'important');
                        }
                      });

                      document.querySelectorAll('a[href*="yinxingfei_zzza"]').forEach(a => {
                        let el = a.parentElement;
                        if (el && el.parentElement) {
                          el.parentElement.style.setProperty('display', 'none', 'important');
                        }
                      });
                    });
                  ''',
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                ),
              ]),
              onWebViewCreated: (controller) async {
                _webViewController = controller;
                try {
                  await WebViewEnvironmentService.cookieManager
                      .deleteAllCookies();
                } catch (e) {
                  LogService.w('[ForumLoginMobile] 清空 Cookie 失败', e);
                }
                if (_isDisposed || !mounted) return;
                await controller.loadUrl(
                  urlRequest: URLRequest(url: WebUri(_forumLoginUrl)),
                );
              },
              onLoadStart: (controller, url) {
                if (url != null) _handleUrlChange(url.toString());
              },
              onUpdateVisitedHistory: (controller, url, isReload) {
                if (url != null) _handleUrlChange(url.toString());
              },
              onLoadStop: (controller, url) {
                if (url != null) _handleUrlChange(url.toString());
              },
            ),

          if (_isLoading || !_isInitialized || !_isCssInjected)
            Container(
              color: bgColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      '正在加载...',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  ],
                ),
              ),
            ),

          if (_isExtracting)
            Container(
              color: bgColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      '登录成功，正在获取信息...',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
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
