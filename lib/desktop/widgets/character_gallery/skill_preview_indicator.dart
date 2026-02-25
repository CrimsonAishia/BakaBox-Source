import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_the_tooltip/just_the_tooltip.dart';
import '../../../core/models/character_models.dart';
import '../../../core/widgets/disk_cached_image.dart';
import 'character_gallery_theme.dart';
import 'video_embed_dialog.dart';

/// 技能/符卡预览指示器
///
/// 整个卡片 hover 一段时间后显示 tooltip 预览：
/// - image: tooltip 显示缩略图，点击打开大图查看器
/// - video_url: tooltip 显示视频平台信息，点击打开 VideoEmbedDialog
///
/// 使用方式：包裹整个卡片内容
/// ```dart
/// SkillPreviewIndicator(
///   previewType: card.previewType,
///   previewImageUrl: card.previewImageUrl,
///   previewVideoUrl: card.previewVideoUrl,
///   skillName: card.name,
///   child: YourCardContent(),
/// )
/// ```
class SkillPreviewIndicator extends StatefulWidget {
  final PreviewType previewType;
  final String? previewImageUrl;
  final String? previewVideoUrl;
  final String? skillName;
  final Widget child;

  const SkillPreviewIndicator({
    super.key,
    required this.previewType,
    this.previewImageUrl,
    this.previewVideoUrl,
    this.skillName,
    required this.child,
  });

  @override
  State<SkillPreviewIndicator> createState() => _SkillPreviewIndicatorState();
}

