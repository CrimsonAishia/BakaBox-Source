import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/core.dart';
import '../../core/constants/policy_constants.dart';
import '../../core/services/game_launcher_service.dart';
import '../../core/services/onboarding_service.dart';
import '../../core/services/policy_service.dart';
import '../../core/services/game_path_service.dart';
import '../widgets/captcha_dialog.dart';
import '../widgets/qq_login_dialog.dart';

/// 引导完成回调
typedef OnOnboardingComplete = void Function();

/// 首次启动引导页面
class OnboardingScreen extends StatefulWidget {
  final OnOnboardingComplete onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final OnboardingService _onboardingService = OnboardingService();
  final PolicyService _policyService = PolicyService();
  final GamePathService _gamePathService = GamePathService();
  final GameLauncherService _gameLauncherService = GameLauncherService();

  int _currentPage = 0;
  static const int _totalPages = 4; // 恢复到4页

  // 隐私政策同意状态（在完成页使用）
  bool _agreedToPrivacy = false;
  bool _agreedToTerms = false;

  // 游戏路径设置状态
  String? _gamePath;
  String? _gamePathError;
  bool _isDetectingPath = false;

  // 登录状态
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoggingIn = false;
  String? _captchaToken;

  @override
  void initState() {
    super.initState();
    _loadExistingPath();
  }

