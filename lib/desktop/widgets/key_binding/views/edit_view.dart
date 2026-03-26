import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../../../core/bloc/key_binding/key_binding_event.dart';
import '../../../../core/bloc/key_binding/key_binding_state.dart';
import '../../../../core/models/key_config_models.dart';
import '../../../../core/utils/key_placeholder_parser.dart';
import '../components/common_widgets.dart';

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
                      _buildInput('配置名称', '给配置起个名字', _nameCtrl),
                      const SizedBox(height: 12),
                      _buildInput('配置描述', '简单描述功能', _descCtrl, maxLines: 2),
                      const SizedBox(height: 16),
                      // 分类选择
                      Text(
                        '选择分类',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white54
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildCategoryChips(state.categories),
                      const SizedBox(height: 16),
                      // 类型选择
                      Text(
                        '配置类型',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white54
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTypeSelector(),
                      const SizedBox(height: 16),
                      // 脚本编辑
                      Row(
                        children: [
                          Text(
                            '配置脚本',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white54
                                  : Colors.grey[600],
                            ),
                          ),
                          if (_needsKey) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFf59e0b,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '需要按键绑定',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFf59e0b),
                                ),
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

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8b5cf6).withValues(alpha: 0.06),
            isDark ? const Color(0xFF1E293B) : Colors.white,
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
              color: const Color(0xFF8b5cf6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              MdiIcons.pencilOutline,
              size: 18,
              color: const Color(0xFF8b5cf6),
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
                    color: isDark ? Colors.white54 : const Color(0xFF6b7280),
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
        color: const Color(0xFFEF4444).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            MdiIcons.alertCircleOutline,
            size: 16,
            color: const Color(0xFFEF4444),
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
                    color: Color(0xFFEF4444),
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

  Widget _buildInput(
    String label,
    String hint,
    TextEditingController ctrl, {
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF1a1a2e),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF334155) : Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF475569) : Colors.grey[200]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF475569) : Colors.grey[200]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0080FF)),
            ),
          ),
          onChanged: (_) => setState(() {}),
          validator: (v) => v?.trim().isEmpty == true ? '必填' : null,
        ),
      ],
    );
  }

  Widget _buildCategoryChips(List<KeyConfigCategory> categories) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((c) {
        final sel = _categoryId == c.id;
        return HoverChip(
          label: c.name,
          selected: sel,
          onTap: () => setState(() => _categoryId = c.id),
        );
      }).toList(),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: HoverTypeOption(
            icon: MdiIcons.autoFix,
            title: '自动应用',
            subtitle: '直接生效，无需选择按键',
            selected: !_needsKey,
            onTap: () => setState(() => _needsKey = false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: HoverTypeOption(
            icon: MdiIcons.keyboardOutline,
            title: '按键绑定',
            subtitle: '需要用户选择绑定按键',
            selected: _needsKey,
            onTap: () => setState(() => _needsKey = true),
          ),
        ),
      ],
    );
  }

  Widget _buildInsertBtn() {
    return FilledButton.icon(
      onPressed: _insertPlaceholder,
      icon: Icon(MdiIcons.keyboardOutline, size: 16),
      label: const Text(
        '插入按键绑定',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
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
            border: Border.all(
              color: isDark ? const Color(0xFF475569) : Colors.grey[200]!,
            ),
          ),
          child: TextFormField(
            controller: _scriptCtrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: isDark ? const Color(0xFFcdd6f4) : const Color(0xFF374151),
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: _needsKey ? '输入脚本，使用 {{KEY:名称}} 插入按键占位符' : '输入脚本...',
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey[400],
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v?.trim().isEmpty == true) return '必填';
              if (_needsKey && !KeyPlaceholderParser.hasPlaceholders(v!)) {
                return '需包含按键占位符';
              }
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
              border: Border.all(
                color: const Color(0xFF0080FF).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 14,
                  color: const Color(0xFF0080FF),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '点击右上角按钮在脚本中插入按键绑定点，使用者可以自己选择按键',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                      height: 1.4,
                    ),
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
            Icon(
              MdiIcons.keyboardOutline,
              size: 12,
              color: const Color(0xFFf59e0b),
            ),
            const SizedBox(width: 6),
            Text(
              '已添加的按键占位符',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: placeholders
              .map(
                (p) => PlaceholderTag(
                  label: p.label,
                  onRemove: () {
                    _scriptCtrl.text = _scriptCtrl.text.replaceAll(
                      '{{KEY:${p.label}}}',
                      '',
                    );
                    setState(() {});
                  },
                ),
              )
              .toList(),
        ),
      ],
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
      hintColor = const Color(0xFF10b981);
      hintIcon = MdiIcons.checkCircleOutline;
    } else if (_needsKey && !hasPlaceholders) {
      hint = '请在脚本中插入按键绑定';
      hintColor = const Color(0xFFf59e0b);
      hintIcon = MdiIcons.informationOutline;
    } else if (needsEditReason) {
      hint = '请填写修改理由';
      hintColor = const Color(0xFFf59e0b);
      hintIcon = MdiIcons.informationOutline;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.grey[50],
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF475569) : Colors.grey[200]!,
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
                backgroundColor: const Color(0xFF8b5cf6),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
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
              child: Icon(
                MdiIcons.keyboardOutline,
                size: 18,
                color: const Color(0xFF0080FF),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '插入按键绑定',
              style: TextStyle(
                fontSize: 15,
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
              '给这个按键位置起个说明，使用者会根据这个说明选择按键',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : null),
              decoration: InputDecoration(
                labelText: '按键说明',
                hintText: '例如：触发键1、触发键2',
                helperText: '将在脚本中插入 {{KEY:按键说明}}',
                helperStyle: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.grey[500],
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF475569) : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF475569) : Colors.grey[300]!,
                  ),
                ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
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
    final ph = ' {{KEY:$label}} ';
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
            color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                MdiIcons.alertCircleOutline,
                size: 16,
                color: const Color(0xFFF59E0B),
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
            fillColor: isDark ? const Color(0xFF334155) : Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF475569) : Colors.grey[200]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF475569) : Colors.grey[200]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFF59E0B)),
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
