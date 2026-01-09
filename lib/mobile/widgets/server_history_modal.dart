import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../../core/core.dart';

class ServerHistoryModal extends StatefulWidget {
  final ExtendedServerItem server;

  const ServerHistoryModal({super.key, required this.server});

  static void show(BuildContext context, ExtendedServerItem server) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ServerHistoryModal(server: server),
    );
  }

  @override
  State<ServerHistoryModal> createState() => _ServerHistoryModalState();
}

class _ServerHistoryModalState extends State<ServerHistoryModal> with SingleTickerProviderStateMixin {
  List<ServerSnapshot> historyData = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  String? error;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  int currentPage = 1;
  final int pageSize = 10;
  bool hasMoreData = true;
  int totalRecords = 0;
  final Map<int, bool> _expandedCards = {};
  final Map<String, MapData> _mapInfoCache = {};
  final ServerApi _serverApi = ServerApi();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _scaleAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack);
    _animationController.forward();
    _loadHistoryData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!isLoadingMore && hasMoreData) _loadMoreData();
    }
  }

  Future<void> _loadHistoryData({bool refresh = false}) async {
    if (!refresh) {
      setState(() { isLoading = true; error = null; currentPage = 1; historyData.clear(); });
    }

    try {
      final String? address = widget.server.serverItem.address;
      if (address == null || address.isEmpty) throw Exception('服务器地址不能为空');

      final String searchTerm = _searchController.text.trim();
      final String? mapName = searchTerm.isNotEmpty ? searchTerm : null;

      final response = await _serverApi.getServerHistory(address: address, pageIndex: currentPage, pageSize: pageSize, mapName: mapName);
      if (response == null) {
        setState(() { historyData = []; totalRecords = 0; hasMoreData = false; isLoading = false; });
        return;
      }

      final newData = response.data;
      totalRecords = response.total;

      setState(() {
        historyData = refresh ? newData : newData;
        if (refresh) currentPage = 1;
        isLoading = false;
        hasMoreData = newData.length >= pageSize && historyData.length < totalRecords;
      });

      _preloadMapInfo(newData);
    } catch (e) {
      LogService.e('加载历史数据失败', e);
      setState(() {
        error = ErrorUtils.getErrorMessage(e, defaultMessage: '加载历史数据失败');
        isLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (isLoadingMore || !hasMoreData) return;
    setState(() => isLoadingMore = true);

    try {
      final String? address = widget.server.serverItem.address;
      if (address == null || address.isEmpty) throw Exception('服务器地址不能为空');

      final String searchTerm = _searchController.text.trim();
      final String? mapName = searchTerm.isNotEmpty ? searchTerm : null;
      final nextPage = currentPage + 1;

      final response = await _serverApi.getServerHistory(address: address, pageIndex: nextPage, pageSize: pageSize, mapName: mapName);
      if (response == null) {
        setState(() => isLoadingMore = false);
        return;
      }

      final moreData = response.data;
      setState(() {
        historyData.addAll(moreData);
        currentPage = nextPage;
        isLoadingMore = false;
        hasMoreData = moreData.length >= pageSize && historyData.length < totalRecords;
      });
      _preloadMapInfo(moreData);
    } catch (e) {
      LogService.e('加载更多历史数据失败', e);
      setState(() => isLoadingMore = false);
      if (mounted) ToastUtils.showError(context, ErrorUtils.getErrorMessage(e, defaultMessage: '加载更多数据失败'));
    }
  }

  Future<void> _preloadMapInfo(List<ServerSnapshot> snapshots) async {
    final uniqueMapNames = snapshots.map((s) => s.mapName).where((name) => name.isNotEmpty && !_mapInfoCache.containsKey(name)).toSet();
    for (final mapName in uniqueMapNames) {
      try {
        final mapInfo = await _serverApi.getMapInfo(mapName);
        if (mapInfo != null && mounted) setState(() => _mapInfoCache[mapName] = mapInfo);
      } catch (_) {}
    }
  }

  void _toggleCardExpansion(int index) => setState(() => _expandedCards[index] = !(_expandedCards[index] ?? false));
  void _performSearch() { setState(() { currentPage = 1; hasMoreData = true; }); _loadHistoryData(); }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: colorScheme.shadow.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(children: [_buildHeader(), _buildSearchBar(), Expanded(child: _buildContent())]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('服务器历史记录', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          const SizedBox(height: 3),
          Text(widget.server.serverData?.hostName ?? widget.server.serverItem.address ?? '未知服务器', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 8),
        IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close, color: colorScheme.onSurface)),
      ]),
    );
  }

  Widget _buildSearchBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(color: colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(12), border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3))),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '搜索地图名称...', hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_searchController.text.isNotEmpty) IconButton(onPressed: () { _searchController.clear(); _performSearch(); }, icon: const Icon(Icons.clear, size: 20)),
              IconButton(onPressed: _performSearch, icon: const Icon(Icons.search, size: 20)),
            ]),
            border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onSubmitted: (_) => _performSearch(),
          onChanged: (value) => setState(() {}),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final colorScheme = Theme.of(context).colorScheme;
    if (isLoading) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary)), const SizedBox(height: 16), Text('正在加载历史数据...', style: TextStyle(color: colorScheme.onSurfaceVariant))]));
    if (error != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.error_outline, size: 48, color: colorScheme.error), const SizedBox(height: 16), Text(error!, style: TextStyle(color: colorScheme.error, fontSize: 16), textAlign: TextAlign.center), const SizedBox(height: 16), ElevatedButton(onPressed: _loadHistoryData, style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), child: const Text('重试'))]));

    final filteredData = _searchController.text.isEmpty ? historyData : historyData.where((snapshot) { final searchTerm = _searchController.text.toLowerCase(); return snapshot.mapName.toLowerCase().contains(searchTerm) || snapshot.mapLabel.toLowerCase().contains(searchTerm); }).toList();
    if (filteredData.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 48, color: colorScheme.onSurfaceVariant), const SizedBox(height: 16), Text(totalRecords == 0 ? '暂无历史记录' : '未找到匹配的历史记录', style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant)), if (totalRecords == 0) ...[const SizedBox(height: 8), Text('服务器历史数据可能还未收集，请稍后再试', style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)))]]));

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredData.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= filteredData.length) return Padding(padding: const EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary))));
        return _buildHistoryCard(filteredData[index], index);
      },
    );
  }

  Widget _buildHistoryCard(ServerSnapshot snapshot, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasPlayerData = snapshot.infos?.isNotEmpty ?? false;
    final isExpanded = _expandedCards[index] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: index == 0 ? colorScheme.primary.withValues(alpha: 0.3) : colorScheme.outline.withValues(alpha: 0.2), width: index == 0 ? 2 : 1),
        boxShadow: [BoxShadow(color: colorScheme.shadow.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildCardHeader(snapshot, index),
        _buildMapInfoSection(snapshot),
        _buildStatsInfo(snapshot),
        if (hasPlayerData) _buildExpandButton(index, isExpanded),
        if (hasPlayerData && isExpanded) _buildPlayerTrendInfo(snapshot),
      ]),
    );
  }

  Widget _buildCardHeader(ServerSnapshot snapshot, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: index == 0 ? colorScheme.primary.withValues(alpha: 0.05) : colorScheme.surfaceContainer, borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))),
      child: Row(children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: index == 0 ? colorScheme.primary : colorScheme.onSurfaceVariant, shape: BoxShape.circle), child: Center(child: Text('#${index + 1}', style: TextStyle(color: colorScheme.onPrimary, fontSize: 11, fontWeight: FontWeight.bold)))),
        const SizedBox(width: 10),
        Expanded(child: Text(Formatters.formatDateTime(snapshot.createdAt), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: index == 0 ? colorScheme.primary : colorScheme.onSurface))),
        if (index == 0) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: colorScheme.secondary, borderRadius: BorderRadius.circular(10)), child: Text('最新', style: TextStyle(color: colorScheme.onPrimary, fontSize: 9, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget _buildMapInfoSection(ServerSnapshot snapshot) {
    final mapInfo = _mapInfoCache[snapshot.mapName];
    return SizedBox(
      height: 100,
      child: Stack(children: [
        Container(color: Colors.grey[300], child: mapInfo?.mapUrl != null ? Image.network(mapInfo!.mapUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => Container(color: Colors.grey[400], child: const Center(child: Icon(Icons.map, size: 40, color: Colors.white54)))) : Container(color: Colors.grey[400], child: const Center(child: Icon(Icons.map, size: 40, color: Colors.white54)))),
        Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54]))),
        Positioned(left: 12, bottom: 12, right: 12, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (mapInfo?.mapLabel != null && mapInfo!.mapLabel.isNotEmpty && mapInfo.mapLabel != snapshot.mapName) Text(mapInfo.mapLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 3)])),
          const SizedBox(height: 2),
          Text(snapshot.mapName, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500, shadows: [Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 3)])),
        ])),
      ]),
    );
  }

  Widget _buildStatsInfo(ServerSnapshot snapshot) {
    int maxHistoryPlayers = snapshot.currentPlayers;
    if (snapshot.infos != null && snapshot.infos!.isNotEmpty) maxHistoryPlayers = snapshot.infos!.map((e) => e.playerCount).reduce((a, b) => a > b ? a : b);
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(children: [_buildStatItem(Icons.trending_up, maxHistoryPlayers.toString(), '最高人数'), const SizedBox(width: 20), _buildStatItem(Icons.access_time, _getMapPlayDuration(snapshot), '运行时长')]));
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(child: Column(children: [Icon(icon, size: 16, color: colorScheme.onSurfaceVariant), const SizedBox(height: 4), Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurface)), Text(label, style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant))]));
  }

  Widget _buildExpandButton(int index, bool isExpanded) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _toggleCardExpansion(index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(isExpanded ? '收起趋势图' : '查看趋势图', style: TextStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.w500)), const SizedBox(width: 4), Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 14, color: colorScheme.primary)]),
      ),
    );
  }

  Widget _buildPlayerTrendInfo(ServerSnapshot snapshot) {
    final colorScheme = Theme.of(context).colorScheme;
    final playerInfos = snapshot.infos!;
    final maxCount = playerInfos.map((e) => e.playerCount).reduce((a, b) => a > b ? a : b);
    final minCount = playerInfos.map((e) => e.playerCount).reduce((a, b) => a < b ? a : b);
    final avgCount = (playerInfos.map((e) => e.playerCount).reduce((a, b) => a + b) / playerInfos.length).round();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colorScheme.surfaceContainer, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.trending_up, size: 15, color: colorScheme.primary), const SizedBox(width: 5), Text('玩家数量趋势', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface)), const Spacer(), Text('${playerInfos.length}个数据点', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant))]),
        const SizedBox(height: 10),
        Container(height: 160, decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2))), child: _TrendChartWidget(playerInfos: playerInfos, maxCount: maxCount)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_buildTrendStat('最高', maxCount.toString(), Colors.red), _buildTrendStat('平均', avgCount.toString(), Colors.blue), _buildTrendStat('最低', minCount.toString(), Colors.green)]),
      ]),
    );
  }

  Widget _buildTrendStat(String label, String value, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(children: [Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)), Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant))]);
  }

  String _getMapPlayDuration(ServerSnapshot snapshot) {
    if (snapshot.infos == null || snapshot.infos!.isEmpty) return '无数据';
    if (snapshot.infos!.length == 1) return '< 1分钟';
    final sortedInfos = [...snapshot.infos!]..sort((a, b) {
      final dateA = TimeUtils.parseServerTime(a.createdAt);
      final dateB = TimeUtils.parseServerTime(b.createdAt);
      if (dateA == null || dateB == null) return 0;
      return dateA.compareTo(dateB);
    });
    final firstDate = TimeUtils.parseServerTime(sortedInfos.first.createdAt);
    final lastDate = TimeUtils.parseServerTime(sortedInfos.last.createdAt);
    if (firstDate == null || lastDate == null) return '无数据';
    final duration = lastDate.difference(firstDate);
    if (duration.inMinutes < 60) return '${duration.inMinutes}分钟';
    if (duration.inHours < 24) return '${duration.inHours}小时${duration.inMinutes % 60}分钟';
    return '${duration.inDays}天${duration.inHours % 24}小时';
  }
}

