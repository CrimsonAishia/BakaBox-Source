import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../core/bloc/auth/auth_bloc.dart';
import '../../../core/bloc/auth/auth_event.dart';
import '../../../core/bloc/auth/auth_state.dart';
import '../../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../../core/bloc/key_binding/key_binding_event.dart';
import '../../../core/bloc/key_binding/key_binding_state.dart';
import '../../../core/models/key_config_models.dart';
import '../../../core/services/token_service.dart';
import '../../../core/utils/key_placeholder_parser.dart';
import '../../../core/utils/toast_utils.dart';
import '../login_dialog.dart';
import 'key_selector.dart';

/// 按键绑定工具 - 现代化两栏布局
class KeyBindingTool extends StatefulWidget {
  const KeyBindingTool({super.key});

  @override
  State<KeyBindingTool> createState() => _KeyBindingToolState();
}

class _KeyBindingToolState extends State<KeyBindingTool> {
  final _searchCtrl = TextEditingController();
  
  // 右侧面板模式: 0=配置详情, 1=autoexec, 2=发布, 3=编辑
  int _rightMode = 0;
  
  // 正在编辑的配置（模式3时使用）
  KeyConfig? _editingConfig;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<KeyBindingBloc>();
      bloc.add(KeyBindingLoadConfigs());
      bloc.add(KeyBindingLoadCategories());
      bloc.add(KeyBindingLoadAutoexecContent());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<KeyBindingBloc, KeyBindingState>(
      listenWhen: (previous, current) {
        // 只在消息从 null 变为非 null 时触发，避免重复
        final successChanged = previous.successMessage != current.successMessage && 
            current.successMessage?.isNotEmpty == true;
        final errorChanged = previous.error != current.error && 
            current.error?.isNotEmpty == true;
        return successChanged || errorChanged;
      },
      listener: (context, state) {
        if (state.successMessage?.isNotEmpty == true) {
          ToastUtils.showSuccess(context, state.successMessage!);
          // 更新成功后自动切换回详情模式
          if (_rightMode == 3 && state.successMessage!.contains('更新')) {
            setState(() {
              _rightMode = 0;
              _editingConfig = null;
            });
          }
        }
        if (state.error?.isNotEmpty == true) {
          ToastUtils.showError(context, state.error!);
        }
        // 统一清除消息
        context.read<KeyBindingBloc>().add(KeyBindingClearMessages());
      },
      child: Container(
        margin: const EdgeInsets.all(0),
        child: Row(
          children: [
            // 左侧：配置列表 + 顶部工具栏
            Expanded(
              flex: 3,
              child: _LeftPanel(
                searchCtrl: _searchCtrl,
                rightMode: _rightMode,
                onModeChanged: (m) => setState(() {
                  _rightMode = m;
                  if (m != 3) _editingConfig = null;
                }),
                onConfigTap: () => setState(() {
                  _rightMode = 0;
                  _editingConfig = null;
                }),
              ),
            ),
            const SizedBox(width: 16),
            // 右侧：动态内容区
            Expanded(
              flex: 5,
              child: _RightPanel(
                mode: _rightMode,
                editingConfig: _editingConfig,
                onEditComplete: () => setState(() {
                  _rightMode = 0;
                  _editingConfig = null;
                }),
                onEditConfig: (config) => setState(() {
                  _rightMode = 3;
                  _editingConfig = config;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 左侧面板：工具栏 + 配置列表
// ============================================================================
class _LeftPanel extends StatelessWidget {
  final TextEditingController searchCtrl;
  final int rightMode;
  final ValueChanged<int> onModeChanged;
  final VoidCallback onConfigTap;

  const _LeftPanel({
    required this.searchCtrl,
    required this.rightMode,
    required this.onModeChanged,
    required this.onConfigTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部功能切换栏
        _buildToolbar(context),
        const SizedBox(height: 12),
        // 配置列表
        Expanded(child: _buildConfigList(context)),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ToolbarBtn(icon: MdiIcons.formatListBulletedSquare, label: '配置库', active: rightMode == 0, onTap: () => onModeChanged(0)),
                  _ToolbarBtn(icon: MdiIcons.fileCodeOutline, label: '本地配置', active: rightMode == 1, onTap: () => onModeChanged(1)),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) => _ToolbarBtn(
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
              child: _IconButton(
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: _SearchField(controller: searchCtrl)),
                const SizedBox(width: 8),
                _CategoryDropdown(),
              ],
            ),
          ),
          // 列表
          Expanded(
            child: BlocBuilder<KeyBindingBloc, KeyBindingState>(
              builder: (context, state) {
                if (state.isLoading && state.configs.isEmpty) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }
                final configs = state.filteredConfigs;
                if (configs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.packageVariant, size: 40, color: isDark ? Colors.white24 : Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('暂无配置', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400], fontSize: 13)),
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
                    return _ConfigCard(
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

// ============================================================================
// 右侧面板：根据模式显示不同内容
// ============================================================================
class _RightPanel extends StatelessWidget {
  final int mode;
  final KeyConfig? editingConfig;
  final VoidCallback? onEditComplete;
  final void Function(KeyConfig config)? onEditConfig;
  
  const _RightPanel({
    required this.mode,
    this.editingConfig,
    this.onEditComplete,
    this.onEditConfig,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: switch (mode) {
          1 => _AutoexecView(),
          2 => _PublishView(),
          3 => editingConfig != null 
              ? _EditView(config: editingConfig!, onComplete: onEditComplete)
              : _ConfigDetailView(onEditConfig: onEditConfig),
          _ => _ConfigDetailView(onEditConfig: onEditConfig),
        },
      ),
    );
  }
}

// ============================================================================
// 配置详情视图
// ============================================================================
class _ConfigDetailView extends StatelessWidget {
  final void Function(KeyConfig config)? onEditConfig;
  
  const _ConfigDetailView({this.onEditConfig});
  
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KeyBindingBloc, KeyBindingState>(
      builder: (context, state) {
        final cfg = state.selectedConfig;
        if (cfg == null) {
          return _EmptyHint(
            icon: MdiIcons.gesture,
            title: '选择一个配置',
            desc: '从左侧列表点击配置查看详情并应用',
          );
        }
        final placeholders = KeyPlaceholderParser.parse(cfg.config);
        final allBound = !cfg.needsKeybind || placeholders.isEmpty ||
            KeyPlaceholderParser.validate(cfg.config, state.keyBindings);
        final applied = state.isConfigApplied(cfg.configId);

        return Column(
          children: [
            // 头部
            _DetailHeader(config: cfg, applied: applied, onEditConfig: onEditConfig),
            // 内容
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cfg.needsKeybind && placeholders.isNotEmpty)
                      _KeyBindSection(placeholders: placeholders, bindings: state.keyBindings),
                    if (cfg.needsKeybind && placeholders.isNotEmpty) const SizedBox(height: 20),
                    _ScriptPreview(script: KeyPlaceholderParser.replace(cfg.config, state.keyBindings)),
                  ],
                ),
              ),
            ),
            // 底部操作
            _DetailFooter(
              config: cfg,
              allBound: allBound,
              applied: applied,
              saving: state.isSaving,
              bindings: state.keyBindings,
            ),
          ],
        );
      },
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final KeyConfig config;
  final bool applied;
  final void Function(KeyConfig config)? onEditConfig;
  
  const _DetailHeader({
    required this.config,
    required this.applied,
    this.onEditConfig,
  });

  @override
  Widget build(BuildContext context) {
    // 使用后端用户ID判断是否为作者
    final backendUserInfo = TokenService.instance.userInfo;
    final isOwner = backendUserInfo != null && backendUserInfo.id == config.userID;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0080FF).withValues(alpha: 0.08), isDark ? const Color(0xFF1E293B) : Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0080FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  config.needsKeybind ? MdiIcons.keyboardOutline : MdiIcons.codeJson,
                  color: const Color(0xFF0080FF),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(config.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1a1a2e))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Badge(label: config.category, color: const Color(0xFF0080FF)),
                        const SizedBox(width: 6),
                        _Badge(
                          label: config.needsKeybind ? '需绑定' : '自动',
                          color: config.needsKeybind ? const Color(0xFFf59e0b) : const Color(0xFF10b981),
                        ),
                        if (applied) ...[
                          const SizedBox(width: 6),
                          _Badge(label: '已应用', color: const Color(0xFF10b981), filled: true),
                        ],
                        if (isOwner) ...[
                          const SizedBox(width: 6),
                          _Badge(label: '我的', color: const Color(0xFF8b5cf6), filled: true),
                        ],
                        // 审核状态标签
                        if (config.isPending) ...[
                          const SizedBox(width: 6),
                          _Badge(label: '待审核', color: const Color(0xFFF59E0B), filled: true),
                        ],
                        if (config.isRejected) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: config.auditRemark.isNotEmpty
                                ? '拒绝原因: ${config.auditRemark}'
                                : '已拒绝',
                            child: _Badge(label: '已拒绝', color: const Color(0xFFEF4444), filled: true),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 投票按钮
              _DetailVoteButtons(config: config, isOwner: config.isOwner),
              const SizedBox(width: 8),
              // 编辑和删除按钮（仅对自己的配置显示）
              if (isOwner) ...[
                _ConfigActionButton(
                  icon: MdiIcons.pencilOutline,
                  tooltip: '编辑配置',
                  onTap: () => onEditConfig?.call(config),
                ),
                const SizedBox(width: 4),
                _ConfigActionButton(
                  icon: MdiIcons.deleteOutline,
                  tooltip: '删除配置',
                  color: const Color(0xFFef4444),
                  onTap: () => _confirmDelete(context, config),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(config.description, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey[600], height: 1.5)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, KeyConfig config) {
    final bloc = context.read<KeyBindingBloc>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(MdiIcons.alertCircleOutline, color: const Color(0xFFef4444), size: 24),
            const SizedBox(width: 10),
            const Text('确认删除', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text('确定要删除配置 "${config.name}" 吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              bloc.add(KeyBindingDeleteConfig(config.id));
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFef4444)),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _KeyBindSection extends StatelessWidget {
  final List<KeyPlaceholder> placeholders;
  final Map<String, String> bindings;
  const _KeyBindSection({required this.placeholders, required this.bindings});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('按键绑定', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1a1a2e))),
            const Spacer(),
            if (bindings.values.any((v) => v.isNotEmpty))
              TextButton.icon(
                onPressed: () => context.read<KeyBindingBloc>().add(KeyBindingClearAllKeyBindings()),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('清除', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: isDark ? Colors.white54 : Colors.grey[600]),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: placeholders.map((p) => SizedBox(
            width: 200,
            child: KeySelector(
              label: p.label,
              selectedKey: bindings[p.label],
              onKeySelected: (k) => context.read<KeyBindingBloc>().add(KeyBindingSetKeyBinding(label: p.label, key: k)),
              onClear: () => context.read<KeyBindingBloc>().add(KeyBindingClearKeyBinding(p.label)),
            ),
          )).toList(),
        ),
      ],
    );
  }
}

class _ScriptPreview extends StatelessWidget {
  final String script;
  const _ScriptPreview({required this.script});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('脚本预览', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1a1a2e))),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1e1e2e),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SelectableText(
            script,
            style: const TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono, monospace', color: Color(0xFFcdd6f4), height: 1.6),
          ),
        ),
      ],
    );
  }
}

