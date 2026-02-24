import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/bloc/announcement/announcement_bloc.dart';
import '../../../core/bloc/announcement/announcement_event.dart';
import '../../../core/bloc/announcement/announcement_state.dart';
import '../../../core/bloc/notification/notification_bloc.dart';
import '../../../core/bloc/notification/notification_event.dart';
import '../../../core/bloc/notification/notification_state.dart';
import '../../../core/models/notification_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_utils.dart';
import '../announcement/announcement_dialog.dart';

/// 消息中心面板
class NotificationPanel extends StatefulWidget {
  final VoidCallback? onClose;

  const NotificationPanel({super.key, this.onClose});

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _notificationScrollController = ScrollController();

  // 筛选状态
  bool _announcementShowUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _notificationScrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationBloc>().add(const NotificationFetch());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notificationScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_notificationScrollController.hasClients) return;
    
    final position = _notificationScrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;
    
    // 当滚动到距离底部 200px 时触发加载更多
    if (maxScroll - currentScroll <= 200) {
      final bloc = context.read<NotificationBloc>();
      if (!bloc.state.isLoadingMore && bloc.state.hasMore) {
        bloc.add(const NotificationLoadMore());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 420,
      constraints: const BoxConstraints(maxHeight: 560),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF0080FF).withValues(alpha: 0.05),
            blurRadius: 40,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(isDark),
          _buildTabBar(isDark),
          Flexible(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAnnouncementTab(isDark),
                _buildNotificationTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          // 图标
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0080FF),
                  const Color(0xFF0080FF).withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0080FF).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_outlined,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          // 标题和统计
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '消息中心',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                _buildUnreadSummary(isDark),
              ],
            ),
          ),
          // 关闭按钮
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: isDark ? Colors.white54 : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 未读消息统计
  Widget _buildUnreadSummary(bool isDark) {
    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
      builder: (context, announcementState) {
        return BlocBuilder<NotificationBloc, NotificationState>(
          builder: (context, notificationState) {
            final total =
                announcementState.unreadCount + notificationState.unreadCount;
            if (total == 0) {
              return Text(
                '暂无未读消息',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                ),
              );
            }
            return Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$total 条未读消息',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: isDark ? Colors.white : const Color(0xFF1F2937),
        unselectedLabelColor: isDark ? Colors.white54 : const Color(0xFF6B7280),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: [
          _buildTab('公告', _buildAnnouncementBadge()),
          _buildTab('消息', _buildNotificationBadge()),
        ],
      ),
    );
  }

  Widget _buildTab(String label, Widget badge) {
    return Tab(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Text(label), badge],
      ),
    );
  }

  Widget _buildAnnouncementBadge() {
    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
      builder: (context, state) {
        if (state.unreadCount == 0) return const SizedBox.shrink();
        return _buildBadge(state.unreadCount);
      },
    );
  }

  Widget _buildNotificationBadge() {
    return BlocBuilder<NotificationBloc, NotificationState>(
      builder: (context, state) {
        if (state.unreadCount == 0) return const SizedBox.shrink();
        return _buildBadge(state.unreadCount);
      },
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
    );
  }

  /// 公告 Tab
  Widget _buildAnnouncementTab(bool isDark) {
    return Column(
      children: [
        _buildAnnouncementToolbar(isDark),
        Expanded(
          child: BlocBuilder<AnnouncementBloc, AnnouncementState>(
            builder: (context, state) {
              if (state.isLoading && state.announcements.isEmpty) {
                return _buildLoadingState();
              }

              // 根据筛选条件过滤
              final filteredAnnouncements = _announcementShowUnreadOnly
                  ? state.announcements
                        .where((item) => !state.readIds.contains(item.id))
                        .toList()
                  : state.announcements;

              if (filteredAnnouncements.isEmpty) {
                return _buildEmptyState(
                  _announcementShowUnreadOnly ? '暂无未读公告' : '暂无公告',
                  Icons.campaign_outlined,
                  isDark,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: filteredAnnouncements.length,
                itemBuilder: (context, index) {
                  final item = filteredAnnouncements[index];
                  final isRead = state.readIds.contains(item.id);

                  return _AnnouncementItemWidget(
                    index: index + 1,
                    announcementId: item.id,
                    title: item.title,
                    content: item.content,
                    type: item.type,
                    createdAt: item.createdAt,
                    isRead: isRead,
                    isDark: isDark,
                    onTap: () {
                      context.read<AnnouncementBloc>().add(
                        AnnouncementMarkAsRead(item.id),
                      );
                      widget.onClose?.call();
                      AnnouncementDialog.showDetail(context, item);
                    },
                    onMarkRead: isRead
                        ? null
                        : () {
                            context.read<AnnouncementBloc>().add(
                              AnnouncementMarkAsRead(item.id),
                            );
                          },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// 公告工具栏
  Widget _buildAnnouncementToolbar(bool isDark) {
    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // 筛选切换
              _buildFilterChips(
                showUnreadOnly: _announcementShowUnreadOnly,
                onChanged: (value) =>
                    setState(() => _announcementShowUnreadOnly = value),
                isDark: isDark,
              ),
              const Spacer(),
              if (state.unreadCount > 0)
                _buildActionButton(
                  label: '全部已读',
                  onTap: () {
                    for (final item in state.announcements) {
                      if (!state.isRead(item.id)) {
                        context.read<AnnouncementBloc>().add(
                          AnnouncementMarkAsRead(item.id),
                        );
                      }
                    }
                  },
                  isDark: isDark,
                ),
            ],
          ),
        );
      },
    );
  }

  /// 筛选切换组件
  Widget _buildFilterChips({
    required bool showUnreadOnly,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilterChip(
            label: '全部',
            isSelected: !showUnreadOnly,
            onTap: () => onChanged(false),
            isDark: isDark,
          ),
          _buildFilterChip(
            label: '未读',
            isSelected: showUnreadOnly,
            onTap: () => onChanged(true),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF334155) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? (isDark ? Colors.white : const Color(0xFF1F2937))
                  : (isDark ? Colors.white54 : const Color(0xFF6B7280)),
            ),
          ),
        ),
      ),
    );
  }

  /// 消息 Tab
  Widget _buildNotificationTab(bool isDark) {
    return Column(
      children: [
        _buildNotificationToolbar(isDark),
        Expanded(
          child: BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, state) {
              if (state.isLoading && state.notifications.isEmpty) {
                return _buildLoadingState();
              }

              if (state.error != null && state.notifications.isEmpty) {
                return _buildErrorState(state.error!, isDark);
              }

              if (state.notifications.isEmpty) {
                return _buildEmptyState(
                  state.filterIsRead == false ? '暂无未读消息' : '暂无消息',
                  Icons.notifications_off_outlined,
                  isDark,
                );
              }

              return ListView.builder(
                controller: _notificationScrollController,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount:
                    state.notifications.length +
                    (state.isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.notifications.length) {
                    return _buildLoadingMore();
                  }

                  final notification = state.notifications[index];
                  return _NotificationItemWidget(
                    index: index + 1,
                    notification: notification,
                    isDark: isDark,
                    onTap: () {
                      if (!notification.isRead) {
                        context.read<NotificationBloc>().add(
                          NotificationMarkRead(notification.id),
                        );
                      }
                    },
                    onMarkRead: notification.isRead
                        ? null
                        : () {
                            context.read<NotificationBloc>().add(
                              NotificationMarkRead(notification.id),
                            );
                          },
                    onDelete: () {
                      context.read<NotificationBloc>().add(
                        NotificationDelete(notification.id),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// 消息工具栏
  Widget _buildNotificationToolbar(bool isDark) {
    return BlocBuilder<NotificationBloc, NotificationState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // 筛选切换 - 使用服务端筛选
              _buildNotificationFilterChips(
                filterIsRead: state.filterIsRead,
                isDark: isDark,
              ),
              const Spacer(),
              if (state.unreadCount > 0)
                _buildActionButton(
                  label: '全部已读',
                  onTap: () {
                    context.read<NotificationBloc>().add(
                      const NotificationMarkAllRead(),
                    );
                  },
                  isDark: isDark,
                ),
              const SizedBox(width: 8),
              _buildIconButton(
                icon: Icons.refresh,
                tooltip: '刷新',
                onTap: () {
                  context.read<NotificationBloc>().add(
                    const NotificationRefresh(),
                  );
                },
                isDark: isDark,
              ),
            ],
          ),
        );
      },
    );
  }

  /// 消息筛选切换组件 - 服务端筛选
  Widget _buildNotificationFilterChips({
    required bool? filterIsRead,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilterChip(
            label: '全部',
            isSelected: filterIsRead == null,
            onTap: () {
              context.read<NotificationBloc>().add(
                const NotificationFetch(isRead: null),
              );
            },
            isDark: isDark,
          ),
          _buildFilterChip(
            label: '未读',
            isSelected: filterIsRead == false,
            onTap: () {
              context.read<NotificationBloc>().add(
                const NotificationFetch(isRead: false),
              );
            },
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0080FF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF0080FF),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 14,
              color: isDark ? Colors.white54 : const Color(0xFF9CA3AF),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildLoadingMore() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
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

  Widget _buildErrorState(String error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 28,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              label: '重试',
              onTap: () {
                context.read<NotificationBloc>().add(
                  const NotificationRefresh(),
                );
              },
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}

/// 公告项组件
class _AnnouncementItemWidget extends StatefulWidget {
  final int index;
  final int announcementId;
  final String title;
  final String content;
  final String type;
  final int createdAt;
  final bool isRead;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onMarkRead;

  const _AnnouncementItemWidget({
    required this.index,
    required this.announcementId,
    required this.title,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.isRead,
    required this.isDark,
    this.onTap,
    this.onMarkRead,
  });

  @override
  State<_AnnouncementItemWidget> createState() =>
      _AnnouncementItemWidgetState();
}

class _AnnouncementItemWidgetState extends State<_AnnouncementItemWidget> {
  bool _isHovered = false;

  Color _getTypeColor() {
    if (widget.isRead) {
      return const Color(0xFF9CA3AF);
    }
    switch (widget.type) {
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

  String _getContentPreview() {
    var text = widget.content
        .replaceAll(RegExp(r'[#*`>\[\]()]'), '')
        .replaceAll(RegExp(r'\n+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.length > 50 ? '${text.substring(0, 50)}...' : text;
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isRead
                    ? (_isHovered
                          ? (widget.isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF9FAFB))
                          : Colors.transparent)
                    : (widget.isDark
                          ? typeColor.withValues(alpha: 0.12)
                          : typeColor.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isHovered
                      ? (widget.isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : const Color(0xFFE5E7EB))
                      : (widget.isRead
                            ? Colors.transparent
                            : typeColor.withValues(alpha: 0.25)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 序号图标
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.isRead
                          ? (widget.isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFF3F4F6))
                          : typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.index}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 内容
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (!widget.isRead)
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: typeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: widget.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w600,
                                  color: widget.isRead
                                      ? (widget.isDark
                                            ? Colors.white54
                                            : const Color(0xFF9CA3AF))
                                      : (widget.isDark
                                            ? Colors.white
                                            : const Color(0xFF1F2937)),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getContentPreview(),
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isRead
                                ? (widget.isDark
                                      ? Colors.white38
                                      : const Color(0xFFD1D5DB))
                                : (widget.isDark
                                      ? Colors.white54
                                      : const Color(0xFF6B7280)),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          TimeUtils.formatTimestampRelative(widget.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: widget.isDark
                                ? Colors.white38
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 箭头
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: widget.isRead
                        ? (widget.isDark
                              ? Colors.white24
                              : const Color(0xFFE5E7EB))
                        : (widget.isDark
                              ? Colors.white24
                              : const Color(0xFFD1D5DB)),
                  ),
                ],
              ),
            ),
            // 浮动操作按钮
            if (_isHovered && !widget.isRead)
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildRoundActionButton(
                    icon: Icons.check,
                    tooltip: '标记已读',
                    onTap: widget.onMarkRead,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.check, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// 消息项组件
class _NotificationItemWidget extends StatefulWidget {
  final int index;
  final NotificationItem notification;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onMarkRead;
  final VoidCallback? onDelete;

  const _NotificationItemWidget({
    required this.index,
    required this.notification,
    required this.isDark,
    this.onTap,
    this.onMarkRead,
    this.onDelete,
  });

  @override
  State<_NotificationItemWidget> createState() =>
      _NotificationItemWidgetState();
}

class _NotificationItemWidgetState extends State<_NotificationItemWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final typeColor = _getTypeColor(notification.type);
    final displayColor = notification.isRead
        ? const Color(0xFF9CA3AF)
        : typeColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: notification.isRead
                    ? (_isHovered
                          ? (widget.isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF9FAFB))
                          : Colors.transparent)
                    : (widget.isDark
                          ? typeColor.withValues(alpha: 0.08)
                          : typeColor.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isHovered
                      ? (widget.isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : const Color(0xFFE5E7EB))
                      : (notification.isRead
                            ? Colors.transparent
                            : typeColor.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 类型图标
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: displayColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTypeIcon(notification.type),
                      size: 18,
                      color: displayColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 内容
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (!notification.isRead)
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: typeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: notification.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w600,
                                  color: notification.isRead
                                      ? (widget.isDark
                                            ? Colors.white54
                                            : const Color(0xFF9CA3AF))
                                      : (widget.isDark
                                            ? Colors.white
                                            : const Color(0xFF1F2937)),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        MarkdownBody(
                          data: notification.content,
                          shrinkWrap: true,
                          softLineBreak: true,
                          onTapLink: (text, href, title) {
                            if (href != null) {
                              final uri = Uri.tryParse(href);
                              if (uri != null)
                                launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                            }
                          },
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: notification.isRead
                                  ? (widget.isDark
                                        ? Colors.white38
                                        : const Color(0xFFD1D5DB))
                                  : (widget.isDark
                                        ? Colors.white60
                                        : const Color(0xFF6B7280)),
                            ),
                            a: TextStyle(
                              fontSize: 12,
                              color: typeColor,
                              decoration: TextDecoration.underline,
                            ),
                            code: TextStyle(
                              fontSize: 11,
                              backgroundColor: widget.isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFF3F4F6),
                              color: notification.isRead
                                  ? (widget.isDark
                                        ? Colors.white38
                                        : const Color(0xFFD1D5DB))
                                  : (widget.isDark
                                        ? Colors.white70
                                        : const Color(0xFF374151)),
                            ),
                            listBullet: TextStyle(
                              fontSize: 12,
                              color: notification.isRead
                                  ? (widget.isDark
                                        ? Colors.white38
                                        : const Color(0xFFD1D5DB))
                                  : (widget.isDark
                                        ? Colors.white60
                                        : const Color(0xFF6B7280)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.formatDate(notification.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: widget.isDark
                                ? Colors.white38
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 浮动操作按钮
            if (_isHovered)
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!notification.isRead)
                        _buildRoundActionButton(
                          icon: Icons.check,
                          tooltip: '标记已读',
                          onTap: widget.onMarkRead,
                          color: const Color(0xFF10B981),
                        ),
                      if (!notification.isRead) const SizedBox(width: 8),
                      _buildRoundActionButton(
                        icon: Icons.delete_outline,
                        tooltip: '删除',
                        onTap: widget.onDelete,
                        color: const Color(0xFFEF4444),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case NotificationType.mapContributionAudit:
        return const Color(0xFF10B981);
      case NotificationType.keyConfigAudit:
        return const Color(0xFF8B5CF6);
      case NotificationType.issueComment:
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF0080FF);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case NotificationType.mapContributionAudit:
        return Icons.map_outlined;
      case NotificationType.keyConfigAudit:
        return Icons.keyboard_outlined;
      case NotificationType.issueComment:
        return Icons.comment_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Widget _buildRoundActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
