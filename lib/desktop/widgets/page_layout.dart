import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../core/constants/app_colors.dart';

/// 页面布局组件
///
/// 提供统一的页面布局结构：
/// - 页面头部：标题 + 副标题 + 操作区域
/// - 页面内容区域
///
/// 所有桌面端页面都应使用此组件作为基础布局
class PageLayout extends StatefulWidget {
  /// 页面标题
  final String title;

  /// 页面内容
  final Widget child;

  /// 返回按钮的回调，如果提供，则会在标题旁边显示一个返回按钮（或者作为面包屑父级的点击事件）
  final VoidCallback? onBack;

  /// 可选的页面背景组件（将显示在最底层）
  final Widget? background;

  /// 面包屑父级标题，如果有提供，则显示为 "父级 / 标题"，点击父级触发 onBack，不再显示返回按钮
  final String? breadcrumbParent;

  const PageLayout({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.background,
    this.breadcrumbParent,
  });

  @override
  State<PageLayout> createState() => _PageLayoutState();
}

class _PageLayoutState extends State<PageLayout> {
  bool _isHoveringTitle = false;
  bool _isHoveringBreadcrumb = false;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 页面头部
          _buildHeader(),
          const SizedBox(height: 8),
          // 页面内容
          Expanded(
            child: SizedBox(width: double.infinity, child: widget.child),
          ),
        ],
      ),
    );

    if (widget.background != null) {
      return Stack(
        children: [
          Positioned.fill(child: widget.background!),
          content,
        ],
      );
    }

    return content;
  }

  /// 构建页面头部
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: _buildTitleSection(),
    );
  }

  /// 构建标题区域
  Widget _buildTitleSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHoveringTitle = true),
      onExit: (_) => setState(() => _isHoveringTitle = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题 + 下划线
          _buildTitle(isDark),
        ],
      ),
    );
  }

  /// 构建标题（带动画下划线）
  Widget _buildTitle(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.breadcrumbParent != null) ...[
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isHoveringBreadcrumb = true),
                onExit: (_) => setState(() => _isHoveringBreadcrumb = false),
                child: GestureDetector(
                  onTap: widget.onBack,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.translationValues(
                      _isHoveringBreadcrumb ? -4.0 : 0.0,
                      0,
                      0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          MdiIcons.chevronLeft,
                          size: 28,
                          color: _isHoveringBreadcrumb
                              ? (isDark ? Colors.white : AppColors.gray900)
                              : (isDark ? Colors.white54 : AppColors.gray500),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          widget.breadcrumbParent!,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: _isHoveringBreadcrumb
                                ? (isDark ? Colors.white : AppColors.gray900)
                                : (isDark ? Colors.white54 : AppColors.gray500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '/',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    color: isDark ? Colors.white24 : AppColors.gray300,
                  ),
                ),
              ),
            ],
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            if (widget.breadcrumbParent == null && widget.onBack != null) ...[
              const SizedBox(width: 16),
              SizedBox(
                height: 34, // 强制高度与 28px 字体视觉高度一致
                child: OutlinedButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text(
                    '返回',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? Colors.white
                        : const Color(0xFF374151),
                    backgroundColor: isDark ? AppColors.slate800 : Colors.white,
                    side: BorderSide(
                      color: isDark ? AppColors.slate600 : AppColors.gray300,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        // 动画下划线
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          width: _isHoveringTitle ? _calculateTitleWidth() : 40,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ],
    );
  }

  /// 计算标题宽度（用于下划线动画）
  double _calculateTitleWidth() {
    String text = widget.title;
    if (widget.breadcrumbParent != null) {
      text = '${widget.breadcrumbParent} / ${widget.title}';
    }
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.width;
  }
}
