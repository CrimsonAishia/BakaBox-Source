import 'package:flutter/material.dart';

import '../../../../core/bloc/guide_mine/guide_mine_event.dart';
import '../../../../core/bloc/guide_mine/guide_mine_state.dart';
import '../../../../core/models/guide_models.dart';
import '../community_guide/community_guide_theme.dart';

const _tabs = MineTab.values;

/// 「我的中心」工具栏：Tab 胶囊组 + 新建攻略按钮
class GuideMineToolbar extends StatelessWidget {
  final GuideMineState state;
  final int selectedTabIndex;
  final ValueChanged<int> onSelectTab;
  final GlobalKey publishedPillKey;
  final VoidCallback onOpenPublishedFilter;
  final Map<MineTab, int> tabCounts;
  final VoidCallback? onCreateGuide;

  const GuideMineToolbar({
    super.key,
    required this.state,
    required this.selectedTabIndex,
    required this.onSelectTab,
    required this.publishedPillKey,
    required this.onOpenPublishedFilter,
    required this.tabCounts,
    this.onCreateGuide,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final tab = _tabs[i];
                  final selected = selectedTabIndex == i;
                  final count = selected ? state.total : (tabCounts[tab] ?? 0);
                  final isLast = i == _tabs.length - 1;

                  if (tab == MineTab.published) {
                    return Padding(
                      padding: EdgeInsets.only(right: isLast ? 0 : 8),
                      child: _PublishedTabPill(
                        anchorKey: publishedPillKey,
                        label: _publishedTabLabel(state, selected),
                        count: count > 0 ? count : null,
                        active: selected,
                        onTap: () {
                          if (!selected) {
                            onSelectTab(i);
                          } else {
                            onOpenPublishedFilter();
                          }
                        },
                      ),
                    );
                  }
                  return Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : 8),
                    child: _TabPill(
                      label: tab.label,
                      count: count > 0 ? count : null,
                      active: selected,
                      onTap: () => onSelectTab(i),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: onCreateGuide,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新建攻略'),
            ),
          ),
        ],
      ),
    );
  }

  /// 根据当前 state 返回「已发布」Tab 的显示文本
  ///
  /// 未选中或未设置 statusFilter 时显示「全部」，否则显示对应状态的中文名
  static String _publishedTabLabel(GuideMineState state, bool selected) {
    if (!selected || state.statusFilter == null) return '全部';
    return switch (state.statusFilter!) {
      GuideStatus.pending => '待审核',
      GuideStatus.published => '已发布',
      GuideStatus.rejected => '已驳回',
      GuideStatus.offShelf => '已下架',
      _ => '全部',
    };
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final int? count;
  final bool active;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: active ? colors.accentBlue : colors.chipInactiveBg,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : colors.chipInactiveText,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                _PillBadge(count: count!, active: active),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 已发布 Tab 专用：右侧带向下箭头，整体点击打开二级筛选浮窗
class _PublishedTabPill extends StatelessWidget {
  final GlobalKey anchorKey;
  final String label;
  final int? count;
  final bool active;
  final VoidCallback onTap;

  const _PublishedTabPill({
    required this.anchorKey,
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          key: anchorKey,
          duration: const Duration(milliseconds: 160),
          height: 36,
          padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
          decoration: BoxDecoration(
            color: active ? colors.accentBlue : colors.chipInactiveBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : colors.chipInactiveText,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                _PillBadge(count: count!, active: active),
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: active ? Colors.white : colors.chipInactiveText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final int count;
  final bool active;

  const _PillBadge({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    final bgColor = active
        ? Colors.white.withValues(alpha: 0.22)
        : (colors.isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.08));
    final textColor = active ? Colors.white : colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count > 999 ? '999+' : count.toString(),
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
