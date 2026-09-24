import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/models/character_models.dart';
import '../../../desktop/widgets/character_gallery/character_gallery_theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/rich_text_viewer.dart';
import '../../../desktop/widgets/character_gallery/video_embed_dialog.dart';
import '../../../core/widgets/image_viewer_dialog.dart';

/// 移动端僵尸技能卡片组件
class ZombieSkillCardMobile extends StatelessWidget {
  /// 僵尸技能数据
  final ZombieSkill skill;

  const ZombieSkillCardMobile({super.key, required this.skill});

  /// 获取技能类型对应的样式配置
  (Color borderColor, Color bgColor, String symbol, String bgAsset)
  _getTypeStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final isPassive = skill.type == ZombieSkillType.passive;

    // 被动用绿色和被动背景，主动用朱红和大符卡背景
    return isPassive
        ? (
            AppColors.skillGreen,
            AppColors.skillGreen.withValues(alpha: isDark ? 0.15 : 0.08),
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

    return GestureDetector(
      onTap: () => _handlePreviewTap(context),
      child: Container(
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
              // 背景图层
              Positioned.fill(
                child: Image.asset(
                  bgAsset,
                  fit: BoxFit.cover,
                  opacity: AlwaysStoppedAnimation(isDark ? 0.3 : 0.6),
                ),
              ),
              // 渐变蒙版
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
                    // 标题行：符号 + 名称
                    _buildHeader(
                      context,
                      inkColor,
                      borderColor,
                      symbol,
                      isDark,
                    ),
                    // 分隔线
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
              // 右上角预览指示器
              if (skill.previewType != PreviewType.none)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      _getPreviewIcon(),
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPreviewIcon() {
    return switch (skill.previewType) {
      PreviewType.image => Icons.photo_outlined,
      PreviewType.videoUrl || PreviewType.video => Icons.play_circle_outline,
      PreviewType.none => Icons.visibility,
    };
  }

  void _handlePreviewTap(BuildContext context) {
    if (skill.previewType == PreviewType.none) return;

    if (skill.previewType == PreviewType.image &&
        skill.previewImageUrl != null &&
        skill.previewImageUrl!.isNotEmpty) {
      ImageViewerDialog.show(
        context,
        imageUrls: [skill.previewImageUrl!],
        initialIndex: 0,
      );
      return;
    }

    if ((skill.previewType == PreviewType.videoUrl ||
            skill.previewType == PreviewType.video) &&
        skill.previewVideoUrl != null &&
        skill.previewVideoUrl!.isNotEmpty) {
      if (!VideoEmbedDialog.canEmbed(
        skill.previewVideoUrl!,
        videoUrlSource: skill.videoUrlSource,
      )) {
        return;
      }
      showDialog(
        context: context,
        builder: (_) => VideoEmbedDialog(
          videoUrl: skill.previewVideoUrl!,
          videoUrlSource: skill.videoUrlSource,
          videoOriginUrl: skill.previewVideoOrigin,
        ),
      );
    }
  }

  /// 构建头部（符号 + 名称）
  Widget _buildHeader(
    BuildContext context,
    Color inkColor,
    Color borderColor,
    String symbol,
    bool isDark,
  ) {
    return Row(
      children: [
        // 符号
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
        // 名称
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
      ],
    );
  }

  /// 构建分隔线
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

  /// 构建描述文本
  Widget _buildDescription(BuildContext context, Color inkColor, bool isDark) {
    return RichTextViewer(
      content: skill.description,
      compact: true,
      textStyle: TextStyle(
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
      skill.cooldown != null ||
      skill.damage != null ||
      skill.cost != null ||
      skill.speed != null ||
      skill.count != null ||
      skill.angle != null ||
      skill.puncture != null ||
      skill.bounce != null ||
      skill.explode != null ||
      skill.holdTime != null ||
      skill.trackSpeed != null ||
      skill.customCd != null;

  /// 构建属性区域
  Widget _buildAttributes(
    BuildContext context,
    Color accentColor,
    bool isDark,
  ) {
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

    if (skill.cost != null) {
      statItems.add(
        _buildStatItem(
          Icons.local_fire_department,
          '能量',
          _formatNumber(skill.cost!),
          CharacterGalleryTheme.getBCostColor(context),
          isDark,
        ),
      );
    }

    if (skill.speed != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.speedometer,
          '弹幕初速',
          _formatNumber(skill.speed!),
          CharacterGalleryTheme.getSpeedColor(context),
          isDark,
        ),
      );
    }

    if (skill.count != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.counter,
          '弹幕数量',
          _formatNumber(skill.count!),
          CharacterGalleryTheme.getCountColor(context),
          isDark,
        ),
      );
    }

    if (skill.angle != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.angleAcute,
          '散射角度',
          '${_formatNumber(skill.angle!)}°',
          CharacterGalleryTheme.getAngleColor(context),
          isDark,
        ),
      );
    }

    if (skill.puncture != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.arrowExpandHorizontal,
          '穿刺次数',
          _formatNumber(skill.puncture!),
          CharacterGalleryTheme.getPunctureColor(context),
          isDark,
        ),
      );
    }

    if (skill.bounce != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.arrowUDownLeft,
          '反弹次数',
          _formatNumber(skill.bounce!),
          CharacterGalleryTheme.getBounceColor(context),
          isDark,
        ),
      );
    }

    if (skill.explode != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.weatherSunny,
          '影响范围',
          _formatNumber(skill.explode!),
          CharacterGalleryTheme.getExplodeColor(context),
          isDark,
        ),
      );
    }

    if (skill.holdTime != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.timerSand,
          '持续时间',
          '${_formatNumber(skill.holdTime!)}s',
          CharacterGalleryTheme.getHoldTimeColor(context),
          isDark,
        ),
      );
    }

    if (skill.trackSpeed != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.crosshairs,
          '追踪转向',
          _formatNumber(skill.trackSpeed!),
          CharacterGalleryTheme.getTrackSpeedColor(context),
          isDark,
        ),
      );
    }

    if (skill.customCd != null) {
      statItems.add(
        _buildStatItem(
          MdiIcons.cog,
          '内置CD',
          '${_formatNumber(skill.customCd!)}s',
          CharacterGalleryTheme.getCustomCdColor(context),
          isDark,
        ),
      );
    }

    return Wrap(spacing: 12, runSpacing: 6, children: statItems);
  }

  /// 构建单个属性项
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
