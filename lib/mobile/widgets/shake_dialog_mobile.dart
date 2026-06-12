import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/bloc/daily_task/daily_task_bloc.dart';
import '../../core/bloc/daily_task/daily_task_event.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/log_service.dart';
import '../../core/constants/app_colors.dart';

/// 移动端摇一摇抽奖对话框
class ShakeDialogMobile extends StatefulWidget {
  const ShakeDialogMobile({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ShakeDialogMobile(),
    );
  }

  @override
  State<ShakeDialogMobile> createState() => _ShakeDialogMobileState();
}

class _ShakeDialogMobileState extends State<ShakeDialogMobile>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isShaking = false;
  bool _hasResult = false;
  bool _alreadyShaked = false;
  String? _resultMessage;
  int? _rewardAmount;

  // 动画控制器
  late List<AnimationController> _digitControllers;
  final List<int> _displayDigits = [0, 0, 0];
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
    for (var controller in _digitControllers) {
      if (controller.isAnimating) {
        controller.stop();
      }
      controller.dispose();
    }
    super.dispose();
  }

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

          if (_rewardAmount != null) {
            final digits = _splitIntoDigits(_rewardAmount!);
            _displayDigits[0] = digits[0];
            _displayDigits[1] = digits[1];
            _displayDigits[2] = digits[2];
          }
        }
      });

      if (result.alreadyShaked && mounted) {
        context.read<DailyTaskBloc>().add(
          DailyTaskShakeCompleted(
            success: true,
            rewardAmount: result.rewardAmount,
          ),
        );
      }
    } catch (e) {
      LogService.e('检查摇一摇状态失败', e);
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('检查状态失败', isError: true);
      }
    }
  }

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

        context.read<DailyTaskBloc>().add(
          DailyTaskShakeCompleted(success: true, rewardAmount: _rewardAmount),
        );
      } else {
        await _stopSlotAnimation();

        if (!mounted) return;

        setState(() {
          _isShaking = false;
          _resultMessage = result.message;
        });

        _showSnackBar(result.message, isError: true);
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
      _showSnackBar('摇一摇失败', isError: true);
    }
  }

  void _startSlotAnimation() {
    for (var controller in _digitControllers) {
      controller.repeat();
    }
  }

  Future<void> _stopSlotAnimation() async {
    if (_rewardAmount == null) {
      for (var controller in _digitControllers) {
        controller.stop();
      }
      return;
    }

    setState(() => _showingResult = true);

    final digits = _splitIntoDigits(_rewardAmount!);

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

  List<int> _splitIntoDigits(int number) {
    final hundreds = (number ~/ 100) % 10;
    final tens = (number ~/ 10) % 10;
    final ones = number % 10;
    return [hundreds, tens, ones];
  }

  Widget _buildSlotDigit(int index, bool isDark, Color textColor) {
    final isAnimating = _digitControllers[index].isAnimating;

    return Container(
      width: 50,
      height: 70,
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
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
                maxHeight: 70,
                minHeight: 70,
                alignment: Alignment.topCenter,
                child: AnimatedBuilder(
                  animation: _digitControllers[index],
                  builder: (context, child) {
                    return _buildScrollingNumbers(
                      _digitControllers[index],
                      textColor,
                    );
                  },
                ),
              )
            : Center(
                child: Text(
                  '${_displayDigits[index]}',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: _showingResult ? Colors.amber : textColor,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildScrollingNumbers(
    AnimationController controller,
    Color textColor,
  ) {
    final offset = controller.value * 10 * 70;

    return SizedBox(
      height: 70,
      child: Stack(
        children: [
          Positioned(
            top: -offset,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(20, (i) {
                final digit = i % 10;
                return SizedBox(
                  height: 70,
                  child: Center(
                    child: Text(
                      '$digit',
                      style: TextStyle(
                        fontSize: 40,
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

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : AppColors.emerald500,
      ),
    );
  }

  Future<void> _openInBrowser() async {
    const url =
        'https://bbs.zombieden.cn/plugin.php?id=yinxingfei_zzza:yinxingfei_zzza_hall';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        LogService.d('已在浏览器中打开摇摇乐页面');
      } else {
        if (mounted) {
          _showSnackBar('无法打开浏览器', isError: true);
        }
      }
    } catch (e) {
      LogService.e('打开浏览器失败', e);
      if (mounted) {
        _showSnackBar('打开浏览器失败', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部拖拽指示器
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // 标题
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '摇一摇抽奖',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 老虎机滚动数字显示
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _buildSlotDigit(
                        index,
                        isDark,
                        theme.textTheme.bodyLarge?.color ?? Colors.black,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),

              // 结果消息
              if (_resultMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _rewardAmount != null
                        ? Colors.amber.withValues(alpha: 0.1)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_rewardAmount != null)
                        const Icon(
                          Icons.monetization_on,
                          color: Colors.amber,
                          size: 20,
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _resultMessage!,
                          style: TextStyle(
                            color: _rewardAmount != null
                                ? Colors.amber
                                : theme.textTheme.bodyLarge?.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

              // Loading状态
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 12),
                      Text('正在加载...'),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // 摇一摇按钮
              SizedBox(
                width: double.infinity,
                height: 48,
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
                      : Icon(
                          _alreadyShaked || _hasResult
                              ? Icons.check
                              : Icons.vibration,
                        ),
                  label: Text(
                    _isShaking
                        ? '摇奖中...'
                        : (_alreadyShaked || _hasResult ? '已完成' : '摇一摇'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _alreadyShaked || _hasResult
                        ? Colors.green
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 打开页面按钮
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _openInBrowser,
                  icon: const Icon(Icons.open_in_browser, size: 16),
                  label: const Text('打开页面'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 提示文字
              Text(
                '每日可摇一次，获得随机僵尸币奖励',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
