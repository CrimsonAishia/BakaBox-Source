import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/map_contribution/map_contribution_bloc.dart';
import '../../core/bloc/map_contribution/map_contribution_event.dart';
import '../../core/bloc/map_contribution/map_contribution_state.dart';
import '../../core/models/map_contribution_models.dart';
import '../../core/utils/toast_utils.dart';
import '../widgets/map_database/map_database_all_tab.dart';
import '../widgets/map_database/map_database_my_tab.dart';

/// 地图数据库页面（桌面端）
///
/// 显示所有地图的贡献信息和用户自己的贡献
/// 包含两个 Tab：全部地图、我的贡献
class MapDatabaseDesktop extends StatefulWidget {
  const MapDatabaseDesktop({super.key});

  @override
  State<MapDatabaseDesktop> createState() => _MapDatabaseDesktopState();
}

class _MapDatabaseDesktopState extends State<MapDatabaseDesktop>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  String _searchKeyword = '';
  int _currentPage = 1;
  static const int _pageSize = 6;
  String? _selectedStatus; // 添加状态筛选变量

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 监听 tab 切换（包括点击和滑动）
    _tabController.addListener(_onTabChanged);

    // 初始加载全部地图数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllMaps();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Tab 切换监听器（处理点击和滑动）
  void _onTabChanged() {
    // indexIsChanging 为 true 表示正在切换（滑动开始）
    // indexIsChanging 为 false 且 index 改变表示切换完成
    if (!_tabController.indexIsChanging) {
      // 切换完成后加载数据
      setState(() {
        // 重置页码
        _currentPage = 1;

        // 切换到"全部地图"时重置状态筛选
        if (_tabController.index == 0) {
          _selectedStatus = null;
          _loadAllMaps();
        } else {
          _loadMyMaps();
        }
      });
    }
  }

  void _loadAllMaps({int page = 1}) {
    final request = MapListRequest(
      pagination: PaginationParams(pageIndex: page, pageSize: _pageSize),
      mapName: _searchKeyword.isEmpty ? null : _searchKeyword,
    );

    setState(() {
      _currentPage = page;
    });
    context.read<MapContributionBloc>().add(LoadAllMaps(request: request));
  }

  void _loadMyMaps({int page = 1}) {
    final request = MapContributionListRequest(
      pagination: PaginationParams(
        pageIndex: page,
        pageSize: _pageSize,
        orderBy: 'created_at DESC',
      ),
      mapName: _searchKeyword.isEmpty ? null : _searchKeyword,
      auditStatus: _selectedStatus, // 添加状态筛选
    );

    setState(() {
      _currentPage = page;
    });
    context.read<MapContributionBloc>().add(
      LoadMyMapContributions(request: request),
    );
  }

  void _onStatusChanged(String? status) {
    setState(() {
      _selectedStatus = status;
      _currentPage = 1;
    });
    _loadMyMaps(page: 1);
  }

  void _onPageChanged(int page) {
    if (_tabController.index == 0) {
      _loadAllMaps(page: page);
    } else {
      _loadMyMaps(page: page);
    }
  }

  void _onSearchChanged(String keyword) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchKeyword != keyword.trim()) {
        _onSearch(keyword);
      }
    });
  }

  void _onSearch(String keyword) {
    final trimmedKeyword = keyword.trim();

    // 如果跟当前搜索词一样且不是强制刷新，则忽略
    if (_searchKeyword == trimmedKeyword && mounted) {
      // 首次搜索或强制刷新的逻辑由调用方保证，这里仅查重避免重复加载（如果需要）
    }

    setState(() {
      _searchKeyword = trimmedKeyword;
      _currentPage = 1;
    });

    if (_tabController.index == 0) {
      _loadAllMaps(page: 1);
    } else {
      _loadMyMaps(page: 1);
    }
  }

  Widget _buildStatusDropdown(bool isDark) {
    final statusOptions = {
      null: '全部状态',
      'pending': '待审核',
      'approved': '已通过',
      'rejected': '已拒绝',
    };

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedStatus,
          isDense: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: isDark
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.black.withValues(alpha: 0.7),
          ),
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : Colors.black,
          ),
          dropdownColor: isDark ? const Color(0xFF2D3748) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          items: statusOptions.entries.map((entry) {
            return DropdownMenuItem<String?>(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: _onStatusChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocListener<MapContributionBloc, MapContributionState>(
      listener: (context, state) {
        if (state.error != null) {
          ToastUtils.showError(context, state.error!);
          context.read<MapContributionBloc>().add(
            const ClearContributionError(),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Tab 栏和搜索栏合并
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Tab 栏
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: const Color(0xFF0080FF),
                            width: 3,
                          ),
                        ),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: const Color(0xFF0080FF),
                      unselectedLabelColor: isDark
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.black.withValues(alpha: 0.6),
                      labelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      tabs: [
                        const Tab(
                          height: 56,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.public, size: 20),
                              SizedBox(width: 8),
                              Text('全部地图'),
                            ],
                          ),
                        ),
                        Tab(
                          height: 56,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person, size: 20),
                              const SizedBox(width: 8),
                              const Text('我的贡献'),
                              const SizedBox(width: 12),
                              _buildStatusDropdown(isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 搜索框（紧凑版）
                  Padding(
                    padding: const EdgeInsets.only(
                      right: 24,
                      top: 8,
                      bottom: 8,
                    ),
                    child: SizedBox(
                      width: 280,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.1),
                          ),
                        ),
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _searchController,
                          builder: (context, value, child) {
                            return TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              onSubmitted: _onSearch,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              decoration: InputDecoration(
                                hintText: '搜索地图...',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.4)
                                      : Colors.black.withValues(alpha: 0.4),
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  size: 20,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : Colors.black.withValues(alpha: 0.5),
                                ),
                                suffixIcon: value.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear,
                                          size: 18,
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.5,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.5,
                                                ),
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          _onSearch('');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab 内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  MapDatabaseAllTab(
                    currentPage: _currentPage,
                    onPageChanged: _onPageChanged,
                  ),
                  MapDatabaseMyTab(
                    currentPage: _currentPage,
                    onPageChanged: _onPageChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
