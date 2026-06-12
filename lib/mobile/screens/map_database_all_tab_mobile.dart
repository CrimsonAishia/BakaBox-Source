import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/map_contribution/map_contribution_bloc.dart';
import '../../core/bloc/map_contribution/map_contribution_event.dart';
import '../../core/bloc/map_contribution/map_contribution_state.dart';
import '../../core/models/map_contribution_models.dart';
import '../widgets/map_database/map_card_mobile.dart';
import '../widgets/map_database/map_history_sheet_mobile.dart';
import '../../core/constants/app_colors.dart';

const _mapTypeOptions = [
  ('ze_', '僵尸逃跑'),
  ('zm_', '僵尸感染'),
  ('surf_', '滑翔'),
  ('bhop_', '连跳'),
  ('kz_', '攀爬'),
  ('mg_', '闯关'),
  ('bkz_', '攀岩'),
  ('', '其他'),
];

/// 移动端地图数据库 - 全部地图列表
class MapDatabaseAllTabMobile extends StatefulWidget {
  const MapDatabaseAllTabMobile({super.key});

  @override
  State<MapDatabaseAllTabMobile> createState() =>
      _MapDatabaseAllTabMobileState();
}

class _MapDatabaseAllTabMobileState extends State<MapDatabaseAllTabMobile>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  String _searchKeyword = '';
  String _selectedMapType = 'ze_';
  int _currentPage = 1;
  int _totalCount = 0;
  bool _isLoadingMore = false;

  // 本地累积的地图列表（Bloc 每次只返回当页数据，需要自己拼接）
  final List<MapInfo> _maps = [];

  static const int _pageSize = 20;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 首次加载
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPage(1));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasMore => _maps.length < _totalCount;

  void _loadPage(int page) {
    context.read<MapContributionBloc>().add(
      LoadAllMaps(
        request: MapListRequest(
          pagination: PaginationParams(pageIndex: page, pageSize: _pageSize),
          mapName: _searchKeyword.isEmpty ? null : _searchKeyword,
          mapType: _selectedMapType,
        ),
      ),
    );
  }

  void _reset() {
    setState(() {
      _currentPage = 1;
      _maps.clear();
      _totalCount = 0;
      _isLoadingMore = false;
    });
    _loadPage(1);
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      setState(() {
        _isLoadingMore = true;
        _currentPage++;
      });
      _loadPage(_currentPage);
    }
  }

  void _onBlocState(MapContributionState state) {
    // Bloc 加载完成后，把新一页数据追加到本地列表
    if (!state.isLoadingAllMaps && state.allMaps.isNotEmpty) {
      setState(() {
        _totalCount = state.allMapsTotal;
        _isLoadingMore = false;
        // 避免重复追加：用 mapName 去重
        final existing = _maps.map((m) => m.mapName).toSet();
        for (final m in state.allMaps) {
          if (!existing.contains(m.mapName)) _maps.add(m);
        }
      });
    } else if (!state.isLoadingAllMaps) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final trimmed = value.trim();
      if (_searchKeyword != trimmed) {
        _searchKeyword = trimmed;
        _reset();
      }
    });
  }

  void _onSearchSubmit(String value) {
    _debounce?.cancel();
    _searchKeyword = value.trim();
    _reset();
  }

  void _onMapTypeChanged(String mapType) {
    if (_selectedMapType == mapType) return;
    setState(() => _selectedMapType = mapType);
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocListener<MapContributionBloc, MapContributionState>(
      listener: (context, state) => _onBlocState(state),
      child: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmit,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: '搜索地图名称...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.35),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.4),
                ),
                suffixIcon: _searchKeyword.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 18,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.5),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchSubmit('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 地图类型筛选 chip 栏
          _buildMapTypeBar(isDark),

          // 地图列表
          Expanded(child: _buildList(isDark)),
        ],
      ),
    );
  }

  Widget _buildList(bool isDark) {
    return BlocBuilder<MapContributionBloc, MapContributionState>(
      builder: (context, state) {
        // 首次加载中
        if (state.isLoadingAllMaps && _maps.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        // 空状态
        if (_maps.isEmpty) {
          return _buildEmpty(isDark);
        }

        return RefreshIndicator(
          onRefresh: () async => _reset(),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: _maps.length + (_isLoadingMore || _hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _maps.length) {
                // 底部加载指示
                return _isLoadingMore
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            '共 $_totalCount 张地图',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.35)
                                  : Colors.black.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      );
              }

              final mapInfo = _maps[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MapCardMobile(
                  key: ValueKey('map_${mapInfo.mapName}'),
                  mapInfo: mapInfo,
                  onTap: () => MapHistorySheetMobile.show(
                    context,
                    mapName: mapInfo.mapName,
                    mapLabel: mapInfo.mapLabel,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMapTypeBar(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 0, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _mapTypeOptions.map((option) {
            final (value, label) = option;
            final isSelected = _selectedMapType == value;
            const activeColor = AppColors.primary;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _onMapTypeChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? activeColor : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.black.withValues(alpha: 0.65)),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 72,
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            _searchKeyword.isEmpty ? '暂无地图数据' : '未找到相关地图',
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
}