class _DetailFooter extends StatelessWidget {
  final KeyConfig config;
  final bool allBound;
  final bool applied;
  final bool saving;
  final Map<String, String> bindings;

  const _DetailFooter({
    required this.config,
    required this.allBound,
    required this.applied,
    required this.saving,
    required this.bindings,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.grey[50],
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          if (!allBound && !applied)
            Row(
              children: [
                Icon(MdiIcons.alertCircleOutline, size: 16, color: const Color(0xFFf59e0b)),
                const SizedBox(width: 6),
                const Text('请完成按键绑定', style: TextStyle(fontSize: 12, color: Color(0xFFf59e0b))),
              ],
            ),
          if (applied)
            Row(
              children: [
                Icon(MdiIcons.checkCircle, size: 16, color: const Color(0xFF10b981)),
                const SizedBox(width: 6),
                const Text('已应用到本地配置', style: TextStyle(fontSize: 12, color: Color(0xFF10b981))),
              ],
            ),
          const Spacer(),
          // 取消应用按钮（仅已应用时显示）
          if (applied) ...[
            OutlinedButton.icon(
              onPressed: saving
                  ? null
                  : () => context.read<KeyBindingBloc>().add(KeyBindingRemoveAppliedConfig(config.configId)),
              icon: Icon(MdiIcons.closeCircleOutline, size: 16, color: saving ? Colors.grey : const Color(0xFFef4444)),
              label: Text('取消应用', style: TextStyle(color: saving ? Colors.grey : const Color(0xFFef4444))),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: saving ? Colors.grey[300]! : const Color(0xFFef4444).withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 10),
          ],
          FilledButton.icon(
            onPressed: (allBound && !saving)
                ? () => context.read<KeyBindingBloc>().add(KeyBindingApplyConfig(config: config, keyBindings: bindings))
                : null,
            icon: saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(applied ? Icons.refresh : Icons.check, size: 18),
            label: Text(saving ? '应用中' : (applied ? '重新应用' : '应用配置')),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0080FF),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Autoexec 视图
// ============================================================================
class _AutoexecView extends StatefulWidget {
  @override
  State<_AutoexecView> createState() => _AutoexecViewState();
}

class _AutoexecViewState extends State<_AutoexecView> {
  final _editCtrl = TextEditingController();
  bool _editMode = false;
  bool _changed = false;

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KeyBindingBloc, KeyBindingState>(
      listener: (context, state) {
        if (state.autoexecContent != null && !_changed) {
          _editCtrl.text = state.autoexecContent!;
        }
      },
      builder: (context, state) {
        if (!state.hasGamePath) {
          return _EmptyHint(
            icon: MdiIcons.folderAlertOutline,
            title: '游戏路径未配置',
            desc: '请先在设置中配置 CS2 游戏路径',
            iconColor: const Color(0xFFf59e0b),
          );
        }
        if (!state.autoexecFileExists) {
          return _EmptyHint(
            icon: MdiIcons.fileDocumentPlusOutline,
            title: '文件不存在',
            desc: 'autoexec.cfg 尚未创建',
            action: FilledButton.icon(
              onPressed: state.isSaving ? null : () => context.read<KeyBindingBloc>().add(KeyBindingCreateAutoexecFile()),
              icon: state.isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add, size: 18),
              label: Text(state.isSaving ? '创建中' : '创建文件'),
            ),
          );
        }
        return Column(
          children: [
            _buildHeader(context, state),
            Expanded(child: _editMode ? _buildEditor(state) : _buildAppliedList(context, state)),
            if (_changed) _buildSaveBar(context, state),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, KeyBindingState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey[200]!))),
      child: Row(
        children: [
          Icon(MdiIcons.fileCodeOutline, size: 20, color: const Color(0xFF0080FF)),
          const SizedBox(width: 8),
          Text('autoexec.cfg', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1a1a2e))),
          const Spacer(),
          _SegmentedBtn(
            items: const ['已应用', '编辑'],
            selected: _editMode ? 1 : 0,
            onChanged: (i) => setState(() => _editMode = i == 1),
          ),
          const SizedBox(width: 12),
          _IconButton(icon: Icons.copy_rounded, onTap: () => context.read<KeyBindingBloc>().add(KeyBindingCopyAutoexecContent())),
          _IconButton(icon: MdiIcons.folderOpenOutline, onTap: () => context.read<KeyBindingBloc>().add(KeyBindingOpenInExplorer())),
          _IconButton(
            icon: Icons.refresh_rounded,
            loading: state.isLoadingAutoexec,
            onTap: () => context.read<KeyBindingBloc>().add(KeyBindingLoadAutoexecContent()),
          ),
        ],
      ),
    );
  }

  Widget _buildAppliedList(BuildContext context, KeyBindingState state) {
    if (state.appliedConfigs.isEmpty) {
      return _EmptyHint(icon: MdiIcons.playlistRemove, title: '暂无已应用配置', desc: '选择配置并点击应用');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.appliedConfigs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _AppliedCard(
        config: state.appliedConfigs[i],
        onRemove: () => _confirmRemove(context, state.appliedConfigs[i]),
      ),
    );
  }

  Widget _buildEditor(KeyBindingState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_editCtrl.text.isEmpty && state.autoexecContent != null) {
      _editCtrl.text = state.autoexecContent!;
    }
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF475569) : Colors.grey[200]!),
      ),
      child: TextField(
        controller: _editCtrl,
        maxLines: null,
        expands: true,
        style: TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono, monospace', color: isDark ? const Color(0xFFcdd6f4) : const Color(0xFF374151), height: 1.6),
        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(14)),
        onChanged: (v) => setState(() => _changed = v != context.read<KeyBindingBloc>().state.autoexecContent),
      ),
    );
  }

  Widget _buildSaveBar(BuildContext context, KeyBindingState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : Colors.grey[50], border: Border(top: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey[200]!))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => setState(() {
              _editCtrl.text = state.autoexecContent ?? '';
              _changed = false;
            }),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: state.isSaving ? null : () {
              context.read<KeyBindingBloc>().add(KeyBindingSaveAutoexecContent(_editCtrl.text));
              setState(() => _changed = false);
            },
            icon: state.isSaving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, size: 16),
            label: Text(state.isSaving ? '保存中' : '保存'),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, ConfigBlock cfg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除配置 "${cfg.displayName}"？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<KeyBindingBloc>().add(KeyBindingRemoveAppliedConfig(cfg.configId));
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFef4444)),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _AppliedCard extends StatefulWidget {
  final ConfigBlock config;
  final VoidCallback onRemove;
  const _AppliedCard({required this.config, required this.onRemove});

  @override
  State<_AppliedCard> createState() => _AppliedCardState();
}

