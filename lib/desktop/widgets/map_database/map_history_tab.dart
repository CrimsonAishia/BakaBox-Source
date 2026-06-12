import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/api/server_api.dart';
import '../../../core/models/map_contribution_models.dart';
import '../../../core/models/server_models.dart';
import '../../../core/services/source_server_service.dart';
import '../../../core/utils/log_service.dart';
import '../player_trend/player_trend_chart.dart';
import '../../../core/constants/app_colors.dart';

/// 地图历史记录 Tab
/// 显示地图在各服务器的运行历史（极简列表式）
class MapHistoryTab extends StatefulWidget {
  final String mapName;

  const MapHistoryTab({super.key, required this.mapName});

  @override
  State<MapHistoryTab> createState() => _MapHistoryTabState();
}

class _MapHistoryTabState extends State<MapHistoryTab> {
  final ServerApi _serverApi = ServerApi();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  List<MapHistoryRecord> _historyData = [];
  int _totalRecords = 0;
  int _currentPage = 1;
  bool _hasMoreData = true;

  // 服务器名称缓存（IP -> 服务器名称）
  final Map<String, String> _serverNameCache = {};
  final Set<String> _loadingServers = {};

  static const int _pageSize = 20; // 增加每页数量，因为列表更紧凑

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();

    // 清理大列表和缓存，防止内存泄漏
    _historyData.clear();
    _serverNameCache.clear();
    _loadingServers.clear();

