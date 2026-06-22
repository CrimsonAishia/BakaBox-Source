import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../models/guide_models.dart';
import '../disk_cached_image.dart';
import '../guide/guide_tokens.dart';
import '../../../desktop/widgets/character_gallery/video_embed_dialog.dart';

/// B 站视频自定义 BlockEmbed 类型标识
const String bilibiliEmbedType = 'bilibili';

/// B 站视频自定义 BlockEmbed
///
/// Delta 格式:
/// ```jsonc
/// { "insert": { "bilibili": {
///     "bvid": "BV1xx",
///     "url": "https://www.bilibili.com/video/BV1xx/",
///     "cover": "https://i0.hdslb.com/...",
///     "title": "演示视频",
///     "durationSec": 312
/// } } }
/// ```
class BilibiliBlockEmbed extends CustomBlockEmbed {
  BilibiliBlockEmbed(Map<String, dynamic> data)
    : super(bilibiliEmbedType, jsonEncode(data));

  /// 从 [VideoEmbed] 创建
  factory BilibiliBlockEmbed.fromVideoEmbed(VideoEmbed embed) {
    return BilibiliBlockEmbed({
      'bvid': embed.bvid,
      'url': embed.url,
      'cover': embed.coverUrl ?? '',
      'title': embed.title ?? '',
      'durationSec': embed.durationSec ?? 0,
    });
  }

  /// 解析 embed data 为结构化数据
  static Map<String, dynamic>? parseData(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }
}

/// B 站视频 Quill EmbedBuilder
///
/// 编辑态与只读态统一渲染为封面卡片（缩略图 + 时长 + 播放图标），
/// 点击弹出 `VideoEmbedDialog` 进行播放。
class BilibiliEmbedBuilder extends EmbedBuilder {
  const BilibiliEmbedBuilder();

  @override
  String get key => bilibiliEmbedType;

  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = BilibiliBlockEmbed.parseData(
      embedContext.node.value.data as String,
    );

    if (data == null) {
      return const _BilibiliEmbedFallback();
    }

    final bvid = data['bvid'] as String? ?? '';
    final url = data['url'] as String? ?? '';
    final cover = data['cover'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final durationSec = data['durationSec'] as int? ?? 0;

    return _BilibiliEmbedCard(
      bvid: bvid,
      url: url,
      cover: cover,
      title: title,
      durationSec: durationSec,
    );
  }
}

/// B 站视频封面卡片
class _BilibiliEmbedCard extends StatefulWidget {
  final String bvid;
  final String url;
  final String cover;
  final String title;
  final int durationSec;

  const _BilibiliEmbedCard({
    required this.bvid,
    required this.url,
    required this.cover,
    required this.title,
    required this.durationSec,
  });

  @override
  State<_BilibiliEmbedCard> createState() => _BilibiliEmbedCardState();
}

class _BilibiliEmbedCardState extends State<_BilibiliEmbedCard> {
  bool _isHovering = false;

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _openVideoDialog() {
    showDialog(
      context: context,
      builder: (_) => VideoEmbedDialog(
        videoUrl: widget.url,
        title: widget.title.isNotEmpty ? widget.title : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: _openVideoDialog,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: _isHovering
                ? (Matrix4.identity()..scaleByDouble(1.01, 1.01, 1.0, 1.0))
                : Matrix4.identity(),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _isHovering ? 0.2 : 0.1,
                  ),
                  blurRadius: _isHovering ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 封面图
                    _buildCover(isDark),
                    // 渐变叠加层
                    _buildGradientOverlay(),
                    // 播放图标
                    _buildPlayIcon(),
                    // 时长徽标
                    if (widget.durationSec > 0) _buildDurationBadge(),
                    // 标题（底部）
                    if (widget.title.isNotEmpty) _buildTitle(),
                    // B站标识
                    _buildBilibiliLogo(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(bool isDark) {
    if (widget.cover.isEmpty) {
      return Container(
        color: isDark
            ? GuideTokens.fallbackBgDark
            : GuideTokens.fallbackBgLight,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_outline,
                size: 48,
                color: GuideTokens.bilibiliPink.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                widget.bvid,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? GuideTokens.textTertiaryDark
                      : GuideTokens.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DiskCachedImage(
      imageUrl: widget.cover,
      fit: BoxFit.cover,
      placeholder: Container(
        color: GuideTokens.bilibiliPlaceholderDark,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: GuideTokens.bilibiliPink,
            ),
          ),
        ),
      ),
      errorWidget: Container(
        color: GuideTokens.bilibiliPlaceholderDark,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_outline,
                size: 48,
                color: GuideTokens.bilibiliPink.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                widget.bvid,
                style: TextStyle(
                  fontSize: 12,
                  color: GuideTokens.textTertiaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
    );
  }

  Widget _buildPlayIcon() {
    return Center(
      child: AnimatedOpacity(
        opacity: _isHovering ? 1.0 : 0.8,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: GuideTokens.bilibiliPink.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: GuideTokens.bilibiliPink.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildDurationBadge() {
    return Positioned(
      right: 8,
      top: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _formatDuration(widget.durationSec),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Text(
        widget.title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildBilibiliLogo() {
    return Positioned(
      left: 8,
      top: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: GuideTokens.bilibiliPink.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_filled, color: Colors.white, size: 12),
            SizedBox(width: 4),
            Text(
              'bilibili',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 解析失败时的兜底 Widget
class _BilibiliEmbedFallback extends StatelessWidget {
  const _BilibiliEmbedFallback();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? GuideTokens.fallbackBgDark
            : GuideTokens.bilibiliFallbackLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : GuideTokens.bilibiliInputBorderLight,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.videocam_off_outlined,
            size: 20,
            color: isDark
                ? GuideTokens.textTertiaryDark
                : GuideTokens.textSecondaryLight,
          ),
          const SizedBox(width: 8),
          Text(
            '视频加载失败',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? GuideTokens.textTertiaryDark
                  : GuideTokens.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
