import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/server_models.dart';
import '../../../core/widgets/dashed_line.dart';
import '../player_trend/player_trend_chart.dart';

/// 历史卡片组件（固定宽度，无Hover，趋势图内嵌）
class ServerHistoryCard extends StatefulWidget {
  final bool isLatest;
  final String? mapUrl;
  final String mapName;
  final bool hasTrendData;
  final int trendDataCount;
  final String formattedMapName;
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
    required this.formattedMapName,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.formattedMapName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                  ),
                ),
                if (hasFinalScore)
                  Positioned(
                    top: 8,
                    right: 12,
                    child: widget.buildStatChip(
                      MdiIcons.flagCheckered,
                      '${widget.finalCtScore} : ${widget.finalTScore}',
                      color: AppColors.primary,
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
          ] else ...[
            const SizedBox(height: 12),
          ],
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
