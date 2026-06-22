import 'package:flutter/material.dart';

import '../../../../core/models/guide_models.dart';
import '../../../../core/utils/formatters.dart';
import '../community_guide/community_guide_theme.dart';

/// 草稿列表项卡片
class GuideMineDraftCard extends StatelessWidget {
  final GuideDraft draft;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const GuideMineDraftCard({
    super.key,
    required this.draft,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);

    return Material(
      color: colors.cardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.toolbarBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.accentBlue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.edit_note,
                  size: 22,
                  color: colors.accentBlue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      (draft.title ?? '').isNotEmpty ? draft.title! : '无标题草稿',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      draft.updatedAt != null
                          ? '上次编辑：${Formatters.formatDate(draft.updatedAt!.toIso8601String())}'
                          : '未保存',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: colors.textTertiary,
                  ),
                  tooltip: '删除草稿',
                  splashRadius: 18,
                ),
              Icon(Icons.chevron_right, size: 20, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
