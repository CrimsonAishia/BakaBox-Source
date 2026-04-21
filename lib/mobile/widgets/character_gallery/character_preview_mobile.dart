import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/models/character_models.dart';
import '../../../core/widgets/disk_cached_image.dart';
import '../../../desktop/widgets/character_gallery/character_gallery_theme.dart';

/// 移动端角色预览图组件
/// 
/// 支持六角度切换（正面、左侧、右侧、背面、手部、腿部）和点击打开全屏图片查看器
/// 采用现代化设计风格，与桌面端保持视觉一致性
class CharacterPreviewMobile extends StatelessWidget {
  final CharacterPreviewImages? preview;
  final int currentPosition;
  final ValueChanged<int> onPositionChanged;
  final VoidCallback onImageTap;

  const CharacterPreviewMobile({
    super.key,
    required this.preview,
    required this.currentPosition,
    required this.onPositionChanged,
    required this.onImageTap,
  });

  /// 获取当前位置对应的图片URL
  String? get _currentImageUrl {
    if (preview == null) return null;
    return switch (currentPosition) {
      0 => preview!.front,
      1 => preview!.left,
      2 => preview!.right,
      3 => preview!.back,
      4 => preview!.hand,
      5 => preview!.leg,
      _ => preview!.front,
    };
  }

  /// 所有位置标签配置（含手部和腿部）
  static const List<(int, String, IconData)> _allPositionLabels = [
    (0, '正面', Icons.person_rounded),
    (1, '左侧', Icons.chevron_left_rounded),
    (2, '右侧', Icons.chevron_right_rounded),
    (3, '背面', Icons.person_outline_rounded),
    (4, '手部', Icons.back_hand_outlined),
    (5, '腿部', Icons.directions_walk_rounded),
  ];

  /// 获取当前预览数据中有效的位置按钮列表
  List<(int, String, IconData)> _getAvailablePositions() {
    final base = _allPositionLabels.sublist(0, 4);
    if (preview == null) return base;
    return [
      ...base,
      if (preview!.hand.isNotEmpty) _allPositionLabels[4],
      if (preview!.leg.isNotEmpty) _allPositionLabels[5],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final goldColor = CharacterGalleryTheme.getGold(context);

    return Column(
      children: [
        _buildPreviewImage(context, washiColor, scrollBrown, goldColor, isDark),
        const SizedBox(height: 14),
        _buildPositionButtons(context, isDark),
      ],
    );
  }


  /// 构建预览图区域
  Widget _buildPreviewImage(
    BuildContext context,
    Color washiColor,
    Color scrollBrown,
    Color goldColor,
    bool isDark,
  ) {
    final imageUrl = _currentImageUrl;
    final hasValidImage = imageUrl != null && imageUrl.isNotEmpty;
    final vermillionColor = CharacterGalleryTheme.getVermillion(context);

    return GestureDetector(
      onTap: hasValidImage ? onImageTap : null,
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          color: washiColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: goldColor.withValues(alpha: isDark ? 0.4 : 0.5),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: goldColor.withValues(alpha: isDark ? 0.15 : 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 背景纹理
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: CustomPaint(
                  painter: _WashiBackgroundPainter(
                    color: scrollBrown.withValues(alpha: isDark ? 0.03 : 0.02),
                  ),
                ),
              ),
            ),
            // 图片内容
            ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: hasValidImage
                  ? DiskCachedImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: _buildLoadingPlaceholder(context, vermillionColor),
                      errorWidget: _buildErrorPlaceholder(washiColor, scrollBrown),
                    )
                  : _buildErrorPlaceholder(washiColor, scrollBrown),
            ),
            // 角落装饰
            ..._buildCornerDecorations(goldColor, isDark),
            // 点击提示图标
            if (hasValidImage)
              Positioned(
                right: 14,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: goldColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    MdiIcons.magnifyPlusOutline,
                    size: 20,
                    color: vermillionColor,
                  ),
                ).animate().fadeIn(delay: 300.ms, duration: 200.ms),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).scale(
      begin: const Offset(0.95, 0.95),
      end: const Offset(1.0, 1.0),
      duration: 350.ms,
      curve: Curves.easeOutCubic,
    );
  }

  /// 构建角落装饰
  List<Widget> _buildCornerDecorations(Color goldColor, bool isDark) {
    final decorColor = goldColor.withValues(alpha: isDark ? 0.3 : 0.4);
    const offset = 8.0;

    return [
      Positioned(
        left: offset,
        top: offset,
        child: _CornerDecoration(color: decorColor, rotation: 0),
      ),
      Positioned(
        right: offset,
        top: offset,
        child: _CornerDecoration(color: decorColor, rotation: 1),
      ),
      Positioned(
        left: offset,
        bottom: offset,
        child: _CornerDecoration(color: decorColor, rotation: 3),
      ),
      Positioned(
        right: offset,
        bottom: offset,
        child: _CornerDecoration(color: decorColor, rotation: 2),
      ),
    ];
  }

  /// 构建加载中占位
  Widget _buildLoadingPlaceholder(BuildContext context, Color vermillionColor) {
    return Container(
      color: CharacterGalleryTheme.getWashiColor(context),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: vermillionColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '加载中...',
              style: TextStyle(
                color: vermillionColor.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建错误/空状态占位
  Widget _buildErrorPlaceholder(Color washiColor, Color scrollBrown) {
    return Container(
      color: washiColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scrollBrown.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                MdiIcons.imageOffOutline,
                size: 48,
                color: scrollBrown.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '暂无预览图',
              style: TextStyle(
                color: scrollBrown.withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建角度切换按钮组
  Widget _buildPositionButtons(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final availablePositions = _getAvailablePositions();

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark 
            ? theme.colorScheme.surfaceContainer
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: availablePositions.map((item) {
          final (position, label, icon) = item;
          return Expanded(
            child: _PositionButton(
              position: position,
              label: label,
              icon: icon,
              isSelected: currentPosition == position,
              onTap: () => onPositionChanged(position),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 150.ms).slideY(begin: 0.1, end: 0);
  }
}


/// 角落装饰组件
class _CornerDecoration extends StatelessWidget {
  final Color color;
  final int rotation;

  const _CornerDecoration({
    required this.color,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation * 1.5708,
      child: SizedBox(
        width: 16,
        height: 16,
        child: CustomPaint(
          painter: _CornerPainter(color: color),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;

  _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.6)
      ..lineTo(0, 0)
      ..lineTo(size.width * 0.6, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 和纸背景绘制器
class _WashiBackgroundPainter extends CustomPainter {
  final Color color;

  _WashiBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < size.height; i += 6) {
      final path = Path();
      path.moveTo(0, i.toDouble());
      for (var x = 0.0; x < size.width; x += 3) {
        final y = i + (x.hashCode % 2 - 0.5);
        path.lineTo(x, y.toDouble());
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 角度切换按钮
class _PositionButton extends StatelessWidget {
  final int position;
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PositionButton({
    required this.position,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? vermillion.withValues(alpha: isDark ? 0.2 : 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? vermillion.withValues(alpha: isDark ? 0.5 : 0.4)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? vermillion : inkColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? vermillion : inkColor.withValues(alpha: 0.7),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 全屏图片查看器
class FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? title;

  const FullscreenImageViewer({
    super.key,
    required this.imageUrl,
    this.title,
  });

  static void show(BuildContext context, String imageUrl, {String? title}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullscreenImageViewer(
            imageUrl: imageUrl,
            title: title,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: DiskCachedImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: const Center(
                    child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
            if (title != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                right: 80,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    title!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
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
