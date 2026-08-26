import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../../../core/bloc/key_binding/key_binding_event.dart';
import '../../../../core/bloc/key_binding/key_binding_state.dart';
import '../../../../core/models/key_config_models.dart';
import '../../../../core/utils/key_placeholder_parser.dart';
import '../components/form_widgets.dart';
import '../components/floating_stepper.dart';
import '../components/section_card.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/rich_text_editor.dart';
import '../../../../core/services/quill_delta_codec.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// 编辑视图
class EditView extends StatefulWidget {
  final KeyConfig config;
  final VoidCallback? onComplete;

  const EditView({super.key, required this.config, this.onComplete});

  @override
  State<EditView> createState() => _EditViewState();
}

class _EditViewState extends State<EditView> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _section1Key = GlobalKey();
  final _section2Key = GlobalKey();
  final _section3Key = GlobalKey();
  final _section4Key = GlobalKey();
  late TextEditingController _nameCtrl;
  late QuillController _descCtrl;
  late RichScriptEditingController _scriptCtrl;
  late TextEditingController _editReasonCtrl;
  int? _categoryId;

  late String _originalName;
  late String _originalDesc;
  late String _originalScript;
  late int _originalCategoryId;
  int _activeStepIndex = 0;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.config.name);
    final decodedDoc = QuillDeltaCodec.decode(widget.config.description);
    _descCtrl = RichTextEditor.createController(document: decodedDoc);
    _scriptCtrl = RichScriptEditingController(text: widget.config.config);
    _editReasonCtrl = TextEditingController();
    _categoryId = widget.config.categoryId;

    _originalName = widget.config.name;
    _originalDesc = widget.config.description;
    _originalScript = widget.config.config;
    _originalCategoryId = widget.config.categoryId;

    _nameCtrl.addListener(() => setState(() {}));
    _descCtrl.addListener(() => setState(() {}));
    _scriptCtrl.addListener(() => setState(() {}));
    _editReasonCtrl.addListener(() => setState(() {}));
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;

    int newIndex = 0;
    if (maxScroll > 0 && offset >= maxScroll - 20) {
      newIndex = widget.config.isApproved ? 3 : 2;
    } else if (widget.config.isApproved && offset > 800) {
      newIndex = 3;
    } else if (offset > 500) {
      newIndex = 2;
    } else if (offset > 200) {
      newIndex = 1;
    }

    if (newIndex != _activeStepIndex) {
      setState(() => _activeStepIndex = newIndex);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _scriptCtrl.dispose();
    _editReasonCtrl.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool get _hasChanges {
    return _nameCtrl.text.trim() != _originalName ||
        _descCtrl.document.toPlainText().trim() !=
            QuillDeltaCodec.decode(_originalDesc).toPlainText().trim() ||
        _scriptCtrl.text != _originalScript ||
        _categoryId != _originalCategoryId;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KeyBindingBloc, KeyBindingState>(
      listenWhen: (previous, current) => previous.isSaving && !current.isSaving,
      listener: (context, state) {
        if (state.error == null) {
          if (widget.onComplete != null) {
            widget.onComplete!();
          } else {
            Navigator.of(context).pop();
          }
        }
      },
      builder: (context, state) {
        final hasName = _nameCtrl.text.trim().isNotEmpty;
        final hasDesc = _descCtrl.document.toPlainText().trim().isNotEmpty;
        final hasScript = _scriptCtrl.text.trim().isNotEmpty;
        final hasCategory = _categoryId != null;
        final hasEditReason =
            !widget.config.isApproved || _editReasonCtrl.text.trim().isNotEmpty;

        return Column(
          children: [
            if (widget.config.isRejected &&
                widget.config.auditRemark.isNotEmpty)
              _buildRejectionNotice(),
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 200),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionCard(
                            cardKey: _section1Key,
                            icon: MdiIcons.informationOutline,
                            iconColor: AppColors.violet500,
                            title: '1. 基本信息',
                            subtitle: '修改配置的名称和描述。',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ConfigFormInput(
                                  label: '配置名称',
                                  hint: '给配置起个名字',
                                  controller: _nameCtrl,
                                  maxLength: 10,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),
                                const SectionLabel('配置描述'),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 240,
                                  child: RichTextEditor(
                                    controller: _descCtrl,
                                    maxLength: 200,
                                    maxImages: 0, // 禁止上传图片
                                    hintText: '简单描述配置的用途和功能...',
                                    compactMode: true,
                                    draftId: null,
                                    enableDraftManualSave: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SectionCard(
                            cardKey: _section2Key,
                            icon: MdiIcons.shapeOutline,
                            iconColor: AppColors.violet500,
                            title: '2. 选择分类',
                            subtitle: '选择最适合这个配置的分类。',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CategoryChips(
                                  categories: state.categories,
                                  selectedId: _categoryId,
                                  onSelected: (id) =>
                                      setState(() => _categoryId = id),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SectionCard(
                            cardKey: _section3Key,
                            icon: MdiIcons.codeJson,
                            iconColor: AppColors.violet500,
                            title: '3. 脚本编辑',
                            subtitle:
                                '修改配置代码。如果需要让多个按键联动（绑定同一按键），只需将它们的按键名称设为一致即可，用户设置一处会自动同步所有同名按键。',
                            titleBadges: [
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.amber500.withValues(
                                    alpha: 0.1,
                                  ),
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
                            headerTrailing: InsertPlaceholderButton(
                              onPressed: () =>
                                  PlaceholderInsertHelper.showInsertDialog(
                                    context,
                                    scriptController: _scriptCtrl,
                                    onInserted: () => setState(() {}),
                                  ),
                            ),
                            child: ScriptEditor(
                              controller: _scriptCtrl,
                              needsKey: true,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),

                          // 已通过的配置编辑时需要填写理由
                          if (widget.config.isApproved) ...[
                            const SizedBox(height: 24),
                            SectionCard(
                              cardKey: _section4Key,
                              icon: MdiIcons.messageAlertOutline,
                              iconColor: AppColors.violet500,
                              title: '4. 修改理由',
                              subtitle: '已通过审核的配置，修改后将重新进入审核流程。',
                              child: _buildEditReasonInput(),
                            ),
                          ],
                        ], // closes children
                      ), // closes Column
                    ), // closes Form
                  ), // closes SingleChildScrollView
                  DraggableFloatingStepper(
                    child: FloatingStepper(
                      activeIndex: _activeStepIndex,
                      steps: [
                        '基本信息',
                        '分类选择',
                        '脚本编辑',
                        if (widget.config.isApproved) '修改理由',
                      ],
                      completedSteps: [
                        hasName && hasDesc,
                        hasCategory,
                        hasScript,
                        if (widget.config.isApproved) hasEditReason,
                      ],
                      onStepTapped: (index) {
                        if (index == 0) _scrollToSection(_section1Key);
                        if (index == 1) _scrollToSection(_section2Key);
                        if (index == 2) _scrollToSection(_section3Key);
                        if (index == 3 && widget.config.isApproved) {
                          _scrollToSection(_section4Key);
                        }
                      },
                    ),
                  ),
                ], // closes Stack children
              ), // closes Stack
            ), // closes Expanded
            _buildBottomBar(state),
          ], // closes Column children
        ); // closes Column
      },
    );
  }

  Widget _buildRejectionNotice() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.red500.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red500.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(MdiIcons.alertCircleOutline, size: 20, color: AppColors.red500),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '审核未通过',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.red500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.config.auditRemark,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                    height: 1.5,
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
    final needsEditReason =
        widget.config.isApproved && _editReasonCtrl.text.trim().isEmpty;
    const double fixedHeight = 48.0;

    String? hint;
    Color? hintColor;
    IconData? hintIcon;

    if (!hasChanges) {
      hint = '没有修改内容';
      hintColor = AppColors.emerald500;
      hintIcon = MdiIcons.checkCircleOutline;
    } else if (needsEditReason) {
      hint = '请填写修改理由';
      hintColor = AppColors.amber500;
      hintIcon = MdiIcons.informationOutline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (hint != null && hintColor != null && hintIcon != null)
            Expanded(
              child: Container(
                height: fixedHeight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: hintColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: hintColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(hintIcon, size: 20, color: hintColor),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        hint,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
          const SizedBox(width: 16),
          SizedBox(
            height: fixedHeight,
            child: TextButton(
              onPressed: () => widget.onComplete?.call(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: Text(
                '取消',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: fixedHeight,
            child: FilledButton.icon(
              onPressed: (state.isSaving || hint != null) ? null : _submit,
              icon: state.isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      MdiIcons.contentSaveOutline,
                      size: 18,
                      color: Colors.white,
                    ),
              label: Text(
                state.isSaving ? '保存中...' : '保存修改',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.violet500,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
            description: QuillDeltaCodec.encode(_descCtrl.document),
            categoryId: _categoryId!,
            config: _scriptCtrl.text,
            needsKeybind: KeyPlaceholderParser.hasPlaceholders(
              _scriptCtrl.text,
            ),
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
        TextFormField(
          controller: _editReasonCtrl,
          maxLines: 2,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF1a1a2e),
          ),
          decoration: InputDecoration(
            hintText: '请说明修改原因，例如：修复按键冲突、优化脚本逻辑...',
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
            filled: true,
            fillColor: isDark ? AppColors.slate700 : Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
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
