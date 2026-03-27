import 'package:flutter/material.dart';
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
  bool _isSearching = false; // 本地搜索状态，用于防抖期间显示 loading

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
    if (!bloc.state.isLoading) {
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
    // 立即显示搜索中状态
    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      context.read<UpdateLogBloc>().add(UpdateLogFetch(query));
      if (mounted) setState(() => _isSearching = false);
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() => _isSearching = false);
    context.read<UpdateLogBloc>().add(const UpdateLogFetch());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF3F4F6),
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
        _buildUpdateLogNotificationToggle(),
        const SizedBox(width: 16),
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

  /// 更新日志通知开关
  Widget _buildUpdateLogNotificationToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<SettingsBloc, SettingsState>(
      buildWhen: (previous, current) =>
          previous.updateLogNotificationEnabled !=
          current.updateLogNotificationEnabled,
      builder: (context, settingsState) {
        final isEnabled = settingsState.updateLogNotificationEnabled;
        final updateLogColor = const Color(0xFF3B82F6); // 蓝色主题

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isEnabled
                ? updateLogColor.withValues(alpha: 0.12)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isEnabled
                  ? updateLogColor.withValues(alpha: 0.3)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  key: ValueKey(isEnabled),
                  size: 15,
                  color: isEnabled
                      ? updateLogColor
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '更新通知',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isEnabled
                      ? updateLogColor
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 22,
                width: 36,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: isEnabled,
                    onChanged: (value) {
                      context.read<SettingsBloc>().add(
                        SettingsSetUpdateLogNotificationEnabled(value),
                      );
                    },
                    activeThumbColor: Colors.white,
                    activeTrackColor: updateLogColor,
                    inactiveThumbColor: isDark
                        ? Colors.white54
                        : Colors.grey.shade400,
                    inactiveTrackColor: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.12),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
      child: _buildLogsContent(),
    );
  }

  /// 日志内容区域
  Widget _buildLogsContent() {
    return BlocBuilder<UpdateLogBloc, UpdateLogState>(
      builder: (context, state) {
        // 搜索中或加载中显示 loading
        if (_isSearching || state.isLoading) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final shimmerColor = isDark
        ? const Color(0xFF334155)
        : Colors.grey.shade200;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      itemBuilder: (context, index) =>
          _buildSkeletonItem(cardColor, shimmerColor, borderColor),
    );
  }

  /// 骨架屏项
  Widget _buildSkeletonItem(
    Color cardColor,
    Color shimmerColor,
    Color borderColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
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
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 140,
                height: 28,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const Spacer(),
              Container(
                width: 60,
                height: 24,
                decoration: BoxDecoration(
                  color: shimmerColor,
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
              color: shimmerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 14,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 200,
            height: 14,
            decoration: BoxDecoration(
              color: shimmerColor,
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
          Icon(
            MdiIcons.alertCircleOutline,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            error,
            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                context.read<UpdateLogBloc>().add(const UpdateLogFetch()),
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
                : () =>
                      context.read<UpdateLogBloc>().add(const UpdateLogFetch()),
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
          return TweenAnimationBuilder<double>(
            key: ValueKey(log.updateTime),
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(
              milliseconds: 200 + (index * 50).clamp(0, 300),
            ),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: _buildLogItem(log, index, isLatest),
          );
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
                gradient: LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                ),
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
                // 头部：序号 + 时间 + 最新标签
                _buildLogHeader(log, index, isLatest),
                const SizedBox(height: 14),
                // 分隔线
                Container(
                  height: 1,
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF3F4F6),
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
                ? const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                MdiIcons.clockOutline,
                size: 13,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 5),
              Text(
                Formatters.formatDate(log.updateTime),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
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
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  /// 日志内容 - 渲染 HTML，支持搜索关键字高亮
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

    // 如果有搜索关键字，对内容进行高亮处理
    final keyword = _searchController.text.trim();
    final processedHtml = keyword.isNotEmpty
        ? _highlightKeyword(htmlContent, keyword)
        : htmlContent;

    return Html(
      data: processedHtml,
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(14),
          lineHeight: const LineHeight(1.7),
          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF374151),
        ),
        'p': Style(margin: Margins.only(bottom: 12)),
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
          backgroundColor: isDark
              ? const Color(0xFF334155)
              : const Color(0xFFF3F4F6),
          color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFE74C3C),
          padding: HtmlPaddings.symmetric(horizontal: 6, vertical: 2),
          fontFamily: 'Consolas, Monaco, monospace',
          fontSize: FontSize(13),
        ),
        'pre': Style(
          backgroundColor: isDark
              ? const Color(0xFF334155)
              : const Color(0xFFF8F9FA),
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
        // 搜索高亮样式
        'mark': Style(
          backgroundColor: const Color(0xFFFEF08A),
          color: const Color(0xFF92400E),
          padding: HtmlPaddings.symmetric(horizontal: 2),
        ),
      },
    );
  }

  /// 高亮搜索关键字
  /// 只处理 HTML 标签外的文本内容，避免破坏 HTML 结构
  String _highlightKeyword(String html, String keyword) {
    if (keyword.isEmpty) return html;

    // 转义正则特殊字符
    final escapedKeyword = RegExp.escape(keyword);

    // 使用正则匹配，但排除 HTML 标签内的内容
    // 匹配策略：找到所有不在 < > 之间的文本，对其中的关键字进行高亮
    final result = StringBuffer();
    var lastEnd = 0;

    // 匹配 HTML 标签
    final tagRegex = RegExp(r'<[^>]*>');
    final matches = tagRegex.allMatches(html);

    for (final match in matches) {
      // 处理标签之前的文本
      if (match.start > lastEnd) {
        final textBefore = html.substring(lastEnd, match.start);
        result.write(_highlightText(textBefore, escapedKeyword));
      }
      // 保留标签原样
      result.write(match.group(0));
      lastEnd = match.end;
    }

    // 处理最后一个标签之后的文本
    if (lastEnd < html.length) {
      final textAfter = html.substring(lastEnd);
      result.write(_highlightText(textAfter, escapedKeyword));
    }

    return result.toString();
  }

  /// 对纯文本进行关键字高亮
  String _highlightText(String text, String escapedKeyword) {
    final regex = RegExp(escapedKeyword, caseSensitive: false);
    return text.replaceAllMapped(regex, (match) {
      return '<mark>${match.group(0)}</mark>';
    });
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
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF0080FF),
                ),
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
