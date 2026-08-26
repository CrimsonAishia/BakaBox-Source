import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/map_subscription/map_subscription_bloc.dart';
import '../../../../core/models/map_subscription_models.dart';
import '../../server/server_detail_dialog.dart';
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
          Icon(Icons.list_alt_rounded, color: AppColors.indigo500, size: 20),
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
        ServerDetailDialog.showMapEdit(
          context,
          mapName: sub.mapName,
          mapLabel: sub.mapLabel,
          mapUrl: sub.mapBackground,
        );
      },
      onDelete: () => _showDeleteConfirmDialog(context, isDark, sub),
      editBeforeDelete: true,
      // 使用自定义 bottomActions 显示在第二行：CD徽章 + 自动加入设置按钮 + 范围设置按钮
      bottomActions: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MapCdBadge(
            mapName: sub.mapName,
            triggerOnHover: false,
            isCompact: true,
          ),
          const SizedBox(width: 8),
          _buildAutoJoinButton(context, isDark, sub),
          const SizedBox(width: 8),
          _buildScopeButtons(context, isDark, sub, categoryText, serverText),
        ],
      ),
    );
  }

  /// 构建自动加入按钮
  Widget _buildAutoJoinButton(
    BuildContext context,
    bool isDark,
    MapSubscription sub,
  ) {
    return _ActionButton(
      icon: sub.isAutoJoinEnabled
          ? Icons.flash_on_rounded
          : Icons.flash_off_rounded,
      label: sub.isAutoJoinEnabled
          ? '${sub.autoJoinCountdownSeconds}s'
          : '自动加入',
      baseColor: const Color(0xFF818CF8), // indigo400
      isActive: sub.isAutoJoinEnabled,
      onTap: () => _showAutoJoinDialog(context, isDark, sub),
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

    return _ActionButton(
      icon: Icons.tune_rounded,
      label: scopeDesc,
      baseColor: Colors.white,
      isActive: false, // 范围设置按钮作为普通按钮，不上色发光
      onTap: () => _showSubscriptionScopeDialog(context, isDark, sub),
    );
  }

  void _showAutoJoinDialog(
    BuildContext context,
    bool isDark,
    MapSubscription sub,
  ) {
    bool isEnabled = sub.isAutoJoinEnabled;
    int seconds = sub.autoJoinCountdownSeconds;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(
                Icons.flash_on_rounded,
                color: AppColors.indigo500,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '自动加入设置',
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
                SwitchListTile(
                  value: isEnabled,
                  onChanged: (v) {
                    setDialogState(() {
                      isEnabled = v;
                    });
                  },
                  title: Text(
                    '开启自动加入',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : AppColors.gray800,
                    ),
                  ),
                  subtitle: Text(
                    '当检测到地图时，自动触发倒计时并加入服务器',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : AppColors.gray400,
                    ),
                  ),
                  activeTrackColor: AppColors.indigo500.withValues(alpha: 0.5),
                  activeThumbColor: AppColors.indigo500,
                  contentPadding: EdgeInsets.zero,
                ),
                if (isEnabled) ...[
                  const SizedBox(height: 16),
                  Text(
                    '加入倒计时：$seconds 秒',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : AppColors.gray500,
                    ),
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      activeTrackColor: AppColors.indigo500,
                      inactiveTrackColor: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : AppColors.gray200,
                      thumbColor: AppColors.indigo500,
                    ),
                    child: Slider(
                      value: seconds.toDouble(),
                      min: 5,
                      max: 120,
                      divisions: 23, // 5 到 120, 步长 5
                      onChanged: (v) {
                        setDialogState(() {
                          seconds = v.round();
                        });
                      },
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
                foregroundColor: isDark ? Colors.white54 : AppColors.gray500,
              ),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<MapSubscriptionBloc>().add(
                  MapSubscriptionUpdateAutoJoin(
                    mapName: sub.mapName,
                    isEnabled: isEnabled,
                    countdownSeconds: seconds,
                  ),
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
              foregroundColor: isDark ? Colors.white54 : AppColors.gray500,
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
                        color: isDark ? Colors.white38 : AppColors.gray400,
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
                        color: isDark ? Colors.white54 : AppColors.gray500,
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
                            color: isDark ? Colors.white38 : AppColors.gray400,
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
                  foregroundColor: isDark ? Colors.white54 : AppColors.gray500,
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

/// 底部操作栏统一样式的按钮（带 Hover 和发光效果，与 CD 徽章对齐）
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color baseColor;
  final VoidCallback onTap;
  final bool isActive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.baseColor,
    required this.onTap,
    this.isActive = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hovered = _isHovered;
    final color = widget.isActive
        ? widget.baseColor
        : Colors.white.withValues(alpha: 0.5);
    final borderColor = widget.isActive
        ? widget.baseColor.withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.25);
    final hoverBorderColor = widget.isActive
        ? widget.baseColor
        : Colors.white.withValues(alpha: 0.5);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: hovered
                ? Colors.black.withValues(alpha: 0.55)
                : Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hovered ? hoverBorderColor : borderColor,
              width: hovered ? 2.0 : 1.5,
            ),
            boxShadow: [
              if (widget.isActive)
                BoxShadow(
                  color: hovered
                      ? widget.baseColor.withValues(alpha: 0.3)
                      : widget.baseColor.withValues(alpha: 0.15),
                  blurRadius: hovered ? 14 : 10,
                  spreadRadius: hovered ? 2 : 1,
                ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 16, color: color),
                  const SizedBox(width: 5),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                      letterSpacing: 0.5,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
