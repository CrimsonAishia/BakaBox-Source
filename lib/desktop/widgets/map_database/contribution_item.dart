import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/map_contribution_models.dart';
import '../../../core/bloc/map_contribution/map_contribution_bloc.dart';
import '../../../core/bloc/map_contribution/map_contribution_event.dart';
import '../../../core/services/image_url_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/disk_cached_image.dart';
import '../../../core/constants/app_colors.dart';

/// 贡献项组件
///
/// 显示单个贡献的详细信息，包括内容、投票、审核状态等
class ContributionItem extends StatelessWidget {
  final MapContribution contribution;
  final bool isMyContribution;

  const ContributionItem({
    super.key,
    required this.contribution,
    this.isMyContribution = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 主要内容区域
          _buildMainContent(context, isDark),

          const SizedBox(height: 14),

          // 次要信息区域（元数据）
          _buildMetadata(context, isDark),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, bool isDark) {
    if (contribution.type == ContributionType.name) {
      // 名称贡献：大字体显示
      return Text(
        contribution.content,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
          height: 1.3,
        ),
      );
    } else {
      // 背景图片贡献：大图显示
      final imageRef = contribution.backgroundImageRef ?? '';
      return FutureBuilder<String>(
        future: ImageUrlService.instance.getSignedUrl(imageRef),
        builder: (context, snapshot) {
          final imageUrl = snapshot.data ?? imageRef;
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: DiskCachedImage(
              imageUrl: imageUrl,
              width: double.infinity,
              height: 140,
              fit: BoxFit.cover,
              placeholder: Container(
                height: 140,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: Container(
                height: 140,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.2),
                ),
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildMetadata(BuildContext context, bool isDark) {
    return Row(
      children: [
        // 类型和状态标签
        _buildTypeTag(isDark),
        if (contribution.auditStatus != AuditStatus.approved) ...[
          const SizedBox(width: 6),
          _buildStatusTag(isDark),
        ],

        const Spacer(),

        // 投票按钮
        _buildVoteButtons(context, isDark),

        const SizedBox(width: 12),

        // 时间和贡献者
        _buildContributorInfo(isDark),
      ],
    );
  }

  Widget _buildTypeTag(bool isDark) {
    final color = contribution.type == ContributionType.name
        ? AppColors.emerald500
        : AppColors.amber500;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        contribution.type.label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusTag(bool isDark) {
    final color = _getAuditStatusColor(contribution.auditStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        contribution.auditStatus.label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildContributorInfo(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 时间
        Text(
          Formatters.formatDate(contribution.createdAt.toIso8601String()),
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.35),
          ),
        ),

        // 贡献者
        if (contribution.contributor != null) ...[
          const SizedBox(width: 8),
          Text(
            '·',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(width: 8),
          if (contribution.contributor!.avatar != null)
            ClipOval(
              child: DiskCachedImage(
                imageUrl: contribution.contributor!.avatar!,
                width: 18,
                height: 18,
                fit: BoxFit.cover,
                errorWidget: Container(
                  width: 18,
                  height: 18,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, size: 12),
                ),
              ),
            ),
          const SizedBox(width: 6),
          Text(
            contribution.contributor!.username,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVoteButtons(BuildContext context, bool isDark) {
    return Row(
      children: [
        // 赞成票
        _buildVoteButton(
          context,
          isDark,
          Icons.thumb_up_outlined,
          Icons.thumb_up,
          contribution.upCount,
          VoteType.up,
          contribution.voteType == VoteType.up,
          AppColors.emerald500,
        ),
        const SizedBox(width: 12),

        // 反对票
        _buildVoteButton(
          context,
          isDark,
          Icons.thumb_down_outlined,
          Icons.thumb_down,
          contribution.downCount,
          VoteType.down,
          contribution.voteType == VoteType.down,
          AppColors.red500,
        ),
      ],
    );
  }

  Widget _buildVoteButton(
    BuildContext context,
    bool isDark,
    IconData icon,
    IconData activeIcon,
    int count,
    VoteType voteType,
    bool isActive,
    Color activeColor,
  ) {
    final isDisabled =
        contribution.isSystem ||
        contribution.auditStatus != AuditStatus.approved;

    return InkWell(
      onTap: isDisabled
          ? null
          : () {
              context.read<MapContributionBloc>().add(
                ToggleVote(contribution.id, voteType),
              );
            },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.12)
              : isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(6),
          border: isActive
              ? Border.all(color: activeColor.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 15,
              color: isActive
                  ? activeColor
                  : isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 6),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? activeColor
                    : isDark
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAuditStatusColor(AuditStatus status) {
    return switch (status) {
      AuditStatus.pending => AppColors.amber500,
      AuditStatus.approved => AppColors.emerald500,
      AuditStatus.rejected => AppColors.red500,
    };
  }
}
