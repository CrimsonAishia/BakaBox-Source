import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/map_subscription/map_subscription_bloc.dart';
import '../../../../core/widgets/map_contribution_dialog.dart';
import '../../common_scroll_indicator.dart';
import '../../map_subscription_card.dart';

/// 添加订阅视图
class AddSubscriptionView extends StatefulWidget {
  final bool isDark;
  final MapSubscriptionState state;

  const AddSubscriptionView({
    super.key,
    required this.isDark,
    required this.state,
  });

  @override
  State<AddSubscriptionView> createState() => _AddSubscriptionViewState();
}

class _AddSubscriptionViewState extends State<AddSubscriptionView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _searchScrollController = ScrollController();
  Timer? _searchDebounce;
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _searchScrollController.addListener(_onSearchScroll);
    _searchScrollController.addListener(_updateScrollIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
  }

  @override
  void didUpdateWidget(AddSubscriptionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.searchResults.length != widget.state.searchResults.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _searchScrollController.removeListener(_onSearchScroll);
    _searchScrollController.removeListener(_updateScrollIndicators);
    _searchScrollController.dispose();
    super.dispose();
  }

  void _updateScrollIndicators() {
    if (!_searchScrollController.hasClients) return;
    final position = _searchScrollController.position;
    final canUp = position.pixels > 0;
    final canDown = position.pixels < position.maxScrollExtent;
    if (canUp != _canScrollUp || canDown != _canScrollDown) {
      setState(() {
        _canScrollUp = canUp;
        _canScrollDown = canDown;
      });
    }
  }

  void _onSearchScroll() {
    if (_searchScrollController.position.pixels >=
        _searchScrollController.position.maxScrollExtent - 100) {
      final state = widget.state;
      if (!state.isSearching && state.hasMoreSearchResults) {
        context.read<MapSubscriptionBloc>().add(
              MapSubscriptionSearchMaps(
                query: _searchController.text,
                loadMore: true,
              ),
            );
      }
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      context.read<MapSubscriptionBloc>().add(
            MapSubscriptionSearchMaps(query: query),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final state = widget.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(isDark),
        const Divider(height: 1),
        _buildSearchBar(isDark),
        Expanded(
          child: _searchController.text.isEmpty
              ? _buildSearchPlaceholder(isDark)
              : _buildSearchResults(isDark, state),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Icon(
            Icons.add_circle_outline_rounded,
            color: const Color(0xFF6366F1),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '添加订阅',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
        ),
        decoration: InputDecoration(
          hintText: '搜索地图名称...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                  ),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                    });
                    context.read<MapSubscriptionBloc>().add(
                          const MapSubscriptionSearchMaps(query: ''),
                        );
                  },
                )
              : null,
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF3F4F6),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color(0xFF6366F1),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPlaceholder(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_rounded,
            size: 48,
            color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
          ),
          const SizedBox(height: 12),
          Text(
            '搜索地图',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '输入地图名称搜索并添加订阅',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDark, MapSubscriptionState state) {
    if (state.isSearching && state.searchResults.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
      );
    }

    if (state.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
            ),
            const SizedBox(height: 12),
            Text(
              '未找到匹配的地图',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '找到 ${state.searchTotalCount} 个地图',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                ),
              ),
              if (state.hasMoreSearchResults) ...[
                const SizedBox(width: 8),
                Text(
                  '(已加载 ${state.searchResults.length} 个)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                controller: _searchScrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: state.searchResults.length + (state.hasMoreSearchResults ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= state.searchResults.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: state.isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF6366F1),
                                ),
                              )
                            : TextButton(
                                onPressed: () {
                                  context.read<MapSubscriptionBloc>().add(
                                        MapSubscriptionSearchMaps(
                                          query: _searchController.text,
                                          loadMore: true,
                                        ),
                                      );
                                },
                                child: Text(
                                  '加载更多',
                                  style: TextStyle(
                                    fontSize: 13,
                                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                  ),
                );
              }
              final result = state.searchResults[index];
              return _buildSearchResultTile(isDark, result);
            },
          ),
              if (_canScrollUp)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: CommonScrollIndicator(isTop: true),
                ),
              if (_canScrollDown)
                const Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: CommonScrollIndicator(isTop: false),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultTile(bool isDark, MapSearchResult result) {
    final hasBackground = result.mapBackground != null;
    return MapSubscriptionCard(
      displayName: result.mapLabel.isNotEmpty ? result.mapLabel : result.mapName,
      mapName: result.mapName,
      mapBackground: result.mapBackground,
      isSubscribed: result.isSubscribed,
      isCompact: true,
      onTap: result.isSubscribed
          ? null
          : () => _showAddSubscriptionDialog(
                mapName: result.mapName,
                mapLabel: result.mapLabel,
                mapBackground: result.mapBackground,
              ),
      trailing: result.isSubscribed
          ? _buildSubscribedTrailing(context, hasBackground, result)
          : _buildUnsubscribedTrailing(context, hasBackground, result),
    );
  }

  /// 未订阅状态的 trailing（编辑按钮 + 订阅按钮）
  Widget _buildUnsubscribedTrailing(BuildContext context, bool hasBackground, MapSearchResult result) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 编辑按钮
        Tooltip(
          message: '编辑地图信息',
          child: IconButton(
            onPressed: () {
              MapContributionDialog.show(
                context,
                mapName: result.mapName,
                mapLabel: result.mapLabel,
              );
            },
            icon: Icon(
              Icons.edit_rounded,
              size: 16,
              color: hasBackground ? Colors.white70 : Colors.white38,
            ),
            iconSize: 16,
            splashRadius: 14,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ),
        const SizedBox(width: 4),
        // 订阅按钮
        _buildSubscribeButton(
          hasBackground: hasBackground,
          onTap: () => _showAddSubscriptionDialog(
            mapName: result.mapName,
            mapLabel: result.mapLabel,
            mapBackground: result.mapBackground,
          ),
        ),
      ],
    );
  }

  /// 已订阅状态的 trailing（编辑按钮 + 已订阅标签）
  Widget _buildSubscribedTrailing(BuildContext context, bool hasBackground, MapSearchResult result) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 编辑按钮
        Tooltip(
          message: '编辑地图信息',
          child: IconButton(
            onPressed: () {
              MapContributionDialog.show(
                context,
                mapName: result.mapName,
                mapLabel: result.mapLabel,
              );
            },
            icon: Icon(
              Icons.edit_rounded,
              size: 16,
              color: hasBackground ? Colors.white70 : Colors.white38,
            ),
            iconSize: 16,
            splashRadius: 14,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ),
        const SizedBox(width: 4),
        // 已订阅标签
        _buildSubscribedLabel(hasBackground),
      ],
    );
  }

  Widget _buildSubscribedLabel(bool hasBackground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hasBackground
            ? const Color(0xFF10B981).withValues(alpha: 0.85)
            : const Color(0xFF10B981).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_rounded,
            size: 14,
            color: hasBackground ? Colors.white : const Color(0xFF10B981),
          ),
          const SizedBox(width: 4),
          Text(
            '已订阅',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: hasBackground ? Colors.white : const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton({
    required bool hasBackground,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: hasBackground
                ? const Color(0xFF6366F1).withValues(alpha: 0.9)
                : const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(6),
            boxShadow: hasBackground
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.add_rounded, size: 14, color: Colors.white),
              SizedBox(width: 4),
              Text(
                '订阅',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSubscriptionDialog({
    required String mapName,
    required String mapLabel,
    String? mapBackground,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(
              Icons.add_circle_rounded,
              color: const Color(0xFF6366F1),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '确认订阅',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.map_rounded,
                    size: 18,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mapLabel.isNotEmpty ? mapLabel : mapName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '监控范围由全局设置控制',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white54 : const Color(0xFF6B7280),
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<MapSubscriptionBloc>().add(
                    MapSubscriptionAdd(
                      mapName: mapName,
                      mapLabel: mapLabel,
                      mapBackground: mapBackground,
                    ),
                  );
              if (_searchController.text.isNotEmpty) {
                context.read<MapSubscriptionBloc>().add(
                      MapSubscriptionSearchMaps(
                        query: _searchController.text,
                      ),
                    );
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('确认订阅'),
          ),
        ],
      ),
    );
  }
}