class _AppliedCardState extends State<_AppliedCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF475569) : Colors.grey[200]!),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(MdiIcons.checkCircle, size: 18, color: const Color(0xFF10b981)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(widget.config.displayName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : const Color(0xFF1a1a2e)))),
                  if (widget.config.keyBindings.isNotEmpty)
                    _Badge(label: widget.config.keyBindings.values.join(' / '), color: const Color(0xFF0080FF)),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: isDark ? Colors.white38 : Colors.grey[400]),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: widget.onRemove,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline, size: 18, color: Colors.red[300]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF1e1e2e), borderRadius: BorderRadius.circular(8)),
              child: SelectableText(
                widget.config.content,
                style: const TextStyle(fontSize: 11, fontFamily: 'JetBrains Mono, monospace', color: Color(0xFFcdd6f4), height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 发布视图 - 卡片式布局
// ============================================================================
class _PublishView extends StatefulWidget {
  @override
  State<_PublishView> createState() => _PublishViewState();
}

class _PublishViewState extends State<_PublishView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _scriptCtrl = TextEditingController();
  String? _category;
  bool _needsKey = false;

  /// 发布所需的最低积分
  static const int _minCreditsRequired = 500;

  @override
  void initState() {
    super.initState();
    // 刷新用户积分
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUserCredits();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _scriptCtrl.dispose();
    super.dispose();
  }

  /// 刷新用户积分
  void _refreshUserCredits() {
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated) {
      context.read<AuthBloc>().add(const AuthRefreshRequested());
    }
  }

  /// 检查积分是否足够
  bool _checkCredits() {
    final authState = context.read<AuthBloc>().state;
    final userInfo = authState.userInfo;
    if (userInfo == null) return false;
    
    final credits = int.tryParse(userInfo.credits ?? '0') ?? 0;
    if (credits < _minCreditsRequired) {
      _showCreditsPrompt(credits);
      return false;
    }
    return true;
  }

  /// 显示积分不足提示
  void _showCreditsPrompt(int currentCredits) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : null,
        title: Row(
          children: [
            Icon(MdiIcons.starCircleOutline, color: const Color(0xFFf59e0b), size: 24),
            const SizedBox(width: 10),
            Text('积分不足', style: TextStyle(fontSize: 16, color: isDark ? Colors.white : null)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('发布配置需要 $_minCreditsRequired 论坛积分', style: TextStyle(color: isDark ? Colors.white70 : null)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('您当前积分：', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600])),
                Text('$currentCredits', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFef4444))),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '积分可通过论坛发帖、回复等方式获取',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (!authState.isAuthenticated) {
          return _buildLoginPrompt();
        }
        return _buildPublishForm(context, authState);
      },
    );
  }

  Widget _buildLoginPrompt() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF0080FF).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(MdiIcons.accountLockOutline, size: 32, color: const Color(0xFF0080FF)),
          ),
          const SizedBox(height: 16),
          Text('登录后发布配置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1a1a2e))),
          const SizedBox(height: 6),
          Text('分享你的配置给其他玩家', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[500])),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => LoginDialog.show(context),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('去登录'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0080FF),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishForm(BuildContext context, AuthState authState) {
    // 获取用户积分
    final credits = int.tryParse(authState.userInfo?.credits ?? '0') ?? 0;
    final hasEnoughCredits = credits >= _minCreditsRequired;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return BlocBuilder<KeyBindingBloc, KeyBindingState>(
      builder: (context, state) {
        final placeholders = KeyPlaceholderParser.parse(_scriptCtrl.text);
        
        return Column(
          children: [
            // 头部
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF0080FF).withValues(alpha: 0.06), isDark ? const Color(0xFF1E293B) : Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0080FF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(MdiIcons.rocketLaunchOutline, size: 18, color: const Color(0xFF0080FF)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('发布新配置', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1a1a2e))),
                      Text('分享给社区', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF6b7280))),
                    ],
                  ),
                ],
              ),
            ),
            // 表单
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 名称和描述
                      _buildInput('配置名称', '给配置起个名字', _nameCtrl),
                      const SizedBox(height: 12),
                      _buildInput('配置描述', '简单描述功能', _descCtrl, maxLines: 2),
                      const SizedBox(height: 16),
                      // 分类选择
                      Text('选择分类', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.grey[600])),
                      const SizedBox(height: 8),
                      _buildCategoryChips(state.categories),
                      const SizedBox(height: 16),
                      // 类型选择
                      Text('配置类型', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.grey[600])),
                      const SizedBox(height: 8),
                      _buildTypeSelector(),
                      const SizedBox(height: 16),
                      // 脚本编辑
                      Row(
                        children: [
                          Text('配置脚本', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.grey[600])),
                          if (_needsKey) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFf59e0b).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '需要按键绑定',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFFf59e0b)),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (_needsKey) _buildInsertBtn(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildScriptEditor(),
                      if (_needsKey && placeholders.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildPlaceholderTags(placeholders),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // 底部
            _buildBottomBar(state, hasEnoughCredits),
          ],
        );
      },
    );
  }

  Widget _buildInput(String label, String hint, TextEditingController ctrl, {int maxLines = 1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.grey[600])),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1a1a2e)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey[400]),
            filled: true,
            fillColor: isDark ? const Color(0xFF334155) : Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey[200]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey[200]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0080FF))),
          ),
          validator: (v) => v?.trim().isEmpty == true ? '必填' : null,
        ),
      ],
    );
  }

  Widget _buildCategoryChips(List<String> categories) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((c) {
        final sel = _category == c;
        return _HoverChip(
          label: c,
          selected: sel,
          onTap: () => setState(() => _category = c),
        );
      }).toList(),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(child: _HoverTypeOption(icon: MdiIcons.autoFix, title: '自动应用', selected: !_needsKey, onTap: () => setState(() => _needsKey = false))),
        const SizedBox(width: 10),
        Expanded(child: _HoverTypeOption(icon: MdiIcons.keyboardOutline, title: '按键绑定', selected: _needsKey, onTap: () => setState(() => _needsKey = true))),
      ],
    );
  }

  Widget _buildInsertBtn() {
    return FilledButton.icon(
      onPressed: _insertPlaceholder,
      icon: Icon(MdiIcons.keyboardOutline, size: 16),
      label: const Text('插入按键绑定', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0080FF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildScriptEditor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF334155) : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF475569) : Colors.grey[200]!),
          ),
          child: TextFormField(
            controller: _scriptCtrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: isDark ? const Color(0xFFcdd6f4) : const Color(0xFF374151), height: 1.5),
            decoration: InputDecoration(
              hintText: _needsKey ? '输入脚本，使用 {{KEY:名称}} 插入按键占位符' : '输入脚本...',
              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400], fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v?.trim().isEmpty == true) return '必填';
              if (_needsKey && !KeyPlaceholderParser.hasPlaceholders(v!)) return '需包含按键占位符';
              return null;
            },
          ),
        ),
        if (_needsKey) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0080FF).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF0080FF).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 14, color: const Color(0xFF0080FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '点击右上角"插入按键绑定"按钮，为需要用户自定义的按键添加绑定点',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey[700], height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlaceholderTags(List<KeyPlaceholder> placeholders) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(MdiIcons.keyboardOutline, size: 12, color: const Color(0xFFf59e0b)),
            const SizedBox(width: 6),
            Text('已添加的按键占位符', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.grey[600])),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: placeholders.map((p) => _PlaceholderTag(
            label: p.label,
            onRemove: () { _scriptCtrl.text = _scriptCtrl.text.replaceAll('{{KEY:${p.label}}}', ''); setState(() {}); },
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomBar(KeyBindingState state, bool hasEnoughCredits) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 检查表单完整性
    final hasName = _nameCtrl.text.trim().isNotEmpty;
    final hasDesc = _descCtrl.text.trim().isNotEmpty;
    final hasScript = _scriptCtrl.text.trim().isNotEmpty;
    final hasCategory = _category != null;
    
    // 生成提示信息
    String? hint;
    if (!hasEnoughCredits) {
      hint = '积分不足，无法发布';
    } else if (!hasName) {
      hint = '请输入配置名称';
    } else if (!hasDesc) {
      hint = '请输入配置描述';
    } else if (!hasCategory) {
      hint = '请选择分类';
    } else if (!hasScript) {
      hint = '请输入配置脚本';
    } else if (_needsKey && !KeyPlaceholderParser.hasPlaceholders(_scriptCtrl.text)) {
      hint = '按键绑定类型需要包含占位符';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : Colors.grey[50], border: Border(top: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey[200]!))),
      child: Row(
        children: [
          if (hint != null)
            Row(
              children: [
                Icon(
                  !hasEnoughCredits ? MdiIcons.alertCircleOutline : Icons.info_outline, 
                  size: 14, 
                  color: !hasEnoughCredits ? const Color(0xFFef4444) : (isDark ? Colors.white38 : Colors.grey[500]),
                ),
                const SizedBox(width: 6),
                Text(
                  hint, 
                  style: TextStyle(
                    fontSize: 11, 
                    color: !hasEnoughCredits ? const Color(0xFFef4444) : (isDark ? Colors.white38 : Colors.grey[500]),
                  ),
                ),
              ],
            ),
          const Spacer(),
          TextButton(onPressed: _clear, child: const Text('清空', style: TextStyle(fontSize: 12))),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: (state.isPublishing || hint != null) ? null : _submit,
            icon: state.isPublishing
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(MdiIcons.rocketLaunchOutline, size: 14, color: Colors.white),
            label: Text(state.isPublishing ? '发布中' : '发布', style: const TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0080FF), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
          ),
        ],
      ),
    );
  }

  void _insertPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0080FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(MdiIcons.keyboardOutline, size: 18, color: const Color(0xFF0080FF)),
            ),
            const SizedBox(width: 10),
            Text('插入按键绑定', style: TextStyle(fontSize: 15, color: isDark ? Colors.white : null)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '为这个按键起个名字，用户在使用时需要绑定具体的键位',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : null),
              decoration: InputDecoration(
                labelText: '按键名称',
                hintText: '例如：买雷',
                helperText: '将在脚本中插入 {{KEY:按键名称}}',
                helperStyle: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey[500]),
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey[300]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey[300]!)),
                prefixIcon: Icon(MdiIcons.tagOutline, size: 18),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  _doInsert(v.trim());
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton.icon(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                _doInsert(ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            icon: const Icon(Icons.check, size: 16),
            label: const Text('插入'),
          ),
        ],
      ),
    );
  }

  void _doInsert(String label) {
    final ph = ' {{KEY:$label}} '; // 直接前后加空格
    final text = _scriptCtrl.text;
    final sel = _scriptCtrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    
    final newText = text.replaceRange(start, end, ph);
    final newCursorPos = start + ph.length;
    
    _scriptCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
    setState(() {});
  }

  void _clear() {
    _nameCtrl.clear();
    _descCtrl.clear();
    _scriptCtrl.clear();
    setState(() { _category = null; _needsKey = false; });
  }

  void _submit() {
    // 再次检查积分（防止状态变化）
    if (!_checkCredits()) return;
    
    if (_formKey.currentState?.validate() == true && _category != null) {
      // 生成 configId：使用时间戳 + 随机数确保唯一性
      final configId = 'cfg_${DateTime.now().millisecondsSinceEpoch}_${_nameCtrl.text.trim().hashCode.abs()}';
      
      context.read<KeyBindingBloc>().add(KeyBindingPublishConfig(KeyConfigCreateRequest(
        configId: configId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category!,
        config: _scriptCtrl.text,
        needsKeybind: _needsKey,
      )));
      _clear();
    }
  }
}

