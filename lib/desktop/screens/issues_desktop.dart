import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../core/core.dart';
import '../../core/services/quill_delta_codec.dart';
import '../widgets/page_layout.dart';

/// Issue 页面视图类型
enum _IssueView { list, detail, create }

/// Issue 列表桌面端页面
/// 
/// 使用局部 BlocProvider 提供 IssueBloc 和 IssueDetailBloc（懒加载优化）
class IssuesDesktop extends StatelessWidget {
  const IssuesDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => IssueBloc()),
        BlocProvider(create: (_) => IssueDetailBloc()),
      ],
      child: const _IssuesDesktopContent(),
    );
  }
}

/// Issue 页面内容
class _IssuesDesktopContent extends StatefulWidget {
  const _IssuesDesktopContent();

  @override
  State<_IssuesDesktopContent> createState() => _IssuesDesktopContentState();
}

class _IssuesDesktopContentState extends State<_IssuesDesktopContent> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  // 当前视图状态
  _IssueView _currentView = _IssueView.list;
  int? _selectedIssueId;

  // 骨架屏延迟显示控制（避免快速加载时闪烁）
  bool _showSkeleton = false;
  Timer? _skeletonTimer;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 每次进入页面检查是否需要加载数据
      final bloc = context.read<IssueBloc>();
      if (!bloc.state.isLoading && bloc.state.issues.isEmpty) {
        bloc.add(const IssueFetch());
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    _skeletonTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final bloc = context.read<IssueBloc>();
      if (bloc.state.canLoadMore) bloc.add(const IssueLoadMore());
    }
  }

  void _performSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      context.read<IssueBloc>().add(IssueSearch(query));
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
    context.read<IssueBloc>().add(const IssueSearch(''));
  }

  void _navigateToCreate() {
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) {
      ToastUtils.showWarning(context, '请先登录后再提交反馈');
      return;
    }
    setState(() => _currentView = _IssueView.create);
  }

  void _navigateToDetail(int issueId) {
    setState(() {
      _currentView = _IssueView.detail;
      _selectedIssueId = issueId;
    });
    context.read<IssueDetailBloc>().add(IssueDetailFetch(issueId));
  }

  void _navigateToList() {
    setState(() {
      _currentView = _IssueView.list;
      _selectedIssueId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
      body: PageLayout(
        title: _getTitle(),
        subtitle: _getSubtitle(),
        headerActions: _buildHeaderActions(),
        child: _buildContent(),
      ),
    );
  }

  String _getTitle() {
    return switch (_currentView) {
      _IssueView.list => '问题反馈',
      _IssueView.detail => '#$_selectedIssueId',
      _IssueView.create => '提交反馈',
    };
  }

  String _getSubtitle() {
    return switch (_currentView) {
      _IssueView.list => '反馈问题和功能建议',
      _IssueView.detail => '查看详情',
      _IssueView.create => '反馈问题或提出建议',
    };
  }

  Widget _buildHeaderActions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_currentView != _IssueView.list) {
      return TextButton.icon(
        onPressed: _navigateToList,
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text('返回列表'),
        style: TextButton.styleFrom(foregroundColor: isDark ? Colors.white54 : const Color(0xFF6B7280)),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [_buildSearchBox(), const SizedBox(width: 12), _buildCreateButton()],
    );
  }

  Widget _buildContent() {
    return switch (_currentView) {
      _IssueView.list => _buildListView(),
      _IssueView.detail => _IssueDetailView(issueId: _selectedIssueId!, onBack: _navigateToList),
      _IssueView.create => _IssueCreateView(onBack: _navigateToList, onCreated: (id) {
        context.read<IssueBloc>().add(const IssueRefresh());
        _navigateToDetail(id);
      }),
    };
  }

  Widget _buildSearchBox() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 240, height: 36,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : null),
        decoration: InputDecoration(
          hintText: '搜索问题...', hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF9CA3AF), fontSize: 14),
          prefixIcon: Icon(Icons.search, size: 18, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: _clearSearch, padding: EdgeInsets.zero, constraints: const BoxConstraints(), color: isDark ? Colors.white38 : const Color(0xFF9CA3AF))
              : null,
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 8), isDense: true,
        ),
        onChanged: (value) { setState(() {}); _performSearch(value); },
      ),
    );
  }

  Widget _buildCreateButton() {
    return ElevatedButton.icon(
      onPressed: _navigateToCreate,
      icon: const Icon(Icons.add, size: 18), label: const Text('提交反馈'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0080FF), foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 2,
      ),
    );
  }

  Widget _buildListView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
      ),
      child: Column(children: [_buildFilters(), Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)), Expanded(child: _buildIssueList())]),
    );
  }

  Widget _buildFilters() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<IssueBloc, IssueState>(
      buildWhen: (prev, curr) => prev.currentType != curr.currentType || prev.currentStatus != curr.currentStatus || prev.currentSort != curr.currentSort || prev.totalCount != curr.totalCount || prev.showMine != curr.showMine,
      builder: (context, state) {
        final authState = context.watch<AuthBloc>().state;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: [
            // 全部/我的 切换
            _buildViewSwitch(state.showMine, authState.isAuthenticated),
            const SizedBox(width: 12), Container(width: 1, height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)), const SizedBox(width: 12),
            // 类型筛选
            _buildCompactFilterChips(
              items: [_FilterItem(null, '全部', null), _FilterItem('bug', 'Bug', MdiIcons.bug), _FilterItem('feature', '建议', MdiIcons.lightbulbOnOutline), _FilterItem('question', '问题', MdiIcons.helpCircleOutline)],
              selected: state.currentType,
              onSelected: (type) => context.read<IssueBloc>().add(IssueFilterType(type)),
            ),
            const SizedBox(width: 8),
            // 状态筛选
            _buildStatusChips(state.currentStatus, (v) => context.read<IssueBloc>().add(IssueFilterStatus(v))),
            const SizedBox(width: 8),
            // 排序
            _buildCompactDropdown(value: state.currentSort, items: _sortOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) { if (v != null) context.read<IssueBloc>().add(IssueSort(v)); }),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
              child: Text('${state.totalCount}条', style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildCompactFilterChips({required List<_FilterItem> items, required String? selected, required ValueChanged<String?> onSelected}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(mainAxisSize: MainAxisSize.min, children: items.map((item) {
      final isSelected = item.value == selected;
      return Padding(padding: const EdgeInsets.only(right: 4), child: Material(color: Colors.transparent, child: InkWell(
        onTap: () => onSelected(item.value), borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: isSelected ? const Color(0xFF0080FF) : (isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6)), borderRadius: BorderRadius.circular(6)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (item.icon != null) ...[Icon(item.icon, size: 12, color: isSelected ? Colors.white : (isDark ? Colors.white54 : const Color(0xFF6B7280))), const SizedBox(width: 4)],
            Text(item.label, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF374151)), fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
          ]),
        ),
      )));
    }).toList());
  }

  Widget _buildCompactDropdown({required String value, required List<DropdownMenuItem<String>> items, required ValueChanged<String?> onChanged}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, items: items, onChanged: onChanged, style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF374151), fontSize: 12, fontWeight: FontWeight.w500), isDense: true, icon: Icon(Icons.keyboard_arrow_down, size: 16, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)), dropdownColor: isDark ? const Color(0xFF1E293B) : null)),
    );
  }

  Widget _buildStatusChips(String currentStatus, ValueChanged<String> onChanged) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _buildStatusChip('open', '开放', MdiIcons.checkCircleOutline, const Color(0xFF16A34A), currentStatus == 'open', () => onChanged('open')),
      const SizedBox(width: 4),
      _buildStatusChip('closed', '已关闭', MdiIcons.closeCircleOutline, const Color(0xFF6B7280), currentStatus == 'closed', () => onChanged('closed')),
      const SizedBox(width: 4),
      _buildStatusChip('all', '全部', MdiIcons.formatListBulleted, const Color(0xFF6B7280), currentStatus == 'all', () => onChanged('all')),
    ]);
  }

  Widget _buildStatusChip(String value, String label, IconData icon, Color color, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(color: Colors.transparent, child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : (isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? color : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: isSelected ? color : (isDark ? Colors.white54 : const Color(0xFF6B7280))),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: isSelected ? color : (isDark ? Colors.white70 : const Color(0xFF374151)), fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
        ]),
      ),
    ));
  }

  Widget _buildViewSwitch(bool showMine, bool isAuthenticated) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _buildViewTab('全部', !showMine, () => context.read<IssueBloc>().add(const IssueSwitchView(false))),
      const SizedBox(width: 2),
      _buildViewTab('我的', showMine, isAuthenticated ? () => context.read<IssueBloc>().add(const IssueSwitchView(true)) : () => ToastUtils.showWarning(context, '请先登录')),
    ]);
  }

  Widget _buildViewTab(String label, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(color: Colors.transparent, child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0080FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white54 : const Color(0xFF6B7280)), fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
      ),
    ));
  }

  Widget _buildIssueList() {
    return BlocConsumer<IssueBloc, IssueState>(
      listenWhen: (prev, curr) => prev.isLoading != curr.isLoading,
      listener: (context, state) {
        // 延迟显示骨架屏，避免快速加载时闪烁
        if (state.isLoading && state.issues.isEmpty) {
          _skeletonTimer?.cancel();
          _skeletonTimer = Timer(const Duration(milliseconds: 200), () {
            if (mounted) setState(() => _showSkeleton = true);
          });
        } else {
          _skeletonTimer?.cancel();
          if (_showSkeleton) setState(() => _showSkeleton = false);
        }
      },
      buildWhen: (prev, curr) => prev.isLoading != curr.isLoading || prev.issues != curr.issues || prev.error != curr.error || prev.isLoadingMore != curr.isLoadingMore || prev.hasMore != curr.hasMore,
      builder: (context, state) {
        if (state.isLoading && state.issues.isEmpty) {
          // 只有延迟后才显示骨架屏
          return _showSkeleton ? _buildLoadingSkeleton() : const SizedBox.shrink();
        }
        if (state.error != null && state.issues.isEmpty) return _buildErrorState(state.error!);
        if (state.issues.isEmpty) return _buildEmptyState();
        return _buildList(state);
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(padding: const EdgeInsets.all(20), itemCount: 5, itemBuilder: (context, index) => _buildSkeletonItem());
  }

  Widget _buildSkeletonItem() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(width: 60, height: 22, decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200, borderRadius: BorderRadius.circular(4))), const SizedBox(width: 10), Container(width: 50, height: 22, decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200, borderRadius: BorderRadius.circular(4))), const SizedBox(width: 16), Expanded(child: Container(height: 20, decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200, borderRadius: BorderRadius.circular(4))))]),
        const SizedBox(height: 14),
        Row(children: [Container(width: 100, height: 14, decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200, borderRadius: BorderRadius.circular(4))), const Spacer(), Container(width: 80, height: 14, decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200, borderRadius: BorderRadius.circular(4)))]),
      ]),
    );
  }

  Widget _buildErrorState(String error) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(child: Container(constraints: const BoxConstraints(maxWidth: 400), padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80, decoration: BoxDecoration(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(40)), child: Icon(MdiIcons.alertCircleOutline, size: 40, color: const Color(0xFFDC2626))),
      const SizedBox(height: 24), Text('加载失败', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1F2937))),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? const Color(0xFFDC2626).withValues(alpha: 0.3) : const Color(0xFFFECACA))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(MdiIcons.informationOutline, size: 16, color: const Color(0xFFDC2626)), const SizedBox(width: 8), Flexible(child: Text(error, style: TextStyle(color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626), fontSize: 14), textAlign: TextAlign.center))])),
      const SizedBox(height: 24),
      ElevatedButton.icon(onPressed: () => context.read<IssueBloc>().add(const IssueFetch()), icon: Icon(MdiIcons.refresh, size: 18), label: const Text('重新加载'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0080FF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
    ])));
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSearching = _searchController.text.isNotEmpty;
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80, decoration: BoxDecoration(color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(40)), child: Icon(isSearching ? Icons.search_off : MdiIcons.commentQuestionOutline, size: 40, color: const Color(0xFF3B82F6))),
      const SizedBox(height: 24), Text(isSearching ? '没有找到相关问题' : '暂无问题反馈', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1F2937))),
      const SizedBox(height: 8), Text(isSearching ? '尝试使用其他关键词搜索' : '成为第一个提出反馈的人吧', style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF6B7280), fontSize: 14)),
      const SizedBox(height: 24),
      if (!isSearching) ElevatedButton.icon(onPressed: _navigateToCreate, icon: const Icon(Icons.add, size: 18), label: const Text('提交反馈'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0080FF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))
      else TextButton.icon(onPressed: _clearSearch, icon: Icon(MdiIcons.close, size: 18), label: const Text('清除搜索'), style: TextButton.styleFrom(foregroundColor: isDark ? Colors.white54 : const Color(0xFF6B7280))),
    ]));
  }

  Widget _buildList(IssueState state) {
    return Column(children: [
      Expanded(
        child: Scrollbar(controller: _scrollController, thumbVisibility: true, child: ListView.builder(
          controller: _scrollController, padding: const EdgeInsets.all(16), itemCount: state.issues.length,
          itemBuilder: (context, index) => _buildIssueItem(state.issues[index]),
        )),
      ),
      if (state.totalPages > 1) _buildPagination(state),
    ]);
  }

  Widget _buildPagination(IssueState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB))),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        // 上一页
        _buildPageButton(
          icon: Icons.chevron_left,
          onTap: state.currentPage > 1 ? () => context.read<IssueBloc>().add(IssueGoToPage(state.currentPage - 1)) : null,
        ),
        const SizedBox(width: 8),
        // 页码
        ..._buildPageNumbers(state),
        const SizedBox(width: 8),
        // 下一页
        _buildPageButton(
          icon: Icons.chevron_right,
          onTap: state.currentPage < state.totalPages ? () => context.read<IssueBloc>().add(IssueGoToPage(state.currentPage + 1)) : null,
        ),
      ]),
    );
  }

  List<Widget> _buildPageNumbers(IssueState state) {
    final pages = <Widget>[];
    final totalPages = state.totalPages;
    final currentPage = state.currentPage;
    
    // 简化的分页逻辑：显示首页、当前页附近、末页
    final pagesToShow = <int>{};
    pagesToShow.add(1);
    pagesToShow.add(totalPages);
    for (int i = currentPage - 1; i <= currentPage + 1; i++) {
      if (i >= 1 && i <= totalPages) pagesToShow.add(i);
    }
    
    final sortedPages = pagesToShow.toList()..sort();
    int? lastPage;
    
    for (final page in sortedPages) {
      if (lastPage != null && page - lastPage > 1) {
        pages.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(color: Color(0xFF9CA3AF))),
        ));
      }
      pages.add(_buildPageNumber(page, page == currentPage));
      lastPage = page;
    }
    
    return pages;
  }

  Widget _buildPageNumber(int page, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSelected ? null : () => context.read<IssueBloc>().add(IssueGoToPage(page)),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 32, height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0080FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$page', style: TextStyle(
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF374151)),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            )),
          ),
        ),
      ),
    );
  }

  Widget _buildPageButton({required IconData icon, VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32, height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: isDisabled ? (isDark ? Colors.white24 : const Color(0xFFD1D5DB)) : (isDark ? Colors.white70 : const Color(0xFF374151))),
        ),
      ),
    );
  }

  Widget _buildIssueItem(IssueListItem issue) {
    return _IssueCard(
      issue: issue,
      onTap: () => _navigateToDetail(issue.id),
    );
  }
}

