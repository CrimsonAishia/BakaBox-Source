import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/models/map_tag_models.dart';
import '../../../../core/widgets/tight_wrap.dart';
import 'server_card_painters.dart';
import 'server_card_tag_chip.dart';

/// 一个包裹卡片的组件，负责在卡片 hover 且标签溢出时，在侧边弹出包含所有标签的 Popover
class HoverTagPopover extends StatefulWidget {
  final Widget child;
  final List<MapTagSimple> tags;
  final bool isHovered;
  final bool hasOverflow;

  const HoverTagPopover({
    super.key,
    required this.child,
    required this.tags,
    required this.isHovered,
    required this.hasOverflow,
  });

  @override
  State<HoverTagPopover> createState() => _HoverTagPopoverState();
}

class _HoverTagPopoverState extends State<HoverTagPopover> {
  final OverlayPortalController _tagPortalController = OverlayPortalController();
  final LayerLink _cardLink = LayerLink();
  Timer? _tagPopoverShowTimer;
  Timer? _tagPopoverHideTimer;

  @override
  void didUpdateWidget(HoverTagPopover oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isHovered != widget.isHovered) {
      if (widget.isHovered) {
        _scheduleShowTagPopover();
      } else {
        _scheduleHideTagPopover();
      }
    }

    if (oldWidget.hasOverflow != widget.hasOverflow) {
      if (!widget.hasOverflow && _tagPortalController.isShowing) {
        _tagPortalController.hide();
        _tagPopoverShowTimer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _tagPopoverShowTimer?.cancel();
    _tagPopoverHideTimer?.cancel();
    if (_tagPortalController.isShowing) {
      _tagPortalController.hide();
    }
    super.dispose();
  }

  void _scheduleShowTagPopover() {
    if (widget.tags.isEmpty) return;
    if (!widget.hasOverflow) return;

    _tagPopoverHideTimer?.cancel();
    if (_tagPortalController.isShowing) return;

    _tagPopoverShowTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted || !widget.isHovered) return;
      if (!widget.hasOverflow) return;
      _tagPortalController.show();
    });
  }

  void _scheduleHideTagPopover() {
    _tagPopoverShowTimer?.cancel();
    _tagPopoverHideTimer?.cancel();
    _tagPopoverHideTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (_tagPortalController.isShowing) {
        _tagPortalController.hide();
      }
    });
  }

  static const double _kPopoverMinWidth = 240;
  static const double _kPopoverMaxWidth = 360;
  static const double _kPopoverGap = 0;
  static const double _kPopoverScreenMargin = 16;

  Widget _buildTagPopoverFollower(BuildContext overlayContext) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return const SizedBox.shrink();
    
    // 获取 Overlay 的真实渲染区域（防止应用存在侧边栏等嵌套布局导致 MediaQuery 宽度不准）
    final overlayState = Overlay.maybeOf(overlayContext);
    final overlayBox = overlayState?.context.findRenderObject() as RenderBox?;
    
    // 坐标转换为相对于 Overlay 的真实坐标，而不是全屏幕坐标
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final targetCenterY = topLeft.dy + box.size.height / 2;
    
    final overlayWidth = overlayBox?.size.width ?? MediaQuery.of(overlayContext).size.width;
    final overlayHeight = overlayBox?.size.height ?? MediaQuery.of(overlayContext).size.height;
    
    final spaceRight = overlayWidth - (topLeft.dx + box.size.width);
    final spaceLeft = topLeft.dx;

    const requiredSpace = _kPopoverMinWidth + _kPopoverGap + _kPopoverScreenMargin;
    bool showOnRight;
    if (spaceRight >= requiredSpace) {
      showOnRight = true;
    } else if (spaceLeft >= requiredSpace) {
      showOnRight = false;
    } else {
      showOnRight = spaceRight >= spaceLeft;
    }

    final available =
        (showOnRight ? spaceRight : spaceLeft) -
        _kPopoverGap -
        _kPopoverScreenMargin;
    final availableMaxWidth = available
        .clamp(_kPopoverMinWidth, _kPopoverMaxWidth)
        .toDouble();

    const panelColor = Color(0xF21A1A1A);
    final borderColor = Colors.white.withValues(alpha: 0.12);

    final arrow = CustomPaint(
      size: const Size(8, 14),
      painter: ServerCardPopoverArrowPainter(
        pointingRight: !showOnRight,
        fillColor: panelColor,
        borderColor: borderColor,
      ),
    );

    final panel = Material(
      color: Colors.transparent,
      child: _PanelBoundsShifter(
        targetCenterY: targetCenterY,
        screenHeight: overlayHeight,
        margin: _kPopoverScreenMargin,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: _kPopoverMinWidth.clamp(0.0, availableMaxWidth),
            maxWidth: availableMaxWidth,
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildPopoverContent(),
          ),
        ),
      ),
    );

    // 显式指定 TextDirection，防止由于未继承导致的 Row 布局失败或反向
    final content = Directionality(
      textDirection: TextDirection.ltr,
      child: FractionalTranslation(
        translation: const Offset(0, -0.5), // 向上偏移自身高度的一半，实现垂直居中于 targetCenterY
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: showOnRight ? [arrow, panel] : [panel, arrow],
        ),
      ),
    );

    // 彻底弃用 CompositedTransformFollower，改用最稳定的绝对坐标系统。
    // Overlay 的本质就是一个 Stack，直接给 Positioned 是最可靠的，能够完美规避 followerAnchor 的各类越界剔除 Bug。
    return Positioned(
      left: showOnRight ? (topLeft.dx + box.size.width + _kPopoverGap) : null,
      right: showOnRight ? null : (overlayWidth - topLeft.dx + _kPopoverGap),
      top: targetCenterY,
      child: content,
    );
  }

  Widget _buildPopoverContent() {
    final officialTags = <MapTagSimple>[];
    final difficultyTags = <MapTagSimple>[];
    final tierTags = <MapTagSimple>[];
    final otherTags = <MapTagSimple>[];

    for (final t in widget.tags) {
      if (t.isOfficial == true) {
        officialTags.add(t);
      } else if (t.isDifficulty == true) {
        if (t.difficultyType == 'difficulty') {
          difficultyTags.add(t);
        } else if (t.difficultyType == 'tier' || t.difficultyType == 'tier_combined') {
          tierTags.add(t);
        } else {
          otherTags.add(t);
        }
      } else {
        otherTags.add(t);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (officialTags.isNotEmpty) ...[
          _buildPopoverTagSection('官方标签', officialTags),
          if (difficultyTags.isNotEmpty || tierTags.isNotEmpty || otherTags.isNotEmpty) const SizedBox(height: 12),
        ],
        if (difficultyTags.isNotEmpty) ...[
          _buildPopoverTagSection('难度标签', difficultyTags),
          if (tierTags.isNotEmpty || otherTags.isNotEmpty) const SizedBox(height: 12),
        ],
        if (tierTags.isNotEmpty) ...[
          _buildPopoverTagSection('Tier 标签', tierTags),
          if (otherTags.isNotEmpty) const SizedBox(height: 12),
        ],
        if (otherTags.isNotEmpty) ...[
          _buildPopoverTagSection('其他标签', otherTags),
        ],
      ],
    );
  }

  Widget _buildPopoverTagSection(String title, List<MapTagSimple> sectionTags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              MdiIcons.tagMultipleOutline,
              size: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              '$title · ${sectionTags.length}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TightWrap(
          spacing: 6,
          runSpacing: 6,
          children: sectionTags.map((t) => ServerCardTagChip(tag: t, showPrefix: true)).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _cardLink,
      child: OverlayPortal(
        controller: _tagPortalController,
        overlayChildBuilder: (overlayContext) => _buildTagPopoverFollower(overlayContext),
        child: widget.child,
      ),
    );
  }
}

