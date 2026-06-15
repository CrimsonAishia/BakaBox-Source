import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/models/character_models.dart';
import '../../../core/services/bilibili_service.dart';
import '../../../core/services/webview_environment_service.dart';

/// 视频内嵌播放弹窗
///
/// 支持：
/// - Bilibili 直链（bilibili_parsed）：使用 video_player 播放，设置 Referer 头
/// - Bilibili 原始链接：使用 WebView iframe 嵌入播放器
/// - 视频直链（mp4/webm）：使用 video_player 播放
class VideoEmbedDialog extends StatefulWidget {
  final String videoUrl;
  final String? title;
  final VideoUrlSource? videoUrlSource;
  final String? videoOriginUrl; // 原始视频地址，用于获取封面

  const VideoEmbedDialog({
    super.key,
    required this.videoUrl,
    this.title,
    this.videoUrlSource,
    this.videoOriginUrl,
  });

  /// 判断 URL 是否支持内嵌播放
  static bool canEmbed(String url, {VideoUrlSource? videoUrlSource}) {
    if (videoUrlSource == VideoUrlSource.bilibiliParsed) return true;
    return _isBilibili(url) || _isDirectVideo(url);
  }

  @override
  State<VideoEmbedDialog> createState() => _VideoEmbedDialogState();
}

class _VideoEmbedDialogState extends State<VideoEmbedDialog> {
  // video_player 控制器（用于直链）
  VideoPlayerController? _controller;

  // WebView 状态标志
  bool _isWebViewReady = false;

  bool _isPlaying = false;
  bool _hasError = false;
  String? _errorMessage;

  // B站封面信息
  String? _coverUrl;
  String? _videoTitle;
  bool _isFetchingCover = false;

  // 是否使用 WebView（非直链B站视频）
  bool get _useWebView =>
      widget.videoUrlSource != VideoUrlSource.bilibiliParsed &&
      _isBilibili(widget.videoUrl);

  @override
  void initState() {
    super.initState();
    // 先获取封面，然后自动开始播放
    if (widget.videoUrlSource == VideoUrlSource.bilibiliParsed) {
      // B站直链：使用原始地址获取封面，然后用 video_player 播放
      _fetchBilibiliCoverFromOrigin().then((_) => _startVideoPlayback());
    } else if (_isBilibili(widget.videoUrl)) {
      // B站原始链接：获取封面，然后用 WebView 嵌入播放
      _fetchBilibiliCover().then((_) => _startWebViewPlayback());
    } else {
      // 普通直链：用 video_player 播放
      _startVideoPlayback();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// 获取B站视频封面和标题
  Future<void> _fetchBilibiliCover() async {
    setState(() => _isFetchingCover = true);

    try {
      final meta = await BilibiliService.fetchMeta(widget.videoUrl);
      if (mounted && meta != null) {
        setState(() {
          _coverUrl = meta.coverUrl;
          _videoTitle = meta.title;
        });
      }
    } catch (_) {}

    if (mounted) setState(() => _isFetchingCover = false);
  }

  /// 从原始B站地址获取封面（用于直链解析后的情况）
  Future<void> _fetchBilibiliCoverFromOrigin() async {
    setState(() => _isFetchingCover = true);

    try {
      // 优先使用原始地址
      final originUrl = widget.videoOriginUrl;
      if (originUrl != null && originUrl.isNotEmpty) {
        final meta = await BilibiliService.fetchMeta(originUrl);
        if (mounted && meta != null) {
          setState(() {
            _coverUrl = meta.coverUrl;
            _videoTitle = meta.title;
          });
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isFetchingCover = false);
  }

  /// 使用 WebView 播放B站原始链接（iframe 嵌入）
  Future<void> _startWebViewPlayback() async {
    if (!mounted) return;
    setState(() {
      _isPlaying = true;
      _isWebViewReady = true;
    });
  }

  /// 使用 video_player 播放直链视频
  Future<void> _startVideoPlayback() async {
    setState(() => _isPlaying = true);

    try {
      final url = widget.videoUrl;

      // B站直链需要设置 Referer 头
      if (widget.videoUrlSource == VideoUrlSource.bilibiliParsed) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          httpHeaders: {
            'Referer': 'https://www.bilibili.com/',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        );
      } else {
        _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }

      await _controller!.initialize();

      // 监听错误
      _controller!.addListener(_onVideoPlayerUpdate);

      // 开始播放
      await _controller!.play();

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '初始化播放器失败：$e';
        });
      }
    }
  }

