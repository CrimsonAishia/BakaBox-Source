import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/character_models.dart';
import 'character_gallery_theme.dart';
import '../../../core/constants/app_colors.dart';

/// 符卡表单样式配置
class SpellCardFormStyle {
  final Color accentColor;
  final String symbol;
  final String bgAsset;
  final String typeLabel;

  const SpellCardFormStyle({
    required this.accentColor,
    required this.symbol,
    required this.bgAsset,
    required this.typeLabel,
  });

  /// 根据符卡类型获取样式
  static SpellCardFormStyle fromType(BuildContext context, String type) {
    return switch (type) {
      'passive' => SpellCardFormStyle(
        accentColor: AppColors.skillGreen,
        symbol: '✦',
        bgAsset: 'assets/images/character_gallery/spell_card_bg_passive.png',
        typeLabel: '被动',
      ),
      'ultimate' => SpellCardFormStyle(
        accentColor: CharacterGalleryTheme.getGold(context),
        symbol: '◈',
        bgAsset: 'assets/images/character_gallery/spell_card_bg_ultimate.png',
        typeLabel: '大符卡',
      ),
      _ => SpellCardFormStyle(
        accentColor: const Color(0xFFCD7F32),
        symbol: '✧',
        bgAsset: 'assets/images/character_gallery/spell_card_bg_normal.png',
        typeLabel: '小符卡',
      ),
    };
  }

  /// 根据 SpellCardType 枚举获取样式
  static SpellCardFormStyle fromSpellCardType(
    BuildContext context,
    SpellCardType type,
  ) {
    return switch (type) {
      SpellCardType.passive => SpellCardFormStyle(
        accentColor: AppColors.skillGreen,
        symbol: '✦',
        bgAsset: 'assets/images/character_gallery/spell_card_bg_passive.png',
        typeLabel: '被动',
      ),
      SpellCardType.ultimate => SpellCardFormStyle(
        accentColor: CharacterGalleryTheme.getGold(context),
        symbol: '◈',
        bgAsset: 'assets/images/character_gallery/spell_card_bg_ultimate.png',
        typeLabel: '大符卡',
      ),
      SpellCardType.normal => SpellCardFormStyle(
        accentColor: const Color(0xFFCD7F32),
        symbol: '✧',
        bgAsset: 'assets/images/character_gallery/spell_card_bg_normal.png',
        typeLabel: '小符卡',
      ),
    };
  }
}

/// 符卡表单文本输入框
class SpellCardTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const SpellCardTextField({
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
}

/// 数值输入框（允许整数和小数）
class SpellCardNumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final Color? iconColor;
  final String? suffix;

  const SpellCardNumberField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.icon,
    this.iconColor,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);
    final effectiveIconColor = iconColor ?? scrollBrown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: effectiveIconColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: scrollBrown,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            _SingleDecimalPointFormatter(),
          ],
          style: TextStyle(color: inkColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: inkColor.withValues(alpha: 0.4)),
            suffixText: suffix,
            suffixStyle: TextStyle(color: scrollBrown, fontSize: 12),
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

/// 伤害输入框（允许数字和特殊字符如 - ~ /）
class SpellCardDamageField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const SpellCardDamageField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);
    final damageColor = CharacterGalleryTheme.getDamageColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flash_on, size: 14, color: damageColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: scrollBrown,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.text,
          // 只允许数字和伤害范围相关字符
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9\-~\/\.\s]')),
          ],
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
}

/// 符卡评级下拉选择器
class SpellCardTierDropdown extends StatelessWidget {
  final SpellCardTier? value;
  final ValueChanged<SpellCardTier?> onChanged;

