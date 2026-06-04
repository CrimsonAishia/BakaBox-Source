import 'dart:ui';

import 'package:flutter/material.dart';

import '../../bloc/guide_categories/guide_categories_state.dart';
import '../../models/guide_models.dart';
import 'guide_category_tab_bar.dart';
import 'guide_tokens.dart';

/// 攻略列表粘性玻璃态 FilterBar
///
/// 组合：分类 Tab + 排序下拉 + 筛选 Popover（含地图筛选） + 搜索输入框。
/// 当 `mapName` 已选时显示可移除的地图 chip。
///
/// 用于 `GuideListView` 的 `SliverPersistentHeader(pinned: true)` 中。
///
/// 用法：
/// ```dart
/// GuideFilterBar(
///   categories: categoriesState.items,
///   categoriesStatus: categoriesState.status,
///   selectedCategory: filter.category,
///   sortBy: state.sortBy,
///   keyword: state.keyword,
///   selectedMapName: filter.mapName,
///   selectedMapLabel: '我的世界',
///   selectedMapBackground: 'https://...',
///   onCategoryChanged: (code) => ...,
///   onSortChanged: (sort) => ...,
///   onKeywordChanged: (kw) => ...,
///   onMapFilterTap: () => showGuideMapPickerSheet(...),
///   onMapFilterRemoved: () => ...,
///   onMapChipTap: () => DesktopNavigator.openMapDatabase(mapName: ...),
///   onRetryCategories: () => categoriesBloc.add(LoadCategories(force: true)),
/// )
/// ```
class GuideFilterBar extends StatelessWidget {
  /// 分类列表（来自 GuideCategoriesBloc）
  final List<GuideCategoryDef> categories;

  /// 分类加载状态（用于判断是否显示分类 Tab）
  final CategoriesStatus categoriesStatus;

  /// 当前选中分类 code
  final String? selectedCategory;

  /// 当前排序方式
  final GuideSortBy sortBy;

  /// 当前搜索关键词
  final String keyword;

  /// 已选地图名称
  final String? selectedMapName;

  /// 已选地图展示名
  final String? selectedMapLabel;

  /// 已选地图背景图 URL
  final String? selectedMapBackground;

  /// 分类切换回调
  final ValueChanged<String?>? onCategoryChanged;

  /// 排序切换回调
  final ValueChanged<GuideSortBy>? onSortChanged;

  /// 搜索关键词变更回调
  final ValueChanged<String>? onKeywordChanged;

  /// 地图筛选按钮点击（弹出 GuideMapPickerSheet）
  final VoidCallback? onMapFilterTap;

  /// 移除地图筛选
  final VoidCallback? onMapFilterRemoved;

  /// 地图 chip 文字部分点击（跳转地图详情）
  final VoidCallback? onMapChipTap;

  /// 分类加载失败时的重试回调
  final VoidCallback? onRetryCategories;

  const GuideFilterBar({
    super.key,
    required this.categories,
    required this.categoriesStatus,
    this.selectedCategory,
    this.sortBy = GuideSortBy.latest,
    this.keyword = '',
    this.selectedMapName,
    this.selectedMapLabel,
    this.selectedMapBackground,
    this.onCategoryChanged,
    this.onSortChanged,
    this.onKeywordChanged,
    this.onMapFilterTap,
    this.onMapFilterRemoved,
    this.onMapChipTap,
    this.onRetryCategories,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: GuideTokens.borderRadius16,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GuideTokens.glassBlurSigma,
          sigmaY: GuideTokens.glassBlurSigma,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: GuideTokens.borderRadius16,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: GuideTokens.space16,
            vertical: GuideTokens.space12,
          ),
          child: Row(
            children: [
              // 搜索输入框
              SizedBox(
                width: 240,
                height: 36,
                child: TextField(
                  controller: TextEditingController(text: keyword),
                  onChanged: onKeywordChanged,
                  style: Theme.of(context).textTheme.bodySmall,
                  decoration: InputDecoration(
                    hintText: 'Search Guides...',
                    hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: GuideTokens.textTertiary(context),
                        ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: GuideTokens.textTertiary(context),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: GuideTokens.space12,
                      vertical: GuideTokens.space8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: GuideTokens.borderRadius20,
                      borderSide: BorderSide(
                        color: GuideTokens.divider(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: GuideTokens.borderRadius20,
                      borderSide: BorderSide(
                        color: GuideTokens.divider(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: GuideTokens.borderRadius20,
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.02),
                  ),
                ),
              ),
              const SizedBox(width: GuideTokens.space16),

              // 分类 Tab 或错误提示
              if (categoriesStatus == CategoriesStatus.success)
                Expanded(
                  child: GuideCategoryTabBar(
                    categories: categories,
                    selectedCode: selectedCategory,
                    onSelected: onCategoryChanged,
                  ),
                )
              else if (categoriesStatus == CategoriesStatus.failure)
                Expanded(child: _buildCategoryError(context))
              else
                const Spacer(),

              const SizedBox(width: GuideTokens.space16),

              // 操作按钮：地图 chip + Filter + Sort
              // 右侧 Submit 按钮
              FilledButton(
                onPressed: () {
                  // TODO: trigger submit
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0080FF), // Bright Blue from prototype
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: GuideTokens.borderRadius8,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: const Text(
                  'Submit Guide',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryError(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(
        horizontal: GuideTokens.space12,
      ),
      decoration: BoxDecoration(
        color: GuideTokens.statusRejected.withValues(alpha: 0.08),
        borderRadius: GuideTokens.borderRadius8,
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: GuideTokens.statusRejected,
          ),
          const SizedBox(width: GuideTokens.space8),
          Expanded(
            child: Text(
              '分类加载失败',
              style: theme.textTheme.bodySmall?.copyWith(
                color: GuideTokens.statusRejected,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetryCategories,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: GuideTokens.space8,
              ),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  // _buildActionRow is intentionally removed since it's merged into build()
}