// ============================================================================
// 编辑视图 - 面板式布局（类似发布视图）
// ============================================================================
class _EditView extends StatefulWidget {
  final KeyConfig config;
  final VoidCallback? onComplete;

  const _EditView({required this.config, this.onComplete});

  @override
  State<_EditView> createState() => _EditViewState();
}

class _EditViewState extends State<_EditView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _scriptCtrl;
  String? _category;
  late bool _needsKey;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.config.name);
    _descCtrl = TextEditingController(text: widget.config.description);
    _scriptCtrl = TextEditingController(text: widget.config.config);
    _category = widget.config.category;
    _needsKey = widget.config.needsKeybind;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _scriptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<KeyBindingBloc, KeyBindingState>(
      builder: (context, state) {
        final placeholders = KeyPlaceholderParser.parse(_scriptCtrl.text);
        
        return Column(
          children: [
            // 头部
            _buildHeader(),
            // 审核拒绝原因提示
            if (widget.config.isRejected && widget.config.auditRemark.isNotEmpty)
              _buildRejectionNotice(),
            // 表单
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 名称和描述
                      _buildInput('配置名称', '给配置起个名字', _nameCtrl),
                      const SizedBox(height: 12),
                      _buildInput('配置描述', '简单描述功能', _descCtrl, maxLines: 2),
                      const SizedBox(height: 16),
                      // 分类选择
                      Text('选择分类', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.grey[600])),
                      const SizedBox(height: 8),
                      _buildCategoryChips(state.categories),
                      const SizedBox(height: 16),
                      // 类型选择
                      Text('配置类型', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.grey[600])),
                      const SizedBox(height: 8),
                      _buildTypeSelector(),
                      const SizedBox(height: 16),
                      // 脚本编辑
                      Row(
                        children: [
                          Text('配置脚本', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.grey[600])),
                          if (_needsKey) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFf59e0b).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '需要按键绑定',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFFf59e0b)),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (_needsKey) _buildInsertBtn(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildScriptEditor(),
                      if (_needsKey && placeholders.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildPlaceholderTags(placeholders),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // 底部
            _buildBottomBar(state),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF8b5cf6).withValues(alpha: 0.06), isDark ? const Color(0xFF1E293B) : Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8b5cf6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(MdiIcons.pencilOutline, size: 18, color: const Color(0xFF8b5cf6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('编辑配置', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1a1a2e))),
                Text('修改 "${widget.config.name}"', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF6b7280))),
              ],
            ),
          ),
          // 关闭按钮
          _ConfigActionButton(
            icon: Icons.close,
            tooltip: '取消编辑',
            onTap: () => widget.onComplete?.call(),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionNotice() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(MdiIcons.alertCircleOutline, size: 16, color: const Color(0xFFEF4444)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('审核未通过', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                const SizedBox(height: 2),
                Text(
                  widget.config.auditRemark,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey[700], height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, String hint, TextEditingController ctrl, {int maxLines = 1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.grey[600])),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1a1a2e)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey[400]),
            filled: true,
            fillColor: isDark ? const Color(0xFF334155) : Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey[200]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey[200]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0080FF))),
          ),
          validator: (v) => v?.trim().isEmpty == true ? '必填' : null,
        ),
      ],
    );
  }

  Widget _buildCategoryChips(List<String> categories) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((c) {
        final sel = _category == c;
        return _HoverChip(
          label: c,
          selected: sel,
          onTap: () => setState(() => _category = c),
        );
      }).toList(),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(child: _HoverTypeOption(icon: MdiIcons.autoFix, title: '自动应用', selected: !_needsKey, onTap: () => setState(() => _needsKey = false))),
        const SizedBox(width: 10),
        Expanded(child: _HoverTypeOption(icon: MdiIcons.keyboardOutline, title: '按键绑定', selected: _needsKey, onTap: () => setState(() => _needsKey = true))),
      ],
    );
  }

  Widget _buildInsertBtn() {
    return FilledButton.icon(
      onPressed: _insertPlaceholder,
      icon: Icon(MdiIcons.keyboardOutline, size: 16),
      label: const Text('插入按键绑定', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0080FF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildScriptEditor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF334155) : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF475569) : Colors.grey[200]!),
          ),
          child: TextFormField(
            controller: _scriptCtrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: isDark ? const Color(0xFFcdd6f4) : const Color(0xFF374151), height: 1.5),
            decoration: InputDecoration(
              hintText: _needsKey ? '输入脚本，使用 {{KEY:名称}} 插入按键占位符' : '输入脚本...',
              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400], fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v?.trim().isEmpty == true) return '必填';
              if (_needsKey && !KeyPlaceholderParser.hasPlaceholders(v!)) return '需包含按键占位符';
              return null;
            },
          ),
        ),
        if (_needsKey) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0080FF).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF0080FF).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 14, color: const Color(0xFF0080FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '点击右上角"插入按键绑定"按钮，为需要用户自定义的按键添加绑定点',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey[700], height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlaceholderTags(List<KeyPlaceholder> placeholders) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(MdiIcons.keyboardOutline, size: 12, color: const Color(0xFFf59e0b)),
            const SizedBox(width: 6),
            Text('已添加的按键占位符', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.grey[600])),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: placeholders.map((p) => _PlaceholderTag(
            label: p.label,
            onRemove: () { _scriptCtrl.text = _scriptCtrl.text.replaceAll('{{KEY:${p.label}}}', ''); setState(() {}); },
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomBar(KeyBindingState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 检查表单完整性
    final hasName = _nameCtrl.text.trim().isNotEmpty;
    final hasDesc = _descCtrl.text.trim().isNotEmpty;
    final hasScript = _scriptCtrl.text.trim().isNotEmpty;
    final hasCategory = _category != null;
    
    // 生成提示信息
    String? hint;
    if (!hasName) {
      hint = '请输入配置名称';
    } else if (!hasDesc) {
      hint = '请输入配置描述';
    } else if (!hasCategory) {
      hint = '请选择分类';
    } else if (!hasScript) {
      hint = '请输入配置脚本';
    } else if (_needsKey && !KeyPlaceholderParser.hasPlaceholders(_scriptCtrl.text)) {
      hint = '按键绑定类型需要包含占位符';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : Colors.grey[50], border: Border(top: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey[200]!))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 重新审核提示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(MdiIcons.informationOutline, size: 14, color: const Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                Text(
                  '修改后需要重新审核',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309)),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (hint != null)
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: isDark ? Colors.white38 : Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(hint, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey[500])),
                  ],
                ),
              const Spacer(),
              TextButton(
                onPressed: () => widget.onComplete?.call(),
                child: const Text('取消', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: (state.isSaving || hint != null) ? null : _submit,
                icon: state.isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(MdiIcons.contentSaveOutline, size: 14, color: Colors.white),
                label: Text(state.isSaving ? '保存中' : '保存修改', style: const TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8b5cf6), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _insertPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0080FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(MdiIcons.keyboardOutline, size: 18, color: const Color(0xFF0080FF)),
            ),
            const SizedBox(width: 10),
            Text('插入按键绑定', style: TextStyle(fontSize: 15, color: isDark ? Colors.white : null)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '为这个按键起个名字，用户在使用时需要绑定具体的键位',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : null),
              decoration: InputDecoration(
                labelText: '按键名称',
                hintText: '例如：买雷',
                helperText: '将在脚本中插入 {{KEY:按键名称}}',
                helperStyle: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey[500]),
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey[300]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey[300]!)),
                prefixIcon: Icon(MdiIcons.tagOutline, size: 18),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  _doInsert(v.trim());
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton.icon(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                _doInsert(ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            icon: const Icon(Icons.check, size: 16),
            label: const Text('插入'),
          ),
        ],
      ),
    );
  }

  void _doInsert(String label) {
    final ph = ' {{KEY:$label}} '; // 直接前后加空格
    final text = _scriptCtrl.text;
    final sel = _scriptCtrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    
    final newText = text.replaceRange(start, end, ph);
    final newCursorPos = start + ph.length;
    
    _scriptCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
    setState(() {});
  }

  void _submit() {
    if (_formKey.currentState?.validate() == true && _category != null) {
      context.read<KeyBindingBloc>().add(KeyBindingUpdateConfig(
        id: widget.config.id,
        request: KeyConfigCreateRequest(
          configId: widget.config.configId,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          category: _category!,
          config: _scriptCtrl.text,
          needsKeybind: _needsKey,
        ),
      ));
    }
  }
}

