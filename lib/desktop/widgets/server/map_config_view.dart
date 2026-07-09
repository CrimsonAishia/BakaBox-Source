import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/map_config_api.dart';
import '../../../core/models/map_config_models.dart';
import '../../../core/api/guide_api.dart';
import '../../../core/models/guide_models.dart';
import '../../../core/utils/storage_utils.dart';
import '../../../core/widgets/tag_color_picker.dart';
import '../guide/community_guide/community_guide_card.dart';
import '../guide/community_guide/community_guide_format.dart';
import '../guide/community_guide/community_guide_theme.dart';
import '../guide/community_guide/community_guide_close_button.dart';
import '../guide/guide_detail_view.dart';

/// 地图配置 Tag 背景颜色持久化 Key
const String _kMapConfigKeyBgStorageKey = 'map_config_tag_key_bg';
const String _kMapConfigValueBgStorageKey = 'map_config_tag_value_bg';

/// 属性完全相同的启用实体集群
class _EntityCluster {
  _EntityCluster({required this.signature});

  final String signature;
  final List<MapConfigEntity> entities = <MapConfigEntity>[];

  MapConfigEntity get primary => entities.first;
  List<MapConfigProperty> get sharedAttributes => primary.attributes;
}

class MapConfigView extends StatefulWidget {
  final String mapName;
  final bool isDark;

  const MapConfigView({super.key, required this.mapName, required this.isDark});

  @override
  State<MapConfigView> createState() => _MapConfigViewState();
}

class _MapConfigViewState extends State<MapConfigView> {
  bool _isLoading = true;
  String? _error;
  MapConfigResponse? _configResponse;

  List<GuideListItem> _guides = [];
  bool _isLoadingGuide = true;
  String? _guideError;

  final ScrollController _scrollController = ScrollController();
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, GlobalKey> _propertyKeys = {};

