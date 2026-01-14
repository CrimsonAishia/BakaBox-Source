import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_windows/webview_windows.dart' as windows_webview;
import '../../core/bloc/daily_task/daily_task_bloc.dart';
import '../../core/bloc/daily_task/daily_task_event.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/toast_utils.dart';
import '../../core/utils/log_service.dart';

/// 摇一摇抽奖对话框
class ShakeDialog extends StatefulWidget {
  const ShakeDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ShakeDialog(),
    );
  }

  @override
  State<ShakeDialog> createState() => _ShakeDialogState();
}

class _ShakeDialogState extends State<ShakeDialog> {
  windows_webview.WebviewController? _webViewController;
  bool _isLoading = true;
  bool _isShaking = false;
  bool _hasResult = false;
  bool _alreadyShaked = false;
  String? _resultMessage;
  int? _rewardAmount;

  static const String _shakeUrl =
      'https://bbs.zombieden.cn/plugin.php?id=yinxingfei_zzza:yinxingfei_zzza_hall&yjjs=yes';

  @override
  void initState() {
    super.initState();
    _checkStatusFirst();
  }

  @override
  void dispose() {
    _webViewController?.dispose();
    super.dispose();
  }

  /// 先用 HTTP 检查状态
  Future<void> _checkStatusFirst() async {
    try {
      final result = await AuthService.instance.checkShakeStatus();
      if (!mounted) return;

      if (result.alreadyShaked) {
        setState(() {
          _isLoading = false;
          _alreadyShaked = true;
          _rewardAmount = result.rewardAmount;
          _resultMessage = result.rewardAmount != null
              ? '今日已获得 ${result.rewardAmount} 僵尸币'
              : '今日已摇过，明天再来吧';
        });
        // 更新 DailyTaskBloc 状态
        context.read<DailyTaskBloc>().add(
              DailyTaskShakeCompleted(
                  success: true, rewardAmount: result.rewardAmount),
            );
        return;
      }

      // 可以摇，初始化 WebView
      _initializeWebView();
    } catch (e) {
      LogService.e('检查摇一摇状态失败', e);
      // 出错也尝试初始化 WebView
      _initializeWebView();
    }
  }

  Future<void> _initializeWebView() async {
    try {
      _webViewController = windows_webview.WebviewController();
      await _webViewController!.initialize();

      await _webViewController!.setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );

      // 监听页面加载完成
      _webViewController!.loadingState.listen((state) {
        if (state == windows_webview.LoadingState.navigationCompleted) {
          if (mounted && _isShaking) {
            // 摇一摇后页面刷新，解析结果
            _parseResult();
          }
        }
      });

      setState(() => _isLoading = false);
      await _webViewController!.loadUrl(_shakeUrl);

      // 等待页面加载
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _checkShakeAvailable();
      }
    } catch (e) {
      LogService.e('WebView 初始化失败', e);
      if (mounted) {
        ToastUtils.showError(context, 'WebView 初始化失败');
        Navigator.of(context).pop();
      }
    }
  }

  /// 检查是否可以摇一摇
  Future<void> _checkShakeAvailable() async {
    if (_webViewController == null) return;

    try {
      final checkScript = '''
        (function() {
          return typeof go_yj === 'function';
        })();
      ''';
      final result = await _webViewController!.executeScript(checkScript);
      LogService.d('go_yj 函数存在: $result');
    } catch (e) {
      LogService.e('检查摇一摇状态失败', e);
    }
  }

  /// 执行摇一摇
  Future<void> _doShake() async {
    if (_webViewController == null || _isShaking) return;

    setState(() {
      _isShaking = true;
      _hasResult = false;
      _resultMessage = null;
      _rewardAmount = null;
    });

    try {
      await _webViewController!.executeScript('go_yj();');

      await Future.delayed(const Duration(seconds: 3));

      if (mounted && !_hasResult) {
        await _parseResult();
      }
    } catch (e) {
      LogService.e('摇一摇执行失败', e);
      if (mounted) {
        setState(() {
          _isShaking = false;
          _resultMessage = '摇一摇失败，请重试';
        });
      }
    }
  }

  /// 解析摇一摇结果
  Future<void> _parseResult() async {
    if (_webViewController == null) return;

    try {
      final extractScript = '''
        (function() {
          var input = document.getElementById('zzza_fw1');
          if (input && input.value) {
            return input.value;
          }
          var html = document.body.innerHTML;
          var match = html.match(/zzza_fw1[^>]*value="(\\d+)"/);
          if (match) return match[1];
          return null;
        })();
      ''';

      final result = await _webViewController!.executeScript(extractScript);
      LogService.d('摇一摇结果: $result');

      if (mounted) {
        setState(() {
          _isShaking = false;
          _hasResult = true;
          if (result != null && result != 'null') {
            _rewardAmount = int.tryParse(result.toString());
            _resultMessage = '恭喜获得 $_rewardAmount 僵尸币！';
          } else {
            _resultMessage = '摇一摇完成';
          }
        });

        // 通知 DailyTaskBloc 摇一摇完成
        if (mounted) {
          context.read<DailyTaskBloc>().add(
                DailyTaskShakeCompleted(
                    success: true, rewardAmount: _rewardAmount),
              );
        }
      }
    } catch (e) {
      LogService.e('解析摇一摇结果失败', e);
      if (mounted) {
        setState(() {
          _isShaking = false;
          _hasResult = true;
          _resultMessage = '摇一摇完成';
        });
        context
            .read<DailyTaskBloc>()
            .add(const DailyTaskShakeCompleted(success: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor =
        isDark ? Colors.white54 : const Color(0xFF6B7280);

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '摇一摇抽奖',
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
            const SizedBox(height: 24),
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              transform: _isShaking
                  ? (Matrix4.identity()..rotateZ(0.05))
                  : Matrix4.identity(),
              child: Icon(
                Icons.casino,
                size: 80,
                color: _hasResult && _rewardAmount != null
                    ? Colors.amber
                    : const Color(0xFF0080FF),
              ),
            ),
            const SizedBox(height: 24),
            if (_resultMessage != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _rewardAmount != null
                      ? Colors.amber.withValues(alpha: 0.1)
                      : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_rewardAmount != null)
                      const Icon(Icons.monetization_on,
                          color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _resultMessage!,
                      style: TextStyle(
                        color: _rewardAmount != null ? Colors.amber : textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF0080FF)),
                    const SizedBox(height: 12),
                    Text('正在加载...',
                        style: TextStyle(color: secondaryTextColor)),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed:
                    _isLoading || _isShaking || _alreadyShaked || _hasResult
                        ? null
                        : _doShake,
                icon: _isShaking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_alreadyShaked || _hasResult
                        ? Icons.check
                        : Icons.vibration),
                label: Text(_isShaking
                    ? '摇奖中...'
                    : (_alreadyShaked || _hasResult ? '已完成' : '摇一摇')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _alreadyShaked || _hasResult
                      ? Colors.green
                      : const Color(0xFF0080FF),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _alreadyShaked || _hasResult
                      ? Colors.green.withValues(alpha: 0.7)
                      : const Color(0xFF0080FF).withValues(alpha: 0.5),
                  disabledForegroundColor: Colors.white70,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '每日可摇一次，获得随机僵尸币奖励',
              style: TextStyle(color: secondaryTextColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
