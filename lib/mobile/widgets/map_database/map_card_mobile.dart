import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/map_cd/map_cd_bloc.dart';
import '../../../core/bloc/map_cd/map_cd_event.dart';
import '../../../core/bloc/map_cd/map_cd_state.dart';
import '../../../core/models/map_contribution_models.dart';
import '../../../core/models/map_tag_models.dart' show MapTagSimple;
import '../../../core/services/image_url_service.dart';
import '../../../core/widgets/disk_cached_image.dart';
import '../../../core/widgets/marquee_text.dart';

/// 移动端地图卡片
class MapCardMobile extends StatefulWidget {
  final MapInfo mapInfo;
  final VoidCallback onTap;

  const MapCardMobile({super.key, required this.mapInfo, required this.onTap});

  @override
  State<MapCardMobile> createState() => _MapCardMobileState();
}

class _MapCardMobileState extends State<MapCardMobile> {
  Future<String>? _signedUrlFuture;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  @override
  void didUpdateWidget(MapCardMobile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapInfo.mapBackground != widget.mapInfo.mapBackground) {
      _loadSignedUrl();
    }
  }

  void _loadSignedUrl() {
    final bg = widget.mapInfo.mapBackground;
    if (bg != null && bg.isNotEmpty) {
      _signedUrlFuture = ImageUrlService.instance.getSignedUrl(bg);
    } else {
      _signedUrlFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapInfo = widget.mapInfo;

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 背景图（全铺）
              _buildBackground(mapInfo),

              // 底部渐变遮罩
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ),

              // CD 徽章（右上角）
              Positioned(
                top: 8,
                right: 8,
                child: _MapCdBadgeMobile(mapName: mapInfo.mapName),
              ),

              // 地图名称 + 译名（左下角，右侧留出 CD 徽章空间）
              Positioned(
                left: 10,
                right: 110,
                bottom: 38,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 地图原名
                    MarqueeText(
                      text: mapInfo.mapName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'monospace',
                        letterSpacing: 0.3,
                        shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 译名
                    MarqueeText(
                      text: '译名：${mapInfo.mapLabel}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 标签行（占满整行宽度，不受 CD 徽章影响）
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: _buildTagRow(mapInfo.tags),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground(MapInfo mapInfo) {
    final fallback = Container(
      color: const Color(0xFF1E293B),
      child: Center(
        child: Icon(
          Icons.map_outlined,
          size: 40,
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
    );

    if (mapInfo.mapBackground == null || mapInfo.mapBackground!.isEmpty) {
      return fallback;
    }

    return FutureBuilder<String>(
      future: _signedUrlFuture,
      builder: (context, snapshot) {
        final imageUrl = snapshot.data ?? mapInfo.mapBackground!;
        return DiskCachedImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: fallback,
          errorWidget: fallback,
        );
      },
    );
  }

  Widget _buildTagRow(List<MapTagSimple> tags) {
    if (tags.isEmpty) {
      return Row(
        children: [
          Icon(
            Icons.label_off_outlined,
            size: 13,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                fontSize: 11,
                fontWeight: FontWeight.w500,
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
          size: 13,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 4),
        Expanded(child: _AutoScrollTagRow(tags: tags)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 自动滚动标签行
// ---------------------------------------------------------------------------

class _AutoScrollTagRow extends StatefulWidget {
  final List<MapTagSimple> tags;

  const _AutoScrollTagRow({required this.tags});

  @override
  State<_AutoScrollTagRow> createState() => _AutoScrollTagRowState();
}

class _AutoScrollTagRowState extends State<_AutoScrollTagRow> {
  final ScrollController _scrollController = ScrollController();
  bool _needsScroll = false;
  bool _isScrolling = false;

  static const double _tagSpacing = 5.0;

  TextStyle get _baseStyle => TextStyle(
    color: Colors.white.withValues(alpha: 0.9),
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {});
  }

  @override
  void didUpdateWidget(_AutoScrollTagRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tags != widget.tags) {
      _isScrolling = false;
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _isScrolling = false;
    _scrollController.dispose();
    super.dispose();
  }

  double _measureTagWidth(MapTagSimple tag) {
    final painter = TextPainter(
      text: TextSpan(text: tag.name, style: _baseStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    return painter.width + 12; // padding horizontal 6*2
  }

  void _checkAndScroll(double containerWidth) {
    if (!mounted || containerWidth <= 0) return;

    double total = 0;
    for (int i = 0; i < widget.tags.length; i++) {
      total += _measureTagWidth(widget.tags[i]);
      if (i < widget.tags.length - 1) total += _tagSpacing;
    }

    final needs = total > containerWidth;
    if (needs != _needsScroll) {
      setState(() => _needsScroll = needs);
    }
    if (needs && !_isScrolling) _startScroll();
  }

  void _startScroll() async {
    if (!mounted || _isScrolling) return;
    _isScrolling = true;

    while (mounted && _needsScroll && _isScrolling) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_isScrolling) break;
      if (!_scrollController.hasClients) break;

      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) break;

      try {
        await _scrollController.animateTo(
          max,
          duration: Duration(
            milliseconds: (max * 0.05).toInt().clamp(2000, 8000),
          ),
          curve: Curves.linear,
        );
      } catch (_) {
        break;
      }

      if (!mounted || !_isScrolling) break;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_isScrolling) break;

      try {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } catch (_) {
        break;
      }

      if (!mounted || !_isScrolling) break;
      await Future.delayed(const Duration(milliseconds: 800));
    }

    _isScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndScroll(constraints.maxWidth);
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
              child: Row(children: _buildChips()),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildChips() {
    final chips = <Widget>[];
    for (int i = 0; i < widget.tags.length; i++) {
      chips.add(_buildChip(widget.tags[i]));
      if (i < widget.tags.length - 1) {
        chips.add(const SizedBox(width: _tagSpacing));
      }
    }
    return chips;
  }

  Widget _buildChip(MapTagSimple tag) {
    final color = tag.colorValue;
    if (color != null) {
      final darkColor = Color.lerp(color, Colors.black, 0.2)!;
      final lightColor = Color.lerp(color, Colors.white, 0.6)!;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              lightColor.withValues(alpha: 0.4),
              color.withValues(alpha: 0.5),
              darkColor.withValues(alpha: 0.45),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          tag.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(color: color.withValues(alpha: 0.8), blurRadius: 2),
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 1,
                offset: const Offset(1, 1),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(tag.name, style: _baseStyle),
    );
  }
}

// ---------------------------------------------------------------------------
// 移动端 CD 徽章（点击获取，点击刷新）
// ---------------------------------------------------------------------------

class _MapCdBadgeMobile extends StatelessWidget {
  final String mapName;

  const _MapCdBadgeMobile({required this.mapName});

  void _load(BuildContext context) {
    final bloc = context.read<MapCdBloc>();
    if (bloc.state.shouldLoad(mapName)) {
      bloc.add(LoadMapCd(mapName));
    }
  }

  void _refresh(BuildContext context) {
    final bloc = context.read<MapCdBloc>();
    bloc.add(ClearMapCdCache(mapName));
    bloc.add(LoadMapCd(mapName));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapCdBloc, MapCdState>(
      builder: (context, state) {
        final isLoading = state.isLoading(mapName);
        final cdInfo = state.getCd(mapName);
        final error = state.getError(mapName);
        final hasCache = state.isCacheValid(mapName);

        Widget content;
        Color borderColor;
        Color glowColor;
        VoidCallback? onTap;

        // 未加载且无缓存 → 点击获取
        if (!isLoading && cdInfo == null && error == null && !hasCache) {
          borderColor = const Color(0xFF6366F1).withValues(alpha: 0.5);
          glowColor = const Color(0xFF6366F1).withValues(alpha: 0.15);
          onTap = () => _load(context);
          content = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 13,
                color: const Color(0xFF818CF8),
              ),
              const SizedBox(width: 4),
              const Text(
                '点击获取CD',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF818CF8),
                  height: 1,
                ),
              ),
            ],
          );
        } else if (isLoading) {
          borderColor = Colors.blue.withValues(alpha: 0.6);
          glowColor = Colors.blue.withValues(alpha: 0.25);
          content = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.blue.shade300,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '获取中',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade300,
                  height: 1,
                ),
              ),
            ],
          );
        } else if (error != null) {
          borderColor = Colors.orange.withValues(alpha: 0.6);
          glowColor = Colors.orange.withValues(alpha: 0.2);
          onTap = () => _load(context);
          content = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 13,
                color: Colors.orange.shade300,
              ),
              const SizedBox(width: 4),
              Text(
                '失败',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade300,
                  height: 1,
                ),
              ),
            ],
          );
        } else if (cdInfo == null) {
          borderColor = Colors.white.withValues(alpha: 0.2);
          glowColor = Colors.transparent;
          content = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.remove_circle_outline,
                size: 13,
                color: Colors.white38,
              ),
              const SizedBox(width: 4),
              Text(
                '无数据',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.4),
                  height: 1,
                ),
              ),
            ],
          );
        } else {
          final cd = cdInfo.currentNominateCd;
          final isAvailable = cd == 0;
          final accentColor = isAvailable
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444);
          borderColor = accentColor.withValues(alpha: 0.8);
          glowColor = accentColor.withValues(alpha: 0.3);
          onTap = () => _refresh(context);
          content = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAvailable ? Icons.check_circle_rounded : Icons.schedule,
                size: 13,
                color: accentColor,
              ),
              const SizedBox(width: 4),
              Text(
                isAvailable ? '可预订' : 'CD：$cd',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                  height: 1,
                ),
              ),
            ],
          );
        }

        final badge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: glowColor != Colors.transparent
                ? [
                    BoxShadow(color: glowColor, blurRadius: 8, spreadRadius: 1),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              content,
              const SizedBox(height: 2),
              Text(
                's.zombieden.cn',
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 0.3,
                  height: 1,
                ),
              ),
            ],
          ),
        );

        if (onTap != null) {
          return GestureDetector(onTap: onTap, child: badge);
        }
        return badge;
      },
    );
  }
}
