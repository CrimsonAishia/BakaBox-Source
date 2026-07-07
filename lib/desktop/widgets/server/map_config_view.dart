import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/map_config_api.dart';
import '../../../core/models/map_config_models.dart';
import '../../../core/api/guide_api.dart';
import '../../../core/models/guide_models.dart';
import '../../../core/models/map_tag_models.dart' show MapTagSimple;
import '../guide/community_guide/community_guide_card.dart';
import '../guide/community_guide/community_guide_format.dart';
import '../guide/community_guide/community_guide_theme.dart';
import '../guide/community_guide/community_guide_close_button.dart';
import '../guide/guide_detail_view.dart';
import 'server_card_components/server_card_tag_chip.dart';

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicators);
    _searchController.addListener(_onSearchChanged);
    _fetchConfigs();
    _fetchGuide();
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
      for (final prop in category.properties) {
        if (prop.key.toLowerCase().contains(query) || 
            prop.value.toLowerCase().contains(query)) {
          final key = _propertyKeys['${category.category}_${prop.key}'];
          if (key != null && key.currentContext != null) {
            Scrollable.ensureVisible(
              key.currentContext!,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: 0.1, // slightly below top
            );
          }
          return; // only scroll to the first match
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
        decoration: InputDecoration(
          hintText: '搜索属性...',
          hintStyle: TextStyle(color: _subTextColor, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, size: 16, color: _subTextColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 14, color: _subTextColor),
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
        // Properties
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: category.properties
                .map((prop) => _buildPropertyItem(prop, category, categoryColor))
                .toList(),
          ),
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

  Widget _buildPropertyItem(MapConfigProperty prop, MapConfigCategory category, String? categoryColor) {
    final hasChanged =
        prop.originalValue != null && prop.originalValue!.isNotEmpty;

    final text = hasChanged
        ? '${prop.key}: ${prop.originalValue} -> ${prop.value}'
        : '${prop.key}: ${prop.value}';

    final color = hasChanged ? '#27AE60' : (categoryColor ?? '#3498DB');

    final itemKeyId = '${category.category}_${prop.key}';
    final globalKey = _propertyKeys.putIfAbsent(itemKeyId, () => GlobalKey());

    bool isMatch = false;
    if (_searchQuery.isNotEmpty) {
      isMatch = prop.key.toLowerCase().contains(_searchQuery) ||
          prop.value.toLowerCase().contains(_searchQuery);
    }
    final double opacity = (_searchQuery.isEmpty || isMatch) ? 1.0 : 0.3;

    Widget chip = Container(
      key: globalKey,
      child: Opacity(
        opacity: opacity,
        child: ServerCardTagChip(
          tag: MapTagSimple(name: text, color: color),
          showPrefix: false,
          useMarkdown: true,
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
