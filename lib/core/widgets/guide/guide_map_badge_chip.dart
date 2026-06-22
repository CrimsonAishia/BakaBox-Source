import 'package:flutter/material.dart';

import '../signed_network_image.dart';
import 'guide_tokens.dart';

/// 攻略卡片右下角地图角标
///
/// 黑 50% 半透明胶囊 + `mapBackground` 16 圆形 + `mapLabel`（最长 6 字截断）。
/// 点击不冒泡到父级卡片，通过 [onTap] 回调通知外部（后续由 `DesktopNavigator.openGuides(mapName: ...)` 接入）。
///
/// 用法：
/// ```dart
/// GuideMapBadgeChip(
///   mapBackground: item.mapBackground,
///   mapLabel: item.mapLabel ?? '',
///   onTap: () => DesktopNavigator.openGuides(mapName: item.mapName),
/// )
/// ```
class GuideMapBadgeChip extends StatelessWidget {
  /// 地图背景图 URL（可空，为空时显示默认图标）
  final String? mapBackground;

  /// 地图展示名称（最多显示 6 字）
  final String mapLabel;

  /// 点击回调（不冒泡到父级）
  final VoidCallback? onTap;

  const GuideMapBadgeChip({
    super.key,
    this.mapBackground,
    required this.mapLabel,
    this.onTap,
  });

  /// 截断标签文本，最多显示 6 个字
  String get _truncatedLabel {
    if (mapLabel.length <= 6) return mapLabel;
    return '${mapLabel.substring(0, 6)}…';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: GuideTokens.space8,
          vertical: GuideTokens.space4,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.50),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 地图缩略圆形（始终在黑色胶囊上展示，主题无需自适应）
            ClipOval(
              child: SizedBox(
                width: 16,
                height: 16,
                child: SignedNetworkImage(
                  url: mapBackground,
                  fallback: _buildFallbackCircle(),
                  cacheWidth: 32,
                  cacheHeight: 32,
                ),
              ),
            ),
            const SizedBox(width: GuideTokens.space4),
            // 地图名称
            Text(
              _truncatedLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCircle() {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: GuideTokens.fallbackIcon,
      ),
      child: const Icon(Icons.map_outlined, size: 10, color: Colors.white70),
    );
  }
}