class _SkillPreviewIndicatorState extends State<SkillPreviewIndicator>
    with TickerProviderStateMixin {
  final _tooltipController = JustTheController();
  bool _isHovered = false;
  bool _isTooltipHovered = false;
  bool _tooltipVisible = false;
  bool _isLoading = false; // loading 状态

  // hover 延迟计时器
  int _hoverStartTime = 0;
  static const _hoverDelay = 500; // 500ms 后显示 tooltip

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _loadingController; // loading 旋转动画

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _tooltipController.dispose();
    _pulseController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool hovered) {
    if (widget.previewType == PreviewType.none) return;

    setState(() => _isHovered = hovered);
    if (hovered) {
      _hoverStartTime = DateTime.now().millisecondsSinceEpoch;

      // 开始 loading 动画
      setState(() => _isLoading = true);
      _pulseController.repeat(reverse: true);
      _loadingController.repeat();

      // 延迟后显示 tooltip，停止 loading
      Future.delayed(const Duration(milliseconds: _hoverDelay), () {
        if (_isHovered && mounted) {
          final elapsed =
              DateTime.now().millisecondsSinceEpoch - _hoverStartTime;
          if (elapsed >= _hoverDelay - 50) {
            setState(() => _isLoading = false);
            _loadingController.stop();
            _pulseController.stop();
            _showTooltip();
          }
        }
      });
    } else {
      // 延迟关闭，给用户时间移到 tooltip 上
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!_isHovered && !_isTooltipHovered && mounted) {
          _hideTooltip();
          setState(() => _isLoading = false);
          _pulseController.stop();
          _pulseController.value = 0.0;
          _loadingController.stop();
          _loadingController.value = 0.0;
        }
      });
    }
  }

  void _onTooltipHoverChanged(bool hovered) {
    _isTooltipHovered = hovered;
    if (!hovered) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!_isHovered && !_isTooltipHovered && mounted) {
          _hideTooltip();
        }
      });
    }
  }

  void _showTooltip() {
    if (_tooltipVisible) return;
    try {
      _tooltipController.showTooltip(immediately: false);
      setState(() => _tooltipVisible = true);
    } catch (_) {}
  }

  void _hideTooltip() {
    if (!_tooltipVisible) return;
    try {
      _tooltipController.hideTooltip(immediately: false);
      setState(() => _tooltipVisible = false);
    } catch (_) {}
  }

  /// 重置所有 tooltip 相关状态（点击预览后调用）
  void _resetTooltipState() {
    try {
      _tooltipController.hideTooltip(immediately: true);
    } catch (_) {}
    setState(() {
      _tooltipVisible = false;
      _isTooltipHovered = false;
      _isLoading = false;
      _isHovered = false;
    });
    _pulseController.stop();
    _pulseController.value = 0.0;
    _loadingController.stop();
    _loadingController.value = 0.0;
  }

  IconData get _icon {
    return switch (widget.previewType) {
      PreviewType.image => Icons.photo_outlined,
      PreviewType.videoUrl || PreviewType.video => Icons.play_circle_outline,
      PreviewType.none => Icons.visibility,
    };
  }

  void _showFullImage(BuildContext context) {
    if (widget.previewImageUrl == null || widget.previewImageUrl!.isEmpty) {
      return;
    }
    // 重置状态
    _resetTooltipState();
    showDialog(
      context: context,
      builder: (_) => SkillPreviewImageDialog(
        imageUrl: widget.previewImageUrl!,
        title: widget.skillName ?? '预览',
      ),
    );
  }

  void _openVideo(BuildContext context) {
    if (widget.previewVideoUrl == null || widget.previewVideoUrl!.isEmpty) {
      return;
    }
    if (!VideoEmbedDialog.canEmbed(widget.previewVideoUrl!)) return;
    // 重置状态
    _resetTooltipState();
    showDialog(
      context: context,
      builder: (_) => VideoEmbedDialog(videoUrl: widget.previewVideoUrl!),
    );
  }

  Widget _buildTooltipContent() {
    if (widget.previewType == PreviewType.image &&
        widget.previewImageUrl != null &&
        widget.previewImageUrl!.isNotEmpty) {
      return MouseRegion(
        onEnter: (_) => _onTooltipHoverChanged(true),
        onExit: (_) => _onTooltipHoverChanged(false),
        child: _ImageTooltipContent(
          imageUrl: widget.previewImageUrl!,
          onTap: () => _showFullImage(context),
        ),
      );
    }

    if ((widget.previewType == PreviewType.videoUrl ||
            widget.previewType == PreviewType.video) &&
        widget.previewVideoUrl != null &&
        widget.previewVideoUrl!.isNotEmpty) {
      final info = _getPlatformInfo(widget.previewVideoUrl!);
      return MouseRegion(
        onEnter: (_) => _onTooltipHoverChanged(true),
        onExit: (_) => _onTooltipHoverChanged(false),
        child: _VideoTooltipContent(
          videoUrl: widget.previewVideoUrl!,
          platformName: info.name,
          platformColor: info.color,
          onTap: () => _openVideo(context),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    // 无预览时直接返回子组件
    if (widget.previewType == PreviewType.none) {
      return widget.child;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 卡片内容 + hover 效果
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                widget.child,
                // hover 高亮边框
                if (_isHovered)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 右上角指示器图标（默认显示，hover 时高亮）
          Positioned(
              top: 6,
              right: 6,
              child: JustTheTooltip(
                controller: _tooltipController,
                isModal: true,
                preferredDirection: AxisDirection.up,
                tailLength: 8,
                tailBaseWidth: 14,
                offset: 4,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: Colors.grey.shade900,
                barrierDismissible: true,
                content: _buildTooltipContent(),
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isLoading ? _pulseAnimation.value : 1.0,
                      child: child,
                    );
                  },
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 背景圆（hover 时高亮）
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isHovered
                                ? Colors.black.withValues(alpha: 0.7)
                                : Colors.black.withValues(alpha: 0.4),
                            boxShadow: _isHovered
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            _icon,
                            size: 16,
                            color: _isHovered
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        // Loading 环（hover 时显示）
                        if (_isLoading)
                          AnimatedBuilder(
                            animation: _loadingController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _loadingController.value * 2 * 3.14159,
                                child: child,
                              );
                            },
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: null,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 图片预览 tooltip 内容
class _ImageTooltipContent extends StatefulWidget {
  final String imageUrl;
  final VoidCallback onTap;

  const _ImageTooltipContent({
    required this.imageUrl,
    required this.onTap,
  });

  @override
  State<_ImageTooltipContent> createState() => _ImageTooltipContentState();
}

class _ImageTooltipContentState extends State<_ImageTooltipContent> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints:
                    const BoxConstraints(maxWidth: 260, maxHeight: 160),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        width: 100,
                        height: 60,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        width: 100,
                        height: 60,
                        child: Center(
                            child: Icon(Icons.broken_image,
                                size: 24, color: Colors.white54)),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.zoom_in,
                    size: 12,
                    color:
                        Colors.white.withValues(alpha: _isHovered ? 0.9 : 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '点击查看大图',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white
                          .withValues(alpha: _isHovered ? 0.9 : 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 视频预览 tooltip 内容（显示封面图 + 播放按钮）
class _VideoTooltipContent extends StatefulWidget {
  final String videoUrl;
  final String platformName;
  final Color platformColor;
  final VoidCallback onTap;

  const _VideoTooltipContent({
    required this.videoUrl,
    required this.platformName,
    required this.platformColor,
    required this.onTap,
  });

  @override
  State<_VideoTooltipContent> createState() => _VideoTooltipContentState();
}

class _VideoTooltipContentState extends State<_VideoTooltipContent> {
  bool _isHovered = false;
  String? _coverUrl;
  bool _isLoadingCover = true;

  @override
  void initState() {
    super.initState();
    _fetchCover();
  }

  Future<void> _fetchCover() async {
    // 尝试获取 B 站视频封面
    final bvid = _extractBvid(widget.videoUrl);
    if (bvid != null) {
      try {
        final response = await Future.any([
          _fetchBilibiliCover(bvid),
          Future.delayed(const Duration(seconds: 3), () => null),
        ]);
        if (mounted && response != null) {
          setState(() {
            _coverUrl = response;
            _isLoadingCover = false;
          });
          return;
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _isLoadingCover = false);
    }
  }

  Future<String?> _fetchBilibiliCover(String bvid) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.bilibili.com/x/web-interface/view?bvid=$bvid'),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0) {
          return data['data']['pic'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 封面图 + 播放按钮
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 240,
                height: 135,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isHovered
                        ? widget.platformColor.withValues(alpha: 0.6)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 封面图或占位
                      if (_coverUrl != null)
                        Image.network(
                          _coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      else if (_isLoadingCover)
                        _buildLoadingPlaceholder()
                      else
                        _buildPlaceholder(),
                      // 半透明遮罩
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        color: Colors.black
                            .withValues(alpha: _isHovered ? 0.3 : 0.4),
                      ),
                      // 播放按钮
                      Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: _isHovered ? 56 : 48,
                          height: _isHovered ? 56 : 48,
                          decoration: BoxDecoration(
                            color: widget.platformColor
                                .withValues(alpha: _isHovered ? 0.95 : 0.85),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: _isHovered ? 36 : 30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // 平台标签
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_circle_outline,
                                size: 12,
                                color: widget.platformColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.platformName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // 提示文字
              Text(
                '点击播放视频',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: _isHovered ? 0.9 : 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF2D2D2D),
      child: Center(
        child: Icon(
          Icons.videocam_outlined,
          size: 48,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: const Color(0xFF2D2D2D),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// 从 B站 URL 提取 BV 号
String? _extractBvid(String url) {
  final match = RegExp(r'BV[\w]+').firstMatch(url);
  return match?.group(0);
}

/// 视频平台信息
class _VideoPlatformInfo {
  final String name;
  final Color color;
  const _VideoPlatformInfo({required this.name, required this.color});
}

/// 根据 URL 识别视频平台
_VideoPlatformInfo _getPlatformInfo(String url) {
  final lowerUrl = url.toLowerCase();

  if (lowerUrl.contains('bilibili.com') || lowerUrl.contains('b23.tv')) {
    return const _VideoPlatformInfo(
      name: 'Bilibili',
      color: Color(0xFFFB7299),
    );
  }

  final path = lowerUrl.split('?').first;
  if (path.endsWith('.mp4') ||
      path.endsWith('.webm') ||
      path.endsWith('.ogg') ||
      path.endsWith('.mov')) {
    return const _VideoPlatformInfo(
      name: '视频直链',
      color: Color(0xFF4A90D9),
    );
  }

  return const _VideoPlatformInfo(
    name: '视频',
    color: Color(0xFF607D8B),
  );
}


/// 技能预览图片查看器对话框
class SkillPreviewImageDialog extends StatefulWidget {
  final String imageUrl;
  final String title;

  const SkillPreviewImageDialog({
    super.key,
    required this.imageUrl,
    required this.title,
  });

  @override
  State<SkillPreviewImageDialog> createState() => _SkillPreviewImageDialogState();
}

class _SkillPreviewImageDialogState extends State<SkillPreviewImageDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _close() {
    _animController.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: inkColor.withValues(alpha: isDark ? 0.3 : 0.9),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.photo_outlined,
                        color: isDark ? Colors.white70 : Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _CloseButton(onTap: _close),
                    ],
                  ),
                ),
                // 图片区域
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 200),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black : const Color(0xFFF5F5F5),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: DiskCachedImage(
                          imageUrl: widget.imageUrl,
                          fit: BoxFit.contain,
                          placeholder: const Center(
                            child: Padding(
                              padding: EdgeInsets.all(48),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(48),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.broken_image_outlined,
                                      size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    '图片加载失败',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 关闭按钮
class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.close,
            size: 18,
            color: Colors.white.withValues(alpha: _isHovered ? 1.0 : 0.7),
          ),
        ),
      ),
    );
  }
}
