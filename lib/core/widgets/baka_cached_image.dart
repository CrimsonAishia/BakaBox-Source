import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/image_utils.dart';

/// 一个封装了 CachedNetworkImage 的组件，专门用来替代原生的 Image.network。
/// 它会自动通过 LayoutBuilder 或提供的宽高，计算出一个适合的内存解码尺寸（memCacheWidth/memCacheHeight），
/// 从而极大节省由于图片尺寸过大造成的内存消耗。
class BakaCachedImage extends StatelessWidget {
  final String src;
  final double scale;
  final Widget Function(BuildContext, Widget, int?, bool)? frameBuilder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final double? width;
  final double? height;
  final Color? color;
  final Animation<double>? opacity;
  final BlendMode? colorBlendMode;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final Rect? centerSlice;
  final bool matchTextDirection;
  final bool gaplessPlayback;
  final FilterQuality filterQuality;
  final bool isAntiAlias;
  final Map<String, String>? headers;
  final int? cacheWidth;
  final int? cacheHeight;
  final String? cacheKey;

  const BakaCachedImage(
    this.src, {
    super.key,
    this.scale = 1.0,
    this.frameBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.width,
    this.height,
    this.color,
    this.opacity,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.gaplessPlayback = false,
    this.filterQuality = FilterQuality.low,
    this.isAntiAlias = false,
    this.headers,
    this.cacheWidth,
    this.cacheHeight,
    this.cacheKey,
  });

  @override
  Widget build(BuildContext context) {
    if (src.isEmpty) {
      return errorBuilder?.call(context, Exception("Empty URL"), StackTrace.empty) ?? 
             const SizedBox.shrink();
    }

    if (cacheWidth != null || cacheHeight != null) {
      return _buildImage(cacheWidth, cacheHeight);
    }

    // 如果直接提供了有效的 width 或 height，基于 devicePixelRatio 计算缓存尺寸
    final hasFiniteWidth = width != null && width!.isFinite;
    final hasFiniteHeight = height != null && height!.isFinite;
    
    if (hasFiniteWidth || hasFiniteHeight) {
      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      int? cw = hasFiniteWidth ? (width! * devicePixelRatio).toInt() : null;
      int? ch = hasFiniteHeight ? (height! * devicePixelRatio).toInt() : null;
      return _buildImage(cw, ch);
    }

    // 否则通过 LayoutBuilder 动态获取容器大小来限制解码大小
    return LayoutBuilder(
      builder: (context, constraints) {
        final memSize = ImageUtils.calculateMemCacheSize(
          context: context,
          constraints: constraints,
          width: width,
          height: height,
        );
        return _buildImage(memSize.width, memSize.height);
      },
    );
  }

  Widget _buildImage(int? memCacheW, int? memCacheH) {
    final finalHeaders = ImageUtils.getBilibiliHeaders(src, headers);
    final safeCacheKey = ImageUtils.generateSafeCacheKey(cacheKey);

    return CachedNetworkImage(
      imageUrl: src,
      cacheKey: safeCacheKey,
      httpHeaders: finalHeaders,
      width: width,
      height: height,
      color: color,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment as Alignment,
      repeat: repeat,
      matchTextDirection: matchTextDirection,
      filterQuality: filterQuality,
      memCacheWidth: memCacheW,
      memCacheHeight: memCacheH,
      errorWidget: errorBuilder != null 
          ? (context, url, error) => errorBuilder!(context, error, StackTrace.empty)
          : (context, url, error) => const SizedBox.shrink(),
      fadeInDuration: const Duration(milliseconds: 300),
    );
  }
}

/// 替代 NetworkImage 的 Provider
CachedNetworkImageProvider bakaCachedImageProvider(String url, {
  double scale = 1.0,
  Map<String, String>? headers,
  String? cacheKey,
  int? maxWidth,
  int? maxHeight,
}) {
  final finalHeaders = ImageUtils.getBilibiliHeaders(url, headers);
  final safeCacheKey = ImageUtils.generateSafeCacheKey(cacheKey);

  return CachedNetworkImageProvider(
    url,
    scale: scale,
    headers: finalHeaders,
    cacheKey: safeCacheKey,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
  );
}
