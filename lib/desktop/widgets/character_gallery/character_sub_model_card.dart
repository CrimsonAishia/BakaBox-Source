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
  final List<ItemTagData>? tags;
  final String? groupName;
  final String? othercheckKeyName;
  final int? othercheckPoint;
  final int? viplevel;
  final bool isSelected;
  final bool isDefault;
  final VoidCallback onTap;

  const SubModelCard({
    super.key,
    required this.name,
    required this.thumbnailUrl,
    this.acquisition,
    this.tags,
    this.groupName,
    this.othercheckKeyName,
    this.othercheckPoint,
    this.viplevel,
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
      tags: subModel.tags,
      groupName: subModel.groupName,
      othercheckKeyName: subModel.othercheckKeyName,
      othercheckPoint: subModel.othercheckPoint,
      viplevel: subModel.viplevel,
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
      tags: model.tags,
      groupName: model.groupName,
      othercheckKeyName: model.othercheckKeyName,
      othercheckPoint: model.othercheckPoint,
      viplevel: model.viplevel,
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
      tags: model.tags,
      groupName: model.groupName,
      othercheckKeyName: model.othercheckKeyName,
      othercheckPoint: model.othercheckPoint,
      viplevel: model.viplevel,
      isSelected: false,
      isDefault: false,
      onTap: onTap,
    );
  }

  /// 从 MenuSkinModel 创建
  factory SubModelCard.fromMenuSkinModel({
    Key? key,
    required MenuSkinModel model,
    required VoidCallback onTap,
  }) {
    return SubModelCard(
      key: key,
      name: model.name,
      thumbnailUrl: model.thumbnailUrl ?? '',
      acquisition: model.acquisition,
      tags: model.tags,
      groupName: model.groupName,
      othercheckKeyName: model.othercheckKeyName,
      othercheckPoint: model.othercheckPoint,
      viplevel: model.viplevel,
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
                    // 先显示 othercheck，然后 groupName，然后捐助者，最后获取方式
                    if (widget.othercheckKeyName != null &&
                        widget.othercheckKeyName!.isNotEmpty)
                      _SubModelOtherCheckTag(
                        keyName: widget.othercheckKeyName!,
                        point: widget.othercheckPoint ?? 0,
                      )
                    else if (widget.groupName != null &&
                        widget.groupName!.isNotEmpty)
                      _SubModelGroupTag(groupName: widget.groupName!)
                    else if (widget.viplevel != null && widget.viplevel! > 0)
                      _SubModelViplevelTag(viplevel: widget.viplevel!)
                    else
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

/// 子模型分组标签
class _SubModelGroupTag extends StatelessWidget {
  final String groupName;

  const _SubModelGroupTag({required this.groupName});

  @override
  Widget build(BuildContext context) {
    final color = CharacterGalleryTheme.getSpecialColor(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.military_tech_outlined, size: 9, color: color),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            groupName,
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

/// 子模型获取途径标签（紧凑版）
class _SubModelAcquisitionTag extends StatelessWidget {
  final AcquisitionInfo? acquisition;

  const _SubModelAcquisitionTag({this.acquisition});

  @override
  Widget build(BuildContext context) {
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    final (
      IconData? icon,
      String text,
      Color color,
    ) = acquisition == null || acquisition!.type == AcquisitionType.unknown
        ? (null, '未知', inkColor.withValues(alpha: 0.5))
        : switch (acquisition!.type) {
            AcquisitionType.gold =>
              (acquisition!.cost ?? 0) == 0
                  ? (
                      Icons.money_off,
                      '免费获取',
                      const Color(0xFF10B981), // Emerald 500
                    )
                  : (
                      Icons.monetization_on,
                      '${acquisition!.cost ?? 0} 金',
                      const Color(0xFFF59E0B), // AppColors.amber500
                    ),
            AcquisitionType.points =>
              (acquisition!.cost ?? 0) == 0
                  ? (Icons.money_off, '免费获取', const Color(0xFF10B981))
                  : (
                      Icons.bolt,
                      '${acquisition!.cost ?? 0} 点',
                      const Color(0xFF60A5FA),
                    ),
            AcquisitionType.custom => (
              null,
              acquisition!.customSource ?? '特殊',
              CharacterGalleryTheme.getCustomSourceColor(context),
            ),
            AcquisitionType.unknown => (
              null,
              '未知',
              inkColor.withValues(alpha: 0.5),
            ),
          };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 9, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 2),
        ],
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

/// 子模型捐助者标签
class _SubModelViplevelTag extends StatelessWidget {
  final int viplevel;

  const _SubModelViplevelTag({required this.viplevel});

  @override
  Widget build(BuildContext context) {
    final color = CharacterGalleryTheme.sakuraPink;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.volunteer_activism, size: 9, color: color),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            '捐助者 Lv.$viplevel',
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

/// 子模型额外条件标签
class _SubModelOtherCheckTag extends StatelessWidget {
  final String keyName;
  final int point;

  const _SubModelOtherCheckTag({required this.keyName, required this.point});

  @override
  Widget build(BuildContext context) {
    final color = CharacterGalleryTheme.getCustomSourceColor(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.card_giftcard_rounded, size: 9, color: color),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            '$keyName: $point',
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
