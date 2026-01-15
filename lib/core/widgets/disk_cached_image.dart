import 'dart:io';
import 'package:flutter/material.dart';
import '../services/disk_image_cache_service.dart';

/// 磁盘缓存图片组件
/// 
/// 使用 [DiskImageCacheService] 从磁盘加载图片，
/// 如果图片未缓存则自动下载并保存到磁盘。
/// 
/// 与 [CachedNetworkImage] 不同，此组件不使用内存缓存，
/// 所有图片都从磁盘读取，以减少内存占用。
/// 
/// 内存优化：
/// - 使用 gaplessPlayback 避免图片切换时的闪烁
/// - 在 dispose 时清理 _cachedFile 引用
/// - 支持 cacheWidth/cacheHeight 限制解码尺寸
class DiskCachedImage extends StatefulWidget {
  /// 图片 URL
  final String imageUrl;
  
  /// 图片填充方式
  final BoxFit? fit;
  
  /// 图片宽度
  final double? width;
  
  /// 图片高度
  final double? height;
  
  /// 加载中占位组件
  final Widget? placeholder;
  
  /// 加载失败占位组件
  final Widget? errorWidget;
  
  /// 图片对齐方式
  final Alignment alignment;
  
  /// 图片颜色混合
  final Color? color;
  
  /// 图片颜色混合模式
  final BlendMode? colorBlendMode;
  
  /// 淡入动画时长
  final Duration fadeInDuration;
  
  /// 解码缓存宽度（限制图片解码尺寸以节省内存）
  /// 设置后图片会以此宽度解码，而非原图宽度
  final int? cacheWidth;
  
  /// 解码缓存高度（限制图片解码尺寸以节省内存）
  /// 设置后图片会以此高度解码，而非原图高度
  final int? cacheHeight;

  const DiskCachedImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.alignment = Alignment.center,
    this.color,
    this.colorBlendMode,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  State<DiskCachedImage> createState() => _DiskCachedImageState();
}

class _DiskCachedImageState extends State<DiskCachedImage> {
  File? _cachedFile;
  bool _isLoading = true;
  bool _hasError = false;
  String? _lastUrl;  // 记录上次加载的 URL
  
  @override
  void initState() {
    super.initState();
    _loadImage();
  }
  
  @override
  void didUpdateWidget(DiskCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }
  
  @override
  void dispose() {
    // 清理文件引用，帮助 GC 回收
    _cachedFile = null;
    _lastUrl = null;
    super.dispose();
  }
  
  Future<void> _loadImage() async {
    // 如果 URL 没变且已加载，不重复加载
    if (widget.imageUrl == _lastUrl && _cachedFile != null && !_hasError) {
      return;
    }
    
    if (widget.imageUrl.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }
    
    _lastUrl = widget.imageUrl;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _cachedFile = null;
    });
    
    // 先检查同步缓存
    final syncFile = DiskImageCacheService.instance.getCachedFileSync(widget.imageUrl);
    if (syncFile != null) {
      if (mounted) {
        setState(() {
          _cachedFile = syncFile;
          _isLoading = false;
        });
      }
      return;
    }
    
    // 异步下载
    final file = await DiskImageCacheService.instance.getImage(widget.imageUrl);
    
    if (mounted) {
      setState(() {
        _cachedFile = file;
        _isLoading = false;
        _hasError = file == null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildPlaceholder();
    }
    
    if (_hasError || _cachedFile == null) {
      return _buildErrorWidget();
    }
    
    return AnimatedSwitcher(
      duration: widget.fadeInDuration,
      child: Image.file(
        _cachedFile!,
        key: ValueKey(_cachedFile!.path),
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        alignment: widget.alignment,
        color: widget.color,
        colorBlendMode: widget.colorBlendMode,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      ),
    );
  }
  
  Widget _buildPlaceholder() {
    return widget.placeholder ?? SizedBox(
      width: widget.width,
      height: widget.height,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
  
  Widget _buildErrorWidget() {
    return widget.errorWidget ?? SizedBox(
      width: widget.width,
      height: widget.height,
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }
}
