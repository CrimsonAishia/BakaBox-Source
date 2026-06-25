import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/models/map_tag_models.dart';
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
  bool _showPopoverOnRight = true;

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

    _tagPopoverShowTimer?.cancel();
    _tagPopoverShowTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted || !widget.isHovered) return;
      if (!widget.hasOverflow) return;
      _decideTagPopoverDirection();
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

  void _decideTagPopoverDirection() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _showPopoverOnRight = true;
      return;
    }
    final topLeft = box.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.of(context).size.width;

    final spaceRight = screenWidth - (topLeft.dx + box.size.width);
    final spaceLeft = topLeft.dx;

    const required = _kPopoverMinWidth + _kPopoverGap + _kPopoverScreenMargin;

    if (spaceRight >= required) {
      _showPopoverOnRight = true;
    } else if (spaceLeft >= required) {
      _showPopoverOnRight = false;
    } else {
      _showPopoverOnRight = spaceRight >= spaceLeft;
    }
  }

  static const double _kPopoverMinWidth = 240;
  static const double _kPopoverMaxWidth = 360;
  static const double _kPopoverMaxHeight = 360;
  static const double _kPopoverGap = 0;
  static const double _kPopoverScreenMargin = 16;

  Widget _buildTagPopoverFollower() {
    final followerAnchor = _showPopoverOnRight
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final targetAnchor = _showPopoverOnRight
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final offset = _showPopoverOnRight
        ? const Offset(_kPopoverGap, 0)
        : const Offset(-_kPopoverGap, 0);

    final box = context.findRenderObject() as RenderBox?;
    double availableMaxWidth = _kPopoverMaxWidth;
    if (box != null && box.hasSize) {
      final topLeft = box.localToGlobal(Offset.zero);
      final screenWidth = MediaQuery.of(context).size.width;
      final spaceRight = screenWidth - (topLeft.dx + box.size.width);
      final spaceLeft = topLeft.dx;
      final available =
          (_showPopoverOnRight ? spaceRight : spaceLeft) -
          _kPopoverGap -
          _kPopoverScreenMargin;
      availableMaxWidth = available
          .clamp(_kPopoverMinWidth, _kPopoverMaxWidth)
          .toDouble();
    }

    const panelColor = Color(0xF21A1A1A);
    final borderColor = Colors.white.withValues(alpha: 0.12);

    final arrow = CustomPaint(
      size: const Size(8, 14),
      painter: ServerCardPopoverArrowPainter(
        pointingRight: !_showPopoverOnRight,
        fillColor: panelColor,
        borderColor: borderColor,
      ),
    );

    final panel = Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: _kPopoverMinWidth.clamp(0, availableMaxWidth),
          maxWidth: availableMaxWidth,
          maxHeight: _kPopoverMaxHeight,
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
          child: SingleChildScrollView(
            child: _buildPopoverContent(),
          ),
        ),
      ),
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: _showPopoverOnRight ? [arrow, panel] : [panel, arrow],
    );

    return CompositedTransformFollower(
      link: _cardLink,
      showWhenUnlinked: false,
      followerAnchor: followerAnchor,
      targetAnchor: targetAnchor,
      offset: offset,
      child: content,
    );
  }

  Widget _buildPopoverContent() {

    final officialTags = widget.tags.where((t) => t.isOfficial == true).toList();
    final difficultyTags = widget.tags.where((t) => t.isOfficial != true && t.isDifficulty == true && t.difficultyType == 'difficulty').toList();
    final tierTags = widget.tags.where((t) => t.isOfficial != true && t.isDifficulty == true && (t.difficultyType == 'tier' || t.difficultyType == 'tier_combined')).toList();
    final otherTags = widget.tags.where((t) => t.isOfficial != true && !(t.isDifficulty == true && (t.difficultyType == 'difficulty' || t.difficultyType == 'tier' || t.difficultyType == 'tier_combined'))).toList();

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
        Wrap(
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
        overlayChildBuilder: (overlayContext) => _buildTagPopoverFollower(),
        child: widget.child,
      ),
    );
  }
}