class _FilterItem {
  final String? value;
  final String label;
  final IconData? icon;
  _FilterItem(this.value, this.label, [this.icon]);
}

/// Issue 卡片组件（带 hover 效果）
class _IssueCard extends StatefulWidget {
  final IssueListItem issue;
  final VoidCallback onTap;
  const _IssueCard({required this.issue, required this.onTap});

  @override
  State<_IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends State<_IssueCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered 
                ? (isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC))
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _isHovered ? const Color(0xFF0080FF).withValues(alpha: 0.3) : (isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB))),
            boxShadow: [
              BoxShadow(
                color: _isHovered ? const Color(0xFF0080FF).withValues(alpha: 0.08) : Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
                blurRadius: _isHovered ? 12 : 6,
                offset: Offset(0, _isHovered ? 4 : 2),
              ),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _buildTypeTag(widget.issue.issueType),
              const SizedBox(width: 8),
              _buildStatusTag(widget.issue.issueStatus),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.issue.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _isHovered ? const Color(0xFF0080FF) : (isDark ? Colors.white : const Color(0xFF1F2937))), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)), child: Text('#${widget.issue.id}', style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w500))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _buildAuthorInfo(widget.issue.authorName, widget.issue.authorAvatar, isDark),
              const SizedBox(width: 16),
              _buildMetaItem(MdiIcons.clockOutline, Formatters.formatRelativeTime(widget.issue.createdAt), isDark),
              const Spacer(),
              _buildStatItem(MdiIcons.thumbUpOutline, widget.issue.voteCount, isDark),
              const SizedBox(width: 12),
              _buildStatItem(MdiIcons.commentOutline, widget.issue.commentCount, isDark),
            ]),
          ]),
        ),
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
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(type.label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildStatusTag(IssueStatus status) {
    final isOpen = status.isOpen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: isOpen ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: isOpen ? const Color(0xFF16A34A) : const Color(0xFF6B7280), shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(status.label, style: TextStyle(color: isOpen ? const Color(0xFF16A34A) : const Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildMetaItem(IconData icon, String text, bool isDark) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF6B7280), fontSize: 12)),
    ]);
  }

  Widget _buildAuthorInfo(String authorName, String? authorAvatar, bool isDark) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      CircleAvatar(
        radius: 10,
        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        backgroundImage: authorAvatar != null ? NetworkImage(authorAvatar) : null,
        child: authorAvatar == null
            ? Text(authorName.isNotEmpty ? authorName[0].toUpperCase() : '?', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : const Color(0xFF6B7280)))
            : null,
      ),
      const SizedBox(width: 6),
      Text(authorName, style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF6B7280), fontSize: 12)),
    ]);
  }

  Widget _buildStatItem(IconData icon, int count, bool isDark) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
      const SizedBox(width: 3),
      Text('$count', style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w500)),
    ]);
  }
}