  /// 加载已存在的游戏路径
  Future<void> _loadExistingPath() async {
    final path = await _gamePathService.getGamePath();
    if (path != null && path.isNotEmpty) {
      setState(() => _gamePath = path);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 下一页
  Future<void> _nextPage() async {
    // 游戏路径页面：未设置时弹出警告
    if (_currentPage == 1 && _gamePath == null) {
      final confirm = await _showSkipPathWarning();
      if (!confirm) return;
    }

    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// 显示跳过游戏路径设置的警告对话框
  Future<bool> _showSkipPathWarning() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  MdiIcons.alertCircleOutline,
                  color: const Color(0xFFF59E0B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '跳过游戏路径设置？',
                style: TextStyle(
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '未设置游戏路径将导致以下功能无法使用：',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              _buildWarningItem(
                MdiIcons.rocketLaunchOutline,
                '一键加入服务器',
                isDark,
              ),
              const SizedBox(height: 8),
              _buildWarningItem(MdiIcons.accountGroupOutline, '自动挤服', isDark),
              const SizedBox(height: 8),
              _buildWarningItem(MdiIcons.cogOutline, '自动配置游戏参数', isDark),
              const SizedBox(height: 16),
              Text(
                '你可以稍后在「设置」中配置游戏路径。',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                '返回设置',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('仍然跳过'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// 构建警告项
  Widget _buildWarningItem(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFEF4444)),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ],
    );
  }

  /// 上一页
  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// 完成引导
  Future<void> _completeOnboarding() async {
    try {
      // 保存协议同意状态
      await _policyService.agreeToPolicy();
      // 标记引导完成
      await _onboardingService.completeOnboarding();
      if (mounted) {
        widget.onComplete();
      }
    } catch (e) {
      LogService.e('[Onboarding] 完成引导时出错', e);
      // 即使出错也尝试跳转
      if (mounted) {
        widget.onComplete();
      }
    }
  }

  /// 跳过引导
  Future<void> _skipOnboarding() async {
    if (_gamePath == null) {
      final confirm = await _showSkipPathWarning();
      if (!confirm) return;
    }
    try {
      await _onboardingService.skipOnboarding();
      if (mounted) {
        widget.onComplete();
      }
    } catch (e) {
      LogService.e('[Onboarding] 跳过引导时出错', e);
      if (mounted) {
        widget.onComplete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 背景装饰
          _buildBackground(isDark),
          // 主内容
          Column(
            children: [
              // 顶部栏（首页不显示 Logo）
              _buildTopBar(isDark),
              // 页面内容
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    _buildWelcomePage(isDark),
                    _buildGamePathPage(isDark),
                    _buildLoginPage(isDark),
                    _buildCompletePage(isDark),
                  ],
                ),
              ),
              // 底部导航
              _buildBottomNav(isDark),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建背景装饰
  Widget _buildBackground(bool isDark) {
    return Positioned.fill(
      child: CustomPaint(painter: _BackgroundPainter(isDark: isDark)),
    );
  }

  /// 构建顶部栏
  Widget _buildTopBar(bool isDark) {
    // 首页（_currentPage == 0）不显示左上角 Logo
    final showLogo = _currentPage > 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo（首页隐藏，其他页面显示）
            AnimatedOpacity(
              opacity: showLogo ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', width: 32, height: 32),
                  const SizedBox(width: 8),
                  Image.asset(
                    'assets/images/sidebar-logo.png',
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
            // 跳过按钮
            if (_currentPage < _totalPages - 1)
              TextButton(
                onPressed: _skipOnboarding,
                child: Text(
                  '跳过',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== 第一步：欢迎页面 ====================
  Widget _buildWelcomePage(bool isDark) {
    return Row(
      children: [
        // 左侧：品牌视觉
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.fromLTRB(64, 48, 32, 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 大 Logo + 文字 Logo（垂直排列，居中对齐）
                Padding(
                  padding: const EdgeInsets.only(left: 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 大 Logo
                      Image.asset(
                        'assets/images/logo.png',
                        width: 160,
                        height: 160,
                      ),
                      const SizedBox(height: 20),
                      // 文字 Logo
                      Image.asset(
                        'assets/images/sidebar-logo.png',
                        height: 80,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(
                          'BakaBox',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1),
                const SizedBox(height: 12),
                // 描述
                Padding(
                  padding: const EdgeInsets.only(left: 60),
                  child: Text(
                    '一键加入服务器，自动挤服，\n自动配置游戏参数，畅享游戏。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
                ),
                const SizedBox(height: 40),
                // 特性标签
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildFeatureTag(
                      MdiIcons.rocketLaunchOutline,
                      '一键启动',
                      const Color(0xFF3B82F6),
                      isDark,
                      400,
                    ),
                    _buildFeatureTag(
                      MdiIcons.bellRing,
                      '换图通知',
                      const Color(0xFF10B981),
                      isDark,
                      500,
                    ),
                    _buildFeatureTag(
                      MdiIcons.accountGroupOutline,
                      '自动挤服',
                      const Color(0xFFF59E0B),
                      isDark,
                      600,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 右侧：功能预览图
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.fromLTRB(0, 32, 48, 32),
            child: _buildPreviewCard(isDark),
          ),
        ),
      ],
    );
  }

  /// 构建特性标签
  Widget _buildFeatureTag(
    IconData icon,
    String label,
    Color color,
    bool isDark,
    int delay,
  ) {
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.8)
                      : color.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: delay.ms)
        .scale(begin: const Offset(0.9, 0.9));
  }

  /// 构建预览卡片（3D 透视应用截图）
  Widget _buildPreviewCard(bool isDark) {
    return Center(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // 透视效果
              ..rotateY(0.08), // Y轴旋转，正值让图片朝向左边
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  // 主阴影（右侧）
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                    blurRadius: 40,
                    offset: const Offset(20, 20),
                    spreadRadius: -5,
                  ),
                  // 底部阴影
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              // 直接显示图片，不加额外圆角裁剪，保留图片本身的圆角
              child: Image.asset(
                'assets/images/software-pic.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 400,
                  height: 280,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(
                      MdiIcons.imageOff,
                      size: 48,
                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 600.ms, delay: 200.ms)
        .slideX(begin: 0.15, duration: 500.ms);
  }

  // ==================== 第二步：游戏路径设置 ====================
  Widget _buildGamePathPage(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 图标
            Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    MdiIcons.folderCog,
                    size: 48,
                    color: const Color(0xFF10B981),
                  ),
                )
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(begin: const Offset(0.8, 0.8), duration: 500.ms),
            const SizedBox(height: 32),
            // 标题
            Text(
              '设置游戏路径',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
            const SizedBox(height: 12),
            // 副标题
            Text(
              '配置 CS2 游戏目录以启用一键加入功能',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
            const SizedBox(height: 40),
            // 路径设置卡片
            _buildPathSettingCard(isDark),
          ],
        ),
      ),
    );
  }

  /// 构建路径设置卡片
  Widget _buildPathSettingCard(bool isDark) {
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);
    final hasError = _gamePathError != null;

    return Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                  : borderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 路径示例
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          MdiIcons.lightbulbOnOutline,
                          size: 14,
                          color: const Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '路径示例',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'D:\\Steam\\steamapps\\common\\Counter-Strike Global Offensive',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 当前路径显示
              Container(
                width: double.infinity,
                height: 56, // 固定高度
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: hasError
                      ? Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                        )
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      _gamePath != null
                          ? MdiIcons.checkCircle
                          : MdiIcons.folderQuestion,
                      color: _gamePath != null
                          ? const Color(0xFF10B981)
                          : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Tooltip(
                        message: _gamePath ?? '请选择 CS2 游戏根目录',
                        waitDuration: const Duration(milliseconds: 500),
                        child: Text(
                          _gamePath ?? '请选择 CS2 游戏根目录',
                          style: TextStyle(
                            fontSize: 13,
                            color: _gamePath != null
                                ? (isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B))
                                : (isDark
                                      ? Colors.white38
                                      : const Color(0xFF94A3B8)),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_gamePath != null) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          icon: Icon(
                            MdiIcons.close,
                            size: 16,
                            color: isDark
                                ? Colors.white38
                                : const Color(0xFF94A3B8),
                          ),
                          onPressed: () => setState(() {
                            _gamePath = null;
                            _gamePathError = null;
                          }),
                          padding: EdgeInsets.zero,
                          tooltip: '清除',
                          splashRadius: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 错误提示
              if (hasError) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 14,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _gamePathError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: MdiIcons.autoFix,
                      label: '自动检测',
                      isLoading: _isDetectingPath,
                      onPressed: _detectGamePath,
                      isPrimary: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: MdiIcons.folderOpen,
                      label: '手动选择',
                      onPressed: _selectGamePath,
                      isPrimary: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 提示信息
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      MdiIcons.informationOutline,
                      size: 16,
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '请选择包含 game 文件夹的 CS2 根目录。\n此步骤可跳过，稍后在设置中配置。',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 200.ms)
        .slideY(begin: 0.1, duration: 400.ms);
  }

  /// 自动检测游戏路径
  Future<void> _detectGamePath() async {
    setState(() {
      _isDetectingPath = true;
      _gamePathError = null;
    });

    try {
      // 使用 GameLauncherService 的检测方法（有更完善的注册表查询和缓存）
      final path = await _gameLauncherService.detectGamePath();
      if (path != null) {
        await _gamePathService.setGamePath(path);
        setState(() => _gamePath = path);
      } else {
        setState(() => _gamePathError = '未能自动检测到游戏路径，请手动选择');
      }
    } catch (e) {
      setState(() => _gamePathError = '检测失败: $e');
    } finally {
      setState(() => _isDetectingPath = false);
    }
  }

  /// 手动选择游戏路径
  Future<void> _selectGamePath() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择 CS2 游戏根目录',
      );

      if (result != null) {
        final validation = await _gamePathService.validateGamePath(result);
        if (validation.isValid) {
          await _gamePathService.setGamePath(result);
          setState(() {
            _gamePath = result;
            _gamePathError = null;
          });
        } else {
          setState(() => _gamePathError = validation.error);
        }
      }
    } catch (e) {
      setState(() => _gamePathError = '选择路径失败: $e');
    }
  }

  // ==================== 第三步：论坛账号绑定 ====================
  Widget _buildLoginPage(bool isDark) {
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final inputBgColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final secondaryTextColor = isDark
        ? Colors.white54
        : const Color(0xFF64748B);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        setState(() {
          _isLoggingIn = state.status == AuthStatus.loading;
          if (state.status == AuthStatus.error) {
            _captchaToken = null;
          }
        });

        // 登录成功后触发每日任务状态检查
        if (state.isAuthenticated && state.userInfo != null) {
          context.read<DailyTaskBloc>().add(
            const DailyTaskCheckStatusRequested(),
          );
        }
        // 登录成功后不自动跳转，让用户看到成功状态后手动点击下一步
      },
      builder: (context, state) {
        final isLoggedIn = state.status == AuthStatus.authenticated;

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 论坛 Logo
                if (isLoggedIn)
                  Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          MdiIcons.accountCheck,
                          size: 48,
                          color: const Color(0xFF10B981),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .scale(begin: const Offset(0.8, 0.8), duration: 500.ms)
                else
                  Image.asset(
                        'assets/images/zed-logo.png',
                        width: 120,
                        height: 69,
                        errorBuilder: (_, __, ___) => Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF8B5CF6,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            MdiIcons.accountCircle,
                            size: 48,
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .scale(begin: const Offset(0.8, 0.8), duration: 500.ms),
                const SizedBox(height: 32),
                // 标题
                Text(
                  isLoggedIn ? '关联成功' : '关联论坛账号',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                const SizedBox(height: 12),
                // 副标题
                Text(
                  isLoggedIn ? '你已准备好开始使用 BakaBox' : '关联后可解锁更多功能（可选）',
                  style: TextStyle(fontSize: 15, color: secondaryTextColor),
                ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
                const SizedBox(height: 40),
                // 登录表单或成功状态
                if (isLoggedIn)
                  _buildLoginSuccessCard(isDark, state)
                else
                  _buildLoginForm(
                    isDark,
                    bgColor,
                    inputBgColor,
                    textColor,
                    secondaryTextColor,
                    borderColor,
                    state,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建登录成功卡片
  Widget _buildLoginSuccessCard(bool isDark, AuthState state) {
    return Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              // 头像
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                child:
                    state.userInfo?.avatar != null &&
                        state.userInfo!.avatar.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          state.userInfo!.avatar,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            MdiIcons.account,
                            size: 32,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      )
                    : Icon(
                        MdiIcons.account,
                        size: 32,
                        color: const Color(0xFF10B981),
                      ),
              ),
              const SizedBox(height: 16),
              // 用户名
              Text(
                state.userInfo?.username ?? '用户',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              // 用户组
              if (state.userInfo?.userGroup != null) ...[
                const SizedBox(height: 4),
                Text(
                  state.userInfo!.userGroup!,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(begin: const Offset(0.95, 0.95), duration: 300.ms);
  }

  /// 构建登录表单
  Widget _buildLoginForm(
    bool isDark,
    Color bgColor,
    Color inputBgColor,
    Color textColor,
    Color secondaryTextColor,
    Color borderColor,
    AuthState state,
  ) {
    return Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 错误提示
              if (state.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // 用户名输入
              TextField(
                controller: _usernameController,
                enabled: !_isLoggingIn,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: '用户名',
                  labelStyle: TextStyle(color: secondaryTextColor),
                  filled: true,
                  fillColor: inputBgColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                  ),
                  prefixIcon: Icon(
                    MdiIcons.account,
                    color: secondaryTextColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 密码输入
              TextField(
                controller: _passwordController,
                enabled: !_isLoggingIn,
                obscureText: true,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: '密码',
                  labelStyle: TextStyle(color: secondaryTextColor),
                  filled: true,
                  fillColor: inputBgColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                  ),
                  prefixIcon: Icon(
                    MdiIcons.lock,
                    color: secondaryTextColor,
                    size: 20,
                  ),
                ),
                onSubmitted: (_) => _handleLogin(),
              ),
              const SizedBox(height: 12),
              // 获取验证码按钮
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isLoggingIn ? null : _handleGetCaptcha,
                  icon: Icon(
                    _captchaToken != null ? Icons.check_circle : Icons.security,
                    size: 20,
                    color: _captchaToken != null ? Colors.green : null,
                  ),
                  label: Text(
                    _captchaToken != null ? '验证码已获取' : '获取验证码',
                    style: TextStyle(
                      fontSize: 15,
                      color: _captchaToken != null ? Colors.green : null,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(
                      color: _captchaToken != null ? Colors.green : borderColor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 登录按钮
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      (_isLoggingIn ||
                          _captchaToken == null ||
                          _captchaToken!.isEmpty)
                      ? null
                      : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    disabledBackgroundColor: const Color(
                      0xFF8B5CF6,
                    ).withValues(alpha: 0.5),
                  ),
                  child: _isLoggingIn
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '关联账号',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              // QQ 登录（仅 Windows）
              if (Platform.isWindows) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: borderColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '或',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: borderColor)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isLoggingIn
                        ? null
                        : () => QQLoginDialog.show(context),
                    icon: Image.asset(
                      'assets/icons/qq.png',
                      width: 20,
                      height: 20,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.chat_bubble, size: 20),
                    ),
                    label: const Text('QQ 登录', style: TextStyle(fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 200.ms)
        .slideY(begin: 0.1, duration: 400.ms);
  }

  /// 处理登录
  void _handleLogin() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ToastUtils.showWarning(context, '请输入用户名和密码');
      return;
    }

    if (_captchaToken == null || _captchaToken!.isEmpty) {
      ToastUtils.showWarning(context, '请先获取验证码');
      return;
    }

    context.read<AuthBloc>().add(
      AuthLoginRequested(
        username: username,
        password: password,
        captchaToken: _captchaToken,
      ),
    );
  }

  Future<void> _handleGetCaptcha() async {
    final captchaToken = await CaptchaDialog.show(context);

    if (!mounted) return;

    if (captchaToken != null && captchaToken.isNotEmpty) {
      setState(() {
        _captchaToken = captchaToken;
      });
      ToastUtils.showSuccess(context, '验证成功');
    } else {
      ToastUtils.showWarning(context, '验证失败或已取消');
    }
  }

  // ==================== 第四步：完成页面（含隐私政策同意） ====================
  Widget _buildCompletePage(bool isDark) {
    // 检查是否已同意协议
    final canComplete = _agreedToPrivacy && _agreedToTerms;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 成功图标
            Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF10B981).withValues(alpha: 0.2),
                        const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    MdiIcons.checkCircle,
                    size: 64,
                    color: const Color(0xFF10B981),
                  ),
                )
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(
                  begin: const Offset(0.5, 0.5),
                  duration: 600.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: 40),
            // 标题
            Text(
                  '设置完成！',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                )
                .animate()
                .fadeIn(duration: 500.ms, delay: 200.ms)
                .slideY(begin: 0.3, duration: 400.ms),
            const SizedBox(height: 16),
            // 副标题
            Text(
                  '在开始使用前，请阅读并同意以下协议',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                )
                .animate()
                .fadeIn(duration: 500.ms, delay: 300.ms)
                .slideY(begin: 0.3, duration: 400.ms),
            const SizedBox(height: 40),
            // 协议同意卡片
            _buildCompactAgreementCard(isDark),
            const SizedBox(height: 32),
            // 开始按钮
            SizedBox(
                  width: 240,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: canComplete ? _completeOnboarding : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: const Color(
                        0xFF3B82F6,
                      ).withValues(alpha: 0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          canComplete ? '开始使用' : '请先同意协议',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (canComplete) ...[
                          const SizedBox(width: 8),
                          Icon(MdiIcons.arrowRight, size: 20),
                        ],
                      ],
                    ),
                  ),
                )
                .animate()
                .fadeIn(duration: 500.ms, delay: 500.ms)
                .slideY(begin: 0.3, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  /// 构建紧凑的协议同意卡片
  Widget _buildCompactAgreementCard(bool isDark) {
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // 隐私政策
              _buildCompactAgreementCheckbox(
                isDark: isDark,
                isChecked: _agreedToPrivacy,
                onTap: () =>
                    setState(() => _agreedToPrivacy = !_agreedToPrivacy),
                label: '隐私政策',
                onViewTap: () => _showPrivacyDialog(isDark),
              ),
              const SizedBox(height: 12),
              // 用户协议
              _buildCompactAgreementCheckbox(
                isDark: isDark,
                isChecked: _agreedToTerms,
                onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                label: '用户协议',
                onViewTap: () => _showTermsDialog(isDark),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 400.ms)
        .slideY(begin: 0.2, duration: 400.ms);
  }

  /// 构建紧凑的协议复选框
  Widget _buildCompactAgreementCheckbox({
    required bool isDark,
    required bool isChecked,
    required VoidCallback onTap,
    required String label,
    required VoidCallback onViewTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isChecked
                ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          children: [
            // 复选框
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isChecked
                    ? const Color(0xFF3B82F6)
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isChecked
                      ? const Color(0xFF3B82F6)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : const Color(0xFFCBD5E1)),
                  width: 1.5,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            // 文字
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  children: [
                    const TextSpan(text: '我已阅读并同意 '),
                    TextSpan(
                      text: '《$label》',
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 查看按钮
            InkWell(
              onTap: onViewTap,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '查看',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF3B82F6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      MdiIcons.openInNew,
                      size: 12,
                      color: const Color(0xFF3B82F6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示隐私政策对话框
  void _showPrivacyDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => _PolicyDialog(
        isDark: isDark,
        title: '隐私政策',
        content: _getPrivacyPolicyContent(),
      ),
    );
  }

  /// 显示用户协议对话框
  void _showTermsDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => _PolicyDialog(
        isDark: isDark,
        title: '用户协议',
        content: _getTermsOfServiceContent(),
      ),
    );
  }

  /// 获取隐私政策内容（简化版）
  String _getPrivacyPolicyContent() {
    return PolicyConstants.privacyPolicy;
  }

  /// 获取用户协议内容（简化版）
  String _getTermsOfServiceContent() {
    return PolicyConstants.termsOfService;
  }

  // ==================== 底部导航 ====================
  Widget _buildBottomNav(bool isDark) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          height: 48, // 固定高度，确保所有页面底部导航高度一致
          child: Stack(
            children: [
              // 页面指示器（居中固定）
              Align(
                alignment: Alignment.center,
                child: _buildPageIndicator(isDark),
              ),
              // 按钮层
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 上一步按钮
                  if (_currentPage > 0 && _currentPage < _totalPages - 1)
                    TextButton.icon(
                      onPressed: _previousPage,
                      icon: Icon(MdiIcons.arrowLeft, size: 18),
                      label: const Text('上一步'),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                      ),
                    )
                  else
                    const SizedBox(width: 100),
                  // 占位符（让按钮对称）
                  const SizedBox(width: 100),
                ],
              ),
              // 下一步按钮（右对齐）
              if (_currentPage < _totalPages - 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildNextButton(isDark),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建下一步按钮（第3页根据登录状态显示不同文字）
  Widget _buildNextButton(bool isDark) {
    // 第3页（账号关联）根据登录状态显示不同文字
    String buttonText = '下一步';
    if (_currentPage == 2) {
      final authState = context.watch<AuthBloc>().state;
      buttonText = authState.status == AuthStatus.authenticated ? '下一步' : '跳过';
    }

    return ElevatedButton(
      onPressed: _nextPage,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(buttonText),
          const SizedBox(width: 4),
          Icon(MdiIcons.arrowRight, size: 18),
        ],
      ),
    );
  }

  /// 构建页面指示器
  Widget _buildPageIndicator(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_totalPages, (index) {
        final isActive = index == _currentPage;
        final isCompleted = index < _currentPage;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? const Color(0xFF3B82F6)
                : isCompleted
                ? const Color(0xFF10B981)
                : (isDark ? Colors.white24 : const Color(0xFFE2E8F0)),
          ),
        );
      }),
    );
  }
}

// ==================== 辅助组件 ====================

/// 操作按钮组件
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isPrimary,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
      ),
    );
  }
}

