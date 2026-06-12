import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/map_subscription/map_subscription_bloc.dart';
import '../../../../core/models/map_subscription_models.dart';
import '../../../../core/widgets/map_contribution_dialog.dart';
import '../../common_scroll_indicator.dart';
import '../../map_subscription_card.dart';
import '../../cd_badge.dart';
import 'subscription_scope_dialog.dart';
import '../../../../core/constants/app_colors.dart';

/// 订阅管理视图（已订阅列表）
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
  final ScrollController _scrollController = ScrollController();
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  bool get isDark => widget.isDark;
  MapSubscriptionState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicators);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateScrollIndicators(),
    );
  }

  @override
  void didUpdateWidget(SubscriptionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.subscriptions.length !=
        widget.state.subscriptions.length) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _updateScrollIndicators(),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollIndicators() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canUp = position.pixels > 0;
    final canDown = position.pixels < position.maxScrollExtent;
    if (canUp != _canScrollUp || canDown != _canScrollDown) {
      setState(() {
        _canScrollUp = canUp;
        _canScrollDown = canDown;
      });
    }
  }

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

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    MapSubscriptionState state,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Icon(
            Icons.list_alt_rounded,
            color: AppColors.indigo500,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '已订阅地图',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.gray800,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.indigo500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${state.subscriptions.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.indigo500,
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

  Widget _buildGlobalScopeSetting(
    BuildContext context,
    bool isDark,
    MapSubscriptionState state,
  ) {
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
              : AppColors.gray100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.gray200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 14,
              color: isDark ? Colors.white54 : AppColors.gray500,
            ),
            const SizedBox(width: 4),
            Text(
              scopeText,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : AppColors.gray500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: isDark ? Colors.white38 : AppColors.gray400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCooldownSetting(
    BuildContext context,
    bool isDark,
    MapSubscriptionState state,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.refresh_rounded,
          size: 14,
          color: isDark ? Colors.white38 : AppColors.gray400,
        ),
        const SizedBox(width: 4),
        Text(
          '刷新频率',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : AppColors.gray400,
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
              activeTrackColor: AppColors.indigo500,
              inactiveTrackColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.gray200,
              thumbColor: AppColors.indigo500,
              overlayColor: AppColors.indigo500.withValues(alpha: 0.1),
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
            color: AppColors.indigo500,
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionList(
    BuildContext context,
    bool isDark,
    MapSubscriptionState state,
  ) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.indigo500),
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
              color: isDark ? Colors.white24 : AppColors.gray300,
            ),
            const SizedBox(height: 12),
            Text(
              '暂无订阅',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : AppColors.gray400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '点击左侧"添加"搜索并订阅地图',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white24 : AppColors.gray300,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: state.subscriptions.length,
          itemBuilder: (context, index) {
            final sub = state.subscriptions[index];
            return _buildSubscriptionTile(context, isDark, sub);
          },
        ),
        if (_canScrollUp)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CommonScrollIndicator(isTop: true),
          ),
        if (_canScrollDown)
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CommonScrollIndicator(isTop: false),
          ),
      ],
    );
  }

  Widget _buildSubscriptionTile(
    BuildContext context,
    bool isDark,
    MapSubscription sub,
  ) {
    // 计算范围文本
    final categoryText = sub.isAllCategories
        ? '继承全局'
        : '${sub.categoryNames.length}个分类';
    final serverText = sub.isAllServers
        ? '继承全局'
        : '${sub.serverAddresses.length}个服务器';

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
      // 使用自定义 trailing 显示CD徽章 + 范围设置按钮
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MapCdBadge(mapName: sub.mapName, triggerOnHover: false),
          const SizedBox(width: 8),
          _buildScopeButtons(context, isDark, sub, categoryText, serverText),
        ],
      ),
    );
  }

  /// 构建单个范围设置按钮（点击弹出左右分栏弹窗）
  Widget _buildScopeButtons(
    BuildContext context,
    bool isDark,
    MapSubscription sub,
    String categoryText,
    String serverText,
  ) {
    // 计算当前范围描述
    String scopeDesc;
    if (sub.isAllCategories && sub.isAllServers) {
      scopeDesc = '继承全局';
    } else {
      final parts = <String>[];
      if (!sub.isAllCategories) {
        parts.add('${sub.categoryNames.length}分类');
      }
      if (!sub.isAllServers) {
        parts.add('${sub.serverAddresses.length}服');
      }
      scopeDesc = parts.join(' · ');
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showSubscriptionScopeDialog(context, isDark, sub),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.gray200,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : AppColors.gray300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 14,
                color: isDark ? Colors.white70 : AppColors.gray500,
              ),
              const SizedBox(width: 6),
              Text(
                scopeDesc,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : AppColors.gray500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    bool isDark,
    MapSubscription sub,
  ) {
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
            color: isDark ? Colors.white : AppColors.gray800,
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
              foregroundColor: isDark
                  ? Colors.white54
                  : AppColors.gray500,
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
              backgroundColor: AppColors.red500,
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

  void _showGlobalCategoryScopeDialog(
    BuildContext context,
    bool isDark,
    MapSubscriptionState state,
  ) {
    context.read<MapSubscriptionBloc>().add(
      const MapSubscriptionLoadCategories(),
    );

    final selectedCategories = <String>{...state.globalCategories};
    bool isAll = state.globalCategories.isEmpty;

    showDialog(
      context: context,
      builder: (ctx) => BlocBuilder<MapSubscriptionBloc, MapSubscriptionState>(
        builder: (blocContext, currentState) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.category_rounded,
                  color: AppColors.indigo500,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '全局监控范围',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.gray800,
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
                      color: isDark ? Colors.white54 : AppColors.gray500,
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
                        color: isDark ? Colors.white : AppColors.gray800,
                      ),
                    ),
                    subtitle: Text(
                      '监控所有服务器分类',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white38
                            : AppColors.gray400,
                      ),
                    ),
                    activeColor: AppColors.indigo500,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  if (!isAll) ...[
                    const SizedBox(height: 8),
                    Text(
                      '选择特定分类：',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white54
                            : AppColors.gray500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (currentState.isLoadingCategories)
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
                                    : AppColors.gray400,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '正在加载分类...',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white38
                                    : AppColors.gray400,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (currentState.availableCategories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '暂无可用分类',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white38
                                : AppColors.gray400,
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
                            children: currentState.availableCategories.map((
                              cat,
                            ) {
                              final isSelected = selectedCategories.contains(
                                cat,
                              );
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
                                selectedColor: const Color(
                                  0xFF6366F1,
                                ).withValues(alpha: 0.2),
                                checkmarkColor: AppColors.indigo500,
                                labelStyle: TextStyle(
                                  fontSize: 13,
                                  color: isSelected
                                      ? AppColors.indigo500
                                      : (isDark
                                            ? Colors.white70
                                            : AppColors.gray700),
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
                  foregroundColor: isDark
                      ? Colors.white54
                      : AppColors.gray500,
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
                  backgroundColor: AppColors.indigo500,
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
      ),
    );
  }

  /// 显示监控范围设置对话框（左右分栏：左侧分类，右侧服务器）
  void _showSubscriptionScopeDialog(
    BuildContext context,
    bool isDark,
    MapSubscription sub,
  ) {
    SubscriptionScopeDialog.show(context, subscription: sub);
  }
}