/// Issue 详情视图（内嵌在 IssuesDesktop 中）
class _IssueDetailView extends StatefulWidget {
  final int issueId;
  final VoidCallback onBack;
  const _IssueDetailView({required this.issueId, required this.onBack});

  @override
  State<_IssueDetailView> createState() => _IssueDetailViewState();
}

class _IssueDetailViewState extends State<_IssueDetailView> {
  final _commentController = quill.QuillController.basic();
  final _scrollController = ScrollController();
  final _commentEditorKey = GlobalKey<RichTextEditorState>();
  List<String> _commentImageUrls = [];

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submitComment() {
    final content = QuillDeltaCodec.encode(_commentController.document);
    if (_commentController.document.toPlainText().trim().isEmpty) { ToastUtils.showWarning(context, '请输入评论内容'); return; }
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) { ToastUtils.showWarning(context, '请先登录后再评论'); return; }
    // 设置当前用户信息用于构建评论
    context.read<IssueDetailBloc>().add(IssueDetailSetUser(authState.userInfo));
    context.read<IssueDetailBloc>().add(IssueDetailAddComment(content, images: _commentImageUrls));
    _commentController.clear();
    _commentEditorKey.currentState?.clearImages();
    setState(() {
      _commentImageUrls = [];
    });
  }

  void _toggleVote() {
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) { ToastUtils.showWarning(context, '请先登录后再投票'); return; }
    context.read<IssueDetailBloc>().add(const IssueDetailToggleVote());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<IssueDetailBloc, IssueDetailState>(
      listener: (context, state) {
        if (state.error != null) { ToastUtils.showError(context, state.error!); context.read<IssueDetailBloc>().add(const IssueDetailClearError()); }
        if (state.successMessage != null) { ToastUtils.showSuccess(context, state.successMessage!); context.read<IssueDetailBloc>().add(const IssueDetailClearError()); }
      },
      builder: (context, state) {
        if (state.isLoading) return const Center(child: CircularProgressIndicator());
        if (state.issue == null) return _buildError(state.error);
        return _buildContent(state);
      },
    );
  }

  Widget _buildError(String? error) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(child: Container(constraints: const BoxConstraints(maxWidth: 400), padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80, decoration: BoxDecoration(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(40)), child: Icon(MdiIcons.alertCircleOutline, size: 40, color: const Color(0xFFDC2626))),
      const SizedBox(height: 24), Text('加载失败', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1F2937))),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? const Color(0xFFDC2626).withValues(alpha: 0.3) : const Color(0xFFFECACA))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(MdiIcons.informationOutline, size: 16, color: const Color(0xFFDC2626)), const SizedBox(width: 8), Flexible(child: Text(error ?? '问题不存在或加载失败', style: TextStyle(color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626), fontSize: 14), textAlign: TextAlign.center))])),
      const SizedBox(height: 24),
      ElevatedButton.icon(onPressed: () => context.read<IssueDetailBloc>().add(IssueDetailFetch(widget.issueId)), icon: Icon(MdiIcons.refresh, size: 18), label: const Text('重新加载'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0080FF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
    ])));
  }

  Widget _buildContent(IssueDetailState state) {
    final issue = state.issue!;
    return Scrollbar(controller: _scrollController, thumbVisibility: true, child: SingleChildScrollView(controller: _scrollController, padding: const EdgeInsets.all(0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildIssueCard(issue, state), const SizedBox(height: 20), _buildCommentsSection(state), const SizedBox(height: 20), if (issue.issueStatus.isOpen) _buildCommentInput(state), if (issue.issueStatus.isOpen) const SizedBox(height: 20),
    ])));
  }

  Widget _buildIssueCard(Issue issue, IssueDetailState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [_buildTypeTag(issue.issueType), const SizedBox(width: 8), _buildStatusTag(issue.issueStatus), const Spacer(), Text('#${issue.id}', style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF9CA3AF), fontSize: 14))]),
      const SizedBox(height: 16), Text(issue.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1F2937))),
      const SizedBox(height: 16),
      Row(children: [
        CircleAvatar(radius: 16, backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB), backgroundImage: issue.authorAvatar != null ? NetworkImage(issue.authorAvatar!) : null, child: issue.authorAvatar == null ? Text(issue.authorName[0].toUpperCase(), style: const TextStyle(fontSize: 14)) : null),
        const SizedBox(width: 10), Text(issue.authorName, style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : const Color(0xFF374151))),
        const SizedBox(width: 8), Text('创建于 ${Formatters.formatDateTime(issue.createdAt.toIso8601String())}', style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF9CA3AF), fontSize: 13)),
      ]),
      const SizedBox(height: 20), Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6)), const SizedBox(height: 20),
      RichTextViewer(
        content: issue.content,
        textStyle: TextStyle(fontSize: 15, height: 1.7, color: isDark ? Colors.white70 : const Color(0xFF374151)),
      ),
      if (issue.images.isNotEmpty) ...[const SizedBox(height: 16), ImageGrid(imageUrls: issue.images, imageWidth: 200, imageHeight: 150, spacing: 12)],
      if (issue.deviceInfo != null) ...[const SizedBox(height: 16), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(MdiIcons.informationOutline, size: 16, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)), const SizedBox(width: 8), Text('${issue.deviceInfo!.appVersion} · ${issue.deviceInfo!.platform} · ${issue.deviceInfo!.osVersion}', style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF6B7280), fontSize: 13))]))],
      const SizedBox(height: 20), Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6)), const SizedBox(height: 16),
      Row(children: [_buildVoteButton(issue, state), const SizedBox(width: 12), _buildCommentCountBadge(issue), const Spacer(), _buildCloseButton(issue, state)]),
    ]));
  }

  Widget _buildTypeTag(IssueType type) {
    final (color, bgColor) = switch (type) { IssueType.bug => (const Color(0xFFDC2626), const Color(0xFFFEE2E2)), IssueType.feature => (const Color(0xFF2563EB), const Color(0xFFDBEAFE)), IssueType.question => (const Color(0xFF059669), const Color(0xFFD1FAE5)) };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)), child: Text(type.label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)));
  }

  Widget _buildStatusTag(IssueStatus status) {
    final isOpen = status.isOpen;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isOpen ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)), child: Text(status.label, style: TextStyle(color: isOpen ? const Color(0xFF16A34A) : const Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500)));
  }

  Widget _buildVoteButton(Issue issue, IssueDetailState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton.icon(onPressed: state.isSubmitting ? null : _toggleVote, icon: Icon(issue.isVoted ? MdiIcons.thumbUp : MdiIcons.thumbUpOutline, size: 18), label: Text('${issue.voteCount}'), style: OutlinedButton.styleFrom(foregroundColor: issue.isVoted ? const Color(0xFF0080FF) : (isDark ? Colors.white54 : const Color(0xFF6B7280)), side: BorderSide(color: issue.isVoted ? const Color(0xFF0080FF) : (isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB))), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)));
  }

  Widget _buildCommentCountBadge(Issue issue) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(children: [Icon(MdiIcons.commentOutline, size: 18, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)), const SizedBox(width: 6), Text('${issue.commentCount} 条评论', style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF6B7280), fontSize: 14))]);
  }

  Widget _buildCloseButton(Issue issue, IssueDetailState state) {
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) return const SizedBox.shrink();
    
    // 使用后端用户ID判断是否为作者
    final backendUserInfo = TokenService.instance.userInfo;
    final isAuthor = backendUserInfo != null && backendUserInfo.id == issue.authorId;
    
    // 如果不是作者，不显示按钮
    if (!isAuthor) return const SizedBox.shrink();
    
    final isOpen = issue.issueStatus.isOpen;
    return ElevatedButton.icon(
      onPressed: state.isSubmitting ? null : () {
        if (isOpen) {
          context.read<IssueDetailBloc>().add(const IssueDetailClose());
        } else {
          context.read<IssueDetailBloc>().add(const IssueDetailReopen());
        }
      },
      icon: Icon(isOpen ? MdiIcons.closeCircleOutline : MdiIcons.refreshCircle, size: 18),
      label: Text(isOpen ? '关闭问题' : '重新开放'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isOpen ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
        foregroundColor: isOpen ? const Color(0xFFDC2626) : const Color(0xFF059669),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildCommentsSection(IssueDetailState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('评论 (${state.comments.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1F2937))),
      const SizedBox(height: 16),
      if (state.isLoadingComments) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
      else if (state.comments.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('暂无评论', style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)))))
      else ...state.comments.map((comment) => _buildCommentItem(comment)),
    ]));
  }

  Widget _buildCommentItem(IssueComment comment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6)))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(radius: 18, backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB), backgroundImage: comment.authorAvatar != null ? NetworkImage(comment.authorAvatar!) : null, child: comment.authorAvatar == null ? Text(comment.authorName[0].toUpperCase(), style: const TextStyle(fontSize: 14)) : null),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(comment.authorName, style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : const Color(0xFF374151))),
          if (comment.isAdmin) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: const Color(0xFF0080FF), borderRadius: BorderRadius.circular(4)), child: const Text('管理员', style: TextStyle(color: Colors.white, fontSize: 10)))],
          const SizedBox(width: 8), Text(Formatters.formatRelativeTime(comment.createdAt), style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF9CA3AF), fontSize: 12)),
        ]),
        const SizedBox(height: 8), 
        RichTextViewer(
          content: comment.content,
          textStyle: TextStyle(fontSize: 14, height: 1.6, color: isDark ? Colors.white70 : const Color(0xFF374151)),
          compact: true,
        ),
        if (comment.images.isNotEmpty) ...[const SizedBox(height: 12), ImageGrid(imageUrls: comment.images, imageWidth: 120, imageHeight: 90, spacing: 8, borderRadius: 6)],
      ])),
    ]));
  }

  Widget _buildCommentInput(IssueDetailState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('发表评论', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : const Color(0xFF374151))),
      const SizedBox(height: 12),
      SizedBox(
        height: 320,
        child: RichTextEditor(
          key: _commentEditorKey,
          controller: _commentController,
          hintText: '写下你的评论...',
          maxLength: 2000,
          maxImages: 3,
          compactMode: false,
          onImagesChanged: (urls) {
            setState(() {
              _commentImageUrls = urls;
            });
          },
        ),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [ElevatedButton(onPressed: state.isSubmitting ? null : _submitComment, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0080FF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)), child: state.isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('发表评论'))]),
    ]));
  }
}


