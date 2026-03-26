import 'package:flutter/material.dart';
import '../../../core/widgets/disk_cached_image.dart';
import 'character_gallery_theme.dart';

/// 角色图鉴大图查看器对话框
class CharacterImageViewerDialog extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String characterName;

  const CharacterImageViewerDialog({
    super.key,
    required this.images,
    this.initialIndex = 0,
    required this.characterName,
  });

  @override
  State<CharacterImageViewerDialog> createState() =>
      _CharacterImageViewerDialogState();
}

class _CharacterImageViewerDialogState
    extends State<CharacterImageViewerDialog> {
  late int _currentIndex;
  late PageController _pageController;

  static const _positionLabels = ['正面', '左侧', '右侧', '背面'];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(40),
      child: Stack(
        children: [
          // 图片区域
          Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题栏
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: CharacterGalleryTheme.getInkColor(
                        context,
                      ).withValues(alpha: 0.9),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          widget.characterName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (widget.images.length > 1)
                          Text(
                            '${_currentIndex < _positionLabels.length ? _positionLabels[_currentIndex] : ''} (${_currentIndex + 1}/${widget.images.length})',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        const Spacer(),
                        // 关闭按钮
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  // 图片
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        color: CharacterGalleryTheme.getWashiColor(context),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(8),
                        ),
                      ),
                      child: widget.images.length == 1
                          ? _buildSingleImage()
                          : _buildPageView(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 左右切换按钮
          if (widget.images.length > 1) ...[
            Positioned(
              left: 5,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavButton(
                  icon: Icons.chevron_left,
                  onTap: _currentIndex > 0 ? _previousImage : null,
                ),
              ),
            ),
            Positioned(
              right: 5,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavButton(
                  icon: Icons.chevron_right,
                  onTap: _currentIndex < widget.images.length - 1
                      ? _nextImage
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSingleImage() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: DiskCachedImage(
          imageUrl: widget.images[0],
          fit: BoxFit.contain,
          placeholder: const Center(child: CircularProgressIndicator()),
          errorWidget: const Center(
            child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildPageView() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: DiskCachedImage(
              imageUrl: widget.images[index],
              fit: BoxFit.contain,
              placeholder: const Center(child: CircularProgressIndicator()),
              errorWidget: const Center(
                child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
              ),
            ),
          );
        },
      ),
    );
  }

  void _previousImage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextImage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}

/// 导航按钮
class _NavButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, this.onTap});

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonBg = CharacterGalleryTheme.getCardBackground(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isEnabled
                ? (_isHovered
                      ? buttonBg
                      : buttonBg.withValues(alpha: isDark ? 0.9 : 0.8))
                : buttonBg.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            boxShadow: isEnabled && _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.icon,
            size: 32,
            color: isEnabled
                ? (_isHovered ? CharacterGalleryTheme.vermillion : inkColor)
                : Colors.grey,
          ),
        ),
      ),
    );
  }
}
