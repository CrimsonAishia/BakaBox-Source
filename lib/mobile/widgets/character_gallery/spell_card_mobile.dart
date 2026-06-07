import 'package:flutter/material.dart';

import '../../../core/models/character_models.dart';
import '../../../desktop/widgets/character_gallery/character_gallery_theme.dart';

/// 移动端符卡卡片组件 - 与桌面端完全一致的设计
///
/// 使用符卡背景图片和符号装饰，显示符卡名称、描述、属性和评级。
/// 支持不同符卡类型（被动、大符卡、小符卡）的视觉区分。
///
/// **Validates: Requirements 5.2, 5.3**
class SpellCardMobile extends StatelessWidget {
  /// 符卡数据
  final SpellCard spellCard;

  const SpellCardMobile({super.key, required this.spellCard});

  /// 获取符卡类型对应的样式配置（与桌面端一致）
  (Color borderColor, Color bgColor, String symbol, String bgAsset)
  _getTypeStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final gold = CharacterGalleryTheme.getGold(context);

    return switch (spellCard.type) {
      SpellCardType.passive => (
        const Color(0xFF4A7C59),
        const Color(0xFF4A7C59).withValues(alpha: isDark ? 0.15 : 0.08),
        '✦',
        'assets/images/character_gallery/spell_card_bg_passive.png',
      ),
      SpellCardType.ultimate => (
        gold,
        gold.withValues(alpha: isDark ? 0.15 : 0.08),
        '◈',
        'assets/images/character_gallery/spell_card_bg_ultimate.png',
      ),
      SpellCardType.normal => (
        vermillion,
        vermillion.withValues(alpha: isDark ? 0.12 : 0.06),
        '✧',
        'assets/images/character_gallery/spell_card_bg_normal.png',
      ),
    };
  }

  /// 获取评级颜色（与桌面端一致）
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
            // 渐变蒙版（顶部透明 → 底部加深，让属性行落在清晰区域）
            Positioned.fill(
              child: DecoratedBox(
                decoration:
                    CharacterGalleryTheme.getCardBottomGradientDecoration(
                      context,
                    ),
              ),
            ),
            // 内容层
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题行：符号 + 名称 + 评级
                  _buildHeader(context, inkColor, borderColor, symbol, isDark),
                  // 分隔线（与桌面端一致）
                  _buildDivider(borderColor),
                  // 描述
                  _buildDescription(context, inkColor, isDark),
                  // 属性区域
                  if (_hasAttributes) ...[
                    const SizedBox(height: 10),
                    _buildAttributes(context, isDark),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建头部（符号 + 名称 + 评级）- 与桌面端完全一致
  Widget _buildHeader(
    BuildContext context,
    Color inkColor,
    Color borderColor,
    String symbol,
    bool isDark,
  ) {
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
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      blurRadius: 6,
                    ),
                  ],
          ),
        ),
        const SizedBox(width: 6),
        // 名称（与桌面端一致的阴影）
        Expanded(
          child: Text(
            spellCard.name,
            style: TextStyle(
              color: inkColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              shadows: isDark
                  ? null
                  : [
                      const Shadow(color: Colors.white, blurRadius: 4),
                      Shadow(
                        color: Colors.white.withValues(alpha: 0.9),
                        blurRadius: 8,
                      ),
                      Shadow(
                        color: Colors.white.withValues(alpha: 0.7),
                        blurRadius: 12,
                      ),
                    ],
            ),
          ),
        ),
        // 评级标签（与桌面端一致）
        if (spellCard.tier != null && spellCard.tier != SpellCardTier.unranked)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withValues(
                alpha: 0.85,
              ),
              border: Border.all(color: _getTierColor(spellCard.tier!)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              spellCard.tier!.shortLabel,
              style: TextStyle(
                color: _getTierColor(spellCard.tier!),
                fontSize: 10,
                fontWeight: FontWeight.bold,
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
              borderColor.withValues(alpha: 0.5),
              borderColor.withValues(alpha: 0.5),
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
      spellCard.description,
      style: TextStyle(
        color: inkColor,
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w500,
        shadows: isDark
            ? null
            : [
                const Shadow(color: Colors.white, blurRadius: 4),
                Shadow(
                  color: Colors.white.withValues(alpha: 0.9),
                  blurRadius: 8,
                ),
                Shadow(
                  color: Colors.white.withValues(alpha: 0.7),
                  blurRadius: 12,
                ),
              ],
      ),
    );
  }

  /// 是否有属性需要显示
  bool get _hasAttributes =>
      spellCard.cooldown != null ||
      spellCard.damage != null ||
      spellCard.cost != null ||
      spellCard.speed != null ||
      spellCard.count != null ||
      spellCard.angle != null ||
      spellCard.puncture != null ||
      spellCard.bounce != null ||
      spellCard.explode != null ||
      spellCard.holdTime != null ||
      spellCard.trackSpeed != null ||
      spellCard.customCd != null;

  /// 构建属性区域
  Widget _buildAttributes(BuildContext context, bool isDark) {
    final statItems = <Widget>[];

    // 冷却时间
    if (spellCard.cooldown != null) {
      statItems.add(
        _buildStatItem(
          Icons.timer_outlined,
          '冷却',
          '${_formatNumber(spellCard.cooldown!)}s',
          CharacterGalleryTheme.getCooldownColor(context),
          isDark,
        ),
      );
    }

    // 伤害
    if (spellCard.damage != null && spellCard.damage!.isNotEmpty) {
      statItems.add(
        _buildStatItem(
          Icons.flash_on,
          '伤害',
          spellCard.damage!,
          CharacterGalleryTheme.getDamageColor(context),
          isDark,
        ),
      );
    }

    // 消耗（根据符卡类型显示P点或B点）
    if (spellCard.cost != null) {
      final isUltimate = spellCard.type == SpellCardType.ultimate;
      statItems.add(
        _buildStatItem(
          Icons.local_fire_department,
          isUltimate ? 'B点' : 'P点',
          _formatNumber(spellCard.cost!),
          isUltimate
              ? CharacterGalleryTheme.getBCostColor(context)
              : CharacterGalleryTheme.getPCostColor(context),
          isDark,
        ),
      );
    }

    if (spellCard.speed != null) {
      statItems.add(_buildStatItem(Icons.speed, '弹幕初速',
          _formatNumber(spellCard.speed!),
          CharacterGalleryTheme.getSpeedColor(context), isDark));
    }
    if (spellCard.count != null) {
      statItems.add(_buildStatItem(Icons.scatter_plot, '弹幕数量',
          spellCard.count!.toString(),
          CharacterGalleryTheme.getCountColor(context), isDark));
    }
    if (spellCard.angle != null) {
      statItems.add(_buildStatItem(Icons.architecture, '散射角度',
          '${_formatNumber(spellCard.angle!)}°',
          CharacterGalleryTheme.getAngleColor(context), isDark));
    }
    if (spellCard.puncture != null) {
      statItems.add(_buildStatItem(Icons.swap_horiz, '穿刺次数',
          spellCard.puncture!.toString(),
          CharacterGalleryTheme.getPunctureColor(context), isDark));
    }
    if (spellCard.bounce != null) {
      statItems.add(_buildStatItem(Icons.replay, '反弹次数',
          spellCard.bounce!.toString(),
          CharacterGalleryTheme.getBounceColor(context), isDark));
    }
    if (spellCard.explode != null) {
      statItems.add(_buildStatItem(Icons.brightness_5, '影响范围',
          _formatNumber(spellCard.explode!),
          CharacterGalleryTheme.getExplodeColor(context), isDark));
    }
    if (spellCard.holdTime != null) {
      statItems.add(_buildStatItem(Icons.hourglass_bottom, '持续时间',
          '${_formatNumber(spellCard.holdTime!)}s',
          CharacterGalleryTheme.getHoldTimeColor(context), isDark));
    }
    if (spellCard.trackSpeed != null) {
      statItems.add(_buildStatItem(Icons.gps_fixed, '追踪转向',
          _formatNumber(spellCard.trackSpeed!),
          CharacterGalleryTheme.getTrackSpeedColor(context), isDark));
    }
    if (spellCard.customCd != null) {
      statItems.add(_buildStatItem(Icons.settings, '内置CD',
          '${_formatNumber(spellCard.customCd!)}s',
          CharacterGalleryTheme.getCustomCdColor(context), isDark));
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
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.8),
                    blurRadius: 6,
                  ),
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
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      blurRadius: 6,
                    ),
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
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      blurRadius: 6,
                    ),
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
