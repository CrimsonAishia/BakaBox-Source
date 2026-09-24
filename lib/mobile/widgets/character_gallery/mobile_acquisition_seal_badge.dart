import 'package:flutter/material.dart';
import '../../../core/core.dart';
import '../../../desktop/widgets/character_gallery/character_gallery_theme.dart';

/// 获取途径徽章
class MobileAcquisitionSealBadge extends StatelessWidget {
  final AcquisitionInfo acquisition;

  const MobileAcquisitionSealBadge({super.key, required this.acquisition});

  @override
  Widget build(BuildContext context) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    final (
      IconData? icon,
      String label,
      String subLabel,
      Color color,
    ) = switch (acquisition.type) {
      AcquisitionType.gold =>
        (acquisition.cost ?? 0) == 0
            ? (Icons.money_off, '免费', '获取', const Color(0xFF10B981))
            : (
                Icons.monetization_on,
                '金',
                '${acquisition.cost ?? 0}',
                CharacterGalleryTheme.getGold(context),
              ),
      AcquisitionType.points =>
        (acquisition.cost ?? 0) == 0
            ? (Icons.money_off, '免费', '获取', const Color(0xFF10B981))
            : (
                Icons.bolt,
                '点',
                '${acquisition.cost ?? 0}',
                const Color(0xFF60A5FA),
              ),
      AcquisitionType.custom => (
        null,
        '特',
        acquisition.customSource ?? '活动',
        CharacterGalleryTheme.getCustomSourceColor(context),
      ),
      _ => (null, '？', '未知', scrollBrown),
    };

    return Container(
      constraints: const BoxConstraints(minWidth: 44, maxWidth: 74),
      height: 44,
      decoration: BoxDecoration(
        color: washiColor,
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 22,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  subLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