// ============================================================================
// 通用组件
// ============================================================================

/// 配置卡片
class _ConfigCard extends StatefulWidget {
  final KeyConfig config;
  final bool selected;
  final bool applied;
  final VoidCallback onTap;

  const _ConfigCard({required this.config, required this.selected, required this.applied, required this.onTap});

  @override
  State<_ConfigCard> createState() => _ConfigCardState();
}

class _ConfigCardState extends State<_ConfigCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    // 判断是否是当前用户创建的配置
    final backendUserInfo = TokenService.instance.userInfo;
    final isOwner = backendUserInfo != null && backendUserInfo.id == widget.config.userID;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFF0080FF).withValues(alpha: 0.06)
                : (_hovered ? (isDark ? const Color(0xFF334155) : Colors.grey[50]) : (isDark ? const Color(0xFF1E293B) : Colors.white)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected ? const Color(0xFF0080FF) : (_hovered ? (isDark ? const Color(0xFF475569) : Colors.grey[300]!) : (isDark ? const Color(0xFF334155) : Colors.grey[200]!)),
              width: widget.selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 图标
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.config.needsKeybind
                          ? const Color(0xFFf59e0b).withValues(alpha: 0.1)
                          : const Color(0xFF10b981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.config.needsKeybind ? MdiIcons.keyboardOutline : MdiIcons.autoFix,
                      size: 18,
                      color: widget.config.needsKeybind ? const Color(0xFFf59e0b) : const Color(0xFF10b981),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 内容
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.config.name,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1a1a2e)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isOwner)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(left: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8b5cf6).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('我的', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF8b5cf6))),
                              ),
                            // 审核状态标签
                            if (widget.config.isPending)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(left: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('待审核', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B))),
                              ),
                            if (widget.config.isRejected)
                              Tooltip(
                                message: widget.config.auditRemark.isNotEmpty
                                    ? '拒绝原因: ${widget.config.auditRemark}'
                                    : '已拒绝',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(left: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('已拒绝', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                                ),
                              ),
                            if (widget.applied)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(left: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10b981).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('已应用', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF10b981))),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.config.description,
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey[500]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // 底部：用户信息
              const SizedBox(height: 8),
              Row(
                children: [
                  // 用户头像
                  if (widget.config.userAvatar != null && widget.config.userAvatar!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        widget.config.userAvatar!,
                        width: 20,
                        height: 20,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                      ),
                    )
                  else
                    _buildDefaultAvatar(),
                  const SizedBox(width: 6),
                  // 用户名
                  Expanded(
                    child: Text(
                      widget.config.userNickname ?? '未知用户',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 投票数
                  _buildVoteCount(widget.config.upCount, widget.config.downCount),
                  const SizedBox(width: 8),
                  // 分类标签
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0080FF).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.config.category,
                      style: const TextStyle(fontSize: 9, color: Color(0xFF0080FF)),
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

  Widget _buildVoteCount(int upCount, int downCount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 点赞数
        Icon(MdiIcons.thumbUpOutline, size: 12, color: const Color(0xFF10b981)),
        const SizedBox(width: 2),
        Text(
          '$upCount',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF10b981)),
        ),
        const SizedBox(width: 6),
        // 点踩数
        Icon(MdiIcons.thumbDownOutline, size: 12, color: const Color(0xFFef4444)),
        const SizedBox(width: 2),
        Text(
          '$downCount',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFFef4444)),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.person, size: 12, color: Colors.grey[400]),
    );
  }
}

