import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/core.dart';

/// 公告面板
class AnnouncementsPanel extends StatelessWidget {
  final bool isDark;

  const AnnouncementsPanel({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
      builder: (context, state) {
        return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行
                  Row(
                    children: [
                      Icon(
                        MdiIcons.bullhorn,
                        size: 16,
                        color: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '公告',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      if (state.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${state.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (state.isLoading)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 公告列表
                  if (state.announcements.isEmpty && !state.isLoading)
                    Expanded(child: _buildEmpty())
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: state.announcements.length,
                        itemBuilder: (context, index) {
                          final item = state.announcements[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _AnnouncementItem(
                              item: item,
                              isRead: state.isRead(item.id),
                              isDark: isDark,
                              onTap: () {
                                context.read<AnnouncementBloc>().add(
                                  AnnouncementMarkAsRead(item.id),
                                );
                                _showDetail(context, item);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 500.ms, delay: 650.ms)
            .slideY(
              begin: 0.2,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Text(
        '暂无公告',
        style: TextStyle(
          fontSize: 13,
          color: isDark
              ? Colors.white.withValues(alpha: 0.4)
              : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, AnnouncementItem item) {
    showDialog(
      context: context,
      builder: (ctx) => _AnnouncementDetailDialog(item: item),
    );
  }
}

/// 单条公告行
class _AnnouncementItem extends StatefulWidget {
  final AnnouncementItem item;
  final bool isRead;
  final bool isDark;
  final VoidCallback onTap;

  const _AnnouncementItem({
    required this.item,
    required this.isRead,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_AnnouncementItem> createState() => _AnnouncementItemState();
}

class _AnnouncementItemState extends State<_AnnouncementItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(widget.item.type);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered
                ? (widget.isDark
                      ? typeColor.withValues(alpha: 0.08)
                      : typeColor.withValues(alpha: 0.05))
                : (widget.isDark
                      ? Colors.white.withValues(alpha: 0.02)
                      : Colors.white.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? typeColor.withValues(alpha: 0.3)
                  : (widget.isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
            ),
          ),
          child: Row(
            children: [
              // 类型图标
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: widget.isRead ? 0.08 : 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  widget.item.isSticky ? MdiIcons.pin : MdiIcons.bullhornOutline,
                  size: 14,
                  color: widget.isRead
                      ? typeColor.withValues(alpha: 0.5)
                      : typeColor,
                ),
              ),
              const SizedBox(width: 10),

              // 标题 + 时间
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (!widget.isRead)
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: typeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            widget.item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: widget.isRead ? FontWeight.w400 : FontWeight.w600,
                              color: widget.isDark
                                  ? Colors.white.withValues(alpha: widget.isRead ? 0.5 : 0.9)
                                  : (widget.isRead
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF1E293B)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatTime(widget.item.createdAt),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.3)
                            : const Color(0xFFB0B8C4),
                      ),
                    ),
                  ],
                ),
              ),

              // hover 时显示箭头
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _hovered ? 1.0 : 0.0,
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: typeColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    return switch (type) {
      'success' => const Color(0xFF10B981),
      'warning' => const Color(0xFFF59E0B),
      'error' => const Color(0xFFEF4444),
      'maintenance' => const Color(0xFF8B5CF6),
      _ => const Color(0xFF3B82F6), // info
    };
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      if (diff.inHours >= 1) return '${diff.inHours}小时前';
      if (diff.inMinutes >= 1) return '${diff.inMinutes}分钟前';
      return '刚刚';
    }
    if (dt.year == now.year) {
      return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

/// 公告详情弹窗
class _AnnouncementDetailDialog extends StatelessWidget {
  final AnnouncementItem item;

  const _AnnouncementDetailDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final typeColor = _typeColor(item.type);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题区
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: typeColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatFullTime(item.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.4)
                                : const Color(0xFF94A3B8),
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
            // 内容区（Markdown 渲染）
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: MarkdownBody(
                  data: item.content,
                  selectable: true,
                  onTapLink: (text, href, title) {
                    if (href != null) _launchUrl(href);
                  },
                  styleSheet: _buildMarkdownStyle(isDark, typeColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    return switch (type) {
      'success' => const Color(0xFF10B981),
      'warning' => const Color(0xFFF59E0B),
      'error' => const Color(0xFFEF4444),
      'maintenance' => const Color(0xFF8B5CF6),
      _ => const Color(0xFF3B82F6),
    };
  }

  String _formatFullTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
        backgroundColor: isDark
            ? const Color(0xFF374151)
            : const Color(0xFFF3F4F6),
        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
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
      listBullet: TextStyle(
        fontSize: 14,
        color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
      ),
    );
  }
}
