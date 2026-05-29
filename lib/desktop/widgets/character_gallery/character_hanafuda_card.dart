import 'package:flutter/material.dart';
import '../../../core/models/character_models.dart';
import '../../../core/widgets/disk_cached_image.dart';
import 'character_gallery_theme.dart';

/// 花札风格角色卡片（带 hover 效果）
class HanafudaCard extends StatefulWidget {
  final CharacterListItem character;
  final bool isSelected;
  final VoidCallback onTap;

  const HanafudaCard({
    super.key,
    required this.character,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<HanafudaCard> createState() => _HanafudaCardState();
}

class _HanafudaCardState extends State<HanafudaCard> {
  bool _isHovered = false;

  /// 格式化浏览量（超过1000显示为 1.2k 格式）
  String _formatViewCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}w';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.isSelected || _isHovered;
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final shadowColor = CharacterGalleryTheme.getShadowColor(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _isHovered && !widget.isSelected
              ? (Matrix4.identity()..setTranslationRaw(0.0, -4.0, 0.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: washiColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? CharacterGalleryTheme.getGold(context)
                  : (_isHovered
                        ? CharacterGalleryTheme.getVermillion(context)
                        : scrollBrown),
              width: isHighlighted ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? CharacterGalleryTheme.getGold(
                        context,
                      ).withValues(alpha: 0.4)
                    : (_isHovered
                          ? CharacterGalleryTheme.getVermillion(
                              context,
                            ).withValues(alpha: 0.3)
                          : shadowColor),
                blurRadius: isHighlighted ? 12 : 6,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 顶部装饰条（朱红色）
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: CharacterGalleryTheme.getVermillion(context),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ),
              // 角色图片
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: CharacterGalleryTheme.getGold(
                        context,
                      ).withValues(alpha: _isHovered ? 0.8 : 0.5),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DiskCachedImage(
                          imageUrl: widget.character.thumbnailUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                          placeholder: Container(
                            color: washiColor,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: CharacterGalleryTheme.getVermillion(
                                  context,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: Container(
                            color: washiColor,
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: scrollBrown.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        // 浏览量显示（图片右上角）
                        if (widget.character.viewCount > 0)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.visibility,
                                    size: 11,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    _formatViewCount(
                                      widget.character.viewCount,
                                    ),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
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
              ),
              // 底部信息
              Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 角色名
                    Text(
                      widget.character.name,
                      style: TextStyle(
                        color: inkColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // 分隔线
                    Container(
                      height: 1,
                      color: scrollBrown.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 4),
                    // 获取方式
                    AcquisitionTag(acquisition: widget.character.acquisition),
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

/// 获取途径标签
class AcquisitionTag extends StatelessWidget {
  final AcquisitionInfo? acquisition;

  const AcquisitionTag({super.key, this.acquisition});

  @override
  Widget build(BuildContext context) {
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    final (
      icon,
      text,
      color,
    ) = acquisition == null || acquisition!.type == AcquisitionType.unknown
        ? ('', '获取途径未知', inkColor.withValues(alpha: 0.5))
        : switch (acquisition!.type) {
            AcquisitionType.gold => (
              '',
              '${acquisition!.cost ?? 0} 金',
              CharacterGalleryTheme.getGold(context),
            ),
            AcquisitionType.points => (
              '',
              '${acquisition!.cost ?? 0} 点',
              CharacterGalleryTheme.getVermillion(context),
            ),
            AcquisitionType.custom => (
              '',
              acquisition!.customSource ?? '特殊',
              CharacterGalleryTheme.getCustomSourceColor(context),
            ),
            AcquisitionType.unknown => (
              '',
              '获取途径未知',
              inkColor.withValues(alpha: 0.5),
            ),
          };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
