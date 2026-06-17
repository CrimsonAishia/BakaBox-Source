import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/bloc/crash_report/crash_report_bloc.dart';
import '../../../core/bloc/crash_report/crash_report_event.dart';
import '../../../core/bloc/crash_report/crash_report_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/toast_utils.dart';
import 'crash_detail_pane.dart';
import 'crash_detail_view_model.dart';
import 'crash_report_card.dart';
import 'crash_sidebar.dart';
import 'local_crash_card.dart';

/// 工具箱内的「CS2 崩溃报告」工具
///
/// 布局：
/// - 顶部：社区聚合面板（总数 / 今日 / 我的）+ 搜索框
/// - 工具条：「全部 / 我的」+ 严重度过滤 + 类别过滤
/// - 主体：左列表 + 右详情（响应式：窄屏只显示其中一列）
class CrashReportTool extends StatelessWidget {
  const CrashReportTool({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CrashReportBloc()
        ..add(const CrashReportFetchStats())
        ..add(const CrashReportFetchMine()),
      child: const _CrashReportToolContent(),
    );
  }
}

class _CrashReportToolContent extends StatefulWidget {
  const _CrashReportToolContent();

  @override
  State<_CrashReportToolContent> createState() =>
      _CrashReportToolContentState();
}

class _CrashReportToolContentState extends State<_CrashReportToolContent> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final bloc = context.read<CrashReportBloc>();
    final state = bloc.state;
    // 仅社区视图分页；已无更多 / 正在加载时不重复触发
    if (state.showMine || !state.canLoadMore || state.isLoadingMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      bloc.add(const CrashReportLoadMore());
    }
  }

  void _search(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      context.read<CrashReportBloc>().add(CrashReportSearch(text));
    });
  }

  Future<void> _confirmDeleteLocal(BuildContext context, String path) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bloc = context.read<CrashReportBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.slate800 : Colors.white,
        title: const Text('删除这个崩溃文件？'),
        content: const Text(
          '将从游戏目录删除该 .mdmp 文件。如果它已经被自动上传到社区，'
          '其他玩家仍能在社区里看到。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red500,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(CrashReportDeleteLocal(path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.gray200,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 980;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CrashSidebar(
                  collapsed: compact,
                  onSearchChanged: _search,
                  searchController: _searchController,
                  onSearchClear: () {
                    _searchController.clear();
                    setState(() {});
                    _search('');
                  },
                ),
                Container(
                  width: 1,
                  color: isDark ? AppColors.slate700 : AppColors.gray200,
                ),
                Expanded(child: _buildMainArea(isDark)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainArea(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumn = constraints.maxWidth >= 820;
        return BlocBuilder<CrashReportBloc, CrashReportState>(
          buildWhen: (prev, curr) =>
              prev.detail != curr.detail ||
              prev.isLoadingDetail != curr.isLoadingDetail ||
              prev.selectedId != curr.selectedId ||
              prev.showMine != curr.showMine ||
              prev.localDetail != curr.localDetail ||
              prev.isLoadingLocalDetail != curr.isLoadingLocalDetail ||
              prev.selectedLocalPath != curr.selectedLocalPath,
          builder: (context, state) {
            final hasDetail = state.showMine
                ? (state.localDetail != null || state.isLoadingLocalDetail)
                : (state.detail != null || state.isLoadingDetail);
            if (!twoColumn) {
              return hasDetail
                  ? _buildDetailPane(state.showMine)
                  : _buildListPane();
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 360, child: _buildListPane()),
                Container(
                  width: 1,
                  color: isDark ? AppColors.slate700 : AppColors.gray200,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildDetailPane(state.showMine),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // List pane
  Widget _buildListPane() {
    return BlocBuilder<CrashReportBloc, CrashReportState>(
      buildWhen: (prev, curr) => prev.showMine != curr.showMine,
      builder: (context, state) {
        return state.showMine ? _buildLocalListPane() : _buildRemoteListPane();
      },
    );
  }

  Widget _buildRemoteListPane() {
    return BlocConsumer<CrashReportBloc, CrashReportState>(
      listenWhen: (prev, curr) =>
          prev.error != curr.error &&
          curr.error != null &&
          // 列表已有数据时只 toast 提示；列表为空走错误页
          curr.items.isNotEmpty,
      listener: (context, state) {
        if (state.error != null) {
          ToastUtils.showError(context, state.error!);
          context.read<CrashReportBloc>().add(const CrashReportClearError());
        }
      },
      buildWhen: (prev, curr) =>
          prev.items != curr.items ||
          prev.isLoading != curr.isLoading ||
          prev.isLoadingMore != curr.isLoadingMore ||
          prev.hasMore != curr.hasMore ||
          prev.selectedId != curr.selectedId ||
          prev.error != curr.error,
      builder: (context, state) {
        if (state.isLoading && state.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.error != null && state.items.isEmpty) {
          return _buildErrorState(state.error!);
        }
        if (state.items.isEmpty) {
          return _buildEmptyList(state, mine: false);
        }
        final list = ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= state.items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              );
            }
            final item = state.items[index];
            return CrashReportCard(
              report: item,
              selected: state.selectedId == item.id,
              onTap: () => context.read<CrashReportBloc>().add(
                CrashReportLoadDetail(item.id),
              ),
            );
          },
        );
        return _withRefreshBar(list, refreshing: state.isLoading);
      },
    );
  }

  Widget _buildLocalListPane() {
    return BlocConsumer<CrashReportBloc, CrashReportState>(
      listenWhen: (prev, curr) =>
          prev.localError != curr.localError && curr.localError != null,
      listener: (context, state) {
        if (state.localError != null) {
          ToastUtils.showError(context, state.localError!);
        }
      },
      buildWhen: (prev, curr) =>
          prev.localFiles != curr.localFiles ||
          prev.isLoadingLocal != curr.isLoadingLocal ||
          prev.selectedLocalPath != curr.selectedLocalPath,
      builder: (context, state) {
        if (state.isLoadingLocal && state.localFiles.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.localFiles.isEmpty) {
          return _buildEmptyList(state, mine: true);
        }
        final list = ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          itemCount: state.localFiles.length,
          itemBuilder: (context, index) {
            final f = state.localFiles[index];
            return LocalCrashCard(
              file: f,
              selected: state.selectedLocalPath == f.path,
              onTap: () => context.read<CrashReportBloc>().add(
                CrashReportLoadLocalDetail(f.path),
              ),
            );
          },
        );
        return _withRefreshBar(list, refreshing: state.isLoadingLocal);
      },
    );
  }

  /// 在列表已有数据的前提下重新加载时，顶部显示一条细进度条。
  Widget _withRefreshBar(Widget child, {required bool refreshing}) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        if (refreshing)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2.5),
          ),
      ],
    );
  }

  Widget _buildEmptyList(CrashReportState state, {required bool mine}) {
    final isSignatureMatch = state.currentSignature != null && !mine;
    final isSearching = state.currentKeyword.isNotEmpty && !mine;

    if (mine && state.gamePathConfigured == false) {
      return _CrashEmptyState(
        icon: MdiIcons.cogOutline,
        title: '尚未配置 CS2 游戏路径',
        subtitle: '在「设置 → 游戏」里指定 CS2 安装目录后，本机崩溃就会出现在这里',
      );
    }

    if (isSignatureMatch) {
      return _CrashEmptyState(
        icon: Icons.search_off,
        title: '没有找到同款崩溃',
        subtitle: '社区中暂时没有与该崩溃特征码一致的公开报告',
        action: OutlinedButton.icon(
          onPressed: () {
            _searchController.clear();
            setState(() {});
            _search('');
          },
          icon: Icon(MdiIcons.close, size: 16),
          label: const Text('清除同款过滤'),
        ),
      );
    }

    return _CrashEmptyState(
      icon: isSearching ? Icons.search_off : MdiIcons.alertCircleOutline,
      title: isSearching ? '没找到相关崩溃' : (mine ? '本机暂无 CS2 崩溃文件' : '社区还没有公开的崩溃'),
      subtitle: isSearching
          ? '试试换个关键字 / 模块名'
          : (mine ? '游戏没崩过 → 这是好事 :)' : '游戏崩了的话，自动上传后社区里就能看到了'),
      action: isSearching
          ? OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {});
                _search('');
              },
              icon: Icon(MdiIcons.close, size: 16),
              label: const Text('清除搜索'),
            )
          : null,
    );
  }

  Widget _buildErrorState(String error) {
    return _CrashEmptyState(
      icon: MdiIcons.alertCircleOutline,
      title: '加载失败',
      subtitle: error,
      iconColor: AppColors.red500,
      action: ElevatedButton.icon(
        onPressed: () =>
            context.read<CrashReportBloc>().add(const CrashReportRefresh()),
        icon: Icon(MdiIcons.refresh, size: 16),
        label: const Text('重试'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  // Detail pane
  Widget _buildDetailPane(bool showMine) {
    return BlocBuilder<CrashReportBloc, CrashReportState>(
      buildWhen: (prev, curr) =>
          prev.detail != curr.detail ||
          prev.isLoadingDetail != curr.isLoadingDetail ||
          prev.localDetail != curr.localDetail ||
          prev.isLoadingLocalDetail != curr.isLoadingLocalDetail,
      builder: (context, state) {
        if (showMine) {
          final vm = state.localDetail == null
              ? null
              : CrashDetailViewModel.fromLocal(state.localDetail!);
          return CrashDetailPane(
            detail: vm,
            isLoading: state.isLoadingLocalDetail,
            onBack: () => context.read<CrashReportBloc>().add(
              const CrashReportCloseLocalDetail(),
            ),
            onDeleteLocal: vm == null
                ? null
                : () => _confirmDeleteLocal(context, vm.dumpPath!),
          );
        }
        final vm = state.detail == null
            ? null
            : CrashDetailViewModel.fromRemote(state.detail!);
        return CrashDetailPane(
          detail: vm,
          isLoading: state.isLoadingDetail,
          onBack: () => context.read<CrashReportBloc>().add(
            const CrashReportCloseDetail(),
          ),
          onFindSimilar: (signature) {
            _searchController.text = signature;
            context.read<CrashReportBloc>().add(
              CrashReportFetch(keyword: signature, signature: signature),
            );
            context.read<CrashReportBloc>().add(const CrashReportCloseDetail());
          },
        );
      },
    );
  }
}

// 通用空 / 错误状态
class _CrashEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final Color? iconColor;

  const _CrashEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = iconColor ?? AppColors.blue500;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.gray800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: isDark ? Colors.white54 : AppColors.gray500,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}
