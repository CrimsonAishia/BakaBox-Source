import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/bloc/crash_report/crash_report_bloc.dart';
import '../../../core/bloc/crash_report/crash_report_event.dart';
import '../../../core/bloc/crash_report/crash_report_state.dart';
import '../../../core/constants/app_colors.dart';

/// 工具页左侧栏：视图切换 + 搜索 + 过滤 + 统计 + 刷新
///
/// 在窄屏（< 980）下变成"图标栏"形态：仅保留视图切换 + 刷新，
/// 过滤、搜索、统计折叠到一个弹出菜单里，避免占用主区宽度。
class CrashSidebar extends StatelessWidget {
  /// 是否折叠（窄屏下传入 true）
  final bool collapsed;

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;

  const CrashSidebar({
    super.key,
    required this.collapsed,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchClear,
  });

  @override
  Widget build(BuildContext context) {
    return collapsed ? const _CollapsedSidebar() : _ExpandedSidebar(
      searchController: searchController,
      onSearchChanged: onSearchChanged,
      onSearchClear: onSearchClear,
    );
  }
}


class _ExpandedSidebar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;

  const _ExpandedSidebar({
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 240,
      color: isDark ? AppColors.slate800 : Colors.white,
      child: BlocBuilder<CrashReportBloc, CrashReportState>(
        buildWhen: (prev, curr) =>
            prev.showMine != curr.showMine ||
            prev.currentSeverity != curr.currentSeverity ||
            prev.currentCategory != curr.currentCategory ||
            prev.stats != curr.stats ||
            prev.localFiles != curr.localFiles ||
            prev.totalCount != curr.totalCount,
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionLabel(text: '视图', isDark: isDark),
              _ViewSwitch(state: state, isDark: isDark, onSwitch: (mine) {
                if (searchController.text.isNotEmpty) onSearchClear();
                context
                    .read<CrashReportBloc>()
                    .add(CrashReportSwitchView(mine));
              }),
              const SizedBox(height: 16),
              _SectionLabel(
                text: '搜索',
                isDark: isDark,
                disabled: state.showMine,
              ),
              _SearchBox(
                controller: searchController,
                onChanged: onSearchChanged,
                onClear: onSearchClear,
                disabled: state.showMine,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _SectionLabel(
                text: '严重度',
                isDark: isDark,
                disabled: state.showMine,
              ),
              _SeverityList(
                value: state.currentSeverity,
                disabled: state.showMine,
                isDark: isDark,
                onChanged: (v) => context
                    .read<CrashReportBloc>()
                    .add(CrashReportFilterSeverity(v)),
              ),
              const SizedBox(height: 16),
              _SectionLabel(
                text: '类别',
                isDark: isDark,
                disabled: state.showMine,
              ),
              _CategoryList(
                value: state.currentCategory,
                disabled: state.showMine,
                isDark: isDark,
                onChanged: (v) => context
                    .read<CrashReportBloc>()
                    .add(CrashReportFilterCategory(v)),
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _StatsBlock(state: state, isDark: isDark),
              const Spacer(),
              _SidebarFooter(
                onRefresh: () => context
                    .read<CrashReportBloc>()
                    .add(const CrashReportRefresh()),
                isDark: isDark,
              ),
            ],
          );
        },
      ),
    );
  }
}


class _CollapsedSidebar extends StatelessWidget {
  const _CollapsedSidebar();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 56,
      color: isDark ? AppColors.slate800 : Colors.white,
      child: BlocBuilder<CrashReportBloc, CrashReportState>(
        buildWhen: (prev, curr) => prev.showMine != curr.showMine,
        builder: (context, state) {
          return Column(
            children: [
              const SizedBox(height: 12),
              _CollapsedTab(
                icon: MdiIcons.laptop,
                tooltip: '我的本机',
                selected: state.showMine,
                onTap: () => context
                    .read<CrashReportBloc>()
                    .add(const CrashReportSwitchView(true)),
              ),
              const SizedBox(height: 6),
              _CollapsedTab(
                icon: MdiIcons.formatListBulleted,
                tooltip: '社区全部',
                selected: !state.showMine,
                onTap: () => context
                    .read<CrashReportBloc>()
                    .add(const CrashReportSwitchView(false)),
              ),
              const Spacer(),
              IconButton(
                tooltip: '刷新',
                icon: Icon(MdiIcons.refresh, size: 18),
                onPressed: () => context
                    .read<CrashReportBloc>()
                    .add(const CrashReportRefresh()),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

class _CollapsedTab extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _CollapsedTab({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: selected
                  ? AppColors.primary
                  : (isDark ? Colors.white70 : AppColors.gray500),
            ),
          ),
        ),
      ),
    );
  }
}


// Section helpers

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  final bool disabled;

  const _SectionLabel({
    required this.text,
    required this.isDark,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: disabled
              ? (isDark ? Colors.white24 : AppColors.gray300)
              : (isDark ? Colors.white60 : AppColors.gray500),
        ),
      ),
    );
  }
}

class _ViewSwitch extends StatelessWidget {
  final CrashReportState state;
  final bool isDark;
  final ValueChanged<bool> onSwitch;

