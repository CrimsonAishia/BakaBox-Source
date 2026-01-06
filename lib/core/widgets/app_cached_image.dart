import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utils/image_cache_manager.dart';

/// 应用统一的网络图片组件
/// 自动使用自定义缓存管理器（桌面端缓存到 我的文档/bakabox/cache/images）
/// 自动提取稳定的缓存 key，避免带鉴权参数的 URL 重复下载
class AppCachedImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit? fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  final double? width;
  final double? height;

  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: AppImageCacheManager.extractCacheKey(imageUrl),
      cacheManager: AppImageCacheManager.instance,
      fit: fit,
      width: width,
      height: height,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}