class _TrendChartWidget extends StatefulWidget {
  final List<PlayerTrendInfo> playerInfos;
  final int maxCount;
  const _TrendChartWidget({required this.playerInfos, required this.maxCount});
  @override
  State<_TrendChartWidget> createState() => _TrendChartWidgetState();
}

class _TrendChartWidgetState extends State<_TrendChartWidget> {
  OverlayEntry? _overlayEntry;
  Timer? _autoRemoveTimer;
  
  // 移动端最大显示数据点数量，避免过于密集
  static const int _maxDisplayPoints = 20;
  
  // 对数据进行采样，减少显示点数
  List<PlayerTrendInfo> get _sampledData {
    if (widget.playerInfos.length <= _maxDisplayPoints) {
      return widget.playerInfos;
    }
    final step = widget.playerInfos.length / _maxDisplayPoints;
    final sampled = <PlayerTrendInfo>[];
    for (int i = 0; i < _maxDisplayPoints; i++) {
      final index = (i * step).floor().clamp(0, widget.playerInfos.length - 1);
      sampled.add(widget.playerInfos[index]);
    }
    // 确保最后一个点被包含
    if (sampled.last != widget.playerInfos.last) {
      sampled[sampled.length - 1] = widget.playerInfos.last;
    }
    return sampled;
  }

