import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/bloc/auth/auth_bloc.dart';
import '../../core/bloc/auth/auth_event.dart';
import '../../core/bloc/auth/auth_state.dart';
import '../../core/utils/toast_utils.dart';
import '../../core/utils/log_service.dart';

/// QQ WebView 登录对话框
class QQLoginDialog extends StatefulWidget {
  const QQLoginDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const QQLoginDialog(),
    );
  }

  @override
  State<QQLoginDialog> createState() => _QQLoginDialogState();
}

class _QQLoginDialogState extends State<QQLoginDialog> {
  InAppWebViewController? _webViewController;
  Timer? _loadingTimer;
  bool _isLoading = true;
  bool _isInitialized = false;
  bool _loginDetected = false;
  bool _isExtracting = false;
  bool _isDisposed = false; // 标记是否已销毁
  bool _hasLeftInitialPage = false; // 标记是否已离开初始登录页面

  // 论坛的 QQ 登录入口
  static const String _forumQQLoginUrl =
      'https://bbs.zombieden.cn/connect.php?mod=login&op=init&referer=forum.php&statfrom=login_simple';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  @override
  void dispose() {
    _isDisposed = true;

    // 取消定时器
    _loadingTimer?.cancel();
    _loadingTimer = null;

    _webViewController = null;

    super.dispose();
  }

