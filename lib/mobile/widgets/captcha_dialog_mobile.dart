import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 移动端顶象验证码页面
/// 加载论坛登录页面，通过 JS 注入隐藏其他元素只显示验证码，
/// 轮询隐藏字段获取 token
class CaptchaDialogMobile extends StatefulWidget {
  const CaptchaDialogMobile({super.key});

  /// 以全屏页面方式打开验证码，返回 token 或 null
  static Future<String?> show(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const CaptchaDialogMobile(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<CaptchaDialogMobile> createState() => _CaptchaDialogMobileState();
}

class _CaptchaDialogMobileState extends State<CaptchaDialogMobile> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  String? _errorMessage;
  String? _captchaToken;
  Timer? _tokenCheckTimer;
  bool _injected = false;

  // 隐藏页面其他元素，只保留验证码区域的 JS
  static const _injectJs = '''
(function() {
  var captchaDiv = document.getElementById('dx_page_logging_input');
  if (!captchaDiv) return;

  var ancestors = [];
  var el = captchaDiv;
  while (el && el !== document.documentElement) {
    ancestors.push(el);
    el = el.parentElement;
  }

  var bodyChildren = document.body.children;
  for (var i = 0; i < bodyChildren.length; i++) {
    bodyChildren[i].style.setProperty('display', 'none', 'important');
  }

  for (var i = 0; i < ancestors.length; i++) {
    ancestors[i].style.setProperty('display', 'block', 'important');
    ancestors[i].style.setProperty('margin', '0', 'important');
    ancestors[i].style.setProperty('padding', '0', 'important');
    ancestors[i].style.setProperty('border', 'none', 'important');
    ancestors[i].style.setProperty('box-shadow', 'none', 'important');
    ancestors[i].style.setProperty('background', 'transparent', 'important');
    ancestors[i].style.setProperty('width', '100%', 'important');
    ancestors[i].style.setProperty('max-width', '100%', 'important');
    ancestors[i].style.setProperty('position', 'static', 'important');
    ancestors[i].style.setProperty('float', 'none', 'important');
    ancestors[i].style.setProperty('overflow', 'visible', 'important');
  }

  for (var i = 0; i < ancestors.length; i++) {
    var parent = ancestors[i].parentElement;
    if (!parent) continue;
    var siblings = parent.children;
    for (var j = 0; j < siblings.length; j++) {
      if (siblings[j] !== ancestors[i]) {
        siblings[j].style.setProperty('display', 'none', 'important');
      }
    }
  }

  document.body.style.setProperty('background', '#f5f5f5', 'important');
  document.body.style.setProperty('overflow', 'hidden', 'important');
  document.body.style.setProperty('margin', '0', 'important');
  document.body.style.setProperty('padding', '0', 'important');

  var th = captchaDiv.querySelector('th');
  if (th) th.style.setProperty('display', 'none', 'important');

  captchaDiv.style.setProperty('display', 'flex', 'important');
  captchaDiv.style.setProperty('justify-content', 'center', 'important');
  captchaDiv.style.setProperty('align-items', 'center', 'important');
  captchaDiv.style.setProperty('height', '100vh', 'important');
  captchaDiv.style.setProperty('padding', '0 10px', 'important');
  captchaDiv.style.setProperty('background', '#f5f5f5', 'important');
})();
''';

  Future<void> _injectAndStartPolling() async {
    _injected = true;

    // 等待验证码 SDK 初始化
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted || _controller == null) return;

    // 注入 viewport meta 标签，让桌面端 UA 的页面在手机上正常缩放显示
    try {
      await _controller!.evaluateJavascript(source: '''
(function() {
  var meta = document.querySelector('meta[name="viewport"]');
  if (!meta) {
    meta = document.createElement('meta');
    meta.name = 'viewport';
    document.head.appendChild(meta);
  }
  meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes';
})();
''');
    } catch (_) {}

    // 注入 JS 隐藏其他元素
    try {
      await _controller!.evaluateJavascript(source: _injectJs);
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    // 开始轮询 token
    _startTokenPolling();
  }

  void _startTokenPolling() {
    _tokenCheckTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (timer) async {
        if (!mounted || _controller == null) {
          timer.cancel();
          return;
        }
        try {
          final result = await _controller!.evaluateJavascript(source: '''
(function() {
  var el = document.getElementById('dx_captcha_verify_logging');
  if (el && el.value && el.value.length > 10) {
    return el.value;
  }
  return '';
})();
''');

          final token = result?.toString().trim() ?? '';
          if (token.isNotEmpty && token != 'null' && token.length > 10) {
            timer.cancel();
            setState(() {
              _captchaToken = token;
            });
            // 延迟关闭，返回 token
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) {
                Navigator.of(context).pop(_captchaToken);
              }
            });
          }
        } catch (_) {}
      },
    );
  }

  @override
  void dispose() {
    _tokenCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('安全验证'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(_captchaToken),
        ),
        actions: [
          if (_captchaToken != null)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '验证成功',
                    style: TextStyle(color: Colors.green, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _buildContent(theme),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(
              'https://bbs.zombieden.cn/member.php?mod=logging&action=login',
            ),
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            userAgent:
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          ),
          onWebViewCreated: (controller) {
            _controller = controller;
          },
          onLoadStop: (controller, url) {
            if (!_injected) {
              _injectAndStartPolling();
            }
          },
          onReceivedError: (controller, request, error) {
            if (mounted && request.url.toString().contains('bbs.zombieden.cn')) {
              setState(() {
                _errorMessage = '加载验证码失败: ${error.description}';
                _isLoading = false;
              });
            }
          },
        ),
        if (_isLoading)
          Container(
            color: theme.scaffoldBackgroundColor,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在加载验证码...'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
