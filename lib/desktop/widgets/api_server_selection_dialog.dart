import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/bloc/server/server_bloc.dart';
import '../../core/bloc/server/server_event.dart';
import '../../core/models/server_models.dart';
import '../../core/services/third_party_api_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../core/constants/app_colors.dart';

class ApiServerSelectionDialog extends StatefulWidget {
  final String? targetCategoryName;
  final String? targetApiCategoryKey;
  final List<ServerItem>? existingServers;

  const ApiServerSelectionDialog({
    super.key,
    this.targetCategoryName,
    this.targetApiCategoryKey,
    this.existingServers,
  });

  @override
  State<ApiServerSelectionDialog> createState() =>
      _ApiServerSelectionDialogState();
}

class _ApiServerSelectionDialogState extends State<ApiServerSelectionDialog> {
  bool _isLoading = true;
  String? _error;
  Map<String, List<CS2ZeServerData>> _data = {};

  // 记录哪些服务器被选中了：Set 中存放的是 serverKey
  final Set<String> _selectedServers = {};

  // 记录已有服务器的备注名
  final Map<String, String> _existingNicknames = {};

  // 当前选中的 Tab 分类
  String? _currentTab;

  // 是否展开所有 Tab
  bool _isTabsExpanded = false;

  // 数据更新模式
  String _dataSourceMode = 'api';

