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

class _ShakeDialogState extends State<ShakeDialog>
    with TickerProviderStateMixin {
  windows_webview.WebviewController? _webViewController;
  StreamSubscription? _loadingStateSubscription; // 添加订阅引用
  bool _isLoading = true;
  bool _isShaking = false;
  bool _hasResult = false;
  bool _alreadyShaked = false;
  String? _resultMessage;
  int? _rewardAmount;
  bool _showWebView = false; // 是否显示 WebView
  bool _isDisposed = false; // 标记是否已销毁

  // 动画控制器
  late List<AnimationController> _digitControllers;
  final List<int> _displayDigits = [0, 0, 0]; // 显示的三个数字
  bool _showingResult = false;

  static const String _shakeUrl =
      'https://bbs.zombieden.cn/plugin.php?id=yinxingfei_zzza:yinxingfei_zzza_hall&yjjs=yes';

  @override
  void initState() {
    super.initState();
    _digitControllers = List.generate(
      3,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      ),
    );
    _checkStatusFirst();
  }

  @override
  void dispose() {
    _isDisposed = true;
    
    // 取消 Stream 订阅
    _loadingStateSubscription?.cancel();
    _loadingStateSubscription = null;
    
    // 停止所有动画
    for (var controller in _digitControllers) {
      if (controller.isAnimating) {
        controller.stop();
      }
      controller.dispose();
    }
    
    // 释放 WebView 控制器
    // WebView dispose 会自动清理内部资源，包括 WebView2 实例
    _webViewController?.dispose();
    _webViewController = null;
    
    super.dispose();
  }

  /// 先用 HTTP 检查状态
  Future<void> _checkStatusFirst() async {
    try {
      final result = await AuthService.instance.checkShakeStatus();
      if (!mounted) return;

      if (result.alreadyShaked) {
        setState(() {
          _alreadyShaked = true;
          _rewardAmount = result.rewardAmount;
          _resultMessage = result.rewardAmount != null
              ? '今日已获得 ${result.rewardAmount} 僵尸币'
              : '今日已摇过，明天再来吧';
        });
        // 更新 DailyTaskBloc 状态
        if (mounted) {
          context.read<DailyTaskBloc>().add(
                DailyTaskShakeCompleted(
                    success: true, rewardAmount: result.rewardAmount),
              );
        }
        // 即使已摇过，也初始化 WebView 以便用户查看页面
        _initializeWebView();
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

      // 监听页面加载完成 - 保存订阅引用以便取消
      _loadingStateSubscription = _webViewController!.loadingState.listen((state) {
        if (state == windows_webview.LoadingState.navigationCompleted) {
          // 页面加载完成后，修复浮窗位置
          _fixFloatingBoxPosition();
          
          if (mounted && _isShaking) {
            // 摇一摇后页面刷新，解析结果
            _parseResult();
          }
        }
      });

      if (!mounted) return;
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

  /// 修复浮窗位置
  Future<void> _fixFloatingBoxPosition() async {
    if (_webViewController == null || _isDisposed) return;

    try {
      final fixScript = '''
        (function() {
          var box = document.getElementById('yyl-random-box');
          if (box) {
            box.style.top = '0';
            console.log('已修复浮窗位置');
          }
        })();
      ''';
      await _webViewController!.executeScript(fixScript);
    } catch (e) {
      LogService.e('修复浮窗位置失败', e);
    }
  }

  /// 检查是否可以摇一摇
  Future<void> _checkShakeAvailable() async {
    if (_webViewController == null || _isDisposed) return;

    try {
      final checkScript = '''
        (function() {
          return typeof go_yj === 'function';
        })();
      ''';
      await _webViewController!.executeScript(checkScript);
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
      _showingResult = false;
    });

    _startSlotAnimation();

    try {
      await _webViewController!.executeScript('go_yj();');

      // 等待页面刷新完成（通过 loadingState 监听器触发 _parseResult）
      // 或者超时后强制解析（防止页面没有刷新）
      await Future.delayed(const Duration(seconds: 4));

      // 如果 4 秒后还没有结果，强制解析一次
      if (mounted && !_hasResult) {
        await _parseResult();
      }
    } catch (e) {
      LogService.e('摇一摇执行失败', e);
      if (mounted) {
        _stopSlotAnimation();
        setState(() {
          _isShaking = false;
          _resultMessage = '摇一摇失败，请重试';
        });
      }
    }
  }

  /// 启动老虎机滚动动画
  void _startSlotAnimation() {
    for (var controller in _digitControllers) {
      controller.repeat();
    }
  }

  /// 停止老虎机滚动动画并显示结果
  Future<void> _stopSlotAnimation() async {
    if (_rewardAmount == null) {
      for (var controller in _digitControllers) {
        controller.stop();
      }
      return;
    }

    setState(() => _showingResult = true);

    // 将奖励金额拆分为三位数字
    final digits = _splitIntoDigits(_rewardAmount!);

    // 逐个停止滚动并显示数字
    for (int i = 0; i < 3; i++) {
      await Future.delayed(Duration(milliseconds: 300 + i * 200));
      if (mounted) {
        setState(() {
          _displayDigits[i] = digits[i];
        });
        _digitControllers[i].stop();
      }
    }
  }

  /// 将数字拆分为三位（百位、十位、个位）
  List<int> _splitIntoDigits(int number) {
    final hundreds = (number ~/ 100) % 10;
    final tens = (number ~/ 10) % 10;
    final ones = number % 10;
    return [hundreds, tens, ones];
  }

  /// 构建单个滚动数字
  Widget _buildSlotDigit(int index, bool isDark, Color textColor) {
    final isAnimating = _digitControllers[index].isAnimating;

    return Container(
      width: 60,
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: isAnimating
            ? OverflowBox(
                maxHeight: 80,
                minHeight: 80,
                alignment: Alignment.topCenter,
                child: AnimatedBuilder(
                  animation: _digitControllers[index],
                  builder: (context, child) {
                    return _buildScrollingNumbers(
                        _digitControllers[index], textColor);
                  },
                ),
              )
            : Center(
                child: Text(
                  '${_displayDigits[index]}',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: _showingResult ? Colors.amber : textColor,
                  ),
                ),
              ),
      ),
    );
  }

  /// 构建滚动的数字列表
  Widget _buildScrollingNumbers(
      AnimationController controller, Color textColor) {
    // 计算滚动偏移量
    final offset = controller.value * 10 * 80; // 10个数字，每个高度80

    return SizedBox(
      height: 80,
      child: Stack(
        children: [
          Positioned(
            top: -offset,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(20, (i) {
                // 生成20个数字（重复两次0-9）以实现无缝循环
                final digit = i % 10;
                return SizedBox(
                  height: 80,
                  child: Center(
                    child: Text(
                      '$digit',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// 解析摇一摇结果
  Future<void> _parseResult() async {
    if (_webViewController == null || _hasResult || _isDisposed) return; // 防止重复调用

    try {
      final extractScript = '''
        (function() {
          // 检查是否已经摇过
          var alreadyShaked = document.querySelector('.zzza_hall_bottom_right_yjan_btn11');
          if (alreadyShaked && alreadyShaked.textContent.includes('已经摇过')) {
            return 'ALREADY_SHAKED';
          }
          
          // 提取奖励金额
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

      if (mounted && !_hasResult && !_isDisposed) {
        // 再次检查，防止并发调用
        if (result == 'ALREADY_SHAKED') {
          // 已经摇过
          _resultMessage = '今日已摇过，明天再来吧';
          setState(() {
            _alreadyShaked = true;
          });
        } else if (result != null && result != 'null') {
          _rewardAmount = int.tryParse(result.toString());
          _resultMessage = '恭喜获得 $_rewardAmount 僵尸币！';
        } else {
          _resultMessage = '摇一摇完成';
        }

        await _stopSlotAnimation();

        setState(() {
          _isShaking = false;
          _hasResult = true;
        });

        if (mounted) {
          context.read<DailyTaskBloc>().add(
                DailyTaskShakeCompleted(
                    success: true, rewardAmount: _rewardAmount),
              );
        }
      }
    } catch (e) {
      LogService.e('解析摇一摇结果失败', e);
      if (mounted && !_hasResult && !_isDisposed) {
        await _stopSlotAnimation();
        setState(() {
          _isShaking = false;
          _hasResult = true;
          _resultMessage = '摇一摇完成';
        });
        if (mounted) {
          context
              .read<DailyTaskBloc>()
              .add(const DailyTaskShakeCompleted(success: true));
        }
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
        width: _showWebView ? 1200 : 400,
        height: _showWebView ? 800 : null,
        padding: const EdgeInsets.all(20),
        child: _showWebView
            ? _buildWebViewContent(textColor, secondaryTextColor)
            : _buildMainContent(
                isDark, textColor, secondaryTextColor, bgColor),
      ),
    );
  }

  /// 构建主内容（摇一摇界面）
  Widget _buildMainContent(
      bool isDark, Color textColor, Color secondaryTextColor, Color bgColor) {
    return Column(
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
        // 老虎机滚动数字显示（始终显示）
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF334155)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF0080FF).withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildSlotDigit(
                  index,
                  isDark,
                  textColor,
                ),
              );
            }),
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
        // 添加"打开页面"按钮
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _isLoading || _webViewController == null ? null : () {
              setState(() => _showWebView = true);
            },
            icon: const Icon(Icons.open_in_browser, size: 18),
            label: const Text('打开页面'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0080FF),
              side: const BorderSide(color: Color(0xFF0080FF)),
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
    );
  }

  /// 构建 WebView 内容
  Widget _buildWebViewContent(Color textColor, Color secondaryTextColor) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: textColor),
                  onPressed: () {
                    setState(() => _showWebView = false);
                  },
                  splashRadius: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '摇一摇页面',
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
        const SizedBox(height: 16),
        Expanded(
          child: _webViewController != null
              ? Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: secondaryTextColor.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: windows_webview.Webview(_webViewController!),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                          color: Color(0xFF0080FF)),
                      const SizedBox(height: 16),
                      Text('正在加载页面...',
                          style: TextStyle(color: secondaryTextColor)),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
