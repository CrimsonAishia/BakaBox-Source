import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart' as windows_webview;
import '../../../core/models/character_models.dart';

/// 视频内嵌播放弹窗
///
/// 支持：
/// - Bilibili 直链（bilibili_parsed）：使用 media_kit 播放，设置 Referer 头
/// - Bilibili 原始链接：使用 WebView iframe 嵌入播放器
/// - 视频直链（mp4/webm）：使用 media_kit 播放
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
  // media_kit 播放器（用于直链）
  Player? _player;
  VideoController? _videoController;
  
  // WebView 控制器（用于B站原始链接）
  windows_webview.WebviewController? _webviewController;
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
      // B站直链：使用原始地址获取封面，然后用 media_kit 播放
      _fetchBilibiliCoverFromOrigin().then((_) => _startMediaKitPlayback());
    } else if (_isBilibili(widget.videoUrl)) {
      // B站原始链接：获取封面，然后用 WebView 嵌入播放
      _fetchBilibiliCover().then((_) => _startWebViewPlayback());
    } else {
      // 普通直链：用 media_kit 播放
      _startMediaKitPlayback();
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    _webviewController?.dispose();
    super.dispose();
  }

  /// 获取B站视频封面和标题
  Future<void> _fetchBilibiliCover() async {
    setState(() => _isFetchingCover = true);

    try {
      final bvid = _extractBvid(widget.videoUrl);
      if (bvid != null) {
        await _fetchCoverByBvid(bvid);
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
        final bvid = _extractBvid(originUrl);
        if (bvid != null) {
          await _fetchCoverByBvid(bvid);
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isFetchingCover = false);
  }

  /// 通过BV号获取封面
  Future<void> _fetchCoverByBvid(String bvid) async {
    final response = await http.get(
      Uri.parse('https://api.bilibili.com/x/web-interface/view?bvid=$bvid'),
    ).timeout(const Duration(seconds: 5));

    if (mounted && response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['code'] == 0) {
        setState(() {
          _coverUrl = data['data']['pic'];
          _videoTitle = data['data']['title'];
        });
      }
    }
  }

  /// 使用 WebView 播放B站原始链接（iframe 嵌入）
  Future<void> _startWebViewPlayback() async {
    if (!mounted) return;
    setState(() => _isPlaying = true);

    try {
      final controller = windows_webview.WebviewController();
      await controller.initialize();
      await controller.setBackgroundColor(Colors.black);
      await controller.setPopupWindowPolicy(
        windows_webview.WebviewPopupWindowPolicy.deny,
      );

      if (!mounted) {
        controller.dispose();
        return;
      }

      // 先设置控制器，让 WebView 开始渲染
      _webviewController = controller;

      // 构建B站嵌入播放器URL
      final embedUrl = _buildBilibiliEmbedUrl(widget.videoUrl);
      await controller.loadUrl(embedUrl);

      // 延迟一小段时间确保 WebView 开始加载
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        setState(() {
          _isWebViewReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '初始化播放器失败：$e';
        });
      }
    }
  }

  /// 使用 media_kit 播放直链视频
  Future<void> _startMediaKitPlayback() async {
    setState(() => _isPlaying = true);

    try {
      _player = Player();
      _videoController = VideoController(_player!);

      final url = widget.videoUrl;
      
      // B站直链需要设置 Referer 头
      if (widget.videoUrlSource == VideoUrlSource.bilibiliParsed) {
        await _player!.open(
          Media(
            url,
            httpHeaders: {
              'Referer': 'https://www.bilibili.com/',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          ),
        );
      } else {
        await _player!.open(Media(url));
      }

      // 监听错误
      _player!.stream.error.listen((error) {
        if (mounted && error.isNotEmpty) {
          setState(() {
            _hasError = true;
            _errorMessage = '播放失败：$error';
          });
        }
      });

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBili = _isBilibili(widget.videoUrl) ||
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
    final displayTitle = widget.title ??
        _videoTitle ??
        (isBili ? 'Bilibili 视频预览' : '视频预览');

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
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
      if (_isPlaying && _isWebViewReady && _webviewController != null) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          child: windows_webview.Webview(_webviewController!),
        );
      }
    } else {
      // media_kit 播放（直链）
      if (_isPlaying && _videoController != null) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          child: Video(
            controller: _videoController!,
            controls: AdaptiveVideoControls,
          ),
        );
      }
    }

    // 加载中 — 显示封面（如果有）+ loading
    return _buildLoadingWithCover(isDark);
  }

  Widget _buildLoadingWithCover(bool isDark) {
    final isBili = _isBilibili(widget.videoUrl) ||
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
                        blurRadius: 4),
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

// ============ URL 解析工具 ============

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
  final match = RegExp(r'BV[\w]+').firstMatch(url);
  return match?.group(0);
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
