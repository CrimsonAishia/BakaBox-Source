import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 图片查看器对话框
/// 
/// 支持：
/// - 点击放大查看
/// - 多图切换
/// - 缩放手势
/// - 键盘导航（桌面端）
class ImageViewerDialog extends StatefulWidget {
  /// 图片URL列表
  final List<String> imageUrls;
  
  /// 初始显示的图片索引
  final int initialIndex;

  const ImageViewerDialog({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  /// 显示图片查看器
  static Future<void> show(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => ImageViewerDialog(
        imageUrls: imageUrls,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  State<ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<ImageViewerDialog> {
  late PageController _pageController;
  late int _currentIndex;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.imageUrls.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _goToPrevious();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _goToNext();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Stack(
        children: [
          // 图片区域
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {}, // 阻止点击图片关闭
                  child: Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.network(
                        widget.imageUrls[index],
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: Colors.white,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.broken_image_rounded,
                                size: 64,
                                color: Colors.white54,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '图片加载失败',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // 关闭按钮
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black38,
                padding: const EdgeInsets.all(8),
              ),
            ),
          ),
          // 图片计数
          if (widget.imageUrls.length > 1)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.imageUrls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          // 左箭头
          if (widget.imageUrls.length > 1 && _currentIndex > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: _goToPrevious,
                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 40),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black38,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
            ),
          // 右箭头
          if (widget.imageUrls.length > 1 && _currentIndex < widget.imageUrls.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: _goToNext,
                  icon: const Icon(Icons.chevron_right, color: Colors.white, size: 40),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black38,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
