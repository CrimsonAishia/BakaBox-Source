import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/crash_report_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/utils/toast_utils.dart';
import 'crash_detail_view_model.dart';
import 'crash_report_palette.dart';

/// 通用崩溃详情面板，远端 / 本地共用
///
/// 在外层（[CrashReportTool]）根据"我的 vs 全部"映射出 [CrashDetailViewModel]
/// 后传进来即可，本组件不感知数据来源差异，只感知 [CrashDetailViewModel.isLocal]
/// 用于决定是否展示"本地"徽标 / "找同款"按钮。
class CrashDetailPane extends StatefulWidget {
  final CrashDetailViewModel? detail;
  final bool isLoading;
  final VoidCallback onBack;

  /// 详情上下文给本地 dump 提供"删除 .mdmp 文件"
  final VoidCallback? onDeleteLocal;

  /// 远端详情提供"找同款 (按 signature)"，本地 dump 不展示
  final ValueChanged<String>? onFindSimilar;

  const CrashDetailPane({
    super.key,
    required this.detail,
    required this.isLoading,
    required this.onBack,
    this.onDeleteLocal,
    this.onFindSimilar,
  });

  @override
  State<CrashDetailPane> createState() => _CrashDetailPaneState();
}

class _CrashDetailPaneState extends State<CrashDetailPane> {
  bool _showFullReport = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final detail = widget.detail;
    if (detail == null) return _buildEmpty();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CrashReportPalette.of(detail.severity);
    final bg = isDark ? AppColors.slate800 : Colors.white;
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.slate200;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.gray200,
        ),
      ),
      child: Column(
        children: [
          _DetailHeader(
            detail: detail,
            palette: palette,
            isDark: isDark,
            onBack: widget.onBack,
          ),
          Container(height: 1, color: divider),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: _showFullReport
                  ? _FullReport(report: detail.fullReport, isDark: isDark)
                  : _SummaryView(
                      detail: detail,
                      palette: palette,
                      isDark: isDark,
                    ),
            ),
          ),
          Container(height: 1, color: divider),
          _DetailFooter(
            detail: detail,
            palette: palette,
            isDark: isDark,
            showFullReport: _showFullReport,
            onToggleFull: () =>
                setState(() => _showFullReport = !_showFullReport),
            onCopy: () {
              Clipboard.setData(ClipboardData(text: detail.fullReport));
              ToastUtils.showSuccess(context, '已复制完整崩溃报告');
            },
            onDeleteLocal: widget.onDeleteLocal,
            onFindSimilar: !detail.isLocal && detail.signature != null
                ? () => widget.onFindSimilar?.call(detail.signature!)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            MdiIcons.fileSearchOutline,
            size: 60,
            color: isDark ? Colors.white24 : AppColors.gray300,
          ),
          const SizedBox(height: 16),
          Text(
            '从左侧选择一份崩溃报告',
            style: TextStyle(
              color: isDark ? Colors.white54 : AppColors.gray500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Header (极简：图标 + 严重度徽标 + 标题 + 关闭按钮)
class _DetailHeader extends StatelessWidget {
  final CrashDetailViewModel detail;
  final CrashReportPalette palette;
  final bool isDark;
  final VoidCallback onBack;

  const _DetailHeader({
    required this.detail,
    required this.palette,
    required this.isDark,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.slate800;
    final secondary = isDark ? Colors.white60 : AppColors.slate500;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(palette.icon, color: palette.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'CS2 崩溃报告',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Badge(color: palette.accent, label: palette.label),
                    if (detail.isLocal) ...[
                      const SizedBox(width: 6),
                      _Badge(
                        color: AppColors.primary,
                        label: '本地',
                        outlined: true,
                      ),
                    ] else if (detail.similarCount > 1) ...[
                      const SizedBox(width: 6),
                      _Badge(
                        color: AppColors.violet500,
                        icon: MdiIcons.linkVariant,
                        label: '同款 ${detail.similarCount}',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  detail.headline,
                  style: TextStyle(
                    fontSize: 13,
                    color: secondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: secondary, size: 18),
            onPressed: onBack,
            tooltip: '返回',
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}

// Footer (操作按钮全部下沉到底部)
class _DetailFooter extends StatelessWidget {
  final CrashDetailViewModel detail;
  final CrashReportPalette palette;
  final bool isDark;
  final bool showFullReport;
  final VoidCallback onToggleFull;
  final VoidCallback onCopy;
  final VoidCallback? onDeleteLocal;
  final VoidCallback? onFindSimilar;

  const _DetailFooter({
    required this.detail,
    required this.palette,
    required this.isDark,
    required this.showFullReport,
    required this.onToggleFull,
    required this.onCopy,
    required this.onDeleteLocal,
    required this.onFindSimilar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
          if (onFindSimilar != null) ...[
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: onFindSimilar,
              icon: Icon(MdiIcons.linkVariant, size: 16),
              label: const Text('找同款'),
            ),
          ],
          const Spacer(),
          if (onDeleteLocal != null) ...[
            OutlinedButton.icon(
              onPressed: onDeleteLocal,
              icon: Icon(
                MdiIcons.deleteOutline,
                size: 16,
                color: AppColors.red500,
              ),
              label: const Text(
                '删除',
                style: TextStyle(color: AppColors.red500),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppColors.red500.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_outlined, size: 16),
            label: const Text('复制完整报告'),
            onPressed: onCopy,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String label;
  final bool outlined;

  const _Badge({
    required this.color,
    required this.label,
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: outlined ? 0.10 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: outlined
            ? Border.all(color: color.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// Summary view
class _SummaryView extends StatelessWidget {
  final CrashDetailViewModel detail;
  final CrashReportPalette palette;
  final bool isDark;

  const _SummaryView({
    required this.detail,
    required this.palette,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetaCard(detail: detail, palette: palette, isDark: isDark),
        if (detail.fatalStrings.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle(
            icon: MdiIcons.alertOctagonOutline,
            text: '致命错误',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          ...detail.fatalStrings.map(
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
        if (detail.resources.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle(
            icon: MdiIcons.fileSearchOutline,
            text: '嫌疑资源',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          ...detail.resources.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ResourceTile(entry: r, isDark: isDark),
            ),
          ),
        ],
        if (detail.workshopIds.isNotEmpty) ...[
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
            children: detail.workshopIds
                .map((id) => _WorkshopChip(id: id, isDark: isDark))
                .toList(),
          ),
        ],
        if (detail.thirdPartyModules.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle(
            icon: MdiIcons.puzzleOutline,
            text: '第三方注入',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          ...detail.thirdPartyModules.map(
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
  final CrashDetailViewModel detail;
  final CrashReportPalette palette;
  final bool isDark;

  const _MetaCard({
    required this.detail,
    required this.palette,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF273449) : AppColors.slate100;
    final textColor = isDark ? Colors.white : AppColors.slate800;
    final secondary = isDark ? Colors.white60 : AppColors.slate500;

    final pairs = <(String, String)>[
      ('类别', detail.category.label),
      if (detail.crashModule != null && detail.crashModule!.isNotEmpty)
        ('崩溃模块', detail.crashModule!),
      if (detail.exceptionCodeName != null)
        (
          '异常',
          '0x${(detail.exceptionCode ?? '').toUpperCase()}'
              ' · ${detail.exceptionCodeName}',
        ),
      if (detail.fileSize != null)
        ('文件大小', Formatters.formatFileSize(detail.fileSize!)),
      if (detail.osVersion != null) ('操作系统', detail.osVersion!),
      if (detail.gpuVendor != null) ('显卡厂商', detail.gpuVendor!),
      if (detail.appVersion != null) ('客户端版本', 'v${detail.appVersion}'),
      ('崩溃时刻', TimeUtils.formatDateTimeRelative(detail.dumpAt)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.accent.withValues(alpha: 0.2)),
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
                      width: 80,
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

class _ResourceTile extends StatelessWidget {
  final CrashReportResource entry;
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
    const accent = Color(0xFF0EA5E9);
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

class _ThirdPartyTile extends StatelessWidget {
  final CrashReportThirdParty entry;
  final bool isDark;

  const _ThirdPartyTile({required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final palette = crashThirdPartyPalette(entry.severity);
    final bg = isDark ? const Color(0xFF273449) : AppColors.slate50;
    final textColor = isDark ? Colors.white : AppColors.slate800;
    final secondary = isDark ? Colors.white70 : AppColors.slate500;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: palette.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              palette.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: palette.color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: entry.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (entry.label.isNotEmpty)
                        TextSpan(
                          text: '  ·  ${entry.label}',
                          style: TextStyle(fontSize: 12.5, color: secondary),
                        ),
                    ],
                  ),
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

class _FullReport extends StatelessWidget {
  final String report;
  final bool isDark;

  const _FullReport({required this.report, required this.isDark});

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
