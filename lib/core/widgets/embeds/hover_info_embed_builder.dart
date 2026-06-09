import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'hover_info_block_embed.dart';
import 'hover_info_card.dart';

/// 悬浮引用徽章 EmbedBuilder（内联）
///
/// 在文本中渲染彩色胶囊徽章，鼠标悬停 200ms 后弹出详情卡片。
/// 移开 150ms 内未进入卡片则关闭。
///
/// 使用 Flutter 内置 [OverlayPortal] + [CompositedTransformTarget]/[CompositedTransformFollower]
/// 实现悬浮卡片，无需 flutter_portal 的 Portal 祖先，桌面/移动端均可用。
class HoverInfoEmbedBuilder extends EmbedBuilder {
  const HoverInfoEmbedBuilder();

  @override
  String get key => hoverInfoEmbedType;

  @override
  bool get expanded => false;

  @override
  WidgetSpan buildWidgetSpan(Widget widget) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: widget,
    );
  }

  @override
  String toPlainText(Embed node) {
    // 纯文本表示：用 label 替代，便于字数统计与复制
    final data = HoverInfoBlockEmbed.parseData(node.value.data as String);
    return data != null ? data.label : super.toPlainText(node);
  }

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = HoverInfoBlockEmbed.parseData(
      embedContext.node.value.data as String,
    );
    if (data == null) {
      return const SizedBox.shrink();
    }
    return _HoverInfoBadge(data: data);
  }
}

/// 悬浮徽章 Widget
class _HoverInfoBadge extends StatefulWidget {
  final HoverInfoData data;

  const _HoverInfoBadge({required this.data});

  @override
  State<_HoverInfoBadge> createState() => _HoverInfoBadgeState();
}

class _HoverInfoBadgeState extends State<_HoverInfoBadge> {
  final OverlayPortalController _portalController = OverlayPortalController();
  final LayerLink _link = LayerLink();

  Timer? _showTimer;
  Timer? _hideTimer;

  /// 卡片相对徽章在上方还是下方（根据空间自适应）
  bool _showAbove = true;

  /// 鼠标是否悬停在徽章上（用于即时视觉反馈）
  bool _isHovering = false;

  void _scheduleShow() {
    _hideTimer?.cancel();
    if (_portalController.isShowing) return;
    _showTimer?.cancel();
    _showTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _decideDirection();
      _portalController.show();
    });
  }

  void _scheduleHide() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (_portalController.isShowing) _portalController.hide();
    });
  }

  /// 根据徽章在屏幕中的位置决定卡片弹出方向，避免超出顶部
  void _decideDirection() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _showAbove = true;
      return;
    }
    final topLeft = box.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    const cardHeight = 220.0;
    // 上方空间不足且下方空间充足 → 往下弹
    final spaceAbove = topLeft.dy;
    final spaceBelow = screenHeight - (topLeft.dy + box.size.height);
    _showAbove = spaceAbove >= cardHeight || spaceAbove >= spaceBelow;
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = HoverInfoColors.color(widget.data.type);
    final icon = HoverInfoColors.icon(widget.data.type);

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: (overlayContext) {
          return _buildCardFollower();
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            _scheduleShow();
            if (mounted) setState(() => _isHovering = true);
          },
          onExit: (_) {
            _scheduleHide();
            if (mounted) setState(() => _isHovering = false);
          },
          child: _buildBadge(color, icon),
        ),
      ),
    );
  }

  Widget _buildCardFollower() {
    final followerAnchor =
        _showAbove ? Alignment.bottomCenter : Alignment.topCenter;
    final targetAnchor =
        _showAbove ? Alignment.topCenter : Alignment.bottomCenter;

    // 用 Stack 顶层放置 follower，follower 通过 LayerLink 跟随徽章定位
    return Stack(
      children: [
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          followerAnchor: followerAnchor,
          targetAnchor: targetAnchor,
          child: MouseRegion(
            onEnter: (_) => _hideTimer?.cancel(),
            onExit: (_) => _scheduleHide(),
            child: HoverInfoCard(data: widget.data),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(Color color, IconData icon) {
    // hover 时加深背景、加实边框，提供即时反馈
    final bgAlpha = _isHovering ? 0.22 : 0.12;
    final borderAlpha = _isHovering ? 0.65 : 0.35;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: borderAlpha),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 5),
          // label 带虚线下划线，暗示「可悬停查看详情」
          Text(
            widget.data.label,
            strutStyle: const StrutStyle(
              fontSize: 16,
              height: 1.0,
              forceStrutHeight: true,
            ),
            style: TextStyle(
              fontSize: 16,
              height: 1.0,
              fontWeight: FontWeight.w600,
              color: color,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dotted,
              decorationColor: color.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 4),
          // 末尾指示图标，明确标识可展开更多信息
          Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: color.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }
}
