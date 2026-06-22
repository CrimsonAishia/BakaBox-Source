import 'package:flutter/material.dart';
import '../../../core/models/character_models.dart';
import '../../../core/utils/toast_utils.dart';
import 'character_gallery_theme.dart';
import 'character_edit_data_models.dart';
import 'spell_card_form_widgets.dart';
import 'preview_type_selector.dart';
import '../../../core/constants/app_colors.dart';

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
  PreviewMediaData? _previewData;

  late TextEditingController _speedController;
  late TextEditingController _countController;
  late TextEditingController _angleController;
  late TextEditingController _punctureController;
  late TextEditingController _bounceController;
  late TextEditingController _explodeController;
  late TextEditingController _holdTimeController;
  late TextEditingController _trackSpeedController;
  late TextEditingController _customCdController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.existingEdit?.description ?? widget.card.description,
    );
    _cooldownController = TextEditingController(
      text:
          (widget.existingEdit?.cooldown ?? widget.card.cooldown)?.toString() ??
          '',
    );
    _damageController = TextEditingController(
      text: widget.existingEdit?.damage ?? widget.card.damage ?? '',
    );
    _costController = TextEditingController(
      text: (widget.existingEdit?.cost ?? widget.card.cost)?.toString() ?? '',
    );
    _selectedTier = widget.existingEdit?.tier ?? widget.card.tier;

    // 高级参数：existingEdit 优先，没有就用原始 card 的值
    _speedController = TextEditingController(
      text: _numToText(widget.existingEdit?.speed ?? widget.card.speed),
    );
    _countController = TextEditingController(
      text: _numToText(widget.existingEdit?.count ?? widget.card.count),
    );
    _angleController = TextEditingController(
      text: _numToText(widget.existingEdit?.angle ?? widget.card.angle),
    );
    _punctureController = TextEditingController(
      text: _numToText(widget.existingEdit?.puncture ?? widget.card.puncture),
    );
    _bounceController = TextEditingController(
      text: _numToText(widget.existingEdit?.bounce ?? widget.card.bounce),
    );
    _explodeController = TextEditingController(
      text: _numToText(widget.existingEdit?.explode ?? widget.card.explode),
    );
    _holdTimeController = TextEditingController(
      text: _numToText(widget.existingEdit?.holdTime ?? widget.card.holdTime),
    );
    _trackSpeedController = TextEditingController(
      text: _numToText(
        widget.existingEdit?.trackSpeed ?? widget.card.trackSpeed,
      ),
    );
    _customCdController = TextEditingController(
      text: _numToText(widget.existingEdit?.customCd ?? widget.card.customCd),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _cooldownController.dispose();
    _damageController.dispose();
    _costController.dispose();
    _speedController.dispose();
    _countController.dispose();
    _angleController.dispose();
    _punctureController.dispose();
    _bounceController.dispose();
    _explodeController.dispose();
    _holdTimeController.dispose();
    _trackSpeedController.dispose();
    _customCdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = SpellCardFormStyle.fromSpellCardType(
      context,
      widget.card.type,
    );
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
                            onChanged: (value) =>
                                setState(() => _selectedTier = value),
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
                                  iconColor:
                                      CharacterGalleryTheme.getCooldownColor(
                                        context,
                                      ),
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
                          const SizedBox(height: 16),
                          _SpellCardAdvancedFields(
                            speedController: _speedController,
                            countController: _countController,
                            angleController: _angleController,
                            punctureController: _punctureController,
                            bounceController: _bounceController,
                            explodeController: _explodeController,
                            holdTimeController: _holdTimeController,
                            trackSpeedController: _trackSpeedController,
                            customCdController: _customCdController,
                          ),
                          const SizedBox(height: 16),
                          PreviewTypeSelector(
                            initialType:
                                widget.existingEdit?.previewType ??
                                _previewTypeToString(widget.card.previewType),
                            initialFileId: widget.existingEdit?.previewFileId,
                            initialVideoUrl:
                                widget.existingEdit?.previewVideoUrl ??
                                widget.card.previewVideoUrl,
                            currentImageUrl: widget.card.previewImageUrl,
                            onChanged: (data) => _previewData = data,
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
    widget.onSave(
      SpellCardEditData(
        description: _descriptionController.text,
        damage: _damageController.text.isNotEmpty
            ? _damageController.text
            : null,
        cooldown: double.tryParse(_cooldownController.text),
        cost: int.tryParse(_costController.text),
        tier: _selectedTier,
        previewType: _previewData?.previewType,
        previewFileId: _previewData?.previewFileId,
        previewVideoUrl: _previewData?.previewVideoUrl,
        speed: _parseDouble(_speedController),
        count: _parseInt(_countController),
        angle: _parseDouble(_angleController),
        customCd: _parseDouble(_customCdController),
        puncture: _parseInt(_punctureController),
        bounce: _parseInt(_bounceController),
        explode: _parseDouble(_explodeController),
        holdTime: _parseDouble(_holdTimeController),
        trackSpeed: _parseDouble(_trackSpeedController),
      ),
    );
    Navigator.pop(context);
  }
}