  void _onVideoPlayerUpdate() {
    if (!mounted) return;
    final value = _controller?.value;
    if (value != null && value.hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = '播放失败：${value.errorDescription}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBili =
        _isBilibili(widget.videoUrl) ||
        widget.videoUrlSource == VideoUrlSource.bilibiliParsed;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(40),
      child: Container(
        width: 800,
        height: 520,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildTitleBar(isDark, isBili),
            Expanded(child: _buildContent(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar(bool isDark, bool isBili) {
    final color = isBili ? const Color(0xFFFB7299) : const Color(0xFF4A90D9);
    final displayTitle =
        widget.title ?? _videoTitle ?? (isBili ? 'Bilibili 视频预览' : '视频预览');

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Icon(
            isBili ? Icons.play_circle_filled : Icons.videocam_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayTitle,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => _openInBrowser(widget.videoUrl),
            icon: Icon(
              Icons.open_in_new,
              size: 16,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            tooltip: '在浏览器中打开',
            splashRadius: 16,
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.close,
              size: 18,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            tooltip: '关闭',
            splashRadius: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[500]),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? '无法加载视频',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (widget.videoUrlSource == VideoUrlSource.bilibiliParsed) ...[
              const SizedBox(height: 8),
              Text(
                '直链可能已过期，请刷新页面重试',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _openInBrowser(widget.videoUrl),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('在浏览器中打开'),
            ),
          ],
        ),
      );
    }

    // WebView 播放（B站原始链接）
    if (_useWebView) {
      if (_isPlaying && _isWebViewReady) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(12),
          ),
          child: Container(
            color: Colors.black,
            child: InAppWebView(
              webViewEnvironment: WebViewEnvironmentService.environment,
              initialUrlRequest: URLRequest(url: WebUri(_buildBilibiliEmbedUrl(widget.videoUrl))),
              initialSettings: InAppWebViewSettings(
                transparentBackground: true,
                supportMultipleWindows: false,
              ),
              onCreateWindow: (controller, createWindowAction) async {
                return false;
              },
              onPermissionRequest: (controller, request) async {
                return PermissionResponse(
                  resources: request.resources,
                  action: PermissionResponseAction.DENY,
                );
              },
              onReceivedError: (controller, request, error) {
                if (mounted) {
                  setState(() {
                    _hasError = true;
                    _errorMessage = '加载失败: ${error.description}';
                  });
                }
              },
            ),
          ),
        );
      }
    } else {
      // video_player 播放（直链）
      if (_isPlaying &&
          _controller != null &&
          _controller!.value.isInitialized) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(12),
          ),
          child: _buildVideoPlayer(),
        );
      }
    }

    // 加载中 — 显示封面（如果有）+ loading
    return _buildLoadingWithCover(isDark);
  }

  /// 构建视频播放器（带简单控制）
  Widget _buildVideoPlayer() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 视频画面
        Center(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
        ),
        // 简单控制层
        _VideoControlsOverlay(controller: _controller!),
      ],
    );
  }

  Widget _buildLoadingWithCover(bool isDark) {
    final isBili =
        _isBilibili(widget.videoUrl) ||
        widget.videoUrlSource == VideoUrlSource.bilibiliParsed;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 封面图
          if (_coverUrl != null)
            Image.network(
              _coverUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(isBili),
            )
          else
            _buildPlaceholder(isBili),

          // 半透明遮罩
          Container(color: Colors.black.withValues(alpha: 0.4)),

          // 居中 loading
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: isBili ? const Color(0xFFFB7299) : Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isFetchingCover ? '获取视频信息...' : '加载播放器...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // 视频标题（底部）
          if (_videoTitle != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Text(
                _videoTitle!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 4,
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  /// 构建占位图
  Widget _buildPlaceholder(bool isBili) {
    return Container(
      color: isBili ? const Color(0xFF1A1A1A) : Colors.black,
      child: Center(
        child: Icon(
          isBili ? Icons.play_circle_outline : Icons.videocam_outlined,
          size: 64,
          color: isBili
              ? const Color(0xFFFB7299).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// 简单的视频控制层
class _VideoControlsOverlay extends StatefulWidget {
  final VideoPlayerController controller;

  const _VideoControlsOverlay({required this.controller});

  @override
  State<_VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<_VideoControlsOverlay> {
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onTap() {
    setState(() => _showControls = true);
    _startHideTimer();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;

    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 播放/暂停按钮
              Expanded(
                child: Center(
                  child: IconButton(
                    iconSize: 64,
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    onPressed: () {
                      if (value.isPlaying) {
                        widget.controller.pause();
                      } else {
                        widget.controller.play();
                      }
                      _startHideTimer();
                    },
                  ),
                ),
              ),
              // 进度条
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      _formatDuration(value.position),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                        ),
                        child: Slider(
                          value: value.duration.inMilliseconds > 0
                              ? value.position.inMilliseconds /
                                    value.duration.inMilliseconds
                              : 0,
                          onChanged: (v) {
                            final position = Duration(
                              milliseconds: (v * value.duration.inMilliseconds)
                                  .toInt(),
                            );
                            widget.controller.seekTo(position);
                            _startHideTimer();
                          },
                          activeColor: Colors.white,
                          inactiveColor: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(value.duration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


bool _isBilibili(String url) {
  final lower = url.toLowerCase();
  return lower.contains('bilibili.com') || lower.contains('b23.tv');
}

bool _isDirectVideo(String url) {
  final lower = url.toLowerCase().split('?').first;
  return lower.endsWith('.mp4') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.ogg') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.m4s'); // B站直链格式
}

/// 从 B站 URL 提取 BV 号
String? _extractBvid(String url) {
  return BilibiliService.extractBvid(url);
}

/// 构建 B站 embed URL（autoplay + 高画质 + 无弹幕）
String _buildBilibiliEmbedUrl(String url) {
  final bvid = _extractBvid(url);
  if (bvid != null) {
    final pMatch = RegExp(r'[?&]p=(\d+)').firstMatch(url);
    final page = pMatch?.group(1) ?? '1';
    return 'https://player.bilibili.com/player.html'
        '?bvid=$bvid&page=$page&autoplay=1&high_quality=1&danmaku=0';
  }

  // AV 号
  final avMatch = RegExp(r'av(\d+)', caseSensitive: false).firstMatch(url);
  if (avMatch != null) {
    final aid = avMatch.group(1);
    return 'https://player.bilibili.com/player.html'
        '?aid=$aid&autoplay=1&high_quality=1&danmaku=0';
  }

  // 无法解析，直接返回原URL
  return url;
}
