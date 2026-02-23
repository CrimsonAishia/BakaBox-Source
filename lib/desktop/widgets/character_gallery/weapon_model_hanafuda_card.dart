import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../core/models/character_models.dart';
import '../../../core/widgets/disk_cached_image.dart';
import 'character_gallery_theme.dart';
import 'character_hanafuda_card.dart';

/// 刀枪模花札风格卡片（和角色卡片一模一样的样式）
class WeaponModelHanafudaCard extends StatefulWidget {
  final String name;
  final String? thumbnailUrl;
  final String? characterName;
  final AcquisitionInfo? acquisition;
  final bool isKnife;
  final bool isSelected;
  final VoidCallback onTap;

  const WeaponModelHanafudaCard({
    super.key,
    required this.name,
    this.thumbnailUrl,
    this.characterName,
    this.acquisition,
    required this.isKnife,
    required this.isSelected,
    required this.onTap,
  });

  /// 从 KnifeModel 创建
  factory WeaponModelHanafudaCard.fromKnifeModel({
    Key? key,
    required KnifeModel model,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return WeaponModelHanafudaCard(
      key: key,
      name: model.name,
      thumbnailUrl: model.thumbnailUrl,
      characterName: model.characterName,
      acquisition: model.acquisition,
      isKnife: true,
      isSelected: isSelected,
      onTap: onTap,
    );
  }

  /// 从 GunModel 创建
  factory WeaponModelHanafudaCard.fromGunModel({
    Key? key,
    required GunModel model,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return WeaponModelHanafudaCard(
      key: key,
      name: model.name,
      thumbnailUrl: model.thumbnailUrl,
      characterName: model.characterName,
      acquisition: model.acquisition,
      isKnife: false,
      isSelected: isSelected,
      onTap: onTap,
    );
  }

  @override
  State<WeaponModelHanafudaCard> createState() => _WeaponModelHanafudaCardState();
}

class _WeaponModelHanafudaCardState extends State<WeaponModelHanafudaCard> {
  bool _isHovered = false;

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
                    ? CharacterGalleryTheme.getGold(context).withValues(alpha: 0.4)
                    : (_isHovered
                          ? CharacterGalleryTheme.getVermillion(context).withValues(alpha: 0.3)
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ),
              // 图片
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: CharacterGalleryTheme.getGold(context).withValues(alpha: _isHovered ? 0.8 : 0.5),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty
                        ? DiskCachedImage(
                            imageUrl: widget.thumbnailUrl!,
                            fit: BoxFit.cover,
                            placeholder: _buildPlaceholder(washiColor, scrollBrown),
                            errorWidget: _buildErrorWidget(washiColor, scrollBrown),
                          )
                        : _buildErrorWidget(washiColor, scrollBrown),
                  ),
                ),
              ),
              // 底部信息
              Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 名称
                    Text(
                      widget.name,
                      style: TextStyle(
                        color: inkColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // 角色名称（如果有）
                    if (widget.characterName != null && widget.characterName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.characterName!,
                        style: TextStyle(
                          color: inkColor.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    // 分隔线
                    Container(
                      height: 1,
                      color: scrollBrown.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 4),
                    // 获取方式
                    AcquisitionTag(acquisition: widget.acquisition),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(Color washiColor, Color scrollBrown) {
    return Container(
      color: washiColor,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: CharacterGalleryTheme.getVermillion(context),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(Color washiColor, Color scrollBrown) {
    return Container(
      color: washiColor,
      child: Icon(
        widget.isKnife ? MdiIcons.knife : MdiIcons.pistol,
        size: 40,
        color: scrollBrown.withValues(alpha: 0.3),
      ),
    );
  }
}
