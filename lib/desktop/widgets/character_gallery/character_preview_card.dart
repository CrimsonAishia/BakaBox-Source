import 'package:flutter/material.dart';
import '../../../core/widgets/disk_cached_image.dart';
import 'character_gallery_theme.dart';

/// 预览图卡片（带 hover 效果）
class PreviewImageCard extends StatefulWidget {
  final String? imageUrl;
  final VoidCallback? onTap;

  const PreviewImageCard({super.key, this.imageUrl, this.onTap});

  @override
  State<PreviewImageCard> createState() => _PreviewImageCardState();
}

class _PreviewImageCardState extends State<PreviewImageCard> {
  bool _isHovered = false;

  /// 是否有有效的图片URL
  bool get _hasValidImage =>
      widget.imageUrl != null && widget.imageUrl!.isNotEmpty;

  /// 是否可点击（有有效图片且有点击回调）
  bool get _isClickable => _hasValidImage && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return MouseRegion(
      cursor: _isClickable
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _isClickable ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            border: Border.all(
              color: _isHovered && _isClickable
                  ? CharacterGalleryTheme.getGold(context)
                  : CharacterGalleryTheme.getGold(
                      context,
                    ).withValues(alpha: 0.5),
              width: 3,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isHovered && _isClickable
                ? [
                    BoxShadow(
                      color: CharacterGalleryTheme.getGold(
                        context,
                      ).withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: _hasValidImage
                      ? DiskCachedImage(
                          imageUrl: widget.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            color: washiColor,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: CharacterGalleryTheme.getVermillion(
                                  context,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: _buildPlaceholder(
                            washiColor,
                            scrollBrown,
                          ),
                        )
                      : _buildPlaceholder(washiColor, scrollBrown),
                ),
              ),
              // Hover 时显示放大图标（仅在可点击时）
              if (_isHovered && _isClickable)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.zoom_in,
                          color: CharacterGalleryTheme.getVermillion(context),
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(Color washiColor, Color scrollBrown) {
    return Container(
      color: washiColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 48,
              color: scrollBrown.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              '暂无预览图',
              style: TextStyle(
                color: scrollBrown.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 预览位置切换按钮
class PreviewPositionButton extends StatelessWidget {
  final int position;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const PreviewPositionButton({
    super.key,
    required this.position,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected
              ? CharacterGalleryTheme.getVermillion(context)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? CharacterGalleryTheme.getVermillion(context)
                : scrollBrown,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : inkColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