/// 背景绘制器
class _BackgroundPainter extends CustomPainter {
  final bool isDark;

  _BackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    if (isDark) {
      // 右上角蓝色光晕
      paint.shader =
          RadialGradient(
            colors: [
              const Color(0xFF3B82F6).withValues(alpha: 0.12),
              const Color(0xFF3B82F6).withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.9, size.height * 0.1),
              radius: size.width * 0.4,
            ),
          );
      canvas.drawCircle(
        Offset(size.width * 0.9, size.height * 0.1),
        size.width * 0.4,
        paint,
      );

      // 左下角紫色光晕
      paint.shader =
          RadialGradient(
            colors: [
              const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              const Color(0xFF8B5CF6).withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.1, size.height * 0.9),
              radius: size.width * 0.35,
            ),
          );
      canvas.drawCircle(
        Offset(size.width * 0.1, size.height * 0.9),
        size.width * 0.35,
        paint,
      );
    } else {
      // 浅色模式的装饰
      paint.shader =
          RadialGradient(
            colors: [
              const Color(0xFF3B82F6).withValues(alpha: 0.06),
              const Color(0xFF3B82F6).withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.85, size.height * 0.15),
              radius: size.width * 0.35,
            ),
          );
      canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.15),
        size.width * 0.35,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==================== 协议对话框组件 ====================