  const SpellCardTierDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Color _getTierColor(BuildContext context, SpellCardTier tier) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    return switch (tier) {
      SpellCardTier.t0 => const Color(0xFFFF4444),
      SpellCardTier.t1 => const Color(0xFFFF8800),
      SpellCardTier.t2 => const Color(0xFFFFCC00),
      SpellCardTier.t3 => const Color(0xFF44BB44),
      SpellCardTier.t4 => const Color(0xFF4488FF),
      SpellCardTier.t5 => const Color(0xFF8888AA),
      SpellCardTier.unranked => scrollBrown,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '符卡评级',
          style: TextStyle(
            color: scrollBrown,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: inputBg,
            border: Border.all(color: scrollBrown.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<SpellCardTier?>(
              value: value,
              isExpanded: true,
              hint: Text(
                '选择评级（可选）',
                style: TextStyle(color: scrollBrown.withValues(alpha: 0.5)),
              ),
              items: [
                DropdownMenuItem<SpellCardTier?>(
                  value: null,
                  child: Text('未选择', style: TextStyle(color: scrollBrown)),
                ),
                ...SpellCardTier.values.map(
                  (tier) => DropdownMenuItem(
                    value: tier,
                    child: Text(
                      tier.label,
                      style: TextStyle(
                        color: _getTierColor(context, tier),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// 符卡类型选择器
class SpellCardTypeSelector extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onChanged;

  const SpellCardTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
        Row(
          children: [
            _SpellCardTypeChip(
              type: 'normal',
              icon: '✧',
              label: '小符卡',
              color: const Color(0xFFCD7F32),
              isSelected: selectedType == 'normal',
              onTap: () => onChanged('normal'),
            ),
            const SizedBox(width: 8),
            _SpellCardTypeChip(
              type: 'ultimate',
              icon: '◈',
              label: '大符卡',
              color: CharacterGalleryTheme.getGold(context),
              isSelected: selectedType == 'ultimate',
              onTap: () => onChanged('ultimate'),
            ),
            const SizedBox(width: 8),
            _SpellCardTypeChip(
              type: 'passive',
              icon: '✦',
              label: '被动',
              color: AppColors.skillGreen,
              isSelected: selectedType == 'passive',
              onTap: () => onChanged('passive'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SpellCardTypeChip extends StatelessWidget {
  final String type;
  final String icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _SpellCardTypeChip({
    required this.type,
    required this.icon,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
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
            '$icon $label',
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
}

/// 符卡对话框头部
class SpellCardDialogHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final SpellCardFormStyle style;
  final String? badge;
  final VoidCallback onClose;

  const SpellCardDialogHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.style,
    this.badge,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: style.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              style.symbol,
              style: TextStyle(
                color: style.accentColor,
                fontSize: 20,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: inkColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '·',
                      style: TextStyle(
                        color: inkColor.withValues(alpha: 0.4),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        color: inkColor.withValues(alpha: 0.7),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: style.accentColor.withValues(alpha: 0.1),
                    border: Border.all(color: style.accentColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge ?? style.typeLabel,
                    style: TextStyle(
                      color: style.accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: scrollBrown),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }
}

/// 符卡对话框渐变分隔线
class SpellCardGradientDivider extends StatelessWidget {
  final Color color;

  const SpellCardGradientDivider({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
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
}

/// 符卡对话框底部按钮区
class SpellCardDialogFooter extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final String saveLabel;
  final Color? saveColor;

  const SpellCardDialogFooter({
    super.key,
    required this.onCancel,
    required this.onSave,
    this.saveLabel = '保存',
    this.saveColor,
  });

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final effectiveSaveColor = saveColor ?? AppColors.skillGreen;

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
            onPressed: onCancel,
            child: Text('取消', style: TextStyle(color: scrollBrown)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: effectiveSaveColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(saveLabel),
          ),
        ],
      ),
    );
  }
}

/// 符卡消耗输入框（带类型区分颜色，允许整数和小数）
class SpellCardCostField extends StatelessWidget {
  final TextEditingController controller;
  final bool isUltimate;

  const SpellCardCostField({
    super.key,
    required this.controller,
    required this.isUltimate,
  });

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);
    // 大符卡用金色，小符卡用蓝色（区别于伤害的红色）
    final costColor = isUltimate
        ? CharacterGalleryTheme.getGold(context)
        : CharacterGalleryTheme.getPCostColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_fire_department, size: 14, color: costColor),
            const SizedBox(width: 4),
            Text(
              isUltimate ? '消耗B点' : '消耗P点',
              style: TextStyle(
                color: scrollBrown,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            _SingleDecimalPointFormatter(),
          ],
          style: TextStyle(color: inkColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: isUltimate ? '100' : '50',
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
}
