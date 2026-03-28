import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/web_server_list_models.dart';
import '../services/web_server_list_ws_adapter.dart';
import '../widgets/web_map_background.dart';
import '../widgets/web_mobile_server_list_item.dart';

/// Web 端服务器列表页面
class WebServerListPage extends StatefulWidget {
  final WebServerListData? initialData;

  const WebServerListPage({
    super.key,
    this.initialData,
  });

  @override
  State<WebServerListPage> createState() => _WebServerListPageState();
}

class _WebServerListPageState extends State<WebServerListPage> {
  static const int _kRefreshIntervalSeconds = 8;
  late Set<String> _selectedCategories;
  late WebServerListData _data;
  late final WebServerListWsAdapter _wsAdapter;
  StreamSubscription<WebServerListWsEvent>? _wsSubscription;
  bool _isCompactMode = false;
  bool _isConnected = false;
  bool _hasReceivedFirstSnapshot = false;
  String? _connectionMessage;
  Timer? _refreshProgressTimer;
  int _refreshCountdown = _kRefreshIntervalSeconds;

  /// 页面级地图背景缓存，key 为服务器 id，value 为缓存的地图背景 Widget
  /// 避免 ListView.builder 虚拟化销毁卡片后缓存丢失
  final Map<String, _CachedMapBg> _mapBackgroundCache = {};

  @override
  void initState() {
    super.initState();
    _data = widget.initialData ?? WebServerListData.empty();
    _hasReceivedFirstSnapshot = widget.initialData != null && widget.initialData!.categories.isNotEmpty;
    _selectedCategories = _data.categories.map((e) => e.name).toSet();
    _wsAdapter = WebServerListWsAdapter();
    _wsSubscription = _wsAdapter.events.listen(_handleWsEvent);
    _wsAdapter.connect();
    _startRefreshProgressTimer();
  }

  @override
  void didUpdateWidget(covariant WebServerListPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final incomingData = widget.initialData;
    if (incomingData != null && !identical(oldWidget.initialData, incomingData)) {
      _data = incomingData;
      _syncSelectedCategories();
    }
  }

  @override
  void dispose() {
    _refreshProgressTimer?.cancel();
    _wsSubscription?.cancel();
    unawaited(_wsAdapter.dispose());
    super.dispose();
  }

  void _handleWsEvent(WebServerListWsEvent event) {
    if (!mounted) {
      return;
    }

    switch (event) {
      case WebServerListSnapshotEvent(:final data):
        setState(() {
          _data = data;
          _hasReceivedFirstSnapshot = true;
          _connectionMessage = null;
          _syncSelectedCategories();
        });
      case WebServerListConnectionChangedEvent(:final isConnected):
        setState(() {
          _isConnected = isConnected;
          if (isConnected) {
            _connectionMessage = null;
          } else {
            _connectionMessage ??= '连接已断开，正在等待重连';
          }
        });
      case WebServerListErrorEvent(:final message):
        setState(() {
          _connectionMessage = message;
        });
    }
  }

  void _syncSelectedCategories() {
    final nextNames = _data.categories.map((e) => e.name).toSet();
    final retained = _selectedCategories.where(nextNames.contains).toSet();
    if (retained.isEmpty && nextNames.isNotEmpty) {
      _selectedCategories = nextNames;
    } else if (retained.length != _selectedCategories.length) {
      _selectedCategories = retained;
    }
  }