class _PolicyDialog extends StatelessWidget {
  final bool isDark;
  final String title;
  final String content;

  const _PolicyDialog({
    required this.isDark,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final secondaryTextColor = isDark
        ? Colors.white70
        : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 700,
        height: 600,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    MdiIcons.fileDocumentOutline,
                    color: const Color(0xFF3B82F6),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: secondaryTextColor),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            // 内容区域 - 使用 Markdown 渲染
            Expanded(
              child: Markdown(
                data: content,
                styleSheet: MarkdownStyleSheet(
                  // 段落样式
                  p: TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: secondaryTextColor,
                  ),
                  // 标题样式
                  h1: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.5,
                  ),
                  h2: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.5,
                  ),
                  h3: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    height: 1.5,
                  ),
                  // 列表样式
                  listBullet: TextStyle(
                    fontSize: 14,
                    color: secondaryTextColor,
                  ),
                  // 粗体样式
                  strong: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  // 链接样式
                  a: const TextStyle(
                    color: Color(0xFF3B82F6),
                    decoration: TextDecoration.underline,
                  ),
                  // 代码样式
                  code: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    backgroundColor: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFF1F5F9),
                    color: const Color(0xFFEF4444),
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  // 引用样式
                  blockquote: TextStyle(
                    fontSize: 14,
                    color: secondaryTextColor,
                    fontStyle: FontStyle.italic,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155).withValues(alpha: 0.3)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(4),
                    border: Border(
                      left: BorderSide(
                        color: const Color(0xFF3B82F6),
                        width: 4,
                      ),
                    ),
                  ),
                  // 水平线样式
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                ),
                padding: const EdgeInsets.all(32),
              ),
            ),
            // 底部按钮
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('我知道了', style: TextStyle(fontSize: 15)),
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
