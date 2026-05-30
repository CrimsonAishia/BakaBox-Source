import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/core.dart';
import '../widgets/server_category_card.dart';
import '../widgets/smooth_server_list_item.dart';
import '../widgets/countdown_progress_bar.dart';
import '../widgets/server_history_modal.dart';

class ServersMobile extends StatefulWidget {
  const ServersMobile({super.key});

  @override
  State<ServersMobile> createState() => _ServersMobileState();
}

class _ServersMobileState extends State<ServersMobile>
    with TickerProviderStateMixin, WidgetsBindingObserver, PageLifecycleMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _pageTransitionController;
  late AnimationController _loadingController;
  late AnimationController _iconAnimationController;
  ServerBloc? _serverBloc;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pageTransitionController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _serverBloc = context.read<ServerBloc>();

    if (!_isInitialized) {
      _isInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final bloc = _serverBloc;
        if (bloc != null) {
          if (bloc.state.serverCategories.isEmpty && !bloc.state.isLoading) {
            bloc.add(ServerFetchList());
          }
          bloc.add(ServerStartPeriodicRefresh());
        }
        _loadingController.repeat();
      });
    }
  }

  @override
  void dispose() {
    _serverBloc?.add(ServerStopPeriodicRefresh());
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _pageTransitionController.dispose();
    _loadingController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  @override
  void onPageBecameActive() {
    super.onPageBecameActive();
    if (mounted) {
      context.read<ServerBloc>().add(ServerResumeRefresh());
    }
  }

  @override
  void onPageBecameInactive() {
    super.onPageBecameInactive();
    if (mounted) {
      context.read<ServerBloc>().add(ServerPauseRefresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    context.read<ServerBloc>().add(
      ServerLifecycleChanged(state == AppLifecycleState.resumed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: BlocBuilder<ServerBloc, ServerState>(
        builder: (context, state) {
          if (state.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<ServerBloc>().add(ServerFetchList()),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.3, end: 0);
          }

          return CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              _buildFixedAppBar(context, state),
              _buildContent(context, state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFixedAppBar(BuildContext context, ServerState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String title;
    String subtitle;

    if (state.isLoading && state.serverCategories.isEmpty) {
      title = '服务器管理';
      subtitle = '正在加载服务器信息...';
    } else if (state.selectedCategory != null) {
      title = state.selectedCategory!.modelName ?? '未知分类';
      subtitle = '${state.servers.length} 台服务器在线';
    } else {
      title = '服务器列表';
      subtitle = '${state.serverCategories.length} 个分类 · 选择开始浏览';
    }

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: theme.appBarTheme.backgroundColor,
      surfaceTintColor: theme.appBarTheme.backgroundColor,
      toolbarHeight: 80,
      automaticallyImplyLeading: false,
      expandedHeight: 80,
      collapsedHeight: 80,
      forceElevated: false,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: theme.appBarTheme.backgroundColor,
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.05),
              offset: const Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                if (state.selectedCategory != null) ...[
                  _buildBackButton(context),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: _buildTitleSection(
                    theme,
                    colorScheme,
                    title,
                    subtitle,
                    state,
                  ),
                ),
                if (!state.isLoading || state.serverCategories.isNotEmpty)
                  _buildCountdownProgress(state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF0080FF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF0080FF).withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF0080FF),
              size: 20,
            ),
            onPressed: () {
              context.read<ServerBloc>().add(ServerClearCategory());
              _pageTransitionController.reverse();
              _iconAnimationController.reset();
              _iconAnimationController.forward();
            },
          ),
        )
        .animate()
        .scale(
          begin: const Offset(0.8, 0.8),
          duration: 400.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 300.ms);
  }

  Widget _buildTitleSection(
    ThemeData theme,
    ColorScheme colorScheme,
    String title,
    String subtitle,
    ServerState state,
  ) {
    return Row(
      children: [
        Container(
              width: 56,
              height: 56,
              padding: const EdgeInsets.all(4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: state.selectedCategory != null
                        ? [
                            CategoryUtils.getCategoryColor(
                              state.selectedCategory?.modelName,
                            ),
                            CategoryUtils.getCategoryColor(
                              state.selectedCategory?.modelName,
                            ).withValues(alpha: 0.8),
                          ]
                        : [const Color(0xFF0080FF), const Color(0xFF00B4FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (state.selectedCategory != null
                                  ? CategoryUtils.getCategoryColor(
                                      state.selectedCategory?.modelName,
                                    )
                                  : const Color(0xFF0080FF))
                              .withValues(alpha: 0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: RotationTransition(
                        turns: Tween(begin: 0.0, end: 1.0).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.elasticOut,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    state.selectedCategory != null
                        ? CategoryUtils.getCategoryIcon(
                            state.selectedCategory?.modelName,
                          )
                        : Icons.public_rounded,
                    key: ValueKey(state.selectedCategory?.modelName ?? 'home'),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            )
            .animate(controller: _iconAnimationController)
            .scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1.0, 1.0),
              duration: 600.ms,
              curve: Curves.elasticOut,
            )
            .fadeIn(duration: 200.ms)
            .then()
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.05, 1.05),
              duration: 200.ms,
              curve: Curves.easeOut,
            )
            .then()
            .scale(
              begin: const Offset(1.05, 1.05),
              end: const Offset(1.0, 1.0),
              duration: 200.ms,
              curve: Curves.easeIn,
            )
            .then()
            .shimmer(
              duration: 1000.ms,
              delay: 100.ms,
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.3),
                Colors.white.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.appBarTheme.foregroundColor,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color:
                      theme.appBarTheme.foregroundColor?.withValues(
                        alpha: 0.7,
                      ) ??
                      colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.2,
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 80.ms),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownProgress(ServerState state) {
    // 只有在未暂停且倒计时激活时才运行
    final isActive = state.isCountdownActive && !state.isPaused;
    final categoryName = state.selectedCategory?.modelName ?? '';
    final isRefreshing = state.selectedCategory != null
        ? (state.isCategoryLoading(categoryName) || state.isLoadingServers)
        : state.isLoading;

    // 使用 countdownResetKey 和 categoryName 组合作为 key，确保分类切换或重置时重建组件
    final keyValue = 'countdown_${state.countdownResetKey}_$categoryName';

    return Container(
      padding: const EdgeInsets.all(8),
      child: CountdownProgressBar(
        key: ValueKey(keyValue),
        duration: 30,
        isActive: isActive,
        isRefreshing: isRefreshing,
        onComplete: () {
          // 使用 context.read 获取最新状态
          final currentState = context.read<ServerBloc>().state;
          if (currentState.selectedCategory != null) {
            // 在服务器列表页面，刷新服务器数据
            context.read<ServerBloc>().add(ServerRefreshServers());
          } else {
            // 在分类页面，刷新分类在线人数
            context.read<ServerBloc>().add(ServerUpdateCategoryOnlineCounts());
          }
        },
        onForceRefresh: () {
          // 手动点击时根据当前页面刷新
          final currentState = context.read<ServerBloc>().state;
          if (currentState.selectedCategory != null) {
            // 在服务器列表页面，强制刷新服务器数据
            context.read<ServerBloc>().add(ServerForceRefresh());
          } else {
            // 在分类页面，刷新分类在线人数
            context.read<ServerBloc>().add(ServerUpdateCategoryOnlineCounts());
          }
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ServerState state) {
    if (state.isLoading && state.serverCategories.isEmpty) {
      return SliverFillRemaining(child: _buildModernLoadingIndicator());
    }

    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Container(
        key: ValueKey(state.selectedCategory?.category ?? 'categories'),
        child: state.selectedCategory == null
            ? _buildCategoryGrid(context, state)
            : _buildServerGrid(context, state),
      ),
    );

    return SliverToBoxAdapter(child: content);
  }

  Widget _buildCategoryGrid(BuildContext context, ServerState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: state.serverCategories.length,
        itemBuilder: (context, index) {
          final category = state.serverCategories[index];
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 600),
            columnCount: 2,
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: ScaleAnimation(
                  scale: 0.9,
                  child: ServerCategoryCard(
                    category: category,
                    onTap: () {
                      context.read<ServerBloc>().add(
                        ServerSelectCategory(category),
                      );
                      _pageTransitionController.forward();
                      _iconAnimationController.reset();
                      _iconAnimationController.forward();
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServerGrid(BuildContext context, ServerState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: state.servers.length,
        itemBuilder: (context, index) {
          final server = state.servers[index];

          if (_searchController.text.isNotEmpty) {
            final searchTerm = _searchController.text.toLowerCase();
            final serverName = server.serverData?.hostName?.toLowerCase() ?? '';
            final mapName = server.serverData?.map?.toLowerCase() ?? '';
            if (!serverName.contains(searchTerm) &&
                !mapName.contains(searchTerm)) {
              return const SizedBox.shrink();
            }
          }

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 400),
            child: SlideAnimation(
              verticalOffset: 20.0,
              child: FadeInAnimation(
                child: SmoothServerListItem(
                  server: server,
                  index: index,
                  onTap: () {
                    ServerHistoryModal.show(context, server);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernLoadingIndicator() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF0080FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: const Color(0xFF0080FF).withValues(alpha: 0.2),
                      ),
                    )
                    .animate(onPlay: (controller) => controller.repeat())
                    .scale(duration: 1000.ms)
                    .fadeIn(duration: 500.ms),
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF0080FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
                '正在获取服务器列表',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF0080FF),
                  fontWeight: FontWeight.w500,
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .fadeIn(duration: 800.ms)
              .then(delay: 200.ms)
              .fadeOut(duration: 800.ms),
          const SizedBox(height: 8),
          Text(
            '请稍候...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
