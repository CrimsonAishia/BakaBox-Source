import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/models/server_models.dart';
import '../../../core/utils/time_utils.dart';

/// 玩家趋势图表组件
/// 显示服务器玩家数量随时间变化的折线图
class PlayerTrendChart extends StatefulWidget {
  /// 玩家趋势数据
  final List<PlayerTrendInfo> infos;

  /// 服务器最大玩家数
  final int maxPlayers;

  /// 图表宽度
  final double width;

  /// 图表高度
  final double height;

  const PlayerTrendChart({
    super.key,
    required this.infos,
    required this.maxPlayers,
    this.width = 320,
    this.height = 200,
  });

  @override
  State<PlayerTrendChart> createState() => _PlayerTrendChartState();
}

class _PlayerTrendChartState extends State<PlayerTrendChart> {
  int? _touchedIndex;

  // 缓存处理后的数据，避免每次 build 都重新计算
  List<PlayerTrendInfo>? _sortedData;
  bool? _isMultiDay;
  double? _yAxisMax;
  
  // 用于检测数据是否变化
  List<PlayerTrendInfo>? _lastInfos;
  int? _lastMaxPlayers;

  @override
  void initState() {
    super.initState();
    _processData();
  }

  @override
  void didUpdateWidget(PlayerTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有数据真正变化时才重新处理
    if (!identical(oldWidget.infos, widget.infos) ||
        oldWidget.maxPlayers != widget.maxPlayers) {
      _processData();
    }
  }
  
  @override
  void dispose() {
    // 清理缓存数据，帮助 GC 回收
    _sortedData = null;
    _lastInfos = null;
    _touchedIndex = null;
    super.dispose();
  }

  void _processData() {
    // 如果数据没变，不重新处理
    if (identical(widget.infos, _lastInfos) && widget.maxPlayers == _lastMaxPlayers) {
      return;
    }
    
    _lastInfos = widget.infos;
    _lastMaxPlayers = widget.maxPlayers;
    
    // 按时间排序
    _sortedData = List<PlayerTrendInfo>.from(widget.infos)
      ..sort((a, b) {
        final dateA = TimeUtils.parseServerTime(a.createdAt);
        final dateB = TimeUtils.parseServerTime(b.createdAt);
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });
    _isMultiDay = _isMultiDayCheck(_sortedData!);
    final maxPlayerCount = _sortedData!.isEmpty
        ? 0
        : _sortedData!
            .map((e) => e.playerCount)
            .reduce((a, b) => a > b ? a : b);
    _yAxisMax = _calculateYAxisMax(maxPlayerCount);
  }

  /// 格式化时间标签
  String _formatTimeLabel(String dateStr, bool showDate) {
    final date = TimeUtils.parseServerTime(dateStr);
    if (date == null) return '';

    if (showDate) {
      return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化完整时间（用于tooltip）
  String _formatFullTime(String dateStr) {
    final date = TimeUtils.parseServerTime(dateStr);
    if (date == null) return dateStr;
    return '${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 判断是否跨天
  bool _isMultiDayCheck(List<PlayerTrendInfo> data) {
    if (data.length < 2) return false;
    final first = TimeUtils.parseServerTime(data.first.createdAt);
    final last = TimeUtils.parseServerTime(data.last.createdAt);
    if (first == null || last == null) return false;
    return last.difference(first).inHours > 24;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.infos.isEmpty || _sortedData == null) {
      return _buildEmptyState();
    }

    final data = _sortedData!;
    final isMultiDay = _isMultiDay ?? false;
    final yAxisMax = _yAxisMax ?? 10.0;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yAxisMax / 4,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFF1F5F9),
                strokeWidth: 1,
              ),
            ),
            titlesData: _buildTitlesData(data, isMultiDay, yAxisMax),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: (data.length - 1).toDouble(),
            minY: 0,
            maxY: yAxisMax,
            lineTouchData: _buildLineTouchData(data),
            lineBarsData: [
              _buildLineChartBarData(data),
            ],
          ),
        ),
      ),
    );
  }

  /// 计算Y轴最大值
  double _calculateYAxisMax(int maxPlayerCount) {
    final yAxisMax =
        widget.maxPlayers > maxPlayerCount ? widget.maxPlayers : maxPlayerCount;
    if (yAxisMax >= 58) {
      return 70;
    }
    return (yAxisMax * 1.1).ceilToDouble().clamp(10, 70);
  }

  /// 构建坐标轴标题数据
  FlTitlesData _buildTitlesData(
      List<PlayerTrendInfo> data, bool isMultiDay, double yAxisMax) {
    final labelInterval = data.length > 10 ? (data.length / 5).ceil() : 1;

    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= data.length) {
              return const SizedBox.shrink();
            }

            // 只显示部分标签
            if (data.length > 10) {
              final shouldShow = index == 0 ||
                  index == data.length - 1 ||
                  index % labelInterval == 0;
              if (!shouldShow) return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Transform.rotate(
                angle: -0.5, // 约 -30 度
                child: Text(
                  _formatTimeLabel(data[index].createdAt, isMultiDay),
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 35,
          interval: yAxisMax / 4,
          getTitlesWidget: (value, meta) {
            return Text(
              '${value.toInt()}人',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            );
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  /// 构建触摸交互数据
  LineTouchData _buildLineTouchData(List<PlayerTrendInfo> data) {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (touchedSpot) =>
            Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF334155)
                : Colors.white,
        tooltipRoundedRadius: 8,
        tooltipPadding: const EdgeInsets.all(12),
        tooltipBorder: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.1)
              : const Color(0xFFE2E8F0),
        ),
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            final index = spot.x.toInt();
            if (index < 0 || index >= data.length) return null;

            final info = data[index];
            return LineTooltipItem(
              '${_formatFullTime(info.createdAt)}\n在线人数: ${info.playerCount}',
              TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF1E293B),
                fontWeight: FontWeight.w500,
              ),
            );
          }).toList();
        },
      ),
      touchCallback: (event, response) {
        setState(() {
          if (event is FlTapUpEvent ||
              event is FlPanEndEvent ||
              event is FlLongPressEnd) {
            _touchedIndex = null;
          } else if (response?.lineBarSpots != null &&
              response!.lineBarSpots!.isNotEmpty) {
            _touchedIndex = response.lineBarSpots!.first.x.toInt();
          }
        });
      },
      handleBuiltInTouches: true,
    );
  }

  /// 构建折线图数据
  LineChartBarData _buildLineChartBarData(List<PlayerTrendInfo> data) {
    return LineChartBarData(
      spots: data.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), entry.value.playerCount.toDouble());
      }).toList(),
      isCurved: true,
      curveSmoothness: 0.3,
      color: const Color(0xFF3B82F6),
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          final isHighlighted = _touchedIndex == index;
          return FlDotCirclePainter(
            radius: isHighlighted ? 6 : (data.length > 20 ? 2 : 3),
            color: const Color(0xFF3B82F6),
            strokeWidth: isHighlighted ? 3 : 2,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 32,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              '暂无趋势数据',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
