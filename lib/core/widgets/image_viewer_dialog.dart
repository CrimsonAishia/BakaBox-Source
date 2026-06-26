import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'disk_cached_image.dart';

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
      builder: (context) =>
          ImageViewerDialog(imageUrls: imageUrls, initialIndex: initialIndex),
    );
  }

  @override
  State<ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<ImageViewerDialog> {
  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;
  static const double _zoomStep = 0.4;

  late PageController _pageController;
  late int _currentIndex;
  final FocusNode _focusNode = FocusNode();
  final TransformationController _transformationController =
      TransformationController();

  /// 当前缩放比例（用于驱动百分比指示与按钮可用态）
  double _scale = 1.0;

  /// 当前页视口尺寸（用于以视口中心为锚点进行缩放）
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _transformationController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final next = _transformationController.value.getMaxScaleOnAxis();
    if ((next - _scale).abs() > 0.001) {
      setState(() => _scale = next);
    }
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

  /// 以视口中心为锚点设置缩放比例
  void _setScale(double target) {
    final clamped = target.clamp(_minScale, _maxScale);
    if (_viewportSize == Size.zero) {
      _transformationController.value = Matrix4.identity()
        ..scaleByDouble(clamped, clamped, 1, 1);
      return;
    }
    final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(
        -center.dx * (clamped - 1),
        -center.dy * (clamped - 1),
        0,
        1,
      )
      ..scaleByDouble(clamped, clamped, 1, 1);
  }

  void _zoomIn() => _setScale(_scale + _zoomStep);

  void _zoomOut() => _setScale(_scale - _zoomStep);

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
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
          } else if (event.logicalKey == LogicalKeyboardKey.equal ||
              event.logicalKey == LogicalKeyboardKey.add ||
              event.logicalKey == LogicalKeyboardKey.numpadAdd) {
            _zoomIn();
          } else if (event.logicalKey == LogicalKeyboardKey.minus ||
              event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
            _zoomOut();
          } else if (event.logicalKey == LogicalKeyboardKey.digit0 ||
              event.logicalKey == LogicalKeyboardKey.numpad0) {
            _resetZoom();
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
              onPageChanged: (index) {
                _resetZoom();
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {}, // 阻止点击图片关闭
                  onDoubleTap: () {
                    // 双击切换 1x / 2x，桌面端鼠标也能快速放大
                    if (_scale > 1.01) {
                      _resetZoom();
                    } else {
                      _setScale(2.0);
                    }
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _viewportSize = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      return SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: InteractiveViewer(
                          transformationController: index == _currentIndex
                              ? _transformationController
                              : null,
                          minScale: _minScale,
                          maxScale: _maxScale,
                          clipBehavior: Clip.none,
                          child: Center(
                            child: DiskCachedImage(
                              imageUrl: widget.imageUrls[index],
                              fit: BoxFit.contain,
                              placeholder: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                              errorWidget: Column(
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
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 40,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black38,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
            ),
          // 右箭头
          if (widget.imageUrls.length > 1 &&
              _currentIndex < widget.imageUrls.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: _goToNext,
                  icon: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 40,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black38,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
            ),
          // 底部缩放控制条
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(child: _buildZoomBar()),
          ),
        ],
      ),
    );
  }

  /// 底部缩放控制条：缩小 / 百分比 / 放大 / 重置
  Widget _buildZoomBar() {
    final canZoomOut = _scale > _minScale + 0.001;
    final canZoomIn = _scale < _maxScale - 0.001;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _zoomBtn(
            icon: Icons.remove_rounded,
            tooltip: '缩小 ( - )',
            enabled: canZoomOut,
            onTap: _zoomOut,
          ),
          GestureDetector(
            onTap: _resetZoom,
            child: Container(
              constraints: const BoxConstraints(minWidth: 56),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              child: Text(
                '${(_scale * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          _zoomBtn(
            icon: Icons.add_rounded,
            tooltip: '放大 ( + )',
            enabled: canZoomIn,
            onTap: _zoomIn,
          ),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: Colors.white.withValues(alpha: 0.15),
          ),
          _zoomBtn(
            icon: Icons.fit_screen_rounded,
            tooltip: '重置 ( 0 )',
            enabled: (_scale - 1.0).abs() > 0.001,
            onTap: _resetZoom,
          ),
        ],
      ),
    );
  }

  Widget _zoomBtn({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 22),
        color: Colors.white,
        disabledColor: Colors.white.withValues(alpha: 0.25),
        splashRadius: 20,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
