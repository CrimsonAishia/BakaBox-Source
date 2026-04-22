import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// 徽章
class Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const Badge({
    super.key,
    required this.label,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: filled ? Colors.white : color,
        ),
      ),
    );
  }
}

/// 空状态提示
class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? desc;
  final Color? iconColor;
  final Widget? action;

  const EmptyHint({
    super.key,
    required this.icon,
    required this.title,
    this.desc,
    this.iconColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 52,
              color: iconColor ?? (isDark ? Colors.white24 : Colors.grey[300]),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            if (desc != null) ...[
              const SizedBox(height: 6),
              Text(
                desc!,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// 图标按钮
class IconButton extends StatefulWidget {
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  const IconButton({
    super.key,
    required this.icon,
    this.loading = false,
    this.onTap,
  });

  @override
  State<IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<IconButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(IconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading && !oldWidget.loading) {
      _rotationController.repeat();
    } else if (!widget.loading && oldWidget.loading) {
      _rotationController.stop();
      _rotationController.reset();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.loading
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: _hovered && !widget.loading
                ? (isDark ? const Color(0xFF334155) : Colors.grey[100])
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: widget.loading
                ? RotationTransition(
                    turns: _rotationController,
                    child: Icon(
                      widget.icon,
                      size: 18,
                      color: const Color(0xFF0080FF),
                    ),
                  )
                : Icon(
                    widget.icon,
                    size: 18,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
          ),
        ),
      ),
    );
  }
}

/// 分段按钮
class SegmentedButton extends StatefulWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onChanged;

  const SegmentedButton({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<SegmentedButton> createState() => _SegmentedButtonState();
}

class _SegmentedButtonState extends State<SegmentedButton> {
  int _hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 30,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          widget.items.length,
          (i) => MouseRegion(
            onEnter: (_) => setState(() => _hoveredIndex = i),
            onExit: (_) => setState(() => _hoveredIndex = -1),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.selected == i
                      ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                      : (_hoveredIndex == i
                            ? (isDark
                                  ? const Color(0xFF475569)
                                  : Colors.grey[300])
                            : Colors.transparent),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: widget.selected == i
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  widget.items[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: widget.selected == i
                        ? const Color(0xFF0080FF)
                        : (isDark ? Colors.white54 : Colors.grey[600]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 配置操作按钮（编辑/删除）
class ConfigActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback onTap;
  /// 是否显示审核标识点（已通过的配置修改需要重新审核）
  final bool badge;

  const ConfigActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.color,
    required this.onTap,
    this.badge = false,
  });

  @override
  State<ConfigActionButton> createState() => _ConfigActionButtonState();
}

class _ConfigActionButtonState extends State<ConfigActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Colors.grey[600]!;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _hovered
                      ? color.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: _hovered ? color : Colors.grey[500],
                ),
              ),
              if (widget.badge)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 带 hover 效果的分类 Chip
class HoverChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const HoverChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<HoverChip> createState() => _HoverChipState();
}

class _HoverChipState extends State<HoverChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFF0080FF)
                : (_hovered
                      ? (isDark ? const Color(0xFF475569) : Colors.grey[200])
                      : (isDark ? const Color(0xFF334155) : Colors.grey[100])),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.selected
                  ? const Color(0xFF0080FF)
                  : (_hovered
                        ? (isDark ? const Color(0xFF64748B) : Colors.grey[300]!)
                        : Colors.transparent),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: widget.selected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.grey[700]),
            ),
          ),
        ),
      ),
    );
  }
}

/// 带 hover 效果的类型选项
class HoverTypeOption extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const HoverTypeOption({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  State<HoverTypeOption> createState() => _HoverTypeOptionState();
}

class _HoverTypeOptionState extends State<HoverTypeOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFF0080FF).withValues(alpha: 0.06)
                : (_hovered
                      ? (isDark ? const Color(0xFF334155) : Colors.grey[100])
                      : (isDark ? const Color(0xFF1E293B) : Colors.grey[50])),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected
                  ? const Color(0xFF0080FF)
                  : (_hovered
                        ? (isDark ? const Color(0xFF475569) : Colors.grey[300]!)
                        : (isDark
                              ? const Color(0xFF334155)
                              : Colors.grey[200]!)),
              width: widget.selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.selected
                    ? const Color(0xFF0080FF)
                    : (isDark ? Colors.white54 : Colors.grey[500]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: widget.selected
                            ? const Color(0xFF0080FF)
                            : (isDark ? Colors.white70 : Colors.grey[700]),
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.selected)
                const Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Color(0xFF0080FF),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 带 hover 效果的占位符标签
class PlaceholderTag extends StatefulWidget {
  final String label;
  final VoidCallback onRemove;

  const PlaceholderTag({
    super.key,
    required this.label,
    required this.onRemove,
  });

  @override
  State<PlaceholderTag> createState() => _PlaceholderTagState();
}

class _PlaceholderTagState extends State<PlaceholderTag> {
  bool _hovered = false;
  bool _closeHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _hovered
              ? const Color(0xFFf59e0b).withValues(alpha: 0.2)
              : const Color(0xFFf59e0b).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFFf59e0b).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MdiIcons.keyboardOutline,
              size: 10,
              color: const Color(0xFFf59e0b),
            ),
            const SizedBox(width: 4),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFFd97706),
              ),
            ),
            const SizedBox(width: 4),
            MouseRegion(
              onEnter: (_) => setState(() => _closeHovered = true),
              onExit: (_) => setState(() => _closeHovered = false),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onRemove,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _closeHovered
                        ? const Color(0xFFf59e0b).withValues(alpha: 0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 10,
                    color: Color(0xFFf59e0b),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
