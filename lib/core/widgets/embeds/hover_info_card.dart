import 'package:flutter/material.dart';

import '../../api/character_api.dart';
import '../../api/map_contribution_api.dart';
import '../../models/character_models.dart';
import '../../models/map_contribution_models.dart';
import '../../utils/log_service.dart';
import '../disk_cached_image.dart';
import '../map_background.dart';
import 'hover_info_block_embed.dart';

/// 悬浮引用详情卡片
///
/// 根据 [HoverInfoData] 渲染详情卡片。
/// 各类型异步拉取详情做增强展示：
/// - 地图：背景图 + 渐变遮罩 + 白字（同关联地图卡片风格）
/// - 角色：左侧大图 + 右侧名称/介绍
/// - 枪模/刀模：大预览图 + 名称/介绍
/// - 符卡：名称/描述/参数 + 预览图
class HoverInfoCard extends StatefulWidget {
  final HoverInfoData data;

  const HoverInfoCard({super.key, required this.data});

  @override
  State<HoverInfoCard> createState() => _HoverInfoCardState();
}

class _HoverInfoCardState extends State<HoverInfoCard> {
  // 各类型详情数据
  CharacterModel? _character;
  GunModel? _gunModel;
  KnifeModel? _knifeModel;
  MapInfo? _mapInfo;
  SpellCardTierItem? _spellCard;

