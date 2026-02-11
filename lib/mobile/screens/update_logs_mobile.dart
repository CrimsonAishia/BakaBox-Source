import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../core/core.dart';
import '../widgets/update_log_item.dart';

class UpdateLogsMobile extends StatefulWidget {
  const UpdateLogsMobile({super.key});

  @override
  State<UpdateLogsMobile> createState() => _UpdateLogsMobileState();
}

class _UpdateLogsMobileState extends State<UpdateLogsMobile> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndFetchData();
    });
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() => setState(() {}));
  }

  void _checkAndFetchData() {
    final bloc = context.read<UpdateLogBloc>();
    // 每次进入页面都刷新数据
    if (!bloc.state.isLoading) {
      bloc.add(const UpdateLogFetch());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > 200;
    if (_showScrollToTop != shouldShow) setState(() => _showScrollToTop = shouldShow);
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      context.read<UpdateLogBloc>().add(UpdateLogLoadMore());
    }
  }

  void _scrollToTop() => _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () => context.read<UpdateLogBloc>().add(UpdateLogFetch(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<UpdateLogBloc, UpdateLogState>(
        builder: (context, state) {
          if (state.error != null && state.logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.withValues(alpha: 0.6)),
                  const SizedBox(height: 16),
                  Text(state.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<UpdateLogBloc>().add(UpdateLogClearError());
                      context.read<UpdateLogBloc>().add(UpdateLogFetch(_searchController.text));
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => context.read<UpdateLogBloc>().add(UpdateLogFetch(_searchController.text)),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildFixedAppBar(context, state),
                _buildContent(context, state),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 6,
              child: const Icon(Icons.keyboard_arrow_up_rounded, size: 28),
            ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.8, 0.8), duration: 200.ms)
          : null,
    );
  }

  Widget _buildFixedAppBar(BuildContext context, UpdateLogState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String title = '更新日志';
    String subtitle;
    if (state.isLoading && state.logs.isEmpty) {
      subtitle = '正在加载更新信息...';
    } else if (state.totalCount > 0) {
      subtitle = '共 ${state.totalCount} 条记录';
    } else {
      subtitle = '获取最新更新信息';
    }

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: theme.appBarTheme.backgroundColor,
      surfaceTintColor: theme.appBarTheme.backgroundColor,
      toolbarHeight: 80,
      automaticallyImplyLeading: false,
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
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        padding: const EdgeInsets.all(4),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                offset: const Offset(0, 4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.article_rounded, color: Colors.white, size: 24),
                        ),
                      )
                          .animate()
                          .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0), duration: 600.ms, curve: Curves.elasticOut)
                          .fadeIn(duration: 200.ms)
                          .then()
                          .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.05, 1.05), duration: 200.ms, curve: Curves.easeOut)
                          .then()
                          .scale(begin: const Offset(1.05, 1.05), end: const Offset(1.0, 1.0), duration: 200.ms, curve: Curves.easeIn)
                          .then()
                          .shimmer(duration: 1000.ms, delay: 100.ms, colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.3),
                            Colors.white.withValues(alpha: 0.8),
                            Colors.white.withValues(alpha: 0.3),
                            Colors.white.withValues(alpha: 0.0),
                          ]),
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
                                color: theme.appBarTheme.foregroundColor?.withValues(alpha: 0.7) ?? colorScheme.onSurface.withValues(alpha: 0.7),
                                height: 1.2,
                              ),
                            ).animate().fadeIn(duration: 300.ms, delay: 80.ms),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, UpdateLogState state) {
    if (state.isLoading && state.logs.isEmpty) {
      return SliverFillRemaining(child: _buildModernLoadingIndicator());
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        _buildSearchBox(context),
        if (state.logs.isEmpty)
          _buildEmptyState(context)
        else
          ...state.logs.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: UpdateLogItem(log: entry.value, isLatest: entry.key == 0),
              )),
        if (state.logs.isNotEmpty && state.hasMore) _buildLoadMore(state),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildSearchBox(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: '搜索更新内容...',
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.clear_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          onChanged: _onSearchChanged,
        ),
      ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SizedBox(
      height: math.max(200, MediaQuery.of(context).size.height - 200),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(Icons.article_outlined, size: 64, color: const Color(0xFFEF4444).withValues(alpha: 0.6)),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 24),
            Text(
              _searchController.text.isEmpty ? '暂无更新日志' : '没有找到相关内容',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isEmpty ? '等待系统更新信息' : '尝试使用其他关键词搜索',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ).animate().fadeIn(duration: 300.ms, delay: 150.ms),
            if (_searchController.text.isNotEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  context.read<UpdateLogBloc>().add(const UpdateLogFetch(''));
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('清除搜索'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMore(UpdateLogState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: state.isLoadingMore
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444))),
                    ),
                    SizedBox(height: 12),
                    Text('正在加载更多...', style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildModernLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
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
                    color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  ),
                ).animate(onPlay: (controller) => controller.repeat()).scale(duration: 1000.ms).fadeIn(duration: 500.ms),
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '正在获取更新日志',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFFEF4444), fontWeight: FontWeight.w500),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true)).fadeIn(duration: 800.ms).then(delay: 200.ms).fadeOut(duration: 800.ms),
          const SizedBox(height: 8),
          Text('请稍候...', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])).animate().fadeIn(delay: 300.ms, duration: 500.ms),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
