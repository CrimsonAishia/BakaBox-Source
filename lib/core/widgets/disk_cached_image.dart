import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/image_utils.dart';
import '../services/disk_image_cache_service.dart';

/// 磁盘缓存图片组件（纯文件缓存方案）
///
/// 专为多窗口（Multi-Window）和高并发场景设计，避免使用 sqlite（CachedNetworkImage 底层）导致的
/// 跨 Isolate/进程数据库死锁问题。结合 LayoutBuilder 和 cacheWidth/cacheHeight 自动控制解码内存。
class DiskCachedImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final FilterQuality filterQuality;
  final int? cacheWidth;
  final int? cacheHeight;
  final String? fallbackAsset;
  final Widget? errorWidget;
  final Widget? placeholder;
  final Color? color;
  final BlendMode? colorBlendMode;
  final bool disableMemCache;

  const DiskCachedImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.filterQuality = FilterQuality.low,
    this.cacheWidth,
    this.cacheHeight,
    this.fallbackAsset,
    this.errorWidget,
    this.placeholder,
    this.color,
    this.colorBlendMode,
    this.disableMemCache = false,
  });

  @override
  State<DiskCachedImage> createState() => _DiskCachedImageState();
}

class _DiskCachedImageState extends State<DiskCachedImage> {
  File? _imageFile;
  bool _isLoading = true;
  bool _hasError = false;
  int? _lastMemWidth;
  int? _lastMemHeight;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant DiskCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final file = await DiskImageCacheService.instance.getImage(
        widget.imageUrl,
        maxRetries: 2,
      );
      if (mounted) {
        setState(() {
          _imageFile = file;
          _isLoading = false;
          _hasError = file == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFiniteWidth = widget.width != null && widget.width!.isFinite;
    final hasFiniteHeight = widget.height != null && widget.height!.isFinite;

    if (widget.cacheWidth != null ||
        widget.cacheHeight != null ||
        hasFiniteWidth ||
        hasFiniteHeight) {
      return _buildContent(context, null);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildContent(context, constraints);
      },
    );
  }

  Widget _buildContent(BuildContext context, BoxConstraints? constraints) {
    if (_isLoading) {
      return widget.placeholder ??
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
    }

    if (_hasError || _imageFile == null) {
      if (widget.fallbackAsset != null) {
        return Image.asset(
          widget.fallbackAsset!,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          alignment: widget.alignment,
          color: widget.color,
          colorBlendMode: widget.colorBlendMode,
          cacheWidth: widget.cacheWidth,
          cacheHeight: widget.cacheHeight,
        );
      }
      return widget.errorWidget ??
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
    }

    int? memWidth = widget.cacheWidth;
    int? memHeight = widget.cacheHeight;

    if (!widget.disableMemCache) {
      final memSize = ImageUtils.calculateMemCacheSize(
        context: context,
        constraints: constraints,
        width: widget.width,
        height: widget.height,
      );

      int? calculatedWidth = memSize.width;
      int? calculatedHeight = memSize.height;

      // 允许 15 像素（约等于 DPR=2 下的 7 逻辑像素）的容差。
      // 这完美解决了卡片 hover 动画（如边框变粗）导致物理像素发生个位数微变，
      // 从而触发 cacheWidth 改变并重新解码闪烁图片的深层 Bug。
      if (calculatedWidth != null) {
        if (_lastMemWidth != null &&
            (calculatedWidth - _lastMemWidth!).abs() <= 15) {
          calculatedWidth = _lastMemWidth;
        } else {
          _lastMemWidth = calculatedWidth;
        }
      }

      if (calculatedHeight != null) {
        if (_lastMemHeight != null &&
            (calculatedHeight - _lastMemHeight!).abs() <= 15) {
          calculatedHeight = _lastMemHeight;
        } else {
          _lastMemHeight = calculatedHeight;
        }
      }

      memWidth ??= calculatedWidth;
      memHeight ??= calculatedHeight;
    }

    return Image.file(
      _imageFile!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      alignment: widget.alignment,
      repeat: widget.repeat,
      filterQuality: widget.filterQuality,
      cacheWidth: memWidth,
      cacheHeight: memHeight,
      color: widget.color,
      colorBlendMode: widget.colorBlendMode,
      errorBuilder: (context, error, stackTrace) {
        if (widget.fallbackAsset != null) {
          return Image.asset(
            widget.fallbackAsset!,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            alignment: widget.alignment,
            color: widget.color,
            colorBlendMode: widget.colorBlendMode,
          );
        }
        return widget.errorWidget ??
            SizedBox(
              width: widget.width,
              height: widget.height,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
      },
    );
  }
}
