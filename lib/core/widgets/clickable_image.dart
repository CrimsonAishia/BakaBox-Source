import 'package:flutter/material.dart';
import '../services/image_url_service.dart';
import 'image_viewer_dialog.dart';

/// 可点击的图片组件
/// 
/// 支持：
/// - 点击放大查看
/// - Hover 效果（边框高亮、遮罩、放大图标）
/// - 加载状态
/// - 错误处理
/// - 圆角边框
/// - fileId引用格式自动获取签名URL
class ClickableImage extends StatefulWidget {
  final String imageUrl;
  final List<String>? allImageUrls;
  final int? currentIndex;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;

  const ClickableImage({
    super.key,
    required this.imageUrl,
    this.allImageUrls,
    this.currentIndex,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
  });

  @override
  State<ClickableImage> createState() => _ClickableImageState();
}

class _ClickableImageState extends State<ClickableImage> {
  String? _signedUrl;
  bool _isLoading = true;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  @override
  void didUpdateWidget(ClickableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadSignedUrl();
    }
  }

  Future<void> _loadSignedUrl() async {
    setState(() => _isLoading = true);
    try {
      final url = await ImageUrlService.instance.getSignedUrl(widget.imageUrl);
      if (mounted) {
        setState(() { _signedUrl = url; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _signedUrl = widget.imageUrl; _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return _buildLoadingPlaceholder(isDark);
    }

    final borderColor = _isHovering 
        ? const Color(0xFF0080FF) 
        : (isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFE5E7EB));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showImageViewer(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: borderColor,
              width: _isHovering ? 2 : 1,
            ),
            boxShadow: _isHovering ? [
              BoxShadow(
                color: const Color(0xFF0080FF).withValues(alpha: 0.15),
                blurRadius: 8,
              ),
            ] : null,
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius - 1),
                child: Image.network(
                  _signedUrl ?? widget.imageUrl,
                  width: widget.width,
                  height: widget.height,
                  fit: widget.fit,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildLoadingPlaceholder(isDark);
                  },
                  errorBuilder: (_, __, ___) => _buildErrorPlaceholder(isDark),
                ),
              ),
              // Hover 遮罩
              if (_isHovering)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.borderRadius - 1),
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                    child: const Center(
                      child: Icon(Icons.zoom_in_rounded, size: 24, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(bool isDark) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB)),
      ),
      child: const Center(
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0080FF))),
      ),
    );
  }

  Widget _buildErrorPlaceholder(bool isDark) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_rounded, size: 24, color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF)),
          const SizedBox(height: 4),
          Text('加载失败', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  Future<void> _showImageViewer(BuildContext context) async {
    final urls = widget.allImageUrls ?? [widget.imageUrl];
    final index = widget.currentIndex ?? 0;
    final signedUrls = await ImageUrlService.instance.getSignedUrls(urls);
    final resolvedUrls = urls.map((url) => signedUrls[url] ?? url).toList();
    if (context.mounted) {
      ImageViewerDialog.show(context, imageUrls: resolvedUrls, initialIndex: index);
    }
  }
}

/// 图片网格组件
class ImageGrid extends StatelessWidget {
  final List<String> imageUrls;
  final double imageWidth;
  final double imageHeight;
  final double spacing;
  final double borderRadius;

  const ImageGrid({
    super.key,
    required this.imageUrls,
    this.imageWidth = 120,
    this.imageHeight = 90,
    this.spacing = 8,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: imageUrls.asMap().entries.map((entry) {
        return ClickableImage(
          imageUrl: entry.value,
          allImageUrls: imageUrls,
          currentIndex: entry.key,
          width: imageWidth,
          height: imageHeight,
          borderRadius: borderRadius,
        );
      }).toList(),
    );
  }
}
