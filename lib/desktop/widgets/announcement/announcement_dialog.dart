import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/bloc/announcement/announcement_bloc.dart';
import '../../../core/bloc/announcement/announcement_event.dart';
import '../../../core/bloc/announcement/announcement_state.dart';
import '../../../core/models/announcement_models.dart';
import '../../../core/utils/announcement_utils.dart';

/// 公告对话框
/// 
/// 显示系统公告列表，支持筛选已读/未读，标记已读等功能
class AnnouncementDialog extends StatefulWidget {
  const AnnouncementDialog({super.key});

  /// 显示公告对话框
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const AnnouncementDialog(),
    );
  }

  @override
  State<AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<AnnouncementDialog> {
  /// 当前筛选类型：all, unread, read
  String _filterType = 'unread';
  
  /// 当前查看的公告详情（null 表示显示列表）
  AnnouncementItem? _viewingDetail;

  @override
  void initState() {
    super.initState();
    // 获取公告数据
    context.read<AnnouncementBloc>().add(AnnouncementFetch());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: _viewingDetail != null ? 700 : 600,
        height: _viewingDetail != null ? 650 : 600,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: _viewingDetail != null ? _buildDetailView(context) : _buildListView(context),
      ),
    );
  }

  /// 构建列表视图
  Widget _buildListView(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        _buildFilterTabs(context),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  /// 构建详情视图
  Widget _buildDetailView(BuildContext context) {
    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
      builder: (context, state) {
        // 使用详情数据，如果还在加载则使用当前的数据
        final detail = state.currentDetail ?? _viewingDetail!;
        final typeInfo = AnnouncementUtils.getAnnouncementTypeInfo(detail.type);

        return Column(
          children: [
            // 头部
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: typeInfo.color.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(
                    color: typeInfo.color.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: typeInfo.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      typeInfo.icon,
                      color: typeInfo.color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (detail.isSticky)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF9800),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '置顶',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: typeInfo.color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                typeInfo.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          detail.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            // 内容
            Expanded(
              child: state.isLoadingDetail
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0080FF)),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: MarkdownBody(
                        data: detail.content,
                        selectable: true,
                        onTapLink: (text, href, title) {
                          if (href != null) {
                            _launchUrl(href);
                          }
                        },
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Color(0xFF374151),
                          ),
                          h1: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                          h2: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                          h3: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                          code: TextStyle(
                            backgroundColor: Colors.grey.shade100,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          blockquoteDecoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: typeInfo.color,
                                width: 4,
                              ),
                            ),
                          ),
                          a: TextStyle(
                            color: typeInfo.color,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
            ),
            // 底部信息和操作栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '系统管理员',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AnnouncementUtils.formatRelativeTime(detail.createdAt),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${detail.readCount} 次阅读',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const Spacer(),
                  // 返回列表按钮
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _viewingDetail = null;
                      });
                      // 清除详情数据
                      context.read<AnnouncementBloc>().state.copyWith(clearDetail: true);
                    },
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('返回列表'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0080FF),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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


  /// 构建头部
  Widget _buildHeader(BuildContext context) {
    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              // 图标
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0080FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(
                        Icons.notifications_outlined,
                        color: Color(0xFF0080FF),
                        size: 24,
                      ),
                    ),
                    // 未读数量角标
                    if (state.unreadCount > 0)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF44336),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              state.unreadCount > 9 ? '9+' : '${state.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 标题和副标题
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '系统公告',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.unreadCount > 0
                          ? '${state.unreadCount} 条未读公告'
                          : '暂无未读公告',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // 全部已读按钮
              if (state.unreadCount > 0)
                TextButton.icon(
                  onPressed: () => _markAllAsRead(context, state),
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('全部已读'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              const SizedBox(width: 8),
              // 刷新按钮
              IconButton(
                icon: state.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh, color: Colors.white),
                onPressed: state.isLoading
                    ? null
                    : () => context.read<AnnouncementBloc>().add(AnnouncementRefresh()),
                tooltip: '刷新',
              ),
              // 关闭按钮
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: '关闭',
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建筛选标签
  Widget _buildFilterTabs(BuildContext context) {
    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
      builder: (context, state) {
        final unreadCount = state.unreadCount;
        final readCount = state.announcements.length - unreadCount;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
          ),
          child: Row(
            children: [
              _buildFilterTab('unread', '未读', unreadCount),
              const SizedBox(width: 16),
              _buildFilterTab('read', '已读', readCount),
            ],
          ),
        );
      },
    );
  }

  /// 构建单个筛选标签
  Widget _buildFilterTab(String type, String label, int count) {
    final isActive = _filterType == type;
    return InkWell(
      onTap: () => setState(() => _filterType = type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0080FF).withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(color: const Color(0xFF0080FF).withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF0080FF) : Colors.grey,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF0080FF).withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? const Color(0xFF0080FF) : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// 构建内容区域
  Widget _buildContent(BuildContext context) {
    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
      builder: (context, state) {
        // 加载中
        if (state.isLoading && state.announcements.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0080FF)),
                ),
                SizedBox(height: 16),
                Text(
                  '正在加载公告...',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          );
        }

        // 错误状态
        if (state.error != null && state.announcements.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(MdiIcons.alertCircle, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  state.error!,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.read<AnnouncementBloc>().add(AnnouncementFetch()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0080FF),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        // 筛选公告
        final filteredAnnouncements = _getFilteredAnnouncements(state);

        // 空状态
        if (filteredAnnouncements.isEmpty) {
          return _buildEmptyState();
        }

        // 公告列表
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredAnnouncements.length,
          itemBuilder: (context, index) {
            final announcement = filteredAnnouncements[index];
            final isRead = state.isRead(announcement.id);
            return _buildAnnouncementItem(context, announcement, isRead, index);
          },
        );
      },
    );
  }

  /// 获取筛选后的公告列表
  List<AnnouncementItem> _getFilteredAnnouncements(AnnouncementState state) {
    switch (_filterType) {
      case 'unread':
        return state.announcements
            .where((a) => !state.isRead(a.id))
            .toList();
      case 'read':
        return state.announcements
            .where((a) => state.isRead(a.id))
            .toList();
      default:
        return state.announcements;
    }
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    final String title;
    final String description;
    final IconData icon;

    switch (_filterType) {
      case 'unread':
        title = '暂无未读公告';
        description = '所有公告都已阅读完毕';
        icon = Icons.mark_email_read_outlined;
        break;
      case 'read':
        title = '暂无已读公告';
        description = '还没有阅读过的公告';
        icon = Icons.email_outlined;
        break;
      default:
        title = '暂无公告';
        description = '目前没有任何公告';
        icon = Icons.notifications_off_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }


  /// 构建公告项
  Widget _buildAnnouncementItem(
    BuildContext context,
    AnnouncementItem announcement,
    bool isRead,
    int index,
  ) {
    final typeInfo = AnnouncementUtils.getAnnouncementTypeInfo(announcement.type);
    final isHighPriority = announcement.priority >= 80;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead
            ? Colors.grey.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead
              ? Colors.grey.withValues(alpha: 0.2)
              : typeInfo.color.withValues(alpha: 0.3),
          width: isRead ? 1 : 1.5,
        ),
        boxShadow: isRead
            ? null
            : [
                BoxShadow(
                  color: typeInfo.color.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAnnouncementDetail(context, announcement),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部：状态指示器、标题、时间
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 状态指示器
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6, right: 12),
                      decoration: BoxDecoration(
                        color: isRead ? Colors.grey : typeInfo.color,
                        shape: BoxShape.circle,
                        boxShadow: isRead
                            ? null
                            : [
                                BoxShadow(
                                  color: typeInfo.color.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ],
                      ),
                    ),
                    // 标题和标签
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // 置顶标签
                              if (announcement.isSticky)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFFF9800).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.push_pin,
                                        size: 10,
                                        color: Color(0xFFFF9800),
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        '置顶',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFFFF9800),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // 重要标签
                              if (isHighPriority)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF44336).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFF44336).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Text(
                                    '重要',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFF44336),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              // 类型标签
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: typeInfo.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      typeInfo.icon,
                                      size: 10,
                                      color: typeInfo.color,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      typeInfo.label,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: typeInfo.color,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 标题
                          Text(
                            announcement.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isRead
                                  ? const Color(0xFF6B7280)
                                  : const Color(0xFF1F2937),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // 时间
                    Text(
                      AnnouncementUtils.formatRelativeTime(announcement.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 内容预览（使用 Markdown 渲染）
                SizedBox(
                  height: 44, // 固定高度约为 2 行
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: MarkdownBody(
                          data: announcement.content,
                          selectable: false,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontSize: 13,
                              color: isRead
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF6B7280),
                              height: 1.5,
                            ),
                            h1: TextStyle(
                              fontSize: 13,
                              color: isRead
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF6B7280),
                              height: 1.5,
                            ),
                            h2: TextStyle(
                              fontSize: 13,
                              color: isRead
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF6B7280),
                              height: 1.5,
                            ),
                            h3: TextStyle(
                              fontSize: 13,
                              color: isRead
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF6B7280),
                              height: 1.5,
                            ),
                            code: TextStyle(
                              fontSize: 12,
                              color: isRead
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF6B7280),
                              backgroundColor: Colors.transparent,
                            ),
                            a: TextStyle(
                              fontSize: 13,
                              color: isRead
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF6B7280),
                              decoration: TextDecoration.none,
                            ),
                            blockquote: TextStyle(
                              fontSize: 13,
                              color: isRead
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),
                      // 底部渐变遮罩，表示内容被截断
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                (isRead
                                    ? Colors.grey.withValues(alpha: 0.05)
                                    : Colors.white).withValues(alpha: 0),
                                isRead
                                    ? Colors.grey.withValues(alpha: 0.05)
                                    : Colors.white,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 底部：作者和操作按钮
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '系统管理员',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const Spacer(),
                    // 标记已读按钮
                    if (!isRead)
                      TextButton.icon(
                        onPressed: () => _markAsRead(context, announcement.id),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('标记已读'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0080FF),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '已读',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 标记单个公告为已读
  void _markAsRead(BuildContext context, int announcementId) {
    context.read<AnnouncementBloc>().add(AnnouncementMarkAsRead(announcementId));
  }

  /// 标记所有公告为已读
  void _markAllAsRead(BuildContext context, AnnouncementState state) {
    for (final announcement in state.announcements) {
      if (!state.isRead(announcement.id)) {
        context.read<AnnouncementBloc>().add(AnnouncementMarkAsRead(announcement.id));
      }
    }
  }


  /// 显示公告详情
  void _showAnnouncementDetail(BuildContext context, AnnouncementItem announcement) {
    // 标记为已读
    _markAsRead(context, announcement.id);
    
    // 获取详情
    context.read<AnnouncementBloc>().add(AnnouncementFetchDetail(announcement.id));

    // 切换到详情视图
    setState(() {
      _viewingDetail = announcement;
    });
  }

  /// 打开链接
  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
