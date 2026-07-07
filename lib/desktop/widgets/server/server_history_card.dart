import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/server_models.dart';
import '../../../core/widgets/dashed_line.dart';
import '../../../core/widgets/marquee_text.dart';
import '../player_trend/player_trend_chart.dart';

/// 历史卡片组件（固定宽度，无Hover，趋势图内嵌）
class ServerHistoryCard extends StatefulWidget {
  final bool isLatest;
  final String? mapUrl;
  final String mapName;
  final bool hasTrendData;
  final int trendDataCount;
  final String? translatedMapName;
  final String? serverName;
  final String mapPlayDuration;
  final List<PlayerTrendInfo>? trendData;
  final int maxPlayers;
  final Widget Function(String?, String) buildMapBackground;
  final Widget Function(IconData, String, {Color? color}) buildStatChip;
  final int? finalCtScore;
  final int? finalTScore;
  final Widget timeHeader;

  const ServerHistoryCard({
    super.key,
    required this.isLatest,
    required this.mapUrl,
    required this.mapName,
    required this.hasTrendData,
    required this.trendDataCount,
    this.translatedMapName,
    this.serverName,
    required this.mapPlayDuration,
    required this.trendData,
    required this.maxPlayers,
    required this.buildMapBackground,
    required this.buildStatChip,
    this.finalCtScore,
    this.finalTScore,
    required this.timeHeader,
  });

  @override
  State<ServerHistoryCard> createState() => _ServerHistoryCardState();
}

class _ServerHistoryCardState extends State<ServerHistoryCard> {
  // 带描边阴影的图标标签行
  static const _textShadow = [
    Shadow(offset: Offset(0, 1), blurRadius: 3.0, color: Colors.black87),
  ];
  static const _textShadowLight = [
    Shadow(offset: Offset(0, 1), blurRadius: 2.0, color: Colors.black87),
  ];

  Widget _buildIconLabel(
    IconData icon,
    String text, {
    required double iconSize,
    required double fontSize,
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.normal,
    List<Shadow>? shadows,
  }) {
    return Row(
      children: [
        Icon(icon, size: iconSize, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: MarqueeText(
            text: text,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: fontWeight,
              shadows: shadows ?? _textShadow,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapInfoLabels() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.serverName != null) ...[
          _buildIconLabel(
            MdiIcons.server,
            widget.serverName!,
            iconSize: 12,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          const SizedBox(height: 2),
        ],
        if (widget.translatedMapName != null) ...[
          _buildIconLabel(
            MdiIcons.translate,
            widget.translatedMapName!,
            iconSize: 14,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 2),
          _buildIconLabel(
            MdiIcons.map,
            widget.mapName,
            iconSize: 12,
            fontSize: 12,
            color: Colors.white70,
            shadows: _textShadowLight,
          ),
        ] else ...[
          _buildIconLabel(
            MdiIcons.map,
            widget.mapName,
            iconSize: 14,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            widget.buildStatChip(
              MdiIcons.clockOutline,
              widget.mapPlayDuration,
            ),
          ],
        ),
      ],
    );
  }

  bool _isExpanded = false;

  bool get hasFinalScore =>
      widget.finalCtScore != null && widget.finalTScore != null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = widget.isLatest
        ? AppColors.amber500
        : (isDark ? Colors.white24 : Colors.black12);
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: widget.isLatest ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 12),
            child: widget.timeHeader,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.buildMapBackground(widget.mapUrl, widget.mapName),
                const _GradientOverlay(),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _buildMapInfoLabels(),
                ),
                if (hasFinalScore)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildScoreBadge(
                      widget.finalCtScore!,
                      widget.finalTScore!,
                    ),
                  ),
              ],
            ),
          ),
          if (widget.hasTrendData && widget.trendData != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: DashedLine(
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: double.infinity,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isExpanded ? '收起趋势图' : '查看人数趋势',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox(
                      width: double.infinity,
                      height: 0,
                    ),
                    secondChild: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SizedBox(
                            height: 120,
                            child: PlayerTrendChart(
                              infos: widget.trendData!,
                              maxPlayers: widget.maxPlayers,
                              width: constraints.maxWidth,
                              height: 120,
                            ),
                          );
                        },
                      ),
                    ),
                    crossFadeState: _isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 250),
                    sizeCurve: Curves.easeOutCubic,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  /// 构建比分徽章
  Widget _buildScoreBadge(int ctScore, int tScore) {
    // 判断是否为僵尸模式地图
    final isZombieMap =
        widget.mapName.startsWith('ze_') || widget.mapName.startsWith('zm_');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // CT/人类 比分
          Text(
            '$ctScore',
            style: TextStyle(
              color: isZombieMap
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFF93C5FD), // 人类绿色 / CT蓝色
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              ':',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // T/僵尸 比分
          Text(
            '$tScore',
            style: TextStyle(
              color: isZombieMap
                  ? const Color(0xFFF87171)
                  : const Color(0xFFFCD34D), // 僵尸红色 / T黄色
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientOverlay extends StatelessWidget {
  const _GradientOverlay();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
        ),
      ),
    );
  }
}
