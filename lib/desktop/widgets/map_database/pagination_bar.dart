import 'package:flutter/material.dart';

/// 分页器组件
///
/// 显示页码按钮和上一页/下一页按钮
class PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final int maxVisiblePages;
  final int? totalItems;
  final int? pageSize;

  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.maxVisiblePages = 7,
    this.totalItems,
    this.pageSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 移除这个判断，即使只有一页也显示
    // if (totalPages <= 1) {
    //   return const SizedBox.shrink();
    // }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 左侧占位，保持分页按钮居中
          if (totalItems != null && pageSize != null)
            Expanded(child: Container()),

          // 中间：分页按钮
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 上一页按钮
              _buildNavigationButton(
                context,
                icon: Icons.chevron_left,
                enabled: currentPage > 1,
                onTap: () => onPageChanged(currentPage - 1),
                isDark: isDark,
              ),
              const SizedBox(width: 8),

              // 页码按钮
              ..._buildPageButtons(context, isDark),

              const SizedBox(width: 8),
              // 下一页按钮
              _buildNavigationButton(
                context,
                icon: Icons.chevron_right,
                enabled: currentPage < totalPages,
                onTap: () => onPageChanged(currentPage + 1),
                isDark: isDark,
              ),
            ],
          ),

          // 右侧：显示条数信息
          if (totalItems != null && pageSize != null)
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '每页 $pageSize 条 / 共 $totalItems 条',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildPageButtons(BuildContext context, bool isDark) {
    final buttons = <Widget>[];
    final pages = _calculateVisiblePages();

    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];

      if (page == -1) {
        // 省略号
        buttons.add(_buildEllipsis(isDark));
      } else {
        // 页码按钮
        buttons.add(
          _buildPageButton(
            context,
            page: page,
            isActive: page == currentPage,
            isDark: isDark,
          ),
        );
      }

      if (i < pages.length - 1) {
        buttons.add(const SizedBox(width: 4));
      }
    }

    return buttons;
  }

  List<int> _calculateVisiblePages() {
    if (totalPages <= maxVisiblePages) {
      return List.generate(totalPages, (i) => i + 1);
    }

    final pages = <int>[];
    final halfVisible = (maxVisiblePages - 3) ~/ 2;

    // 始终显示第一页
    pages.add(1);

    if (currentPage <= halfVisible + 2) {
      // 靠近开始
      for (int i = 2; i <= maxVisiblePages - 2; i++) {
        pages.add(i);
      }
      pages.add(-1); // 省略号
      pages.add(totalPages);
    } else if (currentPage >= totalPages - halfVisible - 1) {
      // 靠近结束
      pages.add(-1); // 省略号
      for (int i = totalPages - maxVisiblePages + 3; i <= totalPages; i++) {
        pages.add(i);
      }
    } else {
      // 在中间
      pages.add(-1); // 省略号
      for (
        int i = currentPage - halfVisible;
        i <= currentPage + halfVisible;
        i++
      ) {
        pages.add(i);
      }
      pages.add(-1); // 省略号
      pages.add(totalPages);
    }

    return pages;
  }

  Widget _buildNavigationButton(
    BuildContext context, {
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: enabled
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled
                  ? (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1))
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05)),
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.black.withValues(alpha: 0.7))
                : (isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.2)),
          ),
        ),
      ),
    );
  }

  Widget _buildPageButton(
    BuildContext context, {
    required int page,
    required bool isActive,
    required bool isDark,
  }) {
    return _PageButton(
      page: page,
      isActive: isActive,
      isDark: isDark,
      onTap: () => onPageChanged(page),
    );
  }

  Widget _buildEllipsis(bool isDark) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      child: Text(
        '...',
        style: TextStyle(
          fontSize: 14,
          color: isDark
              ? Colors.white.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

/// 页码按钮组件
class _PageButton extends StatefulWidget {
  final int page;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _PageButton({
    required this.page,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_PageButton> createState() => _PageButtonState();
}

class _PageButtonState extends State<_PageButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.isActive
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isActive ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: widget.isActive
                ? const Color(0xFF0080FF)
                : _isHovered
                ? (widget.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05))
                : (widget.isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isActive
                  ? const Color(0xFF0080FF)
                  : _isHovered
                  ? (widget.isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.15))
                  : (widget.isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1)),
              width: widget.isActive ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              '${widget.page}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                color: widget.isActive
                    ? Colors.white
                    : (widget.isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black.withValues(alpha: 0.7)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