/// Issue 创建视图（内嵌在 IssuesDesktop 中）
class _IssueCreateView extends StatefulWidget {
  final VoidCallback onBack;
  final ValueChanged<int> onCreated;
  const _IssueCreateView({required this.onBack, required this.onCreated});

  @override
  State<_IssueCreateView> createState() => _IssueCreateViewState();
}

class _IssueCreateViewState extends State<_IssueCreateView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = quill.QuillController.basic();
  final _scrollController = ScrollController();
  IssueType _selectedType = IssueType.bug;
  bool _isSubmitting = false;
  List<String> _imageUrls = [];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  DeviceInfo _collectDeviceInfo() {
    return DeviceInfo(appVersion: AppConstants.appVersion, platform: Platform.operatingSystem, osVersion: Platform.operatingSystemVersion, deviceModel: 'Desktop');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // 验证内容长度
    final plainText = _contentController.document.toPlainText().trim();
    if (plainText.isEmpty) {
      ToastUtils.showWarning(context, '请输入详细描述');
      return;
    }
    if (plainText.length < 10) {
      ToastUtils.showWarning(context, '详细描述至少 10 个字符');
      return;
    }
    if (plainText.length > 5000) {
      ToastUtils.showWarning(context, '详细描述最多 5000 个字符');
      return;
    }
    
    final content = QuillDeltaCodec.encode(_contentController.document);
    
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) { ToastUtils.showWarning(context, '请先登录'); return; }
    setState(() => _isSubmitting = true);
    try {
      final request = CreateIssueRequest(
        type: _selectedType.value, 
        title: _titleController.text.trim(), 
        content: content, 
        images: _imageUrls,
        deviceInfo: _collectDeviceInfo()
      );
      final response = await IssueApi().createIssue(request);
      if (response != null && mounted) { ToastUtils.showSuccess(context, '反馈提交成功'); widget.onCreated(response.id); }
    } catch (e) { if (mounted) ToastUtils.showError(context, ErrorUtils.getErrorMessage(e, defaultMessage: '提交失败，请稍后重试')); }
    finally { if (mounted) setState(() => _isSubmitting = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scrollbar(controller: _scrollController, thumbVisibility: true, child: SingleChildScrollView(controller: _scrollController, child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB))),
      child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        _buildTypeSelector(), const SizedBox(height: 24), _buildTitleField(), const SizedBox(height: 24), _buildContentField(), const SizedBox(height: 24),
        if (_selectedType == IssueType.bug) ...[_buildDeviceInfoCard(), const SizedBox(height: 24)],
        _buildSubmitButton(),
      ])),
    )));
  }

  Widget _buildTypeSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('反馈类型', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : const Color(0xFF374151))),
      const SizedBox(height: 12),
      Row(children: IssueType.values.map((type) {
        final isSelected = _selectedType == type;
        final (color, bgColor, icon) = switch (type) { IssueType.bug => (const Color(0xFFDC2626), const Color(0xFFFEE2E2), MdiIcons.bug), IssueType.feature => (const Color(0xFF2563EB), const Color(0xFFDBEAFE), MdiIcons.lightbulbOnOutline), IssueType.question => (const Color(0xFF059669), const Color(0xFFD1FAE5), MdiIcons.helpCircleOutline) };
        final darkBgColor = switch (type) { IssueType.bug => const Color(0xFF7F1D1D), IssueType.feature => const Color(0xFF1E3A5F), IssueType.question => const Color(0xFF064E3B) };
        return Padding(padding: const EdgeInsets.only(right: 12), child: InkWell(onTap: () => setState(() => _selectedType = type), borderRadius: BorderRadius.circular(8), child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: isSelected ? (isDark ? darkBgColor : bgColor) : (isDark ? const Color(0xFF334155) : Colors.white), borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? color : (isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB)), width: isSelected ? 2 : 1)),
          child: Row(children: [Icon(icon, size: 20, color: isSelected ? color : (isDark ? Colors.white38 : const Color(0xFF9CA3AF))), const SizedBox(width: 8), Text(type.label, style: TextStyle(color: isSelected ? color : (isDark ? Colors.white54 : const Color(0xFF6B7280)), fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal))]),
        )));
      }).toList()),
    ]);
  }

  Widget _buildTitleField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text('标题', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : const Color(0xFF374151))), const SizedBox(width: 4), const Text('*', style: TextStyle(color: Color(0xFFDC2626)))]),
      const SizedBox(height: 8),
      TextFormField(controller: _titleController, style: TextStyle(color: isDark ? Colors.white : null), decoration: InputDecoration(hintText: '简洁描述你的问题或建议', hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)), filled: isDark, fillColor: isDark ? const Color(0xFF334155) : null, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0080FF))), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
        validator: (value) { if (value == null || value.trim().isEmpty) return '请输入标题'; if (value.trim().length < 5) return '标题至少 5 个字符'; if (value.trim().length > 100) return '标题最多 100 个字符'; return null; }),
    ]);
  }

  Widget _buildContentField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text('详细描述', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : const Color(0xFF374151))), const SizedBox(width: 4), const Text('*', style: TextStyle(color: Color(0xFFDC2626)))]),
      const SizedBox(height: 8),
      SizedBox(
        height: 450,
        child: RichTextEditor(
          controller: _contentController,
          hintText: _selectedType == IssueType.bug 
              ? '请详细描述问题，包括：问题现象、复现步骤、期望行为' 
              : '请详细描述你的建议或问题...',
          maxLength: 5000,
          maxImages: 5,
          compactMode: false,
          onImagesChanged: (urls) {
            setState(() {
              _imageUrls = urls;
            });
          },
        ),
      ),
    ]);
  }

  Widget _buildDeviceInfoCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deviceInfo = _collectDeviceInfo();
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB))), child: Row(children: [
      Icon(MdiIcons.informationOutline, size: 20, color: isDark ? Colors.white54 : const Color(0xFF6B7280)), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('设备信息将自动附加', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : const Color(0xFF374151))), const SizedBox(height: 4), Text('${deviceInfo.appVersion} · ${deviceInfo.platform} · ${deviceInfo.osVersion}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF6B7280)))])),
    ]));
  }

  Widget _buildSubmitButton() {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      TextButton(onPressed: _isSubmitting ? null : widget.onBack, child: const Text('取消')),
      const SizedBox(width: 12),
      ElevatedButton(onPressed: _isSubmitting ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0080FF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        child: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('提交反馈')),
    ]);
  }
}
