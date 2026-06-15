import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/crash_report_models.dart';
import '../../../core/utils/time_utils.dart';
import 'crash_report_palette.dart';

/// 社区崩溃报告列表卡片（匿名 / 不带作者维度）
class CrashReportCard extends StatefulWidget {
  final CrashReportListItem report;
  final bool selected;
  final VoidCallback onTap;

  const CrashReportCard({
    super.key,
    required this.report,
    required this.onTap,
    this.selected = false,
  });

  @override
  State<CrashReportCard> createState() => _CrashReportCardState();
}

class _CrashReportCardState extends State<CrashReportCard> {
  bool _hover = false;


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CrashReportPalette.of(widget.report.severityEnum);
    final bg = isDark ? AppColors.slate800 : Colors.white;
    final borderColor = widget.selected
        ? palette.accent
        : (_hover
              ? palette.accent.withValues(alpha: 0.45)
              : (isDark ? AppColors.slate700 : AppColors.gray200));
    final textColor = isDark ? Colors.white : AppColors.gray800;
    final secondary = isDark ? Colors.white60 : AppColors.gray500;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: widget.selected ? 1.5 : 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: palette.accent.withValues(
                        alpha: isDark ? 0.18 : 0.12,
                      ),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: palette.accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(palette, secondary, isDark),
                        const SizedBox(height: 8),
                        _buildHeadline(textColor),
                        const SizedBox(height: 10),
                        _buildFooter(palette, secondary, isDark),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildHeader(
    CrashReportPalette palette,
    Color secondary,
    bool isDark,
  ) {
    return Row(
      children: [
        // 严重度徽标
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(palette.icon, size: 12, color: palette.accent),
              const SizedBox(width: 4),
              Text(
                palette.label,
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // 类别
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate700 : AppColors.gray100,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                crashCategoryIcon(widget.report.category),
                size: 12,
                color: secondary,
              ),
              const SizedBox(width: 4),
              Text(
                widget.report.categoryLabel.isEmpty
                    ? '未知'
                    : widget.report.categoryLabel,
                style: TextStyle(
                  color: secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (widget.report.similarCount > 1) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.violet500.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(MdiIcons.linkVariant,
                    size: 12, color: AppColors.violet500),
                const SizedBox(width: 4),
                Text(
                  '同款 ${widget.report.similarCount}',
                  style: const TextStyle(
                    color: AppColors.violet500,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
        const Spacer(),
        Text(
          TimeUtils.formatDateTimeRelative(widget.report.dumpAt),
          style: TextStyle(color: secondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildHeadline(Color textColor) {
    return Text(
      widget.report.headline,
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFooter(
    CrashReportPalette palette,
    Color secondary,
    bool isDark,
  ) {
    final crashModule = widget.report.crashModule;
    final appVersion = widget.report.appVersion;
    final gpuVendor = widget.report.gpuVendor;
    return Row(
      children: [
        if (crashModule != null && crashModule.isNotEmpty) ...[
          Icon(MdiIcons.fileCodeOutline, size: 14, color: secondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              crashModule,
              style: TextStyle(
                color: secondary,
                fontSize: 12,
                fontFamily: 'Consolas',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
        ],
        if (widget.report.exceptionCode != null) ...[
          Icon(MdiIcons.bug, size: 13, color: secondary),
          const SizedBox(width: 4),
          Text(
            '0x${widget.report.exceptionCode!.toUpperCase()}',
            style: TextStyle(
              color: secondary,
              fontSize: 12,
              fontFamily: 'Consolas',
            ),
          ),
          const SizedBox(width: 10),
        ],
        const Spacer(),
        if (gpuVendor != null && gpuVendor.isNotEmpty) ...[
          Icon(MdiIcons.memory, size: 13, color: secondary),
          const SizedBox(width: 4),
          Text(
            gpuVendor,
            style: TextStyle(color: secondary, fontSize: 12),
          ),
          const SizedBox(width: 10),
        ],
        if (appVersion != null && appVersion.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate700 : AppColors.gray100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'v$appVersion',
              style: TextStyle(
                color: secondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Consolas',
              ),
            ),
          ),
      ],
    );
  }
}