  String _formatTimeLabel(String dateTimeString) { try { final date = TimeUtils.parseServerTime(dateTimeString); return date != null ? DateFormat('HH:mm').format(date) : ''; } catch (_) { return ''; } }
  String _formatFullTime(String dateTimeString) { try { final date = TimeUtils.parseServerTime(dateTimeString); return date != null ? DateFormat('yyyy年MM月dd日 HH:mm:ss').format(date) : ''; } catch (_) { return ''; } }

  void _showDetail(BuildContext context, Offset globalPosition, PlayerTrendInfo playerInfo) {
    _removeOverlay();
    _overlayEntry = OverlayEntry(builder: (context) => Positioned(left: globalPosition.dx - 80, top: globalPosition.dy - 80, child: Material(color: Colors.transparent, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_formatFullTime(playerInfo.createdAt), style: const TextStyle(color: Colors.white, fontSize: 14)), const SizedBox(height: 4), Text('人数：${playerInfo.playerCount}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))])))));
    Overlay.of(context).insert(_overlayEntry!);
    _autoRemoveTimer = Timer(const Duration(seconds: 2), () => _removeOverlay());
  }

  void _removeOverlay() { _autoRemoveTimer?.cancel(); _overlayEntry?.remove(); _overlayEntry = null; }
  @override
  void dispose() { _autoRemoveTimer?.cancel(); _removeOverlay(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayData = _sampledData;
    
    return Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Expanded(child: Row(children: [
        SizedBox(width: 28, child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(widget.maxCount.toString(), style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant)), Text((widget.maxCount * 0.75).round().toString(), style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant)), Text((widget.maxCount * 0.5).round().toString(), style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant)), Text((widget.maxCount * 0.25).round().toString(), style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant)), Text('0', style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant))])),
        const SizedBox(width: 6),
        Expanded(child: GestureDetector(onTapDown: (details) { final RenderBox renderBox = context.findRenderObject() as RenderBox; final localPosition = renderBox.globalToLocal(details.globalPosition); final chartStartX = 12 + 28 + 6; final chartWidth = renderBox.size.width - chartStartX - 12; final chartStartY = 12; final chartHeight = renderBox.size.height - 12 - 6 - 18; if (localPosition.dx >= chartStartX && localPosition.dx <= chartStartX + chartWidth && localPosition.dy >= chartStartY && localPosition.dy <= chartStartY + chartHeight) { final relativeX = (localPosition.dx - chartStartX) / chartWidth; final dataIndex = (relativeX * (displayData.length - 1)).round().clamp(0, displayData.length - 1); _showDetail(context, details.globalPosition, displayData[dataIndex]); } }, child: CustomPaint(painter: _SimpleTrendPainter(displayData, widget.maxCount, colorScheme.primary, colorScheme.outlineVariant), child: Container()))),
      ])),
      const SizedBox(height: 6),
      if (displayData.isNotEmpty) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const SizedBox(width: 34), Text(_formatTimeLabel(displayData.first.createdAt), style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant)), if (displayData.length > 2) Text(_formatTimeLabel(displayData[displayData.length ~/ 2].createdAt), style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant)), Text(_formatTimeLabel(displayData.last.createdAt), style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant))]),
    ]));
  }
}

