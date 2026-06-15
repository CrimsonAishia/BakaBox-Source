import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/local_crash_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_utils.dart';

/// 本地 .mdmp 文件列表卡片（"我的"视图使用）
class LocalCrashCard extends StatefulWidget {
  final LocalCrashFileInfo file;
  final bool selected;
  final VoidCallback onTap;

  const LocalCrashCard({
    super.key,
    required this.file,
    required this.onTap,
    this.selected = false,
  });

  @override
  State<LocalCrashCard> createState() => _LocalCrashCardState();
}

class _LocalCrashCardState extends State<LocalCrashCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.slate800 : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.gray800;
    final secondary = isDark ? Colors.white60 : AppColors.gray500;
    final accent = AppColors.primary;
    final borderColor = widget.selected
        ? accent
        : (_hover
              ? accent.withValues(alpha: 0.45)
              : (isDark ? AppColors.slate700 : AppColors.gray200));

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
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                      color: accent.withValues(
                        alpha: isDark ? 0.18 : 0.12,
                      ),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  MdiIcons.fileDocumentOutline,
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.file.fileName,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        fontFamily: 'Consolas',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          MdiIcons.clockOutline,
                          size: 12,
                          color: secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          TimeUtils.formatDateTimeRelative(
                            widget.file.modified,
                          ),
                          style:
                              TextStyle(fontSize: 12, color: secondary),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          MdiIcons.databaseOutline,
                          size: 12,
                          color: secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          Formatters.formatFileSize(widget.file.size),
                          style:
                              TextStyle(fontSize: 12, color: secondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