    super.dispose();
  }

  /// 获取历史记录
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

        final totalLoaded = _currentPage * _pageSize;
        _hasMoreData = totalLoaded < _totalRecords;

        // 异步加载服务器名称
        _loadServerNames();
      } else {
        if (!isLoadMore) {
          _historyData = [];
          _totalRecords = 0;
        }
        _hasMoreData = false;
      }
    } catch (e) {
      LogService.e('获取地图历史失败: $e', e);
      if (mounted) {
        _error = '获取历史数据失败';
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  /// 加载服务器名称
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
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// 静默加载服务器名称
  Future<void> _loadServerNameSilent(String address) async {
    try {
      final parts = address.split(':');
      if (parts.isEmpty) {
        _loadingServers.remove(address);
        return;
      }

      final host = parts[0];
      final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 27015 : 27015;

      final info = await SourceServerService.getServerInfo(
        host,
        port,
        timeout: 3000,
      );

      if (!mounted) {
        _loadingServers.remove(address);
        return;
      }

      if (info != null && info.name.isNotEmpty) {
        _serverNameCache[address] = info.name;
      }
    } catch (e) {
      LogService.w('获取服务器 $address 名称失败: $e');
    } finally {
      if (mounted) {
        _loadingServers.remove(address);
      }
    }
  }

  /// 获取服务器显示名称
  String _getServerDisplayName(String address) {
    return _serverNameCache[address] ?? address;
  }

  /// 格式化时间（简短格式）
  String _formatShortTime(DateTime dateTime) {
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diffDays = nowDate.difference(date).inDays;

    if (diffDays == 0) {
      // 今天：显示时间
      return '今天 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (diffDays == 1) {
      // 昨天
      return '昨天 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (dateTime.year == now.year) {
      // 今年：显示月-日 时间
      return '${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      // 其他年份：显示年-月-日 时间
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  /// 计算地图游玩时长
  String _getMapPlayDuration(MapHistoryRecord record) {
    final infos = record.infos;
    if (infos.isEmpty) return '无数据';
    if (infos.length == 1) return '<1分钟';

    final sortedInfos = List<MapHistoryPlayerInfo>.from(infos)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final earliest = sortedInfos.first.createdAt;
    final latest = sortedInfos.last.createdAt;
    final diff = latest.difference(earliest);

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// 获取最大玩家数
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppColors.primary : theme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '正在加载历史数据...',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(MdiIcons.alertCircle, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchHistory(),
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

    return Column(
      children: [
        // 统计信息
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                MdiIcons.formatListBulleted,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '${_historyData.length}/$_totalRecords 条记录',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.black.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        // 历史列表
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            itemCount:
                _historyData.length + (_hasMoreData || _isLoadingMore ? 1 : 1),
            itemBuilder: (context, index) {
              if (index < _historyData.length) {
                return _buildHistoryItem(_historyData[index], index, isDark);
              }

              if (_isLoadingMore) {
                return _buildLoadingMore(isDark);
              } else if (_hasMoreData) {
                return _buildLoadMoreButton(isDark);
              } else {
                return _buildNoMoreData(isDark);
              }
            },
          ),
        ),
        // 底部提示
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                MdiIcons.informationOutline,
                size: 14,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 6),
              Text(
                '点击记录查看玩家趋势图',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(MapHistoryRecord record, int index, bool isDark) {
    final isLatest = index == 0;
    final serverName = _getServerDisplayName(record.address);
    final hasTrendData = record.infos.isNotEmpty;
    final maxPlayers = _getMaxPlayers(record);

    return _HistoryListItem(
      key: ValueKey('map_history_${record.id}'),
      isLatest: isLatest,
      time: _formatShortTime(record.createdAt),
      serverName: serverName,
      serverAddress: record.address,
      duration: _getMapPlayDuration(record),
      dataPoints: record.infos.length,
      maxPlayers: maxPlayers,
      totalSlots: record.maxPlayers,
      hasTrendData: hasTrendData,
      getTrendData: hasTrendData ? () => record.infos : null,
      isDark: isDark,
      finalCtScore: record.finalCtScore,
      finalTScore: record.finalTScore,
      mapName: widget.mapName,
    );
  }

  Widget _buildLoadingMore(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? AppColors.primary : Colors.blue,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '正在加载更多...',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: TextButton.icon(
          onPressed: () => _fetchHistory(isLoadMore: true),
          icon: Icon(MdiIcons.chevronDown, size: 18),
          label: const Text('加载更多历史记录'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildNoMoreData(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          '已加载全部 $_totalRecords 条历史记录',
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// 历史列表项组件（极简式 - 可展开）
class _HistoryListItem extends StatefulWidget {
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

  const _HistoryListItem({
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
  State<_HistoryListItem> createState() => _HistoryListItemState();
}

class _HistoryListItemState extends State<_HistoryListItem>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isHovered = false;
  List<PlayerTrendInfo>? _trendData; // 懒加载的趋势数据
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();

    // 清理趋势数据，释放内存
    _trendData?.clear();
    _trendData = null;

    super.dispose();
  }

  void _toggleExpand() {
    if (!widget.hasTrendData) return;

    setState(() {
      _isExpanded = !_isExpanded;

      // 懒加载趋势数据
      if (_isExpanded && _trendData == null && widget.getTrendData != null) {
        final data = widget.getTrendData!();
        _trendData = data
            .map(
              (info) => PlayerTrendInfo(
                playerCount: info.playerCount,
                createdAt: info.createdAt.toIso8601String(),
              ),
            )
            .toList();
      }
    });

    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _isHovered
              ? (widget.isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.02))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isExpanded
                ? AppColors.primary.withValues(alpha: 0.5)
                : (_isHovered
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : (widget.isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05))),
          ),
        ),
        child: Column(
          children: [
            // 主要信息（可点击）
            InkWell(
              onTap: widget.hasTrendData ? _toggleExpand : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 第一行：时间 + 服务器名称
                    Row(
                      children: [
                        Icon(
                          widget.isLatest
                              ? MdiIcons.fire
                              : MdiIcons.clockOutline,
                          size: 16,
                          color: widget.isLatest
                              ? AppColors.amber500
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
                                ? AppColors.amber500
                                : (widget.isDark
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : Colors.black.withValues(alpha: 0.7)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${widget.serverName} (${widget.serverAddress})',
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.isDark
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : Colors.black.withValues(alpha: 0.9),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 展开/收起图标
                        if (widget.hasTrendData)
                          AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              MdiIcons.chevronDown,
                              size: 20,
                              color: widget.isDark
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.black.withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 第二行：统计信息
                    Row(
                      children: [
                        const SizedBox(width: 22), // 对齐图标
                        _buildStatItem(MdiIcons.clockOutline, widget.duration),
                        const SizedBox(width: 16),
                        _buildStatItem(
                          MdiIcons.chartLine,
                          '${widget.dataPoints}点',
                        ),
                        const SizedBox(width: 16),
                        _buildStatItem(
                          MdiIcons.accountGroup,
                          '${widget.maxPlayers}/${widget.totalSlots}',
                        ),
                        if (widget.hasFinalScore) ...[
                          const SizedBox(width: 16),
                          _buildScoreBadge(
                            widget.finalCtScore!,
                            widget.finalTScore!,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 展开的趋势图区域
            SizeTransition(
              sizeFactor: _expandAnimation,
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
                        Icon(
                          MdiIcons.chartLine,
                          color: AppColors.amber400,
                          size: 16,
                        ),
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
                    const SizedBox(height: 12),
                    // 懒加载趋势图
                    if (_trendData != null)
                      ClipRect(
                        clipBehavior: Clip.none,
                        child: SizedBox(
                          height: 180,
                          child: PlayerTrendChart(
                            infos: _trendData!,
                            maxPlayers: widget.totalSlots,
                            width: double.infinity,
                            height: 180,
                          ),
                        ),
                      )
                    else
                      const SizedBox(
                        height: 180,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.black.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreBadge(int ctScore, int tScore) {
    // 判断是否为僵尸模式地图
    final isZombieMap =
        widget.mapName.startsWith('ze_') || widget.mapName.startsWith('zm_');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$ctScore',
            style: TextStyle(
              color: isZombieMap
                  ? AppColors.green500
                  : AppColors.blue500, // 人类绿色 / CT蓝色
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              ':',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$tScore',
            style: TextStyle(
              color: isZombieMap
                  ? AppColors.red500
                  : AppColors.amber500, // 僵尸红色 / T黄色
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
