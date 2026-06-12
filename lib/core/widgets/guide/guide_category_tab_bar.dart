import 'package:flutter/material.dart';

import '../../models/guide_models.dart';
import 'guide_tokens.dart';
import '../../constants/app_colors.dart';

/// 攻略分类圆药丸 Tab 栏
///
/// 水平滚动的药丸风格 Tab，激活项为实色 primary + shadowSm，
/// 非激活项透明背景。数据由 `GuideCategoriesBloc` 提供，
/// 首项固定为"全部"。
///
/// 用法：
/// ```dart
/// GuideCategoryTabBar(
///   categories: categoriesState.items,
///   selectedCode: currentFilter.category,
///   onSelected: (code) => bloc.add(ChangeFilter(filter.copyWith(category: code))),
/// )
/// ```
class GuideCategoryTabBar extends StatelessWidget {
  /// 分类列表（来自 GuideCategoriesBloc）
  final List<GuideCategoryDef> categories;

  /// 当前选中的分类 code（null 表示"全部"）
  final String? selectedCode;

  /// 选中回调（code 为 null 时表示选择了"全部"）
  final ValueChanged<String?>? onSelected;

  const GuideCategoryTabBar({
    super.key,
    required this.categories,
    this.selectedCode,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: GuideTokens.space4),
        itemCount: categories.length + 1, // +1 for "全部"
        separatorBuilder: (_, __) => const SizedBox(width: GuideTokens.space8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CategoryPill(
              label: '全部',
              isSelected: selectedCode == null,
              onTap: () => onSelected?.call(null),
            );
          }
          final cat = categories[index - 1];
          return _CategoryPill(
            label: cat.name,
            count: cat.count > 0 ? cat.count : null,
            isSelected: selectedCode == cat.code,
            onTap: () => onSelected?.call(cat.code),
          );
        },
      ),
    );
  }
}

class _CategoryPill extends StatefulWidget {
  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback? onTap;

  const _CategoryPill({
    required this.label,
    this.count,
    required this.isSelected,
    this.onTap,
  });

  @override
  State<_CategoryPill> createState() => _CategoryPillState();
}

class _CategoryPillState extends State<_CategoryPill> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: GuideTokens.durationFast,
          curve: Curves.easeOutCubic,
          height: 36,
          padding: const EdgeInsets.symmetric(
            horizontal: GuideTokens.space16,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primary // Bright blue
                : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
            borderRadius: GuideTokens.borderRadius8,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: widget.isSelected
                          ? Colors.white
                          : GuideTokens.textSecondary(context),
                      fontWeight:
                          widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (widget.count != null) ...[
                    const SizedBox(width: GuideTokens.space4),
                    Text(
                      '${widget.count}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: widget.isSelected
                            ? Colors.white.withValues(alpha: 0.8)
                            : GuideTokens.textTertiary(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
