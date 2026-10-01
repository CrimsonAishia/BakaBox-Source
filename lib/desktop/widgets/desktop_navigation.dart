import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/widgets/navigation/app_navigation.dart';
import 'user_login_box.dart';
import '../../core/constants/app_colors.dart';

/// 桌面端导航栏组件
///
/// 提供以下功能：
/// - 显示带图标的导航项
/// - 点击导航项切换页面并高亮当前项
/// - 页面切换时播放平滑过渡动画
/// - 底部显示用户登录区域
/// - 底部显示问题反馈入口
class DesktopNavigation extends StatelessWidget {
  /// 当前选中的导航项索引
  final int currentIndex;

  /// 导航项索引变化回调
  final ValueChanged<int> onIndexChanged;

  /// 导航项列表
  final List<NavigationItem> items;

  /// 问题反馈点击回调
  final VoidCallback? onFeedbackTap;

  /// 问题反馈是否选中
  final bool isFeedbackSelected;

  /// 设置点击回调
  final VoidCallback? onSettingsTap;

  /// 设置是否选中
  final bool isSettingsSelected;

  /// 头像点击回调（进入个人主页）
  final VoidCallback? onProfileTap;

  /// 个人主页是否选中
  final bool isProfileSelected;

  const DesktopNavigation({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.items,
    this.onFeedbackTap,
    this.isFeedbackSelected = false,
    this.onSettingsTap,
    this.isSettingsSelected = false,
    this.onProfileTap,
    this.isProfileSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.slate800.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          bottomLeft: Radius.circular(22),
        ),
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildLogoArea(isDark),
          Expanded(child: _buildNavigationItems(theme, isDark)),
          _buildBottomActions(theme, isDark),
          _buildLoginArea(theme, isDark),
        ],
      ),
    );
  }

  /// 构建 Logo 区域
  Widget _buildLogoArea(bool isDark) {
    return Container(
          height: 95,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Center(child: _LogoWidget(isDark: isDark)),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.3, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  /// 构建导航项列表
  ///
  /// - 显示带图标的导航项
  /// - 点击时切换页面并高亮当前项
  Widget _buildNavigationItems(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = currentIndex == index;

          return _NavigationItemWidget(
            item: item,
            isSelected: isSelected,
            isDark: isDark,
            theme: theme,
            index: index,
            onTap: isSelected ? null : () => onIndexChanged(index),
          );
        },
      ),
    );
  }

  /// 构建用户登录区域
  ///
  Widget _buildLoginArea(ThemeData theme, bool isDark) {
    return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: UserLoginBox(
            onProfileTap: onProfileTap,
            isSelected: isProfileSelected,
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 700.ms)
        .slideY(begin: 0.3, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  /// 构建底部操作按钮（问题反馈、设置）
  Widget _buildBottomActions(ThemeData theme, bool isDark) {
    return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: _ActionItemWidget(
                  theme: theme,
                  isDark: isDark,
                  icon: Icons.feedback_outlined,
                  selectedIcon: Icons.feedback,
                  label: '问题反馈',
                  isSelected: isFeedbackSelected,
                  onTap: onFeedbackTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionItemWidget(
                  theme: theme,
                  isDark: isDark,
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: '设置',
                  isSelected: isSettingsSelected,
                  onTap: onSettingsTap,
                ),
              ),
            ],
          ),
        )
        .animate(delay: 600.ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}

