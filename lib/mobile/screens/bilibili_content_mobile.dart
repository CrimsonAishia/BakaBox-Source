import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/core.dart';
import '../widgets/bilibili_content/bilibili_content_grid_mobile.dart';

const _bilibiliBlue = Color(0xFF00A1D6);
const _bilibiliPink = Color(0xFFFB7299);

/// 移动端B站直播/视频页面
class BilibiliContentMobile extends StatefulWidget {
  const BilibiliContentMobile({super.key});

  @override
  State<BilibiliContentMobile> createState() => _BilibiliContentMobileState();
}

class _BilibiliContentMobileState extends State<BilibiliContentMobile>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _liveRoomScrollController = ScrollController();
  final ScrollController _videoScrollController = ScrollController();

  static const int _apiPageSize = 16;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    _liveRoomScrollController.addListener(_onLiveRoomScroll);
    _videoScrollController.addListener(_onVideoScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    if (!mounted) return;
    final bloc = context.read<BilibiliContentBloc>();
    bloc.add(const BilibiliContentTabChanged(0));
    bloc.add(const BilibiliContentFetchRequested(tabIndex: 0, refresh: false));
    bloc.add(const BilibiliContentFetchCategoriesRequested());
  }

  void _onTabChanged() {
    if (!mounted) return;
    final bloc = context.read<BilibiliContentBloc>();
    if (bloc.state.currentTabIndex != _tabController.index) {
      bloc.add(BilibiliContentTabChanged(_tabController.index));

      final state = bloc.state;
      final needsFetch =
          (_tabController.index == 0 && !state.hasLoadedLiveRooms) ||
          (_tabController.index == 1 && !state.hasLoadedVideos);

      if (needsFetch && state.status != BilibiliContentStatus.loading) {
        bloc.add(BilibiliContentFetchRequested(tabIndex: _tabController.index));
      }
    }
  }

  void _onLiveRoomScroll() {
    if (_liveRoomScrollController.position.pixels >=
        _liveRoomScrollController.position.maxScrollExtent - 200) {
      _loadMoreLiveRooms();
    }
  }

  void _onVideoScroll() {
    if (_videoScrollController.position.pixels >=
        _videoScrollController.position.maxScrollExtent - 200) {
      _loadMoreVideos();
    }
  }

  void _loadMoreLiveRooms() {
    final bloc = context.read<BilibiliContentBloc>();
    final state = bloc.state;
    if (state.status == BilibiliContentStatus.loading) return;

    final currentCount = state.liveRooms.length;
    if (currentCount >= state.liveRoomsTotal) return;

    final nextPage = (currentCount / _apiPageSize).ceil() + 1;
    bloc.add(BilibiliContentFetchRequested(tabIndex: 0, pageIndex: nextPage));
  }

  void _loadMoreVideos() {
    final bloc = context.read<BilibiliContentBloc>();
    final state = bloc.state;
    if (state.status == BilibiliContentStatus.loading) return;

    final currentCount = state.videos.length;
    if (currentCount >= state.videosTotal) return;

    final nextPage = (currentCount / _apiPageSize).ceil() + 1;
    bloc.add(BilibiliContentFetchRequested(tabIndex: 1, pageIndex: nextPage));
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _liveRoomScrollController.dispose();
    _videoScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: BlocBuilder<BilibiliContentBloc, BilibiliContentState>(
        builder: (context, state) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildLiveRoomTab(state),
              _buildVideoTab(state),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      title: const Text('直播 / 视频'),
      centerTitle: true,
      actions: [
        BlocBuilder<BilibiliContentBloc, BilibiliContentState>(
          buildWhen: (prev, curr) => prev.isRefreshing != curr.isRefreshing,
          builder: (context, state) {
            return IconButton(
              onPressed: state.isRefreshing
                  ? null
                  : () {
                      context.read<BilibiliContentBloc>().add(
                        BilibiliContentFetchRequested(
                          refresh: true,
                          tabIndex: _tabController.index,
                          pageIndex: 1,
                        ),
                      );
                    },
              icon: state.isRefreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _bilibiliBlue,
                      ),
                    )
                  : const Icon(Icons.refresh),
              tooltip: '刷新',
            );
          },
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: _bilibiliBlue,
        indicatorWeight: 3,
        labelColor: _bilibiliBlue,
        unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        tabs: const [
          Tab(text: '直播间'),
          Tab(text: '视频'),
        ],
      ),
    );
  }

  Widget _buildLiveRoomTab(BilibiliContentState state) {
    if (state.status == BilibiliContentStatus.loading && state.liveRooms.isEmpty && !state.isRefreshing) {
      return const Center(
        child: CircularProgressIndicator(color: _bilibiliBlue),
      );
    }
    if (state.status == BilibiliContentStatus.error &&
        state.liveRooms.isEmpty &&
        state.currentTabIndex == 0) {
      return _buildErrorState(state.errorMessage ?? '加载失败');
    }

    return RefreshIndicator(
      color: _bilibiliBlue,
      onRefresh: () async {
        final bloc = context.read<BilibiliContentBloc>();
        bloc.add(
          const BilibiliContentFetchRequested(refresh: true, tabIndex: 0, pageIndex: 1),
        );
        // 等待 isRefreshing 变为 false（数据加载完成）
        await bloc.stream.firstWhere((s) => !s.isRefreshing);
      },
      child: Stack(
        children: [
          // 列表内容（带淡入动画）
          AnimatedOpacity(
            opacity: state.isRefreshing ? 0.3 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: state.liveRooms.isEmpty
                ? _buildEmptyScrollable('暂无直播间')
                : LiveRoomGridMobile(
                    rooms: state.liveRooms,
                    total: state.liveRoomsTotal,
                    scrollController: _liveRoomScrollController,
                  ),
          ),
          // 刷新时的居中 loading
          if (state.isRefreshing)
            const Center(
              child: CircularProgressIndicator(color: _bilibiliBlue),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoTab(BilibiliContentState state) {
    if (state.status == BilibiliContentStatus.loading && state.videos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _bilibiliBlue),
      );
    }
    if (state.status == BilibiliContentStatus.error &&
        state.videos.isEmpty &&
        state.currentTabIndex == 1) {
      return _buildErrorState(state.errorMessage ?? '加载失败');
    }

    return Column(
      children: [
        // 排序和分类选项
        if (state.videoCategories.isNotEmpty || state.videos.isNotEmpty)
          _buildVideoFilters(state),
        Expanded(
          child: RefreshIndicator(
            color: _bilibiliBlue,
            onRefresh: () async {
              final bloc = context.read<BilibiliContentBloc>();
              bloc.add(
                const BilibiliContentFetchRequested(refresh: true, tabIndex: 1, pageIndex: 1),
              );
              // 等待 isRefreshing 变为 false（数据加载完成）
              await bloc.stream.firstWhere((s) => !s.isRefreshing);
            },
            child: Stack(
              children: [
                // 列表内容（带淡入动画）
                AnimatedOpacity(
                  opacity: state.isRefreshing ? 0.3 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: VideoGridMobile(
                    videos: state.videos,
                    total: state.videosTotal,
                    scrollController: _videoScrollController,
                  ),
                ),
                // 刷新时的居中 loading
                if (state.isRefreshing)
                  const Center(
                    child: CircularProgressIndicator(color: _bilibiliBlue),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoFilters(BilibiliContentState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 排序选项
          Row(
            children: [
              Text(
                '排序：',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              _buildSortChip('默认', state.videoSort != 'newest', () {
                context.read<BilibiliContentBloc>().add(
                  const BilibiliContentVideoSortChanged('view_count'),
                );
              }),
              const SizedBox(width: 8),
              _buildSortChip('新添加', state.videoSort == 'newest', () {
                context.read<BilibiliContentBloc>().add(
                  const BilibiliContentVideoSortChanged('newest'),
                );
              }),
            ],
          ),
          // 分类选项
          if (state.videoCategories.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildCategoryChip('全部', state.videoCategoryFilter == null, () {
                    context.read<BilibiliContentBloc>().add(
                      const BilibiliContentVideoCategoryFilterChanged(null),
                    );
                  }),
                  ...state.videoCategories.map((cat) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildCategoryChip(
                      cat.name,
                      state.videoCategoryFilter == cat.id,
                      () {
                        context.read<BilibiliContentBloc>().add(
                          BilibiliContentVideoCategoryFilterChanged(cat.id),
                        );
                      },
                    ),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? _bilibiliBlue.withValues(alpha: 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _bilibiliBlue.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? _bilibiliBlue : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? _bilibiliPink.withValues(alpha: 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _bilibiliPink.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? _bilibiliPink : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              context.read<BilibiliContentBloc>().add(
                BilibiliContentFetchRequested(
                  refresh: true,
                  tabIndex: _tabController.index,
                  pageIndex: 1,
                ),
              );
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 空状态但可滚动（让 RefreshIndicator 能正常工作）
  Widget _buildEmptyScrollable(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 300,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
                const SizedBox(height: 12),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
