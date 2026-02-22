import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/map_subscription/map_subscription_bloc.dart';
import '../../../../core/models/map_subscription_models.dart';
import '../../../../core/widgets/map_contribution_dialog.dart';
import '../../map_subscription_card.dart';

/// 订阅管理视图（已订阅列表）
class SubscriptionView extends StatelessWidget {
  final bool isDark;
  final MapSubscriptionState state;

  const SubscriptionView({
    super.key,
    required this.isDark,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, isDark, state),
        const Divider(height: 1),
        Expanded(child: _buildSubscriptionList(context, isDark, state)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, MapSubscriptionState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Icon(
            Icons.list_alt_rounded,
            color: const Color(0xFF6366F1),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '已订阅地图',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${state.subscriptions.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6366F1),
              ),
            ),
          ),
          const Spacer(),
          _buildGlobalScopeSetting(context, isDark, state),
          const SizedBox(width: 16),
          _buildCooldownSetting(context, isDark, state),
        ],
      ),
    );
  }

  Widget _buildGlobalScopeSetting(BuildContext context, bool isDark, MapSubscriptionState state) {
    final scopeText = state.globalCategories.isEmpty
        ? '全部分类'
        : '${state.globalCategories.length}个分类';

    return InkWell(
      onTap: () => _showGlobalCategoryScopeDialog(context, isDark, state),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 14,
              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 4),
            Text(
              scopeText,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCooldownSetting(BuildContext context, bool isDark, MapSubscriptionState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.refresh_rounded,
          size: 14,
          color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
        ),
        const SizedBox(width: 4),
        Text(
          '刷新频率',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 100,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: const Color(0xFF6366F1),
              inactiveTrackColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFE5E7EB),
              thumbColor: const Color(0xFF6366F1),
              overlayColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
            ),
            child: Slider(
              value: state.cooldownSeconds.toDouble(),
              min: 10,
              max: 60,
              divisions: 10,
              onChanged: (v) => context.read<MapSubscriptionBloc>().add(
                    MapSubscriptionSetCooldown(seconds: v.round()),
                  ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${state.cooldownSeconds}s',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6366F1),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionList(BuildContext context, bool isDark, MapSubscriptionState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
      );
    }

    if (state.subscriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_border_rounded,
              size: 48,
              color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
            ),
            const SizedBox(height: 12),
            Text(
              '暂无订阅',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '点击左侧"添加"搜索并订阅地图',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: state.subscriptions.length,
      itemBuilder: (context, index) {
        final sub = state.subscriptions[index];
        return _buildSubscriptionTile(context, isDark, sub);
      },
    );
  }

  Widget _buildSubscriptionTile(BuildContext context, bool isDark, MapSubscription sub) {
    return MapSubscriptionCard(
      displayName: sub.mapLabel.isNotEmpty ? sub.mapLabel : sub.mapName,
      mapName: sub.mapName,
      mapBackground: sub.mapBackground,
      isSubscribed: true,
      onEdit: () {
        MapContributionDialog.show(
          context,
          mapName: sub.mapName,
          mapLabel: sub.mapLabel,
        );
      },
      onDelete: () => _showDeleteConfirmDialog(context, isDark, sub),
      editBeforeDelete: true,
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, bool isDark, MapSubscription sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          '取消订阅',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        content: Text(
          '确定要取消订阅「${sub.mapLabel.isNotEmpty ? sub.mapLabel : sub.mapName}」吗？',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white54 : const Color(0xFF6B7280),
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<MapSubscriptionBloc>().add(
                    MapSubscriptionRemove(mapName: sub.mapName),
                  );
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
  }

  void _showGlobalCategoryScopeDialog(BuildContext context, bool isDark, MapSubscriptionState state) {
    context.read<MapSubscriptionBloc>().add(const MapSubscriptionLoadCategories());

    final selectedCategories = <String>{...state.globalCategories};
    bool isAll = state.globalCategories.isEmpty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(
                Icons.category_rounded,
                color: const Color(0xFF6366F1),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '全局监控范围',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '设置所有订阅地图的监控范围',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: isAll,
                  onChanged: (v) {
                    setDialogState(() {
                      isAll = v ?? false;
                      if (isAll) selectedCategories.clear();
                    });
                  },
                  title: Text(
                    '全部分类',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  subtitle: Text(
                    '监控所有服务器分类',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                    ),
                  ),
                  activeColor: const Color(0xFF6366F1),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                if (!isAll) ...[
                  const SizedBox(height: 8),
                  Text(
                    '选择特定分类：',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (state.isLoadingCategories)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '正在加载分类...',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (state.availableCategories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '暂无可用分类',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: state.availableCategories.map((cat) {
                            final isSelected = selectedCategories.contains(cat);
                            return FilterChip(
                              label: Text(cat),
                              selected: isSelected,
                              onSelected: (v) {
                                setDialogState(() {
                                  if (v) {
                                    selectedCategories.add(cat);
                                  } else {
                                    selectedCategories.remove(cat);
                                  }
                                });
                              },
                              selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                              checkmarkColor: const Color(0xFF6366F1),
                              labelStyle: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? const Color(0xFF6366F1)
                                    : (isDark ? Colors.white70 : const Color(0xFF374151)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white54 : const Color(0xFF6B7280),
              ),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final cats = isAll ? <String>[] : selectedCategories.toList();
                context.read<MapSubscriptionBloc>().add(
                      MapSubscriptionUpdateScope(categoryNames: cats),
                    );
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
