import 'package:flutter/material.dart';
import '../../../core/models/character_models.dart';
import '../../../core/utils/toast_utils.dart';
import 'character_gallery_theme.dart';
import 'character_edit_data_models.dart';
import 'spell_card_form_widgets.dart';

/// 符卡编辑子弹窗（东方风格）
class SpellCardEditSubDialog extends StatefulWidget {
  final SpellCard card;
  final SpellCardEditData? existingEdit;
  final void Function(SpellCardEditData) onSave;

  const SpellCardEditSubDialog({
    super.key,
    required this.card,
    this.existingEdit,
    required this.onSave,
  });

  @override
  State<SpellCardEditSubDialog> createState() => _SpellCardEditSubDialogState();
}

class _SpellCardEditSubDialogState extends State<SpellCardEditSubDialog> {
  late TextEditingController _descriptionController;
  late TextEditingController _cooldownController;
  late TextEditingController _damageController;
  late TextEditingController _costController;
  late SpellCardTier? _selectedTier;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.existingEdit?.description ?? widget.card.description,
    );
    _cooldownController = TextEditingController(
      text: (widget.existingEdit?.cooldown ?? widget.card.cooldown)?.toString() ?? '',
    );
    _damageController = TextEditingController(
      text: widget.existingEdit?.damage ?? widget.card.damage ?? '',
    );
    _costController = TextEditingController(
      text: (widget.existingEdit?.cost ?? widget.card.cost)?.toString() ?? '',
    );
    _selectedTier = widget.existingEdit?.tier ?? widget.card.tier;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _cooldownController.dispose();
    _damageController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = SpellCardFormStyle.fromSpellCardType(context, widget.card.type);
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUltimate = widget.card.type == SpellCardType.ultimate;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: washiColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: style.accentColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: style.accentColor.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  style.bgAsset,
                  fit: BoxFit.cover,
                  opacity: AlwaysStoppedAnimation(isDark ? 0.08 : 0.15),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SpellCardDialogHeader(
                    title: '编辑符卡',
                    subtitle: widget.card.name,
                    style: style,
                    onClose: () => Navigator.pop(context),
                  ),
                  SpellCardGradientDivider(color: style.accentColor),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SpellCardTierDropdown(
                            value: _selectedTier,
                            onChanged: (value) => setState(() => _selectedTier = value),
                          ),
                          const SizedBox(height: 16),
                          SpellCardTextField(
                            label: '效果描述',
                            controller: _descriptionController,
                            hint: '描述符卡的效果...',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: SpellCardNumberField(
                                  label: '冷却时间',
                                  controller: _cooldownController,
                                  hint: '60',
                                  icon: Icons.timer_outlined,
                                  iconColor: CharacterGalleryTheme.getCooldownColor(context),
                                  suffix: '秒',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SpellCardDamageField(
                                  label: '伤害',
                                  controller: _damageController,
                                  hint: '150-300',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SpellCardCostField(
                            controller: _costController,
                            isUltimate: isUltimate,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SpellCardDialogFooter(
                    onCancel: () => Navigator.pop(context),
                    onSave: _onSave,
                    saveColor: style.accentColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSave() {
    widget.onSave(SpellCardEditData(
      description: _descriptionController.text,
      damage: _damageController.text.isNotEmpty ? _damageController.text : null,
      cooldown: int.tryParse(_cooldownController.text),
      cost: int.tryParse(_costController.text),
      tier: _selectedTier,
    ));
    Navigator.pop(context);
  }
}


/// 符卡创建子弹窗（东方风格）
class SpellCardCreateSubDialog extends StatefulWidget {
  final void Function(SpellCardCreateData) onSave;

  const SpellCardCreateSubDialog({super.key, required this.onSave});

  @override
  State<SpellCardCreateSubDialog> createState() => _SpellCardCreateSubDialogState();
}

class _SpellCardCreateSubDialogState extends State<SpellCardCreateSubDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _cooldownController;
  late TextEditingController _damageController;
  late TextEditingController _costController;
  String _selectedType = 'normal';
  SpellCardTier? _selectedTier;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _cooldownController = TextEditingController();
    _damageController = TextEditingController();
    _costController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cooldownController.dispose();
    _damageController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = SpellCardFormStyle.fromType(context, _selectedType);
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUltimate = _selectedType == 'ultimate';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 650),
        decoration: BoxDecoration(
          color: washiColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4A7C59), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A7C59).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  style.bgAsset,
                  fit: BoxFit.cover,
                  opacity: AlwaysStoppedAnimation(isDark ? 0.08 : 0.15),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SpellCardDialogHeader(
                    title: '新增符卡',
                    style: style,
                    badge: '新增',
                    onClose: () => Navigator.pop(context),
                  ),
                  SpellCardGradientDivider(color: const Color(0xFF4A7C59)),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SpellCardTextField(
                            label: '符卡名称 *',
                            controller: _nameController,
                            hint: '例：灵符「梦想封印」',
                          ),
                          const SizedBox(height: 16),
                          SpellCardTypeSelector(
                            selectedType: _selectedType,
                            onChanged: (type) => setState(() => _selectedType = type),
                          ),
                          const SizedBox(height: 16),
                          SpellCardTierDropdown(
                            value: _selectedTier,
                            onChanged: (value) => setState(() => _selectedTier = value),
                          ),
                          const SizedBox(height: 16),
                          SpellCardTextField(
                            label: '效果描述 *',
                            controller: _descriptionController,
                            hint: '描述符卡的效果...',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: SpellCardNumberField(
                                  label: '冷却时间',
                                  controller: _cooldownController,
                                  hint: '60',
                                  icon: Icons.timer_outlined,
                                  iconColor: CharacterGalleryTheme.getCooldownColor(context),
                                  suffix: '秒',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SpellCardDamageField(
                                  label: '伤害',
                                  controller: _damageController,
                                  hint: '150-300',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SpellCardCostField(
                            controller: _costController,
                            isUltimate: isUltimate,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SpellCardDialogFooter(
                    onCancel: () => Navigator.pop(context),
                    onSave: _onSave,
                    saveLabel: '添加',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSave() {
    if (_nameController.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写符卡名称');
      return;
    }
    if (_descriptionController.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写效果描述');
      return;
    }

    widget.onSave(SpellCardCreateData(
      name: _nameController.text,
      type: _selectedType,
      description: _descriptionController.text,
      damage: _damageController.text.isNotEmpty ? _damageController.text : null,
      cooldown: int.tryParse(_cooldownController.text),
      cost: int.tryParse(_costController.text),
      tier: _selectedTier,
    ));
    Navigator.pop(context);
  }
}


/// 新增符卡编辑子弹窗（东方风格，允许编辑名称和类型）
class NewSpellCardEditSubDialog extends StatefulWidget {
  final SpellCardCreateData data;
  final void Function(SpellCardCreateData) onSave;

  const NewSpellCardEditSubDialog({
    super.key,
    required this.data,
    required this.onSave,
  });

  @override
  State<NewSpellCardEditSubDialog> createState() => _NewSpellCardEditSubDialogState();
}

class _NewSpellCardEditSubDialogState extends State<NewSpellCardEditSubDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _cooldownController;
  late TextEditingController _damageController;
  late TextEditingController _costController;
  late String _selectedType;
  late SpellCardTier? _selectedTier;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data.name);
    _descriptionController = TextEditingController(text: widget.data.description ?? '');
    _cooldownController = TextEditingController(text: widget.data.cooldown?.toString() ?? '');
    _damageController = TextEditingController(text: widget.data.damage ?? '');
    _costController = TextEditingController(text: widget.data.cost?.toString() ?? '');
    _selectedType = widget.data.type;
    _selectedTier = widget.data.tier;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cooldownController.dispose();
    _damageController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = SpellCardFormStyle.fromType(context, _selectedType);
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUltimate = _selectedType == 'ultimate';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 650),
        decoration: BoxDecoration(
          color: washiColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4A7C59), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A7C59).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  style.bgAsset,
                  fit: BoxFit.cover,
                  opacity: AlwaysStoppedAnimation(isDark ? 0.08 : 0.15),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SpellCardDialogHeader(
                    title: '编辑新增符卡',
                    style: style,
                    badge: '新增',
                    onClose: () => Navigator.pop(context),
                  ),
                  SpellCardGradientDivider(color: const Color(0xFF4A7C59)),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SpellCardTextField(
                            label: '符卡名称 *',
                            controller: _nameController,
                            hint: '例：灵符「梦想封印」',
                          ),
                          const SizedBox(height: 16),
                          SpellCardTypeSelector(
                            selectedType: _selectedType,
                            onChanged: (type) => setState(() => _selectedType = type),
                          ),
                          const SizedBox(height: 16),
                          SpellCardTierDropdown(
                            value: _selectedTier,
                            onChanged: (value) => setState(() => _selectedTier = value),
                          ),
                          const SizedBox(height: 16),
                          SpellCardTextField(
                            label: '效果描述 *',
                            controller: _descriptionController,
                            hint: '描述符卡的效果...',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: SpellCardNumberField(
                                  label: '冷却时间',
                                  controller: _cooldownController,
                                  hint: '60',
                                  icon: Icons.timer_outlined,
                                  iconColor: CharacterGalleryTheme.getCooldownColor(context),
                                  suffix: '秒',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SpellCardDamageField(
                                  label: '伤害',
                                  controller: _damageController,
                                  hint: '150-300',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SpellCardCostField(
                            controller: _costController,
                            isUltimate: isUltimate,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SpellCardDialogFooter(
                    onCancel: () => Navigator.pop(context),
                    onSave: _onSave,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSave() {
    if (_nameController.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写符卡名称');
      return;
    }
    if (_descriptionController.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写效果描述');
      return;
    }

    widget.onSave(SpellCardCreateData(
      name: _nameController.text,
      type: _selectedType,
      description: _descriptionController.text,
      damage: _damageController.text.isNotEmpty ? _damageController.text : null,
      cooldown: int.tryParse(_cooldownController.text),
      cost: int.tryParse(_costController.text),
      tier: _selectedTier,
    ));
    Navigator.pop(context);
  }
}
