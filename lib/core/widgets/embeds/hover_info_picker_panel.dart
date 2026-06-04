import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/character_api.dart';
import '../../api/map_contribution_api.dart';
import '../../models/character_models.dart';
import '../../models/map_contribution_models.dart';
import '../../utils/log_service.dart';
import '../map_background.dart';
import 'hover_info_block_embed.dart';

/// 插入引用选择面板（5 个 tab：地图/角色/枪模/刀模/符卡）
///
/// 用户选择后返回对应的 [HoverInfoData]，由调用方插入 hoverInfo embed。
class HoverInfoPickerPanel extends StatefulWidget {
  const HoverInfoPickerPanel({super.key});

  /// 弹出选择面板，返回选中的引用数据（取消返回 null）
  static Future<HoverInfoData?> show(BuildContext context) {
    return showDialog<HoverInfoData>(
      context: context,
      builder: (_) => const HoverInfoPickerPanel(),
    );
  }

  @override
  State<HoverInfoPickerPanel> createState() => _HoverInfoPickerPanelState();
}

class _HoverInfoPickerPanelState extends State<HoverInfoPickerPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onPicked(HoverInfoData data) {
    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 520,
        height: 580,
        child: Column(
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                children: [
                  Text(
                    '插入引用',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF6B7280),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Tab 栏
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFF0080FF),
              unselectedLabelColor:
                  isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
              indicatorColor: const Color(0xFF0080FF),
              tabs: const [
                Tab(text: '地图'),
                Tab(text: '角色'),
                Tab(text: '枪模'),
                Tab(text: '刀模'),
                Tab(text: '符卡'),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _MapTab(onPicked: _onPicked),
                  _CharacterTab(onPicked: _onPicked),
                  _GunModelTab(onPicked: _onPicked),
                  _KnifeModelTab(onPicked: _onPicked),
                  _SpellCardTab(onPicked: _onPicked),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 地图 tab（API 列表 + 搜索，卡片样式同关联地图组件）──────────────────

class _MapTab extends StatefulWidget {
  final ValueChanged<HoverInfoData> onPicked;
  const _MapTab({required this.onPicked});

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  final _searchController = TextEditingController();
  final _api = MapContributionApi();
  Timer? _debounce;
  List<MapInfo> _maps = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final keyword = _searchController.text.trim();
      final response = await _api.getAllMaps(
        MapListRequest(
          pagination: const PaginationParams(pageIndex: 1, pageSize: 200),
          mapName: keyword.isEmpty ? null : keyword,
        ),
      );
      if (mounted) {
        setState(() {
          _maps = response?.items ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      LogService.e('加载地图列表失败', e);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载地图列表失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SearchField(
          controller: _searchController,
          hint: '搜索地图名称（支持中文/英文）',
          onChanged: _onSearchChanged,
          onSubmitted: (_) => _load(),
        ),
        Expanded(
          child: _ListResult(
            loading: _loading,
            error: _error,
            empty: _maps.isEmpty,
            onRetry: _load,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: _maps.length,
              itemBuilder: (context, index) {
                final map = _maps[index];
                return _MapPickerCard(
                  map: map,
                  onTap: () => widget.onPicked(HoverInfoData(
                    type: HoverInfoType.map,
                    id: map.mapName,
                    label: map.mapLabel,
                    iconUrl: map.mapBackground ?? '',
                  )),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// 地图卡片（与关联地图组件同款样式：背景图 + 渐变遮罩 + 白字阴影）
class _MapPickerCard extends StatefulWidget {
  final MapInfo map;
  final VoidCallback onTap;

  const _MapPickerCard({required this.map, required this.onTap});

  @override
  State<_MapPickerCard> createState() => _MapPickerCardState();
}

class _MapPickerCardState extends State<_MapPickerCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final hasBackground =
        widget.map.mapBackground != null && widget.map.mapBackground!.isNotEmpty;
    final hasDifferentLabel = widget.map.mapLabel != widget.map.mapName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovering
                  ? const Color(0x40FFFFFF)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovering ? 0.25 : 0.15),
                blurRadius: _hovering ? 10 : 5,
                offset: Offset(0, _hovering ? 4 : 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 66,
              child: Stack(
                children: [
                  // 背景图（或底色）
                  if (hasBackground)
                    Positioned.fill(
                      child: MapBackground(
                        mapName: widget.map.mapName,
                        imageUrl: widget.map.mapBackground,
                        fit: BoxFit.cover,
                        cacheWidth: 800,
                      ),
                    )
                  else
                    Positioned.fill(
                      child: Container(color: const Color(0xFF1F2A3D)),
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
                              Colors.black.withValues(alpha: 0.4),
                              Colors.black.withValues(alpha: 0.55),
                              Colors.black.withValues(alpha: 0.8),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                  // 内容
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: widget.onTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 译名（中文）
                              Row(
                                children: [
                                  Icon(
                                    Icons.translate,
                                    size: 13,
                                    color: Colors.white.withValues(alpha: 0.95),
                                    shadows: hasBackground
                                        ? [
                                            Shadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.6),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      widget.map.mapLabel,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        shadows: hasBackground
                                            ? [
                                                Shadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.6),
                                                  blurRadius: 4,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              // 原名（slug）
                              if (hasDifferentLabel) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.map_outlined,
                                      size: 12,
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      shadows: hasBackground
                                          ? [
                                              Shadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.6),
                                                blurRadius: 4,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        widget.map.mapName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white
                                              .withValues(alpha: 0.78),
                                          shadows: hasBackground
                                              ? [
                                                  Shadow(
                                                    color: Colors.black
                                                        .withValues(
                                                            alpha: 0.6),
                                                    blurRadius: 4,
                                                  ),
                                                ]
                                              : null,
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 角色 tab（API 列表 + 搜索，懒加载）──────────────────────────────────

class _CharacterTab extends StatefulWidget {
  final ValueChanged<HoverInfoData> onPicked;
  const _CharacterTab({required this.onPicked});

  @override
  State<_CharacterTab> createState() => _CharacterTabState();
}

class _CharacterTabState extends State<_CharacterTab>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<CharacterListItem> _items = [];
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await CharacterApi().getCharacterList(
        pageIndex: 1,
        pageSize: 30,
        keyword: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _items = resp?.list ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      LogService.d('加载角色列表失败: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _SearchField(
          controller: _searchController,
          hint: '搜索角色',
          onChanged: _onSearchChanged,
          onSubmitted: (_) => _load(),
        ),
        Expanded(
          child: _ListResult(
            loading: _loading,
            error: _error,
            empty: _items.isEmpty,
            onRetry: _load,
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final c = _items[index];
                return _PickerTile(
                  iconUrl: c.thumbnailUrl,
                  fallbackIcon: HoverInfoColors.icon(HoverInfoType.character),
                  color: HoverInfoColors.color(HoverInfoType.character),
                  title: c.name,
                  subtitle: c.nameEn,
                  onTap: () => widget.onPicked(HoverInfoData(
                    type: HoverInfoType.character,
                    id: c.id.toString(),
                    label: c.name,
                    iconUrl: c.thumbnailUrl,
                  )),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 枪模 tab（API 搜索）──────────────────────────────────────────────

class _GunModelTab extends StatefulWidget {
  final ValueChanged<HoverInfoData> onPicked;
  const _GunModelTab({required this.onPicked});

  @override
  State<_GunModelTab> createState() => _GunModelTabState();
}

class _GunModelTabState extends State<_GunModelTab>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<GunModel> _items = [];
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final keyword = _searchController.text.trim();
      final resp = await CharacterApi().getAllGunModels(
        keyword: keyword.isEmpty ? null : keyword,
      );
      if (mounted) {
        setState(() {
          _items = resp?.items ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      LogService.d('加载枪模列表失败: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _SearchField(
          controller: _searchController,
          hint: '搜索枪模',
          onChanged: _onSearchChanged,
          onSubmitted: (_) => _load(),
        ),
        Expanded(
          child: _ListResult(
            loading: _loading,
            error: _error,
            empty: _items.isEmpty,
            onRetry: _load,
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final g = _items[index];
                return _PickerTile(
                  iconUrl: g.thumbnailUrl ?? '',
                  fallbackIcon: HoverInfoColors.icon(HoverInfoType.weapon),
                  color: HoverInfoColors.color(HoverInfoType.weapon),
                  title: g.name,
                  subtitle: g.characterName,
                  onTap: () => widget.onPicked(HoverInfoData(
                    type: HoverInfoType.weapon,
                    id: g.id.toString(),
                    label: g.name,
                    iconUrl: g.thumbnailUrl ?? '',
                  )),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 刀模 tab（API 搜索）──────────────────────────────────────────────

class _KnifeModelTab extends StatefulWidget {
  final ValueChanged<HoverInfoData> onPicked;
  const _KnifeModelTab({required this.onPicked});

  @override
  State<_KnifeModelTab> createState() => _KnifeModelTabState();
}

class _KnifeModelTabState extends State<_KnifeModelTab>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<KnifeModel> _items = [];
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final keyword = _searchController.text.trim();
      final resp = await CharacterApi().getAllKnifeModels(
        keyword: keyword.isEmpty ? null : keyword,
      );
      if (mounted) {
        setState(() {
          _items = resp?.items ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      LogService.d('加载刀模列表失败: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _SearchField(
          controller: _searchController,
          hint: '搜索刀模',
          onChanged: _onSearchChanged,
          onSubmitted: (_) => _load(),
        ),
        Expanded(
          child: _ListResult(
            loading: _loading,
            error: _error,
            empty: _items.isEmpty,
            onRetry: _load,
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final k = _items[index];
                return _PickerTile(
                  iconUrl: k.thumbnailUrl ?? '',
                  fallbackIcon: HoverInfoColors.icon(HoverInfoType.knife),
                  color: HoverInfoColors.color(HoverInfoType.knife),
                  title: k.name,
                  subtitle: k.characterName,
                  onTap: () => widget.onPicked(HoverInfoData(
                    type: HoverInfoType.knife,
                    id: k.id.toString(),
                    label: k.name,
                    iconUrl: k.thumbnailUrl ?? '',
                  )),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 符卡 tab（API 搜索）────────────────────────────────────────────────

class _SpellCardTab extends StatefulWidget {
  final ValueChanged<HoverInfoData> onPicked;
  const _SpellCardTab({required this.onPicked});

  @override
  State<_SpellCardTab> createState() => _SpellCardTabState();
}

class _SpellCardTabState extends State<_SpellCardTab>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<SpellCardTierItem> _items = [];
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final keyword = _searchController.text.trim();
      final resp = await CharacterApi().getSpellCardTierList(
        keyword: keyword.isEmpty ? null : keyword,
      );
      if (mounted) {
        // 展平所有分组中的符卡
        final allItems = <SpellCardTierItem>[];
        if (resp != null) {
          for (final group in resp.tiers) {
            allItems.addAll(group.spellCards);
          }
        }
        setState(() {
          _items = allItems;
          _loading = false;
        });
      }
    } catch (e) {
      LogService.d('加载符卡列表失败: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _SearchField(
          controller: _searchController,
          hint: '搜索符卡名称',
          onChanged: _onSearchChanged,
          onSubmitted: (_) => _load(),
        ),
        Expanded(
          child: _ListResult(
            loading: _loading,
            error: _error,
            empty: _items.isEmpty,
            onRetry: _load,
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final s = _items[index];
                return _PickerTile(
                  iconUrl: s.iconUrl ?? '',
                  fallbackIcon: HoverInfoColors.icon(HoverInfoType.spellCard),
                  color: HoverInfoColors.color(HoverInfoType.spellCard),
                  title: s.name,
                  subtitle: '${s.characterName} · ${_spellCardTypeLabel(s.type)}',
                  onTap: () => widget.onPicked(HoverInfoData(
                    type: HoverInfoType.spellCard,
                    id: s.id.toString(),
                    label: s.name,
                    iconUrl: s.iconUrl ?? '',
                  )),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _spellCardTypeLabel(SpellCardType type) {
    switch (type) {
      case SpellCardType.normal:
        return '小符卡';
      case SpellCardType.ultimate:
        return '大符卡';
      case SpellCardType.passive:
        return '被动';
    }
  }
}

// ─── 复用组件 ──────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
          cursorColor: const Color(0xFF0080FF),
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
            isCollapsed: true,
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF3F4F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          ),
        ),
      ),
    );
  }
}

class _ListResult extends StatelessWidget {
  final bool loading;
  final String? error;
  final bool empty;
  final VoidCallback onRetry;
  final Widget child;

  const _ListResult({
    required this.loading,
    required this.error,
    required this.empty,
    required this.onRetry,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      );
    }
    if (empty) {
      return const _EmptyHint(text: '无结果');
    }
    return child;
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
          fontSize: 13,
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String iconUrl;
  final IconData fallbackIcon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _PickerTile({
    required this.iconUrl,
    required this.fallbackIcon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: iconUrl.isNotEmpty
                  ? Image.network(
                      iconUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(),
                    )
                  : _fallback(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(fallbackIcon, size: 20, color: color),
    );
  }
}
