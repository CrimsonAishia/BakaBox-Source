import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/character_models.dart';
import '../../../core/constants/app_colors.dart';
import 'character_gallery_theme.dart';

/// 模型作者信息标签区域（包含来源、投稿者、模型作者）
class ModelAuthorTagsSection extends StatelessWidget {
  final ModelAuthorMetadata model;
  final WrapAlignment alignment;

  const ModelAuthorTagsSection({
    super.key,
    required this.model,
    this.alignment = WrapAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    if ((model.source == null || model.source!.isEmpty) &&
        (model.provider == null || model.provider!.isEmpty) &&
        (model.modeler == null || model.modeler!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: alignment == WrapAlignment.start
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: alignment,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (model.source != null && model.source!.isNotEmpty)
                _buildSourceTag(context, model.source!),
              if (model.provider != null && model.provider!.isNotEmpty)
                _ProviderTag(
                  provider: model.provider!,
                  steamId: model.providerSteamid,
                ),
              if (model.modeler != null && model.modeler!.isNotEmpty)
                _ModelerTag(
                  modeler: model.modeler!,
                  steamId: model.modelerSteamid,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 1. 来源 (Source) - 左右拼接风格
  Widget _buildSourceTag(BuildContext context, String value) {
    final color = AppColors.skillGreen;
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: CharacterGalleryTheme.getWashiColor(context),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(2.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                const Text(
                  '来源',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelerTag extends StatefulWidget {
  final String modeler;
  final String? steamId;

  const _ModelerTag({required this.modeler, this.steamId});

  @override
  State<_ModelerTag> createState() => _ModelerTagState();
}

class _ModelerTagState extends State<_ModelerTag> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = CharacterGalleryTheme.getGold(context);
    final tagWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 24,
      decoration: BoxDecoration(
        color: _isHovered
            ? color.withValues(alpha: 0.1)
            : CharacterGalleryTheme.getWashiColor(context),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(4),
        boxShadow: _isHovered
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(1, 1),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(2.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.brush_outlined, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                const Text(
                  '模型作者',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                widget.modeler,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.steamId == null || widget.steamId!.isEmpty) {
      return tagWidget;
    }

    return Tooltip(
      message: '联系模型作者',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: () async {
            final url = Uri.parse('steam://url/SteamIDPage/${widget.steamId}');
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            } else {
              final webUrl = Uri.parse(
                'https://steamcommunity.com/profiles/${widget.steamId}',
              );
              if (await canLaunchUrl(webUrl)) {
                await launchUrl(webUrl);
              }
            }
          },
          child: tagWidget,
        ),
      ),
    );
  }
}

class _ProviderTag extends StatefulWidget {
  final String provider;
  final String? steamId;

  const _ProviderTag({required this.provider, this.steamId});

  @override
  State<_ProviderTag> createState() => _ProviderTagState();
}

class _ProviderTagState extends State<_ProviderTag> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = CharacterGalleryTheme.getVermillion(context);
    final tagWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 24,
      decoration: BoxDecoration(
        color: _isHovered
            ? color.withValues(alpha: 0.1)
            : CharacterGalleryTheme.getWashiColor(context),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(4),
        boxShadow: _isHovered
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(1, 1),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(2.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_outline, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                const Text(
                  '投稿者',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                widget.provider,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.steamId == null || widget.steamId!.isEmpty) {
      return tagWidget;
    }

    return Tooltip(
      message: '联系投稿者',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: () async {
            final url = Uri.parse('steam://url/SteamIDPage/${widget.steamId}');
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            } else {
              final webUrl = Uri.parse(
                'https://steamcommunity.com/profiles/${widget.steamId}',
              );
              if (await canLaunchUrl(webUrl)) {
                await launchUrl(webUrl);
              }
            }
          },
          child: tagWidget,
        ),
      ),
    );
  }
}

/// 活动解锁条件徽章
class ModelOtherCheckBadge extends StatelessWidget {
  final ModelAuthorMetadata model;

  const ModelOtherCheckBadge({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    if (model.othercheckKeyName == null || model.othercheckKeyName!.isEmpty) {
      return const SizedBox.shrink();
    }

    // 使用自定义来源（活动）颜色来突显解锁条件
    final color = CharacterGalleryTheme.getCustomSourceColor(context);
    // 与金/点统一印章风格，自适应宽度
    return Container(
      constraints: const BoxConstraints(minWidth: 44, maxWidth: 74),
      height: 44,
      decoration: BoxDecoration(
        color: CharacterGalleryTheme.getWashiColor(context),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 22,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.card_giftcard_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    model.othercheckKeyName ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  '${model.othercheckPoint ?? 0}',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分组徽章
class ModelGroupBadge extends StatelessWidget {
  final ModelAuthorMetadata model;

  const ModelGroupBadge({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    if (model.groupName == null || model.groupName!.isEmpty) {
      return const SizedBox.shrink();
    }

    // 使用特定颜色突显分组
    final color = CharacterGalleryTheme.getSpecialColor(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 44, maxWidth: 74),
      height: 44,
      decoration: BoxDecoration(
        color: CharacterGalleryTheme.getWashiColor(context),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 22,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.military_tech_outlined,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      model.groupName ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  model.group ?? '',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 捐助者徽章
class ModelViplevelBadge extends StatelessWidget {
  final ModelAuthorMetadata model;

  const ModelViplevelBadge({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    if (model.viplevel == null || model.viplevel! <= 0) {
      return const SizedBox.shrink();
    }

    final color = CharacterGalleryTheme.sakuraPink;

    return Container(
      constraints: const BoxConstraints(minWidth: 44, maxWidth: 74),
      height: 44,
      decoration: BoxDecoration(
        color: CharacterGalleryTheme.getWashiColor(context),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 22,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.volunteer_activism, size: 12, color: Colors.white),
                  SizedBox(width: 2),
                  Text(
                    '捐助者',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  '捐助者 Lv.${model.viplevel}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