  void _handleUrlChange(String url) {
    if (!mounted || _loginDetected || _isDisposed) return;

    LogService.d('[QQLogin] URL 变化: $url');

    // 1. 检测是否离开了初始登录页面（跳转到 QQ 登录）
    if (!_hasLeftInitialPage &&
        (url.contains('graph.qq.com') || url.contains('ptlogin2.qq.com'))) {
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
            (url.contains('member.php') && url.contains('mod=connect')))) {
      // 第一时间进入 loading 状态，遮住 WebView
      if (!_isExtracting) {
        LogService.d('[QQLogin] 检测到登录回调，立即显示 loading');
        _isExtracting = true;
        _loginDetected = true;

        // 立即触发 UI 更新
        if (mounted) {
          setState(() {});
        }

        // 然后异步执行登录检查
        _checkLoginStatus();
      }
    }
  }

  Future<void> _initializeWebView() async {
    // Initialization is handled by InAppWebView widget
    if (!mounted) return;
    setState(() {
      _isInitialized = true;
      _isLoading = true;
    });

    // 2秒后关闭 loading
    _loadingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_isDisposed) {
        setState(() => _isLoading = false);
      }
    });
  }

  /// 检查登录状态
  Future<void> _checkLoginStatus() async {
    if (!mounted || _webViewController == null || _isDisposed) return;

    try {
      // 等待页面加载完成（增加等待时间）
      await Future.delayed(const Duration(milliseconds: 2500));

      if (_isDisposed || !mounted) return;

      // 检查页面内容和 URL
      final checkScript = '''
        (function() {
          const html = document.documentElement.innerHTML;
          const url = window.location.href;
          
          // 检查退出链接（更精确的检测，避免误判）
          const hasLogout = html.includes('action=logout') ||
                           html.includes('logging&action=logout') ||
                           (html.includes('退出') && html.includes('登录'));
          
          // 检查绑定账号元素（更精确的检测）
          const hasBindAccount = html.includes('id="layer_reginfo_t"') &&
                                html.includes('绑定已有账号');
          
          // 检查是否是 member.php?mod=connect 页面（绑定页面的特征）
          const isMemberConnectPage = url.includes('member.php') &&
                                      url.includes('mod=connect');
          
          // 检查是否显示"绑定成功"提示（此时页面还会跳转）
          const hasBindSuccess = html.includes('您的账号与QQ账号绑定成功') ||
                                html.includes('绑定成功');
          
          // 检查页面是否加载完整（放宽条件，支持更多 HTML 变体）
          const htmlLower = html.toLowerCase();
          const isPageLoaded = html.length > 200 &&
                              (htmlLower.includes('</html>') ||
                               htmlLower.includes('</body>') ||
                               htmlLower.includes('discuz_uid') ||
                               html.includes('action=logout'));
          
          return JSON.stringify({
            hasLogout: hasLogout,
            hasBindAccount: hasBindAccount,
            hasBindSuccess: hasBindSuccess,
            isMemberConnectPage: isMemberConnectPage,
            isPageLoaded: isPageLoaded,
            url: url,
            htmlLength: html.length
          });
        })();
      ''';

      final result = await _webViewController!.evaluateJavascript(source: checkScript);
      if (result != null) {
        final resultStr = result.toString();
        LogService.d('[QQLogin] 页面检测结果: $resultStr');

        // 解析结果
        final hasBindAccount = resultStr.contains('"hasBindAccount":true');
        final hasBindSuccess = resultStr.contains('"hasBindSuccess":true');
        final isMemberConnectPage = resultStr.contains(
          '"isMemberConnectPage":true',
        );
        final hasLogout = resultStr.contains('"hasLogout":true');
        final isPageLoaded = resultStr.contains('"isPageLoaded":true');

        // 检查是否显示"绑定成功"提示，此时页面还会跳转，需要等待
        if (hasBindSuccess) {
          LogService.d('[QQLogin] 检测到绑定成功提示，等待页面跳转...');
          await Future.delayed(const Duration(milliseconds: 3000));

          if (_isDisposed || !mounted) return;

          // 跳转后重新检测
          _checkLoginStatus();
          return;
        }

        // 检查页面是否加载完整（如果未加载完整，再等待一次）
        if (!isPageLoaded) {
          LogService.w('[QQLogin] 页面未完全加载，等待重试...');
          await Future.delayed(const Duration(milliseconds: 2000));

          if (_isDisposed || !mounted) return;

          // 重新检测
          final retryResult = await _webViewController!.evaluateJavascript(
            source: checkScript,
          );
          if (retryResult != null) {
            final retryStr = retryResult.toString();
            LogService.d('[QQLogin] 重试检测结果: $retryStr');

            // 重试时也检查绑定成功
            if (retryStr.contains('"hasBindSuccess":true')) {
              LogService.d('[QQLogin] 重试时检测到绑定成功提示，等待页面跳转...');
              await Future.delayed(const Duration(milliseconds: 3000));

              if (_isDisposed || !mounted) return;

              _checkLoginStatus();
              return;
            }

            final retryLoaded = retryStr.contains('"isPageLoaded":true');
            if (!retryLoaded) {
              // 仍然未加载完整，但如果有 logout 链接说明已登录
              if (retryStr.contains('"hasLogout":true')) {
                LogService.d('[QQLogin] 页面未完全加载但检测到登录状态，继续提取 Cookie');
                await _extractCookiesAndLogin();
                return;
              }

              if (mounted && !_isDisposed) {
                setState(() {
                  _isExtracting = false;
                  _loginDetected = false;
                  _hasLeftInitialPage = false;
                });
                ToastUtils.showError(context, '页面加载异常，请重试');
              }
              return;
            }
          }
        }

        // 优先检查是否是绑定页面（最明确的特征）
        if (hasBindAccount) {
          // QQ 未绑定论坛账号（有明确的绑定元素）
          LogService.w('[QQLogin] 检测到 QQ 未绑定论坛账号（发现绑定元素）');
          if (mounted && !_isDisposed) {
            ToastUtils.showError(context, 'QQ 未绑定论坛账号，请先在论坛绑定');
            Navigator.of(context).pop();
          }
        } else if (isMemberConnectPage && !hasLogout) {
          // 在 member.php?mod=connect 页面但没有退出链接（可能是未绑定且未登录）
          LogService.w('[QQLogin] 检测到 QQ 未绑定论坛账号（在绑定页面且未登录）');
          if (mounted && !_isDisposed) {
            ToastUtils.showError(context, 'QQ 未绑定论坛账号，请先在论坛绑定');
            Navigator.of(context).pop();
          }
        } else if (hasLogout) {
          // 已登录，提取 Cookie
          LogService.d('[QQLogin] 检测到已登录状态，开始提取 Cookie');
          await _extractCookiesAndLogin();
        } else {
          // 登录失败或状态不明确
          LogService.w('[QQLogin] 未检测到登录状态，可能登录失败或被取消');
          if (mounted && !_isDisposed) {
            setState(() {
              _isExtracting = false;
              _loginDetected = false;
              _hasLeftInitialPage = false;
            });
            ToastUtils.showError(context, '登录失败，请重试');
          }
        }
      }
    } catch (e) {
      LogService.e('检查登录状态失败', e);
      if (mounted && !_isDisposed) {
        setState(() {
          _isExtracting = false;
          _loginDetected = false;
          _hasLeftInitialPage = false;
        });
        ToastUtils.showError(context, '检查登录状态失败，请重试');
      }
    }
  }

  /// 提取 Cookie 并完成登录
  Future<void> _extractCookiesAndLogin() async {
    if (!mounted || _webViewController == null || _isDisposed) return;

    try {
      final cookies = await CookieManager.instance().getCookies(
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

      // 调用 AuthBloc 完成登录（用户信息由 AuthService 从服务器获取）
      if (mounted && !_isDisposed) {
        // 监听 AuthBloc 状态变化
        final authBloc = context.read<AuthBloc>();

        // 创建一个 Completer 来等待登录完成
        final completer = Completer<bool>();
        late final StreamSubscription subscription;

        subscription = authBloc.stream.listen((state) {
          if (state.isAuthenticated) {
            // 登录成功
            if (!completer.isCompleted) {
              completer.complete(true);
              subscription.cancel();
            }
          } else if (state.status == AuthStatus.error) {
            // 登录失败
            if (!completer.isCompleted) {
              completer.complete(false);
              subscription.cancel();
            }
          }
        });

        // 触发登录事件
        authBloc.add(AuthQQLoginRequested(cookies: forumCookies));

        // 等待登录完成（最多等待 10 秒）
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
          ToastUtils.showSuccess(context, 'QQ 登录成功');
          Navigator.of(context).pop();
        } else {
          setState(() => _isExtracting = false);
          _loginDetected = false;
          ToastUtils.showError(context, 'QQ 登录失败，请重试');
        }
      }
    } catch (e) {
      LogService.e('提取 Cookie 失败', e);
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
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark
        ? Colors.white54
        : const Color(0xFF6B7280);

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 480,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'QQ 登录',
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

            // WebView 区域
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    if (_isInitialized)
                      InAppWebView(
                        initialUrlRequest: URLRequest(url: WebUri(_forumQQLoginUrl)),
                        initialSettings: InAppWebViewSettings(
                          userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                        ),
                        onWebViewCreated: (controller) {
                          _webViewController = controller;
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
                        onPermissionRequest: (controller, request) async {
                          return PermissionResponse(
                            resources: request.resources,
                            action: PermissionResponseAction.DENY,
                          );
                        },
                      ),

                    // Loading 遮罩
                    if (_isLoading || !_isInitialized)
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
                                '正在加载...',
                                style: TextStyle(color: secondaryTextColor),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 提取 Cookie 遮罩（完全不透明，遮住 WebView）
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
              ),
            ),

            const SizedBox(height: 12),

            // 底部提示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF0080FF),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '使用 QQ 账号登录，登录成功后将自动关联',
                      style: TextStyle(color: secondaryTextColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
