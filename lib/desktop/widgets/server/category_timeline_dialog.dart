import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bakabox_app/core/bloc/server/server_bloc.dart';
import 'package:bakabox_app/core/models/map_contribution_models.dart';
import 'package:bakabox_app/core/models/server_models.dart';
import 'package:bakabox_app/core/api/server_api.dart';
import 'package:bakabox_app/core/constants/app_colors.dart';
import 'package:bakabox_app/desktop/widgets/server/server_history_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:bakabox_app/core/utils/time_utils.dart';
import 'package:bakabox_app/core/utils/map_utils.dart';
import 'package:bakabox_app/core/widgets/map_background.dart';
import 'package:bakabox_app/core/utils/log_service.dart';
import 'package:intl/intl.dart';

class CategoryTimelineDialog extends StatefulWidget {
  final int initialServerGroupId;
  final List<ServerCategory> categories;

  const CategoryTimelineDialog({
    super.key,
    required this.initialServerGroupId,
    required this.categories,
  });

  @override
  State<CategoryTimelineDialog> createState() => _CategoryTimelineDialogState();
}

class _CategoryTimelineDialogState extends State<CategoryTimelineDialog> {
  final ServerApi _serverApi = ServerApi();
  bool _isLoading = true;
  String? _error;
  List<MapHistoryRecord> _records = [];
  final ScrollController _scrollController = ScrollController();
  late int _currentServerGroupId;
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  // 地图信息缓存
  final Map<String, MapData> _mapInfoCache = {};
  final Set<String> _loadingMaps = {};

