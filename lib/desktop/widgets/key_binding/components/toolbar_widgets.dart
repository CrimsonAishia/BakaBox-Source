import 'package:flutter/material.dart';

/// 工具栏按钮
class ToolbarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool badge;
  final VoidCallback onTap;

  const ToolbarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    this.badge = false,
    required this.onTap,
  });

  @override
  State<ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<ToolbarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) {
        if (!widget.active) {
          setState(() => _hovered = true);
        }
      },
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.active 
                    ? const Color(0xFF0080FF) 
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon, 
                size: 16, 
                color: widget.active 
                    ? const Color(0xFF0080FF)
                    : (_hovered 
                        ? (isDark ? Colors.white : Colors.grey[800])
                        : (isDark ? Colors.white60 : Colors.grey[600])),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.active ? FontWeight.w600 : FontWeight.w500,
                  color: widget.active 
                      ? const Color(0xFF0080FF)
                      : (_hovered 
                          ? (isDark ? Colors.white : Colors.grey[800])
                          : (isDark ? Colors.white60 : Colors.grey[600])),
                ),
              ),
              if (widget.badge) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFf59e0b),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 搜索框
class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const SearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1a1a2e)),
      decoration: InputDecoration(
        hintText: '搜索...',
        hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey[400]),
        prefixIcon: Icon(Icons.search, size: 18, color: isDark ? Colors.white38 : Colors.grey[400]),
        filled: true,
        fillColor: isDark ? const Color(0xFF334155) : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: onChanged,
    );
  }
}

/// 分类下拉
class CategoryDropdown extends StatefulWidget {
  final int? selectedCategoryId;
  final List<CategoryItem> categories;
  final ValueChanged<int?> onChanged;

  const CategoryDropdown({
    super.key,
    required this.selectedCategoryId,
    required this.categories,
    required this.onChanged,
  });

  @override
  State<CategoryDropdown> createState() => _CategoryDropdownState();
}

class _CategoryDropdownState extends State<CategoryDropdown> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final selectedCategory = widget.categories.cast<CategoryItem?>().firstWhere(
      (c) => c?.id == widget.selectedCategoryId,
      orElse: () => null,
    );
    final displayName = selectedCategory?.name ?? '全部';
    
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: PopupMenuButton<int?>(
        itemBuilder: (context) => [
          PopupMenuItem(
            value: null,
            onTap: () {
              Future.delayed(Duration.zero, () => widget.onChanged(null));
            },
            child: Row(
              children: [
                if (widget.selectedCategoryId == null)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.check, size: 16),
                  ),
                const Text('全部'),
              ],
            ),
          ),
          ...widget.categories.map((c) => PopupMenuItem(
            value: c.id,
            onTap: () {
              Future.delayed(Duration.zero, () => widget.onChanged(c.id));
            },
            child: Row(
              children: [
                if (widget.selectedCategoryId == c.id)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.check, size: 16),
                  ),
                Text(c.name),
              ],
            ),
          )),
        ],
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered 
                ? (isDark ? const Color(0xFF475569) : Colors.grey[200]) 
                : (isDark ? const Color(0xFF334155) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分类项数据类
class CategoryItem {
  final int id;
  final String name;

  const CategoryItem({required this.id, required this.name});
}