class _ActionItemWidget extends StatefulWidget {
  final ThemeData theme;
  final bool isDark;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ActionItemWidget({
    required this.theme,
    required this.isDark,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ActionItemWidget> createState() => _ActionItemWidgetState();
}

class _ActionItemWidgetState extends State<_ActionItemWidget>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: -1.0,
      upperBound: 1.0,
      value: 0.0,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ActionItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _shakeController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      } else if (_isHovered) {
        _shakeController.repeat(reverse: true);
      }
    }
  }

  void _onHoverChanged(bool hovered) {
    if (!mounted) return;
    setState(() => _isHovered = hovered);
    if (hovered && !widget.isSelected) {
      _shakeController.repeat(reverse: true);
    } else {
      _shakeController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHovered = _isHovered && !widget.isSelected;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: MouseRegion(
        cursor: widget.isSelected
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => _onHoverChanged(true),
        onExit: (_) => _onHoverChanged(false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : (isHovered
                        ? AppColors.primary.withValues(
                            alpha: widget.isDark ? 0.15 : 0.08,
                          )
                        : (widget.isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : AppColors.gray100)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isSelected
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : (isHovered
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : (widget.isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : AppColors.gray200)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isHovered ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _shakeController.value * 0.25,
                        child: child,
                      );
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        widget.isSelected || isHovered
                            ? widget.selectedIcon
                            : widget.icon,
                        key: ValueKey(widget.isSelected || isHovered),
                        size: 16,
                        color: widget.isSelected || isHovered
                            ? AppColors.primary
                            : (widget.isDark
                                  ? Colors.white60
                                  : AppColors.gray500),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: widget.isSelected || isHovered
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: widget.isSelected || isHovered
                          ? AppColors.primary
                          : (widget.isDark
                                ? Colors.white60
                                : AppColors.gray500),
                    ),
                    child: Text(widget.label, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 单个导航项组件
///
/// 实现平滑的过渡动画和悬停效果
class _NavigationItemWidget extends StatefulWidget {
  final NavigationItem item;
  final bool isSelected;
  final bool isDark;
  final ThemeData theme;
  final int index;
  final VoidCallback? onTap;

  const _NavigationItemWidget({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.theme,
    required this.index,
    required this.onTap,
  });

  @override
  State<_NavigationItemWidget> createState() => _NavigationItemWidgetState();
}

class _NavigationItemWidgetState extends State<_NavigationItemWidget>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: -1.0,
      upperBound: 1.0,
      value: 0.0,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _NavigationItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _shakeController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      } else if (_isHovered) {
        _shakeController.repeat(reverse: true);
      }
    }
  }

  void _onHoverChanged(bool hovered) {
    if (!mounted) return;
    setState(() => _isHovered = hovered);
    if (hovered && !widget.isSelected) {
      _shakeController.repeat(reverse: true);
    } else {
      _shakeController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHovered = _isHovered && !widget.isSelected;

    return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: MouseRegion(
              cursor: widget.isSelected
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              onEnter: (_) => _onHoverChanged(true),
              onExit: (_) => _onHoverChanged(false),
              child: GestureDetector(
                onTap: widget.onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? AppColors.primary
                        : (isHovered
                              ? AppColors.primary.withValues(
                                  alpha: widget.isDark ? 0.15 : 0.08,
                                )
                              : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    gradient: widget.isSelected
                        ? const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF42A5F5)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    boxShadow: widget.isSelected
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFF0080FF,
                              ).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      AnimatedScale(
                        scale: isHovered ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                        child: AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _shakeController.value * 0.25,
                              child: child,
                            );
                          },
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            child: Icon(
                              widget.isSelected
                                  ? widget.item.selectedIcon
                                  : widget.item.icon,
                              key: ValueKey(widget.isSelected),
                              size: 22,
                              color: widget.isSelected
                                  ? Colors.white
                                  : (isHovered
                                        ? AppColors.primary
                                        : (widget.isDark
                                              ? Colors.white70
                                              : AppColors.gray500)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 150),
                          style:
                              widget.theme.textTheme.bodyMedium?.copyWith(
                                color: widget.isSelected
                                    ? Colors.white
                                    : (isHovered
                                          ? AppColors.primary
                                          : (widget.isDark
                                                ? Colors.white70
                                                : AppColors.gray700)),
                                fontWeight: widget.isSelected || isHovered
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ) ??
                              const TextStyle(),
                          child: Text(widget.item.label),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
        .animate(delay: (widget.index * 80).ms)
        .fadeIn(duration: 300.ms)
        .slideX(begin: -0.2, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}

/// Logo 组件，带 Hover 特效
///
/// 点击后跳转到官网
class _LogoWidget extends StatefulWidget {
  final bool isDark;

  const _LogoWidget({required this.isDark});

  @override
  State<_LogoWidget> createState() => _LogoWidgetState();
}

class _LogoWidgetState extends State<_LogoWidget>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  Future<void> _launchUrl() async {
    final uri = Uri.parse('https://baka.aishia.cc');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnimation = Tween<double>(begin: 0.15, end: 0.4).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool isHovered) {
    setState(() => _isHovered = isHovered);
    if (isHovered) {
      _glowController.repeat(reverse: true);
    } else {
      _glowController.stop();
      _glowController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => _onHoverChanged(true),
          onExit: (_) => _onHoverChanged(false),
          child: GestureDetector(
            onTap: _launchUrl,
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: _isHovered
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(
                                0xFF0080FF,
                              ).withValues(alpha: _glowAnimation.value * 0.15),
                              const Color(
                                0xFF42A5F5,
                              ).withValues(alpha: _glowAnimation.value * 0.1),
                            ],
                          )
                        : null,
                    boxShadow: _isHovered
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFF0080FF,
                              ).withValues(alpha: _glowAnimation.value),
                              blurRadius: 20,
                              spreadRadius: -2,
                            ),
                            BoxShadow(
                              color: const Color(
                                0xFF42A5F5,
                              ).withValues(alpha: _glowAnimation.value * 0.5),
                              blurRadius: 30,
                              spreadRadius: -5,
                            ),
                          ]
                        : null,
                  ),
                  child: child,
                );
              },
              child: Image.asset(
                'assets/images/sidebar-logo.png',
                height: 72,
                fit: BoxFit.contain,
              ),
            ),
          ),
        )
        .animate(target: _isHovered ? 1 : 0)
        .scaleXY(end: 1.08, duration: 250.ms, curve: Curves.easeOutCubic)
        .shimmer(
          duration: 1200.ms,
          color: _isHovered
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.transparent,
        );
  }
}