  @override
  void initState() {
    super.initState();
    _currentServerGroupId = widget.initialServerGroupId;
    _fetchHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final request = MapHistoryRequest(
        serverGroupId: _currentServerGroupId,
        date: _dateFormat.format(_selectedDate),
        pagination: const PaginationParams(pageSize: 50),
      );
      final response = await _serverApi.getMapHistory(request);

      if (mounted) {
        setState(() {
          _records = response?.data ?? [];
          _isLoading = false;
        });
        _loadMapInfosForCurrentData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// 加载地图信息
  Future<void> _loadMapInfosForCurrentData() async {
    final uniqueMapNames = _records
        .map((item) => item.mapName)
        .where((name) => name.isNotEmpty)
        .toSet();

    final mapsToLoadInfo = <String>[];
    for (final mapName in uniqueMapNames) {
      if (!_mapInfoCache.containsKey(mapName) &&
          !_loadingMaps.contains(mapName)) {
        mapsToLoadInfo.add(mapName);
        _loadingMaps.add(mapName);
      }
    }

    final futures = <Future>[];
    for (final mapName in mapsToLoadInfo) {
      futures.add(_loadMapInfoSilent(mapName));
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadMapInfoSilent(String mapName) async {
    try {
      final mapInfo = await _serverApi.getMapInfo(mapName);
      if (mapInfo != null && mounted) {
        _mapInfoCache[mapName] = mapInfo;
      }
    } catch (e) {
      LogService.w('获取地图 $mapName 信息失败: $e');
    } finally {
      _loadingMaps.remove(mapName);
    }
  }

  String _formatDuration(DateTime? start, DateTime? end) {
    if (start == null) return '无数据';
    final endTime = end ?? DateTime.now();
    final diff = endTime.difference(start);
    return TimeUtils.formatDuration(diff);
  }

  String? _getTranslatedMapName(MapHistoryRecord snapshot) {
    final mapInfo = _mapInfoCache[snapshot.mapName];
    final mapLabel = mapInfo?.mapLabel;
    return (mapLabel?.isNotEmpty == true) ? mapLabel : null;
  }

  String _getServerName(String address) {
    try {
      final state = context.read<ServerBloc>().state;
      for (final s in state.servers) {
        if (s.serverItem.address == address) {
          return s.serverItem.getDisplayName(s.serverData?.hostName);
        }
      }
    } catch (_) {}
    return address;
  }

  String? _getMapBackgroundUrl(MapHistoryRecord snapshot) {
    final mapInfo = _mapInfoCache[snapshot.mapName];
    return MapUtils.getMapImageUrl(snapshot.mapName, mapUrl: mapInfo?.mapUrl);
  }

  Widget _buildMapBackground(String? mapUrl, String mapName) {
    return MapBackground(
      mapName: mapName,
      imageUrl: mapUrl,
      cacheWidth: 560, // 280 * 2
      cacheHeight: 240, // 120 * 2
    );
  }

  Widget _buildTimeHeader(MapHistoryRecord snapshot, int index, bool isLatest) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeColor = isDark ? Colors.white70 : AppColors.gray500;

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isLatest ? AppColors.amber500 : AppColors.slate500,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '#${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Icon(
                isLatest ? MdiIcons.fire : MdiIcons.clockOutline,
                size: 14,
                color: isLatest ? AppColors.amber500 : timeColor,
              ),
              const SizedBox(width: 4),
              Text(
                TimeUtils.formatWithWeekday(
                  snapshot.createdAt.toIso8601String(),
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: isLatest ? AppColors.amber500 : timeColor,
                  fontWeight: isLatest ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        if (isLatest)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.amber500,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '最新',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String text, {Color? color}) {
    final chipColor = color ?? Colors.white70;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: chipColor),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: chipColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.slate900 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 1000,
        height: 700,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    MdiIcons.timelineTextOutline,
                    size: 24,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '地图历史时间线',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (widget.categories.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _currentServerGroupId,
                          dropdownColor: isDark
                              ? AppColors.slate800
                              : Colors.white,
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          onChanged: (int? newValue) {
                            if (newValue != null &&
                                newValue != _currentServerGroupId) {
                              setState(() {
                                _currentServerGroupId = newValue;
                              });
                              _fetchHistory();
                            }
                          },
                          items: widget.categories.map((category) {
                            return DropdownMenuItem<int>(
                              value: category.id,
                              child: Text(category.modelName ?? '未知分类'),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      backgroundColor: isDark ? Colors.black26 : Colors.black12,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      final DateTime now = DateTime.now();
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: now.subtract(const Duration(days: 30)),
                        lastDate: now,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: isDark
                                  ? const ColorScheme.dark(primary: AppColors.primary)
                                  : const ColorScheme.light(primary: AppColors.primary),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null && picked != _selectedDate) {
                        setState(() {
                          _selectedDate = picked;
                        });
                        _fetchHistory();
                      }
                    },
                    icon: Icon(
                      MdiIcons.calendarToday,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      _dateFormat.format(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    splashRadius: 24,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '加载失败: $_error',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchHistory,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : _records.isEmpty
                  ? const Center(child: Text('暂无历史记录'))
                  : _buildSnakeTimeline(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnakeTimeline() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = 280.0;
        final spacing = 40.0;
        // Calculate max items per row
        int itemsPerRow =
            (constraints.maxWidth + spacing) ~/ (cardWidth + spacing);
        if (itemsPerRow < 1) itemsPerRow = 1;

        // Ensure the items stay centered
        final paddingX =
            (constraints.maxWidth -
                (itemsPerRow * cardWidth + (itemsPerRow - 1) * spacing)) /
            2;

        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.only(
            left: paddingX,
            right: paddingX,
            top: 16,
            bottom: 30,
          ),
          itemCount: (_records.length / itemsPerRow).ceil(),
          itemBuilder: (context, rowIndex) {
            final int startIndex = rowIndex * itemsPerRow;
            int endIndex = startIndex + itemsPerRow;
            if (endIndex > _records.length) endIndex = _records.length;

            final rowItems = _records.sublist(startIndex, endIndex);
            final bool isLeftToRight = rowIndex % 2 == 0;

            final List<Widget> children = [];

            for (int i = 0; i < rowItems.length; i++) {
              final record = rowItems[i];
              final actualIndex = startIndex + i;
              final isLatest = actualIndex == 0;

              DateTime? nextRecordTime;
              if (actualIndex > 0) {
                nextRecordTime = _records[actualIndex - 1].createdAt;
              }

              final durationStr = _formatDuration(
                record.createdAt,
                nextRecordTime,
              );

              children.add(
                SizedBox(
                  width: cardWidth,
                  child: ServerHistoryCard(
                    isLatest: isLatest,
                    mapUrl: _getMapBackgroundUrl(record),
                    mapName: record.mapName,
                    translatedMapName: _getTranslatedMapName(record),
                    serverName: _getServerName(record.address),
                    hasTrendData: false,
                    trendDataCount: 0,
                    mapPlayDuration: durationStr,
                    trendData: null,
                    maxPlayers: record.maxPlayers,
                    buildMapBackground: _buildMapBackground,
                    buildStatChip: _buildStatChip,
                    finalCtScore: record.finalCtScore,
                    finalTScore: record.finalTScore,
                    timeHeader: _buildTimeHeader(record, actualIndex, isLatest),
                  ),
                ),
              );

              // Add horizontal line between items in the same row
              if (i < rowItems.length - 1) {
                children.add(
                  SizedBox(
                    width: spacing,
                    height: 4,
                    child: Center(
                      child: FlowingLine(
                        direction: Axis.horizontal,
                        reverse: !isLeftToRight,
                        color: AppColors.primary,
                        thickness: 6,
                      ),
                    ),
                  ),
                );
              }
            }

            // Re-reverse back if it was right-to-left so Flutter draws them in correct visual order
            final List<Widget> renderedChildren = isLeftToRight
                ? children
                : children.reversed.toList();

            final isLastRow =
                rowIndex == (_records.length / itemsPerRow).ceil() - 1;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: isLeftToRight
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.end,
                  children: renderedChildren,
                ),
                // Draw vertical line connecting to the next row
                if (!isLastRow && rowItems.length == itemsPerRow)
                  Align(
                    alignment: isLeftToRight
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            (cardWidth / 2) - 12, // offset for 24px width
                      ),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: FlowingLine(
                            direction: Axis.vertical,
                            reverse: false, // always downward
                            color: AppColors.primary,
                            thickness: 6,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class FlowingLine extends StatefulWidget {
  final Axis direction;
  final bool reverse;
  final Color color;
  final double thickness;

  const FlowingLine({
    super.key,
    required this.direction,
    required this.reverse,
    required this.color,
    this.thickness = 6,
  });

  @override
  State<FlowingLine> createState() => _FlowingLineState();
}

class _FlowingLineState extends State<FlowingLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = widget.reverse
            ? 1.0 - _controller.value
            : _controller.value;

        return ClipRect(
          child: CustomPaint(
            size: widget.direction == Axis.horizontal
                ? Size(double.infinity, widget.thickness)
                : Size(widget.thickness, double.infinity),
            painter: _FlowPainter(
              direction: widget.direction,
              progress: value,
              color: widget.color,
              thickness: widget.thickness,
            ),
          ),
        );
      },
    );
  }
}

class _FlowPainter extends CustomPainter {
  final Axis direction;
  final double progress; // 0.0 to 1.0
  final Color color;
  final double thickness;

  _FlowPainter({
    required this.direction,
    required this.progress,
    required this.color,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    // Draw background line
    if (direction == Axis.horizontal) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        paint,
      );
    }

    // Draw moving bright segment
    final highlightPaint = Paint()
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    final length = direction == Axis.horizontal ? size.width : size.height;
    final highlightLength = 40.0; // Fixed length for the glowing pulse
    final startPos =
        -highlightLength + progress * (length + highlightLength * 2);

    if (direction == Axis.horizontal) {
      highlightPaint.shader =
          LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              color.withValues(alpha: 0.0),
              color,
              color.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromLTRB(startPos, 0, startPos + highlightLength, size.height),
          );

      canvas.drawLine(
        Offset(startPos, size.height / 2),
        Offset(startPos + highlightLength, size.height / 2),
        highlightPaint,
      );
    } else {
      highlightPaint.shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.0),
              color,
              color.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromLTRB(0, startPos, size.width, startPos + highlightLength),
          );

      canvas.drawLine(
        Offset(size.width / 2, startPos),
        Offset(size.width / 2, startPos + highlightLength),
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlowPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
