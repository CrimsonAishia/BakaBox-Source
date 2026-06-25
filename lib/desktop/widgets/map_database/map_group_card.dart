import 'package:flutter/material.dart';

import '../../../core/models/map_contribution_models.dart';
import '../../../core/models/map_tag_models.dart' show MapTagSimple;
import '../../../core/services/image_url_service.dart';
import '../../../core/widgets/disk_cached_image.dart';
import '../../../core/widgets/marquee_text.dart';
import '../cd_badge.dart';
import 'map_history_dialog.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/map_tag_utils.dart';
import '../server/server_card_components/server_card_tag_chip.dart';

/// 地图大卡片组件
///
/// 显示单个地图的大卡片，点击后弹出详情对话框
class MapGroupCard extends StatefulWidget {
  final MapContributionGroup group;
  final VoidCallback onTap;
  final bool showAuditStatus; // 是否显示审核状态

  const MapGroupCard({
    super.key,
    required this.group,
    required this.onTap,
    this.showAuditStatus = false,
  });

  @override
  State<MapGroupCard> createState() => _MapGroupCardState();
}

class _MapGroupCardState extends State<MapGroupCard> {
  bool _isHovered = false;
  Future<String>? _signedUrlFuture;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  @override
  void didUpdateWidget(MapGroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.mapInfo.mapBackground !=
        widget.group.mapInfo.mapBackground) {
      _loadSignedUrl();
    }
  }

  void _loadSignedUrl() {
    final bg = widget.group.mapInfo.mapBackground;
    if (bg != null && bg.isNotEmpty) {
      _signedUrlFuture = ImageUrlService.instance.getSignedUrl(bg);
    } else {
      _signedUrlFuture = null;
    }
  }

  void _showHistoryDialog() {
    MapHistoryDialog.show(
      context,
      mapName: widget.group.mapInfo.mapName,
      mapLabel: widget.group.mapInfo.mapLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mapInfo = widget.group.mapInfo;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? AppColors.primary
                : (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08)),
            width: _isHovered ? 2 : 1,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
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
            height: 75,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 背景图
                _buildMapBackground(mapInfo, isDark),

                // CD徽章（右上角）
                Positioned(top: 8, right: 8, child: _buildCdBadge(isDark)),

                // 审核状态标签（右上角，CD下方）
                if (widget.showAuditStatus && widget.group.items.isNotEmpty)
                  Positioned(
                    top: 44, // CD徽章下方
                    right: 8,
                    child: _buildAuditStatusBadge(
                      widget.group.items.first.auditStatus,
                    ),
                  ),

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
                        Row(
                          children: [
                            const Icon(
                              Icons.map_outlined,
                              size: 18,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: MarqueeText(
                                text: mapInfo.mapName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.2,
                                  fontFamily: 'monospace',
                                  letterSpacing: 0.5,
                                  shadows: [
                                    const Shadow(
                                      color: Colors.black,
                                      blurRadius: 8,
                                    ),
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.9,
                                      ),
                                      offset: const Offset(1, 1),
                                      blurRadius: 2,
                                    ),
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.9,
                                      ),
                                      offset: const Offset(-1, -1),
                                      blurRadius: 2,
                                    ),
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.9,
                                      ),
                                      offset: const Offset(1, -1),
                                      blurRadius: 2,
                                    ),
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.9,
                                      ),
                                      offset: const Offset(-1, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.translate,
                              size: 15,
                              color: Colors.white.withValues(alpha: 0.9),
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: MarqueeText(
                                text: mapInfo.mapLabel,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  shadows: [
                                    const Shadow(
                                      color: Colors.black,
                                      blurRadius: 4,
                                    ),
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.9,
                                      ),
                                      offset: const Offset(1, 1),
                                      blurRadius: 2,
                                    ),
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.9,
                                      ),
                                      offset: const Offset(-1, -1),
                                      blurRadius: 2,
                                    ),
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.9,
                                      ),
                                      offset: const Offset(1, -1),
                                      blurRadius: 2,
                                    ),
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.9,
                                      ),
                                      offset: const Offset(-1, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!_isHovered) ...[
                          const SizedBox(height: 6),
                          _buildMapTagRow(mapInfo.tags),
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
                            onPressed: widget.onTap,
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

  Widget _buildAuditStatusBadge(AuditStatus status) {
    // 统计各状态的贡献数量
    final items = widget.group.items;
    if (items.isEmpty) return const SizedBox.shrink();

    final pendingCount = items.where((item) => item.isPending).length;
    final approvedCount = items.where((item) => item.isApproved).length;
    final rejectedCount = items.where((item) => item.isRejected).length;

    // 优先级：待审核 > 已拒绝 > 已通过
    // 如果有待审核的，显示待审核
    if (pendingCount > 0) {
      return _buildStatusBadge(
        backgroundColor: Colors.orange.withValues(alpha: 0.9),
        textColor: Colors.white,
        label: '待审核',
        count: pendingCount,
        totalCount: items.length,
      );
    }

    // 如果有被拒绝的，显示已拒绝
    if (rejectedCount > 0) {
      return _buildStatusBadge(
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        textColor: Colors.white,
        label: '已拒绝',
        count: rejectedCount,
        totalCount: items.length,
      );
    }

    // 全部通过，显示已通过
    if (approvedCount > 0) {
      return _buildStatusBadge(
        backgroundColor: Colors.green.withValues(alpha: 0.9),
        textColor: Colors.white,
        label: '已通过',
        count: approvedCount,
        totalCount: items.length,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStatusBadge({
    required Color backgroundColor,
    required Color textColor,
    required String label,
    required int count,
    required int totalCount,
  }) {
    // 如果只有一个贡献，不显示数量
    final showCount = totalCount > 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
              height: 1,
            ),
          ),
          if (showCount) ...[
            const SizedBox(width: 4),
            Text(
              '$count/$totalCount',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: textColor.withValues(alpha: 0.9),
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMapBackground(MapInfo mapInfo, bool isDark) {
    if (mapInfo.mapBackground == null || mapInfo.mapBackground!.isEmpty) {
      return Container(
        color: isDark ? AppColors.slate800 : AppColors.gray200,
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

    // 使用缓存的 Future，避免每次 rebuild 都重新请求
    return FutureBuilder<String>(
      future: _signedUrlFuture,
      builder: (context, snapshot) {
        final imageUrl = snapshot.data ?? mapInfo.mapBackground!;
        return DiskCachedImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: Container(
            color: isDark ? AppColors.slate800 : AppColors.gray200,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: Container(
            color: isDark ? AppColors.slate800 : AppColors.gray200,
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
    final sortedTags = MapTagUtils.prepareTags(tags);
    if (sortedTags.isEmpty) {
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
        Expanded(child: _MapTagRow(tags: sortedTags)),
      ],
    );
  }

  /// 构建CD徽章
  Widget _buildCdBadge(bool isDark) {
    return MapCdBadge(
      mapName: widget.group.mapInfo.mapName,
      triggerOnHover: false,
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
    return ServerCardTagChip(tag: tag, showPrefix: true);
  }

  /// 测量单个标签的宽度
  double _measureTagWidth(MapTagSimple tag) {
    final displayName = tag.isOfficial == true ? '官:${tag.name}' : tag.name;
    final textPainter = TextPainter(
      text: TextSpan(text: displayName, style: _tagTextStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();

    // padding(horizontal: 8 * 2) + border(1 * 2) + ceil(textWidth) 防亚像素误差
    final width = textPainter.width.ceilToDouble() + 18;
    textPainter.dispose();
    return width;
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
