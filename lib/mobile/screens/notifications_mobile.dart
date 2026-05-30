import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/core.dart';
import '../../core/models/notification_models.dart';

/// 移动端消息通知页面（包含公告和消息两个 Tab）
class NotificationsMobile extends StatefulWidget {
  const NotificationsMobile({super.key});

  @override
  State<NotificationsMobile> createState() => _NotificationsMobileState();
}

class _NotificationsMobileState extends State<NotificationsMobile>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<AnnouncementBloc>().add(AnnouncementFetch());
    // 只有登录用户才请求消息
    if (AuthService.instance.isLoggedIn) {
      context.read<NotificationBloc>().add(const NotificationFetch());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('消息中心'),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          tabs: [
            BlocBuilder<AnnouncementBloc, AnnouncementState>(
              builder: (context, state) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('公告'),
                    if (state.unreadCount > 0) ...[
                      const SizedBox(width: 6),
                      _buildBadge(state.unreadCount, theme),
                    ],
                  ],
                ),
              ),
            ),
            BlocBuilder<NotificationBloc, NotificationState>(
              builder: (context, state) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('消息'),
                    if (state.hasUnread) ...[
                      const SizedBox(width: 6),
                      _buildBadge(state.unreadCount, theme),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_AnnouncementTab(), _NotificationTab()],
      ),
    );
  }

  Widget _buildBadge(int count, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 公告 Tab
class _AnnouncementTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
      builder: (context, state) {
        if (state.isLoading && state.announcements.isEmpty) {
          return const _LoadingState();
        }

        if (state.error != null && state.announcements.isEmpty) {
          return _ErrorState(
            error: state.error!,
            onRetry: () =>
                context.read<AnnouncementBloc>().add(AnnouncementFetch()),
          );
        }

        if (state.announcements.isEmpty) {
          return const _EmptyState(isAnnouncement: true);
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<AnnouncementBloc>().add(AnnouncementRefresh());
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: state.announcements.length,
            itemBuilder: (context, index) {
              final announcement = state.announcements[index];
              final isRead = state.isRead(announcement.id);
              return _AnnouncementItem(
                announcement: announcement,
                isRead: isRead,
                index: index,
              );
            },
          ),
        );
      },
    );
  }
}

/// 公告项
class _AnnouncementItem extends StatelessWidget {
  final AnnouncementItem announcement;
  final bool isRead;
  final int index;

  const _AnnouncementItem({
    required this.announcement,
    required this.isRead,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final content = announcement.content;

    final accentColor = announcement.isSticky
        ? colorScheme.error
        : colorScheme.primary;

    return GestureDetector(
          onTap: () {
            if (!isRead) {
              context.read<AnnouncementBloc>().add(
                AnnouncementMarkAsRead(announcement.id),
              );
            }
            // 获取详情并增加阅读量
            context.read<AnnouncementBloc>().add(
              AnnouncementFetchDetail(announcement.id),
            );
            _showDetailSheet(
              context: context,
              icon: announcement.isSticky
                  ? MdiIcons.pin
                  : MdiIcons.bullhornOutline,
              iconColor: accentColor,
              title: announcement.title,
              subtitle: _formatTimestamp(announcement.createdAt),
              content: announcement.content,
              badge: announcement.isSticky ? '置顶' : null,
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: !isRead
                        ? accentColor.withValues(alpha: 0.3)
                        : colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isRead) Container(height: 3, color: accentColor),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              announcement.isSticky
                                  ? MdiIcons.pin
                                  : MdiIcons.bullhornOutline,
                              color: accentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (announcement.isSticky)
                                      Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.error,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          '置顶',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        announcement.title,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              fontWeight: isRead
                                                  ? FontWeight.w500
                                                  : FontWeight.w600,
                                              color: colorScheme.onSurface,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (content.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 40,
                                    child: ShaderMask(
                                      shaderCallback: (Rect bounds) {
                                        return LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.white,
                                            Colors.white,
                                            Colors.transparent,
                                          ],
                                          stops: const [0.0, 0.6, 1.0],
                                        ).createShader(bounds);
                                      },
                                      blendMode: BlendMode.dstIn,
                                      child: SingleChildScrollView(
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        child: MarkdownBody(
                                          data: content,
                                          shrinkWrap: true,
                                          fitContent: true,
                                          styleSheet: MarkdownStyleSheet(
                                            p: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                  height: 1.4,
                                                ),
                                            a: TextStyle(
                                              color: colorScheme.primary,
                                              fontSize: 12,
                                            ),
                                          ),
                                          onTapLink: (text, href, title) {
                                            if (href != null) {
                                              launchUrl(
                                                Uri.parse(href),
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      MdiIcons.clockOutline,
                                      size: 12,
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatTimestamp(announcement.createdAt),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.6),
                                          ),
                                    ),
                                  ],
                                ),
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
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: (index * 40).ms)
        .slideY(begin: 0.08);
  }

  String _formatTimestamp(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dateTime.month}月${dateTime.day}日';
  }
}

/// 消息 Tab
class _NotificationTab extends StatefulWidget {
  @override
  State<_NotificationTab> createState() => _NotificationTabState();
}

