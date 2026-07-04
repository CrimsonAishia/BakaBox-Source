import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/services/image_url_service.dart';
import '../../../../core/utils/log_service.dart';
import '../../../../core/widgets/disk_cached_image.dart';

/// Hover 缩放效果组件
class HoverScaleWidget extends StatefulWidget {
  final Widget child;

  const HoverScaleWidget({
    super.key,required this.child});

  @override
  State<HoverScaleWidget> createState() => _HoverScaleWidgetState();
}

class _HoverScaleWidgetState extends State<HoverScaleWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: widget.child,
      ),
    );
  }
}

/// Hover 遮罩组件
class HoverOverlay extends StatefulWidget {
  final Widget child;

  const HoverOverlay({
    super.key,required this.child});

  @override
  State<HoverOverlay> createState() => _HoverOverlayState();
}

class _HoverOverlayState extends State<HoverOverlay> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedOpacity(
        opacity: _isHovered ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: widget.child,
      ),
    );
  }
}

/// 贡献图片组件
///
/// 支持 fileId 引用格式（file:xxx）和普通 URL
/// 自动获取签名 URL 并缓存
class ContributionImage extends StatefulWidget {
  final String imageRef;
  final BoxFit fit;

  const ContributionImage({
    super.key,required this.imageRef, this.fit = BoxFit.cover});

  @override
  State<ContributionImage> createState() => _ContributionImageState();
}

class _ContributionImageState extends State<ContributionImage> {
  String? _signedUrl;
  bool _isLoading = true;
  bool _hasError = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  @override
  void didUpdateWidget(ContributionImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageRef != widget.imageRef) {
      _loadSignedUrl();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _loadSignedUrl() async {
    if (_disposed) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final url = await ImageUrlService.instance.getSignedUrl(widget.imageRef);
      if (!_disposed && mounted) {
        setState(() {
          _signedUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      LogService.d('加载签名URL失败: $e');
      if (!_disposed && mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_hasError || _signedUrl == null) {
      return Center(
        child: Icon(
          MdiIcons.imageOff,
          color: isDark ? Colors.white24 : Colors.black26,
        ),
      );
    }

    return DiskCachedImage(
      imageUrl: _signedUrl!,
      fit: widget.fit,
      placeholder: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: Center(
        child: Icon(
          MdiIcons.imageOff,
          color: isDark ? Colors.white24 : Colors.black26,
        ),
      ),
    );
  }
}
