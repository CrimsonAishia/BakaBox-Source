import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/activity_model.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/widgets/rich_text_viewer.dart';
import '../../../core/widgets/embeds/bilibili_embed_builder.dart';
import '../../../core/widgets/signed_network_image.dart';

class ActivityDetailDialog extends StatelessWidget {
  final ActivityModel activity;

  const ActivityDetailDialog({super.key, required this.activity});

  static Future<void> show(BuildContext context, ActivityModel activity) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation,
            child: ActivityDetailDialog(activity: activity),
          ),
        );
      },
    );
  }

  // 构建底部元数据栏
  Widget _buildTimeAndStatusRow(
    BuildContext context, {
    bool isOverlay = false,
  }) {
    final theme = Theme.of(context);

    final now = DateTime.now().millisecondsSinceEpoch;
    final isUpcoming = now < activity.startTime;
    final isEnded = activity.endTime != null && now > activity.endTime!;
    final isOngoing = !isUpcoming && !isEnded;

    final String statusText = isOngoing ? '进行中' : (isUpcoming ? '即将开始' : '已结束');
    final Color statusColor = isOngoing
        ? const Color(0xFF10B981) // Emerald (进行中)
        : (isUpcoming
              ? const Color(0xFFF59E0B)
              : const Color(0xFF9CA3AF)); // Amber (未开始) / Gray (已结束)

    final String timeStr = TimeUtils.formatActivityTime(
      activity.startTime,
      activity.endTime,
    );

    // 颜色适配
    final Color timeIconColor = isOverlay
        ? Colors.white.withValues(alpha: 0.6)
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    final Color timeTextColor = isOverlay
        ? Colors.white.withValues(alpha: 0.75)
        : theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 状态指示标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // 时间字符串
        Icon(Icons.schedule_rounded, color: timeIconColor, size: 13),
        const SizedBox(width: 4),
        Text(
          timeStr,
          style: TextStyle(
            color: timeTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.slate800 : Colors.white;
    final borderColor = isDark ? AppColors.slate700 : AppColors.gray200;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 860,
        height: 700,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 头部：关闭按钮
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.celebration_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '活动详情',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    splashRadius: 24,
                  ),
                ],
              ),
            ),

            // 内容区
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero 封面 (全宽，不留白)
                    if (activity.bannerUrl.isNotEmpty)
                      Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 200,
                            clipBehavior: Clip.antiAlias,
                            decoration: const BoxDecoration(),
                            child: SignedNetworkImage(
                              url: activity.bannerUrl,
                              fit: BoxFit.cover,
                              fallback: Container(
                                color: isDark
                                    ? AppColors.slate700
                                    : AppColors.sky100,
                                child: Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    size: 48,
                                    color: isDark
                                        ? AppColors.slate600
                                        : AppColors.sky200,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // 底部平滑渐变遮罩
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.85),
                                    Colors.black.withValues(alpha: 0.3),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.5, 0.8],
                                ),
                              ),
                            ),
                          ),
                          // 左上角角标
                          Positioned(
                            top: 16,
                            left: 16,
                            child: Row(
                              children: [
                                if (activity.isPinned)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFF43F5E),
                                          Color(0xFFE11D48),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFFE11D48,
                                          ).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.push_pin_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '置顶',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // 左下角标题与简介
                          Positioned(
                            bottom: 24,
                            left: 32,
                            right: 32,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildTimeAndStatusRow(
                                  context,
                                  isOverlay: true,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  activity.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                    letterSpacing: -0.5,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black54,
                                        offset: Offset(0, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                if (activity.description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    activity.description,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontSize: 15,
                                      height: 1.4,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black54,
                                          offset: Offset(0, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (activity.bannerUrl.isEmpty) ...[
                            // 当没有图片时，退化显示在正文顶部
                            Row(
                              children: [
                                if (activity.isPinned)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFF43F5E),
                                          Color(0xFFE11D48),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFFE11D48,
                                          ).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.push_pin_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '置顶',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (activity.isPinned)
                                  const SizedBox(width: 12),
                                _buildTimeAndStatusRow(
                                  context,
                                  isOverlay: false,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // 标题
                            Text(
                              activity.title,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                                letterSpacing: -0.5,
                              ),
                            ),

                            if (activity.description.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                activity.description,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),
                          ],

                          // 顶部分隔线 (如果上方没有图片，则这里作为分割正文的线；如果有图片，则不需要分隔线，因为文字就在图片上，这里直接开始正文会更好，所以如果有banner我们甚至可以隐藏线，不过留着也行)
                          if (activity.bannerUrl.isEmpty) ...[
                            Container(height: 1, color: borderColor),
                            const SizedBox(height: 32),
                          ],

                          // 富文本正文
                          if (activity.content.isNotEmpty)
                            RichTextViewer(
                              key: ValueKey('activity-rich-${activity.id}'),
                              content: activity.content,
                              embedBuilders: const [BilibiliEmbedBuilder()],
                              sliceForToc: false,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
