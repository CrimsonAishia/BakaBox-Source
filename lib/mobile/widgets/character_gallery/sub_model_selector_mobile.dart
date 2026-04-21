import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/models/character_models.dart';
import '../../../core/widgets/disk_cached_image.dart';
import '../../../desktop/widgets/character_gallery/character_gallery_theme.dart';

/// 移动端子模型选择器 - 现代花札风格设计
/// 
/// 显示水平滚动的子模型卡片列表，支持选中状态和切换。
/// 
/// **Validates: Requirements 4.5, 4.6**
class SubModelSelectorMobile extends StatelessWidget {
  /// 子模型列表
  final List<CharacterSubModel> subModels;
  
  /// 当前选中的子模型ID
  final int? selectedId;
  
  /// 选中子模型时的回调
  final ValueChanged<int> onSelected;

  const SubModelSelectorMobile({
    super.key,
    required this.subModels,
    this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final vermillionColor = CharacterGalleryTheme.getVermillion(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? theme.colorScheme.surfaceContainer
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: vermillionColor.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.style_rounded,
                  size: 18,
                  color: vermillionColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '皮肤选择',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: inkColor,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: vermillionColor.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${subModels.length} 款',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: vermillionColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 子模型卡片列表
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: subModels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final subModel = subModels[index];
                final isSelected = subModel.id == selectedId;
                return _SubModelCard(
                  subModel: subModel,
                  isSelected: isSelected,
                  onTap: () => onSelected(subModel.id),
                ).animate(delay: (40 * index).ms)
                    .fadeIn(duration: 250.ms)
                    .slideX(begin: 0.1, end: 0, duration: 250.ms, curve: Curves.easeOutCubic);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 子模型卡片组件
class _SubModelCard extends StatefulWidget {
  final CharacterSubModel subModel;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubModelCard({
    required this.subModel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SubModelCard> createState() => _SubModelCardState();
}

class _SubModelCardState extends State<_SubModelCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final goldColor = CharacterGalleryTheme.getGold(context);
    final vermillionColor = CharacterGalleryTheme.getVermillion(context);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 85,
        transform: _isPressed 
            ? Matrix4.diagonal3Values(0.95, 0.95, 1.0)
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: washiColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isSelected 
                ? goldColor 
                : (_isPressed ? vermillionColor : scrollBrown.withValues(alpha: 0.4)),
            width: widget.isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isSelected 
                  ? goldColor.withValues(alpha: isDark ? 0.3 : 0.25) 
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
              blurRadius: widget.isSelected ? 12 : 6,
              offset: Offset(0, widget.isSelected ? 4 : 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部装饰条
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isSelected 
                      ? [goldColor.withValues(alpha: 0.8), goldColor, goldColor.withValues(alpha: 0.8)]
                      : [vermillionColor.withValues(alpha: 0.8), vermillionColor, vermillionColor.withValues(alpha: 0.8)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
            // 缩略图
            Expanded(
              child: _buildThumbnail(context, washiColor, scrollBrown, goldColor, vermillionColor, isDark),
            ),
            // 名称和获取渠道
            _buildName(context, inkColor, goldColor, isDark),
          ],
        ),
      ),
    );
  }

  /// 构建缩略图
  Widget _buildThumbnail(
    BuildContext context,
    Color washiColor,
    Color scrollBrown,
    Color goldColor,
    Color vermillionColor,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 6, 6, 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.isSelected 
              ? goldColor.withValues(alpha: 0.5) 
              : scrollBrown.withValues(alpha: isDark ? 0.25 : 0.2),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: DiskCachedImage(
          imageUrl: widget.subModel.thumbnailUrl,
          fit: BoxFit.cover,
          placeholder: Container(
            color: washiColor,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: vermillionColor.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          errorWidget: Container(
            color: washiColor,
            child: Icon(
              Icons.image_outlined,
              size: 22,
              color: scrollBrown.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建名称和获取渠道
  Widget _buildName(
    BuildContext context,
    Color inkColor,
    Color goldColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.subModel.name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
              color: widget.isSelected ? goldColor : inkColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          // 获取渠道
          _buildAcquisitionTag(context, inkColor, isDark),
        ],
      ),
    );
  }

  /// 获取渠道标签
  Widget _buildAcquisitionTag(BuildContext context, Color inkColor, bool isDark) {
    final acquisition = widget.subModel.acquisition;
    
    final (text, color, icon) = acquisition == null || acquisition.type == AcquisitionType.unknown
        ? ('未知', inkColor.withValues(alpha: 0.5), Icons.help_outline_rounded)
        : switch (acquisition.type) {
            AcquisitionType.gold => (
              '${acquisition.cost ?? 0} 金',
              CharacterGalleryTheme.getGold(context),
              Icons.monetization_on_outlined,
            ),
            AcquisitionType.points => (
              '${acquisition.cost ?? 0} 点',
              CharacterGalleryTheme.getVermillion(context),
              Icons.stars_rounded,
            ),
            AcquisitionType.custom => (
              acquisition.customSource ?? '特殊',
              CharacterGalleryTheme.getCustomSourceColor(context),
              Icons.auto_awesome_rounded,
            ),
            AcquisitionType.unknown => (
              '未知',
              inkColor.withValues(alpha: 0.5),
              Icons.help_outline_rounded,
            ),
          };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