  // 用户自定义标签背景色（hex 字符串，如 '#3B82F6'）；null 表示使用默认样式
  String? _keyBgHex;
  String? _valueBgHex;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicators);
    _searchController.addListener(_onSearchChanged);
    _loadTagColorSettings();
    _fetchConfigs();
    _fetchGuide();
  }

  void _loadTagColorSettings() {
    _keyBgHex = StorageUtils.getString(_kMapConfigKeyBgStorageKey);
    _valueBgHex = StorageUtils.getString(_kMapConfigValueBgStorageKey);
  }

  Future<void> _updateKeyBgColor(String? hex) async {
    setState(() => _keyBgHex = hex);
    if (hex == null) {
      await StorageUtils.remove(_kMapConfigKeyBgStorageKey);
    } else {
      await StorageUtils.setString(_kMapConfigKeyBgStorageKey, hex);
    }
  }

  Future<void> _updateValueBgColor(String? hex) async {
    setState(() => _valueBgHex = hex);
    if (hex == null) {
      await StorageUtils.remove(_kMapConfigValueBgStorageKey);
    } else {
      await StorageUtils.setString(_kMapConfigValueBgStorageKey, hex);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
      });
      _scrollToFirstMatch(query);
    }
  }

  void _scrollToFirstMatch(String query) {
    if (query.isEmpty || _configResponse == null) return;
    for (final category in _configResponse!.categories) {
      for (final entity in category.entities) {
        final entityMatched = entity.name.toLowerCase().contains(query);

        // 找到第一个匹配的属性（若有）
        MapConfigProperty? firstAttrMatch;
        for (final a in entity.attributes) {
          if (a.key.toLowerCase().contains(query) ||
              a.value.toLowerCase().contains(query)) {
            firstAttrMatch = a;
            break;
          }
        }

        if (!entityMatched && firstAttrMatch == null) continue;

        // 禁用实体：只在底部胶囊有 key（实体级）；无论是否有属性
        // 启用实体：如果有属性匹配 → attr 级 key；否则退回第一个属性或匿名回退
        final String candidateId;
        if (!entity.enabled) {
          candidateId = '${category.category}_${entity.name}_';
        } else if (firstAttrMatch != null) {
          candidateId =
              '${category.category}_${entity.name}_${firstAttrMatch.key}';
        } else if (entity.attributes.isNotEmpty) {
          candidateId =
              '${category.category}_${entity.name}_${entity.attributes.first.key}';
        } else {
          candidateId = '${category.category}_${entity.name}_';
        }

        final key = _propertyKeys[candidateId];
        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
          return;
        }
      }
    }
  }

  void _updateScrollIndicators() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canUp = position.pixels > 0;
    final canDown = position.pixels < position.maxScrollExtent;
    if (canUp != _canScrollUp || canDown != _canScrollDown) {
      setState(() {
        _canScrollUp = canUp;
        _canScrollDown = canDown;
      });
    }
  }

  Future<void> _fetchGuide() async {
    try {
      final response = await GuideApi().getGuides(
        query: GuideListQuery(mapName: widget.mapName, pageSize: 6),
      );
      if (mounted) {
        setState(() {
          _guides = response.items;
          _isLoadingGuide = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _guideError = '获取攻略失败';
          _isLoadingGuide = false;
        });
      }
    }
  }

  Future<void> _fetchConfigs() async {
    try {
      final response = await MapConfigApi.getMapConfigs(widget.mapName);
      if (mounted) {
        setState(() {
          _configResponse = response;
          _isLoading = false;
          // 新数据到达，清理旧的 propertyKeys 与 cluster 别名
          _propertyKeys.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '获取地图配置失败';
          _isLoading = false;
        });
      }
    }
  }

  Color get _bgColor =>
      widget.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F7FA);
  Color get _cardColor =>
      widget.isDark ? const Color(0xFF2D2D2D) : Colors.white;
  Color get _textColor =>
      widget.isDark ? Colors.white : const Color(0xFF2C3E50);
  Color get _subTextColor =>
      widget.isDark ? Colors.white70 : const Color(0xFF7F8C8D);
  Color get _accentColor =>
      widget.isDark ? const Color(0xFF64B5F6) : const Color(0xFF3498DB);
  Color get _borderColor =>
      widget.isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollIndicators();
    });

    return Material(
      color: _bgColor,
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildSectionTitle('地图配置参数', Icons.tune_rounded),
                    const Spacer(),
                    _buildSearchBar(),
                    const SizedBox(width: 8),
                    _buildPaletteButton(),
                  ],
                ),
                const SizedBox(height: 16),
                _buildConfigContent(),
                const SizedBox(height: 16),
                _buildSectionTitle('地图攻略', Icons.menu_book_rounded),
                const SizedBox(height: 16),
                _buildGuidePlaceholder(),
              ],
            ),
          ),
          if (_canScrollUp)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildScrollIndicator(isTop: true),
            ),
          if (_canScrollDown)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildScrollIndicator(isTop: false),
            ),
        ],
      ),
    );
  }

  Widget _buildScrollIndicator({required bool isTop}) {
    final iconColor = (widget.isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.3,
    );
    return IgnorePointer(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              _bgColor,
              _bgColor.withValues(alpha: 0.8),
              _bgColor.withValues(alpha: 0),
            ],
          ),
        ),
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(top: isTop ? 4 : 0, bottom: isTop ? 0 : 4),
          child: Icon(
            isTop
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: iconColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 200,
      height: 36,
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: _textColor, fontSize: 13),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: '搜索属性...',
          hintStyle: TextStyle(color: _subTextColor, fontSize: 13, height: 1.0),
          prefixIcon: Icon(Icons.search_rounded, size: 16, color: _subTextColor),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 14, color: _subTextColor),
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                )
              : null,
          suffixIconConstraints: _searchQuery.isNotEmpty 
              ? const BoxConstraints(minWidth: 36, minHeight: 36)
              : const BoxConstraints(minWidth: 12, minHeight: 36), // Right padding when no icon
          contentPadding: EdgeInsets.zero,
          isDense: true,
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _accentColor, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            color: _textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildConfigContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState(_error!);
    }

    if (_configResponse == null || _configResponse!.categories.isEmpty) {
      return _buildEmptyState(
        text: '当前地图采用默认配置',
        icon: Icons.check_circle_outline_rounded,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _configResponse!.categories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          final isLast = index == _configResponse!.categories.length - 1;
          return _buildCategorySection(category, isLast);
        }).toList(),
      ),
    );
  }

  Widget _buildCategorySection(MapConfigCategory category, bool isLast) {
    IconData iconData = Icons.category_rounded;
    String? categoryColor;

    // 匹配项目中的符卡和特定类型颜色
    if (category.category.contains('大符卡')) {
      iconData = Icons.star_rounded;
      categoryColor = '#F1C40F'; // Gold
    } else if (category.category.contains('小符卡') ||
        category.category.contains('符卡')) {
      iconData = Icons.style_rounded;
      categoryColor = '#E74C3C'; // Vermilion
    } else if (category.category.contains('被动')) {
      iconData = Icons.auto_awesome_rounded;
      categoryColor = '#2ECC71'; // Green
    } else if (category.category.contains('武器')) {
      iconData = Icons.hardware_rounded;
    } else if (category.category.contains('机制')) {
      iconData = Icons.settings_applications_rounded;
    }

    Color iconColor = categoryColor != null
        ? Color(int.parse(categoryColor.replaceFirst('#', '0xFF')))
        : _accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(
            left: 16,
            top: 16,
            right: 16,
            bottom: 12,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(iconData, size: 16, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.category,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Entities
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: _buildCategoryBody(category, categoryColor),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: _borderColor,
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }

  /// 分类内容体：拆分为「匿名属性 / 命名实体块 / 纯禁用实体条」三段
  Widget _buildCategoryBody(MapConfigCategory category, String? categoryColor) {
    if (category.entities.isEmpty) {
      return const SizedBox.shrink();
    }

    final anonymousAttrs = <MapConfigProperty>[];
    final enabledNoAttrs = <MapConfigEntity>[];
    final enabledWithAttrs = <MapConfigEntity>[];
    final disabled = <MapConfigEntity>[];

    for (final entity in category.entities) {
      if (entity.isAnonymous) {
        anonymousAttrs.addAll(entity.attributes);
        continue;
      }
      if (!entity.enabled) {
        disabled.add(entity);
        continue;
      }
      if (entity.attributes.isEmpty) {
        enabledNoAttrs.add(entity);
      } else {
        enabledWithAttrs.add(entity);
      }
    }

    // 匿名段的载体也是一个 anonymous entity（enabled=true），用于复用 _buildPropertyItem
    final MapConfigEntity anonymousEntity = MapConfigEntity(
      name: '',
      enabled: true,
      attributes: anonymousAttrs,
    );

    final blocks = <Widget>[];

    if (anonymousAttrs.isNotEmpty) {
      blocks.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: anonymousAttrs
              .map((p) => _buildPropertyItem(
                    p,
                    anonymousEntity,
                    category,
                    categoryColor,
                  ))
              .toList(),
        ),
      );
    }

    if (enabledNoAttrs.isNotEmpty) {
      blocks.add(_buildEnabledEntityStrip(enabledNoAttrs, category));
    }

    for (final cluster in _clusterEntities(enabledWithAttrs)) {
      if (cluster.entities.length == 1) {
        blocks.add(_buildEntityBlock(cluster.primary, category, categoryColor));
      } else {
        blocks.add(_buildEntityCluster(cluster, category, categoryColor));
      }
    }

    if (disabled.isNotEmpty) {
      blocks.add(_buildDisabledEntityStrip(disabled, category));
    }

    // 每段之间留 12px 间距
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) children.add(const SizedBox(height: 12));
      children.add(blocks[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// 属性签名：把实体的属性列表规范化后拼串，用于分桶
  String _signatureOf(MapConfigEntity entity) {
    final sorted = [...entity.attributes]..sort((a, b) => a.key.compareTo(b.key));
    return sorted
        .map((a) =>
            '${a.key}\u0001${a.value}\u0002${a.unit ?? ''}\u0002${a.originalValue ?? ''}\u0002${a.description ?? ''}')
        .join('\u0003');
  }

  /// 按签名把启用实体聚合为 cluster，保持首次出现顺序
  List<_EntityCluster> _clusterEntities(List<MapConfigEntity> entities) {
    final Map<String, _EntityCluster> byKey = <String, _EntityCluster>{};
    for (final e in entities) {
      final sig = _signatureOf(e);
      byKey.putIfAbsent(sig, () => _EntityCluster(signature: sig)).entities.add(e);
    }
    return byKey.values.toList();
  }

  /// 多实体共享同一份属性时的渲染：name pill 列表 + 分隔线 + 共享 chip
  Widget _buildEntityCluster(
    _EntityCluster cluster,
    MapConfigCategory category,
    String? categoryColor,
  ) {
    final primary = cluster.primary;

    // 注册别名：让搜索/滚动能通过任一 cluster 成员的名字定位到共享 chip
    for (final e in cluster.entities.skip(1)) {
      if (cluster.sharedAttributes.isEmpty) {
        final aliasId = '${category.category}_${e.name}_';
        final primaryId = '${category.category}_${primary.name}_';
        _propertyKeys[aliasId] =
            _propertyKeys.putIfAbsent(primaryId, () => GlobalKey());
      } else {
        for (final a in cluster.sharedAttributes) {
          final aliasId = '${category.category}_${e.name}_${a.key}';
          final primaryId = '${category.category}_${primary.name}_${a.key}';
          _propertyKeys[aliasId] =
              _propertyKeys.putIfAbsent(primaryId, () => GlobalKey());
        }
      }
    }

    // 整块命中判断
    bool blockMatched = _searchQuery.isEmpty;
    if (!blockMatched) {
      for (final e in cluster.entities) {
        if (e.name.toLowerCase().contains(_searchQuery)) {
          blockMatched = true;
          break;
        }
      }
      if (!blockMatched) {
        for (final a in cluster.sharedAttributes) {
          if (a.key.toLowerCase().contains(_searchQuery) ||
              a.value.toLowerCase().contains(_searchQuery)) {
            blockMatched = true;
            break;
          }
        }
      }
    }
    final double blockOpacity = blockMatched ? 1.0 : 0.35;

    return Opacity(
      opacity: blockOpacity,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (widget.isDark ? Colors.white : Colors.black)
              .withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部标注：几个实体共享
            Row(
              children: [
                Icon(Icons.copy_all_rounded, size: 12, color: _subTextColor),
                const SizedBox(width: 6),
                Text(
                  '共 ${cluster.entities.length} 个实体使用相同配置',
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 实体名 pill wrap
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: cluster.entities
                  .map((e) => _buildClusterEntityPill(e))
                  .toList(),
            ),
            if (cluster.sharedAttributes.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: _borderColor),
              ),
              // 共享属性 chip
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: cluster.sharedAttributes
                    .map((p) =>
                        _buildPropertyItem(p, primary, category, categoryColor))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClusterEntityPill(MapConfigEntity entity) {
    final Color? userKeyBg = hexToColor(_keyBgHex);
    final bool useCustom = userKeyBg != null;

    final Color bg =
        useCustom ? userKeyBg : _accentColor.withValues(alpha: 0.12);
    final Color borderColor = useCustom
        ? userKeyBg.withValues(alpha: 0.55)
        : _accentColor.withValues(alpha: 0.35);
    final Color textColor =
        useCustom ? _contrastText(userKeyBg) : _accentColor;

    final Widget label = useCustom
        ? _buildStrokedText(
            entity.name,
            textColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          )
        : Text(
            entity.name,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          );

    final isMatch = _searchQuery.isEmpty ||
        entity.name.toLowerCase().contains(_searchQuery);

    return Opacity(
      opacity: isMatch ? 1.0 : 0.4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor),
        ),
        child: label,
      ),
    );
  }

  /// 单个命名实体：实体名标签 + 属性 chip Wrap
  Widget _buildEntityBlock(
    MapConfigEntity entity,
    MapConfigCategory category,
    String? categoryColor,
  ) {
    final bool isDisabled = !entity.enabled;
    final Color themeColor = categoryColor != null
        ? Color(int.parse(categoryColor.replaceFirst('#', '0xFF')))
        : _accentColor;

    // 搜索命中判断（用于整块透明度）
    bool blockMatched = _searchQuery.isEmpty;
    if (!blockMatched) {
      if (entity.name.toLowerCase().contains(_searchQuery)) {
        blockMatched = true;
      } else {
        for (final a in entity.attributes) {
          if (a.key.toLowerCase().contains(_searchQuery) ||
              a.value.toLowerCase().contains(_searchQuery)) {
            blockMatched = true;
            break;
          }
        }
      }
    }
    final double blockOpacity = blockMatched ? 1.0 : 0.35;

    return Opacity(
      opacity: blockOpacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isDisabled ? _subTextColor.withValues(alpha: 0.5) : themeColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  entity.name,
                  style: TextStyle(
                    color: isDisabled ? _subTextColor : _textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration:
                        isDisabled ? TextDecoration.lineThrough : null,
                    decorationColor: _subTextColor,
                    decorationThickness: 1.5,
                  ),
                ),
                if (isDisabled) ...[
                  const SizedBox(width: 8),
                  _buildDisabledBadge(),
                ],
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: entity.attributes
                .map((p) => _buildPropertyItem(
                      p,
                      entity,
                      category,
                      categoryColor,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  /// 「启用」条：把「启用 + 无参数」实体聚拢到顶部一排小胶囊
  /// 用途：类似「人类职业」这种默认全关、仅显式启用某几个的场景
  Widget _buildEnabledEntityStrip(
    List<MapConfigEntity> entities,
    MapConfigCategory category,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 13,
                color: _accentColor,
              ),
              const SizedBox(width: 6),
              Text(
                '已启用（${entities.length}）',
                style: TextStyle(
                  color: _accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: entities
                .map((e) => _buildEnabledEntityPill(e, category))
                .toList(),
          ),
        ],
      ),
    );
  }

  /// 启用条里的胶囊：复用 cluster pill 视觉（跟自定义 key 色一致），并注入 GlobalKey 支持搜索定位
  Widget _buildEnabledEntityPill(
    MapConfigEntity entity,
    MapConfigCategory category,
  ) {
    final itemKeyId = '${category.category}_${entity.name}_';
    final globalKey = _propertyKeys.putIfAbsent(itemKeyId, () => GlobalKey());
    return Container(
      key: globalKey,
      child: _buildClusterEntityPill(entity),
    );
  }

  /// 「禁用」条：把仅禁用无属性的实体聚拢到底部一排小胶囊
  Widget _buildDisabledEntityStrip(
    List<MapConfigEntity> entities,
    MapConfigCategory category,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.block_rounded,
                size: 13,
                color: _subTextColor,
              ),
              const SizedBox(width: 6),
              Text(
                '已禁用（${entities.length}）',
                style: TextStyle(
                  color: _subTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: entities
                .map((e) => _buildDisabledEntityPill(e, category))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledEntityPill(
    MapConfigEntity entity,
    MapConfigCategory category,
  ) {
    final itemKeyId = '${category.category}_${entity.name}_';
    final globalKey = _propertyKeys.putIfAbsent(itemKeyId, () => GlobalKey());

    // 搜索也命中带属性的实体的 attr key/value
    bool isMatch = _searchQuery.isEmpty ||
        entity.name.toLowerCase().contains(_searchQuery);
    if (!isMatch) {
      for (final a in entity.attributes) {
        if (a.key.toLowerCase().contains(_searchQuery) ||
            a.value.toLowerCase().contains(_searchQuery)) {
          isMatch = true;
          break;
        }
      }
    }
    final double opacity = isMatch ? 1.0 : 0.3;

    final hasAttrs = entity.attributes.isNotEmpty;

    Widget pill = Container(
      key: globalKey,
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: EdgeInsets.only(
            left: 8,
            right: hasAttrs ? 4 : 8,
            top: 4,
            bottom: 4,
          ),
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entity.name,
                style: TextStyle(
                  color: _subTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: _subTextColor,
                ),
              ),
              if (hasAttrs) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${entity.attributes.length} 参数',
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!hasAttrs) return pill;

    // 带参数的禁用实体：hover 显示参数明细
    return JustTheTooltip(
      preferredDirection: AxisDirection.up,
      backgroundColor: widget.isDark ? const Color(0xFF333333) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 8,
      tailLength: 8,
      tailBaseWidth: 14,
      margin: const EdgeInsets.all(16),
      content: _buildDisabledEntityTooltip(entity),
      child: MouseRegion(
        cursor: SystemMouseCursors.help,
        child: pill,
      ),
    );
  }

  Widget _buildDisabledEntityTooltip(MapConfigEntity entity) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320, maxHeight: 380),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block_rounded, size: 12, color: _subTextColor),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    entity.name,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: _subTextColor,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 18),
              child: Text(
                '实体已禁用，以下参数不生效',
                style: TextStyle(color: _subTextColor, fontSize: 10),
              ),
            ),
            const SizedBox(height: 8),
            for (final a in entity.attributes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${a.key}: ',
                          style: TextStyle(
                              color: _subTextColor, fontSize: 12),
                        ),
                        Expanded(
                          child: Text(
                            _formatAttributeValue(a),
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (a.description != null && a.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3, left: 4),
                        child: MarkdownBody(
                          data: a.description!,
                          selectable: true,
                          onTapLink: (text, href, title) {
                            if (href != null) {
                              try {
                                launchUrl(
                                  Uri.parse(href),
                                  mode: LaunchMode.externalApplication,
                                );
                              } catch (_) {}
                            }
                          },
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: _subTextColor,
                              fontSize: 11,
                              height: 1.4,
                            ),
                            code: TextStyle(
                              color: _accentColor,
                              backgroundColor: widget.isDark
                                  ? Colors.white10
                                  : Colors.black12,
                              fontFamily: 'monospace',
                              fontSize: 10,
                            ),
                            listBullet: TextStyle(
                              color: _subTextColor,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatAttributeValue(MapConfigProperty a) {
    final unit = (a.unit != null && a.unit!.isNotEmpty) ? ' ${a.unit}' : '';
    final displayValue = '${a.value}$unit';
    if (a.originalValue != null && a.originalValue!.isNotEmpty) {
      return '${a.originalValue} -> $displayValue';
    }
    return displayValue;
  }

  Widget _buildDisabledBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (widget.isDark ? Colors.white : Colors.black)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block_rounded, size: 10, color: _subTextColor),
          const SizedBox(width: 3),
          Text(
            '禁用',
            style: TextStyle(
              color: _subTextColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 计算颜色的最佳文字颜色（黑/白）
  Color _contrastText(Color bg) {
    return bg.computeLuminance() > 0.55 ? Colors.black : Colors.white;
  }

  /// 构建带描边的文本（Paint stroke 底层 + 填充上层）
  Widget _buildStrokedText(
    String text,
    Color textColor, {
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color? strokeColorOverride,
    double strokeWidth = 2.5,
  }) {
    final Color strokeColor = strokeColorOverride ??
        (textColor.computeLuminance() > 0.5 ? Colors.black : Colors.white);
    return Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = strokeColor.withValues(alpha: 0.85),
          ),
        ),
        Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
        ),
      ],
    );
  }

  /// 构建 Tag 的 Key 分段
  Widget _buildTagKeySegment(String key, Color? userKeyBg) {
    final Color bg = userKeyBg ??
        (widget.isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05));

    final Widget label;
    if (userKeyBg != null) {
      // 用户已自定义 → 自动对比色 + 描边
      label = _buildStrokedText(key, _contrastText(userKeyBg));
    } else {
      // 默认：跟随主题
      label = Text(
        key,
        style: TextStyle(
          color: widget.isDark ? Colors.white70 : Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: bg,
      child: label,
    );
  }

  /// 构建 Tag 的 Value 分段
  Widget _buildTagValueSegment(
    String valueText,
    Color? userValueBg,
    Color baseColor,
    Color lightColor,
    Color darkColor,
  ) {
    if (userValueBg != null) {
      // 用户自定义 → 纯色 + 自动对比色 + 描边
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: userValueBg,
        child: _buildStrokedText(valueText, _contrastText(userValueBg)),
      );
    }

    // 默认：分类色渐变 + 白字 + 多重阴影描边
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            lightColor.withValues(alpha: 0.4),
            baseColor.withValues(alpha: 0.5),
            darkColor.withValues(alpha: 0.45),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Text(
        valueText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: baseColor.withValues(alpha: 0.8),
              blurRadius: 2,
              offset: const Offset(0, 0),
            ),
            Shadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 1,
              offset: const Offset(1, 1),
            ),
            Shadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 1,
              offset: const Offset(-1, -1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaletteButton() {
    final hasCustom = _keyBgHex != null || _valueBgHex != null;
    return Tooltip(
      message: '修改标签颜色',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _showColorPaletteDialog,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: hasCustom
                    ? _accentColor.withValues(alpha: 0.6)
                    : _borderColor,
              ),
            ),
            child: Icon(
              Icons.palette_rounded,
              size: 18,
              color: hasCustom ? _accentColor : _subTextColor,
            ),
          ),
        ),
      ),
    );
  }

  void _showColorPaletteDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Widget buildPreview() {
              final userKeyBg = hexToColor(_keyBgHex);
              final userValueBg = hexToColor(_valueBgHex);
              // 使用一个默认分类色作为占位
              const baseColor = Color(0xFF3498DB);
              final darkColor = Color.lerp(baseColor, Colors.black, 0.2)!;
              final lightColor = Color.lerp(baseColor, Colors.white, 0.6)!;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (userValueBg ?? baseColor).withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTagKeySegment('示例属性', userKeyBg),
                      _buildTagValueSegment(
                        '示例值 42',
                        userValueBg,
                        baseColor,
                        lightColor,
                        darkColor,
                      ),
                    ],
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: _cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.palette_rounded, color: _accentColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '修改标签颜色',
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '预览',
                      style: TextStyle(
                        color: _subTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: buildPreview(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '属性 背景色',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TagColorPicker(
                      selectedColor: _keyBgHex,
                      onColorChanged: (hex) {
                        setDialogState(() {});
                        _updateKeyBgColor(hex);
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '值 背景色',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TagColorPicker(
                      selectedColor: _valueBgHex,
                      onColorChanged: (hex) {
                        setDialogState(() {});
                        _updateValueBgColor(hex);
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '提示：选择「无颜色」可恢复默认样式；文字颜色会根据背景自动切换并添加描边。',
                      style: TextStyle(
                        color: _subTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {});
                    _updateKeyBgColor(null);
                    _updateValueBgColor(null);
                  },
                  child: Text(
                    '重置',
                    style: TextStyle(color: _subTextColor),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    '完成',
                    style: TextStyle(color: _accentColor),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPropertyItem(
    MapConfigProperty prop,
    MapConfigEntity entity,
    MapConfigCategory category,
    String? categoryColor,
  ) {
    final hasChanged =
        prop.originalValue != null && prop.originalValue!.isNotEmpty;

    final displayValue = (prop.unit != null && prop.unit!.isNotEmpty)
        ? '${prop.value} ${prop.unit}'
        : prop.value;
    final valueText = hasChanged
        ? '${prop.originalValue} -> $displayValue'
        : displayValue;

    // 禁用实体：所有子属性用冷灰色，避免继续吸引注意力
    final bool isDisabled = !entity.enabled;
    final String colorStr = isDisabled
        ? '#7F8C8D'
        : (hasChanged ? '#27AE60' : (categoryColor ?? '#3498DB'));
    final baseColor = Color(int.parse(colorStr.replaceFirst('#', '0xFF')));

    final darkColor = Color.lerp(baseColor, Colors.black, 0.2)!;
    final lightColor = Color.lerp(baseColor, Colors.white, 0.6)!;

    // 用户自定义颜色（可能为 null，null 表示走默认样式）
    // 禁用实体不吃自定义色，避免视觉冲突
    final Color? userKeyBg = isDisabled ? null : hexToColor(_keyBgHex);
    final Color? userValueBg = isDisabled ? null : hexToColor(_valueBgHex);

    final itemKeyId = '${category.category}_${entity.name}_${prop.key}';
    final globalKey = _propertyKeys.putIfAbsent(itemKeyId, () => GlobalKey());

    bool isMatch = false;
    if (_searchQuery.isNotEmpty) {
      isMatch = entity.name.toLowerCase().contains(_searchQuery) ||
          prop.key.toLowerCase().contains(_searchQuery) ||
          prop.value.toLowerCase().contains(_searchQuery);
    }
    final double opacity = (_searchQuery.isEmpty || isMatch) ? 1.0 : 0.3;

    // 边框/阴影颜色：优先使用用户自定义 value 颜色，其次是分类色
    final Color accent = userValueBg ?? baseColor;

    Widget chip = Container(
      key: globalKey,
      child: Opacity(
        opacity: opacity * (isDisabled ? 0.65 : 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: accent.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTagKeySegment(prop.key, userKeyBg),
                _buildTagValueSegment(
                  valueText,
                  userValueBg,
                  baseColor,
                  lightColor,
                  darkColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (prop.description != null && prop.description!.isNotEmpty) {
      return JustTheTooltip(
        preferredDirection: AxisDirection.up,
        backgroundColor: widget.isDark ? const Color(0xFF333333) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        elevation: 8,
        tailLength: 8,
        tailBaseWidth: 16,
        margin: const EdgeInsets.all(16),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 400),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            child: MarkdownBody(
              data: prop.description!,
              selectable: true,
              onTapLink: (text, href, title) {
                if (href != null) {
                  try {
                    launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
                  } catch (_) {}
                }
              },
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: _textColor, fontSize: 13, height: 1.5),
                h1: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold),
                h2: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.bold),
                h3: TextStyle(color: _textColor, fontSize: 15, fontWeight: FontWeight.bold),
                listBullet: TextStyle(color: _textColor),
                code: TextStyle(
                  color: _accentColor,
                  backgroundColor: widget.isDark ? Colors.white10 : Colors.black12,
                  fontFamily: 'monospace',
                ),
                codeblockDecoration: BoxDecoration(
                  color: widget.isDark ? Colors.white10 : Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.help,
          child: chip,
        ),
      );
    }

    return chip;
  }

  Widget _buildGuidePlaceholder() {
    if (_isLoadingGuide) {
      return _buildLoadingState(text: '正在加载攻略内容...');
    }

    if (_guideError != null) {
      return _buildEmptyState(text: _guideError!);
    }

    if (_guides.isEmpty) {
      return _buildEmptyState(text: '暂无攻略内容');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = guideCrossAxisCount(MediaQuery.of(context).size.width);

        return MasonryGridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _guides.length,
          itemBuilder: (context, index) {
            final item = _guides[index];
            return CommunityGuideCard(
              item: item,
              onTap: () {
                final colors = CommunityGuideColors.of(context);
                showDialog(
                  context: context,
                  barrierColor: colors.scrim,
                  builder: (context) {
                    final size = MediaQuery.of(context).size;
                    return Dialog(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      insetPadding: EdgeInsets.zero,
                      child: Container(
                        width: size.width * 0.9,
                        height: size.height * 0.92,
                        decoration: BoxDecoration(
                          color: colors.detailOverlayBg,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: GuideDetailView(
                                key: ValueKey(item.id),
                                id: item.id,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: CommunityGuideCloseButton(
                                onTap: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingState({String text = '正在加载配置数据...'}) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _accentColor, strokeWidth: 3),
            const SizedBox(height: 16),
            Text(text, style: TextStyle(color: _subTextColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String errorText) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF3B2323)
            : const Color(0xFFFDE8E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark
              ? const Color(0xFF6B3A3A)
              : const Color(0xFFF8B4B4),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade400,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              errorText,
              style: TextStyle(
                color: Colors.red.shade400,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    String text = '暂无地图配置数据',
    IconData icon = Icons.inbox_rounded,
  }) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _subTextColor.withValues(alpha: 0.5), size: 48),
            const SizedBox(height: 16),
            Text(text, style: TextStyle(color: _subTextColor, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
