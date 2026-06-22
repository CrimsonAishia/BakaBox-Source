import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/crash_inspector/crash_inspector.dart';
import '../../core/utils/toast_utils.dart';
import '../../core/constants/app_colors.dart';

/// CS2 崩溃报告弹窗.
///
/// 当 [Cs2CrashMonitorService] 发现新的 .mdmp 文件并分析完成后, 由桌面端首页
/// 监听其事件流并弹出本对话框.
class Cs2CrashDialog extends StatefulWidget {
  final CrashSummary summary;

  const Cs2CrashDialog({super.key, required this.summary});

  static Future<void> show(BuildContext context, CrashSummary summary) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Cs2CrashDialog(summary: summary),
    );
  }

  @override
  State<Cs2CrashDialog> createState() => _Cs2CrashDialogState();
}

class _Cs2CrashDialogState extends State<Cs2CrashDialog> {
  bool _showFullReport = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = widget.summary;
    final palette = _palette(s.severity, isDark);

    final bg = isDark ? AppColors.slate800 : Colors.white;
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.slate200;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(summary: s, palette: palette, isDark: isDark),
            Container(height: 1, color: divider),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
                child: _showFullReport
                    ? _FullReportView(report: s.fullReport, isDark: isDark)
                    : _SummaryView(
                        summary: s,
                        palette: palette,
                        isDark: isDark,
                      ),
              ),
            ),
            Container(height: 1, color: divider),
            _Footer(
              summary: s,
              palette: palette,
              isDark: isDark,
              showFullReport: _showFullReport,
              onToggleFull: () {
                setState(() => _showFullReport = !_showFullReport);
              },
            ),
          ],
        ),
      ),
    );
  }
}


class _Header extends StatelessWidget {
  final CrashSummary summary;
  final _SeverityPalette palette;
  final bool isDark;
  const _Header({
    required this.summary,
    required this.palette,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.slate800;
    final secondary = isDark ? Colors.white70 : AppColors.slate500;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(palette.icon, color: palette.accent, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'CS2 崩溃报告',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _SeverityChip(palette: palette),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  summary.headline,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: secondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: secondary),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '关闭',
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final _SeverityPalette palette;
  const _SeverityChip({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        palette.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: palette.accent,
        ),
      ),
    );
  }
}


