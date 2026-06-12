import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../../../core/bloc/key_binding/key_binding_event.dart';
import '../../../../core/bloc/key_binding/key_binding_state.dart';
import '../../../../core/models/key_config_models.dart';
import '../components/common_widgets.dart' as common;
import '../../../../core/constants/app_colors.dart';

/// Autoexec 视图
///
/// 包括：
/// - 已应用配置列表
/// - 编辑器模式
/// - 文件操作（创建、保存、打开文件夹、复制内容）
class AutoexecView extends StatefulWidget {
  const AutoexecView({super.key});

  @override
  State<AutoexecView> createState() => _AutoexecViewState();
}

class _AutoexecViewState extends State<AutoexecView> {
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
          return common.EmptyHint(
            icon: MdiIcons.folderAlertOutline,
            title: '游戏路径未配置',
            desc: '请先在设置中配置 CS2 游戏路径',
            iconColor: AppColors.amber500,
          );
        }

        if (!state.autoexecFileExists) {
          return common.EmptyHint(
            icon: MdiIcons.fileDocumentPlusOutline,
            title: '文件不存在',
            desc: 'autoexec.cfg 尚未创建',
            action: FilledButton.icon(
              onPressed: state.isSaving
                  ? null
                  : () => context.read<KeyBindingBloc>().add(
                      KeyBindingCreateAutoexecFile(),
                    ),
              icon: state.isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add, size: 18),
              label: Text(state.isSaving ? '创建中' : '创建文件'),
            ),
          );
        }

        return Column(
          children: [
            _buildHeader(context, state),
            Expanded(
              child: _editMode
                  ? _buildEditor(state)
                  : _buildAppliedList(context, state),
            ),
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
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.slate600 : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            MdiIcons.fileCodeOutline,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'autoexec.cfg',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1a1a2e),
            ),
          ),
          const Spacer(),
          common.SegmentedButton(
            items: const ['已应用', '编辑'],
            selected: _editMode ? 1 : 0,
            onChanged: (i) => setState(() => _editMode = i == 1),
          ),
          const SizedBox(width: 12),
          common.IconButton(
            icon: Icons.copy_rounded,
            onTap: () => context.read<KeyBindingBloc>().add(
              KeyBindingCopyAutoexecContent(),
            ),
          ),
          common.IconButton(
            icon: MdiIcons.folderOpenOutline,
            onTap: () =>
                context.read<KeyBindingBloc>().add(KeyBindingOpenInExplorer()),
          ),
          common.IconButton(
            icon: Icons.refresh_rounded,
            loading: state.isLoadingAutoexec,
            onTap: () => context.read<KeyBindingBloc>().add(
              KeyBindingLoadAutoexecContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppliedList(BuildContext context, KeyBindingState state) {
    if (state.appliedConfigs.isEmpty) {
      return common.EmptyHint(
        icon: MdiIcons.playlistRemove,
        title: '暂无已应用配置',
        desc: '选择配置并点击应用',
      );
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
        color: isDark ? AppColors.slate700 : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.slate600 : Colors.grey[200]!,
        ),
      ),
      child: TextField(
        controller: _editCtrl,
        maxLines: null,
        expands: true,
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'JetBrains Mono, monospace',
          color: isDark ? const Color(0xFFcdd6f4) : AppColors.gray700,
          height: 1.6,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(14),
        ),
        onChanged: (v) => setState(
          () => _changed =
              v != context.read<KeyBindingBloc>().state.autoexecContent,
        ),
      ),
    );
  }

  Widget _buildSaveBar(BuildContext context, KeyBindingState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate700 : Colors.grey[50],
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.slate600 : Colors.grey[200]!,
          ),
        ),
      ),
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
            onPressed: state.isSaving
                ? null
                : () {
                    context.read<KeyBindingBloc>().add(
                      KeyBindingSaveAutoexecContent(_editCtrl.text),
                    );
                    setState(() => _changed = false);
                  },
            icon: state.isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<KeyBindingBloc>().add(
                KeyBindingRemoveAppliedConfig(cfg.configId),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red500,
            ),
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
        color: isDark ? AppColors.slate700 : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.slate600 : Colors.grey[200]!,
        ),
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
                  Icon(
                    MdiIcons.checkCircle,
                    size: 18,
                    color: AppColors.emerald500,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.config.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF1a1a2e),
                      ),
                    ),
                  ),
                  if (widget.config.keyBindings.isNotEmpty)
                    common.Badge(
                      label: widget.config.keyBindings.values.join(' / '),
                      color: AppColors.primary,
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: widget.onRemove,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red[300],
                      ),
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
              decoration: BoxDecoration(
                color: const Color(0xFF1e1e2e),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                widget.config.content,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'JetBrains Mono, monospace',
                  color: Color(0xFFcdd6f4),
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
