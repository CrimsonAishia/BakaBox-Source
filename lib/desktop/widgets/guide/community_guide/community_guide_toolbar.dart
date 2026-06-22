import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/guide_categories/guide_categories_bloc.dart';
import '../../../../core/bloc/guide_categories/guide_categories_event.dart';
import '../../../../core/bloc/guide_categories/guide_categories_state.dart';
import '../../../../core/bloc/guide_list/guide_list_bloc.dart';
import '../../../../core/bloc/guide_list/guide_list_event.dart';
import '../../../../core/bloc/guide_list/guide_list_state.dart';
import 'community_guide_category_row.dart';
import 'community_guide_theme.dart';

/// 顶部 Hero Banner + 浮动毛玻璃工具栏
///
/// 工具栏水平居中对齐 Banner 底边，包含：搜索框 / 分类切换按钮 / 个人中心按钮
class CommunityGuideToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final VoidCallback onOpenMine;

  const CommunityGuideToolbar({
    super.key,
    required this.searchController,
    required this.onOpenMine,
  });

  /// Banner 高度
  static const double _bannerHeight = 240.0;

  /// 工具栏自身高度
  static const double _toolbarHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GuideCategoriesBloc, GuideCategoriesState>(
      builder: (context, catState) {
        final listState = context.watch<GuideListBloc>().state;
        const toolbarTop = _bannerHeight - _toolbarHeight / 2;
        const totalHeight = toolbarTop + _toolbarHeight + 12;

        return SizedBox(
          height: totalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _bannerHeight,
                child: _HeroBanner(),
              ),
              Positioned(
                top: toolbarTop,
                left: 24,
                right: 24,
                height: _toolbarHeight,
                child: _ToolbarContent(
                  searchController: searchController,
                  listState: listState,
                  catState: catState,
                  onOpenMine: onOpenMine,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Hero Banner

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/guide/hero_banner.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF1E3A8A),
                    Color(0xFF6D28D9),
                    Color(0xFFB91C1C),
                  ],
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.30),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 工具栏内容（毛玻璃容器内的搜索 + 分类 + 我的）

class _ToolbarContent extends StatelessWidget {
  final TextEditingController searchController;
  final GuideListState listState;
  final GuideCategoriesState catState;
  final VoidCallback onOpenMine;

  const _ToolbarContent({
    required this.searchController,
    required this.listState,
    required this.catState,
    required this.onOpenMine,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.toolbarBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.toolbarBorder),
          ),
          child: Row(
            children: [
              _SearchField(controller: searchController),
              const SizedBox(width: 12),
              Expanded(
                child: _CategoryRow(
                  catState: catState,
                  selectedCode: listState.filter.category,
                ),
              ),
              const SizedBox(width: 12),
              _MineButton(onTap: onOpenMine),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    // 暗色：保留毛玻璃透出 banner；亮色：使用偏白填充以保证阅读
    final fillColor = colors.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.85);

    return SizedBox(
      width: 240,
      height: 36,
      child: TextField(
        controller: controller,
        style: TextStyle(color: colors.textPrimary, fontSize: 13),
        onChanged: (value) {
          context.read<GuideListBloc>().add(ChangeKeyword(value));
        },
        decoration: InputDecoration(
          hintText: '搜索攻略...',
          hintStyle: TextStyle(color: colors.hintText, fontSize: 13),
          prefixIcon: Icon(Icons.search, size: 18, color: colors.hintText),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.inputBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.inputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.accentBlue, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class _MineButton extends StatelessWidget {
  final VoidCallback onTap;

  const _MineButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        icon: const Icon(Icons.person_outline, size: 16),
        label: const Text('个人中心'),
      ),
    );
  }
}

// 分类按钮组（含失败/加载/成功 三态）

class _CategoryRow extends StatelessWidget {
  final GuideCategoriesState catState;
  final String? selectedCode;

  const _CategoryRow({required this.catState, required this.selectedCode});

  void _select(BuildContext context, String? code) {
    final bloc = context.read<GuideListBloc>();
    final filter = bloc.state.filter;
    if (code == null) {
      bloc.add(ChangeFilter(filter.copyWith(clearCategory: true)));
    } else {
      bloc.add(ChangeFilter(filter.copyWith(category: code)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);

    if (catState.status == CategoriesStatus.failure) {
      return Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 14,
            color: Colors.redAccent.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 6),
          Text(
            '分类加载失败',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () => context.read<GuideCategoriesBloc>().add(
              const LoadCategories(force: true),
            ),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '重试',
              style: TextStyle(fontSize: 12, color: colors.accentBlue),
            ),
          ),
        ],
      );
    }

    if (catState.status == CategoriesStatus.loading ||
        (catState.status == CategoriesStatus.initial &&
            catState.items.isEmpty)) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(
            5,
            (i) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                width: 100,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.skeletonBg,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final chips = <Widget>[
      CommunityGuideCategoryChip(
        label: '全部',
        active: selectedCode == null,
        onTap: () => _select(context, null),
      ),
    ];

    for (final cat in catState.items) {
      chips.add(const SizedBox(width: 8));
      chips.add(
        CommunityGuideCategoryChip(
          label: cat.name,
          active: selectedCode == cat.code,
          onTap: () => _select(context, cat.code),
        ),
      );
    }

    return CommunityGuideCategoryRow(children: chips);
  }
}
