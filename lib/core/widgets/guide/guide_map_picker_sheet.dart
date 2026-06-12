import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/map_contribution_api.dart';
import '../../models/map_contribution_models.dart';
import '../../utils/log_service.dart';
import '../map_background.dart';
import '../../constants/app_colors.dart';

/// 关联地图选择器（桌面端 Dialog 形式）
///
/// 使用地图数据库接口 [MapContributionApi.getAllMaps] 拉取地图列表，
/// 与「地图数据库」页同源；支持服务端搜索（中文/英文均可），300ms 输入防抖。
///
/// 卡片样式参考 `MapSubscriptionCard`：地图背景图 + 渐变遮罩 + 白色文字带阴影。
///
/// 使用方式：
/// ```dart
/// final selected = await GuideMapPickerSheet.show(context, current: currentMap);
/// ```
class GuideMapPickerSheet extends StatefulWidget {
  /// 当前已选中的地图（用于显示「移除关联」按钮）
  final MapInfo? current;

  const GuideMapPickerSheet({
    super.key,
    this.current,
  });

  static Future<MapInfo?> show(
    BuildContext context, {
    MapInfo? current,
  }) async {
    final result = await showDialog<_PickerResult>(
      context: context,
      barrierDismissible: true,
      builder: (context) => GuideMapPickerSheet(current: current),
    );

    if (result == null) return current; // 取消，保持原值
    return result.selected; // 选择了新地图
  }

  @override
  State<GuideMapPickerSheet> createState() => _GuideMapPickerSheetState();
}

class _PickerResult {
  final MapInfo? selected;

  const _PickerResult.select(MapInfo map) : selected = map;
}

// ─── 视觉常量（与编辑器一致的风格，支持亮/暗主题）────────────────────────
class _T {
  final Color dialogBg;
  final Color fieldBg;
  final Color borderSoft;
  final Color borderHover;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  static const double radiusField = 10;

  const _T._({
    required this.dialogBg,
    required this.fieldBg,
    required this.borderSoft,
    required this.borderHover,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  factory _T.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _T._(
        dialogBg: Color(0xFF131B2C),
        fieldBg: Color(0xFF1F2A3D),
        borderSoft: Color(0x1FFFFFFF),
        borderHover: Color(0x40FFFFFF),
        accent: Color(0xFF2196F3),
        textPrimary: AppColors.slate100,
        textSecondary: AppColors.slate300,
        textMuted: AppColors.slate400,
      );
    }
    return const _T._(
      dialogBg: Colors.white,
      fieldBg: AppColors.slate50,
      borderSoft: AppColors.gray200,
      borderHover: AppColors.slate300,
      accent: Color(0xFF2196F3),
      textPrimary: AppColors.gray800,
      textSecondary: AppColors.gray700,
      textMuted: AppColors.gray500,
    );
  }
}

class _GuideMapPickerSheetState extends State<GuideMapPickerSheet> {
  final _searchController = TextEditingController();
  final _api = MapContributionApi();
  final _scrollController = ScrollController();

  List<MapInfo> _maps = [];
  bool _isLoading = true;
  String? _error;
  Timer? _debounceTimer;
  String _currentKeyword = '';

