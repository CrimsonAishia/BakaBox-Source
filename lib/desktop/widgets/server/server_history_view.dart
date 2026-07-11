import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../core/models/server_models.dart';
import '../../../core/api/server_api.dart';
import '../../../core/utils/map_utils.dart';
import '../../../core/utils/log_service.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/widgets/map_background.dart';
import '../../../core/widgets/dashed_line.dart';
import '../../../core/constants/app_colors.dart';
import 'server_history_card.dart';

/// 服务器历史记录组件 (作为 Tab 内容)
class ServerHistoryDialog extends StatefulWidget {
  final ExtendedServerItem server;

  const ServerHistoryDialog({super.key, required this.server});

  @override
  State<ServerHistoryDialog> createState() => _ServerHistoryDialogState();
}

class _ServerHistoryDialogState extends State<ServerHistoryDialog> {
  final ServerApi _serverApi = ServerApi();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // 搜索防抖定时器
  Timer? _searchDebounceTimer;

  // 状态
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  List<ServerSnapshot> _historyData = [];
  int _totalRecords = 0;
  int _currentPage = 1;
  bool _hasMoreData = true;
  String _searchQuery = '';

  // 地图信息缓存
  final Map<String, MapData> _mapInfoCache = {};
  final Set<String> _loadingMaps = {};

