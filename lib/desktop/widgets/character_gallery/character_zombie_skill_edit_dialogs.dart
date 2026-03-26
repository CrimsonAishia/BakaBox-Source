import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/character_models.dart';
import '../../../core/utils/toast_utils.dart';
import 'character_gallery_theme.dart';
import 'character_edit_data_models.dart';
import 'preview_type_selector.dart';

/// 输入字段类型
enum ZombieFieldType {
  number, // 数字（冷却）
  damage, // 伤害（允许范围如 50-80）
  text, // 文本（范围、特殊效果、描述）
}

/// 确保只有一个小数点的格式化器
class _SingleDecimalPointFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if ('.'.allMatches(text).length > 1) {
      return oldValue;
    }
    return newValue;
  }
}

/// 僵尸技能编辑子弹窗（东方风格）
class ZombieSkillEditSubDialog extends StatefulWidget {
  final ZombieSkill skill;
  final ZombieSkillEditData? existingEdit;
  final void Function(ZombieSkillEditData) onSave;

  const ZombieSkillEditSubDialog({
    super.key,
    required this.skill,
    this.existingEdit,
    required this.onSave,
  });

  @override
  State<ZombieSkillEditSubDialog> createState() =>
      _ZombieSkillEditSubDialogState();
}

class _ZombieSkillEditSubDialogState extends State<ZombieSkillEditSubDialog> {
  late TextEditingController _descriptionController;
  late TextEditingController _cooldownController;
  late TextEditingController _damageController;
  late TextEditingController _rangeController;
  late TextEditingController _specialController;
  PreviewMediaData? _previewData;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.existingEdit?.description ?? widget.skill.description,
    );
    _cooldownController = TextEditingController(
      text:
          (widget.existingEdit?.cooldown ?? widget.skill.cooldown)
              ?.toString() ??
          '',
    );
    _damageController = TextEditingController(
      text: widget.existingEdit?.damage ?? widget.skill.damage ?? '',
    );
    _rangeController = TextEditingController(
      text: widget.existingEdit?.range ?? widget.skill.range ?? '',
    );
    _specialController = TextEditingController(
      text: widget.existingEdit?.special ?? widget.skill.special ?? '',
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _cooldownController.dispose();
    _damageController.dispose();
    _rangeController.dispose();
    _specialController.dispose();
    super.dispose();
  }

  (Color, String, String) _getTypeStyle(BuildContext context) {
    final isActive = widget.skill.type == ZombieSkillType.active;
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    return isActive
        ? (
            vermillion,
            '◈',
            'assets/images/character_gallery/spell_card_bg_ultimate.png',
          )
        : (
            const Color(0xFF4A7C59),
            '✦',
            'assets/images/character_gallery/spell_card_bg_passive.png',
          );
  }

  @override
  Widget build(BuildContext context) {
    final (accentColor, symbol, bgAsset) = _getTypeStyle(context);
    final typeLabel = widget.skill.type == ZombieSkillType.active ? '主动' : '被动';
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: washiColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.3),
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
                  bgAsset,
                  fit: BoxFit.cover,
                  opacity: AlwaysStoppedAnimation(isDark ? 0.08 : 0.15),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(symbol, typeLabel, accentColor),
                  _buildGradientDivider(accentColor),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            '效果描述',
                            _descriptionController,
                            '描述技能的效果...',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  '冷却时间(秒)',
                                  _cooldownController,
                                  '15',
                                  fieldType: ZombieFieldType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  '伤害',
                                  _damageController,
                                  '50-80',
                                  fieldType: ZombieFieldType.damage,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  '作用范围',
                                  _rangeController,
                                  '中距离',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  '特殊效果',
                                  _specialController,
                                  '减速50%',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          PreviewTypeSelector(
                            initialType:
                                widget.existingEdit?.previewType ??
                                _previewTypeToString(widget.skill.previewType),
                            initialFileId: widget.existingEdit?.previewFileId,
                            initialVideoUrl:
                                widget.existingEdit?.previewVideoUrl ??
                                widget.skill.previewVideoUrl,
                            currentImageUrl: widget.skill.previewImageUrl,
                            onChanged: (data) => _previewData = data,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildFooter(accentColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String symbol, String typeLabel, Color accentColor) {
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            symbol,
            style: TextStyle(
              color: accentColor,
              fontSize: 24,
              shadows: [
                Shadow(
                  color: accentColor.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '编辑技能',
                      style: TextStyle(
                        color: inkColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        border: Border.all(color: accentColor),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.skill.name,
                  style: TextStyle(
                    color: inkColor.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: scrollBrown),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  Widget _buildGradientDivider(Color color) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.6),
            color.withValues(alpha: 0.6),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.2, 0.8, 1],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    ZombieFieldType fieldType = ZombieFieldType.text,
  }) {
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
          keyboardType: fieldType == ZombieFieldType.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: _getInputFormatters(fieldType),
          style: TextStyle(color: inkColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: inkColor.withValues(alpha: 0.4)),
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: scrollBrown.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: scrollBrown.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: CharacterGalleryTheme.getVermillion(context),
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<TextInputFormatter>? _getInputFormatters(ZombieFieldType fieldType) {
    return switch (fieldType) {
      ZombieFieldType.number => [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
        _SingleDecimalPointFormatter(),
      ],
      ZombieFieldType.damage => [
        FilteringTextInputFormatter.allow(RegExp(r'[\d\-~\/.\s]')),
      ],
      ZombieFieldType.text => null,
    };
  }

  Widget _buildFooter(Color accentColor) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scrollBrown.withValues(alpha: 0.05),
        border: Border(
          top: BorderSide(color: scrollBrown.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: scrollBrown)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              widget.onSave(
                ZombieSkillEditData(
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
                  previewType: _previewData?.previewType,
                  previewFileId: _previewData?.previewFileId,
                  previewVideoUrl: _previewData?.previewVideoUrl,
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

/// 僵尸技能创建子弹窗（东方风格）
class ZombieSkillCreateSubDialog extends StatefulWidget {
  final void Function(ZombieSkillCreateData) onSave;

  const ZombieSkillCreateSubDialog({super.key, required this.onSave});

  @override
  State<ZombieSkillCreateSubDialog> createState() =>
      _ZombieSkillCreateSubDialogState();
}

class _ZombieSkillCreateSubDialogState
    extends State<ZombieSkillCreateSubDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _cooldownController;
  late TextEditingController _damageController;
  late TextEditingController _rangeController;
  late TextEditingController _specialController;
  String _selectedType = 'active';
  PreviewMediaData? _previewData;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _cooldownController = TextEditingController();
    _damageController = TextEditingController();
    _rangeController = TextEditingController();
    _specialController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cooldownController.dispose();
    _damageController.dispose();
    _rangeController.dispose();
    _specialController.dispose();
    super.dispose();
  }

  (Color, String, String) _getTypeStyle(BuildContext context) {
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    return _selectedType == 'active'
        ? (
            vermillion,
            '◈',
            'assets/images/character_gallery/spell_card_bg_ultimate.png',
          )
        : (
            const Color(0xFF4A7C59),
            '✦',
            'assets/images/character_gallery/spell_card_bg_passive.png',
          );
  }

  @override
  Widget build(BuildContext context) {
    final (accentColor, symbol, bgAsset) = _getTypeStyle(context);
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  bgAsset,
                  fit: BoxFit.cover,
                  opacity: AlwaysStoppedAnimation(isDark ? 0.08 : 0.15),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(symbol, accentColor),
                  _buildGradientDivider(const Color(0xFF4A7C59)),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField('技能名称 *', _nameController, '例：飞扑'),
                          const SizedBox(height: 16),
                          _buildTypeSelector(),
                          const SizedBox(height: 16),
                          _buildTextField(
                            '效果描述 *',
                            _descriptionController,
                            '描述技能的效果...',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  '冷却时间(秒)',
                                  _cooldownController,
                                  '15',
                                  fieldType: ZombieFieldType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  '伤害',
                                  _damageController,
                                  '50-80',
                                  fieldType: ZombieFieldType.damage,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  '作用范围',
                                  _rangeController,
                                  '中距离',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  '特殊效果',
                                  _specialController,
                                  '减速50%',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          PreviewTypeSelector(
                            onChanged: (data) => _previewData = data,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildFooter(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String symbol, Color accentColor) {
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            symbol,
            style: TextStyle(
              color: accentColor,
              fontSize: 24,
              shadows: [
                Shadow(
                  color: accentColor.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(
                  '新增技能',
                  style: TextStyle(
                    color: inkColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A7C59).withValues(alpha: 0.15),
                    border: Border.all(color: const Color(0xFF4A7C59)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '新增',
                    style: TextStyle(
                      color: Color(0xFF4A7C59),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: scrollBrown),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  Widget _buildGradientDivider(Color color) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.6),
            color.withValues(alpha: 0.6),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.2, 0.8, 1],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    ZombieFieldType fieldType = ZombieFieldType.text,
  }) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);

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
          keyboardType: fieldType == ZombieFieldType.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: _getInputFormatters(fieldType),
          style: TextStyle(color: inkColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: inkColor.withValues(alpha: 0.4)),
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: scrollBrown.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: scrollBrown.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: vermillion, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  List<TextInputFormatter>? _getInputFormatters(ZombieFieldType fieldType) {
    return switch (fieldType) {
      ZombieFieldType.number => [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
        _SingleDecimalPointFormatter(),
      ],
      ZombieFieldType.damage => [
        FilteringTextInputFormatter.allow(RegExp(r'[\d\-~\/.\s]')),
      ],
      ZombieFieldType.text => null,
    };
  }

  Widget _buildTypeSelector() {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);

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
        Row(
          children: [
            _buildTypeChip('active', '◈ 主动', vermillion),
            const SizedBox(width: 12),
            _buildTypeChip('passive', '✦ 被动', const Color(0xFF4A7C59)),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip(String type, String label, Color color) {
    final isSelected = _selectedType == type;
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : inputBg,
            border: Border.all(
              color: isSelected ? color : scrollBrown.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : inkColor,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scrollBrown.withValues(alpha: 0.05),
        border: Border(
          top: BorderSide(color: scrollBrown.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: scrollBrown)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A7C59),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _onSave() {
    if (_nameController.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写技能名称');
      return;
    }
    if (_descriptionController.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写效果描述');
      return;
    }

    widget.onSave(
      ZombieSkillCreateData(
        name: _nameController.text,
        type: _selectedType,
        description: _descriptionController.text,
        damage: _damageController.text.isNotEmpty
            ? _damageController.text
            : null,
        cooldown: double.tryParse(_cooldownController.text),
        range: _rangeController.text.isNotEmpty ? _rangeController.text : null,
        special: _specialController.text.isNotEmpty
            ? _specialController.text
            : null,
        previewType: _previewData?.previewType,
        previewFileId: _previewData?.previewFileId,
        previewVideoUrl: _previewData?.previewVideoUrl,
      ),
    );
    Navigator.pop(context);
  }
}

/// 新增僵尸技能编辑子弹窗（东方风格，允许编辑名称和类型）
class NewZombieSkillEditSubDialog extends StatefulWidget {
  final ZombieSkillCreateData data;
  final void Function(ZombieSkillCreateData) onSave;

  const NewZombieSkillEditSubDialog({
    super.key,
    required this.data,
    required this.onSave,
  });

  @override
  State<NewZombieSkillEditSubDialog> createState() =>
      _NewZombieSkillEditSubDialogState();
}

class _NewZombieSkillEditSubDialogState
    extends State<NewZombieSkillEditSubDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _cooldownController;
  late TextEditingController _damageController;
  late TextEditingController _rangeController;
  late TextEditingController _specialController;
  late String _selectedType;
  PreviewMediaData? _previewData;

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
    _rangeController = TextEditingController(text: widget.data.range ?? '');
    _specialController = TextEditingController(text: widget.data.special ?? '');
    _selectedType = widget.data.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cooldownController.dispose();
    _damageController.dispose();
    _rangeController.dispose();
    _specialController.dispose();
    super.dispose();
  }

  (Color, String, String) _getTypeStyle(BuildContext context) {
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    return _selectedType == 'active'
        ? (
            vermillion,
            '◈',
            'assets/images/character_gallery/spell_card_bg_ultimate.png',
          )
        : (
            const Color(0xFF4A7C59),
            '✦',
            'assets/images/character_gallery/spell_card_bg_passive.png',
          );
  }

  @override
  Widget build(BuildContext context) {
    final (accentColor, symbol, bgAsset) = _getTypeStyle(context);
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  bgAsset,
                  fit: BoxFit.cover,
                  opacity: AlwaysStoppedAnimation(isDark ? 0.08 : 0.15),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(symbol, accentColor),
                  _buildGradientDivider(const Color(0xFF4A7C59)),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField('技能名称 *', _nameController, '例：飞扑'),
                          const SizedBox(height: 16),
                          _buildTypeSelector(),
                          const SizedBox(height: 16),
                          _buildTextField(
                            '效果描述 *',
                            _descriptionController,
                            '描述技能的效果...',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  '冷却时间(秒)',
                                  _cooldownController,
                                  '15',
                                  fieldType: ZombieFieldType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  '伤害',
                                  _damageController,
                                  '50-80',
                                  fieldType: ZombieFieldType.damage,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  '作用范围',
                                  _rangeController,
                                  '中距离',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  '特殊效果',
                                  _specialController,
                                  '减速50%',
                                ),
                              ),
                            ],
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
                  _buildFooter(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String symbol, Color accentColor) {
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            symbol,
            style: TextStyle(
              color: accentColor,
              fontSize: 24,
              shadows: [
                Shadow(
                  color: accentColor.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(
                  '编辑新增技能',
                  style: TextStyle(
                    color: inkColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A7C59).withValues(alpha: 0.15),
                    border: Border.all(color: const Color(0xFF4A7C59)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '新增',
                    style: TextStyle(
                      color: Color(0xFF4A7C59),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: scrollBrown),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  Widget _buildGradientDivider(Color color) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.6),
            color.withValues(alpha: 0.6),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.2, 0.8, 1],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    ZombieFieldType fieldType = ZombieFieldType.text,
  }) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);

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
          keyboardType: fieldType == ZombieFieldType.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: _getInputFormatters(fieldType),
          style: TextStyle(color: inkColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: inkColor.withValues(alpha: 0.4)),
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: scrollBrown.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: scrollBrown.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: vermillion, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  List<TextInputFormatter>? _getInputFormatters(ZombieFieldType fieldType) {
    return switch (fieldType) {
      ZombieFieldType.number => [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
        _SingleDecimalPointFormatter(),
      ],
      ZombieFieldType.damage => [
        FilteringTextInputFormatter.allow(RegExp(r'[\d\-~\/.\s]')),
      ],
      ZombieFieldType.text => null,
    };
  }

  Widget _buildTypeSelector() {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);

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
        Row(
          children: [
            _buildTypeChip('active', '◈ 主动', vermillion),
            const SizedBox(width: 12),
            _buildTypeChip('passive', '✦ 被动', const Color(0xFF4A7C59)),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip(String type, String label, Color color) {
    final isSelected = _selectedType == type;
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : inputBg,
            border: Border.all(
              color: isSelected ? color : scrollBrown.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : inkColor,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scrollBrown.withValues(alpha: 0.05),
        border: Border(
          top: BorderSide(color: scrollBrown.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: scrollBrown)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A7C59),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _onSave() {
    if (_nameController.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写技能名称');
      return;
    }
    if (_descriptionController.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写效果描述');
      return;
    }

    widget.onSave(
      ZombieSkillCreateData(
        name: _nameController.text,
        type: _selectedType,
        description: _descriptionController.text,
        damage: _damageController.text.isNotEmpty
            ? _damageController.text
            : null,
        cooldown: double.tryParse(_cooldownController.text),
        range: _rangeController.text.isNotEmpty ? _rangeController.text : null,
        special: _specialController.text.isNotEmpty
            ? _specialController.text
            : null,
        previewType: _previewData?.previewType,
        previewFileId: _previewData?.previewFileId,
        previewVideoUrl: _previewData?.previewVideoUrl,
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