  void _startRefreshProgressTimer() {
    _refreshProgressTimer?.cancel();
    _refreshCountdown = _kRefreshIntervalSeconds;
    _refreshProgressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _refreshCountdown--;
        if (_refreshCountdown <= 0) {
          _refreshCountdown = _kRefreshIntervalSeconds;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(isDark),
            if (_connectionMessage != null) _buildConnectionBanner(isDark),
            Expanded(child: _buildServerList(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final visibleCategories = _getSelectedCategoryServers();
    final totalServers = visibleCategories.fold<int>(
      0,
      (sum, category) => sum + category.servers.length,
    );
    final totalPlayers = visibleCategories.fold<int>(
      0,
      (sum, category) => sum + category.onlinePlayers,
    );

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    '${_selectedCategories.length} 个分类 · $totalServers 台服务器 · $totalPlayers 人在线',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF374151),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 1,
                  height: 20,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                ),
                const SizedBox(width: 16),
                _buildFilterButton(isDark),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 20,
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
          const SizedBox(width: 12),
          _buildViewModeToggle(isDark),
          const SizedBox(width: 10),
          _buildUpdatedAtBadge(isDark),
        ],
      ),
    );
  }

  Widget _buildConnectionBanner(bool isDark) {
    final message = _connectionMessage ?? (_isConnected ? 'WebSocket 已连接' : '正在连接 WebSocket');
    final accentColor = _isConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
      child: Row(
        children: [
          Icon(
            _isConnected ? Icons.wifi_rounded : Icons.wifi_tethering_error_rounded,
            size: 16,
            color: accentColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(bool isDark) {
    final selectedCount = _selectedCategories.length;
    final totalCount = _data.categories.length;
    final isFiltered = selectedCount < totalCount;
    final accentColor = isFiltered
        ? const Color(0xFF3B82F6)
        : (isDark ? Colors.white70 : const Color(0xFF4B5563));

    return Tooltip(
      message: '点击这里切换分类显示',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _data.categories.isEmpty ? null : () => _showFilterDialog(isDark),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isFiltered
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFiltered
                    ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 16, color: accentColor),
                const SizedBox(width: 6),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFiltered ? '$selectedCount / $totalCount 分类' : '全部分类',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      '点击切换显示分类',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.1,
                        color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                if (isFiltered) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: accentColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpdatedAtBadge(bool isDark) {
    final progress = _refreshCountdown / _kRefreshIntervalSeconds;

    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(
                Colors.grey.withValues(alpha: 0.2),
              ),
            ),
          ),
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF18A058)),
            ),
          ),
          Text(
            '$_refreshCountdown',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeToggle(bool isDark) {
    return Tooltip(
      message: _isCompactMode ? '切换到卡片视图' : '切换到简约视图',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _isCompactMode = !_isCompactMode),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isCompactMode
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isCompactMode
                    ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08)),
              ),
            ),
            child: Icon(
              _isCompactMode ? Icons.grid_view_rounded : Icons.view_list_rounded,
              size: 20,
              color: _isCompactMode
                  ? const Color(0xFF3B82F6)
                  : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterDialog(bool isDark) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final allSelected =
                _selectedCategories.length == _data.categories.length;

            void toggle(String name) {
              setState(() {
                if (_selectedCategories.contains(name)) {
                  if (_selectedCategories.length > 1) {
                    _selectedCategories.remove(name);
                  }
                } else {
                  _selectedCategories.add(name);
                }
              });
              setDialogState(() {});
            }

            void toggleAll() {
              setState(() {
                final allNames = _data.categories.map((e) => e.name).toSet();
                if (_selectedCategories.length == allNames.length && allNames.isNotEmpty) {
                  _selectedCategories = {allNames.first};
                } else {
                  _selectedCategories = allNames;
                }
              });
              setDialogState(() {});
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 360,
                constraints: const BoxConstraints(maxHeight: 480),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '筛选分类',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                                ),
                              ),
                              Text(
                                '默认全选，可按需取消不想看的分类',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white38
                                      : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: toggleAll,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                child: Text(
                                  allSelected ? '取消全选' : '全选',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF3B82F6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.of(dialogContext).pop(),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _data.categories.length,
                        itemBuilder: (_, index) {
                          final category = _data.categories[index];
                          final isSelected = _selectedCategories.contains(category.name);
                          final activeColor = const Color(0xFF3B82F6);

                          return InkWell(
                            onTap: () => toggle(category.name),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: isSelected ? activeColor : Colors.transparent,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: isSelected
                                            ? activeColor
                                            : (isDark
                                                  ? Colors.white24
                                                  : const Color(0xFFD1D5DB)),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check_rounded,
                                            size: 13,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      category.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w500
                                            : FontWeight.w400,
                                        color: isSelected
                                            ? (isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1F2937))
                                            : (isDark
                                                  ? Colors.white60
                                                  : const Color(0xFF6B7280)),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${category.servers.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white38
                                          : const Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 去掉 URL 中的查询参数，只保留基础路径用于比较
  static String? _stripQueryParams(String? url) {
    if (url == null || url.isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    return uri.replace(query: '', fragment: '').toString().replaceAll('?', '').replaceAll('#', '');
  }

  /// 获取页面级缓存的地图背景 Widget
  /// 即使卡片被 ListView.builder 虚拟化销毁，缓存仍保留在页面 State 中
  Widget getMapBackground(WebServerItem server) {
    final serverId = server.id;
    final currentBaseUrl = _stripQueryParams(server.mapImageUrl);
    final cached = _mapBackgroundCache[serverId];

    if (cached != null &&
        cached.mapName == server.mapName &&
        cached.baseUrl == currentBaseUrl) {
      return cached.widget;
    }

    final bg = WebMapBackground.fromMap(
      mapName: server.mapName,
      mapUrl: server.mapImageUrl,
    );
    _mapBackgroundCache[serverId] = _CachedMapBg(
      mapName: server.mapName,
      baseUrl: currentBaseUrl,
      widget: bg,
    );
    return bg;
  }

  Widget _buildServerList(bool isDark) {
    // 尚未收到第一次快照时，显示全屏 loading 骨架屏
    if (!_hasReceivedFirstSnapshot) {
      return _buildLoadingList();
    }

    final categoryServers = _getSelectedCategoryServers();

    if (categoryServers.isEmpty) {
      return _buildEmptyState(isDark);
    }

    final allLoading = categoryServers.every(
      (category) => category.isLoading && category.servers.isEmpty,
    );
    if (allLoading) {
      return _buildLoadingList();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobileLayout = constraints.maxWidth < 600;

        return ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: isMobileLayout ? 12 : 20,
            vertical: isMobileLayout ? 12 : 16,
          ),
          itemCount: categoryServers.length,
          itemBuilder: (context, index) {
            final item = categoryServers[index];
            if (isMobileLayout) {
              return _buildMobileCategorySection(item);
            }
            return _isCompactMode
                ? _buildCompactCategorySection(isDark, item)
                : _buildCategorySection(isDark, item);
          },
        );
      },
    );
  }

  Widget _buildCategorySection(bool isDark, _WebCategoryServers item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Text(
                item.category.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.servers.length} 服务器 · ${item.onlinePlayers} 人',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                ),
              ),
              if (item.isLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF3B82F6)),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (item.servers.isEmpty && item.isLoading)
          _buildCategoryLoadingRow()
        else
          _buildServerGrid(item.servers),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCategoryLoadingRow() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: _WebServerCardSkeleton()),
          SizedBox(width: 12),
          Expanded(child: _WebServerCardSkeleton()),
        ],
      ),
    );
  }

  Widget _buildServerGrid(List<WebServerItem> servers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const maxCardWidth = 545.0;
        const spacing = 12.0;
        final availableWidth = constraints.maxWidth;
        final columns = availableWidth.isFinite
            ? ((availableWidth + spacing) / (maxCardWidth + spacing)).floor().clamp(1, servers.length)
            : 1;
        final contentWidth = columns * maxCardWidth + (columns - 1) * spacing;

        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: availableWidth.isFinite
                ? contentWidth.clamp(0.0, availableWidth)
                : contentWidth,
            child: Wrap(
              alignment: WrapAlignment.start,
              spacing: spacing,
              runSpacing: spacing,
              children: servers.map((server) {
                return ConstrainedBox(
                  key: ValueKey('grid_${server.id}'),
                  constraints: const BoxConstraints(maxWidth: maxCardWidth),
                  child: _WebImmersiveServerCard(
                    key: ValueKey('card_${server.id}'),
                    server: server,
                    mapBackground: getMapBackground(server),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobileLayout = constraints.maxWidth < 600;

        return ListView(
          padding: EdgeInsets.all(isMobileLayout ? 12 : 24),
          children: [
            // 加载提示文字
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        isDark ? Colors.white54 : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '正在连接服务器，获取数据中...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            // 骨架屏卡片
            if (isMobileLayout) ...[
              for (var i = 0; i < 4; i++)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _WebServerCardSkeleton(),
                ),
            ] else ...[
              for (var i = 0; i < 3; i++)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(child: _WebServerCardSkeleton()),
                      SizedBox(width: 16),
                      Expanded(child: _WebServerCardSkeleton()),
                    ],
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 64,
            color: isDark ? Colors.white24 : const Color(0xFFCCCCCC),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无服务器',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请选择分类查看服务器',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCategorySection(bool isDark, _WebCategoryServers item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                item.category.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.servers.length} 服务器 · ${item.onlinePlayers} 人',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                ),
              ),
              if (item.isLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF3B82F6)),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (item.servers.isEmpty && item.isLoading)
          _buildCompactLoadingRows(isDark)
        else
          _buildCompactTable(isDark, item.servers),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCompactLoadingRows(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: List.generate(
          3,
          (index) => _buildCompactLoadingRow(isDark, index == 2),
        ),
      ),
    );
  }

  Widget _buildCompactLoadingRow(bool isDark, bool isLast) {
    final placeholderColor = isDark
        ? Colors.white12
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE5E7EB),
                ),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: placeholderColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTable(bool isDark, List<WebServerItem> servers) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          _buildCompactTableHeader(isDark),
          ...servers.asMap().entries.map((entry) {
            final index = entry.key;
            final server = entry.value;
            return _buildCompactTableRow(
              isDark,
              server,
              isLast: index == servers.length - 1,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompactTableHeader(bool isDark) {
    final headerColor = isDark ? Colors.white38 : const Color(0xFF9CA3AF);
    const headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          ),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Expanded(
            flex: 3,
            child: Text(
              '服务器名称',
              style: headerStyle.copyWith(color: headerColor),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('地图', style: headerStyle.copyWith(color: headerColor)),
          ),
          SizedBox(
            width: 70,
            child: Text(
              '人数',
              style: headerStyle.copyWith(color: headerColor),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              '时间',
              style: headerStyle.copyWith(color: headerColor),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              '比分',
              style: headerStyle.copyWith(color: headerColor),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              '操作',
              style: headerStyle.copyWith(color: headerColor),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTableRow(bool isDark, WebServerItem server, {required bool isLast}) {
    final isOffline = server.isOffline;
    final isLoading = server.isLoading;
    final players = server.players ?? 0;
    final maxPlayers = server.maxPlayers ?? 0;
    final loadRatio = maxPlayers > 0 ? players / maxPlayers : 0.0;
    final runtimeText = _formatCompactRuntime(server);

    Color statusColor;
    if (isOffline) {
      statusColor = const Color(0xFF9CA3AF);
    } else if (loadRatio >= 1.0) {
      statusColor = const Color(0xFFF44336);
    } else if (loadRatio >= 0.8) {
      statusColor = const Color(0xFFFF9800);
    } else {
      statusColor = const Color(0xFF22C55E);
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isLoading ? Colors.transparent : statusColor,
                shape: BoxShape.circle,
                border: isLoading
                    ? Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                        width: 1.5,
                      )
                    : null,
              ),
              child: isLoading
                  ? SizedBox(
                      width: 8,
                      height: 8,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(
                          isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                server.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isOffline
                      ? (isDark ? Colors.white38 : const Color(0xFF9CA3AF))
                      : (isDark ? Colors.white : const Color(0xFF1F2937)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text(
                server.displayMapName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isOffline
                      ? (isDark ? Colors.white24 : const Color(0xFFD1D5DB))
                      : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: _buildCompactPlayerCount(isDark, players, maxPlayers, isOffline),
            ),
            SizedBox(
              width: 50,
              child: Text(
                runtimeText,
                style: TextStyle(
                  fontSize: 12,
                  color: isOffline
                      ? (isDark ? Colors.white24 : const Color(0xFFD1D5DB))
                      : (isDark ? Colors.white54 : const Color(0xFF6B7280)),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(
              width: 70,
              child: _buildCompactScoreColumn(isDark, server),
            ),
            SizedBox(
              width: 100,
              child: _buildCompactActionButtons(server),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactPlayerCount(
    bool isDark,
    int players,
    int maxPlayers,
    bool isOffline,
  ) {
    if (isOffline) {
      return Text(
        '-',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
        ),
        textAlign: TextAlign.center,
      );
    }

    Color primaryColor;
    if (players >= maxPlayers && maxPlayers > 0) {
      primaryColor = const Color(0xFFF44336);
    } else if (players >= maxPlayers * 0.8 && maxPlayers > 0) {
      primaryColor = const Color(0xFFFF9800);
    } else {
      primaryColor = const Color(0xFF0080FF);
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: '$players',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          TextSpan(
            text: '/$maxPlayers',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCompactRuntime(WebServerItem server) {
    if (server.isOffline) return '-';
    final runtimeMinutes = server.runtimeMinutes;
    if (runtimeMinutes == null) {
      return server.isLoading ? '...' : '-';
    }
    if (runtimeMinutes <= 0) return '0分';
    if (runtimeMinutes >= 60) {
      final hours = runtimeMinutes ~/ 60;
      final minutes = runtimeMinutes % 60;
      if (minutes == 0) {
        return '$hours时';
      }
      return '$hours时$minutes分';
    }
    return '$runtimeMinutes分';
  }

  Widget _buildCompactScoreColumn(bool isDark, WebServerItem server) {
    if (server.isOffline) {
      return Text(
        '-',
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
        ),
        textAlign: TextAlign.center,
      );
    }

    final score = server.score;
    final hasValidScore =
        score != null && (score.ctScore > 0 || score.tScore > 0);

    if (!hasValidScore || server.isCustom) {
      return Text(
        '-',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
        ),
        textAlign: TextAlign.center,
      );
    }

    return _buildCompactScoreInline(isDark, server, score);
  }

  Widget _buildCompactScoreInline(
    bool isDark,
    WebServerItem server,
    WebServerScore score,
  ) {
    final isZombie = _isZombieMap(server.mapName);
    final isUnknown = score.dataQuality == 'unknown';

    final Color leftColor;
    final Color rightColor;

    if (isUnknown) {
      leftColor = const Color(0xFF9CA3AF);
      rightColor = const Color(0xFF9CA3AF);
    } else if (isZombie) {
      leftColor = const Color(0xFF22C55E);
      rightColor = const Color(0xFFEF4444);
    } else {
      leftColor = const Color(0xFF3B82F6);
      rightColor = const Color(0xFFEAB308);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${score.ctScore}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: leftColor,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text(
            ':',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
            ),
          ),
        ),
        Text(
          '${score.tScore}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: rightColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactActionButtons(WebServerItem server) {
    final hasAddress = server.address != null && server.address!.isNotEmpty;
    if (!hasAddress || server.isOffline) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCompactActionButton(
          icon: Icons.play_arrow_rounded,
          color: const Color(0xFF0080FF),
          onTap: () => _connectToServer(server),
        ),
        const SizedBox(width: 6),
        _buildCompactActionButton(
          icon: Icons.content_copy_rounded,
          color: const Color(0xFF10B981),
          onTap: () => _copyAddress(server),
        ),
      ],
    );
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }

  void _connectToServer(WebServerItem server) async {
    final address = server.address;
    if (address == null || address.isEmpty) return;

    final uri = Uri.parse('steam://run/730//+connect $address');
    await launchUrl(uri);
  }

  void _copyAddress(WebServerItem server) {
    final address = server.address;
    if (address == null || address.isEmpty) return;
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('已复制服务器地址'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          width: 200,
        ),
      );
  }

  Widget _buildMobileCategorySection(_WebCategoryServers item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                item.category.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.servers.length} 服务器 · ${item.onlinePlayers} 人',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              if (item.isLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF3B82F6)),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (item.servers.isEmpty && item.isLoading)
          _buildCategoryLoadingRow()
        else
          Column(
            children: item.servers
                .map((server) => WebMobileServerListItem(
                      key: ValueKey('mobile_${server.id}'),
                      server: server,
                      mapBackground: getMapBackground(server),
                    ))
                .toList(),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  List<_WebCategoryServers> _getSelectedCategoryServers() {
    final result = <_WebCategoryServers>[];

    for (final category in _data.categories) {
      if (_selectedCategories.contains(category.name)) {
        result.add(
          _WebCategoryServers(
            category: category,
            servers: category.servers,
            isLoading: category.isLoading,
          ),
        );
      }
    }

    return result;
  }

  bool _isZombieMap(String? mapName) {
    if (mapName == null || mapName.isEmpty) {
      return false;
    }
    final lowerName = mapName.toLowerCase();
    return lowerName.startsWith('ze_') || lowerName.startsWith('zm_');
  }
}

/// 地图背景缓存数据
class _CachedMapBg {
  final String? mapName;
  final String? baseUrl;
  final Widget widget;

  const _CachedMapBg({
    required this.mapName,
    required this.baseUrl,
    required this.widget,
  });
}

class _WebCategoryServers {
  final WebServerCategory category;
  final List<WebServerItem> servers;
  final bool isLoading;

  const _WebCategoryServers({
    required this.category,
    required this.servers,
    required this.isLoading,
  });

  int get onlinePlayers {
    return servers.fold<int>(0, (sum, server) => sum + (server.players ?? 0));
  }
}

class _WebImmersiveServerCard extends StatefulWidget {
  final WebServerItem server;
  /// 由父级页面提供的缓存地图背景 Widget
  final Widget mapBackground;

  const _WebImmersiveServerCard({
    super.key,
    required this.server,
    required this.mapBackground,
  });

  @override
  State<_WebImmersiveServerCard> createState() => _WebImmersiveServerCardState();
}

class _WebImmersiveServerCardState extends State<_WebImmersiveServerCard> {
  bool _isHovered = false;

  void _onHoverChanged(bool isHovered) {
    if (!mounted) return;
    if (_isHovered != isHovered) {
      setState(() => _isHovered = isHovered);
    }
  }

  void _connectToServer() async {
    final address = widget.server.address;
    if (address == null || address.isEmpty) return;

    final uri = Uri.parse('steam://run/730//+connect $address');
    await launchUrl(uri);
  }

  void _copyAddress() {
    final address = widget.server.address;
    if (address == null || address.isEmpty) return;
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('已复制服务器地址'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          width: 200,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final server = widget.server;
    final mapName = server.mapName ?? '未知地图';
    final displayMapName = server.displayMapName;
    final address = server.address ?? '未知地址';
    final players = server.players ?? 0;
    final maxPlayers = server.maxPlayers ?? 0;
    final showRuntime = server.mapName != null && !server.isCustom;
    final hasValidScore = server.score != null &&
        (server.score!.ctScore > 0 || server.score!.tScore > 0);

    // 紧凑间距
    const verticalSpacing = 4.0;

    // 边框颜色：hover 时显示蓝色边框
    final borderColor = _isHovered
        ? const Color(0xFF0080FF).withValues(alpha: 0.6)
        : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Positioned.fill(
                child: widget.mapBackground,
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.6),
                      ],
                      stops: const [0.0, 0.3, 1.0],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 服务器名称
                            Text(
                              server.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                  Shadow(color: Colors.black, blurRadius: 8),
                                  Shadow(color: Colors.black, offset: Offset(1, 1)),
                                  Shadow(color: Colors.black, offset: Offset(-1, -1)),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: verticalSpacing),
                            // 地图名称
                            Row(
                              children: [
                                Icon(
                                  MdiIcons.map,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    displayMapName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                        Shadow(color: Colors.black, blurRadius: 6),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: verticalSpacing),
                            // 地址
                            Row(
                              children: [
                                Icon(
                                  MdiIcons.ip,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  address,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontFamily: 'monospace',
                                    shadows: [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 2,
                                        offset: Offset(0, 1),
                                      ),
                                      Shadow(color: Colors.black, blurRadius: 6),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: verticalSpacing),
                            // 地图标签行（hover 时隐藏）
                            if (!_isHovered)
                              _WebMapTagRow(tags: server.tags),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PlayerCountBadge(players: players, maxPlayers: maxPlayers),
                        if (showRuntime) ...[
                          const SizedBox(height: 6),
                          _RuntimeBadge(
                            runtimeMinutes: server.runtimeMinutes,
                            mapName: mapName,
                            score: server.score,
                            hasValidScore: hasValidScore,
                            weeklyOccurrences: server.weeklyOccurrences,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: _StatusDot(server: server),
              ),
              // Hover 时的毛玻璃操作层
              _buildHoverActionOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  /// Hover 时的操作工具栏
  Widget _buildHoverActionOverlay() {
    if (!_isHovered) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 0.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, value * 50),
            child: Opacity(opacity: 1 - value, child: child),
          );
        },
        child: Container(
          padding: const EdgeInsets.only(
            left: 14,
            right: 14,
            top: 12,
            bottom: 8,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.0),
                Colors.black.withValues(alpha: 0.7),
                Colors.black.withValues(alpha: 0.9),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
          child: Row(
            children: [
              // 主操作按钮组
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _WebActionBtn(
                    text: '连接',
                    icon: Icons.play_arrow_rounded,
                    bgColor: const Color(0xFF0080FF),
                    onPressed: _connectToServer,
                  ),
                  _WebActionBtn(
                    text: '复制地址',
                    icon: Icons.content_copy_rounded,
                    bgColor: const Color(0xFF10B981),
                    onPressed: _copyAddress,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 主操作按钮
class _WebActionBtn extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color bgColor;
  final VoidCallback? onPressed;

  const _WebActionBtn({
    required this.text,
    required this.icon,
    required this.bgColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return Material(
      color: disabled ? Colors.white.withValues(alpha: 0.1) : bgColor,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: disabled
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  color: disabled
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 地图标签行
class _WebMapTagRow extends StatelessWidget {
  final List<WebServerTag> tags;

  const _WebMapTagRow({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          tags.isEmpty ? MdiIcons.tagOffOutline : MdiIcons.tagOutline,
          size: 16,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 6),
        if (tags.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                fontSize: 12,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: tags.map((tag) => _WebTagChip(tag: tag)).toList(),
            ),
          ),
      ],
    );
  }
}

/// 单个标签
class _WebTagChip extends StatelessWidget {
  final WebServerTag tag;

  const _WebTagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final tagColor = tag.color;

    // 有颜色时的处理
    if (tagColor != null) {
      final darkColor = Color.lerp(tagColor, Colors.black, 0.2)!;
      final lightColor = Color.lerp(tagColor, Colors.white, 0.6)!;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          // 渐变背景，从浅到深，增加层次感
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              lightColor.withValues(alpha: 0.4),
              tagColor.withValues(alpha: 0.5),
              darkColor.withValues(alpha: 0.45),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: tagColor.withValues(alpha: 0.7),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: tagColor.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          tag.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                color: tagColor.withValues(alpha: 0.8),
                blurRadius: 2,
                offset: const Offset(0, 0),
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 1,
                offset: const Offset(1, 1),
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 1,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
        ),
      );
    }

    // 无颜色时的处理
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerCountBadge extends StatelessWidget {
  final int players;
  final int maxPlayers;

  const _PlayerCountBadge({required this.players, required this.maxPlayers});

  @override
  Widget build(BuildContext context) {
    late final Color primaryColor;
    late final Color bgColor;

    if (players >= maxPlayers && maxPlayers > 0) {
      primaryColor = const Color(0xFFF44336);
      bgColor = const Color(0xFFFEEAEA);
    } else if (players >= maxPlayers * 0.8 && maxPlayers > 0) {
      primaryColor = const Color(0xFFFF9800);
      bgColor = const Color(0xFFFFF9E6);
    } else {
      primaryColor = const Color(0xFF0080FF);
      bgColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$players',
            style: TextStyle(
              color: primaryColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '/',
              style: TextStyle(
                color: primaryColor.withValues(alpha: 0.5),
                fontSize: 18,
                fontWeight: FontWeight.w300,
                height: 1,
              ),
            ),
          ),
          Text(
            '$maxPlayers',
            style: TextStyle(
              color: primaryColor.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuntimeBadge extends StatelessWidget {
  final int? runtimeMinutes;
  final String mapName;
  final WebServerScore? score;
  final bool hasValidScore;
  final int? weeklyOccurrences;

  const _RuntimeBadge({
    required this.runtimeMinutes,
    required this.mapName,
    required this.score,
    required this.hasValidScore,
    this.weeklyOccurrences,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(MdiIcons.clockOutline, size: 12, color: const Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text(
                _formatRuntimeMinutes(runtimeMinutes),
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          // 比分显示或周出现次数
          if (hasValidScore && score != null) ...[
            const SizedBox(height: 2),
            _StaticScoreDisplay(
              ctScore: score!.ctScore,
              tScore: score!.tScore,
              mapName: mapName,
              dataQuality: score!.dataQuality,
            ),
          ] else if (weeklyOccurrences != null) ...[
            const SizedBox(height: 2),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
                children: [
                  const TextSpan(text: '一周内出现'),
                  TextSpan(
                    text: ' $weeklyOccurrences ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  const TextSpan(text: '次'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatRuntimeMinutes(int? value) {
    if (value == null) {
      return '--';
    }
    if (value >= 60) {
      final hours = value ~/ 60;
      final minutes = value % 60;
      if (minutes == 0) {
        return '$hours时';
      }
      return '$hours时$minutes分';
    }
    if (value <= 0) {
      return '0分';
    }
    return '$value分';
  }
}

class _StaticScoreDisplay extends StatelessWidget {
  final int ctScore;
  final int tScore;
  final String mapName;
  final String? dataQuality;

  const _StaticScoreDisplay({
    required this.ctScore,
    required this.tScore,
    required this.mapName,
    this.dataQuality,
  });

  @override
  Widget build(BuildContext context) {
    final isZombie = _isZombieMap(mapName);
    final isUnknown = dataQuality == 'unknown';

    final Color leftColor;
    final Color rightColor;
    final Color iconColor;

    if (isUnknown) {
      leftColor = const Color(0xFF9CA3AF);
      rightColor = const Color(0xFF9CA3AF);
      iconColor = const Color(0xFF9CA3AF);
    } else if (isZombie) {
      leftColor = const Color(0xFF22C55E);
      rightColor = const Color(0xFFEF4444);
      iconColor = const Color(0xFF6B7280);
    } else {
      leftColor = const Color(0xFF3B82F6);
      rightColor = const Color(0xFFEAB308);
      iconColor = const Color(0xFF6B7280);
    }

    final leftLabel = isZombie ? '人类' : 'CT';
    final rightLabel = isZombie ? '僵尸' : 'T';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$leftLabel $ctScore',
          style: TextStyle(
            color: leftColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(MdiIcons.swordCross, size: 12, color: iconColor),
        ),
        Text(
          '$tScore $rightLabel',
          style: TextStyle(
            color: rightColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  bool _isZombieMap(String? mapName) {
    if (mapName == null || mapName.isEmpty) {
      return false;
    }
    final lowerName = mapName.toLowerCase();
    return lowerName.startsWith('ze_') || lowerName.startsWith('zm_');
  }
}

class _StatusDot extends StatelessWidget {
  final WebServerItem server;

  const _StatusDot({required this.server});

  @override
  Widget build(BuildContext context) {
    final color = switch ((server.isLoading, server.isOffline)) {
      (true, _) => const Color(0xFF64748B),
      (_, true) => const Color(0xFFEF4444),
      _ => const Color(0xFF22C55E),
    };

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

class _WebServerCardSkeleton extends StatefulWidget {
  const _WebServerCardSkeleton();

  @override
  State<_WebServerCardSkeleton> createState() => _WebServerCardSkeletonState();
}

class _WebServerCardSkeletonState extends State<_WebServerCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-1.0 + 2.0 * _controller.value + 1.0, 0),
              colors: isDark
                  ? const [
                      Color(0xFF1E293B),
                      Color(0xFF334155),
                      Color(0xFF1E293B),
                    ]
                  : const [
                      Color(0xFFE5E7EB),
                      Color(0xFFF3F4F6),
                      Color(0xFFE5E7EB),
                    ],
            ),
          ),
        );
      },
    );
  }
}

