import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../../../core/bloc/key_binding/key_binding_event.dart';
import '../../../../core/bloc/key_binding/key_binding_state.dart';
import '../../../../core/models/key_config_models.dart';
import '../../../../core/utils/key_placeholder_parser.dart';
import '../components/common_widgets.dart' as common;
import '../components/vote_widgets.dart';
import '../key_selector.dart';
import 'comments_view.dart';
import '../../../../core/constants/app_colors.dart';

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
        final allBound =
            !cfg.needsKeybind ||
            placeholders.isEmpty ||
            KeyPlaceholderParser.validate(cfg.config, state.keyBindings);
        final applied = state.isConfigApplied(cfg.configId);
        final showAuditStatusBar = !cfg.isApproved;

        return Column(
          children: [
            DetailHeader(
              config: cfg,
              applied: applied,
              onEditConfig: onEditConfig,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showAuditStatusBar)
                      AuditStatusBanner(
                        config: cfg,
                        onEditConfig: onEditConfig,
                      ),
                    if (showAuditStatusBar) const SizedBox(height: 20),
                    if (cfg.needsKeybind && placeholders.isNotEmpty)
                      KeyBindSection(
                        placeholders: placeholders,
                        bindings: state.keyBindings,
                      ),
                    if (cfg.needsKeybind && placeholders.isNotEmpty)
                      const SizedBox(height: 20),
                    ScriptPreview(
                      script: KeyPlaceholderParser.replace(
                        cfg.config,
                        state.keyBindings,
                      ),
                    ),
                    // 已通过的配置显示评论区
                    if (cfg.isApproved) ...[
                      const SizedBox(height: 20),
                      ConfigCommentsView(
                        key: ValueKey('comments_${cfg.id}'),
                        config: cfg,
                      ),
                    ],
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
    final isOwner = config.isOwner;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 已通过的配置也可以编辑/删除，但需要填写理由并经过后台审核
    final canEdit = isOwner;
    final canDelete = isOwner;

    return BlocBuilder<KeyBindingBloc, KeyBindingState>(
      buildWhen: (prev, curr) =>
          prev.isCancellingChangeRequest != curr.isCancellingChangeRequest,
      builder: (context, state) {
        final hasPending =
            config.isApproved && isOwner && config.hasPendingChange;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.06),
                isDark ? AppColors.slate800 : Colors.white,
              ],
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
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      config.needsKeybind
                          ? MdiIcons.keyboardOutline
                          : MdiIcons.codeJson,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1a1a2e),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            common.Badge(
                              label: config.category,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            common.Badge(
                              label: config.needsKeybind ? '需绑定' : '自动',
                              color: config.needsKeybind
                                  ? AppColors.amber500
                                  : AppColors.emerald500,
                            ),
                            if (applied) ...[
                              const SizedBox(width: 6),
                              common.Badge(
                                label: '已应用',
                                color: AppColors.emerald500,
                                filled: true,
                              ),
                            ],
                            if (isOwner) ...[
                              const SizedBox(width: 6),
                              common.Badge(
                                label: '我的',
                                color: AppColors.violet500,
                                filled: true,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  DetailVoteButtons(config: config, isOwner: config.isOwner),
                  const SizedBox(width: 8),
                  if (hasPending) ...[
                    _PendingChangeActions(
                      configId: config.id,
                      isDark: isDark,
                      isCancelling: state.isCancellingChangeRequest,
                    ),
                  ] else ...[
                    if (canEdit) ...[
                      common.ConfigActionButton(
                        icon: MdiIcons.pencilOutline,
                        tooltip: config.isApproved ? '编辑配置（需重新审核）' : '编辑配置',
                        badge: config.isApproved,
                        onTap: () => onEditConfig?.call(config),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (canDelete)
                      common.ConfigActionButton(
                        icon: MdiIcons.deleteOutline,
                        tooltip: config.isApproved ? '删除配置（需重新审核）' : '删除配置',
                        color: AppColors.red500,
                        badge: config.isApproved,
                        onTap: () => _confirmDelete(context, config),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                config.description,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : AppColors.gray500,
                ),
              ),
              // 显示应用次数和评论数
              if (config.isApproved) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      MdiIcons.downloadOutline,
                      size: 14,
                      color: isDark ? Colors.white38 : AppColors.gray400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${config.useCount} 次应用',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : AppColors.gray400,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      MdiIcons.commentOutline,
                      size: 14,
                      color: isDark ? Colors.white38 : AppColors.gray400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${config.commentCount} 条评论',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : AppColors.gray400,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, KeyConfig config) {
    final bloc = context.read<KeyBindingBloc>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 已通过的配置需要填写删除理由
    if (config.isApproved) {
      final reasonCtrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: isDark ? AppColors.slate800 : null,
          title: Row(
            children: [
              Icon(
                MdiIcons.alertCircleOutline,
                color: AppColors.red500,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                '删除配置',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : null,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '确定要删除配置 "${config.name}" 吗？删除后不可恢复!!!',
                style: TextStyle(color: isDark ? Colors.white70 : null),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                style: TextStyle(color: isDark ? Colors.white : null),
                decoration: InputDecoration(
                  labelText: '删除理由',
                  hintText: '请说明删除原因...',
                  filled: true,
                  fillColor: isDark ? AppColors.slate700 : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.slate600 : Colors.grey[300]!,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                bloc.add(
                  KeyBindingDeleteConfig(
                    config.id,
                    editReason: reasonCtrl.text.trim(),
                  ),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.red500),
              child: const Text('删除'),
            ),
          ],
        ),
      );
    } else {
      // 未通过或待审核的配置直接删除
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(
                MdiIcons.alertCircleOutline,
                color: AppColors.red500,
                size: 24,
              ),
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
              style: FilledButton.styleFrom(backgroundColor: AppColors.red500),
              child: const Text('删除'),
            ),
          ],
        ),
      );
    }
  }
}