  bool _loading = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    try {
      switch (widget.data.type) {
        case HoverInfoType.character:
          final id = int.tryParse(widget.data.id);
          if (id != null) {
            final character = await CharacterApi().getCharacterDetail(id);
            if (mounted) setState(() => _character = character);
          }
          break;
        case HoverInfoType.weapon:
          final id = int.tryParse(widget.data.id);
          if (id != null) {
            final gun = await CharacterApi().getGunModelDetail(id);
            if (mounted) setState(() => _gunModel = gun);
          }
          break;
        case HoverInfoType.knife:
          final id = int.tryParse(widget.data.id);
          if (id != null) {
            final knife = await CharacterApi().getKnifeModelDetail(id);
            if (mounted) setState(() => _knifeModel = knife);
          }
          break;
        case HoverInfoType.map:
          // 使用 MapContributionApi 搜索地图
          final resp = await MapContributionApi().getAllMaps(
            MapListRequest(
              pagination: const PaginationParams(pageIndex: 1, pageSize: 1),
              mapName: widget.data.id,
            ),
          );
          if (mounted && resp != null && resp.items.isNotEmpty) {
            setState(() => _mapInfo = resp.items.first);
          }
          break;
        case HoverInfoType.spellCard:
          // 符卡通过 tier list 搜索获取详情
          final id = int.tryParse(widget.data.id);
          if (id != null) {
            final resp = await CharacterApi().getSpellCardTierList(
              keyword: widget.data.label,
            );
            if (mounted && resp != null) {
              // 在结果中匹配 id
              for (final group in resp.tiers) {
                for (final card in group.spellCards) {
                  if (card.id == id) {
                    setState(() => _spellCard = card);
                    break;
                  }
                }
                if (_spellCard != null) break;
              }
            }
          }
          break;
      }
    } catch (e) {
      LogService.d('悬浮卡片加载详情失败: $e');
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = HoverInfoColors.color(widget.data.type);

    // 地图类型使用特殊卡片（背景图风格）
    if (widget.data.type == HoverInfoType.map && !_loading) {
      return _buildMapCard(isDark, color);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: _cardWidth,
          constraints: BoxConstraints(minHeight: 80, maxHeight: _cardMaxHeight),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildContent(isDark, color),
          ),
        ),
      ),
    );
  }

  double get _cardWidth {
    switch (widget.data.type) {
      case HoverInfoType.character:
        return 380;
      case HoverInfoType.weapon:
      case HoverInfoType.knife:
        return 360;
      case HoverInfoType.spellCard:
        return 380;
      case HoverInfoType.map:
        return 360;
    }
  }

  double get _cardMaxHeight {
    switch (widget.data.type) {
      case HoverInfoType.character:
        return 200;
      case HoverInfoType.weapon:
      case HoverInfoType.knife:
        return 220;
      case HoverInfoType.spellCard:
        return 280;
      case HoverInfoType.map:
        return 140;
    }
  }

  Widget _buildContent(bool isDark, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 头部：类型条
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          color: color.withValues(alpha: 0.12),
          child: Row(
            children: [
              Icon(HoverInfoColors.icon(widget.data.type), size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                _typeLabel(widget.data.type),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _buildBody(isDark, color),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(bool isDark, Color color) {
    if (_loading) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    switch (widget.data.type) {
      case HoverInfoType.character:
        return _buildCharacterBody(isDark, color);
      case HoverInfoType.weapon:
        return _buildGunModelBody(isDark, color);
      case HoverInfoType.knife:
        return _buildKnifeModelBody(isDark, color);
      case HoverInfoType.spellCard:
        return _buildSpellCardBody(isDark, color);
      case HoverInfoType.map:
        return _buildBasicBody(isDark, color);
    }
  }

  // ─── 角色卡片：左侧大图 + 右侧名称/介绍 ────────────────────────────────

  Widget _buildCharacterBody(bool isDark, Color color) {
    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1F2937);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    final imageUrl = _character?.thumbnailUrl ?? widget.data.iconUrl;
    final name = _character?.name ?? widget.data.label;
    final description = _character?.description;
    final nameEn = _character?.nameEn;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧大图
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 100,
            height: 130,
            child: imageUrl.isNotEmpty
                ? DiskCachedImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: _imagePlaceholder(color),
                    errorWidget: _imagePlaceholder(color),
                  )
                : _imagePlaceholder(color),
          ),
        ),
        const SizedBox(width: 12),
        // 右侧信息
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (nameEn != null && nameEn.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  nameEn,
                  style: TextStyle(fontSize: 12, color: subColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Flexible(
                  child: Text(
                    description,
                    style: TextStyle(fontSize: 12, height: 1.4, color: subColor),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─── 枪模卡片：大预览图 + 名称/介绍 ──────────────────────────────────

  Widget _buildGunModelBody(bool isDark, Color color) {
    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1F2937);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    final imageUrl = _gunModel?.preview?.front ??
        _gunModel?.thumbnailUrl ??
        widget.data.iconUrl;
    final name = _gunModel?.name ?? widget.data.label;
    final description = _gunModel?.description;
    final characterName = _gunModel?.characterName;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 大预览图
        if (imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: double.infinity,
              height: 100,
              child: DiskCachedImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: _imagePlaceholder(color),
                errorWidget: _imagePlaceholder(color),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Text(
          name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (characterName != null && characterName.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            '专属：$characterName',
            style: TextStyle(fontSize: 12, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              description,
              style: TextStyle(fontSize: 12, height: 1.4, color: subColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  // ─── 刀模卡片：大预览图 + 名称/介绍 ──────────────────────────────────

  Widget _buildKnifeModelBody(bool isDark, Color color) {
    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1F2937);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    final imageUrl = _knifeModel?.preview?.front ??
        _knifeModel?.thumbnailUrl ??
        widget.data.iconUrl;
    final name = _knifeModel?.name ?? widget.data.label;
    final description = _knifeModel?.description;
    final characterName = _knifeModel?.characterName;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 大预览图
        if (imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: double.infinity,
              height: 100,
              child: DiskCachedImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: _imagePlaceholder(color),
                errorWidget: _imagePlaceholder(color),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Text(
          name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (characterName != null && characterName.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            '专属：$characterName',
            style: TextStyle(fontSize: 12, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              description,
              style: TextStyle(fontSize: 12, height: 1.4, color: subColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }


  Widget _buildSpellCardBody(bool isDark, Color color) {
    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1F2937);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    if (_spellCard == null) return _buildBasicBody(isDark, color);

    final card = _spellCard!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 图标 + 名称 + 类型
        Row(
          children: [
            if (card.iconUrl != null && card.iconUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: DiskCachedImage(
                    imageUrl: card.iconUrl!,
                    fit: BoxFit.cover,
                    placeholder: _imagePlaceholder(color),
                    errorWidget: _imagePlaceholder(color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${card.characterName} · ${_spellCardTypeLabel(card.type)}',
                    style: TextStyle(fontSize: 11, color: subColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 评级标签
            if (card.tier != SpellCardTier.unranked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _tierColor(card.tier).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _tierColor(card.tier)),
                ),
                child: Text(
                  card.tier.shortLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _tierColor(card.tier),
                  ),
                ),
              ),
          ],
        ),
        // 描述
        if (card.description != null && card.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              card.description!,
              style: TextStyle(fontSize: 12, height: 1.4, color: subColor),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        // 参数行
        if (_hasSpellCardStats(card)) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (card.cooldown != null)
                _buildStat(Icons.timer_outlined, '冷却',
                    '${_formatNum(card.cooldown!)}s', const Color(0xFF2196F3)),
              if (card.damage != null && card.damage!.isNotEmpty)
                _buildStat(Icons.flash_on, '伤害', card.damage!,
                    const Color(0xFFFF5722)),
              if (card.cost != null)
                _buildStat(
                  Icons.local_fire_department,
                  card.type == SpellCardType.ultimate ? 'B点' : 'P点',
                  _formatNum(card.cost!),
                  card.type == SpellCardType.ultimate
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF8B5CF6),
                ),
            ],
          ),
        ],
      ],
    );
  }

  bool _hasSpellCardStats(SpellCardTierItem card) =>
      card.cooldown != null ||
      (card.damage != null && card.damage!.isNotEmpty) ||
      card.cost != null;

  Widget _buildStat(IconData icon, String label, String value, Color iconColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 3),
        Text(
          '$label $value',
          style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  String _formatNum(double v) {
    return v == v.toInt().toDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  Color _tierColor(SpellCardTier tier) {
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

  String _spellCardTypeLabel(SpellCardType type) {
    return switch (type) {
      SpellCardType.normal => '小符卡',
      SpellCardType.ultimate => '大符卡',
      SpellCardType.passive => '被动',
    };
  }

  // ─── 地图卡片（背景图 + 渐变遮罩 + 白字，同关联地图风格）─────────────────

  Widget _buildMapCard(bool isDark, Color color) {
    final hasMapInfo = _mapInfo != null;
    final hasBackground = hasMapInfo &&
        _mapInfo!.mapBackground != null &&
        _mapInfo!.mapBackground!.isNotEmpty;
    final mapLabel = _mapInfo?.mapLabel ?? widget.data.label;
    final mapName = _mapInfo?.mapName ?? widget.data.id;
    final hasDifferentLabel = mapLabel != mapName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 360,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 头部：类型条
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  color: color.withValues(alpha: 0.12),
                  child: Row(
                    children: [
                      Icon(HoverInfoColors.icon(HoverInfoType.map),
                          size: 14, color: color),
                      const SizedBox(width: 6),
                      Text(
                        '地图',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // 地图背景区域
                SizedBox(
                  height: 100,
                  child: Stack(
                    children: [
                      // 背景图
                      if (hasBackground)
                        Positioned.fill(
                          child: MapBackground(
                            mapName: mapName,
                            imageUrl: _mapInfo!.mapBackground,
                            fit: BoxFit.cover,
                            cacheWidth: 800,
                          ),
                        )
                      else
                        Positioned.fill(
                          child: Container(
                            color: isDark
                                ? const Color(0xFF1F2A3D)
                                : const Color(0xFF2D3748),
                          ),
                        ),
                      // 渐变遮罩
                      if (hasBackground)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.3),
                                  Colors.black.withValues(alpha: 0.5),
                                  Colors.black.withValues(alpha: 0.8),
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                        ),
                      // 内容
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.translate,
                                    size: 14,
                                    color:
                                        Colors.white.withValues(alpha: 0.95),
                                    shadows: const [
                                      Shadow(
                                          color: Colors.black54,
                                          blurRadius: 4),
                                    ],
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      mapLabel,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                              color: Colors.black54,
                                              blurRadius: 4),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (hasDifferentLabel) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.map_outlined,
                                      size: 12,
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      shadows: const [
                                        Shadow(
                                            color: Colors.black54,
                                            blurRadius: 4),
                                      ],
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        mapName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white
                                              .withValues(alpha: 0.78),
                                          shadows: const [
                                            Shadow(
                                                color: Colors.black54,
                                                blurRadius: 4),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── 基础卡片（兜底） ─────────────────────────────────────────────────

  Widget _buildBasicBody(bool isDark, Color color) {
    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1F2937);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (widget.data.iconUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: DiskCachedImage(
                    imageUrl: widget.data.iconUrl,
                    fit: BoxFit.cover,
                    placeholder: _imagePlaceholder(color),
                    errorWidget: _imagePlaceholder(color),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                widget.data.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (_loadFailed) ...[
          const SizedBox(height: 6),
          Text(
            '详情加载失败',
            style: TextStyle(fontSize: 12, color: subColor),
          ),
        ],
      ],
    );
  }

  Widget _imagePlaceholder(Color color) {
    return Container(
      color: color.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          HoverInfoColors.icon(widget.data.type),
          size: 24,
          color: color.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  String _typeLabel(HoverInfoType type) {
    switch (type) {
      case HoverInfoType.map:
        return '地图';
      case HoverInfoType.character:
        return '角色';
      case HoverInfoType.weapon:
        return '枪模';
      case HoverInfoType.knife:
        return '刀模';
      case HoverInfoType.spellCard:
        return '符卡';
    }
  }
}
