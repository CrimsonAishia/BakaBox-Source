import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/models/server_models.dart';
import '../../../core/utils/map_utils.dart';
import '../../../core/utils/player_count_utils.dart';
import '../../../core/utils/image_cache_manager.dart';

/// 挤服窗口中的服务器信息卡片
class QueueServerCard extends StatelessWidget {
  final ServerInfo? serverInfo;
  final MapData? mapInfo;
  final String serverAddress;
  final bool isLoading;
  final String? error;

  const QueueServerCard({
    super.key,
    this.serverInfo,
    this.mapInfo,
    required this.serverAddress,
    this.isLoading = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 地图背景
          _buildMapBackground(),
          // 渐变遮罩
          _buildGradientOverlay(),
          // 服务器信息
          _buildServerInfo(context, isDark),
          // 加载状态
          if (isLoading) _buildLoadingOverlay(),
          // 错误状态
          if (error != null) _buildErrorOverlay(context),
        ],
      ),
    );
  }

  Widget _buildMapBackground() {
    final mapUrl = MapUtils.getMapImageUrl(
      serverInfo?.map,
      mapUrl: mapInfo?.mapUrl,
    );

    if (mapUrl.startsWith('http://') || mapUrl.startsWith('https://')) {
      final cacheKey = AppImageCacheManager.extractCacheKey(mapUrl);
      return CachedNetworkImage(
        imageUrl: mapUrl,
        cacheKey: cacheKey,
        cacheManager: AppImageCacheManager.instance,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: const Color(0xFF1E293B),
        ),
        errorWidget: (context, url, error) => _buildDefaultBackground(),
      );
    }

    return Image.asset(
      mapUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildDefaultBackground(),
    );
  }

  Widget _buildDefaultBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
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
            Colors.black.withValues(alpha: 0.4),
            Colors.black.withValues(alpha: 0.85),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
    );
  }

  Widget _buildServerInfo(BuildContext context, bool isDark) {
    final hostName = serverInfo?.hostName ?? '加载中...';
    final mapName = serverInfo?.map ?? '未知地图';
    final players = serverInfo?.players ?? 0;
    final maxPlayers = serverInfo?.maxPlayers ?? 0;
    final playerColor = PlayerCountUtils.getPlayerCountColor(players, maxPlayers);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 玩家数量标签
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: playerColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: playerColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(MdiIcons.accountGroup, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '$players/$maxPlayers',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          // 服务器名称
          Text(
            hostName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // 地图和地址
          Row(
            children: [
              _buildInfoChip(
                icon: MdiIcons.map,
                text: MapUtils.formatMapName(mapName),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoChip(
                  icon: MdiIcons.ip,
                  text: serverAddress,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MdiIcons.alertCircle,
              color: Colors.red.shade300,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              error!,
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
