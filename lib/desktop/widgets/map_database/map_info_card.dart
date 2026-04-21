import 'package:flutter/material.dart';

import '../../../core/models/map_contribution_models.dart';
import '../../../core/models/map_tag_models.dart';
import '../../../core/services/image_url_service.dart';
import '../../../core/widgets/disk_cached_image.dart';
import '../../../core/widgets/map_contribution_dialog.dart';
import '../../../core/widgets/marquee_text.dart';
import 'map_history_dialog.dart';

/// 地图信息卡片组件
///
/// 显示单个地图的信息卡片，点击后弹出贡献对话框
class MapInfoCard extends StatefulWidget {
  final MapInfo mapInfo;

  const MapInfoCard({super.key, required this.mapInfo});

  @override
  State<MapInfoCard> createState() => _MapInfoCardState();
}

class _MapInfoCardState extends State<MapInfoCard> {
  bool _isHovered = false;

  void _showContributionDialog() {
    MapContributionDialog.show(
      context,
      mapName: widget.mapInfo.mapName,
      mapLabel: widget.mapInfo.mapLabel,
    );
  }

  void _showHistoryDialog() {
    MapHistoryDialog.show(
      context,
      mapName: widget.mapInfo.mapName,
      mapLabel: widget.mapInfo.mapLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? const Color(0xFF0080FF)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08)),
            width: _isHovered ? 2 : 1,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: const Color(0xFF0080FF).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 背景图
                _buildMapBackground(widget.mapInfo, isDark),

