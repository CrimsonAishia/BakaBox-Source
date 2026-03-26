import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/models/map_contribution_models.dart';
import 'contribution_item.dart';
import 'map_history_tab.dart';

/// 地图详情对话框
///
/// 显示地图的详细贡献列表和运行历史
class MapDetailDialog extends StatefulWidget {
  final MapInfo mapInfo;
  final List<MapContribution>? contributions;
  final bool isMyContribution;

  const MapDetailDialog({
    super.key,
    required this.mapInfo,
    this.contributions,
    this.isMyContribution = false,
  });

  /// 从 MapContributionGroup 创建对话框（用于"我的贡献" Tab）
  factory MapDetailDialog.fromGroup({
    required MapContributionGroup group,
    bool isMyContribution = false,
  }) {
    return MapDetailDialog(
      mapInfo: group.mapInfo,
      contributions: group.items,
      isMyContribution: isMyContribution,
    );
  }

  @override
  State<MapDetailDialog> createState() => _MapDetailDialogState();
}

class _MapDetailDialogState extends State<MapDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final items = widget.contributions ?? [];

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 700,
        height: 600,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // 头部
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.mapInfo.mapLabel,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.mapInfo.mapName,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.black.withValues(alpha: 0.5),
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildStatChip(
                              Icons.article_outlined,
                              '${widget.mapInfo.contribCount} 贡献',
                              const Color(0xFF6366F1),
                              isDark,
                            ),
                            const SizedBox(width: 12),
                            _buildStatChip(
                              Icons.label_outline,
                              '${widget.mapInfo.nameCount} 名称',
                              const Color(0xFF10B981),
                              isDark,
                            ),
                            const SizedBox(width: 12),
                            _buildStatChip(
                              Icons.image_outlined,
                              '${widget.mapInfo.backgroundCount} 背景',
                              const Color(0xFFF59E0B),
                              isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black.withValues(alpha: 0.7),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),

            // Tab 栏
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: isDark ? Colors.white : const Color(0xFF111827),
                unselectedLabelColor: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.5),
                indicatorColor: const Color(0xFF0080FF),
                indicatorWeight: 3,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.article_outlined, size: 18),
                        const SizedBox(width: 8),
                        const Text('贡献'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.history, size: 18),
                        const SizedBox(width: 8),
                        const Text('运行历史'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab 内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 贡献列表
                  items.isEmpty
                      ? _buildNoContributions(isDark)
                      : ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final contribution = items[index];
                            return ContributionItem(
                              contribution: contribution,
                              isMyContribution: widget.isMyContribution,
                            );
                          },
                        ),
                  // 运行历史
                  MapHistoryTab(mapName: widget.mapInfo.mapName),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoContributions(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无贡献',
            style: TextStyle(
              fontSize: 15,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
