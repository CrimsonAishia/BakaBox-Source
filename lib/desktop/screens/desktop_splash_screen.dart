import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/core.dart';
import '../../core/services/onboarding_service.dart';
import '../router/desktop_router.dart';

/// 桌面端启动屏幕 - 简洁快速的启动动画
class DesktopSplashScreen extends StatefulWidget {
  const DesktopSplashScreen({super.key});

  @override
  State<DesktopSplashScreen> createState() => _DesktopSplashScreenState();
}

class _DesktopSplashScreenState extends State<DesktopSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  String _loadingText = 'LOADING';

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _startAnimationAndNavigate();
  }

  Future<void> _startAnimationAndNavigate() async {
    try {
      if (mounted) {
        setState(() => _loadingText = 'INITIALIZING');
      }
      _progressController.animateTo(
        0.3,
        duration: const Duration(milliseconds: 400),
      );
      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        setState(() => _loadingText = 'CHECKING UPDATE');
        final updateBloc = context.read<UpdateBloc>();

        // 开始更新检查
        updateBloc.add(UpdateAutoCheck());

        // 启动进度条动画到60%
        _progressController.animateTo(
          0.6,
          duration: const Duration(milliseconds: 1200),
        );

        // 等待更新检查完成，设置合理的超时时间
        try {
          await updateBloc.stream
              .firstWhere(
                (state) => state.status != UpdateStatus.checking,
                orElse: () => updateBloc.state,
              )
              .timeout(
                const Duration(milliseconds: 1200),
                onTimeout: () {
                  // 超时时记录日志，但不影响启动流程
                  LogService.w('[SplashScreen] 更新检查超时，继续启动流程');
                  return updateBloc.state;
                },
              );
        } catch (e) {
          // 捕获任何异常，确保启动流程不会中断
          LogService.e('[SplashScreen] 更新检查异常: $e', e);
        }

        // 更新检查完成，快速推进到60%
        if (_progressController.value < 0.6) {
          await _progressController.animateTo(
            0.6,
            duration: const Duration(milliseconds: 200),
          );
        }
      }

      if (mounted) {
        setState(() => _loadingText = 'LOADING');
        _progressController.animateTo(
          1.0,
          duration: const Duration(milliseconds: 400),
        );
        await Future.delayed(const Duration(milliseconds: 400));

        // 进度条走完后检查是否需要显示引导
        if (mounted) {
          await _navigateToNextScreen();
        }
      }
    } catch (e) {
      // 出错时快速完成进度条并跳转
      _progressController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 500),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await _navigateToNextScreen();
      }
    }
  }

  /// 根据引导状态导航到下一个页面
  Future<void> _navigateToNextScreen() async {
    final onboardingService = OnboardingService();
    final shouldShowOnboarding = await onboardingService.shouldShowOnboarding();

    if (mounted) {
      if (shouldShowOnboarding) {
        context.go(DesktopRoutes.onboarding);
      } else {
        context.go(DesktopRoutes.home);
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate900 : const Color(0xFFE9EEF8),
      body: Stack(
        children: [
          // 简化的背景光效
          _buildBackgroundGlow(isDark),
          // 主要内容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo + 发光效果
                _buildLogoWithGlow(isDark),
                const SizedBox(height: 32),
                // 应用名称
                _buildAppName(theme, isDark),
                const SizedBox(height: 48),
                // 进度条
                _buildProgressBar(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 简化的背景光效
  Widget _buildBackgroundGlow(bool isDark) {
    return Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.6,
                colors: [
                  const Color(
                    0xFF3B82F6,
                  ).withValues(alpha: isDark ? 0.08 : 0.04),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 2000.ms)
        .then()
        .fadeOut(duration: 2000.ms);
  }

  /// Logo + 发光效果
  Widget _buildLogoWithGlow(bool isDark) {
    return SizedBox(
          width: 160,
          height: 160,
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .custom(
          duration: 2500.ms,
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            final glowIntensity = 0.5 + (value * 0.3);

            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF3B82F6,
                    ).withValues(alpha: glowIntensity * 0.4),
                    blurRadius: 30 + (glowIntensity * 20),
                    spreadRadius: 5 + (glowIntensity * 10),
                  ),
                  BoxShadow(
                    color: const Color(
                      0xFF0080FF,
                    ).withValues(alpha: glowIntensity * 0.3),
                    blurRadius: 50 + (glowIntensity * 30),
                    spreadRadius: 10 + (glowIntensity * 15),
                  ),
                ],
              ),
              child: child,
            );
          },
        )
        .fadeIn(duration: 400.ms)
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1.0, 1.0),
          duration: 400.ms,
          curve: Curves.easeOutBack,
        );
  }

  /// 应用名称
  Widget _buildAppName(ThemeData theme, bool isDark) {
    return Column(
          children: [
            // Logo 图片
            Image.asset(
              'assets/images/sidebar-logo.png',
              height: 72,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 10),
            // 副标题 - 使用灰蓝色
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        (isDark ? AppColors.slate500 : AppColors.slate400)
                            .withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'CS2 LAUNCHER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3.0,
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.3 : 0.15,
                        ),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 20,
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (isDark ? AppColors.slate500 : AppColors.slate400)
                            .withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 300.ms)
        .slideY(
          begin: 0.15,
          end: 0,
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );
  }

  /// 进度条
  Widget _buildProgressBar(bool isDark) {
    return SizedBox(
      width: 200,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              return Stack(
                children: [
                  // 背景轨道
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate700 : AppColors.slate200,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  // 进度条
                  FractionallySizedBox(
                    widthFactor: _progressController.value,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.blue500, AppColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF3B82F6,
                            ).withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          // 加载文字 - 使用点动画
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _loadingText,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.slate500 : AppColors.slate400,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              _buildLoadingDots(isDark),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 500.ms);
  }

  /// 构建加载点动画
  Widget _buildLoadingDots(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 2),
          child:
              Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppColors.slate500 : AppColors.slate400,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .fadeIn(duration: 600.ms, delay: (index * 200).ms)
                  .then()
                  .fadeOut(duration: 600.ms),
        );
      }),
    );
  }
}