                // 底部渐变遮罩（始终显示）
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: _isHovered ? 100 : 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(
                            alpha: _isHovered ? 0.95 : 0.8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 地图名称（始终显示）
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: _isHovered ? 56 : 12,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: 1.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MarqueeText(
                          text: widget.mapInfo.mapName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        MarqueeText(
                          text: '译名：${widget.mapInfo.mapLabel}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                        if (!_isHovered) ...[
                          const SizedBox(height: 4),
                          _buildMapTagRow(widget.mapInfo.tags),
                        ],
                      ],
                    ),
                  ),
                ),

                // Hover 时显示的按钮
                if (_isHovered)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildBottomButton(
                            icon: Icons.info_outline,
                            label: '地图信息',
                            onPressed: _showContributionDialog,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBottomButton(
                            icon: Icons.history,
                            label: '运行记录',
                            onPressed: _showHistoryDialog,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapBackground(MapInfo mapInfo, bool isDark) {
    if (mapInfo.mapBackground == null || mapInfo.mapBackground!.isEmpty) {
      return Container(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE5E7EB),
        child: Center(
          child: Icon(
            Icons.map_outlined,
            size: 48,
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.2),
          ),
        ),
      );
    }

    return FutureBuilder<String>(
      future: ImageUrlService.instance.getSignedUrl(mapInfo.mapBackground!),
      builder: (context, snapshot) {
        final imageUrl = snapshot.data ?? mapInfo.mapBackground!;
        return DiskCachedImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: Container(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE5E7EB),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: Container(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE5E7EB),
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: 48,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.2),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return _BottomButton(icon: icon, label: label, onPressed: onPressed);
  }

  Widget _buildMapTagRow(List<MapTagSimple> tags) {
    if (tags.isEmpty) {
      return Row(
        children: [
          Icon(
            Icons.label_off_outlined,
            size: 16,
            color: Colors.white.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Text(
              '暂无标签',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(
          Icons.label_outline,
          size: 16,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 6),
        Expanded(child: _MapTagRow(tags: tags)),
      ],
    );
  }
}

/// 底部按钮组件（带 hover 效果）
class _BottomButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _BottomButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_BottomButton> createState() => _BottomButtonState();
}

class _BottomButtonState extends State<_BottomButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 36,
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isHovered
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 滚动标签行组件 - 标签过多时自动水平滚动
class _MapTagRow extends StatefulWidget {
  final List<MapTagSimple> tags;

  const _MapTagRow({required this.tags});

  @override
  State<_MapTagRow> createState() => _MapTagRowState();
}

class _MapTagRowState extends State<_MapTagRow> {
  ScrollController? _scrollController;
  bool _needsScroll = false;
  bool _isScrolling = false;
  double _totalScrollWidth = 0;
  double _containerWidth = 0;

  // 固定间距（spacing: 6）
  static const double _tagSpacing = 6.0;

  // 标签样式（与 _buildTagChip 保持一致）
  TextStyle get _tagTextStyle => TextStyle(
        color: Colors.white.withValues(alpha: 0.9),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      );

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(_MapTagRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tags != widget.tags) {
      _stopScrolling();
      _scrollController?.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _containerWidth > 0) {
          _checkOverflowWithContainerWidth(_containerWidth);
        }
      });
    }
  }

  @override
  void dispose() {
    _stopScrolling();
    _scrollController?.dispose();
    super.dispose();
  }

  void _stopScrolling() {
    _isScrolling = false;
  }

  /// 构建单个标签 Widget
  Widget _buildTagChip(MapTagSimple tag) {
    final tagColorValue = tag.colorValue;

    if (tagColorValue != null) {
      final darkColor = Color.lerp(tagColorValue, Colors.black, 0.2)!;
      final lightColor = Color.lerp(tagColorValue, Colors.white, 0.6)!;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              lightColor.withValues(alpha: 0.4),
              tagColorValue.withValues(alpha: 0.5),
              darkColor.withValues(alpha: 0.45),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: tagColorValue.withValues(alpha: 0.7),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: tagColorValue.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          tag.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                color: tagColorValue.withValues(alpha: 0.8),
                blurRadius: 2,
                offset: const Offset(0, 0),
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 1,
                offset: const Offset(1, 1),
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 1,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
        ),
      );
    }

    // 无颜色时的处理
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(tag.name, style: _tagTextStyle),
    );
  }

  /// 测量单个标签的宽度
  double _measureTagWidth(MapTagSimple tag) {
    final textPainter = TextPainter(
      text: TextSpan(text: tag.name, style: _tagTextStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();

    // padding(horizontal: 8 * 2) + textWidth
    return textPainter.width + 16;
  }

  /// 检查是否需要滚动（通过 LayoutBuilder 获取容器宽度）
  void _checkOverflowWithContainerWidth(double maxWidth) {
    if (!mounted) return;

    _containerWidth = maxWidth;
    if (_containerWidth <= 0) return;

    double totalWidth = 0;
    for (int i = 0; i < widget.tags.length; i++) {
      totalWidth += _measureTagWidth(widget.tags[i]);
      if (i < widget.tags.length - 1) {
        totalWidth += _tagSpacing;
      }
    }

    final needsScroll = totalWidth > _containerWidth;

    if (needsScroll != _needsScroll ||
        (needsScroll && (totalWidth - _totalScrollWidth).abs() > 1)) {
      setState(() {
        _needsScroll = needsScroll;
        _totalScrollWidth = totalWidth;
      });
    }

    if (_needsScroll && !_isScrolling) {
      _startScrolling();
    }
  }

  /// 开始滚动动画
  void _startScrolling() async {
    if (!mounted || !_needsScroll || _scrollController == null) return;
    if (!_scrollController!.hasClients) return;

    _isScrolling = true;

    while (mounted && _needsScroll && _isScrolling) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_needsScroll || _scrollController == null) break;
      if (!_scrollController!.hasClients) break;

      final maxScroll = _scrollController!.position.maxScrollExtent;
      if (maxScroll <= 0) break;

      try {
        await _scrollController!.animateTo(
          maxScroll,
          duration: Duration(
            milliseconds: (maxScroll * 0.05).toInt().clamp(3000, 10000),
          ),
          curve: Curves.linear,
        );
      } catch (_) {
        break;
      }

      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) break;

      try {
        await _scrollController!.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } catch (_) {
        break;
      }

      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
    }

    _isScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    // 离屏渲染降级
    if (View.maybeOf(context) == null) {
      return Row(
        children: [
          ..._buildTagRow().take(5),
          if (widget.tags.length > 5)
            Text('...', style: _tagTextStyle.copyWith(color: Colors.white54)),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkOverflowWithContainerWidth(constraints.maxWidth);
        });
        return ClipRect(
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: _needsScroll
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(children: _buildTagRow()),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildTagRow() {
    final List<Widget> widgets = [];
    for (int i = 0; i < widget.tags.length; i++) {
      widgets.add(_buildTagChip(widget.tags[i]));
      if (i < widget.tags.length - 1) {
        widgets.add(const SizedBox(width: _tagSpacing));
      }
    }
    return widgets;
  }
}