/// 待审核变更申请操作区
class _PendingChangeActions extends StatelessWidget {
  final int configId;
  final bool isDark;
  final bool isCancelling;

  const _PendingChangeActions({
    required this.configId,
    required this.isDark,
    required this.isCancelling,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '变更申请审核中',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.amber500.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.amber500.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(MdiIcons.clockOutline, size: 13, color: AppColors.amber500),
            const SizedBox(width: 6),
            const Text(
              '审核中',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.amber500,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 7),
              width: 1,
              height: 11,
              color: AppColors.red500.withValues(alpha: 0.5),
            ),
            GestureDetector(
              onTap: isCancelling ? null : () => _confirmCancel(context),
              child: MouseRegion(
                cursor: isCancelling
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.click,
                child: isCancelling
                    ? const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.amber500,
                        ),
                      )
                    : const Text(
                        '撤销',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.red500,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.red500,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    final bloc = context.read<KeyBindingBloc>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDark ? AppColors.slate800 : null,
        title: Row(
          children: [
            Icon(Icons.undo_rounded, color: Colors.grey[600], size: 22),
            const SizedBox(width: 10),
            Text(
              '撤销变更申请',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white : null,
              ),
            ),
          ],
        ),
        content: Text(
          '确定要撤销此变更申请吗？撤销后可以重新发起申请。',
          style: TextStyle(color: isDark ? Colors.white70 : null),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              bloc.add(KeyBindingCancelChangeRequest(configId));
            },
            child: const Text('确认撤销'),
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

  const AuditStatusBanner({super.key, required this.config, this.onEditConfig});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPending = config.isPending;
    final statusColor = isPending ? AppColors.amber500 : AppColors.red500;
    final statusIcon = isPending
        ? MdiIcons.clockOutline
        : MdiIcons.alertCircleOutline;
    final statusText = isPending ? '审核中' : '审核失败';
    final statusMessage = isPending
        ? '等待管理员审核'
        : (config.auditRemark.isNotEmpty ? config.auditRemark : '未通过审核');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
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
                    color: isDark ? Colors.white70 : AppColors.gray700,
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
            Text(
              '按键绑定',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1a1a2e),
              ),
            ),
            const Spacer(),
            if (bindings.values.any((v) => v.isNotEmpty))
              TextButton.icon(
                onPressed: () => context.read<KeyBindingBloc>().add(
                  KeyBindingClearAllKeyBindings(),
                ),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('清除', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: placeholders
              .map(
                (p) => SizedBox(
                  width: 200,
                  child: KeySelector(
                    label: p.label,
                    selectedKey: bindings[p.label],
                    onKeySelected: (k) => context.read<KeyBindingBloc>().add(
                      KeyBindingSetKeyBinding(label: p.label, key: k),
                    ),
                    onClear: () => context.read<KeyBindingBloc>().add(
                      KeyBindingClearKeyBinding(p.label),
                    ),
                  ),
                ),
              )
              .toList(),
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
        Text(
          '脚本预览',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1a1a2e),
          ),
        ),
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
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'JetBrains Mono, monospace',
              color: Color(0xFFcdd6f4),
              height: 1.6,
            ),
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
    const double fixedHeight = 44.0; // 统一高度

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
        children: [
          if (!allBound && !applied)
            Expanded(
              child: Container(
                height: fixedHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.amber500.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.amber500.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      MdiIcons.alertCircleOutline,
                      size: 18,
                      color: AppColors.amber500,
                    ),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        '请完成按键绑定后再应用配置',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.amber500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (applied)
            Expanded(
              child: Container(
                height: fixedHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.emerald500.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.emerald500.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      MdiIcons.checkCircle,
                      size: 18,
                      color: AppColors.emerald500,
                    ),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        '已应用到本地配置文件',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.emerald500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 当没有提示信息时，用 Spacer 把按钮推到右边
          if (allBound && !applied) const Spacer(),
          if (!allBound || applied) const SizedBox(width: 12),
          if (applied) ...[
            SizedBox(
              height: fixedHeight,
              child: OutlinedButton.icon(
                onPressed: saving
                    ? null
                    : () => context.read<KeyBindingBloc>().add(
                        KeyBindingRemoveAppliedConfig(config.configId),
                      ),
                icon: Icon(
                  MdiIcons.closeCircleOutline,
                  size: 16,
                  color: saving ? Colors.grey : AppColors.red500,
                ),
                label: Text(
                  '取消应用',
                  style: TextStyle(
                    color: saving ? Colors.grey : AppColors.red500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: saving
                        ? Colors.grey[300]!
                        : AppColors.red500.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          SizedBox(
            height: fixedHeight,
            child: FilledButton.icon(
              onPressed: (allBound && !saving)
                  ? () => context.read<KeyBindingBloc>().add(
                      KeyBindingApplyConfig(
                        config: config,
                        keyBindings: bindings,
                      ),
                    )
                  : null,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(applied ? Icons.refresh : Icons.check, size: 18),
              label: Text(saving ? '应用中' : (applied ? '重新应用' : '应用配置')),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
