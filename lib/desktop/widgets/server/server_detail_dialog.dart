import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../core/models/server_models.dart';
import '../../../core/widgets/map_background.dart';
import '../../../core/constants/app_colors.dart';
import 'server_history_view.dart';
import 'map_contribution/map_general_contribution_view.dart';
import 'map_contribution/map_tag_contribution_view.dart';
import '../../../core/models/map_contribution_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/bloc/map_contribution/map_contribution_bloc.dart';
import '../../../core/bloc/map_tag/map_tag_bloc.dart';
import 'map_config_view.dart';
import 'server_players_view.dart';

class ServerDetailDialog extends StatefulWidget {
  final ExtendedServerItem server;
  final String? categoryName; // 分类名称
  final VoidCallback? onDelete; // 删除回调（仅自定义服务器）
  final bool isServerMode;

  const ServerDetailDialog({
    super.key,
    required this.server,
    this.categoryName,
    this.onDelete,
    this.isServerMode = true,
  });

  /// 快捷入口：仅展示地图编辑相关信息（通过构造一个假的 ExtendedServerItem）
  static void showMapEdit(
    BuildContext context, {
    required String mapName,
    String? mapLabel,
    bool isDifficultySeparated = false,
    String? serverAddress,
  }) {
    showDialog(
      context: context,
      builder: (context) => ServerDetailDialog(
        isServerMode: false,
        server: ExtendedServerItem(
          serverItem: ServerItem(
            address: serverAddress,
            isDifficultySeparated: isDifficultySeparated,
          ),
          serverData: ServerInfo(map: mapName),
          mapInfo: MapData(
            id: 0,
            mapName: mapName,
            mapLabel: mapLabel ?? '',
            mapUrl: '',
          ),
        ),
      ),
    );
  }

  @override
  State<ServerDetailDialog> createState() => _ServerDetailDialogState();
}

class _ServerDetailDialogState extends State<ServerDetailDialog> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);
    final dividerColor = isDark ? Colors.white10 : Colors.black12;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => MapContributionBloc()),
          BlocProvider(create: (context) => MapTagBloc()),
        ],
        child: Container(
          width: 1100,
          height: 750,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                _buildSidebar(isDark),
                VerticalDivider(width: 1, color: dividerColor),
                Expanded(child: _buildContentArea(isDark)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(bool isDark) {
    final mapName = widget.server.serverData?.map ?? '未知地图';
    final mapLabel = widget.server.mapInfo?.mapLabel;
    final displayMapName = mapLabel != null && mapLabel.isNotEmpty
        ? mapLabel
        : mapName;
    final subMapName = mapLabel != null && mapLabel.isNotEmpty ? mapName : '';

    return SizedBox(
      width: 240,
      child: Column(
        children: [
          // 左上角地图缩略图与信息
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: MapBackground(
                    mapName: widget.server.serverData?.map,
                    imageUrl: widget.server.mapInfo?.mapUrl,
                    cacheWidth: 480,
                    cacheHeight: 320,
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(
                            alpha: 0.8,
                          ), // 图片遮罩始终用深色保证文字可读
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayMapName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subMapName.isNotEmpty)
                        Text(
                          subMapName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 导航菜单
          _buildNavItem(
            isDark: isDark,
            index: 0,
            icon: MdiIcons.mapSearch,
            title: '地图详情',
          ),
          if (widget.isServerMode) ...[
            _buildNavItem(
              isDark: isDark,
              index: 1,
              icon: Icons.people_alt_outlined,
              title: '玩家列表',
            ),
            _buildNavItem(
              isDark: isDark,
              index: 2,
              icon: Icons.history_rounded,
              title: '历史记录',
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 24, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '编辑地图',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          _buildNavItem(
            isDark: isDark,
            index: 3,
            icon: MdiIcons.textBoxOutline,
            title: '中文名称',
          ),
          _buildNavItem(
            isDark: isDark,
            index: 4,
            icon: MdiIcons.imageOutline,
            title: '背景图片',
          ),
          _buildNavItem(
            isDark: isDark,
            index: 5,
            icon: MdiIcons.tagOutline,
            title: '标签',
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required bool isDark,
    required int index,
    required IconData icon,
    required String title,
  }) {
    final isSelected = _selectedIndex == index;
    final selectedColor = AppColors.primary;
    final unselectedColor = isDark ? Colors.white60 : Colors.black54;
    final textColor = isSelected
        ? (isDark ? Colors.white : Colors.black87)
        : unselectedColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_selectedIndex != index) {
            setState(() {
              _selectedIndex = index;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? selectedColor.withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isSelected ? selectedColor : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? selectedColor : unselectedColor,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentArea(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.white60 : Colors.black54;
    final dividerColor = isDark ? Colors.white10 : Colors.black12;

    return Column(
      children: [
        // 顶部 Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: dividerColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.isServerMode
                      ? widget.server.serverItem.getDisplayName(
                          widget.server.serverData?.hostName,
                        )
                      : '地图信息',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: iconColor),
                tooltip: '关闭',
              ),
            ],
          ),
        ),
        // 内容主体
        Expanded(child: _buildCurrentTab(isDark)),
      ],
    );
  }

  Widget _buildCurrentTab(bool isDark) {
    switch (_selectedIndex) {
      case 0:
        return _buildMapDetailsTab(isDark);
      case 1:
        return widget.isServerMode
            ? ServerPlayersView(server: widget.server, isDark: isDark)
            : const SizedBox.shrink();
      case 2:
        return widget.isServerMode
            ? _buildHistoryTab(isDark)
            : const SizedBox.shrink();
      case 3:
        return _buildNameContributionTab(isDark);
      case 4:
        return _buildBackgroundContributionTab(isDark);
      case 5:
        return _buildTagContributionTab(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMapDetailsTab(bool isDark) {
    return MapConfigView(
      mapName: widget.server.serverData?.map ?? '',
      isDark: isDark,
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    return ServerHistoryDialog(server: widget.server);
  }

  Widget _buildNameContributionTab(bool isDark) {
    final mapName = widget.server.serverData?.map ?? '';
    return MapGeneralContributionView(
      mapName: mapName,
      type: ContributionType.name,
    );
  }

  Widget _buildBackgroundContributionTab(bool isDark) {
    final mapName = widget.server.serverData?.map ?? '';
    return MapGeneralContributionView(
      mapName: mapName,
      type: ContributionType.background,
    );
  }

  Widget _buildTagContributionTab(bool isDark) {
    final mapName = widget.server.serverData?.map ?? '';
    final mapLabel = widget.server.mapInfo?.mapLabel;
    final isDifficultySeparated =
        widget.server.serverItem.isDifficultySeparated;
    final serverAddress =
        widget.server.serverItem.address ??
        widget.server.serverItem.serverAddress;

    return MapTagContributionView(
      mapName: mapName,
      mapLabel: mapLabel,
      isDifficultySeparated: isDifficultySeparated,
      serverAddress: serverAddress,
    );
  }
}
