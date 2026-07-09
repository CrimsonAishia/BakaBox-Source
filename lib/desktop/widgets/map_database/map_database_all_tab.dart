import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/map_contribution/map_contribution_bloc.dart';
import '../../../core/bloc/map_contribution/map_contribution_state.dart';
import '../../../core/models/map_contribution_models.dart';
import '../server/server_detail_dialog.dart';
import 'map_group_card.dart';
import 'pagination_bar.dart';

/// 全部地图 Tab
class MapDatabaseAllTab extends StatelessWidget {
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  const MapDatabaseAllTab({
    super.key,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapContributionBloc, MapContributionState>(
      builder: (context, state) {
        if (state.isLoadingAllMaps && state.allMaps.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.isAllMapsEmpty) {
          return _buildEmptyState(context);
        }

        final totalPages = (state.allMapsTotal / 6).ceil();

        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GridView.builder(
                        key: PageStorageKey(
                          'map_database_all_grid_page_$currentPage',
                        ),
                        padding: const EdgeInsets.all(6),
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate: MapGroupCard.getGridDelegate(
                          constraints.maxWidth,
                        ),
                        itemCount: state.allMaps.length,
                        itemBuilder: (context, index) {
                          final mapInfo = state.allMaps[index];
                          // 将 MapInfo 转换为 MapContributionGroup
                          final group = MapContributionGroup(
                            mapInfo: mapInfo,
                            items: const [],
                          );
                          return MapGroupCard(
                            key: ValueKey(
                              'map_${mapInfo.mapName}_page_$currentPage',
                            ),
                            group: group,
                            onTap: () {
                              ServerDetailDialog.showMapEdit(
                                context,
                                mapName: mapInfo.mapName,
                                mapLabel: mapInfo.mapLabel,
                                mapUrl: mapInfo.mapBackground,
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
                  totalItems: state.allMapsTotal,
                  pageSize: 6,
                ),
              ],
            ),

            // Loading 覆盖层（切换分页时显示）
            if (state.isLoadingAllMaps && state.allMaps.isNotEmpty)
              _buildLoadingOverlay(context),
          ],
        );
      },
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
                Text('加载中...', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
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
            Icons.map_outlined,
            size: 80,
            color: isDark
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无地图数据',
            style: TextStyle(
              fontSize: 16,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
