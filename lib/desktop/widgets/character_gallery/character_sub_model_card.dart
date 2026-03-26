import 'package:flutter/material.dart';
import '../../../core/models/character_models.dart';
import '../../../core/widgets/disk_cached_image.dart';
import 'character_gallery_theme.dart';

/// 子模型卡片组件（带 hover 效果）
/// 支持 CharacterSubModel、KnifeModel、GunModel 等
class SubModelCard extends StatefulWidget {
  final String name;
  final String thumbnailUrl;
  final AcquisitionInfo? acquisition;
  final bool isSelected;
  final bool isDefault;
  final VoidCallback onTap;

  const SubModelCard({
    super.key,
    required this.name,
    required this.thumbnailUrl,
    this.acquisition,
    this.isSelected = false,
    this.isDefault = false,
    required this.onTap,
  });

  /// 从 CharacterSubModel 创建
  factory SubModelCard.fromSubModel({
    Key? key,
    required CharacterSubModel subModel,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return SubModelCard(
      key: key,
      name: subModel.name,
      thumbnailUrl: subModel.thumbnailUrl,
      acquisition: subModel.acquisition,
      isSelected: isSelected,
      isDefault: subModel.isDefault,
      onTap: onTap,
    );
  }

  /// 从 KnifeModel 创建
  factory SubModelCard.fromKnifeModel({
    Key? key,
    required KnifeModel model,
    required VoidCallback onTap,
  }) {
    return SubModelCard(
      key: key,
      name: model.name,
      thumbnailUrl: model.thumbnailUrl ?? '',
      acquisition: model.acquisition,
      isSelected: false,
      isDefault: false,
      onTap: onTap,
    );
  }

  /// 从 GunModel 创建
  factory SubModelCard.fromGunModel({
    Key? key,
    required GunModel model,
    required VoidCallback onTap,
  }) {
    return SubModelCard(
      key: key,
      name: model.name,
      thumbnailUrl: model.thumbnailUrl ?? '',
      acquisition: model.acquisition,
      isSelected: false,
      isDefault: false,
      onTap: onTap,
    );
  }

  @override
  State<SubModelCard> createState() => _SubModelCardState();
}

class _SubModelCardState extends State<SubModelCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final cardBg = CharacterGalleryTheme.getOverlayColor(context, alpha: 0.5);

    final borderColor = widget.isSelected
        ? CharacterGalleryTheme.gold
        : _isHovered
        ? scrollBrown
        : scrollBrown.withValues(alpha: 0.4);
    final borderWidth = widget.isSelected ? 2.5 : (_isHovered ? 1.5 : 1.0);
    final elevation = widget.isSelected ? 4.0 : (_isHovered ? 2.0 : 0.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 90,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? CharacterGalleryTheme.getGold(context).withValues(alpha: 0.08)
                : _isHovered
                ? washiColor
                : cardBg,
            border: Border.all(color: borderColor, width: borderWidth),
            borderRadius: BorderRadius.circular(8),
            boxShadow: elevation > 0
                ? [
                    BoxShadow(
                      color: widget.isSelected
                          ? CharacterGalleryTheme.getGold(
                              context,
                            ).withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.1),
                      blurRadius: elevation * 2,
                      offset: Offset(0, elevation / 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              // 缩略图
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                      child: widget.thumbnailUrl.isNotEmpty
                          ? DiskCachedImage(
                              imageUrl: widget.thumbnailUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Container(
                              color: scrollBrown.withValues(alpha: 0.1),
                              child: Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  color: scrollBrown.withValues(alpha: 0.3),
                                  size: 24,
                                ),
                              ),
                            ),
                    ),
                    // 选中指示器
                    if (widget.isSelected)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: CharacterGalleryTheme.getGold(context),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    // 默认标签
                    if (widget.isDefault)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scrollBrown.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            '默认',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 名称和获取途径
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? CharacterGalleryTheme.getGold(
                          context,
                        ).withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(7),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.name,
                      style: TextStyle(
                        color: widget.isSelected
                            ? CharacterGalleryTheme.getGold(context)
                            : inkColor,
                        fontSize: 11,
                        fontWeight: widget.isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    _SubModelAcquisitionTag(acquisition: widget.acquisition),
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

/// 子模型获取途径标签（紧凑版）
class _SubModelAcquisitionTag extends StatelessWidget {
  final AcquisitionInfo? acquisition;

  const _SubModelAcquisitionTag({this.acquisition});

  @override
  Widget build(BuildContext context) {
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    final (
      icon,
      text,
      color,
    ) = acquisition == null || acquisition!.type == AcquisitionType.unknown
        ? ('', '未知', inkColor.withValues(alpha: 0.5))
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
              '未知',
              inkColor.withValues(alpha: 0.5),
            ),
          };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 9)),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
