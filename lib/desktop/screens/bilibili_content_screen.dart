import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/core.dart';
import '../widgets/bilibili_content/live_room_card.dart';
import '../widgets/bilibili_content/video_card.dart';
import '../widgets/bilibili_content/content_toolbar.dart';
import '../widgets/bilibili_content/content_empty_state.dart';
import '../widgets/bilibili_content/content_error_state.dart';
import '../widgets/bilibili_content/user_center_dialog.dart';

/// B站主题色常量
const kBilibiliBlue = Color(0xFF00A1D6);
const kBilibiliPink = Color(0xFFFB7299);

/// B站内容页面
class BilibiliContentScreen extends StatefulWidget {
  const BilibiliContentScreen({super.key});

  @override
  State<BilibiliContentScreen> createState() => _BilibiliContentScreenState();
}

class _BilibiliContentScreenState extends State<BilibiliContentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // B站主题色
  static const kBilibiliBlue = Color(0xFF00A1D6);

  // 网格布局常量（每页8个卡片）
  static const int _itemsPerRow = 4; // 每行4个
  static const int _rowsPerPage = 2; // 每页2行
  static const int _pageSize = _itemsPerRow * _rowsPerPage; // 每页8个

  // 滚动控制器和状态（用于上下滚动指示器）
  final ScrollController _videoScrollController = ScrollController();

  // 标记TabController是否已初始化完成，防止初始化时触发重复刷新
  bool _isTabControllerInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // 标记TabController初始化完成后再允许刷新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isTabControllerInitialized = true;
    });

    // 进入页面后主动刷新所有直播间/视频的封面、标题和直播状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshContentOnPageEnter();
    });
  }

  /// 进入页面时加载内容数据（每次进入都刷新）
  void _refreshContentOnPageEnter() {
    if (!mounted) return;

    final bloc = context.read<BilibiliContentBloc>();

    // 进入页面时，重置Tab状态到直播间Tab
    bloc.add(const BilibiliContentTabChanged(0));

    // 每次进入页面都刷新数据
    // 使用 refresh: true 强制获取最新数据
    bloc.add(const BilibiliContentFetchRequested(tabIndex: 0, refresh: true));

    // 加载视频分类列表
    bloc.add(const BilibiliContentFetchCategoriesRequested());
  }

  void _openUserCenter() {
    // 检查用户是否已登录
    if (!TokenService.instance.isTokenValid) {
      ToastUtils.showError(context, '请先登录后再访问用户中心');
      return;
    }
    BilibiliUserCenterDialog.show(context);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    _videoScrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // 只有在TabController初始化完成后才处理Tab切换
    if (!_isTabControllerInitialized) return;

    final bloc = context.read<BilibiliContentBloc>();

    // 及时通知状态层 Tab 已经切换
    if (bloc.state.currentTabIndex != _tabController.index) {
      bloc.add(BilibiliContentTabChanged(_tabController.index));

      // 如果切换到的 Tab 完全没有数据，且当前并不处于 loading 状态，主动补发请求拉取数据
      final state = bloc.state;
      final isTabEmpty =
          (_tabController.index == 0 && state.liveRooms.isEmpty) ||
          (_tabController.index == 1 && state.videos.isEmpty);

      // 切换Tab时主动刷新B站数据（点赞、关注等实时信息）
      final isVideoTab = _tabController.index == 1;
      final isLiveRoomTab = _tabController.index == 0;

      // 视频Tab：刷新视频的点赞、播放量等数据
      if (isVideoTab && state.videos.isNotEmpty) {
        bloc.add(BilibiliContentFetchRequested(tabIndex: 1));
      }
      // 直播间Tab：刷新直播间的粉丝数、观看人数等数据
      else if (isLiveRoomTab && state.liveRooms.isNotEmpty) {
        bloc.add(BilibiliContentFetchRequested(tabIndex: 0));
      }
      // 如果Tab完全没有数据，则全量获取
      else if (isTabEmpty && state.status != BilibiliContentStatus.loading) {
        bloc.add(BilibiliContentFetchRequested(tabIndex: _tabController.index));
      }
    }
  }

  // ===== 主题颜色辅助方法 =====
  static const _inkColorLight = Color(0xFF2C1810);
  static const _inkColorDark = Color(0xFFE8E0D8);

  Color _getInkColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _inkColorDark
        : _inkColorLight;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BilibiliContentBloc, BilibiliContentState>(
      builder: (context, state) {
        return Scaffold(
          body: Stack(
            children: [
              // 渐变背景
              Positioned.fill(child: _buildGradientBackground(context)),
              // 浮动装饰图标
              const _FloatingBilibiliIcons(),
              // 主内容
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 55, 16, 16),
                child: _buildScrollContent(state),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建渐变背景
  Widget _buildGradientBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  // 深色模式
                  const Color(0xFF0F172A),
                  const Color(0xFF1E293B),
                  const Color(0xFF0D1B2A),
                ]
              : [
                  // 浅色模式
                  const Color(0xFFE3F2FD), // 浅蓝
                  const Color(0xFFE0F7FA), // 青色
                  const Color(0xFFFCE4EC), // 浅粉
                  const Color(0xFFE1F5FE), // 淡蓝
                ],
          stops: isDark ? [0.0, 0.5, 1.0] : [0.0, 0.4, 0.7, 1.0],
        ),
      ),
    );
  }

  Widget _buildScrollContent(BilibiliContentState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 使用半透明背景风格
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155)
              : const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          BilibiliContentToolbar(
            tabController: _tabController,
            searchController: _searchController,
            state: state,
            onUserCenterTap: _openUserCenter,
            onRefreshTap: () {
              // 用户主动点击刷新按钮：强制请求第1页以获取最新数据
              context.read<BilibiliContentBloc>().add(
                BilibiliContentFetchRequested(
                  refresh: true,
                  tabIndex: _tabController.index,
                  pageIndex: 1,
                ),
              );
            },
            onTabChanged: (index) {
              _tabController.animateTo(index);
            },
            onLiveRoomTabTap: () => _switchTab(0),
            onVideoTabTap: () => _switchTab(1),
          ),
          Container(height: 1, color: isDark ? Colors.white10 : Colors.black12),
          Expanded(child: _buildContent(state)),
        ],
      ),
    );
  }

  void _switchTab(int index) {
    _tabController.animateTo(index);
  }

  Widget _buildContent(BilibiliContentState state) {
    // 直接返回 TabBarView 支持自然滑动
    return TabBarView(
      controller: _tabController,
      children: [_buildLiveRoomTab(state), _buildVideoTab(state)],
    );
  }

  Widget _buildLiveRoomTab(BilibiliContentState state) {
    if (state.status == BilibiliContentStatus.loading &&
        state.liveRooms.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: kBilibiliBlue),
      );
    }
    if (state.status == BilibiliContentStatus.error &&
        state.liveRooms.isEmpty &&
        state.currentTabIndex == 0) {
      return BilibiliContentErrorState(message: state.errorMessage ?? '加载失败');
    }

    if (state.liveRooms.isEmpty) {
      return const BilibiliContentEmptyState(currentTabIndex: 0);
    }

    return _buildLiveRoomGrid(state, state.liveRooms);
  }

  Widget _buildVideoTab(BilibiliContentState state) {
    if (state.status == BilibiliContentStatus.loading && state.videos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: kBilibiliBlue),
      );
    }
    if (state.status == BilibiliContentStatus.error &&
        state.videos.isEmpty &&
        state.currentTabIndex == 1) {
      return BilibiliContentErrorState(message: state.errorMessage ?? '加载失败');
    }

    // 即使列表为空，也显示排序和分类选项
    return Column(
      children: [
        // 排序和分类选项（始终显示在视频列表上方）
        Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
          child: _buildVideoSortAndCategoryOptions(state),
        ),
        Expanded(
          child: state.videos.isEmpty
              ? const BilibiliContentEmptyState(currentTabIndex: 1)
              : _buildVideoGrid(state, state.videos),
        ),
      ],
    );
  }

  Widget _buildLiveRoomGrid(
    BilibiliContentState state,
    List<LiveRoom> rooms,
  ) {
    if (rooms.isEmpty) {
      return const SizedBox.shrink();
    }

    // 计算行数（每行4个）
    final rows = (rooms.length / _itemsPerRow).ceil();

    final totalItems = state.liveRoomsTotal;
    final totalPages = (totalItems / _pageSize).ceil().clamp(1, 999);
    final currentPage = state.currentPage;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(4),
            itemCount: rows,
            itemBuilder: (context, rowIndex) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    for (int col = 0; col < _itemsPerRow; col++)
                      if (rowIndex * _itemsPerRow + col < rooms.length)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: col < _itemsPerRow - 1 ? 4 : 0,
                            ),
                            child: SizedBox(
                              height: 255,
                              child: _buildLiveRoomCard(
                                context,
                                state,
                                rooms[rowIndex * _itemsPerRow + col],
                              ),
                            ),
                          ),
                        )
                      else
                        const Expanded(child: SizedBox()),
                  ],
                ),
              );
            },
          ),
        ),
        // 分页组件
        if (totalItems > 0)
          _buildSimplePaginationBar(
            currentPage: currentPage,
            totalPages: totalPages,
            onPageChanged: (page) {
              context.read<BilibiliContentBloc>().add(
                BilibiliContentFetchRequested(
                  tabIndex: 0,
                  pageIndex: page,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSimplePaginationBar({
    required int currentPage,
    required int totalPages,
    required ValueChanged<int> onPageChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSimplePageButton(
            icon: Icons.chevron_left,
            enabled: currentPage > 1,
            onTap: () => onPageChanged(currentPage - 1),
          ),
          const SizedBox(width: 8),
          ..._buildSimplePageNumbers(currentPage, totalPages, onPageChanged),
          const SizedBox(width: 8),
          _buildSimplePageButton(
            icon: Icons.chevron_right,
            enabled: currentPage < totalPages,
            onTap: () => onPageChanged(currentPage + 1),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSimplePageNumbers(
    int currentPage,
    int totalPages,
    ValueChanged<int> onPageChanged,
  ) {
    final buttons = <Widget>[];
    const maxVisible = 5;

    if (totalPages <= maxVisible) {
      for (int i = 1; i <= totalPages; i++) {
        buttons.add(
          _buildSimplePageNumber(i, i == currentPage, () => onPageChanged(i)),
        );
      }
    } else {
      buttons.add(
        _buildSimplePageNumber(1, currentPage == 1, () => onPageChanged(1)),
      );

      if (currentPage > 3) {
        buttons.add(_buildSimpleEllipsis());
      }

      final start = (currentPage - 1).clamp(2, totalPages - 1);
      final end = (currentPage + 1).clamp(2, totalPages - 1);
      for (int i = start; i <= end; i++) {
        buttons.add(
          _buildSimplePageNumber(i, i == currentPage, () => onPageChanged(i)),
        );
      }

      if (currentPage < totalPages - 2) {
        buttons.add(_buildSimpleEllipsis());
      }

      buttons.add(
        _buildSimplePageNumber(
          totalPages,
          currentPage == totalPages,
          () => onPageChanged(totalPages),
        ),
      );
    }

    return buttons;
  }

  Widget _buildSimplePageNumber(int page, bool isActive, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _HoverableWidget(
      builder: (isHovered) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive
                ? kBilibiliBlue
                : (isHovered
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.06))
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03))),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? kBilibiliBlue
                  : (isHovered
                      ? kBilibiliBlue.withValues(alpha: 0.5)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.1))),
            ),
          ),
          child: Center(
            child: Text(
              '$page',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleEllipsis() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '...',
        style: TextStyle(color: _getInkColor(context).withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _buildSimplePageButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _HoverableWidget(
      builder: (isHovered) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: enabled
                ? (isHovered
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.06))
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03)))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: enabled
                  ? (isHovered
                      ? kBilibiliBlue.withValues(alpha: 0.5)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.1)))
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05)),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled
                ? (isHovered
                    ? kBilibiliBlue
                    : (isDark ? Colors.white70 : Colors.black87))
                : (isDark ? Colors.white30 : Colors.black38),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveRoomCard(
    BuildContext context,
    BilibiliContentState state,
    LiveRoom room,
  ) {
    return LiveRoomCard(
      room: room,
      isOwner: room.id == state.myLiveRoomId,
      coverUrl: room.displayCoverUrl,
      title: room.displayTitle,
      isRefreshing: state.isRefreshing,
      isLoadingBilibiliData: state.isLoadingBilibiliData,
      onToggle: room.id == state.myLiveRoomId
          ? (enabled) {
              context.read<BilibiliContentBloc>().add(
                BilibiliContentToggleLiveRoomRequested(
                  id: room.id,
                  enabled: enabled,
                ),
              );
            }
          : null,
      onTap: () {
        // 点击时增加点击数
        context.read<BilibiliContentBloc>().add(
          BilibiliContentIncreaseLiveRoomViewRequested(id: room.id),
        );
      },
    );
  }

  Widget _buildVideoGrid(
    BilibiliContentState state,
    List<BilibiliVideo> videos,
  ) {
    if (videos.isEmpty) {
      return const SizedBox.shrink();
    }

    // 计算行数（每行4个）
    final rows = (videos.length / _itemsPerRow).ceil();

    final totalItems = state.videosTotal;
    final totalPages = (totalItems / _pageSize).ceil().clamp(1, 999);
    final currentPage = state.currentPage;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _videoScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: rows,
            itemBuilder: (context, rowIndex) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    for (int col = 0; col < _itemsPerRow; col++)
                      if (rowIndex * _itemsPerRow + col < videos.length)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: col < _itemsPerRow - 1 ? 8 : 0,
                            ),
                            child: SizedBox(
                              height: 255,
                              child: VideoCard(
                                video: videos[rowIndex * _itemsPerRow + col],
                                isOwner: false,
                                onEdit: null,
                                onDelete: null,
                                isRefreshing: state.isRefreshing,
                                isLoadingBilibiliData: state.isLoadingBilibiliData,
                                onTap: () {
                                  context.read<BilibiliContentBloc>().add(
                                    BilibiliContentIncreaseVideoViewRequested(
                                      id: videos[rowIndex * _itemsPerRow + col].id,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                      else
                        const Expanded(child: SizedBox()),
                  ],
                ),
              );
            },
          ),
        ),
        // 简化分页组件
        if (totalItems > 0)
          _buildSimplePaginationBar(
            currentPage: currentPage,
            totalPages: totalPages,
            onPageChanged: (page) {
              context.read<BilibiliContentBloc>().add(
                BilibiliContentFetchRequested(
                  tabIndex: 1,
                  pageIndex: page,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildVideoSortAndCategoryOptions(BilibiliContentState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 2,
      children: [
        // 排序选项始终显示，带文字描述
        Row(
          mainAxisSize: MainAxisSize.min,
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
            _buildVideoSortOptions(state),
          ],
        ),
        const SizedBox(width: 8),
        // 分类选项：有数据时显示，无数据时不显示（但不隐藏排序）
        if (state.videoCategories.isNotEmpty) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '分类：',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              _buildVideoCategoryOptions(state),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildVideoCategoryOptions(BilibiliContentState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = state.videoCategories;
    final selectedCategoryId = state.videoCategoryFilter;

    return _HoverableWidget(
      builder: (isHovered) => Container(
        height: 32,
        decoration: BoxDecoration(
          color: isDark
              ? (isHovered
                    ? Colors.black.withValues(alpha: 0.8)
                    : Colors.black.withValues(alpha: 0.5))
              : (isHovered
                    ? Colors.white.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHovered
                ? kBilibiliBlue.withValues(alpha: 0.5)
                : (isDark ? Colors.white24 : Colors.black12),
          ),
          boxShadow: [
            if (isHovered)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCategoryOption('全部', null, selectedCategoryId, () {
                context.read<BilibiliContentBloc>().add(
                  const BilibiliContentVideoCategoryFilterChanged(null),
                );
              }),
              for (int i = 0; i < categories.length; i++) ...[
                Container(
                  width: 1,
                  height: 16,
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
                _buildCategoryOption(
                  categories[i].name,
                  categories[i].id,
                  selectedCategoryId,
                  () {
                    context.read<BilibiliContentBloc>().add(
                      BilibiliContentVideoCategoryFilterChanged(categories[i].id),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryOption(String label, int? categoryId, int? selectedCategoryId, VoidCallback onTap) {
    final isSelected = categoryId == selectedCategoryId;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? kBilibiliBlue
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoSortOptions(BilibiliContentState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNewest = state.videoSort == 'newest';

    return _HoverableWidget(
      builder: (isHovered) => Container(
        height: 32,
        decoration: BoxDecoration(
          color: isDark
              ? (isHovered
                    ? Colors.black.withValues(alpha: 0.8)
                    : Colors.black.withValues(alpha: 0.5))
              : (isHovered
                    ? Colors.white.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHovered
                ? kBilibiliBlue.withValues(alpha: 0.5)
                : (isDark ? Colors.white24 : Colors.black12),
          ),
          boxShadow: [
            if (isHovered)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortOption('默认', !isNewest, () {
              context.read<BilibiliContentBloc>().add(
                const BilibiliContentVideoSortChanged('view_count'),
              );
            }),
            Container(
              width: 1,
              height: 16,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            _buildSortOption('新添加', isNewest, () {
              context.read<BilibiliContentBloc>().add(
                const BilibiliContentVideoSortChanged('newest'),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? kBilibiliBlue
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}

/// Hover效果辅助widget
class _HoverableWidget extends StatefulWidget {
  final Widget Function(bool isHovered) builder;

  const _HoverableWidget({required this.builder});

  @override
  State<_HoverableWidget> createState() => _HoverableWidgetState();
}

class _HoverableWidgetState extends State<_HoverableWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.builder(_isHovered),
    );
  }
}

/// 浮动B站图标装饰组件
class _FloatingBilibiliIcons extends StatelessWidget {
  const _FloatingBilibiliIcons();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _FloatingBilibiliIcon(
          icon: Icons.play_circle_outline,
          size: 40,
          top: 0.10,
          left: 0.05,
          delay: 0,
          color: kBilibiliBlue,
        ),
        _FloatingBilibiliIcon(
          icon: Icons.people_outline,
          size: 36,
          top: 0.25,
          right: 0.08,
          delay: 600,
          color: kBilibiliPink, // B站粉色
        ),
        _FloatingBilibiliIcon(
          icon: Icons.verified_outlined,
          size: 32,
          bottom: 0.35,
          left: 0.10,
          delay: 1200,
          color: kBilibiliPink,
        ),
        _FloatingBilibiliIcon(
          icon: Icons.subscriptions_outlined,
          size: 38,
          top: 0.50,
          right: 0.05,
          delay: 1800,
          color: kBilibiliBlue,
        ),
        _FloatingBilibiliIcon(
          icon: Icons.thumb_up_outlined,
          size: 30,
          bottom: 0.20,
          right: 0.15,
          delay: 2400,
          color: kBilibiliPink,
        ),
        _FloatingBilibiliIcon(
          icon: Icons.star_outline,
          size: 34,
          top: 0.38,
          left: 0.07,
          delay: 3000,
          color: kBilibiliPink,
        ),
      ],
    );
  }
}

/// 单个浮动B站图标
class _FloatingBilibiliIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final int delay;
  final Color color;

  const _FloatingBilibiliIcon({
    required this.icon,
    required this.size,
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.delay,
    required this.color,
  });

  @override
  State<_FloatingBilibiliIcon> createState() => _FloatingBilibiliIconState();
}

class _FloatingBilibiliIconState extends State<_FloatingBilibiliIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _floatAnimation = Tween<double>(
      begin: 0,
      end: 12,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _rotateAnimation = Tween<double>(
      begin: -0.04,
      end: 0.04,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: widget.top != null ? screenSize.height * widget.top! : null,
      bottom: widget.bottom != null ? screenSize.height * widget.bottom! : null,
      left: widget.left != null ? screenSize.width * widget.left! : null,
      right: widget.right != null ? screenSize.width * widget.right! : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -_floatAnimation.value),
            child: Transform.rotate(
              angle: _rotateAnimation.value * math.pi,
              child: child,
            ),
          );
        },
        child: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.color.withValues(alpha: isDark ? 0.5 : 0.4),
              widget.color.withValues(alpha: isDark ? 0.3 : 0.2),
            ],
          ).createShader(bounds),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: isDark ? Colors.white.withValues(alpha: 0.7) : Colors.white,
          ),
        ),
      ),
    );
  }
}
