import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_windows/webview_windows.dart' as windows_webview;
import 'package:url_launcher/url_launcher.dart';

/// 视频内嵌播放弹窗
///
/// 支持：
/// - Bilibili：先显示封面+居中播放按钮，点击后 autoplay
/// - 视频直链（mp4/webm）：HTML5 video 标签播放
class VideoEmbedDialog extends StatefulWidget {
  final String videoUrl;
  final String? title;

  const VideoEmbedDialog({
    super.key,
    required this.videoUrl,
    this.title,
  });

  /// 判断 URL 是否支持内嵌播放
  static bool canEmbed(String url) {
    return _isBilibili(url) || _isDirectVideo(url);
  }

  @override
  State<VideoEmbedDialog> createState() => _VideoEmbedDialogState();
}

class _VideoEmbedDialogState extends State<VideoEmbedDialog> {
  windows_webview.WebviewController? _controller;
  bool _isWebViewReady = false;
  bool _isPlaying = false;
  bool _hasError = false;

  // B站封面信息
  String? _coverUrl;
  String? _videoTitle;
  bool _isFetchingCover = false;

  @override
  void initState() {
    super.initState();
    if (_isBilibili(widget.videoUrl)) {
      _fetchBilibiliCover();
    } else {
      // 直链直接开始播放
      _startPlayback();
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
      final bvid = _extractBvid(widget.videoUrl);
      if (bvid != null) {
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
    } catch (_) {
      // 获取封面失败不影响播放
    }

    if (mounted) setState(() => _isFetchingCover = false);
  }

  /// 初始化 WebView 并开始播放
  Future<void> _startPlayback() async {
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

      final url = widget.videoUrl;
      if (_isBilibili(url)) {
        await controller.loadUrl(_buildBilibiliEmbedUrl(url));
      } else if (_isDirectVideo(url)) {
        await controller.loadStringContent(_buildDirectVideoHtml(url));
      }

      if (mounted) {
        setState(() {
          _controller = controller;
          _isWebViewReady = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBili = _isBilibili(widget.videoUrl);

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
    final displayTitle = widget.title
        ?? _videoTitle
        ?? (isBili ? 'Bilibili 视频预览' : '视频预览');

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
              '无法加载视频播放器',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
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

    // 正在播放 — 显示 WebView
    if (_isPlaying) {
      if (!_isWebViewReady || _controller == null) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(height: 12),
              Text(
                '加载播放器中...',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        );
      }

      return ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        child: windows_webview.Webview(_controller!),
      );
    }

    // 未播放 — 显示封面 + 播放按钮（B站）
    return _buildCoverWithPlayButton(isDark);
  }

  Widget _buildCoverWithPlayButton(bool isDark) {
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
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
            )
          else
            Container(
              color: Colors.black,
              child: _isFetchingCover
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white30,
                      ),
                    )
                  : null,
            ),

          // 半透明遮罩
          Container(
            color: Colors.black.withValues(alpha: 0.3),
          ),

          // 居中播放按钮
          Center(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _startPlayback,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.8),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
              ),
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
                    Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 4),
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
      lower.endsWith('.mov');
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

  // b23.tv 短链无法解析，直接加载
  return url;
}

/// 构建 HTML5 video 播放页面
String _buildDirectVideoHtml(String url) {
  return '''
<!DOCTYPE html>
<html>
<head>
<style>
  * { margin: 0; padding: 0; }
  body { background: #000; display: flex; align-items: center; justify-content: center; height: 100vh; }
  video { max-width: 100%; max-height: 100%; }
</style>
</head>
<body>
<video controls autoplay>
  <source src="$url">
</video>
</body>
</html>
''';
}
