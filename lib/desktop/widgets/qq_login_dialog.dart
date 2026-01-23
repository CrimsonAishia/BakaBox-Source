import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_windows/webview_windows.dart' as windows_webview;
import '../../core/bloc/auth/auth_bloc.dart';
import '../../core/bloc/auth/auth_event.dart';
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
  windows_webview.WebviewController? _webViewController;
  StreamSubscription? _urlSubscription; // URL 监听订阅
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
    
    // 取消 URL 订阅
    _urlSubscription?.cancel();
    _urlSubscription = null;
    
    // 释放 WebView 控制器
    _webViewController?.dispose();
    _webViewController = null;
    
    super.dispose();
  }

  Future<void> _initializeWebView() async {
    try {
      _webViewController = windows_webview.WebviewController();
      await _webViewController!.initialize();

      await _webViewController!.setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );

      // 监听 URL 变化事件 - 保存订阅引用以便取消
      _urlSubscription = _webViewController!.url.listen((url) {
        if (!mounted || _loginDetected || _isDisposed) return;
        
        LogService.d('[QQLogin] URL 变化: $url');
        
        // 1. 检测是否离开了初始登录页面（跳转到 QQ 登录）
        if (!_hasLeftInitialPage && 
            (url.contains('graph.qq.com') || url.contains('ptlogin2.qq.com'))) {
          _hasLeftInitialPage = true;
          LogService.d('[QQLogin] 用户开始 QQ 登录流程');
        }
        
        // 2. 只有在用户已经进行过 QQ 登录后，再跳回论坛时才显示 loading
        // 排除：初始登录页、QQ 登录页、论坛首页等非回调页面
        if (_hasLeftInitialPage && 
            url.contains('bbs.zombieden.cn') && 
            !url.contains('op=init') &&
            !url.contains('graph.qq.com') && 
            !url.contains('ptlogin2.qq.com') &&
            url.contains('connect.php')) {  // 确保是 connect.php 回调页面
          
          // 第一时间进入 loading 状态，遮住 WebView
          // 使用同步方式立即更新状态，不等待 setState 的异步调度
          if (!_isExtracting) {
            LogService.d('[QQLogin] 检测到登录回调，立即显示 loading');
            _isExtracting = true;  // 先同步更新标志
            _loginDetected = true;
            
            // 立即触发 UI 更新
            if (mounted) {
              setState(() {});  // 触发重建，此时 _isExtracting 已经是 true
            }
            
            // 然后异步执行登录检查
            _checkLoginStatus();
          }
        }
      });

      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _isLoading = true;
      });

      await _webViewController!.loadUrl(_forumQQLoginUrl);

      // 2秒后关闭 loading
      _loadingTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && !_isDisposed) {
          setState(() => _isLoading = false);
        }
      });
    } catch (e) {
      LogService.e('WebView 初始化失败', e);
      if (mounted && !_isDisposed) {
        setState(() => _isLoading = false);
        ToastUtils.showError(context, 'WebView 初始化失败');
        Navigator.of(context).pop();
      }
    }
  }

  /// 检查登录状态
  Future<void> _checkLoginStatus() async {
    if (!mounted || _webViewController == null || _isDisposed) return;

    try {
      // 等待页面加载完成
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (_isDisposed || !mounted) return;

      // 检查页面是否包含退出链接（已登录标志）
      final checkScript = '''
        (function() {
          const html = document.documentElement.innerHTML;
          const hasLogout = html.includes('action=logout');
          return hasLogout;
        })();
      ''';

      final result = await _webViewController!.executeScript(checkScript);
      if (result != null && result.toString() == 'true') {
        LogService.d('[QQLogin] 检测到已登录状态，开始提取 Cookie');
        await _extractCookiesAndLogin();
      } else {
        LogService.w('[QQLogin] 未检测到登录状态，可能登录失败或被取消');
        if (mounted && !_isDisposed) {
          setState(() {
            _isExtracting = false;
            _loginDetected = false;
            _hasLeftInitialPage = false; // 重置状态，允许用户重试
          });
          ToastUtils.showError(context, '登录失败，请重试');
        }
      }
    } catch (e) {
      LogService.e('检查登录状态失败', e);
      if (mounted && !_isDisposed) {
        setState(() {
          _isExtracting = false;
          _loginDetected = false;
          _hasLeftInitialPage = false; // 重置状态，允许用户重试
        });
        ToastUtils.showError(context, '检查登录状态失败，请重试');
      }
    }
  }

  /// 提取 Cookie 并完成登录
  Future<void> _extractCookiesAndLogin() async {
    if (!mounted || _webViewController == null || _isDisposed) return;

    try {
      // 使用 CDP 获取所有 Cookie（包括 HttpOnly）
      final cookieJson = await _webViewController!.getCookiesForUrl('https://bbs.zombieden.cn/');
      
      if (cookieJson == null || cookieJson.isEmpty) {
        throw Exception('无法获取 Cookie');
      }
      
      final cookieData = jsonDecode(cookieJson) as Map<String, dynamic>;
      final cookies = cookieData['cookies'] as List<dynamic>? ?? [];
      
      final forumCookies = <Map<String, String>>[];
      bool hasAuthCookie = false;
      
      for (final cookie in cookies) {
        final cookieMap = cookie as Map<String, dynamic>;
        final name = cookieMap['name'] as String? ?? '';
        final value = cookieMap['value'] as String? ?? '';
        
        if (name.isNotEmpty && value.isNotEmpty) {
          forumCookies.add({
            'name': name,
            'value': value,
          });
          
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
        context.read<AuthBloc>().add(AuthQQLoginRequested(cookies: forumCookies));
        ToastUtils.showSuccess(context, 'QQ 登录成功');
        Navigator.of(context).pop();
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
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF6B7280);

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
                    if (_isInitialized && _webViewController != null)
                      windows_webview.Webview(_webViewController!),

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
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF0080FF), size: 18),
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
