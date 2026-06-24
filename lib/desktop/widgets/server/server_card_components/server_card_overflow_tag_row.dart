import 'package:flutter/material.dart';
import '../../../../core/models/map_tag_models.dart';
import 'server_card_tag_chip.dart';

class ServerCardOverflowTagRow extends StatefulWidget {
  final List<MapTagSimple> tags;
  final ValueChanged<bool>? onOverflowChanged;

  const ServerCardOverflowTagRow({
    super.key,
    required this.tags,
    this.onOverflowChanged,
  });

  @override
  State<ServerCardOverflowTagRow> createState() =>
      _ServerCardOverflowTagRowState();
}

class _ServerCardOverflowTagRowState extends State<ServerCardOverflowTagRow> {
  static const double _tagSpacing = 6.0;

  bool? _lastReportedOverflow;

  // 测量缓存：tags 引用 + maxWidth 都没变就直接复用结果，避免高频 layout 时反复
  // 走 TextPainter（窗口缩放、列表滚动场景）
  List<MapTagSimple>? _cachedTags;
  double? _cachedMaxWidth;
  int? _cachedHiddenCount;

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

  /// 测量单个标签的渲染宽度
  ///
  /// 注意：`Container` 的 `Border.all(width: 1)` 会**额外**占用宽度（左右各 1px），
  /// 必须把 border 算进来，否则会出现累计误差导致 Row 溢出且 +N 不触发。
  double _measureTagWidth(String text) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: _tagTextStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    // padding(horizontal: 8 * 2) + border(1 * 2) + ceil(textWidth) 防亚像素误差
    final width = textPainter.width.ceilToDouble() + 16 + 2;
    // Flutter 3.10+ 后 TextPainter 持有 image 资源，需主动释放
    textPainter.dispose();
    return width;
  }

  /// 计算溢出标签数量
  ///
  /// 全量渲染 + 浮动 +N 徽章覆盖：测量目的不是控制渲染，而是判断
  /// 在固定容器宽度下，哪些 chip 会被右侧浮动 +N 徽章遮住，从而算出 +N 数字。
  ///
  /// 规则：可见区域 = `maxWidth - +N徽章宽度 - spacing`
  /// 任何末端落在可见区域之外的 chip 都视为"被遮住"，计入 hiddenCount。
  ///
  /// 缓存：tags 引用 + maxWidth 都没变就直接复用上次结果。
  int _calculateHiddenCount(double maxWidth) {
    if (widget.tags.isEmpty) return 0;
    if (maxWidth <= 0) return 0;

    // 命中缓存（注意 List 用 identical 比对，依赖 tags 列表的不变性传递）
    if (identical(_cachedTags, widget.tags) &&
        _cachedMaxWidth == maxWidth &&
        _cachedHiddenCount != null) {
      return _cachedHiddenCount!;
    }

    final hidden = _computeHiddenCount(maxWidth);

    _cachedTags = widget.tags;
    _cachedMaxWidth = maxWidth;
    _cachedHiddenCount = hidden;
    return hidden;
  }

  int _computeHiddenCount(double maxWidth) {
    // 先看不加 +N 的情况下能不能全部塞下
    double total = 0;
    for (int i = 0; i < widget.tags.length; i++) {
      final tag = widget.tags[i];
      final displayName = tag.isOfficial == true ? '官:${tag.name}' : tag.name;
      total += _measureTagWidth(displayName);
      if (i < widget.tags.length - 1) total += _tagSpacing;
    }
    if (total <= maxWidth) return 0; // 全部能塞下，不需要 +N

    // 需要 +N：可见区域要扣掉 +N 徽章宽度 + spacing
    final plusBadgeWidth = _measureTagWidth('+99');
    final visibleArea = maxWidth - plusBadgeWidth - _tagSpacing;
    if (visibleArea <= 0) return widget.tags.length;

    double used = 0;
    int visible = 0;
    for (int i = 0; i < widget.tags.length; i++) {
      final tag = widget.tags[i];
      final displayName = tag.isOfficial == true ? '官:${tag.name}' : tag.name;
      final tagWidth = _measureTagWidth(displayName);
      final addition = (i == 0 ? 0 : _tagSpacing) + tagWidth;
      if (used + addition <= visibleArea) {
        used += addition;
        visible = i + 1;
      } else {
        break;
      }
    }
    return widget.tags.length - visible;
  }

  Widget _buildTagChip(MapTagSimple tag) {
    return ServerCardTagChip(tag: tag);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tags.isEmpty) {
      _reportOverflow(false);
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final hiddenCount = _calculateHiddenCount(maxWidth);
        _reportOverflow(hiddenCount > 0);

        // 构建全量 tag Row（用 SizedBox + OverflowBox 让 Row 在无限宽下展开，永远不溢出报错）
        final fullRow = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < widget.tags.length; i++) ...[
              if (i > 0) const SizedBox(width: _tagSpacing),
              _buildTagChip(widget.tags[i]),
            ],
          ],
        );

        // SizedBox 给一个固定宽度让父级约束确定，OverflowBox 解除子级宽度约束
        final unbounded = SizedBox(
          width: maxWidth,
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: double.infinity,
            child: fullRow,
          ),
        );

        return ClipRect(
          child: SizedBox(
            height: 27,
            width: maxWidth,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 底层：全量 tag Row（被 ClipRect 裁掉右边）
                Positioned.fill(child: unbounded),
                // 右侧渐变羽化 + +N 徽章浮层（仅在溢出时显示）
                if (hiddenCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: _buildOverflowOverlay(hiddenCount),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 右侧渐变遮罩 + +N 徽章浮层
  ///
  /// 布局：
  ///   - 第一层：遮罩横铺整个右侧区域，左缘羽化渐变、右段完全不透明，挡住所有被裁的 tag
  ///   - 第二层：+N 徽章浮在遮罩之上
  /// 遮罩颜色根据当前主题：暗色 → 黑、亮色 → 白
  Widget _buildOverflowOverlay(int hiddenCount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fadeBaseColor = isDark ? Colors.black : Colors.white;

    // 用绿色 MapTagSimple 复用普通 chip 的渐变/边框/阴影/文字样式
    final overflowTag = MapTagSimple(name: '+$hiddenCount', color: '#22C55E');

    // +N 徽章宽度估算（padding 16 + border 2 + 文字宽度）；超出时整个浮层至少这么宽
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        // 第一层：羽化遮罩（覆盖整个右侧）
        IgnorePointer(
          child: Container(
            // 整体宽度 = 羽化区 + +N 徽章占位（用足够宽度托住徽章）
            width: 96,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  fadeBaseColor.withValues(alpha: 0.0),
                  fadeBaseColor.withValues(alpha: 0.7),
                  fadeBaseColor.withValues(alpha: 1.0),
                  fadeBaseColor.withValues(alpha: 1.0),
                ],
                stops: const [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),
        ),
        // 第二层：+N 徽章浮在遮罩上
        Padding(
          padding: const EdgeInsets.only(right: 0),
          child: _buildTagChip(overflowTag),
        ),
      ],
    );
  }

  /// 通知父级溢出状态（去抖：状态未变化不重复回调）
  void _reportOverflow(bool overflow) {
    if (_lastReportedOverflow == overflow) return;
    _lastReportedOverflow = overflow;
    final cb = widget.onOverflowChanged;
    if (cb == null) return;
    // 在 build 期间调用，延后到帧结束后通知，避免触发父级 setState 警告
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      cb(overflow);
    });
  }
}
