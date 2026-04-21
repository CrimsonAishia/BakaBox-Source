import 'package:flutter/material.dart';

import '../../../core/models/character_models.dart';
import '../../../desktop/widgets/character_gallery/character_gallery_theme.dart';

/// 移动端僵尸技能卡片组件 - 与桌面端完全一致的设计
///
/// 使用符卡背景图片和符号装饰，显示技能名称和描述。
/// 被动技能使用绿色系和被动背景，主动技能使用朱红色和大符卡背景。
///
/// **Validates: Requirements 6.2**
class ZombieSkillCardMobile extends StatelessWidget {
  /// 僵尸技能数据
  final ZombieSkill skill;

  const ZombieSkillCardMobile({
    super.key,
    required this.skill,
  });

  /// 获取技能类型对应的样式配置（与桌面端完全一致）
  (Color borderColor, Color bgColor, String symbol, String bgAsset) _getTypeStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final isPassive = skill.type == ZombieSkillType.passive;

    // 被动用绿色和被动背景，主动用朱红和大符卡背景（与桌面端完全一致）
    return isPassive
        ? (
            const Color(0xFF4A7C59),
            const Color(0xFF4A7C59).withValues(alpha: isDark ? 0.15 : 0.08),
            '✦',
            'assets/images/character_gallery/spell_card_bg_passive.png',
          )
        : (
            vermillion,
            vermillion.withValues(alpha: isDark ? 0.12 : 0.06),
            '✧',
            'assets/images/character_gallery/spell_card_bg_ultimate.png',
          );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final (borderColor, bgColor, symbol, bgAsset) = _getTypeStyle(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            // 背景图层（与桌面端一致）
            Positioned.fill(
              child: Image.asset(
                bgAsset,
                fit: BoxFit.cover,
                opacity: AlwaysStoppedAnimation(isDark ? 0.3 : 0.6),
              ),
            ),
            // 内容层
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题行：符号 + 名称
                  _buildHeader(context, inkColor, borderColor, symbol, isDark),
                  // 分隔线（与桌面端完全一致）
                  _buildDivider(borderColor),
                  // 描述
                  _buildDescription(context, inkColor, isDark),
                  // 属性区域
                  if (_hasAttributes) ...[
                    const SizedBox(height: 10),
                    _buildAttributes(context, borderColor, isDark),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建头部（符号 + 名称）- 与桌面端完全一致
  Widget _buildHeader(BuildContext context, Color inkColor, Color borderColor, String symbol, bool isDark) {
    return Row(
      children: [
        // 符号（与桌面端一致的阴影）
        Text(
          symbol,
          style: TextStyle(
            color: borderColor,
            fontSize: 14,
            shadows: isDark
                ? null
                : [
                    const Shadow(color: Colors.white, blurRadius: 3),
                    Shadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 6),
                  ],
          ),
        ),
        const SizedBox(width: 6),
        // 名称（与桌面端一致的阴影）
        Expanded(
          child: Text(
            skill.name,
            style: TextStyle(
              color: inkColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              shadows: isDark
                  ? null
                  : [
                      const Shadow(color: Colors.white, blurRadius: 4),
                      Shadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 8),
                      Shadow(color: Colors.white.withValues(alpha: 0.7), blurRadius: 12),
                    ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建分隔线（与桌面端完全一致）
  Widget _buildDivider(Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              borderColor.withValues(alpha: 0),
              borderColor.withValues(alpha: 0.4),
              borderColor.withValues(alpha: 0.4),
              borderColor.withValues(alpha: 0),
            ],
            stops: const [0, 0.2, 0.8, 1],
          ),
        ),
      ),
    );
  }

  /// 构建描述文本（与桌面端一致的阴影）
  Widget _buildDescription(BuildContext context, Color inkColor, bool isDark) {
    return Text(
      skill.description,
      style: TextStyle(
        color: inkColor,
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w500,
        shadows: isDark
            ? null
            : [
                const Shadow(color: Colors.white, blurRadius: 4),
                Shadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 8),
                Shadow(color: Colors.white.withValues(alpha: 0.7), blurRadius: 12),
              ],
      ),
    );
  }

  /// 是否有属性需要显示
  bool get _hasAttributes =>
      skill.cooldown != null ||
      skill.damage != null ||
      skill.range != null ||
      skill.special != null;

  /// 构建属性区域（与桌面端完全一致）
  Widget _buildAttributes(BuildContext context, Color accentColor, bool isDark) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final statItems = <Widget>[];

    if (skill.cooldown != null) {
      statItems.add(
        _buildStatItem(
          Icons.timer_outlined,
          '冷却',
          '${_formatNumber(skill.cooldown!)}s',
          CharacterGalleryTheme.getCooldownColor(context),
          isDark,
        ),
      );
    }

    if (skill.damage != null && skill.damage!.isNotEmpty) {
      statItems.add(
        _buildStatItem(
          Icons.flash_on,
          '伤害',
          skill.damage!,
          CharacterGalleryTheme.getDamageColor(context),
          isDark,
        ),
      );
    }

    if (skill.range != null && skill.range!.isNotEmpty) {
      statItems.add(
        _buildStatItem(
          Icons.radar,
          '范围',
          skill.range!,
          scrollBrown,
          isDark,
        ),
      );
    }

    if (skill.special != null && skill.special!.isNotEmpty) {
      statItems.add(
        _buildStatItem(
          Icons.auto_awesome,
          '特殊',
          skill.special!,
          CharacterGalleryTheme.getSpecialColor(context),
          isDark,
        ),
      );
    }

    return Wrap(spacing: 12, runSpacing: 6, children: statItems);
  }

  /// 构建单个属性项（与桌面端完全一致）
  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
          shadows: isDark
              ? null
              : [
                  const Shadow(color: Colors.white, blurRadius: 3),
                  Shadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 6),
                ],
        ),
        const SizedBox(width: 4),
        Text(
          '$label:',
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            shadows: isDark
                ? null
                : [
                    const Shadow(color: Colors.white, blurRadius: 3),
                    Shadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 6),
                  ],
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            shadows: isDark
                ? null
                : [
                    const Shadow(color: Colors.white, blurRadius: 3),
                    Shadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 6),
                  ],
          ),
        ),
      ],
    );
  }

  /// 格式化数值：整数不显示小数点
  String _formatNumber(num value) {
    if (value is int) return value.toString();
    final d = value as double;
    if (d == d.truncateToDouble()) return d.toInt().toString();
    return d.toString();
  }
}
