import 'package:flutter/material.dart';

/// 默认地图背景图片路径
const String _kDefaultMapBackground = 'assets/images/default-map-bg.jpg';

class WebMapBackground extends StatelessWidget {
  final String? imageUrl;
  final String? mapName;
  final BoxFit fit;

  const WebMapBackground({
    super.key,
    this.imageUrl,
    this.mapName,
    this.fit = BoxFit.cover,
  });

  factory WebMapBackground.fromMap({
    Key? key,
    String? mapName,
    String? mapUrl,
    BoxFit fit = BoxFit.cover,
  }) {
    return WebMapBackground(
      key: key,
      imageUrl: mapUrl,
      mapName: mapName,
      fit: fit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl?.trim();

    // 有网络 URL 时，直接加载网络图片
    if (normalizedUrl != null &&
        normalizedUrl.isNotEmpty &&
        (normalizedUrl.startsWith('http://') ||
            normalizedUrl.startsWith('https://'))) {
      return Image.network(
        normalizedUrl,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) =>
            _buildDefaultAssetBackground(),
      );
    }

    // 有 assets 路径时直接使用
    if (normalizedUrl != null &&
        normalizedUrl.isNotEmpty &&
        normalizedUrl.startsWith('assets/')) {
      return Image.asset(
        normalizedUrl,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) =>
            _FallbackBackground(mapName: mapName),
      );
    }

    // 没有 URL 或 URL 为空，显示默认资源背景
    return _buildDefaultAssetBackground();
  }

  /// 加载默认资源背景图
  Widget _buildDefaultAssetBackground() {
    return Image.asset(
      _kDefaultMapBackground,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) =>
          _FallbackBackground(mapName: mapName),
    );
  }
}

class _FallbackBackground extends StatelessWidget {
  final String? mapName;

  const _FallbackBackground({this.mapName});

  @override
  Widget build(BuildContext context) {
    final label = (mapName != null && mapName!.isNotEmpty)
        ? mapName!
        : 'Unknown Map';

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF10B981)],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