/// 搜索框
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1a1a2e)),
      decoration: InputDecoration(
        hintText: '搜索...',
        hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey[400]),
        prefixIcon: Icon(Icons.search, size: 18, color: isDark ? Colors.white38 : Colors.grey[400]),
        filled: true,
        fillColor: isDark ? const Color(0xFF334155) : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      ),
      onChanged: (v) => context.read<KeyBindingBloc>().add(KeyBindingSetSearchKeyword(v.isEmpty ? null : v)),
    );
  }
}

/// 分类下拉
class _CategoryDropdown extends StatefulWidget {
  @override
  State<_CategoryDropdown> createState() => _CategoryDropdownState();
}

class _CategoryDropdownState extends State<_CategoryDropdown> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<KeyBindingBloc, KeyBindingState>(
      builder: (context, state) {
        return MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          cursor: SystemMouseCursors.click,
          child: PopupMenuButton<String?>(
            initialValue: state.categoryFilter,
            onSelected: (v) => context.read<KeyBindingBloc>().add(KeyBindingSetCategoryFilter(v)),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('全部')),
              ...state.categories.map((c) => PopupMenuItem(value: c, child: Text(c))),
            ],
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _hovered 
                    ? (isDark ? const Color(0xFF475569) : Colors.grey[200]) 
                    : (isDark ? const Color(0xFF334155) : Colors.grey[100]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.categoryFilter ?? '全部', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey[700])),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 18, color: isDark ? Colors.white54 : Colors.grey[600]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 工具栏按钮
