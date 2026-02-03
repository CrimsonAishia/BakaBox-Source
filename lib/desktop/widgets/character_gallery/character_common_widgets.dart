import 'package:flutter/material.dart';
import 'character_gallery_theme.dart';

/// 带 hover 效果的分类按钮
class CategoryButton extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<CategoryButton> createState() => _CategoryButtonState();
}

class _CategoryButtonState extends State<CategoryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final cardBg = CharacterGalleryTheme.getCardBackground(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? CharacterGalleryTheme.getVermillion(context)
                : _isHovered
                    ? CharacterGalleryTheme.getVermillion(context).withValues(alpha: isDark ? 0.2 : 0.1)
                    : cardBg.withValues(alpha: 0.8),
            border: Border.all(
              color: widget.isSelected || _isHovered
                  ? CharacterGalleryTheme.getVermillion(context)
                  : scrollBrown.withValues(alpha: 0.4),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isSelected ? Colors.white : inkColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

/// 带 hover 效果的操作按钮
class HoverButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool small;

  const HoverButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.small = false,
  });

  @override
  State<HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<HoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    
    final iconSize = widget.small ? 12.0 : 14.0;
    final fontSize = widget.small ? 11.0 : 12.0;
    final hPadding = widget.small ? 8.0 : 10.0;
    final vPadding = widget.small ? 4.0 : 5.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
          decoration: BoxDecoration(
            color: _isHovered
                ? CharacterGalleryTheme.getVermillion(context).withValues(alpha: isDark ? 0.2 : 0.1)
                : Colors.transparent,
            border: Border.all(
              color: _isHovered
                  ? CharacterGalleryTheme.getVermillion(context)
                  : scrollBrown.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: iconSize,
                color: _isHovered
                    ? CharacterGalleryTheme.getVermillion(context)
                    : scrollBrown,
              ),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: _isHovered
                      ? CharacterGalleryTheme.getVermillion(context)
                      : scrollBrown,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 滚动指示器
class ScrollIndicator extends StatelessWidget {
  final bool isTop;

  const ScrollIndicator({super.key, required this.isTop});

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    
    return IgnorePointer(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              scrollBrown.withValues(alpha: 0.25),
              scrollBrown.withValues(alpha: 0.12),
              scrollBrown.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        padding: EdgeInsets.only(top: isTop ? 2 : 0, bottom: isTop ? 0 : 2),
        child: Icon(
          isTop ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: scrollBrown,
          size: 24,
        ),
      ),
    );
  }
}

/// 分隔线（带标题）
class SectionDivider extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionDivider({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Container(width: 30, height: 2, color: scrollBrown),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: scrollBrown,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 2,
              color: scrollBrown.withValues(alpha: 0.3),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