  @override
  void initState() {
    super.initState();
    _loadMaps();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// 服务端搜索（支持中英文）
  Future<void> _loadMaps({String? keyword}) async {
    final kw = keyword ?? _currentKeyword;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _api.getAllMaps(
        MapListRequest(
          pagination: const PaginationParams(pageIndex: 1, pageSize: 200),
          mapName: kw.isEmpty ? null : kw,
        ),
      );
      final maps = response?.items ?? const <MapInfo>[];
      if (mounted) {
        setState(() {
          _maps = maps;
          _isLoading = false;
        });
      }
    } catch (e) {
      LogService.e('加载地图列表失败', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '加载地图列表失败，请重试';
        });
      }
    }
  }

  void _onSearchChanged(String keyword) {
    _currentKeyword = keyword;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadMaps(keyword: keyword);
    });
  }

  void _selectMap(MapInfo map) {
    Navigator.of(context).pop(_PickerResult.select(map));
  }

  @override
  Widget build(BuildContext context) {
    final colors = _T.of(context);
    return Dialog(
      backgroundColor: colors.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.borderSoft),
      ),
      // 显式覆盖 InputDecorationTheme，避免外层主题白色 fillColor 渗透
      child: Theme(
        data: Theme.of(context).copyWith(
          brightness: Brightness.dark,
          inputDecorationTheme: const InputDecorationTheme(
            filled: false,
            fillColor: Colors.transparent,
          ),
        ),
        child: Container(
          width: 520,
          constraints: const BoxConstraints(maxHeight: 620),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 14),
              _buildSearchField(),
              const SizedBox(height: 12),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final colors = _T.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '选择关联地图',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
        _CloseButton(onTap: () => Navigator.of(context).pop()),
      ],
    );
  }

  Widget _buildSearchField() {
    final colors = _T.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.fieldBg,
        borderRadius: BorderRadius.circular(_T.radiusField),
        border: Border.all(color: colors.borderSoft),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        autofocus: true,
        style: TextStyle(fontSize: 13, color: colors.textPrimary),
        cursorColor: colors.accent,
        decoration: InputDecoration(
          hintText: '搜索地图名称（支持中文/英文）...',
          hintStyle: TextStyle(fontSize: 13, color: colors.textMuted),
          prefixIcon: Icon(Icons.search, size: 18, color: colors.textMuted),
          prefixIconConstraints:
              BoxConstraints(minWidth: 38, minHeight: 38),
          isDense: true,
          filled: false,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildContent() {
    final colors = _T.of(context);
    if (_isLoading && _maps.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.accent,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.textMuted),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadMaps,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重试'),
              style: TextButton.styleFrom(foregroundColor: colors.accent),
            ),
          ],
        ),
      );
    }

    if (_maps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 48, color: colors.textMuted),
            const SizedBox(height: 12),
            Text(
              _currentKeyword.isEmpty ? '暂无可用地图' : '未找到匹配「$_currentKeyword」的地图',
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(right: 6, bottom: 4),
            itemCount: _maps.length,
            itemBuilder: (context, index) {
              final map = _maps[index];
              final isSelected = widget.current?.mapName == map.mapName;
              return _MapPickerCard(
                map: map,
                isSelected: isSelected,
                onTap: () => _selectMap(map),
              );
            },
          ),
        ),
        if (_isLoading)
          Positioned(
            top: 0,
            right: 0,
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.accent,
              ),
            ),
          ),
      ],
    );
  }
}

/// 关闭按钮（圆形 + hover）
class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = _T.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hovering
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Icon(Icons.close, size: 16, color: colors.textMuted),
        ),
      ),
    );
  }
}

/// 地图选择卡片（参考 [MapSubscriptionCard] 的视觉：背景图 + 渐变遮罩 + 白字阴影）
class _MapPickerCard extends StatefulWidget {
  final MapInfo map;
  final bool isSelected;
  final VoidCallback onTap;

  const _MapPickerCard({
    required this.map,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_MapPickerCard> createState() => _MapPickerCardState();
}

class _MapPickerCardState extends State<_MapPickerCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = _T.of(context);
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
              color: widget.isSelected
                  ? colors.accent
                  : _hovering
                      ? colors.borderHover
                      : Colors.white.withValues(alpha: 0.08),
              width: widget.isSelected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: _hovering ? 0.25 : 0.15),
                blurRadius: _hovering ? 10 : 5,
                offset: Offset(0, _hovering ? 4 : 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 72,
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
                      child: Container(color: colors.fieldBg),
                    ),
                  // 渐变遮罩（增强文字可读性）
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
                  // 选中态高亮蒙层
                  if (widget.isSelected)
                    Positioned.fill(
                      child: Container(
                        color: colors.accent.withValues(alpha: 0.15),
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
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // 译名（中文）：使用翻译图标
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.translate,
                                          size: 13,
                                          color: hasBackground
                                              ? Colors.white
                                                  .withValues(alpha: 0.95)
                                              : colors.textPrimary,
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
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            widget.map.mapLabel,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
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
                                    // 原名（slug）：使用地图图标
                                    if (hasDifferentLabel) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.map_outlined,
                                            size: 12,
                                            color: hasBackground
                                                ? Colors.white
                                                    .withValues(alpha: 0.7)
                                                : colors.textMuted,
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
                              // 攻略数 / 贡献数 徽标
                              if ((widget.map.guideCount ?? 0) > 0) ...[
                                _MetaBadge(
                                  icon: Icons.article_outlined,
                                  label: '${widget.map.guideCount}',
                                  hasBg: hasBackground,
                                ),
                                const SizedBox(width: 6),
                              ],
                              // 选中标记
                              if (widget.isSelected)
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors.accent,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
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

/// 卡片右侧小徽标（攻略数等）
class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasBg;

  const _MetaBadge({
    required this.icon,
    required this.label,
    required this.hasBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasBg
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasBg
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.92)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