/// 符卡创建子弹窗（东方风格）
class SpellCardCreateSubDialog extends StatefulWidget {
  final void Function(SpellCardCreateData) onSave;

  const SpellCardCreateSubDialog({super.key, required this.onSave});

  @override
  State<SpellCardCreateSubDialog> createState() =>
      _SpellCardCreateSubDialogState();
}

class _SpellCardCreateSubDialogState extends State<SpellCardCreateSubDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _cooldownController;
  late TextEditingController _damageController;
  late TextEditingController _costController;
  String _selectedType = 'normal';
  SpellCardTier? _selectedTier;
  PreviewMediaData? _previewData;

  late TextEditingController _speedController;
  late TextEditingController _countController;
  late TextEditingController _angleController;
  late TextEditingController _punctureController;
  late TextEditingController _bounceController;
  late TextEditingController _explodeController;
  late TextEditingController _holdTimeController;
  late TextEditingController _trackSpeedController;
  late TextEditingController _customCdController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _cooldownController = TextEditingController();
    _damageController = TextEditingController();
    _costController = TextEditingController();
    _speedController = TextEditingController();
    _countController = TextEditingController();
    _angleController = TextEditingController();
    _punctureController = TextEditingController();
    _bounceController = TextEditingController();
    _explodeController = TextEditingController();
    _holdTimeController = TextEditingController();
    _trackSpeedController = TextEditingController();
    _customCdController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cooldownController.dispose();
    _damageController.dispose();
    _costController.dispose();
    _speedController.dispose();
    _countController.dispose();
    _angleController.dispose();
    _punctureController.dispose();
    _bounceController.dispose();
    _explodeController.dispose();
    _holdTimeController.dispose();
    _trackSpeedController.dispose();
    _customCdController.dispose();
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
          border: Border.all(color: AppColors.skillGreen, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.skillGreen.withValues(alpha: 0.3),
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
                  SpellCardGradientDivider(color: AppColors.skillGreen),
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
                            onChanged: (type) =>
                                setState(() => _selectedType = type),
                          ),
                          const SizedBox(height: 16),
                          SpellCardTierDropdown(
                            value: _selectedTier,
                            onChanged: (value) =>
                                setState(() => _selectedTier = value),
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
                                  iconColor:
                                      CharacterGalleryTheme.getCooldownColor(
                                        context,
                                      ),
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
                          const SizedBox(height: 16),
                          _SpellCardAdvancedFields(
                            speedController: _speedController,
                            countController: _countController,
                            angleController: _angleController,
                            punctureController: _punctureController,
                            bounceController: _bounceController,
                            explodeController: _explodeController,
                            holdTimeController: _holdTimeController,
                            trackSpeedController: _trackSpeedController,
                            customCdController: _customCdController,
                          ),
                          const SizedBox(height: 16),
                          PreviewTypeSelector(
                            onChanged: (data) => _previewData = data,
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

    widget.onSave(
      SpellCardCreateData(
        name: _nameController.text,
        type: _selectedType,
        description: _descriptionController.text,
        damage: _damageController.text.isNotEmpty
            ? _damageController.text
            : null,
        cooldown: double.tryParse(_cooldownController.text),
        cost: int.tryParse(_costController.text),
        tier: _selectedTier,
        previewType: _previewData?.previewType,
        previewFileId: _previewData?.previewFileId,
        previewVideoUrl: _previewData?.previewVideoUrl,
        speed: _parseDouble(_speedController),
        count: _parseInt(_countController),
        angle: _parseDouble(_angleController),
        customCd: _parseDouble(_customCdController),
        puncture: _parseInt(_punctureController),
        bounce: _parseInt(_bounceController),
        explode: _parseDouble(_explodeController),
        holdTime: _parseDouble(_holdTimeController),
        trackSpeed: _parseDouble(_trackSpeedController),
      ),
    );
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
  State<NewSpellCardEditSubDialog> createState() =>
      _NewSpellCardEditSubDialogState();
}

class _NewSpellCardEditSubDialogState extends State<NewSpellCardEditSubDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _cooldownController;
  late TextEditingController _damageController;
  late TextEditingController _costController;
  late String _selectedType;
  late SpellCardTier? _selectedTier;
  PreviewMediaData? _previewData;

  late TextEditingController _speedController;
  late TextEditingController _countController;
  late TextEditingController _angleController;
  late TextEditingController _punctureController;
  late TextEditingController _bounceController;
  late TextEditingController _explodeController;
  late TextEditingController _holdTimeController;
  late TextEditingController _trackSpeedController;
  late TextEditingController _customCdController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data.name);
    _descriptionController = TextEditingController(
      text: widget.data.description ?? '',
    );
    _cooldownController = TextEditingController(
      text: widget.data.cooldown?.toString() ?? '',
    );
    _damageController = TextEditingController(text: widget.data.damage ?? '');
    _costController = TextEditingController(
      text: widget.data.cost?.toString() ?? '',
    );
    _selectedType = widget.data.type;
    _selectedTier = widget.data.tier;

    _speedController = TextEditingController(
      text: _numToText(widget.data.speed),
    );
    _countController = TextEditingController(
      text: _numToText(widget.data.count),
    );
    _angleController = TextEditingController(
      text: _numToText(widget.data.angle),
    );
    _punctureController = TextEditingController(
      text: _numToText(widget.data.puncture),
    );
    _bounceController = TextEditingController(
      text: _numToText(widget.data.bounce),
    );
    _explodeController = TextEditingController(
      text: _numToText(widget.data.explode),
    );
    _holdTimeController = TextEditingController(
      text: _numToText(widget.data.holdTime),
    );
    _trackSpeedController = TextEditingController(
      text: _numToText(widget.data.trackSpeed),
    );
    _customCdController = TextEditingController(
      text: _numToText(widget.data.customCd),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cooldownController.dispose();
    _damageController.dispose();
    _costController.dispose();
    _speedController.dispose();
    _countController.dispose();
    _angleController.dispose();
    _punctureController.dispose();
    _bounceController.dispose();
    _explodeController.dispose();
    _holdTimeController.dispose();
    _trackSpeedController.dispose();
    _customCdController.dispose();
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
          border: Border.all(color: AppColors.skillGreen, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.skillGreen.withValues(alpha: 0.3),
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
                  SpellCardGradientDivider(color: AppColors.skillGreen),
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
                            onChanged: (type) =>
                                setState(() => _selectedType = type),
                          ),
                          const SizedBox(height: 16),
                          SpellCardTierDropdown(
                            value: _selectedTier,
                            onChanged: (value) =>
                                setState(() => _selectedTier = value),
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
                                  iconColor:
                                      CharacterGalleryTheme.getCooldownColor(
                                        context,
                                      ),
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
                          const SizedBox(height: 16),
                          _SpellCardAdvancedFields(
                            speedController: _speedController,
                            countController: _countController,
                            angleController: _angleController,
                            punctureController: _punctureController,
                            bounceController: _bounceController,
                            explodeController: _explodeController,
                            holdTimeController: _holdTimeController,
                            trackSpeedController: _trackSpeedController,
                            customCdController: _customCdController,
                          ),
                          const SizedBox(height: 16),
                          PreviewTypeSelector(
                            initialType: widget.data.previewType ?? 'none',
                            initialFileId: widget.data.previewFileId,
                            initialVideoUrl: widget.data.previewVideoUrl,
                            onChanged: (data) => _previewData = data,
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

    widget.onSave(
      SpellCardCreateData(
        name: _nameController.text,
        type: _selectedType,
        description: _descriptionController.text,
        damage: _damageController.text.isNotEmpty
            ? _damageController.text
            : null,
        cooldown: double.tryParse(_cooldownController.text),
        cost: int.tryParse(_costController.text),
        tier: _selectedTier,
        previewType: _previewData?.previewType,
        previewFileId: _previewData?.previewFileId,
        previewVideoUrl: _previewData?.previewVideoUrl,
        speed: _parseDouble(_speedController),
        count: _parseInt(_countController),
        angle: _parseDouble(_angleController),
        customCd: _parseDouble(_customCdController),
        puncture: _parseInt(_punctureController),
        bounce: _parseInt(_bounceController),
        explode: _parseDouble(_explodeController),
        holdTime: _parseDouble(_holdTimeController),
        trackSpeed: _parseDouble(_trackSpeedController),
      ),
    );
    Navigator.pop(context);
  }
}

/// PreviewType 枚举转 API 字符串
String _previewTypeToString(PreviewType type) {
  return switch (type) {
    PreviewType.none => 'none',
    PreviewType.image => 'image',
    PreviewType.video => 'video',
    PreviewType.videoUrl => 'video_url',
  };
}

/// 高级参数输入区
///
/// 把 9 个新增字段集中放在一块可折叠/可滚动的区域里，
/// 已经被对话框外层 [SingleChildScrollView] 包裹，所以这里只用普通 [Column]。
class _SpellCardAdvancedFields extends StatelessWidget {
  final TextEditingController speedController;
  final TextEditingController countController;
  final TextEditingController angleController;
  final TextEditingController punctureController;
  final TextEditingController bounceController;
  final TextEditingController explodeController;
  final TextEditingController holdTimeController;
  final TextEditingController trackSpeedController;
  final TextEditingController customCdController;

  const _SpellCardAdvancedFields({
    required this.speedController,
    required this.countController,
    required this.angleController,
    required this.punctureController,
    required this.bounceController,
    required this.explodeController,
    required this.holdTimeController,
    required this.trackSpeedController,
    required this.customCdController,
  });

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 小标题
        Row(
          children: [
            Container(width: 3, height: 14, color: scrollBrown),
            const SizedBox(width: 8),
            Text(
              '高级参数（可选）',
              style: TextStyle(
                color: scrollBrown,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '留空表示不变更/未设置；被动符卡通常无需填写大部分字段。',
          style: TextStyle(
            color: inkColor.withValues(alpha: 0.55),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 12),
        // 第一排：弹幕初速 / 弹幕数量 / 散射角度
        Row(
          children: [
            Expanded(
              child: SpellCardNumberField(
                label: '弹幕初速',
                controller: speedController,
                hint: '800',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SpellCardNumberField(
                label: '弹幕数量',
                controller: countController,
                hint: '5',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SpellCardNumberField(
                label: '散射角度',
                controller: angleController,
                hint: '3',
                suffix: '°',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 第二排：穿刺次数 / 反弹次数 / 影响范围
        Row(
          children: [
            Expanded(
              child: SpellCardNumberField(
                label: '穿刺次数',
                controller: punctureController,
                hint: '5',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SpellCardNumberField(
                label: '反弹次数',
                controller: bounceController,
                hint: '5',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SpellCardNumberField(
                label: '影响范围',
                controller: explodeController,
                hint: '300',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 第三排：持续时间 / 追踪转向 / 内置CD
        Row(
          children: [
            Expanded(
              child: SpellCardNumberField(
                label: '持续时间',
                controller: holdTimeController,
                hint: '5',
                suffix: '秒',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SpellCardNumberField(
                label: '追踪转向',
                controller: trackSpeedController,
                hint: '600',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SpellCardNumberField(
                label: '内置CD',
                controller: customCdController,
                hint: '5',
                suffix: '秒',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 把数值控制器内容转换为 double?（空字符串视为未设置）
double? _parseDouble(TextEditingController c) {
  final text = c.text.trim();
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

/// 把数值控制器内容转换为 int?（空字符串视为未设置；带小数则截断为整数）
int? _parseInt(TextEditingController c) {
  final text = c.text.trim();
  if (text.isEmpty) return null;
  // 优先按整数解析，失败则尝试按 double 截断，避免"5.0"被识别成 null
  return int.tryParse(text) ?? double.tryParse(text)?.toInt();
}

/// 把可空数值转回字符串供输入框显示（null/未设置时显示空）
String _numToText(num? value) => value?.toString() ?? '';