class _SimpleTrendPainter extends CustomPainter {
  final List<PlayerTrendInfo> data;
  final int maxValue;
  final Color primaryColor;
  final Color gridColor;
  _SimpleTrendPainter(this.data, this.maxValue, this.primaryColor, this.gridColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()..color = primaryColor..strokeWidth = 2..style = PaintingStyle.stroke;
    final fillPaint = Paint()..color = primaryColor.withValues(alpha: 0.1)..style = PaintingStyle.fill;
    final path = Path();
    final fillPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = data.length > 1 ? (i / (data.length - 1)) * size.width : size.width / 2;
      final ratio = maxValue > 0 ? (data[i].playerCount / maxValue).clamp(0.0, 1.0) : 0.0;
      final y = size.height - (ratio * size.height);
      if (x.isFinite && y.isFinite) {
        points.add(Offset(x, y));
        if (points.length == 1) { path.moveTo(x, y); fillPath.moveTo(x, size.height); fillPath.lineTo(x, y); } else { path.lineTo(x, y); fillPath.lineTo(x, y); }
      }
    }

    if (points.isNotEmpty) { fillPath.lineTo(points.last.dx, size.height); fillPath.close(); }
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    final pointPaint = Paint()..color = primaryColor..style = PaintingStyle.fill;
    for (final point in points) { canvas.drawCircle(point, 3, pointPaint); canvas.drawCircle(point, 3, Paint()..color = const Color(0xFFFFFFFF)..style = PaintingStyle.stroke..strokeWidth = 2); }

    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.5..style = PaintingStyle.stroke;
    for (int i = 1; i < 4; i++) { final y = size.height * (i / 4); canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint); }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
