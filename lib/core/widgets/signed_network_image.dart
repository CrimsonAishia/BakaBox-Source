import 'package:flutter/material.dart';

import '../services/image_url_service.dart';
import 'disk_cached_image.dart';

/// 签名 URL 网络图片
///
/// 自动处理 `ImageUrlService.getSignedUrl(url)` → `DiskCachedImage` 的常见模式。
/// 当 [url] 为 null 或空字符串、签名失败时回退到 [fallback]。
///
/// 用法：
/// ```dart
/// SignedNetworkImage(
///   url: avatarUrl,
///   cacheWidth: 64,
///   cacheHeight: 64,
///   fallback: const Icon(Icons.person),
/// )
/// ```
class SignedNetworkImage extends StatefulWidget {
  /// 原始 URL（可以是文件 ID 引用或者完整 URL）
  final String? url;

  /// 占位/失败时的回退 widget
  final Widget fallback;

  /// 装载中显示的 widget（默认显示 fallback）
  final Widget? loading;

  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;

  const SignedNetworkImage({
    super.key,
    required this.url,
    required this.fallback,
    this.loading,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  State<SignedNetworkImage> createState() => _SignedNetworkImageState();
}

class _SignedNetworkImageState extends State<SignedNetworkImage> {
  Future<String>? _signedFuture;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant SignedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _resolve();
    }
  }

  void _resolve() {
    final url = widget.url;
    if (url != null && url.isNotEmpty) {
      _signedFuture = ImageUrlService.instance.getSignedUrl(url);
    } else {
      _signedFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_signedFuture == null) return widget.fallback;
    return FutureBuilder<String>(
      future: _signedFuture,
      builder: (context, snap) {
        if (snap.hasData) {
          return DiskCachedImage(
            imageUrl: snap.data!,
            fit: widget.fit,
            cacheWidth: widget.cacheWidth,
            cacheHeight: widget.cacheHeight,
          );
        }
        if (snap.hasError) return widget.fallback;
        return widget.loading ?? widget.fallback;
      },
    );
  }
}
