import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../../../core/bloc/key_binding/key_binding_event.dart';
import '../../../../core/bloc/key_binding/key_binding_state.dart';
import '../../../../core/models/key_config_models.dart';
import '../../../../core/services/token_service.dart';
import '../../../../core/utils/key_placeholder_parser.dart';
import '../components/common_widgets.dart' as common;
import '../components/vote_widgets.dart';
import '../key_selector.dart';

/// 配置详情视图
class ConfigDetailView extends StatelessWidget {
  final void Function(KeyConfig config)? onEditConfig;
  
  const ConfigDetailView({super.key, this.onEditConfig});
  
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KeyBindingBloc, KeyBindingState>(
      builder: (context, state) {
        final cfg = state.selectedConfig;
        if (cfg == null) {
          return common.EmptyHint(
            icon: MdiIcons.gesture,
            title: '选择一个配置',
            desc: '从左侧列表点击配置查看详情并应用',
          );
        }
        final placeholders = KeyPlaceholderParser.parse(cfg.config);
        final allBound = !cfg.needsKeybind || placeholders.isEmpty ||
            KeyPlaceholderParser.validate(cfg.config, state.keyBindings);
        final applied = state.isConfigApplied(cfg.configId);
        final showAuditStatusBar = !cfg.isApproved;

        return Column(
          children: [
            DetailHeader(config: cfg, applied: applied, onEditConfig: onEditConfig),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showAuditStatusBar)
                      AuditStatusBanner(config: cfg, onEditConfig: onEditConfig),
                    if (showAuditStatusBar) const SizedBox(height: 20),
                    if (cfg.needsKeybind && placeholders.isNotEmpty)
                      KeyBindSection(placeholders: placeholders, bindings: state.keyBindings),
                    if (cfg.needsKeybind && placeholders.isNotEmpty) const SizedBox(height: 20),
                    ScriptPreview(script: KeyPlaceholderParser.replace(cfg.config, state.keyBindings)),
                  ],
                ),
              ),
            ),
            DetailFooter(
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

class DetailHeader extends StatelessWidget {
  final KeyConfig config;
  final bool applied;
  final void Function(KeyConfig config)? onEditConfig;
  
  const DetailHeader({
    super.key,
    required this.config,
    required this.applied,
    this.onEditConfig,
  });

  @override
  Widget build(BuildContext context) {
    final backendUserInfo = TokenService.instance.userInfo;
    final isOwner = backendUserInfo != null && backendUserInfo.id == config.userID;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final canEdit = isOwner && config.isRejected;
    final canDelete = isOwner && !config.isPending;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0080FF).withValues(alpha: 0.06), isDark ? const Color(0xFF1E293B) : Colors.white],
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0080FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  config.needsKeybind ? MdiIcons.keyboardOutline : MdiIcons.codeJson,
                  color: const Color(0xFF0080FF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(config.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1a1a2e))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        common.Badge(label: config.category, color: const Color(0xFF0080FF)),
                        const SizedBox(width: 6),
                        common.Badge(
                          label: config.needsKeybind ? '需绑定' : '自动',
                          color: config.needsKeybind ? const Color(0xFFf59e0b) : const Color(0xFF10b981),
                        ),
                        if (applied) ...[
                          const SizedBox(width: 6),
                          common.Badge(label: '已应用', color: const Color(0xFF10b981), filled: true),
                        ],
                        if (isOwner) ...[
                          const SizedBox(width: 6),
                          common.Badge(label: '我的', color: const Color(0xFF8b5cf6), filled: true),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              DetailVoteButtons(config: config, isOwner: config.isOwner),
              const SizedBox(width: 8),
              if (canEdit) ...[
                common.ConfigActionButton(
                  icon: MdiIcons.pencilOutline,
                  tooltip: '编辑配置',
                  onTap: () => onEditConfig?.call(config),
                ),
                const SizedBox(width: 4),
              ],
              if (canDelete)
                common.ConfigActionButton(
                  icon: MdiIcons.deleteOutline,
                  tooltip: '删除配置',
                  color: const Color(0xFFef4444),
                  onTap: () => _confirmDelete(context, config),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(config.description, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF6b7280))),
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

/// 审核状态横幅
class AuditStatusBanner extends StatelessWidget {
  final KeyConfig config;
  final void Function(KeyConfig config)? onEditConfig;

  const AuditStatusBanner({
    super.key,
    required this.config,
    this.onEditConfig,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPending = config.isPending;
    final statusColor = isPending ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    final statusIcon = isPending ? MdiIcons.clockOutline : MdiIcons.alertCircleOutline;
    final statusText = isPending ? '审核中' : '审核失败';
    final statusMessage = isPending
        ? '等待管理员审核'
        : (config.auditRemark.isNotEmpty ? config.auditRemark : '未通过审核');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 20, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class KeyBindSection extends StatelessWidget {
  final List<KeyPlaceholder> placeholders;
  final Map<String, String> bindings;
  
  const KeyBindSection({
    super.key,
    required this.placeholders,
    required this.bindings,
  });

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

class ScriptPreview extends StatelessWidget {
  final String script;
  
  const ScriptPreview({super.key, required this.script});

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

class DetailFooter extends StatelessWidget {
  final KeyConfig config;
  final bool allBound;
  final bool applied;
  final bool saving;
  final Map<String, String> bindings;

  const DetailFooter({
    super.key,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.grey[50],
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          if (!allBound && !applied)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFf59e0b).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFf59e0b).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(MdiIcons.alertCircleOutline, size: 18, color: const Color(0xFFf59e0b)),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        '请完成按键绑定后再应用配置',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFf59e0b)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (applied)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10b981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10b981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(MdiIcons.checkCircle, size: 18, color: const Color(0xFF10b981)),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        '已应用到本地配置文件',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF10b981)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!allBound || applied) const SizedBox(width: 12),
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
