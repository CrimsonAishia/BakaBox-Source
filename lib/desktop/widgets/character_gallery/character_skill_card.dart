import 'package:flutter/material.dart';
import '../../../core/models/character_models.dart';
import 'character_gallery_theme.dart';
import 'character_common_widgets.dart';

/// 技能/符卡卡片
class SkillCard extends StatelessWidget {
  final int id;
  final String name;
  final String type;
  final String description;
  final double? cooldown;
  final String? damage;
  final double? cost;
  final String? range;
  final String? special; // 特殊效果（僵尸技能）
  final bool isSpellCard;
  final bool isSubModelSpecific;
  final SpellCardTier? tier; // 符卡评级
  final VoidCallback? onEdit;
  final VoidCallback? onHistory;

  const SkillCard({
    super.key,
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    this.cooldown,
    this.damage,
    this.cost,
    this.range,
    this.special,
    required this.isSpellCard,
    this.isSubModelSpecific = false,
    this.tier,
    this.onEdit,
    this.onHistory,
  });

  String get _typeLabel {
    return switch (type) {
      'ultimate' => '大符卡',
      'passive' => '被动',
      'normal' => '小符卡',
      'active' => '主动',
      _ => type,
    };
  }

  Color _getTypeColor(BuildContext context) {
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    return switch (type) {
      'ultimate' => CharacterGalleryTheme.getGold(context),
      'passive' => const Color(0xFF4A7C59),
      _ => vermillion,
    };
  }

  Color _getTierColor(SpellCardTier tier) {
    return switch (tier) {
      SpellCardTier.t0 => const Color(0xFFFF4444),
      SpellCardTier.t1 => const Color(0xFFFF8C00),
      SpellCardTier.t2 => const Color(0xFFFFD700),
      SpellCardTier.t3 => const Color(0xFF32CD32),
      SpellCardTier.t4 => const Color(0xFF4169E1),
      SpellCardTier.t5 => const Color(0xFF9370DB),
      SpellCardTier.unranked => const Color(0xFFAAAAAA),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final cardBg = CharacterGalleryTheme.getOverlayColor(context, alpha: 0.5);
    final typeColor = _getTypeColor(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: scrollBrown.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 类型标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  border: Border.all(color: typeColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _typeLabel,
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // 评级标签（仅符卡显示）
              if (isSpellCard &&
                  tier != null &&
                  tier != SpellCardTier.unranked) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getTierColor(tier!).withValues(alpha: 0.15),
                    border: Border.all(color: _getTierColor(tier!)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tier!.shortLabel,
                    style: TextStyle(
                      color: _getTierColor(tier!),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              // 名称
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: inkColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // 历史按钮
              if (onHistory != null)
                HoverButton(
                  icon: Icons.history,
                  label: '历史',
                  onTap: onHistory!,
                  small: true,
                ),
              if (onHistory != null && onEdit != null) const SizedBox(width: 6),
              // 编辑按钮
              if (onEdit != null)
                HoverButton(
                  icon: Icons.edit_outlined,
                  label: '编辑',
                  onTap: onEdit!,
                  small: true,
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 描述
          Text(
            description,
            style: TextStyle(
              color: inkColor.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          // 数值信息
          if (cooldown != null ||
              damage != null ||
              cost != null ||
              range != null ||
              special != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (cooldown != null)
                  _StatItem(
                    icon: Icons.timer_outlined,
                    label: '冷却',
                    value: '${_formatNumber(cooldown!)}s',
                    color: CharacterGalleryTheme.getCooldownColor(context),
                  ),
                if (damage != null)
                  _StatItem(
                    icon: Icons.flash_on,
                    label: '伤害',
                    value: damage!,
                    color: CharacterGalleryTheme.getDamageColor(context),
                  ),
                // 符卡显示消耗
                if (isSpellCard && cost != null)
                  _StatItem(
                    icon: Icons.local_fire_department,
                    label: type == 'ultimate' ? 'B点' : 'P点',
                    value: _formatNumber(cost!),
                    color: type == 'ultimate'
                        ? CharacterGalleryTheme.getBCostColor(context)
                        : CharacterGalleryTheme.getPCostColor(context),
                  ),
                // 僵尸技能显示范围
                if (!isSpellCard && range != null)
                  _StatItem(
                    icon: Icons.radar,
                    label: '范围',
                    value: range!,
                    color: CharacterGalleryTheme.getRangeColor(context),
                  ),
                // 僵尸技能显示特殊效果
                if (!isSpellCard && special != null)
                  _StatItem(
                    icon: Icons.auto_awesome,
                    label: '特殊',
                    value: special!,
                    color: CharacterGalleryTheme.getSpecialColor(context),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 空技能提示
class EmptySkillHint extends StatelessWidget {
  final String text;

  const EmptySkillHint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final cardBg = CharacterGalleryTheme.getOverlayColor(context, alpha: 0.3);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: scrollBrown.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📝', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: inkColor.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// 格式化数值：整数不显示小数点，小数保留原样
String _formatNumber(num value) {
  if (value is int) {
    return value.toString();
  }
  final d = value as double;
  if (d == d.truncateToDouble()) {
    return d.toInt().toString();
  }
  return d.toString();
}

/// 数值统计项（图标+文字+数值）
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        SizedBox(
          width: 36, // 固定宽度确保 label 对齐
          child: Text(
            '$label:',
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
