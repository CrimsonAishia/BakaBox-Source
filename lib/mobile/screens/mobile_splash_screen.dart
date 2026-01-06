import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../core/core.dart';
import '../router/mobile_router.dart';

/// 移动端启动屏幕
class MobileSplashScreen extends StatefulWidget {
  const MobileSplashScreen({super.key});

  @override
  State<MobileSplashScreen> createState() => _MobileSplashScreenState();
}

class _MobileSplashScreenState extends State<MobileSplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _glowController;
  late AnimationController _exitController;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);
    _glowController = AnimationController(duration: const Duration(milliseconds: 3000), vsync: this);
    _exitController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _logoController.forward();
    _glowController.repeat(reverse: true);

    // 检查更新
    if (mounted) {
      try {
        final updateBloc = context.read<UpdateBloc>();
        updateBloc.add(UpdateAutoCheck());
        await updateBloc.stream.firstWhere(
          (state) => state.status != UpdateStatus.checking,
          orElse: () => updateBloc.state,
        ).timeout(const Duration(milliseconds: 1500), onTimeout: () => updateBloc.state);
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      _exitController.forward();
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) context.go(MobileRoutes.home);
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _glowController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _exitController,
        builder: (context, child) {
          return Transform.scale(
            scale: Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic)).value,
            child: Opacity(
              opacity: Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _exitController, curve: Curves.easeOut)).value,
              child: Stack(
                children: [
                  // 渐变背景
                  _GradientBackground(isDark: isDark),
                  // 浮动图标
                  const _FloatingIcons(),
                  // Logo 和加载指示器
                  _buildContent(context, size, isDark),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _buildContent(BuildContext context, Size size, bool isDark) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // 亮色模式用深色文字/loading，暗色模式用浅色
    final loadingColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E88E5);
    final textColor = isDark ? Colors.white60 : const Color(0xFF546E7A);
    
    return Stack(
      children: [
        // Logo - 移动端位置稍微靠上
        Positioned(
          top: size.height * 0.32,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Transform.scale(
                  scale: Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.elasticOut)).value,
                  child: Opacity(
                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.8, curve: Curves.easeOut))).value,
                    child: AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        return Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E88E5).withValues(alpha: 0.3 + 0.2 * _glowController.value),
                                blurRadius: 16 + 8 * _glowController.value,
                                spreadRadius: 4 + 2 * _glowController.value,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 110,
                              height: 110,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 110,
                                height: 110,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                child: const Icon(Icons.apps, size: 55, color: Color(0xFF1976D2)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // 加载指示器 - 适配安全区域
        Positioned(
          bottom: 80 + bottomPadding,
          left: 0,
          right: 0,
          child: Center(
            child: Column(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(loadingColor)),
                ).animate(delay: 1500.ms).fadeIn(duration: 600.ms),
                const SizedBox(height: 10),
                Text(
                  '正在启动...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontSize: 13,
                      ),
                ).animate(delay: 1500.ms).fadeIn(duration: 600.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


/// 渐变背景组件
class _GradientBackground extends StatelessWidget {
  final bool isDark;
  const _GradientBackground({required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (isDark) {
      // 夜间模式：深蓝紫色星空渐变 + 星星点缀
      return Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0D1B2A), // 深夜蓝
                  Color(0xFF1B263B), // 深蓝灰
                  Color(0xFF2D1B4E), // 深紫
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // 星星点缀
          ..._buildStars(),
        ],
      );
    } else {
      // 白天模式：清新蓝青渐变
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE3F2FD), // 浅蓝
              Color(0xFFE0F7FA), // 浅青
              Color(0xFFEDE7F6), // 浅紫
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
      );
    }
  }

  List<Widget> _buildStars() {
    // 生成随机星星
    final stars = <Widget>[];
    final positions = [
      [0.1, 0.08], [0.85, 0.12], [0.25, 0.22], [0.7, 0.18],
      [0.15, 0.35], [0.9, 0.32], [0.4, 0.45], [0.6, 0.52],
      [0.08, 0.6], [0.75, 0.65], [0.3, 0.72], [0.55, 0.78],
    ];
    for (var i = 0; i < positions.length; i++) {
      final size = (i % 3 == 0) ? 2.0 : 1.5;
      final opacity = (i % 2 == 0) ? 0.6 : 0.4;
      stars.add(
        Positioned(
          left: positions[i][0] * 400,
          top: positions[i][1] * 800,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.3),
                  blurRadius: 2,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return stars;
  }
}

/// 浮动图标组件 - 移动端适配：更少图标、更小尺寸、更靠边缘
class _FloatingIcons extends StatelessWidget {
  const _FloatingIcons();

  @override
  Widget build(BuildContext context) {
    // 移动端只显示3个图标，避免视觉干扰
    return Stack(
      children: [
        _FloatingIcon(emoji: '❄️', size: 28, top: 0.08, left: 0.05, delay: 0),
        _FloatingIcon(emoji: '✨', size: 24, top: 0.18, right: 0.06, delay: 1200),
        _FloatingIcon(emoji: '🌟', size: 22, bottom: 0.22, left: 0.08, delay: 2400),
      ],
    );
  }
}

/// 单个浮动图标
class _FloatingIcon extends StatefulWidget {
  final String emoji;
  final double size;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final int delay;

  const _FloatingIcon({
    required this.emoji,
    required this.size,
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.delay,
  });

  @override
  State<_FloatingIcon> createState() => _FloatingIconState();
}


class _FloatingIconState extends State<_FloatingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 6));
    // 移动端浮动幅度更小，动画更柔和
    _floatAnimation = Tween<double>(begin: 0, end: 10).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _rotateAnimation = Tween<double>(begin: 0, end: 0.05).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned(
      top: widget.top != null ? size.height * widget.top! : null,
      bottom: widget.bottom != null ? size.height * widget.bottom! : null,
      left: widget.left != null ? size.width * widget.left! : null,
      right: widget.right != null ? size.width * widget.right! : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -_floatAnimation.value),
            child: Transform.rotate(
              angle: _rotateAnimation.value * math.pi,
              child: Opacity(opacity: 0.4, child: Text(widget.emoji, style: TextStyle(fontSize: widget.size))),
            ),
          );
        },
      ),
    );
  }
}
