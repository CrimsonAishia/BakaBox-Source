import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/map_cd/map_cd_bloc.dart';
import '../../core/bloc/map_contribution/map_contribution_bloc.dart';
import 'map_database_all_tab_mobile.dart';

/// 移动端地图数据库页面
///
/// 展示所有地图列表，支持搜索和地图类型筛选，点击查看运行历史
class MapDatabaseMobile extends StatelessWidget {
  const MapDatabaseMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => MapContributionBloc()),
        BlocProvider(create: (_) => MapCdBloc()),
      ],
      child: const _MapDatabaseView(),
    );
  }
}

class _MapDatabaseView extends StatelessWidget {
  const _MapDatabaseView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '地图数据库',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      body: const MapDatabaseAllTabMobile(),
    );
  }
}
