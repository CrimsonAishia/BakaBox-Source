import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/bloc/auth/auth_bloc.dart';
import '../../../../core/bloc/auth/auth_state.dart';
import '../../../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../../../core/bloc/key_binding/key_binding_event.dart';
import '../../../../core/bloc/key_binding/key_binding_state.dart';
import '../components/common_widgets.dart' as common;
import '../components/config_card.dart';
import '../components/toolbar_widgets.dart';

/// 左侧面板：工具栏 + 配置列表
class LeftPanel extends StatelessWidget {
  final TextEditingController searchCtrl;
  final int rightMode;
  final ValueChanged<int> onModeChanged;
  final VoidCallback onConfigTap;

  const LeftPanel({
    super.key,
    required this.searchCtrl,
    required this.rightMode,
    required this.onModeChanged,
    required this.onConfigTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(context),
        const SizedBox(height: 12),
        Expanded(child: _buildConfigList(context)),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : Colors.grey[200]!,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ToolbarButton(
                    icon: MdiIcons.formatListBulletedSquare,
                    label: '配置库',
                    active: rightMode == 0,
                    onTap: () => onModeChanged(0),
                  ),
                  ToolbarButton(
                    icon: MdiIcons.fileCodeOutline,
                    label: '本地配置',
                    active: rightMode == 1,
                    onTap: () => onModeChanged(1),
                  ),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) => ToolbarButton(
                      icon: MdiIcons.cloudUploadOutline,
                      label: '发布',
                      active: rightMode == 2,
                      onTap: () => onModeChanged(2),
                      badge: !state.isAuthenticated,
                    ),
                  ),
                ],
              ),
            ),
          ),
          BlocBuilder<KeyBindingBloc, KeyBindingState>(
            builder: (context, state) => Tooltip(
              message: '刷新配置列表',
              child: common.IconButton(
                icon: Icons.refresh_rounded,
                loading: state.isLoading,
                onTap: () {
                  context.read<KeyBindingBloc>().add(const KeyBindingLoadConfigs(showSuccessMessage: true));
                  context.read<KeyBindingBloc>().add(KeyBindingLoadCategories());
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: SearchField(
                    controller: searchCtrl,
                    onChanged: (v) => context.read<KeyBindingBloc>().add(
                      KeyBindingSetSearchKeyword(v.isEmpty ? null : v),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                BlocBuilder<KeyBindingBloc, KeyBindingState>(
                  builder: (context, state) => CategoryDropdown(
                    selectedCategoryId: state.categoryFilter,
                    categories: state.categories
                        .map((c) => CategoryItem(id: c.id, name: c.name))
                        .toList(),
                    onChanged: (v) => context.read<KeyBindingBloc>().add(
                      KeyBindingSetCategoryFilter(v),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<KeyBindingBloc, KeyBindingState>(
              builder: (context, state) {
                if (state.isLoading && state.configs.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                
                final configs = state.filteredConfigs;
                if (configs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          MdiIcons.packageVariant,
                          size: 40,
                          color: isDark ? Colors.white24 : Colors.grey[300],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '暂无配置',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: configs.length,
                  itemBuilder: (context, i) {
                    final cfg = configs[i];
                    final selected = state.selectedConfig?.id == cfg.id;
                    final applied = state.isConfigApplied(cfg.configId);
                    return ConfigCard(
                      config: cfg,
                      selected: selected,
                      applied: applied,
                      onTap: () {
                        context.read<KeyBindingBloc>().add(KeyBindingSelectConfig(cfg));
                        onConfigTap();
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
