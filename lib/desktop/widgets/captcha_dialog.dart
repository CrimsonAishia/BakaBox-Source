import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

/// 顶象验证码对话框
/// 加载论坛登录页面，通过 JS 注入隐藏其他元素只显示验证码，
/// 轮询隐藏字段获取 token
class CaptchaDialog extends StatefulWidget {
  const CaptchaDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CaptchaDialog(),
    );
  }

  @override
  State<CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<CaptchaDialog> {
  final _controller = WebviewController();
  bool _isLoading = true;
  String? _errorMessage;
  String? _captchaToken;
  Timer? _tokenCheckTimer;

  // 隐藏页面其他元素，只保留验证码区域的 JS
  // 纯 CSS + 最小 DOM 操作：不移动元素，不破坏事件绑定
  static const _injectJs = '''
(function() {
  // 找到验证码容器
  var captchaDiv = document.getElementById('dx_page_logging_input');
  if (!captchaDiv) return;

  // 从验证码容器向上遍历，收集所有祖先
  var ancestors = [];
  var el = captchaDiv;
  while (el && el !== document.documentElement) {
    ancestors.push(el);
    el = el.parentElement;
  }

  // 隐藏 body 下所有直接子元素
  var bodyChildren = document.body.children;
  for (var i = 0; i < bodyChildren.length; i++) {
    bodyChildren[i].style.setProperty('display', 'none', 'important');
  }

  // 显示祖先链上的所有元素
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

  // 隐藏祖先链上每个元素的兄弟节点
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

  // 设置 body 样式
  document.body.style.setProperty('background', '#f5f5f5', 'important');
  document.body.style.setProperty('overflow', 'hidden', 'important');
  document.body.style.setProperty('margin', '0', 'important');
  document.body.style.setProperty('padding', '0', 'important');

  // 隐藏验证码容器内的 th（"滑块验证:" 文字）
  var th = captchaDiv.querySelector('th');
  if (th) th.style.setProperty('display', 'none', 'important');

  // 让验证码贴底显示
  captchaDiv.style.setProperty('display', 'flex', 'important');
  captchaDiv.style.setProperty('justify-content', 'center', 'important');
  captchaDiv.style.setProperty('align-items', 'flex-end', 'important');
  captchaDiv.style.setProperty('height', '100vh', 'important');
  captchaDiv.style.setProperty('padding', '0 10px 10px 10px', 'important');
  captchaDiv.style.setProperty('background', '#f5f5f5', 'important');
})();
''';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      await _controller.initialize();

      // 监听页面加载完成
      _controller.loadingState.listen((state) {
        if (state == LoadingState.navigationCompleted) {
          // 页面加载完成后注入 JS 隐藏其他元素，并开始轮询 token
          _injectAndStartPolling();
        }
      });

      // 加载论坛登录页面
      await _controller.loadUrl(
        'https://bbs.zombieden.cn/member.php?mod=logging&action=login',
      );
    } catch (e) {
      setState(() {
        _errorMessage = '初始化验证码失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _injectAndStartPolling() async {
    // 等待一小段时间让验证码 SDK 初始化
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // 注入 JS 隐藏其他元素
    try {
      await _controller.executeScript(_injectJs);
    } catch (_) {}

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
        if (!mounted) {
          timer.cancel();
          return;
        }
        try {
          // 检查隐藏字段的值（论坛验证码成功后会写入这个字段）
          final result = await _controller.executeScript('''
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
            // 延迟关闭
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 360,
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '安全验证',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    if (_captchaToken != null)
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '验证成功',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        ],
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(_captchaToken),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // WebView 内容
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
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
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载验证码...'),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Webview(_controller),
    );
  }
}
