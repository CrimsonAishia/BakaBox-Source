import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/core.dart';

/// 服务器分类在线状态面板
class ServerCategoriesPanel extends StatelessWidget {
  final bool isDark;
  final VoidCallback? onNavigateToServers;

  const ServerCategoriesPanel({
    super.key,
    required this.isDark,
    this.onNavigateToServers,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        final officialCategories = state.serverCategories
            .where((cat) => !cat.isCustom)
            .toList();

        final isLoading =
            !state.hasEverLoadedOnlineCounts || state.isLoadingOnlineCounts;

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
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Row(
                    children: [
                      Text(
                        '服务器在线状态',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.slate800,
                        ),
                      ),
                      const Spacer(),
                      if (isLoading)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : AppColors.slate400,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (officialCategories.isEmpty && !isLoading)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          '暂无服务器数据',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : AppColors.slate400,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: officialCategories.length,
                        itemBuilder: (context, index) {
                          final category = officialCategories[index];
                          final categoryKey = category.modelName ?? '';
                          final hasOnlineCountData = state.categoryOnlineCounts
                              .containsKey(categoryKey);
                          final onlineCount =
                              state.categoryOnlineCounts[categoryKey] ?? 0;
                          final serverCount = category.serverList.length;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CategoryItem(
                              categoryName:
                                  category.modelName ??
                                  category.category ??
                                  '未知分类',
                              onlineCount: onlineCount,
                              serverCount: serverCount,
                              isDark: isDark,
                              hasOnlineCountData: hasOnlineCountData,
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: onNavigateToServers,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('浏览全部服务器'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.blue500,
                      ),
                    ),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 500.ms, delay: 500.ms)
            .slideY(
              begin: 0.2,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }
}

/// 单个分类项 - 卡片样式
class _CategoryItem extends StatelessWidget {
  final String categoryName;
  final int onlineCount;
  final int serverCount;
  final bool isDark;

  /// 是否已经获取到该分类的在线人数。
  /// false 时（如弱网模式下从未拉取）显示占位符 "—" 而不是 "0"。
  final bool hasOnlineCountData;

  const _CategoryItem({
    required this.categoryName,
    required this.onlineCount,
    required this.serverCount,
    required this.isDark,
    this.hasOnlineCountData = true,
  });

  @override
  Widget build(BuildContext context) {
    // 根据在线人数显示不同的颜色
    Color getStatusColor() {
      if (!hasOnlineCountData || onlineCount == 0) {
        return isDark
            ? Colors.white.withValues(alpha: 0.3)
            : AppColors.slate400;
      } else if (onlineCount < 20) {
        return AppColors.emerald500; // 绿色：人少
      } else if (onlineCount < 50) {
        return AppColors.blue500; // 蓝色：中等
      } else if (onlineCount < 100) {
        return AppColors.amber500; // 橙色：较多
      } else {
        return AppColors.red500; // 红色：很多
      }
    }

    final statusColor = getStatusColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          // 状态指示点
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 分类名称
          Expanded(
            child: Text(
              categoryName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : AppColors.slate800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // 在线人数标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  hasOnlineCountData ? '$onlineCount' : '—',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 服务器数量
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$serverCount服',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.6)
                    : AppColors.slate500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