class _ToolbarBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool badge;
  final VoidCallback onTap;

  const _ToolbarBtn({required this.icon, required this.label, required this.active, this.badge = false, required this.onTap});

  @override
  State<_ToolbarBtn> createState() => _ToolbarBtnState();
}

class _ToolbarBtnState extends State<_ToolbarBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) {
        if (!widget.active) {
          setState(() => _hovered = true);
        }
      },
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.active
                ? const Color(0xFF0080FF)
                : (_hovered ? (isDark ? const Color(0xFF334155) : Colors.grey[100]) : Colors.transparent),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: widget.active ? Colors.white : (isDark ? Colors.white70 : Colors.grey[600])),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: widget.active ? Colors.white : (isDark ? Colors.white70 : Colors.grey[700]),
                ),
              ),
              if (widget.badge) ...[
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Color(0xFFf59e0b), shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 图标按钮
class _IconButton extends StatefulWidget {
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  const _IconButton({required this.icon, this.loading = false, this.onTap});

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(_IconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading && !oldWidget.loading) {
      _rotationController.repeat();
    } else if (!widget.loading && oldWidget.loading) {
      _rotationController.stop();
      _rotationController.reset();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.loading ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: _hovered && !widget.loading 
                ? (isDark ? const Color(0xFF334155) : Colors.grey[100]) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: widget.loading
                ? RotationTransition(
                    turns: _rotationController,
                    child: Icon(widget.icon, size: 18, color: const Color(0xFF0080FF)),
                  )
                : Icon(widget.icon, size: 18, color: isDark ? Colors.white54 : Colors.grey[600]),
          ),
        ),
      ),
    );
  }
}

/// 分段按钮
class _SegmentedBtn extends StatefulWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onChanged;

  const _SegmentedBtn({required this.items, required this.selected, required this.onChanged});

  @override
  State<_SegmentedBtn> createState() => _SegmentedBtnState();
}

class _SegmentedBtnState extends State<_SegmentedBtn> {
  int _hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 30,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : Colors.grey[200], borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.items.length, (i) => MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = i),
          onExit: (_) => setState(() => _hoveredIndex = -1),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => widget.onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.selected == i 
                    ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                    : (_hoveredIndex == i ? (isDark ? const Color(0xFF475569) : Colors.grey[300]) : Colors.transparent),
                borderRadius: BorderRadius.circular(6),
                boxShadow: widget.selected == i ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)] : null,
              ),
              child: Text(widget.items[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: widget.selected == i ? const Color(0xFF0080FF) : (isDark ? Colors.white54 : Colors.grey[600]))),
            ),
          ),
        )),
      ),
    );
  }
}

/// 徽章
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const _Badge({required this.label, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: filled ? Colors.white : color)),
    );
  }
}

/// 空状态提示
class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? desc;
  final Color? iconColor;
  final Widget? action;

  const _EmptyHint({required this.icon, required this.title, this.desc, this.iconColor, this.action});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: iconColor ?? (isDark ? Colors.white24 : Colors.grey[300])),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey[700])),
            if (desc != null) ...[
              const SizedBox(height: 6),
              Text(desc!, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[500]), textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// 带 hover 效果的分类 Chip
class _HoverChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HoverChip({required this.label, required this.selected, required this.onTap});

  @override
  State<_HoverChip> createState() => _HoverChipState();
}