class _SummaryView extends StatelessWidget {
  final CrashSummary summary;
  final _SeverityPalette palette;
  final bool isDark;
  const _SummaryView({
    required this.summary,
    required this.palette,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetaCard(summary: summary, palette: palette, isDark: isDark),
        if (summary.fatalStrings.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle(
            icon: MdiIcons.alertOctagonOutline,
            text: '致命错误',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          ...summary.fatalStrings.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MonoBlock(
                text: s,
                isDark: isDark,
                accent: palette.accent,
              ),
            ),
          ),
        ],
        if (summary.resources.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle(
            icon: MdiIcons.fileSearchOutline,
            text: '嫌疑资源',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          ...summary.resources.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ResourceTile(entry: r, isDark: isDark),
            ),
          ),
        ],
        if (summary.workshopIds.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle(
            icon: MdiIcons.steam,
            text: '相关 Workshop 订阅',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: summary.workshopIds
                .map((id) => _WorkshopChip(id: id, isDark: isDark))
                .toList(),
          ),
        ],
        if (summary.thirdPartyModules.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle(
            icon: MdiIcons.puzzleOutline,
            text: '第三方注入',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          ...summary.thirdPartyModules.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ThirdPartyTile(entry: e, isDark: isDark),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetaCard extends StatelessWidget {
  final CrashSummary summary;
  final _SeverityPalette palette;
  final bool isDark;
  const _MetaCard({
    required this.summary,
    required this.palette,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF273449) : AppColors.slate100;
    final textColor = isDark ? Colors.white : AppColors.slate800;
    final secondary = isDark ? Colors.white70 : AppColors.slate500;

    final pairs = <(String, String)>[
      ('类别', summary.categoryLabel),
      if (summary.crashModule != null) ('崩溃模块', summary.crashModule!),
      if (summary.exceptionCodeName != null) ('异常', summary.exceptionCodeName!),
      ('时间', _formatTime(summary.createdAt)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: pairs
            .map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        p.$1,
                        style: TextStyle(fontSize: 12.5, color: secondary),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        p.$2,
                        style: TextStyle(
                          fontSize: 13,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  const _SectionTitle({
    required this.icon,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDark ? Colors.white : AppColors.slate800;
    return Row(
      children: [
        Icon(icon, size: 16, color: color.withValues(alpha: 0.85)),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ThirdPartyTile extends StatelessWidget {
  final CrashThirdPartyEntry entry;
  final bool isDark;
  const _ThirdPartyTile({required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final palette = _thirdPartyPalette(entry.severity);
    final bg = isDark ? const Color(0xFF273449) : AppColors.slate50;
    final textColor = isDark ? Colors.white : AppColors.slate800;
    final secondary = isDark ? Colors.white70 : AppColors.slate500;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.$1.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: palette.$1.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              palette.$2,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: palette.$1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (entry.label.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '· ${entry.label}',
                          style: TextStyle(fontSize: 12.5, color: secondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (entry.advice.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.advice,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: secondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  final CrashResourceEntry entry;
  final bool isDark;
  const _ResourceTile({required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
    final textColor = isDark ? Colors.white : AppColors.slate800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              entry.kindLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              entry.path,
              style: TextStyle(
                fontSize: 12.5,
                color: textColor,
                fontFamily: 'Consolas',
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkshopChip extends StatelessWidget {
  final String id;
  final bool isDark;
  const _WorkshopChip({required this.id, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF0EA5E9);
    final textColor = isDark ? Colors.white : AppColors.slate800;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () async {
        final uri = Uri.parse(
          'https://steamcommunity.com/sharedfiles/filedetails/?id=$id',
        );
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(MdiIcons.openInNew, size: 13, color: accent),
            const SizedBox(width: 6),
            Text(
              id,
              style: TextStyle(
                fontSize: 12.5,
                color: textColor,
                fontFamily: 'Consolas',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonoBlock extends StatelessWidget {
  final String text;
  final bool isDark;
  final Color accent;
  const _MonoBlock({
    required this.text,
    required this.isDark,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.black.withValues(alpha: 0.28)
        : AppColors.slate100;
    final textColor = isDark ? Colors.white : AppColors.slate800;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontFamily: 'Consolas',
          height: 1.5,
          color: textColor,
        ),
      ),
    );
  }
}


class _FullReportView extends StatelessWidget {
  final String report;
  final bool isDark;
  const _FullReportView({required this.report, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.black.withValues(alpha: 0.32)
        : AppColors.slate900;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        report,
        style: const TextStyle(
          fontSize: 12,
          height: 1.5,
          fontFamily: 'Consolas',
          color: AppColors.slate200,
        ),
      ),
    );
  }
}


class _Footer extends StatelessWidget {
  final CrashSummary summary;
  final _SeverityPalette palette;
  final bool isDark;
  final bool showFullReport;
  final VoidCallback onToggleFull;

  const _Footer({
    required this.summary,
    required this.palette,
    required this.isDark,
    required this.showFullReport,
    required this.onToggleFull,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onToggleFull,
            icon: Icon(
              showFullReport
                  ? MdiIcons.viewListOutline
                  : MdiIcons.codeBracesBox,
              size: 16,
            ),
            label: Text(showFullReport ? '返回摘要' : '查看完整报告'),
          ),
          const Spacer(),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_outlined, size: 16),
            label: const Text('复制完整报告'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: summary.fullReport));
              ToastUtils.showSuccess(context, '已复制崩溃报告');
            },
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('我知道了', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}


class _SeverityPalette {
  final String label;
  final Color accent;
  final IconData icon;
  const _SeverityPalette({
    required this.label,
    required this.accent,
    required this.icon,
  });
}

_SeverityPalette _palette(CrashSeverity severity, bool isDark) {
  switch (severity) {
    case CrashSeverity.high:
      return _SeverityPalette(
        label: '严重',
        accent: AppColors.red500,
        icon: MdiIcons.alertOctagon,
      );
    case CrashSeverity.medium:
      return _SeverityPalette(
        label: '警告',
        accent: AppColors.amber500,
        icon: MdiIcons.alert,
      );
    case CrashSeverity.low:
      return _SeverityPalette(
        label: '一般',
        accent: AppColors.blue500,
        icon: MdiIcons.informationOutline,
      );
  }
}

(Color, String) _thirdPartyPalette(String sev) {
  switch (sev) {
    case 'high':
      return (AppColors.red500, '严重');
    case 'benign':
      return (AppColors.emerald500, '正常');
    case 'medium':
    default:
      return (AppColors.amber500, '可疑');
  }
}
