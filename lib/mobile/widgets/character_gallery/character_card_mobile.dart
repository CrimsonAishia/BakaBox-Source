import 'package:flutter/material.dart';

import '../../../core/models/character_models.dart';
import '../../../core/widgets/disk_cached_image.dart';
import '../../../desktop/widgets/character_gallery/character_gallery_theme.dart';

/// 移动端角色卡片组件 - 现代花札风格设计
/// 
/// 采用更精致的视觉效果，包括渐变装饰、柔和阴影和流畅动画
class CharacterCardMobile extends StatefulWidget {
  final CharacterListItem character;
  final bool isSelected;
  final VoidCallback onTap;

  const CharacterCardMobile({
    super.key,
    required this.character,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  State<CharacterCardMobile> createState() => _CharacterCardMobileState();
}

class _CharacterCardMobileState extends State<CharacterCardMobile> 
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

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
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: washiColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected
                  ? goldColor
                  : (_isPressed ? vermillionColor : scrollBrown.withValues(alpha: 0.6)),
              width: widget.isSelected ? 2.5 : 1.5,
            ),
            boxShadow: [
              // 主阴影
              BoxShadow(
                color: widget.isSelected
                    ? goldColor.withValues(alpha: isDark ? 0.3 : 0.25)
                    : (_isPressed 
                        ? vermillionColor.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: isDark ? 0.3 : 0.08)),
                blurRadius: widget.isSelected ? 16 : (_isPressed ? 12 : 8),
                offset: Offset(0, widget.isSelected ? 6 : (_isPressed ? 4 : 3)),
                spreadRadius: widget.isSelected ? 1 : 0,
              ),
              // 内发光效果（选中时）
              if (widget.isSelected)
                BoxShadow(
                  color: goldColor.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // 背景纹理（和纸效果）
                Positioned.fill(
                  child: CustomPaint(
                    painter: _WashiTexturePainter(
                      color: scrollBrown.withValues(alpha: isDark ? 0.03 : 0.02),
                    ),
                  ),
                ),
                // 主内容
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 顶部装饰条（渐变）
                    _buildTopDecoration(context, vermillionColor, goldColor),
                    // 角色图片
                    Expanded(
                      child: _buildCharacterImage(
                        context, 
                        washiColor, 
                        scrollBrown,
                        goldColor,
                        vermillionColor,
                        isDark,
                      ),
                    ),
                    // 底部信息
                    _buildBottomInfo(context, inkColor, scrollBrown, isDark),
                  ],
                ),
                // 选中时的光晕效果
                if (widget.isSelected)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: RadialGradient(
                            center: Alignment.topCenter,
                            radius: 1.5,
                            colors: [
                              goldColor.withValues(alpha: 0.15),
                              goldColor.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 顶部渐变装饰条
  Widget _buildTopDecoration(BuildContext context, Color vermillion, Color gold) {
    return Container(
      height: 5,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isSelected
              ? [gold, gold.withValues(alpha: 0.8), gold]
              : [vermillion.withValues(alpha: 0.9), vermillion, vermillion.withValues(alpha: 0.9)],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: (widget.isSelected ? gold : vermillion).withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  /// 角色缩略图
  Widget _buildCharacterImage(
    BuildContext context,
    Color washiColor,
    Color scrollBrown,
    Color goldColor,
    Color vermillionColor,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isSelected 
              ? goldColor.withValues(alpha: 0.6)
              : scrollBrown.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DiskCachedImage(
              imageUrl: widget.character.thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: Container(
                color: washiColor,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: vermillionColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              errorWidget: Container(
                color: washiColor,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 32,
                      color: scrollBrown.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '暂无图片',
                      style: TextStyle(
                        fontSize: 10,
                        color: scrollBrown.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 底部渐变遮罩
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 30,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 底部信息区域
  Widget _buildBottomInfo(
    BuildContext context,
    Color inkColor,
    Color scrollBrown,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 角色名称
          Text(
            widget.character.name,
            style: TextStyle(
              color: inkColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          // 装饰分隔线
          _buildDecorativeDivider(scrollBrown, isDark),
          const SizedBox(height: 5),
          // 获取渠道标签
          _buildAcquisitionTag(context, inkColor, isDark),
        ],
      ),
    );
  }

  /// 装饰性分隔线
  Widget _buildDecorativeDivider(Color scrollBrown, bool isDark) {
    return SizedBox(
      height: 3,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 20,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scrollBrown.withValues(alpha: 0),
                  scrollBrown.withValues(alpha: isDark ? 0.4 : 0.3),
                ],
              ),
            ),
          ),
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scrollBrown.withValues(alpha: isDark ? 0.5 : 0.4),
            ),
          ),
          Container(
            width: 20,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scrollBrown.withValues(alpha: isDark ? 0.4 : 0.3),
                  scrollBrown.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取渠道标签
  Widget _buildAcquisitionTag(BuildContext context, Color inkColor, bool isDark) {
    final acquisition = widget.character.acquisition;
    
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 和纸纹理绘制器
class _WashiTexturePainter extends CustomPainter {
  final Color color;

  _WashiTexturePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // 绘制细微的纤维纹理
    for (var i = 0; i < size.height; i += 8) {
      final path = Path();
      path.moveTo(0, i.toDouble());
      for (var x = 0.0; x < size.width; x += 4) {
        final y = i + (x.hashCode % 3 - 1);
        path.lineTo(x, y.toDouble());
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
