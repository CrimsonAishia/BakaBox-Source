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

/// 论坛 Web 登录对话框
class ForumLoginDialog extends StatefulWidget {
  const ForumLoginDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ForumLoginDialog(),
    );
  }

  @override
  State<ForumLoginDialog> createState() => _ForumLoginDialogState();
}

class _ForumLoginDialogState extends State<ForumLoginDialog> {
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
    LogService.d('[ForumLogin] URL 变化: $url');
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
      final checkScript = '''
        (function() {
          if (typeof document === 'undefined' || !document || !document.documentElement) {
            return JSON.stringify({ hasLogout: false, isPageLoaded: false, url: '' });
          }

          if (!document.getElementById('baka-injected-style')) {
            var style = document.createElement('style');
            style.id = 'baka-injected-style';
            style.innerHTML = `
              body > *:not(#wp):not(#append_parent):not(#ajaxwaitid):not(#baka-injected-style):not([id*="dx"]):not([class*="dx"]):not([id*="captcha"]):not([class*="captcha"]):not([id^="fwin"]):not(iframe) { display: none !important; }
              body { background: transparent !important; padding: 0 !important; margin: 0 !important; min-width: auto !important; overflow-x: hidden !important; }
              #wp { padding: 0 !important; margin: 0 auto !important; width: 100% !important; max-width: 100% !important; box-sizing: border-box !important; }
              .wp { width: 100% !important; min-width: auto !important; }
              #main_message { margin: 0 !important; }
              .bm { border: none !important; margin-bottom: 0 !important; }
              .bm_h { border-top: none !important; }
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
        LogService.d('[ForumLogin] 页面检测结果: $resultStr');

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
          LogService.d('[ForumLogin] 检测到已登录状态，开始提取 Cookie');
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
      LogService.e('[ForumLogin] 检查登录状态失败', e);
    }
  }

  Future<void> _extractCookiesAndLogin() async {
    if (!mounted || _webViewController == null || _isDisposed) return;

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
        final authBloc = context.read<AuthBloc>();
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

        // Reuse the generic cookie login event
        authBloc.add(AuthQQLoginRequested(cookies: forumCookies));

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
          setState(() => _isExtracting = false);
          _loginDetected = false;
          ToastUtils.showError(context, '论坛登录失败，请重试');
        }
      }
    } catch (e) {
      LogService.e('[ForumLogin] 提取 Cookie 失败', e);
      if (mounted && !_isDisposed) {
        ToastUtils.showError(context, '获取登录信息失败，请重试');
        setState(() => _isExtracting = false);
        _loginDetected = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.slate800 : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.gray800;
    final secondaryTextColor = isDark ? Colors.white54 : AppColors.gray500;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 725,
        height: 530,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 24,
                      height: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '论坛登录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: secondaryTextColor),
                  onPressed: () => Navigator.of(context).pop(),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 网页区域
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    if (_isInitialized)
                      AppWebView(
                        initialSettings: InAppWebViewSettings(
                          userAgent:
                              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                          transparentBackground: true,
                        ),
                        initialUserScripts: UnmodifiableListView([
                          UserScript(
                            source: '''
                              var style = document.createElement('style');
                              style.innerHTML = `
                                body > *:not(#wp):not(#append_parent):not(#ajaxwaitid):not(#baka-injected-style):not([id*="dx"]):not([class*="dx"]):not([id*="captcha"]):not([class*="captcha"]):not([id^="fwin"]):not(iframe) { display: none !important; }
                                body { background: transparent !important; padding: 0 !important; margin: 0 !important; min-width: auto !important; overflow-x: hidden !important; }
                                #wp { padding: 0 !important; margin: 0 auto !important; width: 100% !important; max-width: 100% !important; box-sizing: border-box !important; }
                                .wp { width: 100% !important; min-width: auto !important; }
                                #main_message { margin: 0 !important; }
                                .bm { border: none !important; margin-bottom: 0 !important; }
                                .bm_h { border-top: none !important; }
                              `;
                              document.documentElement.appendChild(style);
                              
                              document.addEventListener('DOMContentLoaded', function() {
                                document.querySelectorAll('.rfm').forEach(rfm => {
                                  if (rfm.innerHTML.includes('cookietime') || rfm.innerHTML.includes('快捷登录')) {
                                    rfm.style.setProperty('display', 'none', 'important');
                                  }
                                });
                              });
                            ''',
                            injectionTime:
                                UserScriptInjectionTime.AT_DOCUMENT_START,
                          ),
                        ]),
                        onWebViewCreated: (controller) async {
                          _webViewController = controller;
                          try {
                            await WebViewEnvironmentService.cookieManager
                                .deleteAllCookies();
                          } catch (e) {
                            LogService.w('[ForumLogin] 清空 Cookie 失败', e);
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
                    // If not loading, we still only reveal the webview when CSS is injected
                    if (_isLoading || !_isInitialized || !_isCssInjected)
                      Container(
                        color: bgColor,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
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
                        color: bgColor, // 使背景完全不透明，禁止用户看到后面的内容
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