class _NotificationTabState extends State<_NotificationTab> {
  final ScrollController _scrollController = ScrollController();
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _wasAuthenticated = context.read<AuthBloc>().state.isAuthenticated;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = context.read<NotificationBloc>().state;
      if (!state.isLoadingMore && state.hasMore) {
        context.read<NotificationBloc>().add(const NotificationLoadMore());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, authState) {
        // 用户刚登录时，加载消息数据
        if (authState.isAuthenticated && !_wasAuthenticated) {
          context.read<NotificationBloc>().add(const NotificationFetch());
        }
        // 用户退出登录时，清除消息数据
        if (!authState.isAuthenticated && _wasAuthenticated) {
          context.read<NotificationBloc>().add(const NotificationClear());
        }
        _wasAuthenticated = authState.isAuthenticated;
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          // 未登录时显示提示
          if (!authState.isAuthenticated) {
            return const _NotLoggedInState();
          }

          return BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, state) {
              if (state.isLoading && state.notifications.isEmpty) {
                return const _LoadingState();
              }

              if (state.error != null && state.notifications.isEmpty) {
                return _ErrorState(
                  error: state.error!,
                  onRetry: () => context.read<NotificationBloc>().add(
                    const NotificationFetch(),
                  ),
                );
              }

              if (state.notifications.isEmpty) {
                return const _EmptyState(isAnnouncement: false);
              }

              return Column(
                children: [
                  if (state.hasUnread)
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => context
                                .read<NotificationBloc>()
                                .add(const NotificationMarkAllRead()),
                            icon: Icon(
                              Icons.done_all,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            label: Text(
                              '全部已读',
                              style: TextStyle(color: colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        context.read<NotificationBloc>().add(
                          const NotificationRefresh(),
                        );
                        await Future.delayed(const Duration(milliseconds: 500));
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          state.hasUnread ? 4 : 12,
                          16,
                          16,
                        ),
                        itemCount:
                            state.notifications.length +
                            (state.isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == state.notifications.length) {
                            return const _LoadMoreIndicator();
                          }
                          return _NotificationItemWidget(
                            notification: state.notifications[index],
                            index: index,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// 消息项
class _NotificationItemWidget extends StatelessWidget {
  final NotificationItem notification;
  final int index;

  const _NotificationItemWidget({
    required this.notification,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final typeColor = _getTypeColor(notification.type);

    return Dismissible(
          key: Key('notification_${notification.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colorScheme.error,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          onDismissed: (_) {
            context.read<NotificationBloc>().add(
              NotificationDelete(notification.id),
            );
          },
          child: GestureDetector(
            onTap: () {
              if (!notification.isRead) {
                context.read<NotificationBloc>().add(
                  NotificationMarkRead(notification.id),
                );
              }
              _showDetailSheet(
                context: context,
                icon: _getTypeIcon(notification.type),
                iconColor: typeColor,
                title: notification.title,
                subtitle: Formatters.formatDateTime(notification.createdAt),
                content: notification.content,
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: !notification.isRead
                          ? typeColor.withValues(alpha: 0.3)
                          : colorScheme.outlineVariant.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!notification.isRead)
                        Container(height: 3, color: typeColor),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getTypeIcon(notification.type),
                                color: typeColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notification.title,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: notification.isRead
                                          ? FontWeight.w500
                                          : FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    notification.content,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        MdiIcons.clockOutline,
                                        size: 12,
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        Formatters.formatDate(
                                          notification.createdAt,
                                        ),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: colorScheme
                                                  .onSurfaceVariant
                                                  .withValues(alpha: 0.6),
                                            ),
                                      ),
                                    ],
                                  ),
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
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: (index * 40).ms)
        .slideY(begin: 0.08);
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case NotificationType.mapContributionAudit:
        return MdiIcons.mapOutline;
      case NotificationType.keyConfigAudit:
        return MdiIcons.keyboardOutline;
      case NotificationType.issueComment:
        return MdiIcons.commentOutline;
      default:
        return MdiIcons.bellOutline;
    }
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
}

// ==================== 共享组件 ====================

/// 加载状态
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '加载中...',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// 空状态
class _EmptyState extends StatelessWidget {
  final bool isAnnouncement;

  const _EmptyState({required this.isAnnouncement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAnnouncement
                    ? MdiIcons.bullhornOutline
                    : MdiIcons.bellOffOutline,
                size: 48,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isAnnouncement ? '暂无公告' : '暂无消息',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAnnouncement ? '有新公告时会在这里显示' : '有新消息时会在这里显示',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 未登录状态
class _NotLoggedInState extends StatelessWidget {
  const _NotLoggedInState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                MdiIcons.accountOutline,
                size: 48,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '请先登录',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '登录后可查看您的消息通知',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 错误状态
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                MdiIcons.alertCircleOutline,
                size: 48,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '加载失败',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 加载更多指示器
class _LoadMoreIndicator extends StatelessWidget {
  const _LoadMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// 详情弹窗
void _showDetailSheet({
  required BuildContext context,
  required IconData icon,
  required Color iconColor,
  required String title,
  required String subtitle,
  required String content,
  String? badge,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示器
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 头部
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (badge != null)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.error,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (badge != null) const SizedBox(height: 6),
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            MdiIcons.clockOutline,
                            size: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          // 内容
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: MarkdownBody(
                  data: content,
                  selectable: true,
                  onTapLink: (text, href, title) {
                    if (href != null) {
                      launchUrl(
                        Uri.parse(href),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  styleSheet: MarkdownStyleSheet(
                    p: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.7,
                      color: colorScheme.onSurface,
                    ),
                    h1: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    h2: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    h3: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    code: TextStyle(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      color: colorScheme.primary,
                      fontSize: 13,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    blockquoteDecoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: colorScheme.primary, width: 3),
                      ),
                    ),
                    a: TextStyle(
                      color: colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 底部按钮
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('知道了'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