  // 滚动指示器状态
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  // 分页配置
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicators);
    _fetchServerHistory();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollIndicators);
    _searchDebounceTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _mapInfoCache.clear();
    _loadingMaps.clear();
    _historyData.clear();
    super.dispose();
  }

  void _updateScrollIndicators() {
    if (!mounted || !_scrollController.hasClients) return;
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

  /// 获取服务器历史数据
  Future<void> _fetchServerHistory({
    bool isLoadMore = false,
    bool resetData = true,
  }) async {
    if (!mounted) return;

    // 所有自定义服务器（包括三方导入和手动添加），直接不请求数据，显示无记录
    if (widget.server.serverItem.isCustom) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _historyData = [];
        _totalRecords = 0;
        _hasMoreData = false;
        _error = null;
      });
      return;
    }

    final address = widget.server.serverItem.address ?? widget.server.serverItem.serverAddress;
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

        final totalLoaded = _currentPage * _pageSize;
        _hasMoreData = totalLoaded < _totalRecords;

        _loadMapInfosForCurrentData();
      } else {
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

  void _handleSearch() {
    final query = _searchController.text.trim().toLowerCase();
    if (query != _searchQuery) {
      _searchQuery = query;
      _fetchServerHistory(resetData: true);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    if (_searchQuery.isNotEmpty) {
      _searchQuery = '';
      _fetchServerHistory(resetData: true);
    } else {
      setState(() {});
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    setState(() {});
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _handleSearch();
    });
  }

  void _loadMore() {
    if (!_isLoadingMore && _hasMoreData) {
      _fetchServerHistory(isLoadMore: true);
    }
  }

  String? _getTranslatedMapName(ServerSnapshot snapshot) {
    final mapInfo = _mapInfoCache[snapshot.mapName];
    final mapLabel = mapInfo?.mapLabel;
    return (mapLabel?.isNotEmpty == true) ? mapLabel : null;
  }

  String? _getMapBackgroundUrl(ServerSnapshot snapshot) {
    final mapInfo = _mapInfoCache[snapshot.mapName];
    return MapUtils.getMapImageUrl(snapshot.mapName, mapUrl: mapInfo?.mapUrl);
  }

  String _formatDateTime(String dateStr) {
    return TimeUtils.formatWithWeekday(dateStr);
  }

  String _getMapPlayDuration(ServerSnapshot snapshot) {
    final infos = snapshot.infos;
    if (infos == null || infos.isEmpty) return '无数据';
    if (infos.length == 1) return '< 1分钟';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        _buildSearchBar(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: DashedLine(color: isDark ? Colors.white24 : Colors.black12),
        ),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.gray800;
    final hintColor = isDark ? Colors.white38 : AppColors.gray400;
    final inputBgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      margin: const EdgeInsets.only(bottom: 5),
      child: Column(
        children: [
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(MdiIcons.calendarClock, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                '已加载 ${_historyData.length} / $_totalRecords 条',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : AppColors.gray500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '搜索地图名称...',
                      hintStyle: TextStyle(color: hintColor),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: hintColor,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: 18,
                                color: hintColor,
                              ),
                              onPressed: _clearSearch,
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      filled: true,
                      fillColor: inputBgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _handleSearch(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _handleSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 0,
                  ),
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '搜索',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            SizedBox(height: 16),
            Text('正在加载历史数据...', style: TextStyle(color: AppColors.gray500)),
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
            Text(_error!, style: const TextStyle(color: AppColors.gray500)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchServerHistory(resetData: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
              style: const TextStyle(color: AppColors.gray500),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _clearSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('清空搜索条件'),
              ),
            ],
          ],
        ),
      );
    }

    return _buildZigZagTimeline();
  }

  Widget _buildZigZagTimeline() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollIndicators();
    });

    final int totalItems = _historyData.length;
    final int rowCount = (totalItems / 2).ceil();

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          itemCount: rowCount + 1, // +1 for loading/no-more indicator
          itemBuilder: (context, index) {
        if (index == rowCount) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: _isLoadingMore
                ? _buildLoadingMore()
                : (_hasMoreData ? _buildLoadMoreButton() : _buildNoMoreData()),
          );
        }

        final leftIndex = index * 2;
        final rightIndex = index * 2 + 1;
        final hasRight = rightIndex < totalItems;

        final leftSnapshot = _historyData[leftIndex];
        final rightSnapshot = hasRight ? _historyData[rightIndex] : null;

        // 错位布局的关键：右侧卡片整体向下偏移 64 像素，左侧卡片底部增加 64 像素间距
        return Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧列
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 64),
                    child: _buildTimelineItem(
                      leftSnapshot,
                      leftIndex,
                      isLatest: leftIndex == 0,
                    ),
                  ),
                ),
                const SizedBox(width: 96), // 中央轴宽度
                // 右侧列
                Expanded(
                  child: hasRight
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8, top: 64),
                          child: _buildTimelineItem(
                            rightSnapshot!,
                            rightIndex,
                            isLatest:
                                rightIndex == 0, // 右侧永远不可能是最新(index 0)，但以防万一
                          ),
                        )
                      : const SizedBox(),
                ),
              ],
            ),
            // 中央时间线轴（每行负责画出左右两张卡片的连接点）
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.center,
                child: _buildTimelineCenterAxisPaired(
                  leftIndex: leftIndex,
                  hasRight: hasRight,
                  isFirstRow: index == 0,
                  isLastRow: index == rowCount - 1,
                  hasMoreData: _hasMoreData,
                ),
              ),
            ),
          ],
        );
      },
        ),
        if (_canScrollUp)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildScrollIndicator(isTop: true),
          ),
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

  Widget _buildTimelineCenterAxisPaired({
    required int leftIndex,
    required bool hasRight,
    required bool isFirstRow,
    required bool isLastRow,
    required bool hasMoreData,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = isDark ? Colors.white24 : Colors.black12;

    // 左侧永远有节点
    final isLeftLatest = leftIndex == 0;
    // 右侧如果有节点，永远不可能是 index 0

    return SizedBox(
      width: 96,
      height: double.infinity,
      child: Stack(
        children: [
          // 贯穿上下的垂直线
          Positioned(
            top: isFirstRow ? 20 : 0, // 第一项从中心点开始往下
            bottom: isLastRow && !hasMoreData ? null : 0,
            // 如果是最后一行且没有更多数据，线只需画到最后一个节点即可
            height: isLastRow && !hasMoreData
                ? (hasRight ? 84 + 32.0 : 20 + 32.0)
                : null,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.center,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ),
          // 左侧节点 (对应 leftIndex)
          Positioned(
            top: 20, // 左侧卡片没有 top padding
            left: 0,
            right: 0,
            child: _buildTimelineNode(
              isLatest: isLeftLatest,
              isEven: true,
              lineColor: lineColor,
            ),
          ),
          // 右侧节点 (对应 rightIndex)
          if (hasRight)
            Positioned(
              top: 20 + 64, // 右侧卡片有 64 的 top padding，节点随之下移
              left: 0,
              right: 0,
              child: _buildTimelineNode(
                isLatest: false,
                isEven: false,
                lineColor: lineColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode({
    required bool isLatest,
    required bool isEven,
    required Color lineColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final connectorColor = isLatest ? AppColors.amber500 : lineColor;
    final dotColor = isLatest
        ? AppColors.amber500
        : (isDark ? Colors.white38 : Colors.black26);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 指向左侧卡片
        if (isEven) ...[
          Icon(Icons.arrow_left, color: connectorColor, size: 24),
          Container(width: 16, height: 2, color: connectorColor),
        ] else ...[
          const SizedBox(width: 40),
        ],

        // 中心点
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isLatest
                ? AppColors.amber500
                : (isDark ? AppColors.slate800 : Colors.white),
            shape: BoxShape.circle,
            border: Border.all(color: dotColor, width: isLatest ? 0 : 3),
            boxShadow: isLatest
                ? [
                    BoxShadow(
                      color: AppColors.amber500.withValues(alpha: 0.6),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),

        // 指向右侧卡片
        if (!isEven) ...[
          Container(width: 16, height: 2, color: connectorColor),
          Icon(Icons.arrow_right, color: connectorColor, size: 24),
        ] else ...[
          const SizedBox(width: 40),
        ],
      ],
    );
  }

  Widget _buildTimelineItem(
    ServerSnapshot snapshot,
    int index, {
    required bool isLatest,
  }) {
    final mapUrl = _getMapBackgroundUrl(snapshot);
    final hasTrendData = snapshot.infos != null && snapshot.infos!.isNotEmpty;
    final trendDataCount = snapshot.infos?.length ?? 0;

    return ServerHistoryCard(
      key: ValueKey('history_card_${snapshot.id}'),
      isLatest: isLatest,
      mapUrl: mapUrl,
      mapName: snapshot.mapName,
      hasTrendData: hasTrendData,
      trendDataCount: trendDataCount,
      translatedMapName: _getTranslatedMapName(snapshot),
      mapPlayDuration: _getMapPlayDuration(snapshot),
      trendData: hasTrendData ? snapshot.infos! : null,
      maxPlayers: snapshot.maxPlayers,
      buildMapBackground: _buildMapBackground,
      buildStatChip: _buildStatChip,
      finalCtScore: snapshot.finalCtScore,
      finalTScore: snapshot.finalTScore,
      timeHeader: _buildTimeHeader(snapshot, index, isLatest),
    );
  }

  Widget _buildTimeHeader(ServerSnapshot snapshot, int index, bool isLatest) {
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
                _formatDateTime(snapshot.createdAt),
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

  Widget _buildMapBackground(String? mapUrl, String mapName) {
    return MapBackground(
      mapName: mapName,
      imageUrl: mapUrl,
      cacheWidth: 560, // 280 * 2
      cacheHeight: 240, // 120 * 2
    );
  }

  Widget _buildStatChip(IconData icon, String text, {Color? color}) {
    final chipColor = color ?? Colors.white70;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: chipColor),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: chipColor, fontSize: 12)),
      ],
    );
  }

  Widget _buildLoadingMore() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: const Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            SizedBox(height: 12),
            Text(
              '正在加载更多数据...',
              style: TextStyle(color: AppColors.gray500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: _loadMore,
          icon: Icon(MdiIcons.chevronDown, size: 18),
          label: const Text('加载更多历史记录'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildNoMoreData() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(MdiIcons.library, size: 20, color: AppColors.gray500),
            const SizedBox(width: 8),
            Text(
              '已加载全部 $_totalRecords 条历史记录',
              style: const TextStyle(color: AppColors.gray500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollIndicator({required bool isTop}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final iconColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3);
    
    return IgnorePointer(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              bgColor,
              bgColor.withValues(alpha: 0.8),
              bgColor.withValues(alpha: 0),
            ],
          ),
        ),
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(top: isTop ? 4 : 0, bottom: isTop ? 0 : 4),
          child: Icon(
            isTop ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            color: iconColor,
            size: 24,
          ),
        ),
      ),
    );
  }
}
