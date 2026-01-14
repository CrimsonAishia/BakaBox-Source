import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'dart:async';
import '../../core/core.dart';

/// Issue 列表移动端页面
class IssuesMobile extends StatefulWidget {
  const IssuesMobile({super.key});

  @override
  State<IssuesMobile> createState() => _IssuesMobileState();
}

class _IssuesMobileState extends State<IssuesMobile> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  bool _showScrollToTop = false;

  // 排序选项映射
  static const Map<String, String> _sortOptions = {
    'created_at DESC': '最新',
    'created_at ASC': '最早',
    'vote_count DESC': '最多投票',
    'comment_count DESC': '最多评论',
  };

  @override
  void initState() {
    super.initState();
    // IssueBloc 已在路由中初始化并触发 IssueFetch
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() => setState(() {}));
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
      final bloc = context.read<IssueBloc>();
      if (bloc.state.canLoadMore) {
        bloc.add(const IssueLoadMore());
      }
    }
  }

  void _scrollToTop() => _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () => context.read<IssueBloc>().add(IssueSearch(value)));
  }

  void _navigateToCreate() {
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) {
      ToastUtils.showWarning(context, '请先登录后再提交反馈');
      return;
    }
    context.push('/issues/create');
  }

  void _navigateToDetail(int issueId) {
    context.push('/issues/$issueId');
  }

  void _showSortSheet() {
    final currentSort = context.read<IssueBloc>().state.currentSort;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('排序方式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
            ),
            ..._sortOptions.entries.map((e) => ListTile(
              leading: Icon(
                currentSort == e.key ? Icons.radio_button_checked : Icons.radio_button_off,
                color: currentSort == e.key ? const Color(0xFF0080FF) : Colors.grey,
              ),
              title: Text(e.value),
              onTap: () {
                Navigator.pop(context);
                this.context.read<IssueBloc>().add(IssueSort(e.key));
              },
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<IssueBloc, IssueState>(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () async => context.read<IssueBloc>().add(const IssueRefresh()),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildAppBar(context, state),
                _buildContent(context, state),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showScrollToTop)
            FloatingActionButton.small(
              heroTag: 'scroll_top',
              onPressed: _scrollToTop,
              backgroundColor: Colors.grey.shade700,
              child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white),
            ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.8, 0.8), duration: 200.ms),
          if (_showScrollToTop) const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'create',
            onPressed: _navigateToCreate,
            backgroundColor: const Color(0xFF0080FF),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, IssueState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
          boxShadow: [BoxShadow(color: colorScheme.shadow.withValues(alpha: 0.05), offset: const Offset(0, 1), blurRadius: 3)],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                      gradient: const LinearGradient(colors: [Color(0xFF0080FF), Color(0xFF0066CC)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: const Color(0xFF0080FF).withValues(alpha: 0.3), offset: const Offset(0, 4), blurRadius: 12)],
                    ),
                    child: Icon(MdiIcons.commentQuestionOutline, color: Colors.white, size: 24),
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
                      Text('问题反馈', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.appBarTheme.foregroundColor)).animate().fadeIn(duration: 300.ms),
                      const SizedBox(height: 2),
                      Text(
                        state.isLoading ? '加载中...' : '共 ${state.totalCount} 条',
                        style: TextStyle(fontSize: 13, color: theme.appBarTheme.foregroundColor?.withValues(alpha: 0.7)),
                      ).animate().fadeIn(duration: 300.ms, delay: 80.ms),
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

  Widget _buildContent(BuildContext context, IssueState state) {
    if (state.isLoading && state.issues.isEmpty) {
      return SliverFillRemaining(child: _buildModernLoadingIndicator());
    }
    if (state.error != null && state.issues.isEmpty) {
      return SliverFillRemaining(child: _buildErrorState(state.error!));
    }
    return SliverList(
      delegate: SliverChildListDelegate([
        _buildSearchBox(context),
        _buildFilters(context, state),
        if (state.issues.isEmpty)
          _buildEmptyState(context)
        else
          AnimationLimiter(
            child: Column(
              children: state.issues.asMap().entries.map((entry) {
                return AnimationConfiguration.staggeredList(
                  position: entry.key,
                  duration: const Duration(milliseconds: 400),
                  child: SlideAnimation(
                    verticalOffset: 30.0,
                    child: FadeInAnimation(
                      child: _buildIssueItem(context, entry.value),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        if (state.issues.isNotEmpty) _buildBottomIndicator(state),
        const SizedBox(height: 80),
      ]),
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
                ).animate(onPlay: (controller) => controller.repeat()).scale(duration: 1000.ms).fadeIn(duration: 500.ms),
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0080FF)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '正在加载问题列表',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF0080FF),
              fontWeight: FontWeight.w500,
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true)).fadeIn(duration: 800.ms).then(delay: 200.ms).fadeOut(duration: 800.ms),
          const SizedBox(height: 8),
          Text(
            '请稍候...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
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
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: '搜索问题...',
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
                      onPressed: () { _searchController.clear(); _onSearchChanged(''); },
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

  Widget _buildFilters(BuildContext context, IssueState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        children: [
          // 类型筛选
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(context, '全部', state.currentType == null, () => context.read<IssueBloc>().add(const IssueFilterType(null))),
                _buildFilterChip(context, 'Bug', state.currentType == 'bug', () => context.read<IssueBloc>().add(const IssueFilterType('bug')), color: const Color(0xFFDC2626), icon: MdiIcons.bug),
                _buildFilterChip(context, '功能建议', state.currentType == 'feature', () => context.read<IssueBloc>().add(const IssueFilterType('feature')), color: const Color(0xFF2563EB), icon: MdiIcons.lightbulbOnOutline),
                _buildFilterChip(context, '问题', state.currentType == 'question', () => context.read<IssueBloc>().add(const IssueFilterType('question')), color: const Color(0xFF059669), icon: MdiIcons.helpCircleOutline),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 状态和排序
          Row(
            children: [
              _buildStatusChip(context, '开放', state.currentStatus == 'open', () => context.read<IssueBloc>().add(const IssueFilterStatus('open')), icon: MdiIcons.checkCircleOutline, activeColor: const Color(0xFF16A34A)),
              const SizedBox(width: 8),
              _buildStatusChip(context, '已关闭', state.currentStatus == 'closed', () => context.read<IssueBloc>().add(const IssueFilterStatus('closed')), icon: MdiIcons.closeCircleOutline, activeColor: const Color(0xFF6B7280)),
              const Spacer(),
              // 排序按钮
              GestureDetector(
                onTap: _showSortSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(MdiIcons.sortVariant, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(_sortOptions[state.currentSort] ?? '排序', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, bool isSelected, VoidCallback onTap, {Color? color, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? (color ?? const Color(0xFF0080FF)) : Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? (color ?? const Color(0xFF0080FF)) : Theme.of(context).dividerColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: isSelected ? Colors.white : (color ?? Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(width: 5),
              ],
              Text(label, style: TextStyle(color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String label, bool isSelected, VoidCallback onTap, {IconData? icon, Color? activeColor}) {
    final color = activeColor ?? const Color(0xFF0080FF);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
            ],
            Text(label, style: TextStyle(color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueItem(BuildContext context, IssueListItem issue) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToDetail(issue.id),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildTypeTag(issue.issueType),
                    const SizedBox(width: 8),
                    _buildStatusTag(issue.issueStatus),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
                      child: Text('#${issue.id}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(issue.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      backgroundImage: issue.authorAvatar != null ? NetworkImage(issue.authorAvatar!) : null,
                      child: issue.authorAvatar == null
                          ? Text(issue.authorName.isNotEmpty ? issue.authorName[0].toUpperCase() : '?', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant))
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Text(issue.authorName, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(width: 12),
                    Icon(MdiIcons.clockOutline, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(Formatters.formatRelativeTime(issue.createdAt), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                    const Spacer(),
                    _buildStatBadge(context, MdiIcons.thumbUpOutline, issue.voteCount),
                    const SizedBox(width: 10),
                    _buildStatBadge(context, MdiIcons.commentOutline, issue.commentCount),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(BuildContext context, IconData icon, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text('$count', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTypeTag(IssueType type) {
    final (color, bgColor, icon) = switch (type) {
      IssueType.bug => (const Color(0xFFDC2626), const Color(0xFFFEE2E2), MdiIcons.bug),
      IssueType.feature => (const Color(0xFF2563EB), const Color(0xFFDBEAFE), MdiIcons.lightbulbOnOutline),
      IssueType.question => (const Color(0xFF059669), const Color(0xFFD1FAE5), MdiIcons.helpCircleOutline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(type.label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatusTag(IssueStatus status) {
    final isOpen = status.isOpen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: isOpen ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: isOpen ? const Color(0xFF16A34A) : const Color(0xFF6B7280), shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(status.label, style: TextStyle(color: isOpen ? const Color(0xFF16A34A) : const Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isSearching = _searchController.text.isNotEmpty;
    return Container(
      height: 300,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Icon(isSearching ? Icons.search_off : MdiIcons.commentQuestionOutline, size: 36, color: const Color(0xFF3B82F6)),
            ),
            const SizedBox(height: 20),
            Text(isSearching ? '没有找到相关问题' : '暂无问题反馈', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(isSearching ? '尝试使用其他关键词搜索' : '成为第一个提出反馈的人吧', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
            const SizedBox(height: 20),
            if (!isSearching)
              ElevatedButton.icon(
                onPressed: _navigateToCreate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('提交反馈'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0080FF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              )
            else
              TextButton.icon(
                onPressed: () { _searchController.clear(); _onSearchChanged(''); },
                icon: Icon(MdiIcons.close, size: 18),
                label: const Text('清除搜索'),
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(36)),
              child: Icon(MdiIcons.alertCircleOutline, size: 36, color: const Color(0xFFDC2626)),
            ),
            const SizedBox(height: 20),
            const Text('加载失败', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(MdiIcons.informationOutline, size: 16, color: const Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Flexible(child: Text(error, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13), textAlign: TextAlign.center)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.read<IssueBloc>().add(const IssueFetch()),
              icon: Icon(MdiIcons.refresh, size: 18),
              label: const Text('重新加载'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0080FF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomIndicator(IssueState state) {
    if (state.isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0080FF))),
              const SizedBox(width: 10),
              Text('加载更多...', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    if (!state.hasMore && state.issues.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(MdiIcons.checkCircleOutline, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text('已显示全部 ${state.totalCount} 条', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
