import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/map_background.dart';
import '../../../../core/widgets/marquee_text.dart';
import '../../../../core/widgets/dashed_line.dart';
import '../common_scroll_indicator.dart';
import 'bloc/map_manage_bloc.dart';
import 'bloc/map_manage_event.dart';
import 'bloc/map_manage_state.dart';

class Cs2MapManageTool extends StatefulWidget {
  const Cs2MapManageTool({super.key});

  @override
  State<Cs2MapManageTool> createState() => _Cs2MapManageToolState();
}

class _Cs2MapManageToolState extends State<Cs2MapManageTool> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listScrollController = ScrollController();
  Timer? _statusTimer;
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  final List<String> _mapTypes = [
    '全部',
    'ze_',
    'zm_',
    'mg_',
    'surf_',
    'bhop_',
    'kz_',
    'de_',
    'cs_',
  ];
  String _selectedType = '全部';

  void _checkScroll() {
    if (!_listScrollController.hasClients) return;
    final position = _listScrollController.position;
    final canUp = position.pixels > 0;
    final canDown = position.pixels < position.maxScrollExtent;
    if (canUp != _canScrollUp || canDown != _canScrollDown) {
      setState(() {
        _canScrollUp = canUp;
        _canScrollDown = canDown;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    context.read<MapManageBloc>().add(ScanLocalMaps());
    _listScrollController.addListener(_checkScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
    
    // 定期检测 Steam 运行状态（每 3 秒一次）
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        context.read<MapManageBloc>().add(CheckSteamStatus());
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _searchController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<MapManageBloc>().add(
      SetFilter(
        searchQuery: query,
        filterType: _selectedType == '全部' ? '' : _selectedType,
      ),
    );
  }

  void _onTypeChanged(String? type) {
    if (type == null) return;
    setState(() {
      _selectedType = type;
    });
    context.read<MapManageBloc>().add(
      SetFilter(
        searchQuery: _searchController.text,
        filterType: type == '全部' ? '' : type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<MapManageBloc, MapManageState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: AppColors.red500,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          context.read<MapManageBloc>().add(ClearMapManageError());
        }
      },
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate800 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildToolbar(context, isDark, state),
              DashedLine(
                color: isDark ? AppColors.slate700 : AppColors.gray200,
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildMapList(context, isDark, state),
                    ),
                    Container(
                      width: 1,
                      color: isDark ? AppColors.slate700 : AppColors.gray200,
                    ),
                    Expanded(
                      flex: 4,
                      child: _buildPreviewPane(context, isDark, state),
                    ),
                  ],
                ),
              ),
              DashedLine(
                color: isDark ? AppColors.slate700 : AppColors.gray200,
              ),
              _buildBottomBar(context, isDark, state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    bool isDark,
    MapManageState state,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 280,
            height: 40,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: '搜索地图名或ID...',
                prefixIcon: Icon(
                  MdiIcons.magnify,
                  size: 20,
                  color: AppColors.gray400,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                filled: true,
                fillColor: isDark ? AppColors.slate900 : AppColors.gray50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            initialValue: _selectedType,
            onSelected: _onTypeChanged,
            color: isDark ? AppColors.slate800 : Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isDark ? AppColors.slate700 : AppColors.gray200,
              ),
            ),
            offset: const Offset(0, 44),
            itemBuilder: (context) => _mapTypes.map((type) {
              final isSelected = type == _selectedType;
              return PopupMenuItem<String>(
                value: type,
                height: 36,
                child: Row(
                  children: [
                    Text(
                      type,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.blue500
                            : (isDark ? Colors.white70 : AppColors.gray700),
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    if (isSelected) ...[
                      const Spacer(),
                      Icon(Icons.check, size: 16, color: AppColors.blue500),
                    ],
                  ],
                ),
              );
            }).toList(),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate900 : AppColors.gray50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 16,
                    color: isDark ? Colors.white54 : AppColors.gray500,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedType,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.gray700,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: isDark ? Colors.white38 : AppColors.gray400,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          FilledButton.tonalIcon(
            icon: Icon(MdiIcons.refresh, size: 16),
            label: const Text('重新扫描', style: TextStyle(fontSize: 13)),
            onPressed: state.isLoading
                ? null
                : () => context.read<MapManageBloc>().add(ScanLocalMaps()),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapList(
    BuildContext context,
    bool isDark,
    MapManageState state,
  ) {
    if (state.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('正在扫描本地地图...', style: TextStyle(color: AppColors.gray500)),
          ],
        ),
      );
    }

    final maps = state.displayMaps;
    if (maps.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                MdiIcons.folderSearchOutline,
                size: 64,
                color: AppColors.gray300,
              ),
              const SizedBox(height: 16),
              Text(
                '没有找到匹配的地图',
                style: TextStyle(
                  color: AppColors.gray500,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Scrollbar(
          controller: _listScrollController,
          thumbVisibility: true,
          child: ListView.separated(
            controller: _listScrollController,
            padding: const EdgeInsets.all(12),
            itemCount: maps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final mapItem = maps[index];
              final isSelected = state.selectedMapIds.contains(mapItem.id);
              final isActive = state.previewMapId == mapItem.id;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isActive
                      ? (isDark
                            ? AppColors.blue900.withValues(alpha: 0.3)
                            : AppColors.blue50.withValues(alpha: 0.5))
                      : (isDark ? AppColors.slate800 : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? AppColors.blue500
                        : (isDark ? Colors.transparent : AppColors.gray200),
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.read<MapManageBloc>().add(
                      PreviewMap(mapItem.id),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            activeColor: AppColors.blue500,
                            onChanged: (val) {
                              context.read<MapManageBloc>().add(
                                ToggleMapSelection(mapItem.id, val ?? false),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mapItem.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.gray800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      MdiIcons.fileDocumentOutline,
                                      size: 14,
                                      color: AppColors.gray400,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'ID: ${mapItem.id}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.gray500,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      MdiIcons.harddisk,
                                      size: 14,
                                      color: AppColors.gray400,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(mapItem.size / 1024 / 1024).toStringAsFixed(1)} MB',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.gray500,
                                      ),
                                    ),
                                  ],
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
            },
          ),
        ),
        if (_canScrollUp)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CommonScrollIndicator(isTop: true),
          ),
        if (_canScrollDown)
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CommonScrollIndicator(isTop: false),
          ),
      ],
    );
  }

  Widget _buildPreviewPane(
    BuildContext context,
    bool isDark,
    MapManageState state,
  ) {
    if (state.previewMapId == null) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                MdiIcons.mapSearchOutline,
                size: 64,
                color: AppColors.gray300,
              ),
              const SizedBox(height: 16),
              Text(
                '在左侧选择地图以预览详情',
                style: TextStyle(color: AppColors.gray500, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    final mapItem = state.localMaps.firstWhere(
      (m) => m.id == state.previewMapId,
      orElse: () => const LocalMapItem(
        id: '',
        title: '',
        timeUpdated: 0,
        size: 0,
        folderPath: '',
      ),
    );
    if (mapItem.id.isEmpty) return const SizedBox.shrink();

    final mapInfo = state.previewMapInfo;
    final mapLabel = mapInfo?.mapLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 160,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                ),
                child: MapBackground(
                  mapName: mapItem.title,
                  imageUrl: mapInfo?.mapUrl,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.map_outlined,
                          size: 20,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MarqueeText(
                            text: mapItem.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                              fontFamily: 'monospace',
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 8),
                                Shadow(color: Colors.black87, offset: Offset(1, 1), blurRadius: 2),
                                Shadow(color: Colors.black87, offset: Offset(-1, -1), blurRadius: 2),
                                Shadow(color: Colors.black87, offset: Offset(1, -1), blurRadius: 2),
                                Shadow(color: Colors.black87, offset: Offset(-1, 1), blurRadius: 2),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (mapLabel != null && mapLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.translate,
                            size: 15,
                            color: Colors.white.withValues(alpha: 0.9),
                            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: MarqueeText(
                              text: mapLabel,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.9),
                                shadows: [
                                  const Shadow(color: Colors.black, blurRadius: 4),
                                  Shadow(color: Colors.black.withValues(alpha: 0.9), offset: const Offset(1, 1), blurRadius: 2),
                                  Shadow(color: Colors.black.withValues(alpha: 0.9), offset: const Offset(-1, -1), blurRadius: 2),
                                  Shadow(color: Colors.black.withValues(alpha: 0.9), offset: const Offset(1, -1), blurRadius: 2),
                                  Shadow(color: Colors.black.withValues(alpha: 0.9), offset: const Offset(-1, 1), blurRadius: 2),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '详细信息',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.gray800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDataChip(
                      context,
                      '工坊 ID',
                      mapItem.id,
                      MdiIcons.identifier,
                      trailing: Tooltip(
                        message: '在 Steam 中打开创意工坊页面',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () {
                            launchUrlString(
                              'steam://openurl/https://steamcommunity.com/sharedfiles/filedetails/?id=${mapItem.id}',
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.blue500.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.blue500.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(MdiIcons.steam, size: 12, color: AppColors.blue500),
                                const SizedBox(width: 4),
                                const Text(
                                  '前往工坊',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.blue500,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildDataChip(
                      context,
                      '磁盘占用',
                      mapItem.size > 1024 * 1024 * 1024
                          ? '${(mapItem.size / 1024 / 1024 / 1024).toStringAsFixed(2)} GB'
                          : '${(mapItem.size / 1024 / 1024).toStringAsFixed(2)} MB',
                      MdiIcons.harddisk,
                    ),
                    _buildDataChip(
                      context,
                      '更新时间',
                      DateTime.fromMillisecondsSinceEpoch(
                        mapItem.timeUpdated * 1000,
                      ).toString().split('.').first,
                      MdiIcons.clockOutline,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '文件路径',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.gray800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate900 : AppColors.gray50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.slate700 : AppColors.gray200,
                    ),
                  ),
                  child: SelectableText(
                    mapItem.folderPath,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.gray500,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: Icon(MdiIcons.folderOpenOutline),
            label: const Text('在资源管理器中打开目录'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              launchUrlString(
                'file:///${mapItem.folderPath.replaceAll('\\', '/')}',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDataChip(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: AppColors.gray500),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.gray500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.gray800,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    bool isDark,
    MapManageState state,
  ) {
    final totalSizeBytes = state.localMaps.fold<int>(
      0,
      (sum, m) => sum + m.size,
    );
    final sizeStr = totalSizeBytes > 1024 * 1024 * 1024
        ? '${(totalSizeBytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB'
        : '${(totalSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate900 : AppColors.gray50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => context.read<MapManageBloc>().add(
                    const SelectAllMaps(true),
                  ),
                  icon: Icon(MdiIcons.checkboxMarkedOutline, size: 16),
                  label: const Text('全选'),
                ),
                Container(width: 1, height: 16, color: AppColors.gray300),
                TextButton.icon(
                  onPressed: () => context.read<MapManageBloc>().add(
                    const SelectAllMaps(false),
                  ),
                  icon: Icon(MdiIcons.checkboxBlankOutline, size: 16),
                  label: const Text('取消'),
                ),
                Container(width: 1, height: 16, color: AppColors.gray300),
                TextButton.icon(
                  onPressed: () =>
                      context.read<MapManageBloc>().add(InvertSelection()),
                  icon: Icon(MdiIcons.swapHorizontal, size: 16),
                  label: const Text('反选'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '已选 ${state.selectedMapIds.length} 张地图',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: state.selectedMapIds.isNotEmpty
                      ? AppColors.blue500
                      : AppColors.gray500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '共 ${state.localMaps.length} 张地图 • 总占用 $sizeStr',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : AppColors.gray500,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (state.isSteamRunning)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '必须完全退出 Steam 才能删除',
                style: TextStyle(
                  color: AppColors.red500,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ElevatedButton.icon(
            icon: state.isDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(MdiIcons.deleteEmptyOutline, size: 20),
            label: Text(
              '批量删除 (${state.selectedMapIds.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              elevation: state.selectedMapIds.isNotEmpty ? 4 : 0,
              shadowColor: AppColors.red500.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed:
                state.selectedMapIds.isEmpty ||
                    state.isSteamRunning ||
                    state.isDeleting
                ? null
                : () => _confirmDelete(context, state),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MapManageState state,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.amber500.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: AppColors.amber500,
              ),
            ),
            const SizedBox(width: 12),
            const Text('确认删除', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确定要删除选中的 ${state.selectedMapIds.length} 张地图吗？\n该操作直接删除本地文件，将不可恢复。',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.red500.withValues(alpha: 0.05),
                border: Border.all(
                  color: AppColors.red500.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    MdiIcons.alertCircleOutline,
                    size: 16,
                    color: AppColors.red500,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: const Text(
                      '【注意】必须完全退出 Steam 才能删除地图，否则将导致云同步异常！',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.red500,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('取消', style: TextStyle(color: AppColors.gray500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      context.read<MapManageBloc>().add(DeleteSelectedMaps());
    }
  }
}
