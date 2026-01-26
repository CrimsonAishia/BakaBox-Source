import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  bool _isLoading = true;
  bool _isShaking = false;
  bool _hasResult = false;
  bool _alreadyShaked = false;
  String? _resultMessage;
  int? _rewardAmount;

  // 动画控制器
  late List<AnimationController> _digitControllers;
  final List<int> _displayDigits = [0, 0, 0]; // 显示的三个数字
  bool _showingResult = false;

  @override
  void initState() {
    super.initState();
    _digitControllers = List.generate(
      3,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      ),
    );
    _checkStatusFirst();
  }

  @override
  void dispose() {
    // 停止所有动画
    for (var controller in _digitControllers) {
      if (controller.isAnimating) {
        controller.stop();
      }
      controller.dispose();
    }
    super.dispose();
  }

  /// 检查摇一摇状态
  Future<void> _checkStatusFirst() async {
    try {
      final result = await AuthService.instance.checkShakeStatus();
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (result.alreadyShaked) {
          _alreadyShaked = true;
          _hasResult = true;
          _rewardAmount = result.rewardAmount;
          _resultMessage = result.rewardAmount != null
              ? '今日已获得 ${result.rewardAmount} 僵尸币'
              : '今日已摇过，明天再来吧';
          
          // 显示已获得的奖励金额
          if (_rewardAmount != null) {
            final digits = _splitIntoDigits(_rewardAmount!);
            _displayDigits[0] = digits[0];
            _displayDigits[1] = digits[1];
            _displayDigits[2] = digits[2];
          }
        }
      });

      // 更新 DailyTaskBloc 状态
      if (result.alreadyShaked && mounted) {
        context.read<DailyTaskBloc>().add(
              DailyTaskShakeCompleted(
                  success: true, rewardAmount: result.rewardAmount),
            );
      }
    } catch (e) {
      LogService.e('检查摇一摇状态失败', e);
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.showError(context, '检查状态失败');
      }
    }
  }

  /// 执行摇一摇
  Future<void> _doShake() async {
    if (_isShaking || _alreadyShaked || _hasResult) return;

    setState(() {
      _isShaking = true;
      _hasResult = false;
      _resultMessage = null;
      _rewardAmount = null;
      _showingResult = false;
    });

    _startSlotAnimation();

    try {
      final result = await AuthService.instance.doShake();
      
      if (!mounted) return;

      if (result.success) {
        _rewardAmount = result.rewardAmount;
        _resultMessage = result.message;
        _alreadyShaked = result.alreadyShaked;

        await _stopSlotAnimation();

        if (!mounted) return;

        setState(() {
          _isShaking = false;
          _hasResult = true;
        });

        // 更新 DailyTaskBloc 状态
        context.read<DailyTaskBloc>().add(
              DailyTaskShakeCompleted(
                  success: true, rewardAmount: _rewardAmount),
            );
      } else {
        await _stopSlotAnimation();
        
        if (!mounted) return;
        
        setState(() {
          _isShaking = false;
          _resultMessage = result.message;
        });
        
        ToastUtils.showError(context, result.message);
      }
    } catch (e) {
      LogService.e('摇一摇执行失败', e);
      if (!mounted) return;
      
      await _stopSlotAnimation();
      
      if (!mounted) return;
      
      setState(() {
        _isShaking = false;
        _resultMessage = '摇一摇失败，请重试';
      });
      ToastUtils.showError(context, '摇一摇失败');
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

    // 逐个停止滚动并显示数字（更快的间隔）
    for (int i = 0; i < 3; i++) {
      await Future.delayed(Duration(milliseconds: 200 + i * 150));
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
    // 计算滚动偏移量（更快的滚动速度）
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
            // 老虎机滚动数字显示
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
                    Flexible(
                      child: Text(
                        _resultMessage!,
                        style: TextStyle(
                          color: _rewardAmount != null ? Colors.amber : textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
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
