import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/widgets/navigation/app_navigation.dart';
import 'user_login_box.dart';

/// 桌面端导航栏组件
///
/// 提供以下功能：
/// - 显示带图标的导航项 (Requirements 9.1)
/// - 点击导航项切换页面并高亮当前项 (Requirements 9.2)
/// - 页面切换时播放平滑过渡动画 (Requirements 9.3)
/// - 底部显示用户登录区域 (Requirements 9.4)
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

  const DesktopNavigation({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.items,
    this.onFeedbackTap,
    this.isFeedbackSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.95)
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
          _buildFeedbackButton(theme, isDark),
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
  /// 实现 Requirements 9.1 和 9.2：
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
  /// 实现 Requirements 9.4：在底部显示用户登录区域
  Widget _buildLoginArea(ThemeData theme, bool isDark) {
    return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: const UserLoginBox(),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 700.ms)
        .slideY(begin: 0.3, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  /// 构建问题反馈按钮
  Widget _buildFeedbackButton(ThemeData theme, bool isDark) {
    return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onFeedbackTap,
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isFeedbackSelected
                      ? const Color(0xFF0080FF).withValues(alpha: 0.1)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF3F4F6)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFeedbackSelected
                        ? const Color(0xFF0080FF).withValues(alpha: 0.3)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : const Color(0xFFE5E7EB)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFeedbackSelected
                          ? Icons.feedback
                          : Icons.feedback_outlined,
                      size: 18,
                      color: isFeedbackSelected
                          ? const Color(0xFF0080FF)
                          : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '问题反馈',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isFeedbackSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isFeedbackSelected
                              ? const Color(0xFF0080FF)
                              : (isDark
                                    ? Colors.white60
                                    : const Color(0xFF6B7280)),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: isFeedbackSelected
                          ? const Color(0xFF0080FF)
                          : (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate(delay: 600.ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}

/// 单个导航项组件
///
/// 实现平滑的过渡动画 (Requirements 9.3)
class _NavigationItemWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0080FF)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF0080FF), Color(0xFF42A5F5)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  boxShadow: isSelected
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
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isSelected ? item.selectedIcon : item.icon,
                        key: ValueKey(isSelected),
                        size: 22,
                        color: isSelected
                            ? Colors.white
                            : isDark
                            ? Colors.white70
                            : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style:
                            theme.textTheme.bodyMedium?.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : isDark
                                  ? Colors.white70
                                  : const Color(0xFF374151),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ) ??
                            const TextStyle(),
                        child: Text(item.label),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: isSelected ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate(delay: (index * 80).ms)
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
              ? const Color(0xFF0080FF).withValues(alpha: 0.3)
              : Colors.transparent,
        );
  }
}