  @override
  void initState() {
    super.initState();
    if (widget.existingServers != null) {
      for (final s in widget.existingServers!) {
        final addr = s.address ?? s.serverAddress;
        if (addr != null) {
          _selectedServers.add(addr);
          if (s.nickname != null && s.nickname!.isNotEmpty) {
            _existingNicknames[addr] = s.nickname!;
          }
        }
      }
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await ThirdPartyApiService.fetchCS2ZeServers();
      if (mounted) {
        setState(() {
          if (widget.targetApiCategoryKey != null &&
              data.containsKey(widget.targetApiCategoryKey)) {
            _data = {
              widget.targetApiCategoryKey!: data[widget.targetApiCategoryKey!]!,
            };
          } else if (widget.targetCategoryName != null &&
              data.containsKey(widget.targetCategoryName)) {
            _data = {
              widget.targetCategoryName!: data[widget.targetCategoryName!]!,
            };
          } else {
            _data = data;
          }
          if (_currentTab == null && _data.isNotEmpty) {
            _currentTab = _data.keys.first;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _toggleCategory(String categoryName, bool? value) {
    setState(() {
      final servers = _data[categoryName] ?? [];
      if (value == true) {
        _selectedServers.addAll(servers.map((s) => s.serverKey));
      } else {
        _selectedServers.removeAll(servers.map((s) => s.serverKey));
      }
    });
  }

  void _toggleServer(String serverKey, bool? value) {
    setState(() {
      if (value == true) {
        _selectedServers.add(serverKey);
      } else {
        _selectedServers.remove(serverKey);
      }
    });
  }

  bool _isCategoryFullySelected(String categoryName) {
    final servers = _data[categoryName] ?? [];
    if (servers.isEmpty) return false;
    return servers.every((s) => _selectedServers.contains(s.serverKey));
  }

  bool _isCategoryPartiallySelected(String categoryName) {
    final servers = _data[categoryName] ?? [];
    if (servers.isEmpty) return false;
    final selectedCount = servers
        .where((s) => _selectedServers.contains(s.serverKey))
        .length;
    return selectedCount > 0 && selectedCount < servers.length;
  }

  void _handleImport() {
    if (_selectedServers.isEmpty && widget.targetCategoryName == null) return;

    final bloc = context.read<ServerBloc>();

    _data.forEach((categoryName, servers) {
      // 在编辑模式下，只处理目标分类对应的数据
      if ((widget.targetApiCategoryKey != null &&
              categoryName != widget.targetApiCategoryKey) &&
          (widget.targetCategoryName != null &&
              categoryName != widget.targetCategoryName)) {
        return;
      }

      final selectedInThisCategory = servers
          .where((s) => _selectedServers.contains(s.serverKey))
          .toList();
      final destinationCategoryName = widget.targetCategoryName ?? categoryName;

      if (widget.targetCategoryName != null && widget.existingServers != null) {
        // 同步已有分类
        final existingAddresses = widget.existingServers!
            .map((e) => e.address ?? e.serverAddress)
            .toSet();
        final newAddresses = selectedInThisCategory
            .map((e) => e.serverKey)
            .toSet();

        // 新增选中的
        for (var server in selectedInThisCategory) {
          if (!existingAddresses.contains(server.serverKey)) {
            final newItem = ServerItem(
              serverAddress: server.serverKey,
              nickname: server.name,
              isCustom: true,
              dataSourceMode: _dataSourceMode,
              sourceApiUrl: ThirdPartyApiService.cs2zeApiUrl,
            );
            bloc.add(
              ServerAddServerToCategory(
                destinationCategoryName,
                newItem,
                isFromApi: true,
                sourceApiUrl: ThirdPartyApiService.cs2zeApiUrl,
                sourceApiCategoryName: categoryName,
              ),
            );
          }
        }

        // 删除取消选中的
        for (var existingServer in widget.existingServers!) {
          final addr = existingServer.address ?? existingServer.serverAddress;
          if (addr != null && !newAddresses.contains(addr)) {
            bloc.add(
              ServerDeleteServer(
                categoryName: destinationCategoryName,
                serverAddress: addr,
              ),
            );
          }
        }
      } else {
        // 全新导入
        if (selectedInThisCategory.isNotEmpty) {
          for (var server in selectedInThisCategory) {
            final newItem = ServerItem(
              serverAddress: server.serverKey,
              nickname: server.name,
              isCustom: true,
              dataSourceMode: _dataSourceMode,
              sourceApiUrl: ThirdPartyApiService.cs2zeApiUrl,
            );
            bloc.add(
              ServerAddServerToCategory(
                categoryName,
                newItem,
                isFromApi: true,
                sourceApiUrl: ThirdPartyApiService.cs2zeApiUrl,
                sourceApiCategoryName: categoryName,
              ),
            );
          }
        }
      }
    });

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 800,
            constraints: const BoxConstraints(maxHeight: 700),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.slate900.withValues(alpha: 0.75)
                  : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(isDark),
                const Divider(height: 1, thickness: 1, color: Colors.white10),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState(isDark)
                      : _error != null
                      ? _buildErrorState(isDark)
                      : _buildTree(isDark),
                ),
                if (!_isLoading && _error == null) ...[
                  const Divider(height: 1, thickness: 1, color: Colors.white10),
                  _buildFooter(isDark),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final titleText = widget.targetCategoryName != null
        ? '编辑 API 分类: ${widget.targetCategoryName}'
        : '导入第三方接口服务器';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.blue500.withValues(alpha: 0.1),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.blue500.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(MdiIcons.api, color: const Color(0xFF60A5FA), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.slate800,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '数据来源: CS2ZE Public API',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : AppColors.slate500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close_rounded,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
            splashRadius: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue500),
              backgroundColor: AppColors.blue500.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '正在拉取服务器数据...',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.slate600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.slate800,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(_error ?? '未知错误', style: TextStyle(color: Colors.red[300])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _fetchData();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重试'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue500,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTree(bool isDark) {
    if (_data.isEmpty) {
      return Center(
        child: Text(
          '没有找到任何服务器',
          style: TextStyle(color: isDark ? Colors.white54 : AppColors.slate500),
        ),
      );
    }

    final originalCategories = _data.keys.toList();
    if (_currentTab == null || !originalCategories.contains(_currentTab)) {
      if (widget.targetApiCategoryKey != null &&
          originalCategories.contains(widget.targetApiCategoryKey)) {
        _currentTab = widget.targetApiCategoryKey;
      } else if (widget.targetCategoryName != null &&
          originalCategories.contains(widget.targetCategoryName)) {
        _currentTab = widget.targetCategoryName;
      } else {
        _currentTab = originalCategories.first;
      }
    }

    final servers = _data[_currentTab]!;
    final fullySelected = _isCategoryFullySelected(_currentTab!);
    final partiallySelected = _isCategoryPartiallySelected(_currentTab!);

    // 控制显示多少个 Tab
    List<String> displayCategories = List.from(originalCategories);
    bool showExpandBtn = false;
    if (originalCategories.length > 5) {
      if (!_isTabsExpanded) {
        // 收起状态：将当前选中的移到最前面，然后截取前 4 个
        if (displayCategories.contains(_currentTab)) {
          displayCategories.remove(_currentTab);
          displayCategories.insert(0, _currentTab!);
        }
        displayCategories = displayCategories.take(4).toList();
      }
      showExpandBtn = true;
    }

    return Column(
      children: [
        // 顶部 Tab 栏和全选按钮
        if (widget.targetCategoryName == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.15)
                  : AppColors.slate100,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : AppColors.slate200,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧 Tabs
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...displayCategories.map((cat) {
                        final isSelected = cat == _currentTab;
                        return InkWell(
                          onTap: () {
                            if (_currentTab != cat) {
                              setState(() {
                                // 切换分类时清除已选服务器，保证只能选一个分类
                                _selectedServers.clear();
                                _currentTab = cat;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.blue500
                                  : (isDark ? Colors.white10 : Colors.white),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.blue500
                                    : (isDark
                                          ? Colors.white10
                                          : AppColors.slate200),
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white70
                                          : AppColors.slate600),
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }),

                      // 展开/收起按钮
                      if (showExpandBtn)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isTabsExpanded = !_isTabsExpanded;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black26
                                  : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isTabsExpanded ? '收起' : '展开',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : AppColors.slate500,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _isTabsExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: isDark
                                      ? Colors.white70
                                      : AppColors.slate500,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // 右侧全选按钮
                InkWell(
                  onTap: () => _toggleCategory(
                    _currentTab!,
                    !(fullySelected || partiallySelected),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: (fullySelected || partiallySelected)
                          ? AppColors.blue500.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (fullySelected || partiallySelected)
                            ? AppColors.blue500.withValues(alpha: 0.5)
                            : (isDark ? Colors.white10 : AppColors.slate300),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          (fullySelected || partiallySelected)
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 16,
                          color: (fullySelected || partiallySelected)
                              ? const Color(0xFF60A5FA)
                              : (isDark ? Colors.white54 : AppColors.slate500),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '全选该分类',
                          style: TextStyle(
                            fontSize: 13,
                            color: (fullySelected || partiallySelected)
                                ? const Color(0xFF60A5FA)
                                : (isDark
                                      ? Colors.white54
                                      : AppColors.slate500),
                            fontWeight: (fullySelected || partiallySelected)
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 服务器网格
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 500 ? 2 : 1;
                double spacing = 12;
                double itemWidth =
                    (constraints.maxWidth - (crossAxisCount - 1) * spacing) /
                    crossAxisCount;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: servers.map((server) {
                    final isSelected = _selectedServers.contains(
                      server.serverKey,
                    );
                    return SizedBox(
                      width: itemWidth,
                      child: _buildServerItem(server, isSelected, isDark),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServerItem(
    CS2ZeServerData server,
    bool isSelected,
    bool isDark,
  ) {
    return AnimatedScale(
      scale: isSelected ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: InkWell(
        onTap: () => _toggleServer(server.serverKey, !isSelected),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.blue500
                  : (isDark ? Colors.white10 : Colors.black12),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.blue500.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 背景图片
                if (server.imageUrl != null && server.imageUrl!.isNotEmpty)
                  Image.network(
                    server.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildFallbackBg(isDark),
                  )
                else
                  _buildFallbackBg(isDark),

                // 深色渐变遮罩层（底部黑，顶部透明）
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.4),
                        Colors.black.withValues(alpha: 0.9),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),

                // 如果未选中，再加一层微弱遮罩，突出选中状态
                if (!isSelected)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),

                // 内容层
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 顶部标牌与选中徽章
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 游戏标牌
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              server.gameType.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          // 选中徽章
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: AppColors.blue500,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              ),
                            )
                          else
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white54,
                                  width: 1.5,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const Spacer(),

                      // 服务器名称与备注
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: server.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 2),
                                ],
                              ),
                            ),
                            if (_existingNicknames.containsKey(
                                  server.serverKey,
                                ) &&
                                _existingNicknames[server.serverKey] !=
                                    server.name)
                              TextSpan(
                                text:
                                    ' (${_existingNicknames[server.serverKey]})',
                                style: const TextStyle(
                                  color: Color(0xFF60A5FA),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      // 地图与人数标签
                      Row(
                        children: [
                          Icon(
                            MdiIcons.mapOutline,
                            size: 14,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              server.mapCn ?? server.map ?? '未知地图',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 1),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.people_outline,
                            size: 14,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${server.players}/${server.maxPlayers}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 1),
                              ],
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
  }

  Widget _buildFallbackBg(bool isDark) {
    return Container(
      color: isDark ? AppColors.slate800 : AppColors.slate500,
      child: const Center(
        child: Icon(Icons.dns_rounded, size: 40, color: Colors.white10),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.2) : AppColors.slate50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 模式选择区
          Text(
            '数据更新模式',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.slate600,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildModeOption(
                  title: '接口获取 (推荐)',
                  subtitle: '从第三方网站统一获取人数和地图',
                  value: 'api',
                  icon: Icons.cloud_sync_rounded,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildModeOption(
                  title: '本地直连 (A2S)',
                  subtitle: '由电脑直接连到服务器，数据绝对实时',
                  value: 'a2s',
                  icon: Icons.dns_rounded,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 操作按钮区
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  foregroundColor: isDark ? Colors.white70 : AppColors.slate600,
                ),
                child: const Text(
                  '取消',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed:
                    _selectedServers.isEmpty &&
                        widget.targetCategoryName == null
                    ? null
                    : _handleImport,
                icon: const Icon(Icons.check_rounded, size: 20),
                label: Text(
                  widget.targetCategoryName != null
                      ? '保存修改 (${_selectedServers.length})'
                      : '确认导入 (${_selectedServers.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue500,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark
                      ? Colors.white10
                      : Colors.black12,
                  disabledForegroundColor: isDark
                      ? Colors.white30
                      : Colors.black38,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _dataSourceMode == value;
    return InkWell(
      onTap: () {
        setState(() {
          _dataSourceMode = value;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.blue500.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.blue500.withValues(alpha: 0.5)
                : (isDark ? Colors.white10 : Colors.black12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? const Color(0xFF60A5FA)
                  : (isDark ? Colors.white54 : AppColors.slate500),
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
                      color: isSelected
                          ? (isDark ? Colors.white : AppColors.slate800)
                          : (isDark ? Colors.white54 : AppColors.slate500),
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF60A5FA)
                          : (isDark ? Colors.white38 : AppColors.slate400),
                      fontSize: 12,
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
}
