import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/api/server_api.dart';
import '../../../core/models/map_contribution_models.dart';
import '../../../core/models/server_models.dart';
import '../../../core/services/source_server_service.dart';
import '../../../core/utils/log_service.dart';
import '../../../desktop/widgets/player_trend/player_trend_chart.dart';

/// 移动端地图运行历史底部弹出面板
class MapHistorySheetMobile extends StatelessWidget {
  final String mapName;
  final String mapLabel;

  const MapHistorySheetMobile({
    super.key,
    required this.mapName,
    required this.mapLabel,
  });

  static Future<void> show(
    BuildContext context, {
    required String mapName,
    required String mapLabel,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MapHistorySheetMobile(
        mapName: mapName,
        mapLabel: mapLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖拽指示条
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 头部
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              children: [
                Icon(MdiIcons.history,
                    color: const Color(0xFF0080FF), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '运行历史',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        '$mapLabel  ·  $mapName',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.black.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 内容
          Expanded(
            child: MapHistoryContentMobile(
              mapName: mapName,
              mapLabel: mapLabel,
            ),
          ),
        ],
      ),
    );
  }
}

/// 地图历史内容组件（可单独嵌入其他页面）
class MapHistoryContentMobile extends StatefulWidget {
  final String mapName;
  final String mapLabel;

  const MapHistoryContentMobile({
    super.key,
    required this.mapName,
    required this.mapLabel,
  });

  @override
  State<MapHistoryContentMobile> createState() =>
      _MapHistoryContentMobileState();
}

class _MapHistoryContentMobileState extends State<MapHistoryContentMobile> {
  final ServerApi _serverApi = ServerApi();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  List<MapHistoryRecord> _historyData = [];
  int _totalRecords = 0;
  int _currentPage = 1;
  bool _hasMoreData = true;

  final Map<String, String> _serverNameCache = {};
  final Set<String> _loadingServers = {};

  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _historyData.clear();
    _serverNameCache.clear();
    _loadingServers.clear();
    super.dispose();
  }