class _HoverChipState extends State<_HoverChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.selected 
                ? const Color(0xFF0080FF) 
                : (_hovered ? (isDark ? const Color(0xFF475569) : Colors.grey[200]) : (isDark ? const Color(0xFF334155) : Colors.grey[100])),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.selected 
                  ? const Color(0xFF0080FF) 
                  : (_hovered ? (isDark ? const Color(0xFF64748B) : Colors.grey[300]!) : Colors.transparent),
            ),
          ),
          child: Text(
            widget.label, 
            style: TextStyle(
              fontSize: 11, 
              fontWeight: FontWeight.w500, 
              color: widget.selected ? Colors.white : (isDark ? Colors.white70 : Colors.grey[700]),
            ),
          ),
        ),
      ),
    );
  }
}

/// 带 hover 效果的类型选项
class _HoverTypeOption extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _HoverTypeOption({required this.icon, required this.title, required this.selected, required this.onTap});

  @override
  State<_HoverTypeOption> createState() => _HoverTypeOptionState();
}

class _HoverTypeOptionState extends State<_HoverTypeOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.selected 
                ? const Color(0xFF0080FF).withValues(alpha: 0.06) 
                : (_hovered ? (isDark ? const Color(0xFF334155) : Colors.grey[100]) : (isDark ? const Color(0xFF1E293B) : Colors.grey[50])),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected 
                  ? const Color(0xFF0080FF) 
                  : (_hovered ? (isDark ? const Color(0xFF475569) : Colors.grey[300]!) : (isDark ? const Color(0xFF334155) : Colors.grey[200]!)), 
              width: widget.selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: widget.selected ? const Color(0xFF0080FF) : (isDark ? Colors.white54 : Colors.grey[500])),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title, 
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.w500, 
                    color: widget.selected ? const Color(0xFF0080FF) : (isDark ? Colors.white70 : Colors.grey[700]),
                  ),
                ),
              ),
              if (widget.selected) const Icon(Icons.check_circle, size: 16, color: Color(0xFF0080FF)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 带 hover 效果的占位符标签
class _PlaceholderTag extends StatefulWidget {
  final String label;
  final VoidCallback onRemove;

  const _PlaceholderTag({required this.label, required this.onRemove});

  @override
  State<_PlaceholderTag> createState() => _PlaceholderTagState();
}

class _PlaceholderTagState extends State<_PlaceholderTag> {
  bool _hovered = false;
  bool _closeHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _hovered 
              ? const Color(0xFFf59e0b).withValues(alpha: 0.2) 
              : const Color(0xFFf59e0b).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFf59e0b).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(MdiIcons.keyboardOutline, size: 10, color: const Color(0xFFf59e0b)),
            const SizedBox(width: 4),
            Text(widget.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFFd97706))),
            const SizedBox(width: 4),
            MouseRegion(
              onEnter: (_) => setState(() => _closeHovered = true),
              onExit: (_) => setState(() => _closeHovered = false),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onRemove,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _closeHovered ? const Color(0xFFf59e0b).withValues(alpha: 0.3) : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Icon(Icons.close, size: 10, color: Color(0xFFf59e0b)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// 配置操作按钮（编辑/删除）
class _ConfigActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback onTap;

  const _ConfigActionButton({
    required this.icon,
    required this.tooltip,
    this.color,
    required this.onTap,
  });

  @override
  State<_ConfigActionButton> createState() => _ConfigActionButtonState();
}

class _ConfigActionButtonState extends State<_ConfigActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Colors.grey[600]!;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hovered ? color.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: 18, color: _hovered ? color : Colors.grey[500]),
          ),
        ),
      ),
    );
  }
}



/// 详情页投票按钮组
class _DetailVoteButtons extends StatelessWidget {
  final KeyConfig config;
  final bool isOwner;

  const _DetailVoteButtons({required this.config, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final upCount = config.upCount;
    final downCount = config.downCount;
    final voteType = config.voteTypeEnum;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 点赞按钮 + 数量
          _VoteButton(
            icon: voteType == KeyConfigVoteType.up
                ? MdiIcons.thumbUp
                : MdiIcons.thumbUpOutline,
            isActive: voteType == KeyConfigVoteType.up,
            onTap: () => _handleVote(context, KeyConfigVoteType.up),
          ),
          const SizedBox(width: 2),
          Text(
            '$upCount',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: voteType == KeyConfigVoteType.up
                  ? const Color(0xFF10b981)
                  : (isDark ? Colors.white54 : Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 10),
          // 点踩按钮 + 数量（自己的配置不能踩）
          _VoteButton(
            icon: voteType == KeyConfigVoteType.down
                ? MdiIcons.thumbDown
                : MdiIcons.thumbDownOutline,
            isActive: voteType == KeyConfigVoteType.down,
            isDownVote: true,
            disabled: isOwner,
            onTap: isOwner ? null : () => _handleVote(context, KeyConfigVoteType.down),
          ),
          const SizedBox(width: 2),
          Text(
            '$downCount',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: voteType == KeyConfigVoteType.down
                  ? const Color(0xFFef4444)
                  : (isOwner ? (isDark ? Colors.white24 : Colors.grey[400]) : (isDark ? Colors.white54 : Colors.grey[600])),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  void _handleVote(BuildContext context, KeyConfigVoteType voteType) {
    // 检查登录状态
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) {
      _showLoginPrompt(context);
      return;
    }
    
    // 发送投票事件
    context.read<KeyBindingBloc>().add(KeyBindingVote(
      configId: config.id,
      voteType: voteType,
    ));
  }

  void _showLoginPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(MdiIcons.accountLockOutline, color: const Color(0xFF0080FF), size: 24),
            const SizedBox(width: 10),
            const Text('需要登录', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Text('登录后才能进行投票'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              LoginDialog.show(context);
            },
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }
}

/// 单个投票按钮（使用 Material + InkWell，自动管理 hover 状态）
class _VoteButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final bool isDownVote;
  final bool disabled;
  final VoidCallback? onTap;

  const _VoteButton({
    required this.icon,
    required this.isActive,
    this.isDownVote = false,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor =
        isDownVote ? const Color(0xFFef4444) : const Color(0xFF10b981);
    final bgColor = Colors.grey[200]!;
    final normalColor = Colors.grey[500]!;
    final disabledColor = Colors.grey[300]!;

    return Tooltip(
      message: disabled
          ? '不能对自己的配置投反对票'
          : (isDownVote ? '反对' : '赞成'),
      child: Material(
        color: isActive ? activeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          hoverColor: disabled ? Colors.transparent : bgColor,
          mouseCursor:
              disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 14,
              color: disabled
                  ? disabledColor
                  : (isActive ? Colors.white : normalColor),
            ),
          ),
        ),
      ),
    );
  }
}
