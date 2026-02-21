import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/map_subscription/map_subscription_bloc.dart';
import '../../../../core/models/map_subscription_models.dart';
import '../../../../core/widgets/map_contribution_dialog.dart';
import '../../map_subscription_card.dart';

/// 订阅管理视图
class SubscriptionView extends StatefulWidget {
  final bool isDark;
  final MapSubscriptionState state;

  const SubscriptionView({
    super.key,
    required this.isDark,
    required this.state,
  });

  @override
  State<SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends State<SubscriptionView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      context.read<MapSubscriptionBloc>().add(
            MapSubscriptionSearchMaps(query: query),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final state = widget.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        _buildHeader(isDark, state),
        const Divider(height: 1),
        // 搜索栏
        _buildSearchBar(isDark),
        // 内容区
        Expanded(
          child: state.searchResults.isNotEmpty ||
                  _searchController.text.isNotEmpty
              ? _buildSearchResults(isDark, state)
              : _buildSubscriptionList(isDark, state),
        ),
      ],
    );
  }

  /// 标题栏
  Widget _buildHeader(bool isDark, MapSubscriptionState state) {
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
          // 冷却时间设置
          _buildCooldownSetting(isDark, state),
        ],
      ),
    );
  }

  /// 冷却时间设置
  Widget _buildCooldownSetting(bool isDark, MapSubscriptionState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timer_outlined,
          size: 14,
          color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
        ),
        const SizedBox(width: 4),
        Text(
          '冷却',
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

  /// 搜索栏
  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
        ),
        decoration: InputDecoration(
          hintText: '搜索地图名称...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                  ),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                    });
                    context.read<MapSubscriptionBloc>().add(
                          const MapSubscriptionSearchMaps(query: ''),
                        );
                  },
                )
              : null,
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF3F4F6),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color(0xFF6366F1),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  /// 订阅列表
  Widget _buildSubscriptionList(bool isDark, MapSubscriptionState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6366F1),
        ),
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
              '搜索并添加你感兴趣的地图',
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
        return _buildSubscriptionTile(isDark, sub, state);
      },
    );
  }

  /// 订阅项
  Widget _buildSubscriptionTile(
    bool isDark,
    MapSubscription sub,
    MapSubscriptionState state,
  ) {
    // 分类范围文本
    final scopeText = sub.categoryNames.isEmpty
        ? '全部分类'
        : '${sub.categoryNames.length}个分类';

    return MapSubscriptionCard(
      displayName: sub.mapLabel.isNotEmpty ? sub.mapLabel : sub.mapName,
      mapName: sub.mapName,
      mapBackground: sub.mapBackground,
      // scopeText 用于分类范围按钮
      scopeText: scopeText,
      isSubscribed: true,
      onEdit: () {
        MapContributionDialog.show(
          context,
          mapName: sub.mapName,
          mapLabel: sub.mapLabel,
        );
      },
      onScopeTap: () => _showCategoryScopeDialog(
        mapName: sub.mapName,
        mapLabel: sub.mapLabel,
        mapBackground: sub.mapBackground,
        availableCategories: state.availableCategories,
        currentCategories: sub.categoryNames,
        isEdit: true,
      ),
      onDelete: () => _showDeleteConfirmDialog(sub),
    );
  }

  /// 搜索结果
  Widget _buildSearchResults(bool isDark, MapSubscriptionState state) {
    if (state.isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6366F1),
        ),
      );
    }

    if (state.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
            ),
            const SizedBox(height: 12),
            Text(
              '未找到匹配的地图',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: state.searchResults.length,
      itemBuilder: (context, index) {
        final result = state.searchResults[index];
        return _buildSearchResultTile(isDark, result, state);
      },
    );
  }

  /// 搜索结果项
  Widget _buildSearchResultTile(
    bool isDark,
    MapSearchResult result,
    MapSubscriptionState state,
  ) {
    final hasBackground = result.mapBackground != null;
    return MapSubscriptionCard(
      displayName: result.mapLabel.isNotEmpty ? result.mapLabel : result.mapName,
      mapName: result.mapName,
      mapBackground: result.mapBackground,
      isSubscribed: result.isSubscribed,
      isCompact: true,
      onTap: result.isSubscribed
          ? null
          : () => _showCategoryScopeDialog(
                mapName: result.mapName,
                mapLabel: result.mapLabel,
                mapBackground: result.mapBackground,
                availableCategories: state.availableCategories,
              ),
      onEdit: result.isSubscribed
          ? () {
              MapContributionDialog.show(
                context,
                mapName: result.mapName,
                mapLabel: result.mapLabel,
              );
            }
          : null,
      trailing: result.isSubscribed
          ? _buildSubscribedLabel(hasBackground)
          : _buildSubscribeButton(
              hasBackground: hasBackground,
              onTap: () => _showCategoryScopeDialog(
                mapName: result.mapName,
                mapLabel: result.mapLabel,
                mapBackground: result.mapBackground,
                availableCategories: state.availableCategories,
              ),
            ),
    );
  }

  /// 已订阅标签
  Widget _buildSubscribedLabel(bool hasBackground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: hasBackground
            ? const Color(0xFF10B981).withValues(alpha: 0.85)
            : const Color(0xFF10B981).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_rounded,
            size: 12,
            color: hasBackground ? Colors.white : const Color(0xFF10B981),
          ),
          const SizedBox(width: 4),
          Text(
            '已订阅',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: hasBackground ? Colors.white : const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  /// 订阅按钮
  Widget _buildSubscribeButton({
    required bool hasBackground,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: hasBackground
                ? const Color(0xFF6366F1).withValues(alpha: 0.9)
                : const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(6),
            boxShadow: hasBackground
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.add_rounded, size: 14, color: Colors.white),
              SizedBox(width: 4),
              Text(
                '订阅',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 删除确认对话框
  void _showDeleteConfirmDialog(MapSubscription sub) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

  /// 分类范围选择对话框
  void _showCategoryScopeDialog({
    required String mapName,
    required String mapLabel,
    String? mapBackground,
    required List<String> availableCategories,
    List<String>? currentCategories,
    bool isEdit = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedCategories = <String>{...?currentCategories};
    bool isAll = currentCategories?.isEmpty ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit_rounded : Icons.add_circle_rounded,
                color: const Color(0xFF6366F1),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEdit ? '编辑订阅范围' : '选择订阅范围',
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
                // 地图名称
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.map_rounded,
                        size: 18,
                        color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mapLabel.isNotEmpty ? mapLabel : mapName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 全部分类选项
                CheckboxListTile(
                  value: isAll,
                  onChanged: (v) {
                    setDialogState(() {
                      isAll = v ?? false;
                      if (isAll) {
                        selectedCategories.clear();
                      }
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
                // 分类列表
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
                  if (widget.state.isLoadingCategories)
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
                              color: isDark
                                  ? Colors.white38
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '正在加载分类...',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white38
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (availableCategories.isEmpty)
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
                          children: availableCategories.map((cat) {
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
                              selectedColor:
                                  const Color(0xFF6366F1).withValues(alpha: 0.2),
                              checkmarkColor: const Color(0xFF6366F1),
                              labelStyle: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? const Color(0xFF6366F1)
                                    : (isDark
                                        ? Colors.white70
                                        : const Color(0xFF374151)),
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
                if (isEdit) {
                  context.read<MapSubscriptionBloc>().add(
                        MapSubscriptionUpdateScope(
                          mapName: mapName,
                          categoryNames: cats,
                        ),
                      );
                } else {
                  context.read<MapSubscriptionBloc>().add(
                        MapSubscriptionAdd(
                          mapName: mapName,
                          mapLabel: mapLabel,
                          mapBackground: mapBackground,
                          categoryNames: cats,
                        ),
                      );
                  // 刷新搜索结果
                  if (_searchController.text.isNotEmpty) {
                    context.read<MapSubscriptionBloc>().add(
                          MapSubscriptionSearchMaps(
                            query: _searchController.text,
                          ),
                        );
                  }
                }
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(isEdit ? '保存' : '确认订阅'),
            ),
          ],
        ),
      ),
    );
  }
}
