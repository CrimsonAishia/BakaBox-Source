import 'package:flutter/material.dart';

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

  /// 页面副标题（可选）
  final String? subtitle;

  /// 头部右侧操作区域（可选）
  final Widget? headerActions;

  /// 页面内容
  final Widget child;

  const PageLayout({
    super.key,
    required this.title,
    this.subtitle,
    this.headerActions,
    required this.child,
  });

  @override
  State<PageLayout> createState() => _PageLayoutState();
}

class _PageLayoutState extends State<PageLayout> {
  bool _isHoveringTitle = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 50, 15, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 页面头部
          _buildHeader(),
          const SizedBox(height: 15),
          // 页面内容
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  /// 构建页面头部
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 标题区域
          _buildTitleSection(),
          // 操作区域
          if (widget.headerActions != null) widget.headerActions!,
        ],
      ),
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
          // 副标题
          if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.subtitle!,
                style: TextStyle(
                  color: isDark ? Colors.white60 : const Color(0xFF4B5563),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
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
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        // 动画下划线
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          width: _isHoveringTitle ? _calculateTitleWidth() : 40,
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFF0080FF),
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ],
    );
  }

  /// 计算标题宽度（用于下划线动画）
  double _calculateTitleWidth() {
    final textPainter = TextPainter(
      text: TextSpan(
        text: widget.title,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.width;
  }
}
