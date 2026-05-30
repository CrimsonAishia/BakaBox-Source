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

/// 大厅玩家交互菜单组件（Flame 渲染）
///
/// 左键靠近玩家时显示，包含"调查"和"关注/取消关注"选项。
/// 半透明毛玻璃风格，轻量不遮挡场景。
class LobbyContextMenuComponent extends PositionComponent {
  LobbyContextMenuComponent({
    required List<ContextMenuItem> items,
    required Vector2 worldPosition,
    required void Function(String itemId) onItemSelected,
    required VoidCallback onDismiss,
  }) : _items = items,
       _onItemSelected = onItemSelected,
       _onDismiss = onDismiss,
       super(position: worldPosition, anchor: Anchor.topLeft, priority: 1000);

  final List<ContextMenuItem> _items;
  final void Function(String itemId) _onItemSelected;
  final VoidCallback _onDismiss;

  // 菜单样式常量
  static const double _itemHeight = 28.0;
  static const double _itemPaddingH = 12.0;
  static const double _itemPaddingV = 4.0;
  static const double _menuPadding = 5.0;
  static const double _borderRadius = 10.0;
  static const double _menuWidth = 110.0;

  // 动画
  double _opacity = 0.0;
  double _scaleValue = 0.9;
  static const double _animSpeed = 10.0;

  // 悬停状态
  int _hoveredIndex = -1;

  /// 当前是否悬停在某个菜单项上（供外部切换鼠标光标）
  bool get isHoveringItem => _hoveredIndex >= 0;

  // TextPainter 缓存
  final List<TextPainter> _textPainters = [];
  bool _paintersBuilt = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final menuHeight =
        _items.length * _itemHeight +
        (_items.length - 1) * _itemPaddingV +
        _menuPadding * 2;
    size = Vector2(_menuWidth, menuHeight);

    _buildTextPainters();
  }

  void _buildTextPainters() {
    for (final item in _items) {
      final painter = TextPainter(
        text: TextSpan(
          text: item.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: item.enabled
                ? Colors.white.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.35),
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

    if (_opacity < 1.0) {
      _opacity = (_opacity + _animSpeed * dt).clamp(0.0, 1.0);
    }
    if (_scaleValue < 1.0) {
      _scaleValue = (_scaleValue + _animSpeed * dt).clamp(0.0, 1.0);
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) {
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
      final itemTop = _menuPadding + i * (_itemHeight + _itemPaddingV);
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

    canvas.save();

    // 入场缩放动画（从顶部中心展开）
    if (_scaleValue < 1.0) {
      canvas.translate(size.x / 2, 0);
      canvas.scale(_scaleValue, _scaleValue);
      canvas.translate(-size.x / 2, 0);
    }

    final bgRect = Rect.fromLTWH(0, 0, size.x, size.y);
    final bgRRect = RRect.fromRectAndRadius(
      bgRect,
      const Radius.circular(_borderRadius),
    );

    // 外阴影（柔和扩散）
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35 * _opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawRRect(bgRRect.shift(const Offset(0, 2)), shadowPaint);

    // 背景：深色半透明（80% 不透明度）
    final bgPaint = Paint()
      ..color = const Color(0xFF0D1117).withValues(alpha: 0.80 * _opacity);
    canvas.drawRRect(bgRRect, bgPaint);

    // 内层微光（模拟毛玻璃高光）
    final innerGlowRect = Rect.fromLTWH(0, 0, size.x, size.y * 0.5);
    final innerGlowRRect = RRect.fromRectAndRadius(
      innerGlowRect,
      const Radius.circular(_borderRadius),
    );
    final innerGlowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.06 * _opacity),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(innerGlowRect);
    canvas.drawRRect(innerGlowRRect, innerGlowPaint);

    // 边框：细微白色描边
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10 * _opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawRRect(bgRRect, borderPaint);

    // 绘制菜单项
    for (int i = 0; i < _items.length; i++) {
      final itemTop = _menuPadding + i * (_itemHeight + _itemPaddingV);
      final itemRect = Rect.fromLTWH(
        _menuPadding,
        itemTop,
        size.x - _menuPadding * 2,
        _itemHeight,
      );

      // 悬停高亮：柔和白色填充
      if (i == _hoveredIndex && _items[i].enabled) {
        final hoverRRect = RRect.fromRectAndRadius(
          itemRect,
          const Radius.circular(6),
        );
        final hoverPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.12 * _opacity);
        canvas.drawRRect(hoverRRect, hoverPaint);
      }

      // 绘制文字（左对齐，带左边距）
      if (i < _textPainters.length) {
        final painter = _textPainters[i];
        final textX = itemRect.left + _itemPaddingH;
        final textY = itemRect.top + (itemRect.height - painter.height) / 2;
        painter.paint(canvas, Offset(textX, textY));
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
