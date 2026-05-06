import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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
                            padding: const EdgeInsets.only(bottom: 8),
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
            .fadeIn(duration: 500.ms, delay: 700.ms)
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
    // 取第一行作为摘要
    final summary = widget.log.content.split('\n').first.trim();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? (widget.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.04))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  summary.isEmpty ? '（无内容）' : summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.8)
                        : const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDate(widget.log.updateTime),
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : const Color(0xFFCBD5E1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr.length > 10 ? dateStr.substring(5, 10) : dateStr;
    }
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 560),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题行
            Row(
              children: [
                const Icon(
                  Icons.update,
                  size: 20,
                  color: Color(0xFF3B82F6),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '更新日志 · ${log.updateTime}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                ),
              ],
            ),
            const Divider(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  log.content,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.8,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.85)
                        : const Color(0xFF334155),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
