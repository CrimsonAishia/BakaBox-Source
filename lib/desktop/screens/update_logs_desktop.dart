import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'dart:async';
import '../../core/core.dart';
import '../widgets/page_layout.dart';

/// 更新日志桌面端页面
/// 使用 PageLayout 统一布局，卡片式列表展示
class UpdateLogsDesktop extends StatefulWidget {
  const UpdateLogsDesktop({super.key});

  @override
  State<UpdateLogsDesktop> createState() => _UpdateLogsDesktopState();
}

class _UpdateLogsDesktopState extends State<UpdateLogsDesktop> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndFetchData();
    });
    _scrollController.addListener(_onScroll);
  }

  void _checkAndFetchData() {
    final bloc = context.read<UpdateLogBloc>();
    // 每次进入页面都刷新数据
    if (!bloc.state.isLoading && bloc.state.logs.isEmpty) {
      bloc.add(const UpdateLogFetch());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final bloc = context.read<UpdateLogBloc>();
      if (!bloc.state.isLoading && bloc.state.hasMore) {
        bloc.add(UpdateLogLoadMore());
      }
    }
  }

  void _performSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      context.read<UpdateLogBloc>().add(UpdateLogFetch(query));
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
    context.read<UpdateLogBloc>().add(const UpdateLogFetch());
  }

  void _copyLogContent(SteamWorkChangeLog log) {
    final formattedTime = Formatters.formatDateTime(log.updateTime);
    // 复制时使用纯文本内容
    final plainText = log.content.isNotEmpty ? log.content : Formatters.htmlToText(log.rawHtml);
    final copyText = '时间: $formattedTime\n\n$plainText';
    Clipboard.setData(ClipboardData(text: copyText));
    ToastUtils.showSuccess(context, '复制成功');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
      body: PageLayout(
        title: '更新日志',
        subtitle: '查看最新更新和改动',
        headerActions: _buildHeaderActions(),
        child: _buildLogCard(),
      ),
    );
  }

  /// 头部操作区域
  Widget _buildHeaderActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSearchBox(),
        const SizedBox(width: 16),
        _buildTotalCount(),
      ],
    );
  }

  /// 搜索框
  Widget _buildSearchBox() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 250,
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF374151),
        ),
        decoration: InputDecoration(
          hintText: '搜索更新内容...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: _clearSearch,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
        onChanged: (value) {
          setState(() {});
          _performSearch(value);
        },
      ),
    );
  }

  /// 统计信息
  Widget _buildTotalCount() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<UpdateLogBloc, UpdateLogState>(
      builder: (context, state) {
        String text;
        if (_searchController.text.isNotEmpty) {
          text = '搜索结果: ${state.logs.length} 条';
        } else if (state.hasMore) {
          text = '已加载 ${state.logs.length} / ${state.totalCount} 条记录';
        } else {
          text = '共 ${state.totalCount} 条记录';
        }
        return Text(
          text,
          style: TextStyle(
            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
            fontSize: 14,
          ),
        );
      },
    );
  }

  /// 日志卡片容器
  Widget _buildLogCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          _buildSearchResultTip(),
          Expanded(child: _buildLogsContent()),
        ],
      ),
    );
  }

  /// 搜索结果提示
  Widget _buildSearchResultTip() {
    return BlocBuilder<UpdateLogBloc, UpdateLogState>(
      builder: (context, state) {
        if (_searchController.text.isEmpty || state.isLoading) {
          return const SizedBox.shrink();
        }
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Text(
                '搜索结果: "${_searchController.text}"',
                style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 14),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearSearch,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                ),
                child: const Text('清除搜索', style: TextStyle(color: Color(0xFF0080FF))),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 日志内容区域
  Widget _buildLogsContent() {
    return BlocBuilder<UpdateLogBloc, UpdateLogState>(
      builder: (context, state) {
        if (state.isLoading && state.logs.isEmpty) {
          return _buildLoadingSkeleton();
        }
        if (state.error != null && state.logs.isEmpty) {
          return _buildErrorState(state.error!);
        }
        if (state.logs.isEmpty) {
          return _buildEmptyState();
        }
        return _buildLogsList(state);
      },
    );
  }

  /// 加载骨架屏
  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      itemBuilder: (context, index) => _buildSkeletonItem(),
    );
  }

  /// 骨架屏项
  Widget _buildSkeletonItem() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 140,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const Spacer(),
              Container(
                width: 60,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 200,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  /// 错误状态
  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(MdiIcons.alertCircleOutline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(error, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.read<UpdateLogBloc>().add(const UpdateLogFetch()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0080FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('刷新数据'),
          ),
        ],
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    final isSearching = _searchController.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : MdiIcons.fileDocumentOutline,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? '没有找到相关的更新记录' : '暂无更新记录',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isSearching
                ? _clearSearch
                : () => context.read<UpdateLogBloc>().add(const UpdateLogFetch()),
            child: Text(isSearching ? '清除搜索条件' : '刷新数据'),
          ),
        ],
      ),
    );
  }

  /// 日志列表
  Widget _buildLogsList(UpdateLogState state) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        itemCount: state.logs.length + 1,
        itemBuilder: (context, index) {
          if (index >= state.logs.length) {
            return _buildBottomIndicator(state);
          }
          final log = state.logs[index];
          final isLatest = index == 0 && _searchController.text.isEmpty;
          return _buildLogItem(log, index, isLatest);
        },
      ),
    );
  }

  /// 日志项卡片
  Widget _buildLogItem(SteamWorkChangeLog log, int index, bool isLatest) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isLatest
            ? (isDark ? const Color(0xFF422006) : const Color(0xFFFFFBEB))
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLatest
              ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
          width: isLatest ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isLatest
                ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 最新标签装饰条
          if (isLatest)
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)]),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部：序号 + 时间 + 最新标签 + 复制按钮
                _buildLogHeader(log, index, isLatest),
                const SizedBox(height: 14),
                // 分隔线
                Container(
                  height: 1,
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
                ),
                const SizedBox(height: 14),
                // 内容
                _buildLogContent(log),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 日志头部
  Widget _buildLogHeader(SteamWorkChangeLog log, int index, bool isLatest) {
    return Row(
      children: [
        // 序号徽章
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '#${index + 1}',
            style: const TextStyle(
              color: Color(0xFF6366F1),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 时间徽章
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: isLatest
                ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)])
                : const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(MdiIcons.clockOutline, size: 13, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 5),
              Text(
                Formatters.formatDate(log.updateTime),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // 最新标签
        if (isLatest)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '最新',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        const Spacer(),
        // 复制按钮
        _buildCopyButton(log),
      ],
    );
  }

  /// 复制按钮
  Widget _buildCopyButton(SteamWorkChangeLog log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _copyLogContent(log),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                MdiIcons.contentCopy,
                size: 14,
                color: isDark ? Colors.white54 : Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                '复制',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 日志内容 - 渲染 HTML
  Widget _buildLogContent(SteamWorkChangeLog log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final htmlContent = log.rawHtml.isNotEmpty ? log.rawHtml : log.content;
    if (htmlContent.isEmpty) {
      return Text(
        '暂无详细内容',
        style: TextStyle(
          color: isDark ? Colors.white54 : Colors.grey.shade500,
          fontSize: 14,
        ),
      );
    }
    return Html(
      data: htmlContent,
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(14),
          lineHeight: const LineHeight(1.7),
          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF374151),
        ),
        'p': Style(
          margin: Margins.only(bottom: 12),
        ),
        'h1': Style(
          fontSize: FontSize(18),
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
          margin: Margins.only(top: 16, bottom: 12),
        ),
        'h2': Style(
          fontSize: FontSize(16),
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
          margin: Margins.only(top: 14, bottom: 10),
        ),
        'h3': Style(
          fontSize: FontSize(15),
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
          margin: Margins.only(top: 12, bottom: 8),
        ),
        'ul': Style(
          margin: Margins.only(top: 8, bottom: 8),
          padding: HtmlPaddings.only(left: 20),
        ),
        'ol': Style(
          margin: Margins.only(top: 8, bottom: 8),
          padding: HtmlPaddings.only(left: 20),
        ),
        'li': Style(
          margin: Margins.only(bottom: 6),
          lineHeight: const LineHeight(1.6),
        ),
        'strong': Style(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
        ),
        'em': Style(
          fontStyle: FontStyle.italic,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF6B7280),
        ),
        'a': Style(
          color: const Color(0xFF0080FF),
          textDecoration: TextDecoration.none,
        ),
        'code': Style(
          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
          color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFE74C3C),
          padding: HtmlPaddings.symmetric(horizontal: 6, vertical: 2),
          fontFamily: 'Consolas, Monaco, monospace',
          fontSize: FontSize(13),
        ),
        'pre': Style(
          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF8F9FA),
          padding: HtmlPaddings.all(16),
          margin: Margins.symmetric(vertical: 12),
        ),
        'blockquote': Style(
          border: Border(
            left: BorderSide(
              color: isDark ? const Color(0xFF64748B) : const Color(0xFFD1D5DB),
              width: 4,
            ),
          ),
          padding: HtmlPaddings.only(left: 16),
          margin: Margins.symmetric(vertical: 12),
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF6B7280),
          fontStyle: FontStyle.italic,
        ),
      },
    );
  }

  /// 底部指示器
  Widget _buildBottomIndicator(UpdateLogState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (state.isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0080FF)),
              ),
              const SizedBox(width: 10),
              Text(
                '正在加载更多...',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey.shade500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!state.hasMore && state.logs.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                MdiIcons.checkCircleOutline,
                size: 16,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              const SizedBox(width: 6),
              Text(
                '已显示全部 ${state.totalCount} 条记录',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey.shade500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