  Future<void> _fetchHistory({bool isLoadMore = false}) async {
    if (!mounted) return;

    if (isLoadMore) {
      if (_isLoadingMore || !_hasMoreData) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
        _historyData = [];
        _currentPage = 1;
        _totalRecords = 0;
        _hasMoreData = true;
      });
    }

    try {
      final page = isLoadMore ? _currentPage + 1 : 1;
      final request = MapHistoryRequest(
        mapName: widget.mapName,
        pagination: PaginationParams(
          pageIndex: page,
          pageSize: _pageSize,
          orderBy: 'created_at desc',
        ),
      );

      final response = await _serverApi.getMapHistory(request);
      if (!mounted) return;

      if (response != null) {
        _totalRecords = response.total;
        final newData = response.data;
        if (isLoadMore) {
          _historyData.addAll(newData);
          _currentPage = page;
        } else {
          _historyData = newData;
          _currentPage = 1;
        }
        _hasMoreData = (_currentPage * _pageSize) < _totalRecords;
        _loadServerNames();
      } else {
        if (!isLoadMore) {
          _historyData = [];
          _totalRecords = 0;
        }
        _hasMoreData = false;
      }
    } catch (e) {
      LogService.e('获取地图历史失败', e);
      if (mounted) _error = '获取历史数据失败';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadServerNames() async {
    final addresses = _historyData
        .map((item) => item.address)
        .where((addr) => addr.isNotEmpty)
        .toSet();

    final futures = <Future>[];
    for (final address in addresses) {
      if (!_serverNameCache.containsKey(address) &&
          !_loadingServers.contains(address)) {
        _loadingServers.add(address);
        futures.add(_loadServerNameSilent(address));
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadServerNameSilent(String address) async {
    try {
      final parts = address.split(':');
      if (parts.isEmpty) return;
      final host = parts[0];
      final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 27015 : 27015;
      final info = await SourceServerService.getServerInfo(
        host,
        port,
        timeout: 3000,
      );
      if (mounted && info != null && info.name.isNotEmpty) {
        _serverNameCache[address] = info.name;
      }
    } catch (e) {
      LogService.w('获取服务器 $address 名称失败: $e');
    } finally {
      _loadingServers.remove(address);
    }
  }

  String _getServerDisplayName(String address) =>
      _serverNameCache[address] ?? address;

  String _formatShortTime(DateTime dt) {
    final now = DateTime.now();
    final diffDays = DateTime(now.year, now.month, now.day)
        .difference(DateTime(dt.year, dt.month, dt.day))
        .inDays;
    final hm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diffDays == 0) return '今天 $hm';
    if (diffDays == 1) return '昨天 $hm';
    if (dt.year == now.year) {
      return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $hm';
    }
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $hm';
  }

  String _getPlayDuration(MapHistoryRecord record) {
    final infos = record.infos;
    if (infos.isEmpty) return '无数据';
    if (infos.length == 1) return '<1分钟';
    final sorted = List<MapHistoryPlayerInfo>.from(infos)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final diff = sorted.last.createdAt.difference(sorted.first.createdAt);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return h > 0 ? '${h}h${m}m' : '${m}m';
  }

  int _getMaxPlayers(MapHistoryRecord record) {
    if (record.infos.isEmpty) return 0;
    return record.infos
        .map((e) => e.playerCount)
        .reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(MdiIcons.alertCircle, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchHistory,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_historyData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              MdiIcons.history,
              size: 64,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无历史记录',
              style: TextStyle(
                fontSize: 15,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _historyData.length + 1,
      itemBuilder: (context, index) {
        if (index < _historyData.length) {
          return _buildHistoryItem(_historyData[index], index, isDark);
        }
        if (_isLoadingMore) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (_hasMoreData) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: TextButton.icon(
                onPressed: () => _fetchHistory(isLoadMore: true),
                icon: Icon(MdiIcons.chevronDown, size: 18),
                label: const Text('加载更多'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0080FF),
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              '已加载全部 $_totalRecords 条记录',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryItem(MapHistoryRecord record, int index, bool isDark) {
    return _HistoryItemMobile(
      key: ValueKey('history_${record.id}'),
      isLatest: index == 0,
      time: _formatShortTime(record.createdAt),
      serverName: _getServerDisplayName(record.address),
      serverAddress: record.address,
      duration: _getPlayDuration(record),
      dataPoints: record.infos.length,
      maxPlayers: _getMaxPlayers(record),
      totalSlots: record.maxPlayers,
      hasTrendData: record.infos.isNotEmpty,
      getTrendData: record.infos.isNotEmpty ? () => record.infos : null,
      isDark: isDark,
      finalCtScore: record.finalCtScore,
      finalTScore: record.finalTScore,
      mapName: widget.mapName,
    );
  }
}

/// 历史记录列表项（可展开趋势图）
class _HistoryItemMobile extends StatefulWidget {
  final bool isLatest;
  final String time;
  final String serverName;
  final String serverAddress;
  final String duration;
  final int dataPoints;
  final int maxPlayers;
  final int totalSlots;
  final bool hasTrendData;
  final List<MapHistoryPlayerInfo> Function()? getTrendData;
  final bool isDark;
  final int? finalCtScore;
  final int? finalTScore;
  final String mapName;

  const _HistoryItemMobile({
    super.key,
    required this.isLatest,
    required this.time,
    required this.serverName,
    required this.serverAddress,
    required this.duration,
    required this.dataPoints,
    required this.maxPlayers,
    required this.totalSlots,
    required this.hasTrendData,
    required this.getTrendData,
    required this.isDark,
    this.finalCtScore,
    this.finalTScore,
    required this.mapName,
  });

  bool get hasFinalScore => finalCtScore != null && finalTScore != null;

  @override
  State<_HistoryItemMobile> createState() => _HistoryItemMobileState();
}

class _HistoryItemMobileState extends State<_HistoryItemMobile>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  List<PlayerTrendInfo>? _trendData;
  late AnimationController _animController;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _trendData?.clear();
    _trendData = null;
    super.dispose();
  }

  void _toggleExpand() {
    if (!widget.hasTrendData) return;
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded && _trendData == null && widget.getTrendData != null) {
        final data = widget.getTrendData!();
        _trendData = data
            .map((info) => PlayerTrendInfo(
                  playerCount: info.playerCount,
                  createdAt: info.createdAt.toIso8601String(),
                ))
            .toList();
      }
    });
    if (_isExpanded) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isExpanded
              ? const Color(0xFF0080FF).withValues(alpha: 0.4)
              : (widget.isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.07)),
        ),
        color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.hasTrendData ? _toggleExpand : null,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.isLatest
                            ? MdiIcons.fire
                            : MdiIcons.clockOutline,
                        size: 15,
                        color: widget.isLatest
                            ? const Color(0xFFF59E0B)
                            : (widget.isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.black.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.time,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.isLatest
                              ? const Color(0xFFF59E0B)
                              : (widget.isDark
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : Colors.black.withValues(alpha: 0.8)),
                        ),
                      ),
                      const Spacer(),
                      if (widget.hasTrendData)
                        AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            MdiIcons.chevronDown,
                            size: 18,
                            color: widget.isDark
                                ? Colors.white.withValues(alpha: 0.4)
                                : Colors.black.withValues(alpha: 0.4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.serverName} (${widget.serverAddress})',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStat(MdiIcons.clockOutline, widget.duration),
                      const SizedBox(width: 14),
                      _buildStat(MdiIcons.accountGroup,
                          '${widget.maxPlayers}/${widget.totalSlots}'),
                      const SizedBox(width: 14),
                      _buildStat(MdiIcons.chartLine, '${widget.dataPoints}点'),
                      if (widget.hasFinalScore) ...[
                        const SizedBox(width: 14),
                        _buildScoreBadge(
                            widget.finalCtScore!, widget.finalTScore!),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnim,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                    height: 1,
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(MdiIcons.chartLine,
                          color: const Color(0xFFFBBF24), size: 15),
                      const SizedBox(width: 6),
                      Text(
                        '玩家趋势',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.black.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_trendData != null)
                    SizedBox(
                      height: 160,
                      child: PlayerTrendChart(
                        infos: _trendData!,
                        maxPlayers: widget.totalSlots,
                        width: double.infinity,
                        height: 160,
                      ),
                    )
                  else
                    const SizedBox(
                      height: 160,
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.45)
              : Colors.black.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.55)
                : Colors.black.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreBadge(int ctScore, int tScore) {
    final isZombieMap =
        widget.mapName.startsWith('ze_') || widget.mapName.startsWith('zm_');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$ctScore',
            style: TextStyle(
              color: isZombieMap
                  ? const Color(0xFF22C55E)
                  : const Color(0xFF3B82F6),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 3),
            child: Text(':',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Text(
            '$tScore',
            style: TextStyle(
              color: isZombieMap
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFF59E0B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
