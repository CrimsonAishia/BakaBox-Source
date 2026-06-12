import 'package:flutter/material.dart';
import '../utils/map_utils.dart';
import '../utils/log_service.dart';
import '../services/image_url_service.dart';
import '../services/disk_image_cache_service.dart';
import 'disk_cached_image.dart';
import '../constants/app_colors.dart';

/// 统一的地图背景组件
///
/// 自动处理：
/// - 网络图片加载和缓存
/// - 本地资源图片
/// - fileId 引用格式（file:xxx）自动获取签名 URL
/// - 默认背景 fallback
/// - 地图变化时的刷新
/// - 图片解码尺寸限制（节省内存）
class MapBackground extends StatefulWidget {
  /// 地图名称（用于生成缓存 key）
  final String? mapName;

  /// 地图背景 URL（可以是网络 URL、本地资源路径或 fileId 引用格式）
  final String? imageUrl;

  /// 圆角
  final BorderRadius? borderRadius;

  /// 图片填充方式
  final BoxFit fit;

  /// 解码缓存宽度（限制图片解码尺寸以节省内存）
  /// 建议设置为显示宽度的 2 倍以保证清晰度
  final int? cacheWidth;

  /// 解码缓存高度（限制图片解码尺寸以节省内存）
  /// 建议设置为显示高度的 2 倍以保证清晰度
  final int? cacheHeight;

  const MapBackground({
    super.key,
    this.mapName,
    this.imageUrl,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
  });

  /// 从 mapName 和 mapUrl 构建
  factory MapBackground.fromMap({
    Key? key,
    String? mapName,
    String? mapUrl,
    BorderRadius? borderRadius,
    BoxFit fit = BoxFit.cover,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    final url = MapUtils.getMapImageUrl(mapName, mapUrl: mapUrl);
    return MapBackground(
      key: key,
      mapName: mapName,
      imageUrl: url,
      borderRadius: borderRadius,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  @override
  State<MapBackground> createState() => _MapBackgroundState();
}

class _MapBackgroundState extends State<MapBackground>
    with SingleTickerProviderStateMixin {
  String? _resolvedUrl;
  bool _isLoading = false;
  bool _animationCompleted = false; // 动画完成后移除底层渐变
  String? _lastImageUrl; // 缓存上次的 imageUrl，避免重复解析

  // 淡入动画控制器（用于本地资源图片）
  late AnimationController _fadeController;
  late CurvedAnimation _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.addStatusListener(_onAnimationStatus);
    _resolveUrl();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _animationCompleted = true);
    }
  }

  @override
  void didUpdateWidget(MapBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _fadeController.reset();
      _animationCompleted = false;
      _resolveUrl();
    }
  }

  @override
  void dispose() {
    _fadeController.removeStatusListener(_onAnimationStatus);
    _fadeAnimation.dispose();
    _fadeController.dispose();
    _resolvedUrl = null;
    _lastImageUrl = null;
    super.dispose();
  }

  Future<void> _resolveUrl() async {
    final url = (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
        ? widget.imageUrl!
        : MapUtils.defaultMapBackground;

    // 如果 URL 没变，不需要重新解析
    if (url == _lastImageUrl && _resolvedUrl != null) {
      return;
    }
    _lastImageUrl = url;

    // 如果是 fileId 引用格式，需要获取签名 URL
    if (ImageUrlService.isFileIdRef(url)) {
      // 只在首次加载时显示 loading，避免闪烁
      if (_resolvedUrl == null) {
        setState(() => _isLoading = true);
      }
      try {
        final signedUrl = await ImageUrlService.instance.getSignedUrl(url);
        if (mounted) {
          setState(() {
            _resolvedUrl = signedUrl;
            _isLoading = false;
          });
        }
      } catch (e) {
        LogService.d('加载地图背景签名URL失败: $e');
        if (mounted) {
          setState(() {
            _resolvedUrl = MapUtils.defaultMapBackground;
            _isLoading = false;
          });
        }
      }
    } else {
      // 非 fileId 格式，直接设置（合并为一次 setState）
      if (_resolvedUrl != url || _isLoading) {
        setState(() {
          _resolvedUrl = url;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _resolvedUrl == null) {
      return _buildDefaultBackground();
    }

    final url = _resolvedUrl!;
    // 原始的 imageUrl，用于生成稳定的缓存 key
    final originalUrl = widget.imageUrl ?? MapUtils.defaultMapBackground;

    Widget child;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      // 生成稳定的缓存 key
      // 如果原始 URL 是 fileId 格式（file:xxx），使用它作为缓存 key
      // 否则使用 URL 的 host+path 作为缓存 key（忽略查询参数）
      final cacheKey = ImageUrlService.isFileIdRef(originalUrl)
          ? originalUrl
          : DiskImageCacheService.extractCacheKey(url);

      child = DiskCachedImage(
        // 使用 cacheKey 作为 widget key，确保图片变化时刷新
        key: ValueKey('map_bg_$cacheKey'),
        imageUrl: url,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        // 不传 placeholder，使用默认的 loading 指示器
        // 图片加载完成后会淡入显示
        fallbackAsset: MapUtils.defaultMapBackground,
        errorWidget: _buildDefaultBackground(),
      );
    } else {
      // 本地资源图片
      final assetImage = Image.asset(
        url,
        key: ValueKey('map_bg_asset_${widget.mapName ?? ''}_$url'),
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            // 图片加载完成，播放淡入动画
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted &&
                  !_fadeController.isAnimating &&
                  _fadeController.value == 0) {
                _fadeController.forward();
              }
            });
            return child;
          }
          return const SizedBox.shrink();
        },
        errorBuilder: (context, error, stackTrace) {
          // 如果不是默认背景加载失败，尝试加载默认背景
          if (url != MapUtils.defaultMapBackground) {
            return _buildDefaultBackground();
          }
          // 默认背景也加载失败，显示渐变兜底
          return _buildFallbackGradient();
        },
      );

      // 动画完成后直接返回图片，移除底层渐变释放内存
      if (_animationCompleted) {
        child = assetImage;
      } else {
        child = Stack(
          fit: StackFit.expand,
          children: [
            _buildFallbackGradient(),
            FadeTransition(opacity: _fadeAnimation, child: assetImage),
          ],
        );
      }
    }

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }
    return child;
  }

  Widget _buildDefaultBackground() {
    return Image.asset(
      MapUtils.defaultMapBackground,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => _buildFallbackGradient(),
    );
  }

  Widget _buildFallbackGradient() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.slate800, AppColors.slate700],
        ),
      ),
    );
  }
}
