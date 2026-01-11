import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/core.dart';
import '../router/desktop_router.dart';

/// 桌面端启动屏幕 - 简洁快速的启动动画
class DesktopSplashScreen extends StatefulWidget {
  const DesktopSplashScreen({super.key});

  @override
  State<DesktopSplashScreen> createState() => _DesktopSplashScreenState();
}

class _DesktopSplashScreenState extends State<DesktopSplashScreen> with SingleTickerProviderStateMixin {
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
      // 阶段1: 初始化 (0-30%)
      if (mounted) {
        setState(() => _loadingText = 'INITIALIZING');
      }
      _progressController.animateTo(0.3, duration: const Duration(milliseconds: 400));
      await Future.delayed(const Duration(milliseconds: 400));
      
      // 阶段2: 检查更新 (30-80%)
      if (mounted) {
        setState(() => _loadingText = 'CHECKING UPDATE');
        final updateBloc = context.read<UpdateBloc>();
        
        // 开始更新检查
        updateBloc.add(UpdateAutoCheck());
        
        // 启动进度条动画到80%
        _progressController.animateTo(0.8, duration: const Duration(milliseconds: 2000));
        
        // 等待更新检查完成
        await updateBloc.stream.firstWhere(
          (state) => state.status != UpdateStatus.checking,
          orElse: () => updateBloc.state,
        ).timeout(
          const Duration(milliseconds: 2000),
          onTimeout: () => updateBloc.state,
        );
        
        // 更新检查完成，快速推进到80%
        if (_progressController.value < 0.8) {
          await _progressController.animateTo(0.8, duration: const Duration(milliseconds: 200));
        }
      }
      
      // 阶段3: 完成 (80-100%)
      if (mounted) {
        setState(() => _loadingText = 'LOADING');
        _progressController.animateTo(1.0, duration: const Duration(milliseconds: 400));
        await Future.delayed(const Duration(milliseconds: 400));
        
        // 进度条走完后跳转
        if (mounted) {
          context.go(DesktopRoutes.home);
        }
      }
    } catch (e) {
      // 出错时快速完成进度条并跳转
      _progressController.animateTo(1.0, duration: const Duration(milliseconds: 500));
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE9EEF8),
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
              const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.08 : 0.04),
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
    return Container(
      width: 160,
      height: 160,
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
      ),
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
                color: const Color(0xFF3B82F6).withValues(alpha: glowIntensity * 0.4),
                blurRadius: 30 + (glowIntensity * 20),
                spreadRadius: 5 + (glowIntensity * 10),
              ),
              BoxShadow(
                color: const Color(0xFF0080FF).withValues(alpha: glowIntensity * 0.3),
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
        // 主标题 - 使用金色/橙色渐变，与蓝色Logo形成冷暖对比
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: isDark
                ? [
                    const Color(0xFFFBBF24), // 金色
                    const Color(0xFFF59E0B), // 橙色
                    const Color(0xFFEF4444), // 红色
                  ]
                : [
                    const Color(0xFFFCD34D), // 亮金色
                    const Color(0xFFFBBF24), // 金色
                    const Color(0xFFF59E0B), // 橙色
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            AppConstants.appName,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontSize: 38,
              letterSpacing: 2.0,
              height: 1.1,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.7 : 0.4),
                  offset: const Offset(0, 3),
                  blurRadius: 6,
                ),
                Shadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.25),
                  offset: const Offset(0, 6),
                  blurRadius: 12,
                ),
                // 金色发光
                Shadow(
                  color: const Color(0xFFFBBF24).withValues(alpha: isDark ? 0.4 : 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
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
                    (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                        .withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'CS2 SERVER BROWSER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 3.0,
                color: isDark 
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
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
                    (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
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
    .slideY(begin: 0.15, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
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
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                          colors: [Color(0xFF3B82F6), Color(0xFF0080FF)],
                        ),
                        borderRadius: BorderRadius.circular(1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
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
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
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
    )
    .animate()
    .fadeIn(duration: 500.ms, delay: 500.ms);
  }

  /// 构建加载点动画
  Widget _buildLoadingDots(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 2),
          child: Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          )
          .animate(onPlay: (c) => c.repeat())
          .fadeIn(
            duration: 600.ms,
            delay: (index * 200).ms,
          )
          .then()
          .fadeOut(duration: 600.ms),
        );
      }),
    );
  }
}
