import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/core.dart';

/// 更新日志面板
class UpdateLogsPanel extends StatelessWidget {
  final bool isDark;

  const UpdateLogsPanel({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UpdateLogBloc, UpdateLogState>(
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
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
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
                        MdiIcons.update,
                        size: 16,
                        color: const Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '更新日志',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
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

                  // 日志列表
                  if (state.logs.isEmpty && !state.isLoading)
                    Expanded(child: _buildEmpty())
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: state.logs.length,
                        itemBuilder: (context, index) {
                          final log = state.logs[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: _UpdateLogItem(
                              log: log,
                              isDark: isDark,
                              onTap: () => _showDetail(context, log),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 500.ms, delay: 800.ms)
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
        '暂无更新日志',
        style: TextStyle(
          fontSize: 13,
          color: isDark
              ? Colors.white.withValues(alpha: 0.4)
              : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, SteamWorkChangeLog log) {
    showDialog(
      context: context,
      builder: (ctx) => _UpdateLogDetailDialog(log: log),
    );
  }
}

/// 单条更新日志行
class _UpdateLogItem extends StatefulWidget {
  final SteamWorkChangeLog log;
  final bool isDark;
  final VoidCallback onTap;

  const _UpdateLogItem({
    required this.log,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_UpdateLogItem> createState() => _UpdateLogItemState();
}

class _UpdateLogItemState extends State<_UpdateLogItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    // 取第一行作为摘要（去掉 HTML 标签）
    final rawSummary = widget.log.content.split('\n').first.trim();
    final summary = rawSummary
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&[a-z]+;'), ' ')
        .trim();
    final accentColor = const Color(0xFF3B82F6);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered
                ? (widget.isDark
                      ? accentColor.withValues(alpha: 0.08)
                      : accentColor.withValues(alpha: 0.04))
                : (widget.isDark
                      ? Colors.white.withValues(alpha: 0.02)
                      : Colors.white.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? accentColor.withValues(alpha: 0.3)
                  : (widget.isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
            ),
          ),
          child: Row(
            children: [
              // 图标
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  MdiIcons.fileDocumentOutline,
                  size: 14,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 10),

              // 摘要 + 时间
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      summary.isEmpty ? '（无内容）' : summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.85)
                            : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(widget.log.updateTime),
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
                  color: accentColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    return TimeUtils.formatRelative(dateStr);
  }
}

/// 更新日志详情弹窗
class _UpdateLogDetailDialog extends StatelessWidget {
  final SteamWorkChangeLog log;

  const _UpdateLogDetailDialog({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // 优先使用 rawHtml，fallback 到 content
    final htmlContent = log.rawHtml.isNotEmpty ? log.rawHtml : log.content;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 580),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题区
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.update,
                      size: 18,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '更新日志',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          TimeUtils.formatFull(log.updateTime),
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
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 内容区（HTML 渲染）
            Flexible(
              child: htmlContent.isEmpty
                  ? Center(
                      child: Text(
                        '暂无详细内容',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Html(
                        data: htmlContent,
                        onLinkTap: (url, attributes, element) {
                          if (url != null) _launchUrl(url);
                        },
                        style: {
                          'body': Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                            fontSize: FontSize(14),
                            lineHeight: const LineHeight(1.7),
                            color: isDark
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF374151),
                          ),
                          'p': Style(margin: Margins.only(bottom: 12)),
                          'h1': Style(
                            fontSize: FontSize(18),
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1F2937),
                            margin: Margins.only(top: 16, bottom: 12),
                          ),
                          'h2': Style(
                            fontSize: FontSize(16),
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1F2937),
                            margin: Margins.only(top: 14, bottom: 10),
                          ),
                          'h3': Style(
                            fontSize: FontSize(15),
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1F2937),
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
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1F2937),
                          ),
                          'em': Style(
                            fontStyle: FontStyle.italic,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF6B7280),
                          ),
                          'a': Style(
                            color: const Color(0xFF3B82F6),
                            textDecoration: TextDecoration.none,
                          ),
                          'code': Style(
                            backgroundColor: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFF3F4F6),
                            color: isDark
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFE74C3C),
                            padding: HtmlPaddings.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
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
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFFD1D5DB),
                                width: 4,
                              ),
                            ),
                            padding: HtmlPaddings.only(left: 16),
                            margin: Margins.symmetric(vertical: 12),
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF6B7280),
                            fontStyle: FontStyle.italic,
                          ),
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
