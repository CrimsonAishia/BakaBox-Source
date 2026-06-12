import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../core/models/update_log_models.dart';
import '../../core/utils/formatters.dart';
import '../../core/constants/app_colors.dart';

/// 更新日志时间线项组件
/// 以时间线形式展示日志项，支持选中状态高亮
///
class TimelineLogItem extends StatelessWidget {
  final SteamWorkChangeLog log;
  final int index;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final bool isLatest;
  final VoidCallback? onTap;

  const TimelineLogItem({
    super.key,
    required this.log,
    required this.index,
    this.isSelected = false,
    this.isFirst = false,
    this.isLast = false,
    this.isLatest = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间线指示器
            _buildTimelineIndicator(context, primaryColor),
            const SizedBox(width: 16),
            // 日志内容卡片
            Expanded(child: _buildLogCard(context, primaryColor)),
          ],
        ),
      ),
    );
  }

  /// 构建时间线指示器
  Widget _buildTimelineIndicator(BuildContext context, Color primaryColor) {
    // 最新日志使用绿色，其他使用主题色
    final indicatorColor = isLatest ? AppColors.emerald500 : primaryColor;

    return SizedBox(
      width: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 上方连接线
          if (!isFirst)
            Container(
              width: 2,
              height: 8,
              color: isSelected
                  ? indicatorColor
                  : Theme.of(context).dividerColor.withValues(alpha: 0.3),
            ),
          // 圆点指示器
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isSelected || isLatest)
                  ? indicatorColor
                  : Colors.transparent,
              border: Border.all(
                color: (isSelected || isLatest)
                    ? indicatorColor
                    : Theme.of(context).dividerColor.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: (isSelected || isLatest)
                  ? [
                      BoxShadow(
                        color: indicatorColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          // 下方连接线 - 使用固定高度而不是 Expanded
          if (!isLast)
            Container(
              width: 2,
              height: 60,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            ),
        ],
      ),
    );
  }

  /// 构建日志内容卡片
  Widget _buildLogCard(BuildContext context, Color primaryColor) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected
            ? primaryColor.withValues(alpha: 0.1)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? primaryColor
              : theme.dividerColor.withValues(alpha: 0.1),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          _buildTitleRow(context, primaryColor),
          if (log.content.isNotEmpty) ...[
            const SizedBox(height: 12),
            // 内容预览
            _buildContentPreview(context),
          ],
        ],
      ),
    );
  }

  /// 构建标题行
  Widget _buildTitleRow(BuildContext context, Color primaryColor) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // 版本标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.2)
                : primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(MdiIcons.tagOutline, size: 14, color: primaryColor),
              const SizedBox(width: 4),
              Text(
                '更新 ${Formatters.formatDate(log.updateTime)}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // 日期
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(MdiIcons.calendarClock, size: 14, color: theme.disabledColor),
            const SizedBox(width: 4),
            Text(
              _formatDate(log.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.disabledColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建内容预览
  Widget _buildContentPreview(BuildContext context) {
    final theme = Theme.of(context);
    final previewText = log.content.length > 150
        ? '${log.content.substring(0, 150)}...'
        : log.content;

    return Text(
      previewText,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
        height: 1.5,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 格式化日期显示
  String _formatDate(String dateStr) {
    return Formatters.formatDate(dateStr);
  }
}
