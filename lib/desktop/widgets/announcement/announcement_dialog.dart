import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/bloc/announcement/announcement_bloc.dart';
import '../../../core/bloc/announcement/announcement_event.dart';
import '../../../core/bloc/announcement/announcement_state.dart';
import '../../../core/models/announcement_models.dart';
import '../../../core/utils/announcement_utils.dart';

/// 公告详情对话框
class AnnouncementDialog extends StatefulWidget {
  final AnnouncementItem? initialDetail;

  const AnnouncementDialog({super.key, this.initialDetail});

  /// 显示公告列表对话框
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const AnnouncementDialog(),
    );
  }

  /// 显示单条公告详情
  static Future<void> showDetail(BuildContext context, AnnouncementItem announcement) {
    return showDialog(
      context: context,
      builder: (context) => AnnouncementDialog(initialDetail: announcement),
    );
  }

  @override
  State<AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<AnnouncementDialog> {
  AnnouncementItem? _viewingDetail;
  String _filterType = 'unread';

  @override
  void initState() {
    super.initState();
    _viewingDetail = widget.initialDetail;
    context.read<AnnouncementBloc>().add(AnnouncementFetch());
    if (widget.initialDetail != null) {
      context.read<AnnouncementBloc>().add(
        AnnouncementFetchDetail(widget.initialDetail!.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: _viewingDetail != null ? 600 : 480,
        height: _viewingDetail != null ? 520 : null,
        constraints: _viewingDetail != null 
            ? null 
            : const BoxConstraints(maxHeight: 540),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: _viewingDetail != null
            ? _buildDetailView(isDark)
            : _buildListView(isDark),
      ),
    );
  }

  /// 列表视图
  Widget _buildListView(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(isDark),
        _buildFilterBar(isDark),
        Flexible(child: _buildList(isDark)),
      ],
    );
  }

  /// 头部
  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF0080FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.campaign_outlined,
              size: 18,
              color: Color(0xFF0080FF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '系统公告',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                BlocBuilder<AnnouncementBloc, AnnouncementState>(
                  builder: (context, state) {
                    return Text(
                      state.unreadCount > 0
                          ? '${state.unreadCount} 条未读'
                          : '暂无未读',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : const Color(0xFF9CA3AF),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          BlocBuilder<AnnouncementBloc, AnnouncementState>(
            builder: (context, state) {
              if (state.unreadCount == 0) return const SizedBox.shrink();
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _markAllAsRead(state),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '全部已读',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF0080FF),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              size: 18,
              color: isDark ? Colors.white54 : const Color(0xFF9CA3AF),
            ),
            tooltip: '关闭',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  /// 筛选栏
  Widget _buildFilterBar(bool isDark) {
    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
      builder: (context, state) {
        final unreadCount = state.unreadCount;
        final readCount = state.announcements.length - unreadCount;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _buildFilterChip('unread', '未读', unreadCount, isDark),
              _buildFilterChip('read', '已读', readCount, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String type, String label, int count, bool isDark) {
    final isSelected = _filterType == type;
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _filterType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0080FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white54 : const Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 公告列表
  Widget _buildList(bool isDark) {
    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
      builder: (context, state) {
        if (state.isLoading && state.announcements.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final filtered = _filterType == 'unread'
            ? state.announcements.where((a) => !state.isRead(a.id)).toList()
            : state.announcements.where((a) => state.isRead(a.id)).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState(isDark);
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 12),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final item = filtered[index];
            final isRead = state.isRead(item.id);
            return _buildAnnouncementItem(item, isRead, isDark);
          },
        );
      },
    );
  }

  Widget _buildAnnouncementItem(AnnouncementItem item, bool isRead, bool isDark) {
    final typeColor = _getTypeColor(item.type);

    return _HoverableItem(
      isDark: isDark,
      isRead: isRead,
      typeColor: typeColor,
      onTap: () {
        context.read<AnnouncementBloc>().add(AnnouncementMarkAsRead(item.id));
        context.read<AnnouncementBloc>().add(AnnouncementFetchDetail(item.id));
        setState(() => _viewingDetail = item);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.campaign_outlined, size: 18, color: typeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!isRead)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: typeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (item.isSticky)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          '置顶',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFFFF9800),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _getContentPreview(item.content),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  AnnouncementUtils.formatRelativeTime(item.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
          ),
        ],
      ),
    );
  }

  /// 详情视图
  Widget _buildDetailView(bool isDark) {
    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
      builder: (context, state) {
        final detail = state.currentDetail ?? _viewingDetail!;
        final typeColor = _getTypeColor(detail.type);
        final typeInfo = AnnouncementUtils.getAnnouncementTypeInfo(detail.type);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(typeInfo.icon, size: 20, color: typeColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (detail.isSticky)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF9800),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '置顶',
                                  style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                typeInfo.label,
                                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          detail.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: isDark ? Colors.white54 : const Color(0xFF9CA3AF),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            // 内容
            Flexible(
              child: state.isLoadingDetail
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: MarkdownBody(
                        data: detail.content,
                        selectable: true,
                        onTapLink: (text, href, title) {
                          if (href != null) _launchUrl(href);
                        },
                        styleSheet: _buildMarkdownStyle(isDark, typeColor),
                      ),
                    ),
            ),
            // 底部
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text(
                    AnnouncementUtils.formatRelativeTime(detail.createdAt),
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.visibility_outlined, size: 14, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text(
                    '${detail.readCount} 次阅读',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                  ),
                  const Spacer(),
                  // 只有从列表进入详情时才显示返回按钮
                  if (widget.initialDetail == null)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => setState(() => _viewingDetail = null),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_back, size: 14, color: const Color(0xFF0080FF)),
                            const SizedBox(width: 4),
                            const Text(
                              '返回列表',
                              style: TextStyle(fontSize: 12, color: Color(0xFF0080FF)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final isUnread = _filterType == 'unread';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isUnread ? Icons.mark_email_read_outlined : Icons.email_outlined,
              size: 48,
              color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
            ),
            const SizedBox(height: 12),
            Text(
              isUnread ? '暂无未读公告' : '暂无已读公告',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'error':
        return const Color(0xFFEF4444);
      case 'success':
        return const Color(0xFF10B981);
      case 'maintenance':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF0080FF);
    }
  }

  String _getContentPreview(String content) {
    var text = content
        .replaceAll(RegExp(r'[#*`>\[\]()]'), '')
        .replaceAll(RegExp(r'\n+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.length > 60 ? '${text.substring(0, 60)}...' : text;
  }

  void _markAllAsRead(AnnouncementState state) {
    for (final item in state.announcements) {
      if (!state.isRead(item.id)) {
        context.read<AnnouncementBloc>().add(AnnouncementMarkAsRead(item.id));
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  MarkdownStyleSheet _buildMarkdownStyle(bool isDark, Color accentColor) {
    return MarkdownStyleSheet(
      p: TextStyle(
        fontSize: 14,
        height: 1.7,
        color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
      ),
      h1: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : const Color(0xFF111827),
      ),
      h2: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : const Color(0xFF1F2937),
      ),
      h3: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
      ),
      code: TextStyle(
        backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
        fontFamily: 'Consolas, Monaco, monospace',
        fontSize: 13,
      ),
      codeblockDecoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      blockquoteDecoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.05),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
      ),
      a: TextStyle(color: accentColor, decoration: TextDecoration.underline),
    );
  }
}

/// 可悬停的列表项
class _HoverableItem extends StatefulWidget {
  final Widget child;
  final bool isDark;
  final bool isRead;
  final Color typeColor;
  final VoidCallback onTap;

  const _HoverableItem({
    required this.child,
    required this.isDark,
    required this.isRead,
    required this.typeColor,
    required this.onTap,
  });

  @override
  State<_HoverableItem> createState() => _HoverableItemState();
}

class _HoverableItemState extends State<_HoverableItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isRead
                ? (_isHovered
                    ? (widget.isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF9FAFB))
                    : Colors.transparent)
                : widget.typeColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered
                  ? (widget.isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : const Color(0xFFE5E7EB))
                  : (widget.isRead
                      ? Colors.transparent
                      : widget.typeColor.withValues(alpha: 0.2)),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
