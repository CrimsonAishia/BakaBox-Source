import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../core/models/server_models.dart';
import '../../../core/api/server_api.dart';
import '../../../core/utils/map_utils.dart';
import '../../../core/utils/log_service.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/widgets/map_background.dart';
import '../player_trend/player_trend_chart.dart';

/// 服务器历史记录弹窗
/// 显示服务器地图变更历史时间线
class ServerHistoryDialog extends StatefulWidget {
  final ExtendedServerItem server;

  const ServerHistoryDialog({
    super.key,
    required this.server,
  });

  @override
  State<ServerHistoryDialog> createState() => _ServerHistoryDialogState();
}

class _ServerHistoryDialogState extends State<ServerHistoryDialog> {
  final ServerApi _serverApi = ServerApi();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // 状态
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  List<ServerSnapshot> _historyData = [];
  int _totalRecords = 0;
  int _currentPage = 1;
  bool _hasMoreData = true;
  String _searchQuery = '';

  // 滚动指示器状态
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  // 地图信息缓存
  final Map<String, MapData> _mapInfoCache = {};
  final Set<String> _loadingMaps = {};

  // 分页配置
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicators);
    _fetchServerHistory();
  }

  void _updateScrollIndicators() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canUp = position.pixels > 0;
    final canDown = position.pixels < position.maxScrollExtent;
    if (canUp != _canScrollUp || canDown != _canScrollDown) {
      setState(() {
        _canScrollUp = canUp;
        _canScrollDown = canDown;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 获取服务器历史数据
  Future<void> _fetchServerHistory({bool isLoadMore = false, bool resetData = true}) async {
    if (!mounted) return;

    final address = widget.server.serverItem.address;
    if (address == null || address.isEmpty) {
      setState(() {
        _error = '服务器地址无效';
        _isLoading = false;
      });
      return;
    }

    if (isLoadMore) {
      if (_isLoadingMore || !_hasMoreData) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
        if (resetData) {
          _historyData = [];
          _currentPage = 1;
          _totalRecords = 0;
          _hasMoreData = true;
        }
      });
    }

    try {
      final page = isLoadMore ? _currentPage + 1 : 1;
      final data = await _serverApi.getServerHistory(
        address: address,
        pageIndex: page,
        pageSize: _pageSize,
        mapName: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (!mounted) return;

      if (data != null) {
        _totalRecords = data.total;
        final newData = data.data;

        if (isLoadMore) {
          _historyData.addAll(newData);
          _currentPage = page;
        } else {
          _historyData = newData;
          _currentPage = 1;
        }

        // 检查是否还有更多数据
        final totalLoaded = _currentPage * _pageSize;
        _hasMoreData = totalLoaded < _totalRecords;

        // 异步加载地图信息
        _loadMapInfosForCurrentData();
      } else {
        // 无数据
        if (!isLoadMore) {
          _historyData = [];
          _totalRecords = 0;
        }
        _hasMoreData = false;
      }
    } catch (e) {
      LogService.e('获取服务器历史失败: $e', e);
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

  /// 加载地图信息
  Future<void> _loadMapInfosForCurrentData() async {
    final uniqueMapNames = _historyData
        .map((item) => item.mapName)
        .where((name) => name.isNotEmpty)
        .toSet();

    // 收集需要加载的地图
    final mapsToLoadInfo = <String>[];
    
    for (final mapName in uniqueMapNames) {
      if (!_mapInfoCache.containsKey(mapName) && !_loadingMaps.contains(mapName)) {
        mapsToLoadInfo.add(mapName);
        _loadingMaps.add(mapName);
      }
    }

    // 并行加载所有数据
    final futures = <Future>[];
    
    // 加载地图信息
    for (final mapName in mapsToLoadInfo) {
      futures.add(_loadMapInfoSilent(mapName));
    }
    
    // 等待所有加载完成后统一刷新
    if (futures.isNotEmpty) {
      await Future.wait(futures);
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// 静默加载地图信息（不触发 setState）
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

  /// 处理搜索
  void _handleSearch() {
    final query = _searchController.text.trim().toLowerCase();
    if (query != _searchQuery) {
      _searchQuery = query;
      _fetchServerHistory(resetData: true);
    }
  }

  /// 清空搜索
  void _clearSearch() {
    _searchController.clear();
    if (_searchQuery.isNotEmpty) {
      _searchQuery = '';
      _fetchServerHistory(resetData: true);
    }
  }

  /// 加载更多
  void _loadMore() {
    if (!_isLoadingMore && _hasMoreData) {
      _fetchServerHistory(isLoadMore: true);
    }
  }

  /// 获取格式化的地图名称
  String _getFormattedMapName(ServerSnapshot snapshot) {
    // 使用地图信息
    final mapInfo = _mapInfoCache[snapshot.mapName];
    if (mapInfo != null && mapInfo.mapLabel.isNotEmpty) {
      return '${snapshot.mapName}（${mapInfo.mapLabel}）';
    }
    return snapshot.mapName.isNotEmpty ? snapshot.mapName : '未知地图';
  }

  /// 获取地图背景URL
  String? _getMapBackgroundUrl(ServerSnapshot snapshot) {
    // 使用地图背景
    final mapInfo = _mapInfoCache[snapshot.mapName];
    return MapUtils.getMapImageUrl(snapshot.mapName, mapUrl: mapInfo?.mapUrl);
  }

  /// 格式化时间
  String _formatDateTime(String dateStr) {
    return TimeUtils.formatWithWeekday(dateStr);
  }

  /// 计算地图游玩时长
  String _getMapPlayDuration(ServerSnapshot snapshot) {
    final infos = snapshot.infos;
    if (infos == null || infos.isEmpty) {
      return '无数据';
    }

    if (infos.length == 1) {
      return '< 1分钟';
    }

    // 按时间排序
    final sortedInfos = List<PlayerTrendInfo>.from(infos)
      ..sort((a, b) {
        final dateA = TimeUtils.parseServerTime(a.createdAt);
        final dateB = TimeUtils.parseServerTime(b.createdAt);
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });

    final earliest = TimeUtils.parseServerTime(sortedInfos.first.createdAt);
    final latest = TimeUtils.parseServerTime(sortedInfos.last.createdAt);
    if (earliest == null || latest == null) return '无数据';
    
    final diff = latest.difference(earliest);
    return TimeUtils.formatDuration(diff);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        height: 600,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  /// 构建头部
  Widget _buildHeader(BuildContext context) {
    final serverInfo = widget.server.serverData;
    final hostName = serverInfo?.hostName ?? '未知服务器';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(MdiIcons.history, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '地图变更历史',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hostName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // 刷新按钮
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : () => _fetchServerHistory(resetData: true),
            tooltip: '刷新',
          ),
          // 关闭按钮
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(MdiIcons.calendarClock, color: const Color(0xFF0080FF), size: 18),
              const SizedBox(width: 8),
              Text(
                '已加载 ${_historyData.length} / $_totalRecords 条',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索地图名称...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: _clearSearch,
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _handleSearch(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _handleSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0080FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('搜索'),
              ),
            ],
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0080FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 14, color: const Color(0xFF0080FF)),
                  const SizedBox(width: 4),
                  Text(
                    '搜索"$_searchQuery"的结果',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0080FF)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_historyData.length} 条记录',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建内容区域
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0080FF)),
            ),
            SizedBox(height: 16),
            Text('正在加载历史数据...', style: TextStyle(color: Color(0xFF6B7280))),
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
            Text(_error!, style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchServerHistory(resetData: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0080FF),
                foregroundColor: Colors.white,
              ),
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
            Icon(MdiIcons.history, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? '未找到匹配的地图记录' : '暂无历史数据',
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _clearSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0080FF),
                  foregroundColor: Colors.white,
                ),
                child: const Text('清空搜索条件'),
              ),
            ],
          ],
        ),
      );
    }

    return _buildTimeline();
  }

  /// 构建时间线
  Widget _buildTimeline() {
    // 延迟检查滚动状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollIndicators();
    });

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          // 性能优化：禁用自动保持活跃，减少内存占用
          addAutomaticKeepAlives: false,
          // 性能优化：每个 item 自动添加 RepaintBoundary
          addRepaintBoundaries: true,
          itemCount:
              _historyData.length + (_hasMoreData || _isLoadingMore ? 1 : 1),
          itemBuilder: (context, index) {
            if (index < _historyData.length) {
              return _buildTimelineItem(_historyData[index], index);
            }

            // 底部加载更多或已加载全部
            if (_isLoadingMore) {
              return _buildLoadingMore();
            } else if (_hasMoreData) {
              return _buildLoadMoreButton();
            } else {
              return _buildNoMoreData();
            }
          },
        ),
        // 顶部滚动指示器
        if (_canScrollUp)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildScrollIndicator(isTop: true),
          ),
        // 底部滚动指示器
        if (_canScrollDown)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildScrollIndicator(isTop: false),
          ),
      ],
    );
  }

  /// 构建滚动指示器
  Widget _buildScrollIndicator({required bool isTop}) {
    return IgnorePointer(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              Theme.of(context).colorScheme.surface.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        padding: EdgeInsets.only(top: isTop ? 2 : 0, bottom: isTop ? 0 : 2),
        child: Icon(
          isTop ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: const Color(0xFF6B7280),
          size: 24,
        ),
      ),
    );
  }

  /// 构建时间线项
  Widget _buildTimelineItem(ServerSnapshot snapshot, int index) {
    final isLatest = index == 0;
    final mapUrl = _getMapBackgroundUrl(snapshot);
    final hasTrendData = snapshot.infos != null && snapshot.infos!.isNotEmpty;
    final trendDataCount = snapshot.infos?.length ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // 时间头部
          _buildTimeHeader(snapshot, index, isLatest),
          // 地图卡片（不传递 snapshot，只传递必要数据）
          _HistoryCard(
            key: ValueKey('history_card_${snapshot.id}'),
            isLatest: isLatest,
            mapUrl: mapUrl,
            mapName: snapshot.mapName,
            hasTrendData: hasTrendData,
            trendDataCount: trendDataCount,
            formattedMapName: _getFormattedMapName(snapshot),
            mapPlayDuration: _getMapPlayDuration(snapshot),
            // 懒加载趋势图数据
            getTrendData: hasTrendData ? () => snapshot.infos! : null,
            maxPlayers: snapshot.maxPlayers,
            buildMapBackground: _buildMapBackground,
            buildStatChip: _buildStatChip,
          ),
          // 连接线
          if (index < _historyData.length - 1)
            Container(
              width: 2,
              height: 16,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建时间头部
  Widget _buildTimeHeader(ServerSnapshot snapshot, int index, bool isLatest) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // 序号
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isLatest ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 时间
          Expanded(
            child: Row(
              children: [
                Icon(
                  isLatest ? MdiIcons.fire : MdiIcons.clockOutline,
                  size: 16,
                  color: isLatest ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDateTime(snapshot.createdAt),
                  style: TextStyle(
                    fontSize: 13,
                    color: isLatest ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                    fontWeight: isLatest ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          // 最新标识
          if (isLatest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '最新',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建地图背景
  Widget _buildMapBackground(String? mapUrl, String mapName) {
    return MapBackground(
      mapName: mapName,
      imageUrl: mapUrl,
    );
  }

  /// 构建统计标签
  Widget _buildStatChip(IconData icon, String text, {Color? color}) {
    final chipColor = color ?? Colors.white70;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: chipColor),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: chipColor, fontSize: 12),
        ),
      ],
    );
  }

  /// 构建加载更多中
  Widget _buildLoadingMore() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: const Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0080FF)),
            ),
            SizedBox(height: 12),
            Text(
              '正在加载更多数据...',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建加载更多按钮
  Widget _buildLoadMoreButton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: _loadMore,
          icon: Icon(MdiIcons.chevronDown, size: 18),
          label: const Text('加载更多历史记录'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0080FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
    );
  }

  /// 构建无更多数据提示
  Widget _buildNoMoreData() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(MdiIcons.library, size: 20, color: const Color(0xFF6B7280)),
            const SizedBox(width: 8),
            Text(
              '已加载全部 $_totalRecords 条历史记录',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// 历史卡片组件（优化版：懒加载趋势数据）
class _HistoryCard extends StatefulWidget {
  final bool isLatest;
  final String? mapUrl;
  final String mapName;
  final bool hasTrendData;
  final int trendDataCount;
  final String formattedMapName;
  final String mapPlayDuration;
  final List<PlayerTrendInfo> Function()? getTrendData;
  final int maxPlayers;
  final Widget Function(String?, String) buildMapBackground;
  final Widget Function(IconData, String, {Color? color}) buildStatChip;

  const _HistoryCard({
    super.key,
    required this.isLatest,
    required this.mapUrl,
    required this.mapName,
    required this.hasTrendData,
    required this.trendDataCount,
    required this.formattedMapName,
    required this.mapPlayDuration,
    required this.getTrendData,
    required this.maxPlayers,
    required this.buildMapBackground,
    required this.buildStatChip,
  });

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isCardHovered = false;
  bool _isOverlayHovered = false;
  // 延迟显示 overlay，避免快速滑过时频繁创建
  bool _overlayActivated = false;

  bool get _shouldShowOverlay => _isCardHovered || _isOverlayHovered;

  void _updateOverlay() {
    if (_shouldShowOverlay && widget.hasTrendData && _overlayActivated) {
      _showOverlay();
    } else if (!_shouldShowOverlay) {
      _hideOverlay();
      _overlayActivated = false;
    }
  }

  void _onHoverStart() {
    setState(() => _isCardHovered = true);
    // 延迟 200ms 后才显示 overlay，避免快速滑过
    if (!_overlayActivated) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && _isCardHovered && !_overlayActivated) {
          _overlayActivated = true;
          _updateOverlay();
        }
      });
    }
  }

  void _onHoverEnd() {
    setState(() => _isCardHovered = false);
    // 延迟检查，给鼠标移动到 overlay 的时间
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _updateOverlay();
    });
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    if (widget.getTrendData == null) return;

    // 懒加载趋势数据
    final trendData = widget.getTrendData!();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 340,
        child: CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: Alignment.centerRight,
          followerAnchor: Alignment.centerLeft,
          offset: const Offset(12, 0),
          child: MouseRegion(
            onEnter: (_) {
              _isOverlayHovered = true;
              _updateOverlay();
            },
            onExit: (_) {
              _isOverlayHovered = false;
              _updateOverlay();
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(MdiIcons.chartLine, color: const Color(0xFFFBBF24), size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          '玩家趋势',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 160,
                      child: PlayerTrendChart(
                        infos: trendData,
                        maxPlayers: widget.maxPlayers,
                        width: 316,
                        height: 160,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 预计算边框颜色
    final borderColor = _isCardHovered
        ? const Color(0xFF0080FF)
        : widget.isLatest
            ? const Color(0xFFF59E0B)
            : Colors.grey.withValues(alpha: 0.3);

    return RepaintBoundary(
      child: CompositedTransformTarget(
        link: _layerLink,
        child: MouseRegion(
          onEnter: (_) => _onHoverStart(),
          onExit: (_) => _onHoverEnd(),
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 地图背景
                  RepaintBoundary(
                    child: widget.buildMapBackground(widget.mapUrl, widget.mapName),
                  ),
                  // 渐变遮罩
                  const _GradientOverlay(),
                  // 地图信息
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
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            widget.buildStatChip(
                              MdiIcons.clockOutline,
                              widget.mapPlayDuration,
                            ),
                            const SizedBox(width: 12),
                            if (widget.hasTrendData)
                              widget.buildStatChip(
                                MdiIcons.chartLine,
                                '${widget.trendDataCount}个数据点',
                                color: const Color(0xFFFBBF24),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 右上角静态黄点
                  if (widget.hasTrendData)
                    const Positioned(
                      top: 12,
                      right: 12,
                      child: _StaticDot(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 静态渐变遮罩（const 优化）
class _GradientOverlay extends StatelessWidget {
  const _GradientOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
        ),
      ),
    );
  }
}

/// 静态黄点（替代动画版本，提升性能）
class _StaticDot extends StatelessWidget {
  const _StaticDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFBBF24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFBBF24).withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
