import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/bloc/character_gallery/character_gallery_bloc.dart';
import '../../../core/bloc/character_gallery/character_gallery_event.dart';
import '../../../core/bloc/character_gallery/character_gallery_state.dart';
import '../../../core/models/character_models.dart';
import '../../../core/utils/toast_utils.dart';
import 'character_gallery_theme.dart';
// TODO: 视频上传功能暂时隐藏
// import 'video_upload_widget.dart';

/// Dialog 输入框组件
class DialogTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const DialogTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: scrollBrown,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(color: inkColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: inkColor.withValues(alpha: 0.4),
              fontSize: 13,
            ),
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: scrollBrown.withValues(alpha: 0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: scrollBrown.withValues(alpha: 0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                color: CharacterGalleryTheme.getVermillion(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 快捷编辑理由选择器
class EditReasonSelector extends StatefulWidget {
  final TextEditingController controller;
  final bool isRequired;
  final List<String>? customReasons; // 自定义快捷理由列表

  const EditReasonSelector({
    super.key,
    required this.controller,
    this.isRequired = false,
    this.customReasons,
  });

  @override
  State<EditReasonSelector> createState() => _EditReasonSelectorState();
}

class _EditReasonSelectorState extends State<EditReasonSelector> {
  String? _selectedReason;
  bool _useCustom = false;

  static const List<String> _defaultReasons = [
    '修正错误信息',
    '补充遗漏内容',
    '根据游戏更新调整',
    '优化描述表达',
  ];

  List<String> get _reasons => widget.customReasons ?? _defaultReasons;

  @override
  void initState() {
    super.initState();
    // 如果 controller 已有值，检查是否匹配预设选项
    if (widget.controller.text.isNotEmpty) {
      if (_reasons.contains(widget.controller.text)) {
        _selectedReason = widget.controller.text;
      } else {
        _useCustom = true;
      }
    }
  }

  void _onReasonSelected(String? reason) {
    setState(() {
      _selectedReason = reason;
      _useCustom = false;
      widget.controller.text = reason ?? '';
    });
  }

  void _onCustomToggle(bool value) {
    setState(() {
      _useCustom = value;
      if (value) {
        _selectedReason = null;
      } else {
        widget.controller.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '编辑理由',
              style: TextStyle(
                color: scrollBrown,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.isRequired)
              Text(
                ' *',
                style: TextStyle(
                  color: CharacterGalleryTheme.getVermillion(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // 快捷选项
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._reasons.map(
              (reason) => _ReasonChip(
                label: reason,
                isSelected: _selectedReason == reason && !_useCustom,
                onTap: () => _onReasonSelected(reason),
              ),
            ),
            _ReasonChip(
              label: '其他',
              isSelected: _useCustom,
              onTap: () => _onCustomToggle(!_useCustom),
              isOther: true,
            ),
          ],
        ),
        // 自定义输入框
        if (_useCustom) ...[
          const SizedBox(height: 10),
          TextField(
            controller: widget.controller,
            style: TextStyle(color: inkColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: '请输入编辑理由...',
              hintStyle: TextStyle(
                color: inkColor.withValues(alpha: 0.4),
                fontSize: 13,
              ),
              filled: true,
              fillColor: inputBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(
                  color: scrollBrown.withValues(alpha: 0.4),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(
                  color: scrollBrown.withValues(alpha: 0.4),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(
                  color: CharacterGalleryTheme.getVermillion(context),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 理由选择芯片
class _ReasonChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isOther;

  const _ReasonChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isOther = false,
  });

  @override
  State<_ReasonChip> createState() => _ReasonChipState();
}

class _ReasonChipState extends State<_ReasonChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final cardBg = CharacterGalleryTheme.getCardBackground(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? (widget.isOther
                      ? scrollBrown
                      : CharacterGalleryTheme.getVermillion(context))
                : _isHovered
                ? CharacterGalleryTheme.getVermillion(
                    context,
                  ).withValues(alpha: 0.08)
                : cardBg,
            border: Border.all(
              color: widget.isSelected
                  ? (widget.isOther
                        ? scrollBrown
                        : CharacterGalleryTheme.getVermillion(context))
                  : _isHovered
                  ? CharacterGalleryTheme.getVermillion(
                      context,
                    ).withValues(alpha: 0.5)
                  : scrollBrown.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isSelected)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.check, size: 14, color: Colors.white),
                ),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected ? Colors.white : inkColor,
                  fontSize: 12,
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 获取类型选择芯片
class AcquisitionTypeChip extends StatelessWidget {
  final String label;
  final AcquisitionType type;
  final AcquisitionType selectedType;
  final void Function(AcquisitionType) onSelect;

  const AcquisitionTypeChip({
    super.key,
    required this.label,
    required this.type,
    required this.selectedType,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedType == type;
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final cardBg = CharacterGalleryTheme.getCardBackground(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);

    return GestureDetector(
      onTap: () => onSelect(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? vermillion : cardBg,
          border: Border.all(
            color: isSelected ? vermillion : scrollBrown.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : inkColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 编辑子模型获取来源弹窗
class EditSubModelAcquisitionDialog extends StatefulWidget {
  final int characterId;
  final CharacterSubModel subModel;

  const EditSubModelAcquisitionDialog({
    super.key,
    required this.characterId,
    required this.subModel,
  });

  @override
  State<EditSubModelAcquisitionDialog> createState() =>
      _EditSubModelAcquisitionDialogState();
}

class _EditSubModelAcquisitionDialogState
    extends State<EditSubModelAcquisitionDialog> {
  late AcquisitionType _selectedType;
  late TextEditingController _costController;
  late TextEditingController _customSourceController;
  late TextEditingController _editReasonController;

  @override
  void initState() {
    super.initState();
    final currentAcquisition = widget.subModel.acquisition;
    _selectedType = currentAcquisition?.type ?? AcquisitionType.unknown;
    _costController = TextEditingController(
      text: currentAcquisition?.cost?.toString() ?? '',
    );
    _customSourceController = TextEditingController(
      text: currentAcquisition?.customSource ?? '',
    );
    _editReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _costController.dispose();
    _customSourceController.dispose();
    _editReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    // 判断是否已维护：如果原始数据不为null且不是unknown，则认为已维护
    final currentAcquisition = widget.subModel.acquisition;
    final isMaintained =
        currentAcquisition != null &&
        currentAcquisition.type != AcquisitionType.unknown;

    return AlertDialog(
      backgroundColor: washiColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scrollBrown, width: 2),
      ),
      title: _buildDialogTitle(
        context: context,
        icon: Icons.shopping_bag_outlined,
        iconColor: CharacterGalleryTheme.getGold(context),
        title: '编辑获取来源',
        subtitle: widget.subModel.name,
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '获取类型',
              style: TextStyle(
                color: scrollBrown,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AcquisitionTypeChip(
                  label: '金',
                  type: AcquisitionType.gold,
                  selectedType: _selectedType,
                  onSelect: (type) => setState(() => _selectedType = type),
                ),
                AcquisitionTypeChip(
                  label: '点',
                  type: AcquisitionType.points,
                  selectedType: _selectedType,
                  onSelect: (type) => setState(() => _selectedType = type),
                ),
                AcquisitionTypeChip(
                  label: '自定义',
                  type: AcquisitionType.custom,
                  selectedType: _selectedType,
                  onSelect: (type) => setState(() => _selectedType = type),
                ),
                // 只有未维护时才显示"未知"选项
                if (!isMaintained)
                  AcquisitionTypeChip(
                    label: '未知',
                    type: AcquisitionType.unknown,
                    selectedType: _selectedType,
                    onSelect: (type) => setState(() => _selectedType = type),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedType == AcquisitionType.gold ||
                _selectedType == AcquisitionType.points)
              DialogTextField(
                label: _selectedType == AcquisitionType.gold ? '金数量' : '点数量',
                controller: _costController,
                hint: _selectedType == AcquisitionType.gold
                    ? '例：2000'
                    : '例：500',
              ),
            if (_selectedType == AcquisitionType.custom)
              DialogTextField(
                label: '自定义来源',
                controller: _customSourceController,
                hint: '例：捐助者、OP',
              ),
            const SizedBox(height: 12),
            EditReasonSelector(
              controller: _editReasonController,
              isRequired: true, // 修改获取来源需要必填理由
              customReasons: const ['修正价格信息', '更新获取途径', '根据游戏更新调整'],
            ),
          ],
        ),
      ),
      actions: _buildDialogActions(context: context, onSubmit: _onSubmit),
    );
  }

  void _onSubmit() {
    if ((_selectedType == AcquisitionType.gold ||
            _selectedType == AcquisitionType.points) &&
        _costController.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写价格');
      return;
    }
    if (_selectedType == AcquisitionType.custom &&
        _customSourceController.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写自定义来源');
      return;
    }
    if (_editReasonController.text.isEmpty) {
      ToastUtils.showWarning(context, '请选择或填写编辑理由');
      return;
    }

    context.read<CharacterGalleryBloc>().add(
      SubmitUnifiedEdit(
        characterId: widget.characterId,
        subModelId: widget.subModel.id,
        editReason: _editReasonController.text,
        acquisition: AcquisitionEditData(
          type: _selectedType,
          cost: int.tryParse(_costController.text),
          customSource: _customSourceController.text.isNotEmpty
              ? _customSourceController.text
              : null,
        ),
      ),
    );
  }
}

/// 获取符卡类型的中文显示名称
String getSpellCardTypeLabel(String type) {
  return switch (type) {
    'ultimate' => '大符卡',
    'passive' => '被动',
    'normal' => '小符卡',
    'active' => '主动',
    _ => type,
  };
}

/// 编辑符卡弹窗（支持视频上传）
class EditSpellCardDialog extends StatefulWidget {
  final int characterId;
  final int subModelId;
  final int spellCardId;
  final String name;
  final String type;
  final String description;
  final int? cooldown;
  final String? damage;
  final int? cost;
  final String? currentVideoUrl;

  const EditSpellCardDialog({
    super.key,
    required this.characterId,
    required this.subModelId,
    required this.spellCardId,
    required this.name,
    required this.type,
    required this.description,
    this.cooldown,
    this.damage,
    this.cost,
    this.currentVideoUrl,
  });

  @override
  State<EditSpellCardDialog> createState() => _EditSpellCardDialogState();
}

class _EditSpellCardDialogState extends State<EditSpellCardDialog> {
  late TextEditingController _descriptionController;
  late TextEditingController _cooldownController;
  late TextEditingController _damageController;
  late TextEditingController _costController;
  late TextEditingController _editReasonController;
  // TODO: 视频上传功能暂时隐藏
  // int? _uploadedVideoFileId;
  // bool _isVideoUploading = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.description);
    _cooldownController = TextEditingController(
      text: widget.cooldown?.toString() ?? '',
    );
    _damageController = TextEditingController(text: widget.damage ?? '');
    _costController = TextEditingController(
      text: widget.cost?.toString() ?? '',
    );
    _editReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _cooldownController.dispose();
    _damageController.dispose();
    _costController.dispose();
    _editReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return AlertDialog(
      backgroundColor: washiColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scrollBrown, width: 2),
      ),
      title: _buildDialogTitle(
        context: context,
        icon: Icons.edit_outlined,
        iconColor: CharacterGalleryTheme.getVermillion(context),
        title: '编辑符卡: ${widget.name}',
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeLabel(context, getSpellCardTypeLabel(widget.type)),
              const SizedBox(height: 16),
              DialogTextField(
                label: '效果描述 *',
                controller: _descriptionController,
                hint: '描述符卡的效果...',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DialogTextField(
                      label: '冷却时间(秒)',
                      controller: _cooldownController,
                      hint: '60',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        _SingleDecimalPointFormatter(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DialogTextField(
                      label: '伤害',
                      controller: _damageController,
                      hint: '150-300',
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[\d\-~\/.\s]'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DialogTextField(
                label: widget.type == 'ultimate' ? '消耗B点' : '消耗P点',
                controller: _costController,
                hint: widget.type == 'ultimate' ? '100' : '50',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  _SingleDecimalPointFormatter(),
                ],
              ),
              const SizedBox(height: 12),
              // TODO: 视频上传功能暂时隐藏，等待服务器端转换方案
              // VideoUploadWidget(...),
              EditReasonSelector(controller: _editReasonController),
            ],
          ),
        ),
      ),
      actions: _buildDialogActions(context: context, onSubmit: _onSubmit),
    );
  }

  void _onSubmit() {
    if (_descriptionController.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写效果描述');
      return;
    }
    if (_editReasonController.text.isEmpty) {
      ToastUtils.showWarning(context, '请选择或填写编辑理由');
      return;
    }

    context.read<CharacterGalleryBloc>().add(
      SubmitUnifiedEdit(
        characterId: widget.characterId,
        subModelId: widget.subModelId,
        editReason: _editReasonController.text,
        spellCardUpdates: [
          SpellCardEditItem(
            id: widget.spellCardId,
            description: _descriptionController.text,
            damage: _damageController.text.isNotEmpty
                ? _damageController.text
                : null,
            cooldown: double.tryParse(_cooldownController.text),
            cost: double.tryParse(_costController.text),
          ),
        ],
      ),
    );
  }
}

/// 编辑僵尸技能弹窗（支持视频上传）
class EditZombieSkillDialog extends StatefulWidget {
  final int characterId;
  final int subModelId;
  final int skillId;
  final String name;
  final String type;
  final String description;
  final int? cooldown;
  final String? damage;
  final String? range;
  final String? special;
  final String? currentVideoUrl;

  const EditZombieSkillDialog({
    super.key,
    required this.characterId,
    required this.subModelId,
    required this.skillId,
    required this.name,
    required this.type,
    required this.description,
    this.cooldown,
    this.damage,
    this.range,
    this.special,
    this.currentVideoUrl,
  });

  @override
  State<EditZombieSkillDialog> createState() => _EditZombieSkillDialogState();
}

class _EditZombieSkillDialogState extends State<EditZombieSkillDialog> {
  late TextEditingController _descriptionController;
  late TextEditingController _cooldownController;
  late TextEditingController _damageController;
  late TextEditingController _rangeController;
  late TextEditingController _specialController;
  late TextEditingController _editReasonController;
  // TODO: 视频上传功能暂时隐藏
  // int? _uploadedVideoFileId;
  // bool _isVideoUploading = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.description);
    _cooldownController = TextEditingController(
      text: widget.cooldown?.toString() ?? '',
    );
    _damageController = TextEditingController(text: widget.damage ?? '');
    _rangeController = TextEditingController(text: widget.range ?? '');
    _specialController = TextEditingController(text: widget.special ?? '');
    _editReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _cooldownController.dispose();
    _damageController.dispose();
    _rangeController.dispose();
    _specialController.dispose();
    _editReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return AlertDialog(
      backgroundColor: washiColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scrollBrown, width: 2),
      ),
      title: _buildDialogTitle(
        context: context,
        icon: Icons.edit_outlined,
        iconColor: CharacterGalleryTheme.getVermillion(context),
        title: '编辑技能: ${widget.name}',
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeLabel(context, widget.type == 'active' ? '主动' : '被动'),
              const SizedBox(height: 16),
              DialogTextField(
                label: '效果描述 *',
                controller: _descriptionController,
                hint: '描述技能的效果...',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DialogTextField(
                      label: '冷却时间(秒)',
                      controller: _cooldownController,
                      hint: '15',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        _SingleDecimalPointFormatter(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DialogTextField(
                      label: '伤害',
                      controller: _damageController,
                      hint: '50-80',
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[\d\-~\/.\s]'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DialogTextField(
                      label: '作用范围',
                      controller: _rangeController,
                      hint: '中距离',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DialogTextField(
                      label: '特殊效果',
                      controller: _specialController,
                      hint: '减速50%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // TODO: 视频上传功能暂时隐藏，等待服务器端转换方案
              // VideoUploadWidget(...),
              EditReasonSelector(controller: _editReasonController),
            ],
          ),
        ),
      ),
      actions: _buildDialogActions(context: context, onSubmit: _onSubmit),
    );
  }

  void _onSubmit() {
    if (_descriptionController.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写效果描述');
      return;
    }
    if (_editReasonController.text.isEmpty) {
      ToastUtils.showWarning(context, '请选择或填写编辑理由');
      return;
    }

    context.read<CharacterGalleryBloc>().add(
      SubmitUnifiedEdit(
        characterId: widget.characterId,
        subModelId: widget.subModelId,
        editReason: _editReasonController.text,
        zombieSkillUpdates: [
          ZombieSkillEditItem(
            id: widget.skillId,
            description: _descriptionController.text,
            damage: _damageController.text.isNotEmpty
                ? _damageController.text
                : null,
            range: _rangeController.text.isNotEmpty
                ? _rangeController.text
                : null,
            cooldown: double.tryParse(_cooldownController.text),
            special: _specialController.text.isNotEmpty
                ? _specialController.text
                : null,
          ),
        ],
      ),
    );
  }
}

/// 编辑角色介绍弹窗
class EditCharacterDescriptionDialog extends StatefulWidget {
  final int characterId;
  final int subModelId;
  final String currentDescription;

  const EditCharacterDescriptionDialog({
    super.key,
    required this.characterId,
    required this.subModelId,
    required this.currentDescription,
  });

  @override
  State<EditCharacterDescriptionDialog> createState() =>
      _EditCharacterDescriptionDialogState();
}

class _EditCharacterDescriptionDialogState
    extends State<EditCharacterDescriptionDialog> {
  late TextEditingController _descriptionController;
  late TextEditingController _editReasonController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.currentDescription,
    );
    _editReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _editReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return AlertDialog(
      backgroundColor: washiColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scrollBrown, width: 2),
      ),
      title: _buildDialogTitle(
        context: context,
        icon: Icons.description_outlined,
        iconColor: CharacterGalleryTheme.getVermillion(context),
        title: '编辑角色介绍',
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DialogTextField(
              label: '角色介绍 *',
              controller: _descriptionController,
              hint: '描述角色的背景、特点等...',
              maxLines: 6,
            ),
            const SizedBox(height: 12),
            EditReasonSelector(controller: _editReasonController),
          ],
        ),
      ),
      actions: _buildDialogActions(context: context, onSubmit: _onSubmit),
    );
  }

  void _onSubmit() {
    if (_descriptionController.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写角色介绍');
      return;
    }
    if (_editReasonController.text.isEmpty) {
      ToastUtils.showWarning(context, '请选择或填写编辑理由');
      return;
    }

    context.read<CharacterGalleryBloc>().add(
      SubmitUnifiedEdit(
        characterId: widget.characterId,
        subModelId: widget.subModelId,
        editReason: _editReasonController.text,
        description: _descriptionController.text,
      ),
    );
  }
}

// ============ 共享组件 ============

/// 构建对话框标题
Widget _buildDialogTitle({
  required BuildContext context,
  required IconData icon,
  required Color iconColor,
  required String title,
  String? subtitle,
}) {
  final inkColor = CharacterGalleryTheme.getInkColor(context);

  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: inkColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(
                  color: inkColor.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

/// 构建类型标签
Widget _buildTypeLabel(BuildContext context, String label) {
  final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
  final vermillion = CharacterGalleryTheme.getVermillion(context);

  return Row(
    children: [
      Text('类型: ', style: TextStyle(color: scrollBrown, fontSize: 13)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: vermillion.withValues(alpha: 0.1),
          border: Border.all(color: vermillion),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: vermillion,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );
}

/// 构建对话框操作按钮
List<Widget> _buildDialogActions({
  required BuildContext context,
  required VoidCallback onSubmit,
  bool isVideoUploading = false,
}) {
  final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

  return [
    Builder(
      builder: (ctx) => TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: Text('取消', style: TextStyle(color: scrollBrown)),
      ),
    ),
    BlocConsumer<CharacterGalleryBloc, CharacterGalleryState>(
      listenWhen: (prev, curr) => prev.submitEditState != curr.submitEditState,
      listener: (ctx, state) {
        if (state.submitEditState == LoadState.success) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.canPop(ctx)) {
              Navigator.pop(ctx);
            }
          });
          ToastUtils.showSuccess(ctx, '编辑已提交审核');
        } else if (state.submitEditState == LoadState.failure) {
          ToastUtils.showError(ctx, state.submitEditError ?? '提交失败');
        }
      },
      builder: (ctx, state) {
        final isLoading = state.submitEditState == LoadState.loading;
        final isDisabled = isLoading || isVideoUploading;
        return ElevatedButton(
          onPressed: isDisabled ? null : onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: CharacterGalleryTheme.getVermillion(context),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isVideoUploading ? '视频上传中...' : '提交审核'),
        );
      },
    ),
  ];
}

/// 新增符卡弹窗
class AddSpellCardDialog extends StatefulWidget {
  final int characterId;
  final int subModelId;

  const AddSpellCardDialog({
    super.key,
    required this.characterId,
    required this.subModelId,
  });

  @override
  State<AddSpellCardDialog> createState() => _AddSpellCardDialogState();
}

class _AddSpellCardDialogState extends State<AddSpellCardDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _cooldownController;
  late TextEditingController _damageController;
  late TextEditingController _costController;
  late TextEditingController _editReasonController;
  String _selectedType = 'normal';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _cooldownController = TextEditingController();
    _damageController = TextEditingController();
    _costController = TextEditingController();
    _editReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cooldownController.dispose();
    _damageController.dispose();
    _costController.dispose();
    _editReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return AlertDialog(
      backgroundColor: washiColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scrollBrown, width: 2),
      ),
      title: _buildDialogTitle(
        context: context,
        icon: Icons.add_circle_outline,
        iconColor: CharacterGalleryTheme.getVermillion(context),
        title: '新增符卡',
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DialogTextField(
                label: '符卡名称 *',
                controller: _nameController,
                hint: '例：灵符「梦想封印」',
              ),
              const SizedBox(height: 12),
              _buildTypeSelector(),
              const SizedBox(height: 12),
              DialogTextField(
                label: '效果描述 *',
                controller: _descriptionController,
                hint: '描述符卡的效果...',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DialogTextField(
                      label: '冷却时间(秒)',
                      controller: _cooldownController,
                      hint: '60',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        _SingleDecimalPointFormatter(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DialogTextField(
                      label: '伤害',
                      controller: _damageController,
                      hint: '150-300',
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[\d\-~\/.\s]'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DialogTextField(
                label: _selectedType == 'ultimate' ? '消耗B点' : '消耗P点',
                controller: _costController,
                hint: _selectedType == 'ultimate' ? '100' : '50',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  _SingleDecimalPointFormatter(),
                ],
              ),
              const SizedBox(height: 12),
              EditReasonSelector(
                controller: _editReasonController,
                customReasons: const ['补充遗漏符卡', '根据游戏更新添加', '添加新版本内容'],
              ),
            ],
          ),
        ),
      ),
      actions: _buildDialogActions(context: context, onSubmit: _onSubmit),
    );
  }

  Widget _buildTypeSelector() {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '符卡类型 *',
          style: TextStyle(
            color: scrollBrown,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildTypeChip('normal', '普通'),
            _buildTypeChip('ultimate', '终极'),
            _buildTypeChip('passive', '被动'),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip(String type, String label) {
    final isSelected = _selectedType == type;
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final cardBg = CharacterGalleryTheme.getCardBackground(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);

    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? vermillion : cardBg,
          border: Border.all(
            color: isSelected ? vermillion : scrollBrown.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : inkColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _onSubmit() {
    if (_nameController.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写符卡名称');
      return;
    }
    if (_descriptionController.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写效果描述');
      return;
    }
    if (_editReasonController.text.isEmpty) {
      ToastUtils.showWarning(context, '请选择或填写新增理由');
      return;
    }

    context.read<CharacterGalleryBloc>().add(
      SubmitUnifiedEdit(
        characterId: widget.characterId,
        subModelId: widget.subModelId,
        editReason: _editReasonController.text,
        spellCardCreates: [
          SpellCardCreateItem(
            name: _nameController.text,
            type: _selectedType,
            description: _descriptionController.text,
            damage: _damageController.text.isNotEmpty
                ? _damageController.text
                : null,
            cooldown: double.tryParse(_cooldownController.text),
            cost: double.tryParse(_costController.text),
          ),
        ],
      ),
    );
  }
}

/// 新增僵尸技能弹窗
class AddZombieSkillDialog extends StatefulWidget {
  final int characterId;
  final int subModelId;

  const AddZombieSkillDialog({
    super.key,
    required this.characterId,
    required this.subModelId,
  });

  @override
  State<AddZombieSkillDialog> createState() => _AddZombieSkillDialogState();
}

class _AddZombieSkillDialogState extends State<AddZombieSkillDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _cooldownController;
  late TextEditingController _damageController;
  late TextEditingController _rangeController;
  late TextEditingController _specialController;
  late TextEditingController _editReasonController;
  String _selectedType = 'active';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _cooldownController = TextEditingController();
    _damageController = TextEditingController();
    _rangeController = TextEditingController();
    _specialController = TextEditingController();
    _editReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cooldownController.dispose();
    _damageController.dispose();
    _rangeController.dispose();
    _specialController.dispose();
    _editReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return AlertDialog(
      backgroundColor: washiColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scrollBrown, width: 2),
      ),
      title: _buildDialogTitle(
        context: context,
        icon: Icons.add_circle_outline,
        iconColor: CharacterGalleryTheme.getVermillion(context),
        title: '新增技能',
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DialogTextField(
                label: '技能名称 *',
                controller: _nameController,
                hint: '例：飞扑',
              ),
              const SizedBox(height: 12),
              _buildTypeSelector(),
              const SizedBox(height: 12),
              DialogTextField(
                label: '效果描述 *',
                controller: _descriptionController,
                hint: '描述技能的效果...',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DialogTextField(
                      label: '冷却时间(秒)',
                      controller: _cooldownController,
                      hint: '15',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        _SingleDecimalPointFormatter(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DialogTextField(
                      label: '伤害',
                      controller: _damageController,
                      hint: '50-80',
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[\d\-~\/.\s]'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DialogTextField(
                      label: '作用范围',
                      controller: _rangeController,
                      hint: '中距离',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DialogTextField(
                      label: '特殊效果',
                      controller: _specialController,
                      hint: '减速50%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              EditReasonSelector(
                controller: _editReasonController,
                customReasons: const ['补充遗漏技能', '根据游戏更新添加', '添加新版本内容'],
              ),
            ],
          ),
        ),
      ),
      actions: _buildDialogActions(context: context, onSubmit: _onSubmit),
    );
  }

  Widget _buildTypeSelector() {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '技能类型 *',
          style: TextStyle(
            color: scrollBrown,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildTypeChip('active', '主动'),
            _buildTypeChip('passive', '被动'),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip(String type, String label) {
    final isSelected = _selectedType == type;
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final cardBg = CharacterGalleryTheme.getCardBackground(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);

    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? vermillion : cardBg,
          border: Border.all(
            color: isSelected ? vermillion : scrollBrown.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : inkColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _onSubmit() {
    if (_nameController.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写技能名称');
      return;
    }
    if (_descriptionController.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写效果描述');
      return;
    }
    if (_editReasonController.text.isEmpty) {
      ToastUtils.showWarning(context, '请选择或填写新增理由');
      return;
    }

    context.read<CharacterGalleryBloc>().add(
      SubmitUnifiedEdit(
        characterId: widget.characterId,
        subModelId: widget.subModelId,
        editReason: _editReasonController.text,
        zombieSkillCreates: [
          ZombieSkillCreateItem(
            name: _nameController.text,
            type: _selectedType,
            description: _descriptionController.text,
            damage: _damageController.text.isNotEmpty
                ? _damageController.text
                : null,
            cooldown: double.tryParse(_cooldownController.text),
            range: _rangeController.text.isNotEmpty
                ? _rangeController.text
                : null,
            special: _specialController.text.isNotEmpty
                ? _specialController.text
                : null,
          ),
        ],
      ),
    );
  }
}

/// 确保只有一个小数点的格式化器
class _SingleDecimalPointFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    // 如果有多个小数点，拒绝输入
    if ('.'.allMatches(text).length > 1) {
      return oldValue;
    }
    return newValue;
  }
}
