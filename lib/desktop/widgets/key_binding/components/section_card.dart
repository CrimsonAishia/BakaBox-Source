import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// 表单分区卡片
///
/// 用于发布配置和编辑配置视图中包裹每个分区（基本信息、分类选择、脚本编辑等）。
class SectionCard extends StatelessWidget {
  /// 卡片 key（用于滚动定位）
  final Key? cardKey;

  /// 分区标题左侧图标
  final IconData icon;

  /// 图标颜色（默认为 [AppColors.primary]）
  final Color iconColor;

  /// 分区标题文本
  final String title;

  /// 分区副标题/描述
  final String subtitle;

  /// 分区内容
  final Widget child;

  /// 标题右侧的额外 widget（如插入占位符按钮）
  final Widget? headerTrailing;

  /// 标题右侧的徽章列表
  final List<Widget>? titleBadges;

  const SectionCard({
    super.key,
    this.cardKey,
    required this.icon,
    this.iconColor = AppColors.primary,
    required this.title,
    required this.subtitle,
    required this.child,
    this.headerTrailing,
    this.titleBadges,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      key: cardKey,
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.slate700 : Colors.grey[100]!,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1a1a2e),
                            ),
                          ),
                          if (titleBadges != null) ...titleBadges!,
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (headerTrailing != null) headerTrailing!,
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}

/// 表单分区小标签
///
/// 用于在分区内部标注子字段名称（如 "配置描述"）。
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white54 : Colors.grey[600],
      ),
    );
  }
}
