import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../../../core/bloc/key_binding/key_binding_event.dart';
import '../../../../core/bloc/key_binding/key_binding_state.dart';
import '../../../../core/models/key_config_models.dart';
import '../../../../core/utils/key_placeholder_parser.dart';
import '../components/common_widgets.dart';
import '../components/form_widgets.dart';
import '../../../../core/constants/app_colors.dart';

/// 编辑视图
///
/// 包括：
/// - 编辑表单（与发布视图类似）
/// - 审核拒绝原因提示
/// - 变更检测
class EditView extends StatefulWidget {
  final KeyConfig config;
  final VoidCallback? onComplete;

  const EditView({super.key, required this.config, this.onComplete});

  @override
  State<EditView> createState() => _EditViewState();
}

class _EditViewState extends State<EditView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _scriptCtrl;
  late TextEditingController _editReasonCtrl;
  int? _categoryId;
  late bool _needsKey;

  late String _originalName;
  late String _originalDesc;
  late String _originalScript;
  late int _originalCategoryId;
  late bool _originalNeedsKey;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.config.name);
    _descCtrl = TextEditingController(text: widget.config.description);
    _scriptCtrl = TextEditingController(text: widget.config.config);
    _editReasonCtrl = TextEditingController();
    _categoryId = widget.config.categoryId;
    _needsKey = widget.config.needsKeybind;

    _originalName = widget.config.name;
    _originalDesc = widget.config.description;
    _originalScript = widget.config.config;
    _originalCategoryId = widget.config.categoryId;
    _originalNeedsKey = widget.config.needsKeybind;

    _nameCtrl.addListener(() => setState(() {}));
    _descCtrl.addListener(() => setState(() {}));
    _scriptCtrl.addListener(() => setState(() {}));
    _editReasonCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _scriptCtrl.dispose();
    _editReasonCtrl.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    return _nameCtrl.text.trim() != _originalName ||
        _descCtrl.text.trim() != _originalDesc ||
        _scriptCtrl.text != _originalScript ||
        _categoryId != _originalCategoryId ||
        _needsKey != _originalNeedsKey;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KeyBindingBloc, KeyBindingState>(
      builder: (context, state) {
        final placeholders = KeyPlaceholderParser.parse(_scriptCtrl.text);

        return Column(
          children: [
            _buildHeader(),
            if (widget.config.isRejected &&
                widget.config.auditRemark.isNotEmpty)
              _buildRejectionNotice(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConfigFormInput(
                        label: '配置名称',
                        hint: '给配置起个名字',
                        controller: _nameCtrl,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      ConfigFormInput(
                        label: '配置描述',
                        hint: '简单描述功能',
                        controller: _descCtrl,
                        maxLines: 2,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      // 分类选择
                      _buildSectionLabel('选择分类'),
                      const SizedBox(height: 8),
                      CategoryChips(
                        categories: state.categories,
                        selectedId: _categoryId,
                        onSelected: (id) => setState(() => _categoryId = id),
                      ),
                      const SizedBox(height: 16),
                      // 类型选择
                      _buildSectionLabel('配置类型'),
                      const SizedBox(height: 8),
                      ConfigTypeSelector(
                        needsKey: _needsKey,
                        onChanged: (v) => setState(() => _needsKey = v),
                      ),
                      const SizedBox(height: 16),
                      // 脚本编辑
                      _buildScriptHeader(),
                      const SizedBox(height: 8),
                      ScriptEditor(
                        controller: _scriptCtrl,
                        needsKey: _needsKey,
                        onChanged: (_) => setState(() {}),
                      ),
                      if (_needsKey && placeholders.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        PlaceholderTagList(
                          placeholders: placeholders,
                          scriptController: _scriptCtrl,
                          onChanged: () => setState(() {}),
                        ),
                      ],
                      // 已通过的配置编辑时需要填写理由
                      if (widget.config.isApproved) ...[
                        const SizedBox(height: 20),
                        _buildEditReasonInput(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomBar(state),
          ],
        );
      },
    );
  }

  Widget _buildSectionLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white54 : Colors.grey[600],
      ),
    );
  }

  Widget _buildScriptHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          '配置脚本',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.grey[600],
          ),
        ),
        if (_needsKey) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.amber500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '需要按键绑定',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.amber500,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (_needsKey)
          InsertPlaceholderButton(
            onPressed: () => PlaceholderInsertHelper.showInsertDialog(
              context,
              scriptController: _scriptCtrl,
              onInserted: () => setState(() {}),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.violet500.withValues(alpha: 0.06),
            isDark ? AppColors.slate800 : Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.violet500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              MdiIcons.pencilOutline,
              size: 18,
              color: AppColors.violet500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '编辑配置',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1a1a2e),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '修改 "${widget.config.name}"',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          ConfigActionButton(
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
        color: AppColors.red500.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.red500.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            MdiIcons.alertCircleOutline,
            size: 16,
            color: AppColors.red500,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '审核未通过',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.red500,
                  ),
                ),
                const SizedBox(height: 2),
                Tooltip(
                  message: widget.config.auditRemark,
                  waitDuration: const Duration(milliseconds: 500),
                  child: Text(
                    widget.config.auditRemark,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(KeyBindingState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasChanges = _hasChanges;
    final hasPlaceholders = KeyPlaceholderParser.hasPlaceholders(
      _scriptCtrl.text,
    );
    final needsEditReason =
        widget.config.isApproved && _editReasonCtrl.text.trim().isEmpty;
    const double fixedHeight = 44.0;

    String? hint;
    Color? hintColor;
    IconData? hintIcon;

    if (!hasChanges) {
      hint = '没有修改内容';
      hintColor = AppColors.emerald500;
      hintIcon = MdiIcons.checkCircleOutline;
    } else if (_needsKey && !hasPlaceholders) {
      hint = '请在脚本中插入按键绑定';
      hintColor = AppColors.amber500;
      hintIcon = MdiIcons.informationOutline;
    } else if (needsEditReason) {
      hint = '请填写修改理由';
      hintColor = AppColors.amber500;
      hintIcon = MdiIcons.informationOutline;
    }

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
          if (hint != null && hintColor != null && hintIcon != null)
            Expanded(
              child: Container(
                height: fixedHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: hintColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: hintColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(hintIcon, size: 18, color: hintColor),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        hint,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: hintColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 12),
          SizedBox(
            height: fixedHeight,
            child: TextButton(
              onPressed: () => widget.onComplete?.call(),
              child: const Text('取消', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: fixedHeight,
            child: FilledButton.icon(
              onPressed: (state.isSaving || hint != null) ? null : _submit,
              icon: state.isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      MdiIcons.contentSaveOutline,
                      size: 14,
                      color: Colors.white,
                    ),
              label: Text(
                state.isSaving ? '保存中' : '保存修改',
                style: const TextStyle(fontSize: 12),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.violet500,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() == true && _categoryId != null) {
      // 已通过的配置需要填写编辑理由
      if (widget.config.isApproved && _editReasonCtrl.text.trim().isEmpty) {
        return;
      }

      context.read<KeyBindingBloc>().add(
        KeyBindingUpdateConfig(
          id: widget.config.id,
          request: KeyConfigCreateRequest(
            configId: widget.config.configId,
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            categoryId: _categoryId!,
            config: _scriptCtrl.text,
            needsKeybind: _needsKey,
          ),
          editReason: widget.config.isApproved
              ? _editReasonCtrl.text.trim()
              : null,
        ),
      );
    }
  }

  Widget _buildEditReasonInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.amber500.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.amber500.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                MdiIcons.alertCircleOutline,
                size: 16,
                color: AppColors.amber500,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '此配置已通过审核，修改后将重新进入审核流程',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '修改理由（必填）',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _editReasonCtrl,
          maxLines: 2,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF1a1a2e),
          ),
          decoration: InputDecoration(
            hintText: '请说明修改原因，例如：修复按键冲突、优化脚本逻辑...',
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
            filled: true,
            fillColor: isDark ? AppColors.slate700 : Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? AppColors.slate600 : Colors.grey[200]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? AppColors.slate600 : Colors.grey[200]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.amber500),
            ),
          ),
          validator: (v) =>
              widget.config.isApproved && v?.trim().isEmpty == true
              ? '已通过的配置修改时必须填写理由'
              : null,
        ),
      ],
    );
  }
}