class _PanelBoundsShifter extends SingleChildRenderObjectWidget {
  final double targetCenterY;
  final double screenHeight;
  final double margin;

  const _PanelBoundsShifter({
    required Widget child,
    required this.targetCenterY,
    required this.screenHeight,
    required this.margin,
  }) : super(child: child);

  @override
  _RenderPanelBoundsShifter createRenderObject(BuildContext context) {
    return _RenderPanelBoundsShifter(
      targetCenterY: targetCenterY,
      screenHeight: screenHeight,
      margin: margin,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderPanelBoundsShifter renderObject) {
    renderObject
      ..targetCenterY = targetCenterY
      ..screenHeight = screenHeight
      ..margin = margin;
  }
}

class _RenderPanelBoundsShifter extends RenderShiftedBox {
  double _targetCenterY;
  double _screenHeight;
  double _margin;

  _RenderPanelBoundsShifter({
    RenderBox? child,
    required double targetCenterY,
    required double screenHeight,
    required double margin,
  })  : _targetCenterY = targetCenterY,
        _screenHeight = screenHeight,
        _margin = margin,
        super(child);

  set targetCenterY(double value) {
    if (_targetCenterY != value) {
      _targetCenterY = value;
      markNeedsLayout();
    }
  }

  set screenHeight(double value) {
    if (_screenHeight != value) {
      _screenHeight = value;
      markNeedsLayout();
    }
  }

  set margin(double value) {
    if (_margin != value) {
      _margin = value;
      markNeedsLayout();
    }
  }

  @override
  void performLayout() {
    if (child != null) {
      // 移除 maxHeight 限制，让面板呈现其自然高度（不滚动）
      child!.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(child!.size);

      double idealTopGlobal = _targetCenterY - size.height / 2;
      double actualTopGlobal = idealTopGlobal;

      // 1. 如果超出底部，则向上推
      if (actualTopGlobal + size.height > _screenHeight - _margin) {
        actualTopGlobal = _screenHeight - _margin - size.height;
      }
      
      // 2. 如果超出顶部，则向下推（顶部优先级更高，确保即使面板比屏幕还高，顶部也不被截断）
      if (actualTopGlobal < _margin) {
        actualTopGlobal = _margin;
      }

      final shiftY = actualTopGlobal - idealTopGlobal;
      final childParentData = child!.parentData as BoxParentData;
      childParentData.offset = Offset(0, shiftY);
    } else {
      size = Size.zero;
    }
  }
}
