import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 右键菜单项数据
class ContextMenuItem {
  final String id;
  final String label;
  final bool enabled;

  const ContextMenuItem({
    required this.id,
    required this.label,
    this.enabled = true,
  });
}

/// 大厅右键菜单组件（Flame 渲染）
///
/// 在角色模型上右键时显示，包含"调查"和"关注/取消关注"选项。
/// 使用 Flame 渲染以保持与游戏场景一致的视觉风格。
class LobbyContextMenuComponent extends PositionComponent {
  LobbyContextMenuComponent({
    required List<ContextMenuItem> items,
    required Vector2 worldPosition,
    required void Function(String itemId) onItemSelected,
    required VoidCallback onDismiss,
  })  : _items = items,
        _onItemSelected = onItemSelected,
        _onDismiss = onDismiss,
        super(
          position: worldPosition,
          anchor: Anchor.topLeft,
          priority: 1000, // 最高层级，确保菜单在所有组件之上
        );

  final List<ContextMenuItem> _items;
  final void Function(String itemId) _onItemSelected;
  final VoidCallback _onDismiss;

  // 菜单样式常量
  static const double _itemHeight = 32.0;
  static const double _itemPadding = 6.0;
  static const double _borderRadius = 8.0;
  static const double _menuWidth = 120.0;
  static const double _shadowBlur = 12.0;

  // 动画
  double _opacity = 0.0;
  double _scaleValue = 0.85;
  static const double _animSpeed = 8.0;

  // 悬停状态
  int _hoveredIndex = -1;

  // TextPainter 缓存
  final List<TextPainter> _textPainters = [];
  bool _paintersBuilt = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 计算菜单尺寸
    final menuHeight =
        _items.length * _itemHeight + (_items.length + 1) * _itemPadding;
    size = Vector2(_menuWidth, menuHeight);

    // 构建 TextPainter
    _buildTextPainters();
  }

  void _buildTextPainters() {
    for (final item in _items) {
      final painter = TextPainter(
        text: TextSpan(
          text: item.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: item.enabled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _textPainters.add(painter);
    }
    _paintersBuilt = true;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 入场动画
    if (_opacity < 1.0) {
      _opacity = (_opacity + _animSpeed * dt).clamp(0.0, 1.0);
    }
    if (_scaleValue < 1.0) {
      _scaleValue = (_scaleValue + _animSpeed * dt).clamp(0.0, 1.0);
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    // 扩大点击区域，包含菜单本身
    return point.x >= 0 &&
        point.x <= size.x &&
        point.y >= 0 &&
        point.y <= size.y;
  }

  /// 处理鼠标悬停（由 LobbyGame 调用）
  void handleHoverAt(Vector2 localPoint) {
    final newIndex = _getItemIndexAt(localPoint);
    if (newIndex != _hoveredIndex) {
      _hoveredIndex = newIndex;
    }
  }

  /// 处理点击（由 LobbyGame 调用）
  void handleTapAt(Vector2 localPoint) {
    final index = _getItemIndexAt(localPoint);
    if (index >= 0 && index < _items.length && _items[index].enabled) {
      _onItemSelected(_items[index].id);
    }
    _onDismiss();
  }

  int _getItemIndexAt(Vector2 localPoint) {
    if (localPoint.x < 0 || localPoint.x > size.x) return -1;
    if (localPoint.y < 0 || localPoint.y > size.y) return -1;

    for (int i = 0; i < _items.length; i++) {
      final itemTop = _itemPadding + i * (_itemHeight + _itemPadding);
      final itemBottom = itemTop + _itemHeight;
      if (localPoint.y >= itemTop && localPoint.y <= itemBottom) {
        return i;
      }
    }
    return -1;
  }

  @override
  void render(Canvas canvas) {
    if (!_paintersBuilt) return;

    // 应用动画变换
    canvas.save();
    if (_scaleValue < 1.0 || _opacity < 1.0) {
      canvas.translate(size.x / 2, 0);
      canvas.scale(_scaleValue, _scaleValue);
      canvas.translate(-size.x / 2, 0);
    }

    // 绘制阴影
    final shadowRect = Rect.fromLTWH(0, 2, size.x, size.y);
    final shadowRRect =
        RRect.fromRectAndRadius(shadowRect, const Radius.circular(_borderRadius));
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4 * _opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _shadowBlur);
    canvas.drawRRect(shadowRRect, shadowPaint);

    // 绘制背景（半透明深色毛玻璃风格）
    final bgRect = Rect.fromLTWH(0, 0, size.x, size.y);
    final bgRRect =
        RRect.fromRectAndRadius(bgRect, const Radius.circular(_borderRadius));
    final bgPaint = Paint()
      ..color = const Color(0xE6141B2D).withValues(alpha: _opacity);
    canvas.drawRRect(bgRRect, bgPaint);

    // 绘制边框
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12 * _opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(bgRRect, borderPaint);

    // 绘制菜单项
    for (int i = 0; i < _items.length; i++) {
      final itemTop = _itemPadding + i * (_itemHeight + _itemPadding);
      final itemRect = Rect.fromLTWH(
        _itemPadding,
        itemTop,
        size.x - _itemPadding * 2,
        _itemHeight,
      );

      // 悬停高亮
      if (i == _hoveredIndex && _items[i].enabled) {
        final hoverRRect = RRect.fromRectAndRadius(
          itemRect,
          const Radius.circular(6),
        );
        final hoverPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.1 * _opacity);
        canvas.drawRRect(hoverRRect, hoverPaint);
      }

      // 绘制文字（居中）
      if (i < _textPainters.length) {
        final painter = _textPainters[i];
        final textX = itemRect.left + (itemRect.width - painter.width) / 2;
        final textY = itemRect.top + (itemRect.height - painter.height) / 2;
        painter.paint(
          canvas,
          Offset(textX, textY),
        );
      }
    }

    canvas.restore();
  }

  @override
  void onRemove() {
    for (final painter in _textPainters) {
      painter.dispose();
    }
    _textPainters.clear();
    super.onRemove();
  }
}