  const _ViewSwitch({
    required this.state,
    required this.isDark,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _ViewTab(
              icon: MdiIcons.laptop,
              label: '我的',
              selected: state.showMine,
              isDark: isDark,
              onTap: () => onSwitch(true),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ViewTab(
              icon: MdiIcons.formatListBulleted,
              label: '社区',
              selected: !state.showMine,
              isDark: isDark,
              onTap: () => onSwitch(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _ViewTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : (isDark ? AppColors.slate700 : AppColors.gray100),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : AppColors.gray500),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white70 : AppColors.gray500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _SearchBox extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool disabled;
  final bool isDark;

  const _SearchBox({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.disabled,
    required this.isDark,
  });

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final hasText = widget.controller.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Opacity(
        opacity: widget.disabled ? 0.5 : 1,
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : AppColors.gray50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.gray200,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            enabled: !widget.disabled,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : null,
            ),
            decoration: InputDecoration(
              hintText: '模块 / 关键字...',
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : AppColors.gray400,
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 16,
                color: isDark ? Colors.white38 : AppColors.gray400,
              ),
              suffixIcon: hasText
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 14),
                      padding: EdgeInsets.zero,
                      onPressed: widget.onClear,
                      color: isDark
                          ? Colors.white38
                          : AppColors.gray400,
                      splashRadius: 14,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              isDense: true,
            ),
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
  }
}


class _SeverityList extends StatelessWidget {
  final String value;
  final bool disabled;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const _SeverityList({
    required this.value,
    required this.disabled,
    required this.isDark,
    required this.onChanged,
  });

  static final _options = <(String, String, IconData, Color)>[
    ('all', '全部', MdiIcons.formatListBulleted, AppColors.gray500),
    ('high', '严重', MdiIcons.alertOctagon, AppColors.red500),
    ('medium', '警告', MdiIcons.alert, AppColors.amber500),
    ('low', '一般', MdiIcons.informationOutline, AppColors.blue500),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: AbsorbPointer(
          absorbing: disabled,
          child: Column(
            children: _options.map((o) {
              final selected = value == o.$1;
              return _SidebarRow(
                icon: o.$3,
                label: o.$2,
                color: o.$4,
                selected: selected,
                isDark: isDark,
                onTap: () => onChanged(o.$1),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final String value;
  final bool disabled;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const _CategoryList({
    required this.value,
    required this.disabled,
    required this.isDark,
    required this.onChanged,
  });

  // (key, label, icon)
  static const _options = <(String, String)>[
    ('all', '全部'),
    ('resource', '游戏资源'),
    ('gpu', '显卡驱动'),
    ('code_exec', '代码异常'),
    ('system', '系统组件'),
    ('tools', 'Workshop 工具'),
    ('unknown', '未知'),
  ];

  @override
  Widget build(BuildContext context) {
    final iconFor = {
      'all': MdiIcons.formatListBulleted,
      'resource': MdiIcons.fileSearchOutline,
      'gpu': MdiIcons.memory,
      'code_exec': MdiIcons.skullOutline,
      'system': MdiIcons.cogOutline,
      'tools': MdiIcons.toolboxOutline,
      'unknown': MdiIcons.helpCircleOutline,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: AbsorbPointer(
          absorbing: disabled,
          child: Column(
            children: _options.map((o) {
              final selected = value == o.$1;
              return _SidebarRow(
                icon: iconFor[o.$1] ?? MdiIcons.helpCircleOutline,
                label: o.$2,
                color: AppColors.gray500,
                selected: selected,
                isDark: isDark,
                onTap: () => onChanged(o.$1),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}


class _SidebarRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _SidebarRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: selected
                    ? color
                    : (isDark ? Colors.white60 : AppColors.gray500),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? color
                        : (isDark ? Colors.white70 : AppColors.gray700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsBlock extends StatelessWidget {
  final CrashReportState state;
  final bool isDark;

  const _StatsBlock({required this.state, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final stats = state.stats;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatRow(
            icon: MdiIcons.alertCircleOutline,
            color: AppColors.blue500,
            label: '社区总数',
            value: stats?.totalCount ?? 0,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _StatRow(
            icon: MdiIcons.calendarTodayOutline,
            color: AppColors.amber500,
            label: '今天',
            value: stats?.todayCount ?? 0,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _StatRow(
            icon: MdiIcons.laptop,
            color: AppColors.violet500,
            label: '本机',
            value: state.localFiles.length,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final bool isDark;

  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : AppColors.gray500,
            ),
          ),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.gray800,
          ),
        ),
      ],
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool isDark;

  const _SidebarFooter({required this.onRefresh, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SizedBox(
        height: 34,
        child: OutlinedButton.icon(
          onPressed: onRefresh,
          icon: Icon(MdiIcons.refresh, size: 14),
          label: const Text('刷新', style: TextStyle(fontSize: 12.5)),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.white70 : AppColors.gray700,
            side: BorderSide(
              color: isDark ? AppColors.slate600 : AppColors.gray300,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ),
    );
  }
}
