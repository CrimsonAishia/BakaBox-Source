import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/auth/auth_bloc.dart';
import '../../../core/bloc/auth/auth_state.dart';
import '../../../core/bloc/map_contribution/map_contribution_bloc.dart';
import '../../../core/bloc/map_contribution/map_contribution_state.dart';
import '../../../core/widgets/map_contribution_dialog.dart';
import 'map_group_card.dart';
import 'pagination_bar.dart';

/// 我的贡献 Tab
class MapDatabaseMyTab extends StatelessWidget {
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  
  const MapDatabaseMyTab({
    super.key,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (!authState.isAuthenticated) {
          return _buildLoginPrompt(context);
        }

        return BlocBuilder<MapContributionBloc, MapContributionState>(
          builder: (context, state) {
            if (state.isLoadingMyMaps && state.myMapGroups.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (state.isMyMapsEmpty) {
              return _buildEmptyState(context);
            }

            final totalPages = (state.myMapsTotal / 6).ceil();

            return Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // 根据宽度计算列数
                          final crossAxisCount = _calculateCrossAxisCount(constraints.maxWidth);
                          
                          return GridView.builder(
                            key: PageStorageKey('map_database_my_grid_page_$currentPage'),
                            padding: const EdgeInsets.all(24),
                            physics: const AlwaysScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 3.0,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                            ),
                            itemCount: state.myMapGroups.length,
                            itemBuilder: (context, index) {
                              final group = state.myMapGroups[index];
                              // 安全地获取第一个 item 的 id，如果为空则使用 mapName
                              final itemId = group.items.isNotEmpty ? group.items.first.id : 'empty';
                              return MapGroupCard(
                                key: ValueKey('group_${group.mapInfo.mapName}_${itemId}_page_$currentPage'),
                                group: group,
                                showAuditStatus: true,
                                onTap: () {
                                  MapContributionDialog.show(
                                    context,
                                    mapName: group.mapInfo.mapName,
                                    mapLabel: group.mapInfo.mapLabel,
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    
                    // 分页器
                    PaginationBar(
                      currentPage: currentPage,
                      totalPages: totalPages,
                      onPageChanged: onPageChanged,
                      totalItems: state.myMapsTotal,
                      pageSize: 6,
                    ),
                  ],
                ),
                
                // Loading 覆盖层（切换分页时显示）
                if (state.isLoadingMyMaps && state.myMapGroups.isNotEmpty)
                  _buildLoadingOverlay(context),
              ],
            );
          },
        );
      },
    );
  }

  int _calculateCrossAxisCount(double width) {
    if (width > 1600) return 4;
    if (width > 1200) return 3;
    if (width > 800) return 2;
    return 1;
  }

  Widget _buildLoginPrompt(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.login,
            size: 80,
            color: isDark
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '请先登录',
            style: TextStyle(
              fontSize: 16,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.black.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '登录后可查看您的地图信息提交',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: isDark
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无贡献记录',
            style: TextStyle(
              fontSize: 16,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.black.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '快去为地图补充信息吧',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Positioned.fill(
      child: Container(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D3748) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                SizedBox(height: 12),
                Text(
                  '加载中...',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
